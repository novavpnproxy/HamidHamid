from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app import main


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "DB_PATH", str(tmp_path / "test.sqlite3"))
    monkeypatch.setattr(main, "ADMIN_USERNAME", "owner")
    monkeypatch.setattr(main, "ADMIN_PASSWORD", "correct-horse-battery-staple")
    monkeypatch.setattr(main, "JWT_SECRET", "a-test-secret-that-is-long-enough-for-hmac-signing")
    monkeypatch.setattr(main, "TOKEN_TTL_MINUTES", 30)
    main._login_attempts.clear()
    with TestClient(main.app) as test_client:
        yield test_client


def admin_headers(client: TestClient) -> dict[str, str]:
    response = client.post("/api/v1/admin/login", json={
        "username": "owner",
        "password": "correct-horse-battery-staple",
    })
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def server_payload(**overrides):
    return {
        "name": "Managed server",
        "protocol": "VLESS",
        "country_code": None,
        "country_name_fa": None,
        "country_name_en": None,
        "location_verified": False,
        "enabled": True,
        "config": "vless://example-profile",
        **overrides,
    }


def test_database_starts_empty_and_public_api_has_no_fake_servers(client):
    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/ready").json() == {"status": "ready"}
    response = client.get("/api/v1/servers")
    assert response.status_code == 200
    assert response.json() == {"servers": []}
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["x-content-type-options"] == "nosniff"


def test_admin_server_management_never_returns_config_in_public_directory(client):
    headers = admin_headers(client)
    created = client.post("/api/v1/admin/servers", headers=headers, json=server_payload())
    assert created.status_code == 201
    server_id = created.json()["id"]

    public_response = client.get("/api/v1/servers")
    assert public_response.status_code == 200
    assert len(public_response.json()["servers"]) == 1
    assert "config" not in public_response.json()["servers"][0]
    assert "example-profile" not in public_response.text

    admin_detail = client.get(f"/api/v1/admin/servers/{server_id}", headers=headers)
    assert admin_detail.status_code == 200
    assert admin_detail.json()["config"] == "vless://example-profile"
    assert admin_detail.headers["cache-control"] == "no-store"


def test_country_and_city_location_metadata_reaches_app_without_raw_config(client):
    headers = admin_headers(client)
    created = client.post(
        "/api/v1/admin/servers",
        headers=headers,
        json=server_payload(
            country_code="DE",
            country_name_fa="آلمان",
            country_name_en="Germany",
            location_name_fa="فرانکفورت",
            location_name_en="Frankfurt",
            location_verified=True,
        ),
    )
    assert created.status_code == 201
    public = client.get("/api/v1/servers")
    assert public.status_code == 200
    server = public.json()["servers"][0]
    assert server["country_code"] == "DE"
    assert server["location_name_fa"] == "فرانکفورت"
    assert server["location_name_en"] == "Frankfurt"
    assert "config" not in server


def test_home_content_supports_manual_ads_and_rotating_announcements(client):
    headers = admin_headers(client)
    assert client.get("/api/v1/home-content").json() == {
        "ad_mode": "manual", "network_provider": None, "network_zone_id": None,
        "network_code": None, "ads": [], "announcements": [],
    }
    created_ad = client.post("/api/v1/admin/home-content/ads", headers=headers, json={
        "title": "Nova partner", "description": "Offer", "image_url": "https://cdn.example/ad.png",
        "target_url": "https://example.com/offer", "enabled": True, "sort_order": 1,
    })
    assert created_ad.status_code == 201
    ad_id = created_ad.json()["id"]
    created_notice = client.post("/api/v1/admin/home-content/announcements", headers=headers, json={
        "message": "Happy new year", "enabled": True, "sort_order": 1,
    })
    assert created_notice.status_code == 201
    public = client.get("/api/v1/home-content")
    assert public.status_code == 200
    assert public.json()["ads"][0]["id"] == ad_id
    assert public.json()["announcements"][0]["message"] == "Happy new year"
    assert "network_code" not in public.json() or public.json()["network_code"] is None

    network = client.put("/api/v1/admin/home-content/settings", headers=headers, json={
        "mode": "network", "network_provider": "adsterra", "network_zone_id": "1234567",
    })
    assert network.status_code == 200
    assert client.get("/api/v1/home-content").json()["ad_mode"] == "network"
    assert client.get("/api/v1/admin/home-content", headers=headers).status_code == 200


def test_home_content_admin_routes_require_authentication(client):
    assert client.get("/api/v1/admin/home-content").status_code == 401
    assert client.post("/api/v1/admin/home-content/ads", json={}).status_code == 401


def test_raw_profile_delivery_requires_client_authorization(client):
    response = client.get("/api/v1/servers/server-id/config")
    assert response.status_code == 401
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["www-authenticate"] == "Bearer"
    assert "config" not in response.json()


def test_device_must_be_approved_before_receiving_profile(client):
    headers = admin_headers(client)
    created = client.post(
        "/api/v1/admin/servers",
        headers=headers,
        json=server_payload(),
    )
    assert created.status_code == 201
    server_id = created.json()["id"]

    device_id = "a" * 64
    pending = client.post(
        "/api/v1/client/register",
        json={"device_id": device_id},
    )
    assert pending.status_code == 403
    assert pending.headers["cache-control"] == "no-store"

    devices = client.get("/api/v1/admin/devices", headers=headers)
    assert devices.status_code == 200
    assert any(
        item["device_id"] == device_id and not item["enabled"]
        for item in devices.json()["devices"]
    )

    approved = client.put(
        f"/api/v1/admin/devices/{device_id}",
        headers=headers,
        json={"enabled": True},
    )
    assert approved.status_code == 200

    registration = client.post(
        "/api/v1/client/register",
        json={"device_id": device_id},
    )
    assert registration.status_code == 200
    token = registration.json()["access_token"]

    profile = client.get(
        f"/api/v1/servers/{server_id}/config",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert profile.status_code == 200
    assert profile.json()["config"] == "vless://example-profile"
    assert profile.headers["cache-control"] == "no-store"


def test_admin_routes_require_authentication(client):
    assert client.get("/api/v1/admin/servers").status_code == 401
    assert client.get("/api/v1/admin/servers", headers={"Authorization": "Bearer invalid"}).status_code == 401


def test_admin_login_is_rate_limited(client):
    for _ in range(8):
        response = client.post("/api/v1/admin/login", json={"username": "owner", "password": "wrong-password"})
        assert response.status_code == 401
    response = client.post("/api/v1/admin/login", json={"username": "owner", "password": "correct-horse-battery-staple"})
    assert response.status_code == 429


def test_profile_protocol_must_match_declared_protocol(client):
    headers = admin_headers(client)
    response = client.post("/api/v1/admin/servers", headers=headers, json=server_payload(protocol="VMESS", config="vless://not-vmess"))
    assert response.status_code == 422


def test_supported_protocol_uri_is_accepted():
    for protocol, config in (
        ("VLESS", "vless://profile"),
        ("VMESS", "vmess://profile"),
        ("TROJAN", "trojan://profile"),
        ("SHADOWSOCKS", "ss://profile"),
    ):
        assert main.ServerInput(name="Node", protocol=protocol, config=config).protocol == protocol


def test_unsupported_uri_and_malformed_json_are_rejected():
    with pytest.raises(ValidationError):
        main.ServerInput(name="Node", protocol="VLESS", config="ftp://not-a-vpn-profile")
    with pytest.raises(ValidationError):
        main.ServerInput(name="Node", protocol="VLESS", config="{broken")


def test_verified_location_requires_country_metadata(client):
    headers = admin_headers(client)
    response = client.post("/api/v1/admin/servers", headers=headers, json=server_payload(location_verified=True))
    assert response.status_code == 422


def test_disabled_server_is_not_public(client):
    headers = admin_headers(client)
    created = client.post("/api/v1/admin/servers", headers=headers, json=server_payload(enabled=False))
    assert created.status_code == 201
    assert client.get("/api/v1/servers").json() == {"servers": []}



def test_postgresql_database_adapter(monkeypatch):
    import os

    database_url = os.getenv("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("PostgreSQL integration service is not configured")

    monkeypatch.setattr(main, "DATABASE_URL", database_url)
    monkeypatch.setattr(main, "ADMIN_USERNAME", "owner")
    monkeypatch.setattr(main, "ADMIN_PASSWORD", "correct-horse-battery-staple")
    monkeypatch.setattr(main, "JWT_SECRET", "a-test-secret-that-is-long-enough-for-hmac-signing")
    monkeypatch.setattr(main, "TOKEN_TTL_MINUTES", 30)
    main._login_attempts.clear()

    with TestClient(main.app) as postgres_client:
        with main.database() as conn:
            conn.execute("DELETE FROM client_devices")
            conn.execute("DELETE FROM servers")

        assert postgres_client.get("/health").json() == {"status": "ok"}
        headers = admin_headers(postgres_client)
        created = postgres_client.post(
            "/api/v1/admin/servers",
            headers=headers,
            json=server_payload(),
        )
        assert created.status_code == 201
        server_id = created.json()["id"]

        public = postgres_client.get("/api/v1/servers")
        assert public.status_code == 200
        assert len(public.json()["servers"]) == 1
        assert "config" not in public.json()["servers"][0]

        detail = postgres_client.get(
            f"/api/v1/admin/servers/{server_id}",
            headers=headers,
        )
        assert detail.status_code == 200
        assert detail.json()["config"] == "vless://example-profile"

        device_id = "b" * 64
        pending = postgres_client.post(
            "/api/v1/client/register",
            json={"device_id": device_id},
        )
        assert pending.status_code == 403

        approved = postgres_client.put(
            f"/api/v1/admin/devices/{device_id}",
            headers=headers,
            json={"enabled": True},
        )
        assert approved.status_code == 200

        registration = postgres_client.post(
            "/api/v1/client/register",
            json={"device_id": device_id},
        )
        assert registration.status_code == 200
        profile = postgres_client.get(
            f"/api/v1/servers/{server_id}/config",
            headers={"Authorization": f"Bearer {registration.json()['access_token']}"},
        )
        assert profile.status_code == 200
        assert profile.json()["config"] == "vless://example-profile"


def test_protocols_outside_current_xray_engine_are_rejected():
    with pytest.raises(ValidationError):
        main.ServerInput(
            name="Unsupported node",
            protocol="HYSTERIA2",
            config="hy2://profile",
        )
