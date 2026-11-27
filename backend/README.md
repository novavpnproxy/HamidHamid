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
- `GET /api/v1/servers` — active server metadata only.
- `POST /api/v1/client/register` — register a device ID. New devices are saved as pending and receive HTTP 403 until approved.
- `GET /api/v1/admin/devices` — authenticated list of registered devices.
- `PUT /api/v1/admin/devices/{device_id}` — authenticated approve or revoke a device.
- `GET /api/v1/servers/{id}/config` — returns a profile only to a device holding a valid, short-lived client token and currently approved by the administrator. Missing/invalid tokens receive HTTP 401; unapproved devices receive HTTP 403. Responses are marked `no-store`.

Country metadata is shown to app clients only when the owner explicitly marks it verified. Protocol/profile format checks are syntactic and do not establish that a server is reachable or operational.

## Vox partner integration

The backend exposes public location metadata at `GET /api/v1/vox/locations?protocol=vless` and an authenticated config route at `GET /api/v1/vox/config?location=de-frankfurt&protocol=vless`. The first request for a NOVA device creates its Vox user idempotently (`nova_<device_id>`); later config requests fetch a fresh profile from Vox. The Vox partner key is read only from `VOX_API_KEY` on the server and must never be included in the APK or logs. Configure it in the hosting provider's secret environment settings. This first integration intentionally exposes VLESS only because the currently pinned Android engine is Xray-based; WireGuard and AmneziaWG require a separately integrated Android engine before the app can consume those profiles.

- `GET /api/v1/vox/locations?protocol=vless` — public metadata list of VLESS-capable Vox locations (contains no credentials).
- `GET /api/v1/vox/config?location=<location-id>&protocol=vless` — authenticated fresh VLESS config for the calling NOVA installation; response is `no-store`.

Each distinct NOVA installation/device identity maps to one Vox trial account. Vox's trial limits still apply (10 simultaneous users, 20 total created, 2 devices per user, 10 GB per user, 100 GB total). The route has not yet been exercised against the live Vox account; configure the key and run an end-to-end test before enabling it in the app.

## Production blockers

Before public launch, add stronger abuse controls and rate limiting at the reverse proxy, database backups and migrations, monitoring without secret logging, and independent security review. Configure the app with the deployed HTTPS API URL using `--dart-define=API_BASE_URL=...`. Never embed administrator credentials or a shared API secret in the APK. A profile delivered to a device can be extracted from that device. Validate real traffic and throughput on physical Android devices before claiming the VPN is production-ready.
