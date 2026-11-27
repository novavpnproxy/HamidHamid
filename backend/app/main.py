from __future__ import annotations

from .Profile_delivery import install_profile_delivery

import hmac
import json
import os
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterator, Mapping

from fastapi import Depends, FastAPI, Header, HTTPException, Request, Response, status
from fastapi.responses import FileResponse
from jose import JWTError, jwt
from pydantic import BaseModel, Field, field_validator, model_validator

APP_DIR = Path(__file__).resolve().parent
DB_PATH = os.getenv("DATABASE_PATH", str(APP_DIR.parent / "nova.sqlite3"))
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")
JWT_SECRET = os.getenv("JWT_SECRET", "")
TOKEN_TTL_MINUTES = int(os.getenv("TOKEN_TTL_MINUTES", "30"))
ALGORITHM = "HS256"
TOKEN_ISSUER = "nova-vpn-api"
SUPPORTED_PROTOCOLS = {"VLESS", "VMESS", "TROJAN", "SHADOWSOCKS"}
COUNTRY_CODE = re.compile(r"^[A-Z]{2}$")
PROFILE_SCHEMES = {
    "VLESS": {"vless"},
    "VMESS": {"vmess"},
    "TROJAN": {"trojan"},
    "SHADOWSOCKS": {"ss", "shadowsocks"},
}

app = FastAPI(title="NOVA VPN API", version="0.3.0", docs_url=None, redoc_url=None)
_login_attempts: dict[str, list[float]] = {}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def check_runtime_secrets() -> None:
    if not ADMIN_USERNAME.strip() or len(ADMIN_USERNAME) > 128:
        raise RuntimeError("Set ADMIN_USERNAME to a non-empty value of at most 128 characters")
    if len(ADMIN_PASSWORD) < 16 or len(ADMIN_PASSWORD) > 512:
        raise RuntimeError("Set a unique ADMIN_PASSWORD between 16 and 512 characters")
    if len(JWT_SECRET) < 32 or "replace-with" in JWT_SECRET:
        raise RuntimeError("Set JWT_SECRET to at least 32 random characters")
    if not 5 <= TOKEN_TTL_MINUTES <= 240:
        raise RuntimeError("TOKEN_TTL_MINUTES must be between 5 and 240")


class DatabaseConnection:
    """Small SQL compatibility layer for SQLite and managed PostgreSQL."""

    def __init__(self, connection, *, postgres: bool):
        self._connection = connection
        self._postgres = postgres

    def execute(self, statement: str, parameters=()):
        if self._postgres:
            statement = statement.replace("?", "%s")
        return self._connection.execute(statement, parameters)


@contextmanager
def database() -> Iterator[DatabaseConnection]:
    if DATABASE_URL:
        if not DATABASE_URL.startswith(("postgres://", "postgresql://")):
            raise RuntimeError("DATABASE_URL must be a PostgreSQL connection string")
        import psycopg
        from psycopg.rows import dict_row

        conn = psycopg.connect(
            DATABASE_URL,
            row_factory=dict_row,
            connect_timeout=10,
        )
        wrapped = DatabaseConnection(conn, postgres=True)
    else:
        path = Path(DB_PATH)
        path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(path, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        wrapped = DatabaseConnection(conn, postgres=False)

    try:
        yield wrapped
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def initialize_database() -> None:
    with database() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS servers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                protocol TEXT NOT NULL,
                country_code TEXT,
                country_name_fa TEXT,
                country_name_en TEXT,
                location_name_fa TEXT,
                location_name_en TEXT,
                location_verified INTEGER NOT NULL DEFAULT 0,
                enabled INTEGER NOT NULL DEFAULT 0,
                config TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        # Safe additive migration for databases created by earlier app versions.
        if conn._postgres:
            existing = {row["column_name"] for row in conn.execute(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_schema = current_schema() AND table_name = 'servers'"
            ).fetchall()}
        else:
            existing = {row["name"] for row in conn.execute("PRAGMA table_info(servers)").fetchall()}
        for column in ("location_name_fa", "location_name_en"):
            if column not in existing:
                conn.execute(f"ALTER TABLE servers ADD COLUMN {column} TEXT")


@app.on_event("startup")
def startup() -> None:
    check_runtime_secrets()
    initialize_database()


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
    if request.url.path == "/admin" or request.url.path.startswith("/api/v1/admin/") or request.url.path.endswith("/config"):
        response.headers["Cache-Control"] = "no-store"
    return response


class LoginPayload(BaseModel):
    username: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=1, max_length=512)


class ServerInput(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    protocol: str = Field(min_length=2, max_length=24)
    country_code: str | None = None
    country_name_fa: str | None = Field(default=None, max_length=80)
    country_name_en: str | None = Field(default=None, max_length=80)
    location_name_fa: str | None = Field(default=None, max_length=80)
    location_name_en: str | None = Field(default=None, max_length=80)
    location_verified: bool = False
    enabled: bool = False
    config: str = Field(min_length=1, max_length=200_000)

    @field_validator("name")
    @classmethod
    def name_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Name cannot be blank")
        return value

    @field_validator("protocol")
    @classmethod
    def protocol_supported(cls, value: str) -> str:
        normalized = value.strip().upper()
        if normalized not in SUPPORTED_PROTOCOLS:
            raise ValueError("Unsupported protocol")
        return normalized

    @field_validator("country_code")
    @classmethod
    def country_code_format(cls, value: str | None) -> str | None:
        if value is None or value.strip() == "":
            return None
        value = value.strip().upper()
        if not COUNTRY_CODE.fullmatch(value):
            raise ValueError("Country code must be a two-letter ISO code")
        return value

    @field_validator("config")
    @classmethod
    def config_has_supported_syntax(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Configuration cannot be blank")
        if "://" in value:
            scheme = value.split("://", 1)[0].lower()
            known_schemes = {item for schemes in PROFILE_SCHEMES.values() for item in schemes}
            if scheme not in known_schemes:
                raise ValueError("Unsupported profile URI scheme")
        elif value.startswith("{"):
            try:
                parsed = json.loads(value)
            except json.JSONDecodeError as exc:
                raise ValueError("Profile JSON is malformed") from exc
            if not isinstance(parsed, dict):
                raise ValueError("Profile JSON must be an object")
        else:
            raise ValueError("Profile must be a supported protocol URI or JSON object")
        return value

    @model_validator(mode="after")
    def validate_profile_protocol_and_location(self):
        if "://" in self.config:
            scheme = self.config.split("://", 1)[0].lower()
            if scheme not in PROFILE_SCHEMES[self.protocol]:
                raise ValueError("Profile URI scheme does not match the selected protocol")
        if self.location_verified and (not self.country_code or not (self.country_name_fa or self.country_name_en)):
            raise ValueError("Verified location requires a country code and at least one country name")
        return self


def admin_claims(authorization: str | None = Header(default=None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Admin authentication required")
    token = authorization[7:].strip()
    try:
        claims = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER,
            options={"require_iss": True, "require_sub": True, "require_exp": True, "require_iat": True},
        )
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
    if claims.get("sub") != ADMIN_USERNAME or claims.get("scope") != "admin":
        raise HTTPException(status_code=403, detail="Insufficient privileges")
    return claims


def public_server(row: Mapping[str, Any]) -> dict:
    location_valid = bool(row["location_verified"])
    return {
        "id": row["id"],
        "name": row["name"],
        "protocol": row["protocol"],
        "country_code": row["country_code"] if location_valid else None,
        "country_name_fa": row["country_name_fa"] if location_valid else None,
        "country_name_en": row["country_name_en"] if location_valid else None,
        "location_name_fa": row["location_name_fa"] if location_valid else None,
        "location_name_en": row["location_name_en"] if location_valid else None,
        "location_verified": location_valid,
    }


def admin_server(row: Mapping[str, Any]) -> dict:
    result = public_server(row)
    result.update({"enabled": bool(row["enabled"]), "updated_at": row["updated_at"]})
    return result


def login_is_limited(key: str) -> bool:
    now = time.monotonic()
    attempts = [t for t in _login_attempts.get(key, []) if now - t < 300]
    _login_attempts[key] = attempts
    return len(attempts) >= 8


@app.get("/health")
def health() -> dict:
    # Liveness only; it deliberately does not claim that a VPN server is reachable.
    return {"status": "ok"}


@app.get("/ready")
def readiness() -> dict:
    # Readiness includes a live database round-trip for hosted deployments.
    try:
        with database() as conn:
            conn.execute("SELECT 1").fetchone()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable",
        ) from exc
    return {"status": "ready"}


@app.post("/api/v1/admin/login")
def login(payload: LoginPayload, request: Request) -> dict:
    # Do not trust X-Forwarded-For here. Configure trusted-proxy rate limiting at the edge.
    key = request.client.host if request.client else "unknown"
    if login_is_limited(key):
        raise HTTPException(status_code=429, detail="Too many login attempts")
    valid = hmac.compare_digest(payload.username, ADMIN_USERNAME) and hmac.compare_digest(
        payload.password, ADMIN_PASSWORD
    )
    if not valid:
        _login_attempts.setdefault(key, []).append(time.monotonic())
        raise HTTPException(status_code=401, detail="Invalid credentials")
    _login_attempts.pop(key, None)
    now = datetime.now(timezone.utc)
    expiry = now + timedelta(minutes=TOKEN_TTL_MINUTES)
    token = jwt.encode(
        {"sub": ADMIN_USERNAME, "scope": "admin", "iat": now, "exp": expiry, "iss": TOKEN_ISSUER, "jti": secrets.token_urlsafe(16)},
        JWT_SECRET,
        algorithm=ALGORITHM,
    )
    return {"access_token": token, "token_type": "bearer", "expires_in": TOKEN_TTL_MINUTES * 60}


@app.get("/api/v1/servers")
def list_servers() -> dict:
    with database() as conn:
        rows = conn.execute("SELECT * FROM servers WHERE enabled = 1 ORDER BY name").fetchall()
    return {"servers": [public_server(row) for row in rows]}



@app.get("/api/v1/admin/servers")
def admin_list_servers(_: dict = Depends(admin_claims)) -> dict:
    with database() as conn:
        rows = conn.execute("SELECT * FROM servers ORDER BY updated_at DESC").fetchall()
    return {"servers": [admin_server(row) for row in rows]}


@app.post("/api/v1/admin/servers", status_code=status.HTTP_201_CREATED)
def create_server(payload: ServerInput, _: dict = Depends(admin_claims)) -> dict:
    server_id = secrets.token_urlsafe(12)
    with database() as conn:
        conn.execute("""INSERT INTO servers
            (id, name, protocol, country_code, country_name_fa, country_name_en,
             location_name_fa, location_name_en, location_verified, enabled, config, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (server_id, payload.name, payload.protocol, payload.country_code,
             payload.country_name_fa, payload.country_name_en, payload.location_name_fa,
             payload.location_name_en, int(payload.location_verified), int(payload.enabled),
             payload.config, utc_now()))
        row = conn.execute("SELECT * FROM servers WHERE id = ?", (server_id,)).fetchone()
    return admin_server(row)


@app.get("/api/v1/admin/servers/{server_id}")
def admin_get_server(server_id: str, _: dict = Depends(admin_claims)) -> dict:
    with database() as conn:
        row = conn.execute("SELECT * FROM servers WHERE id = ?", (server_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Server not found")
    result = admin_server(row)
    result["config"] = row["config"]
    return result


@app.put("/api/v1/admin/servers/{server_id}")
def update_server(server_id: str, payload: ServerInput, _: dict = Depends(admin_claims)) -> dict:
    with database() as conn:
        cursor = conn.execute("""UPDATE servers SET name = ?, protocol = ?, country_code = ?,
            country_name_fa = ?, country_name_en = ?, location_name_fa = ?, location_name_en = ?,
            location_verified = ?, enabled = ?, config = ?, updated_at = ? WHERE id = ?""",
            (payload.name, payload.protocol, payload.country_code, payload.country_name_fa,
             payload.country_name_en, payload.location_name_fa, payload.location_name_en,
             int(payload.location_verified), int(payload.enabled), payload.config, utc_now(), server_id))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Server not found")
        row = conn.execute("SELECT * FROM servers WHERE id = ?", (server_id,)).fetchone()
    return admin_server(row)


@app.delete("/api/v1/admin/servers/{server_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_server(server_id: str, _: dict = Depends(admin_claims)) -> Response:
    with database() as conn:
        cursor = conn.execute("DELETE FROM servers WHERE id = ?", (server_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Server not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/admin", include_in_schema=False)
def admin_page() -> FileResponse:
    return FileResponse(APP_DIR / "admin.html", headers={"Cache-Control": "no-store"})
install_profile_delivery(
    app,
    database=database,
    admin_claims=admin_claims,
    jwt_secret=JWT_SECRET,
    issuer=TOKEN_ISSUER,
    algorithm=ALGORITHM,
)
