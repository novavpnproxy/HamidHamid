# Architecture and release gates

## Data flow

1. The owner uses the separate `/admin` site and authenticated admin API to add, change, disable, or remove server records.
2. The Android app requests active display metadata from `GET /api/v1/servers`. Configurations are not part of this response.
3. On connection, the app registers the device when needed, requests the selected server profile over HTTPS, and keeps the profile transient in memory.
4. The Android app passes the profile to the pinned `flutter_v2ray_client` engine. The native Xray core receives the Android `VpnService` TUN file descriptor.
5. The engine's native status stream—not a successful API request—is the source of the UI's connected/disconnected state.

## Current implementation status

- Android uses `flutter_v2ray_client` 3.5.0 from the pinned Git commit `138faaddc216ef2b2960a0acd265151f065234e3`.
- The plugin uses the Xray core and its native TUN inbound for Android VPN mode.
- The backend is FastAPI; local development uses SQLite and hosted deployments use managed PostgreSQL through DATABASE_URL. No production database or public HTTPS deployment is configured yet.
- The server database is empty until the owner adds verified, working server profiles through the admin API.
- A native `CONNECTED` event confirms that the core started; it does **not** prove that user traffic reaches the internet or that throughput is acceptable.
- No owner-provided profile has yet passed an end-to-end Android traffic and throughput check. No production APK has been accepted as release-ready.

## Production gates

- Validate real traffic with owner-provided profiles on a physical Android device, including DNS, IPv4/IPv6 behavior, upload/download throughput, latency, and stability.
- Compare representative server profiles and transports before deciding whether to retain Xray or migrate to another core. Do not infer performance from a logo, protocol label, or CONNECTED state.
- Deploy the FastAPI control plane behind HTTPS with persistent database storage, backups, migrations, rotated secrets, and protected admin access.
- Verify device approval and protected profile delivery under production hosting.
- Complete security and privacy review, publish a privacy policy, and only then consider advertising SDKs.


### Native engine security gate — 2026-11-25

The pinned Xray plugin fork now includes a fail-closed socket-protection helper. Missing listener, invalid FD, callback exception, and Android protect rejection all return failure. JUnit tests were added but have not yet been run in CI. A native CONNECTED event still only confirms core startup; it is not a verified data-plane connection. The app must not claim internet connectivity until physical-device TCP/DNS/UDP and IP-leak tests pass. Candidate routing/IPv6 behavior and native AAR provenance remain open gates.
