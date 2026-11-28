from __future__ import annotations

import re
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Response,
)
from jose import JWTError, jwt
from pydantic import BaseModel, Field


DEVICE_ID_PATTERN = re.compile(r"^[a-f0-9]{64}$")
CLIENT_AUDIENCE = "nova-vpn-client"


class RegistrationPayload(BaseModel):
    device_id: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[a-f0-9]{64}$",
    )
    stable_device_id: str | None = Field(
        default=None,
        min_length=64,
        max_length=64,
        pattern=r"^[a-f0-9]{64}$",
    )


class DevicePermissionPayload(BaseModel):
    enabled: bool


def install_profile_delivery(
    app,
    *,
    database,
    admin_claims,
    jwt_secret,
    issuer,
    algorithm,
):
    """
    Install automatic device registration and protected profile delivery.

    New devices are enabled automatically. Access is controlled by subscription entitlement, not manual device approval.
    Admin credentials must never be included in the mobile application.
    """

    router = APIRouter()

    @app.on_event("startup")
    def initialize_devices():
        with database() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS client_devices (
                    device_id TEXT PRIMARY KEY,
                    first_seen_at TEXT NOT NULL,
                    last_seen_at TEXT NOT NULL,
                    enabled INTEGER NOT NULL DEFAULT 1
                )
                """
            )
            if conn._postgres:
                columns = {row["column_name"] for row in conn.execute(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_schema = current_schema() AND table_name = 'client_devices'"
                ).fetchall()}
            else:
                columns = {row["name"] for row in conn.execute("PRAGMA table_info(client_devices)").fetchall()}
            if "stable_device_id" not in columns:
                conn.execute("ALTER TABLE client_devices ADD COLUMN stable_device_id TEXT")
            conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_client_devices_stable_id ON client_devices(stable_device_id)")
            conn.execute("""
                CREATE TABLE IF NOT EXISTS app_migrations (
                    name TEXT PRIMARY KEY,
                    applied_at TEXT NOT NULL
                )
            """)
            migrated = conn.execute(
                "SELECT name FROM app_migrations WHERE name = ?",
                ("remove_manual_device_approval_v1",),
            ).fetchone()
            if migrated is None:
                # Activate legacy pending installs exactly once. Future explicit
                # security blocks remain effective across service restarts.
                conn.execute("UPDATE client_devices SET enabled = 1")
                conn.execute(
                    "INSERT INTO app_migrations (name, applied_at) VALUES (?, ?)",
                    ("remove_manual_device_approval_v1", datetime.now(timezone.utc).isoformat()),
                )

    def require_device_id(device_id: str) -> str:
        if not DEVICE_ID_PATTERN.fullmatch(device_id):
            raise HTTPException(
                status_code=422,
                detail="Invalid device identity",
            )
        return device_id

    def require_client(
        authorization: str | None = Header(default=None),
    ) -> dict:
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(
                status_code=401,
                detail="Client authentication required",
                headers={"WWW-Authenticate": "Bearer"},
            )

        token = authorization[7:].strip()

        try:
            claims = jwt.decode(
                token,
                jwt_secret,
                algorithms=[algorithm],
                issuer=issuer,
                audience=CLIENT_AUDIENCE,
                options={
                    "require_iss": True,
                    "require_sub": True,
                    "require_exp": True,
                    "require_iat": True,
                    "require_aud": True,
                },
            )
        except JWTError as exc:
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired client token",
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc

        if claims.get("scope") != "client":
            raise HTTPException(
                status_code=403,
                detail="Client permission required",
            )

        device_id = claims.get("sub")
        if (
            not isinstance(device_id, str)
            or not DEVICE_ID_PATTERN.fullmatch(device_id)
        ):
            raise HTTPException(
                status_code=401,
                detail="Invalid device identity",
            )

        with database() as conn:
            row = conn.execute(
                """
                SELECT enabled
                FROM client_devices
                WHERE device_id = ?
                """,
                (device_id,),
            ).fetchone()

        if row is None or not bool(row["enabled"]):
            raise HTTPException(
                status_code=403,
                detail="Device access is blocked",
            )

        return claims

    @router.post("/api/v1/client/register")
    def register_client(
        payload: RegistrationPayload,
        response: Response,
    ) -> dict:
        response.headers["Cache-Control"] = "no-store"
        now = datetime.now(timezone.utc)
        timestamp = now.isoformat()

        with database() as conn:
            canonical_id = payload.device_id
            row = None
            if payload.stable_device_id:
                row = conn.execute(
                    "SELECT device_id, enabled FROM client_devices WHERE stable_device_id = ?",
                    (payload.stable_device_id,),
                ).fetchone()
                if row is not None:
                    canonical_id = row["device_id"]

            if row is None:
                row = conn.execute(
                    "SELECT device_id, enabled FROM client_devices WHERE device_id = ?",
                    (payload.device_id,),
                ).fetchone()

            if row is None:
                conn.execute(
                    """
                    INSERT INTO client_devices (
                        device_id, first_seen_at, last_seen_at, enabled, stable_device_id
                    ) VALUES (?, ?, ?, 1, ?)
                    """,
                    (canonical_id, timestamp, timestamp, payload.stable_device_id),
                )
            else:
                canonical_id = row["device_id"]
                conn.execute(
                    """
                    UPDATE client_devices
                    SET last_seen_at = ?,
                        stable_device_id = COALESCE(stable_device_id, ?)
                    WHERE device_id = ?
                    """,
                    (timestamp, payload.stable_device_id, canonical_id),
                )

            row = conn.execute(
                "SELECT enabled FROM client_devices WHERE device_id = ?",
                (canonical_id,),
            ).fetchone()
            registered = row is not None and bool(row["enabled"])

        if not registered:
            raise HTTPException(
                status_code=403,
                detail="Device access is blocked",
                headers={"Cache-Control": "no-store"},
            )

        expires_at = now + timedelta(minutes=30)
        token = jwt.encode(
            {
                "sub": canonical_id,
                "scope": "client",
                "iss": issuer,
                "aud": CLIENT_AUDIENCE,
                "iat": now,
                "exp": expires_at,
                "jti": secrets.token_urlsafe(24),
            },
            jwt_secret,
            algorithm=algorithm,
        )

        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": 1800,
        }

    @router.get("/api/v1/admin/devices")
    def list_devices(
        _: dict = Depends(admin_claims),
    ) -> dict:
        with database() as conn:
            rows = conn.execute(
                """
                SELECT
                    device_id,
                    first_seen_at,
                    last_seen_at,
                    enabled
                FROM client_devices
                ORDER BY first_seen_at DESC
                LIMIT 100
                """
            ).fetchall()

        return {
            "devices": [
                {
                    "device_id": row["device_id"],
                    "first_seen_at": row["first_seen_at"],
                    "last_seen_at": row["last_seen_at"],
                    "enabled": bool(row["enabled"]),
                }
                for row in rows
            ]
        }

    @router.put("/api/v1/admin/devices/{device_id}")
    def set_device_permission(
        device_id: str,
        payload: DevicePermissionPayload,
        _: dict = Depends(admin_claims),
    ) -> dict:
        require_device_id(device_id)

        with database() as conn:
            cursor = conn.execute(
                """
                UPDATE client_devices
                SET enabled = ?
                WHERE device_id = ?
                """,
                (int(payload.enabled), device_id),
            )

            if cursor.rowcount == 0:
                raise HTTPException(
                    status_code=404,
                    detail="Device not found",
                )

        return {
            "device_id": device_id,
            "enabled": payload.enabled,
        }

    @router.get("/api/v1/servers/{server_id}/config")
    def get_server_config(
        server_id: str,
        response: Response,
        _: dict = Depends(require_client),
    ) -> dict:
        response.headers["Cache-Control"] = "no-store"

        with database() as conn:
            row = conn.execute(
                """
                SELECT id, config, updated_at
                FROM servers
                WHERE id = ? AND enabled = 1
                """,
                (server_id,),
            ).fetchone()

        if row is None:
            raise HTTPException(
                status_code=404,
                detail="Server not found or disabled",
            )

        return {
            "id": row["id"],
            "config": row["config"],
            "updated_at": row["updated_at"],
        }

    app.include_router(router)
    return require_client
