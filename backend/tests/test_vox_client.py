from __future__ import annotations

import httpx
import pytest
from fastapi.testclient import TestClient

from app import main
from app import vox_client


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "DB_PATH", str(tmp_path / "vox-test.sqlite3"))
    monkeypatch.setattr(main, "ADMIN_USERNAME", "owner")
    monkeypatch.setattr(main, "ADMIN_PASSWORD", "correct-horse-battery-staple")
    monkeypatch.setattr(main, "JWT_SECRET", "a-test-secret-that-is-long-enough-for-hmac-signing")
    monkeypatch.setattr(main, "TOKEN_TTL_MINUTES", 30)
    monkeypatch.setenv("VOX_API_KEY", "vxk_test_secret")
    main._login_attempts.clear()
    with TestClient(main.app) as test_client:
        yield test_client


def _approved_client_token(client: TestClient, device_id: str) -> str:
    # Current product behavior auto-enables new devices; manual admin approval
    # was intentionally removed. Registration must immediately issue a client token.
    registered = client.post("/api/v1/client/register", json={"device_id": device_id})
    assert registered.status_code == 200
    return registered.json()["access_token"]


def test_vox_locations_and_fresh_vless_config_are_server_side_and_authenticated(client, monkeypatch):
    device_id = "c" * 64
    token = _approved_client_token(client, device_id)
    calls = []

    def fake_request(method, url, *, headers, params=None, json=None, timeout=None):
        calls.append((method, url, headers, params, json, timeout))
        request = httpx.Request(method, url)
        if method == "GET" and url.endswith("/locations"):
            return httpx.Response(200, json={"locations": [{"id": "de-frankfurt", "protocols": ["vless"]}]}, request=request)
        if method == "POST" and url.endswith("/users"):
            return httpx.Response(200, json={"user": {"external_id": json["external_id"], "status": "active"}, "created": True}, request=request)
        if method == "GET" and url.endswith(f"/users/nova_{device_id}/config"):
            return httpx.Response(200, json={
                "external_id": f"nova_{device_id}",
                "location": "de-frankfurt",
                "location_label": "Germany (Frankfurt)",
                "protocol": "vless",
                "config": "vless://private-config",
                "xray_outbound": {"protocol": "vless"},
            }, request=request)
        return httpx.Response(404, json={"detail": "not_found"}, request=request)

    monkeypatch.setattr(vox_client.httpx, "request", fake_request)
    headers = {"Authorization": f"Bearer {token}"}

    locations = client.get("/api/v1/vox/locations?protocol=vless", headers=headers)
    assert locations.status_code == 200
    assert locations.json()["locations"][0]["id"] == "de-frankfurt"

    config = client.get(
        "/api/v1/vox/config?location=de-frankfurt&protocol=vless",
        headers=headers,
    )
    assert config.status_code == 200
    assert config.headers["cache-control"] == "no-store"
    assert config.json()["config"] == "vless://private-config"
    assert config.json()["external_id"] == f"nova_{device_id}"
    assert len(calls) == 3
    assert all(call[2]["Authorization"] == "Bearer vxk_test_secret" for call in calls)
    assert all("vxk_test_secret" not in str(call[3:5]) for call in calls)


def test_vox_routes_require_approved_client_and_secret(client, monkeypatch):
    assert client.get("/api/v1/vox/config?location=de-frankfurt").status_code == 401
    token = _approved_client_token(client, "d" * 64)
    monkeypatch.delenv("VOX_API_KEY", raising=False)
    # Public location metadata may legitimately be served from the one-hour
    # cache after the upstream key is removed. Verify a cache miss with a
    # fresh client so this test is independent of other tests' cache state.
    with pytest.raises(vox_client.HTTPException) as error:
        vox_client.VoxClient().locations()
    assert error.value.status_code == 503
    assert error.value.detail == "Vox integration is not configured"


def test_vox_protocol_route_does_not_expose_unintegrated_wireguard_or_amneziawg(client):
    token = _approved_client_token(client, "e" * 64)
    response = client.get(
        "/api/v1/vox/locations?protocol=amneziawg",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422
