# Backend

FastAPI API plus a separate authenticated owner dashboard at `/admin`. The database begins empty: no sample or presumed-working VPN servers are inserted. The currently pinned Android engine is Xray-based and accepts VLESS, VMess, Trojan, and Shadowsocks profiles; Hysteria, TUIC, and WireGuard profiles must not be added until a separately licensed Sing-box engine is integrated.

## Local run

Python 3.12 is recommended. From `backend/`:

```sh
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Set a unique administrator password (at least 16 characters) and a randomly generated `JWT_SECRET` (at least 32 random characters). For local development, leave `DATABASE_URL` empty to use SQLite. For hosted deployment, set `DATABASE_URL` to a managed PostgreSQL connection string; the service automatically uses PostgreSQL and creates the required tables at startup.

Run locally with `set -a; . ./.env; set +a; uvicorn app.main:app --reload`. Run backend tests with `pytest -q`.

## Free hosting blueprint

The repository root contains `render.yaml` for a free Render web service in Frankfurt. It expects these environment variables to be supplied privately in the Render dashboard:

- `DATABASE_URL`: a PostgreSQL connection string from a managed database such as Neon.
- `ADMIN_USERNAME`: a non-empty owner login.
- `ADMIN_PASSWORD`: a unique password of at least 16 characters.
- `JWT_SECRET`: at least 32 random characters.

Do not commit real credentials or put them in the Android application. Render free web services sleep after 15 minutes without inbound traffic, so the first request after sleep can be slow. The service gets a free `onrender.com` HTTPS address; no custom domain is required. Free services have resource and usage limits. See the official [Render free deployment guide](https://render.com/docs/free) and [Neon pricing](https://neon.com/pricing).

## API

- `GET /health` — liveness endpoint only; it does not verify VPN server reachability.
- `POST /api/v1/admin/login` — obtain a short-lived admin bearer token.
- `GET /api/v1/admin/servers` — authenticated list (no raw configurations).
- `POST /api/v1/admin/servers` — authenticated create.
- `GET /api/v1/admin/servers/{id}` — authenticated detail (includes raw configuration for owner editing).
- `PUT /api/v1/admin/servers/{id}` — authenticated update / configuration rotation.
- `DELETE /api/v1/admin/servers/{id}` — authenticated delete.
- `GET /api/v1/home-content` — active home-page ad configuration, manual ad records, and active announcement messages.
- `GET /api/v1/admin/home-content` — authenticated home-page advertising and announcement management data.
- `PUT /api/v1/admin/home-content/settings` — switch the home ad placement between manual ads and a supported ad network (currently Adsterra configuration fields are prepared).
- `POST/PUT/DELETE /api/v1/admin/home-content/ads[/{id}]` — manage an unlimited list of manually supplied HTTPS image ads and destination links.
- `POST/PUT/DELETE /api/v1/admin/home-content/announcements[/{id}]` — manage multiple messages for the rotating home-page announcement strip.
- `GET /api/v1/servers` — active server metadata only.
- `POST /api/v1/client/register` — register a device ID. New devices are saved as pending and receive HTTP 403 until approved.
- `GET /api/v1/admin/devices` — authenticated list of registered devices.
- `PUT /api/v1/admin/devices/{device_id}` — authenticated approve or revoke a device.
- `GET /api/v1/servers/{id}/config` — returns a profile only to a device holding a valid, short-lived client token and currently approved by the administrator. Missing/invalid tokens receive HTTP 401; unapproved devices receive HTTP 403. Responses are marked `no-store`.

Country metadata is shown to app clients only when the owner explicitly marks it verified. Protocol/profile format checks are syntactic and do not establish that a server is reachable or operational.

## Production blockers

Before public launch, add stronger abuse controls and rate limiting at the reverse proxy, database backups and migrations, monitoring without secret logging, and independent security review. Configure the app with the deployed HTTPS API URL using `--dart-define=API_BASE_URL=...`. Never embed administrator credentials or a shared API secret in the APK. A profile delivered to a device can be extracted from that device. Validate real traffic and throughput on physical Android devices before claiming the VPN is production-ready.
