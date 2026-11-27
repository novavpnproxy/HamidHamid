# Android engine integration status

The client depends on `flutter_v2ray_client` 3.5.0 and has an adapter that initializes the engine, requests Android VPN permission, starts/stops a tunnel, and listens to engine status callbacks. A native `CONNECTED` event is only a core-start signal; the UI remains in a verification state until an HTTPS data-plane probe succeeds.

The backend now supports device registration, administrator approval, and short-lived client tokens. On first connection, the app registers its device; an administrator must approve it in `/admin` before profile delivery. Missing or invalid tokens return 401 and unapproved devices return 403. The app then requests the profile just in time over HTTPS. No actual server/profile has been provided, and no device build or live tunnel test has been performed.

Before public launch, deploy the backend behind HTTPS, configure the app's `API_BASE_URL`, add rate limiting and abuse controls at the edge, and validate revocation and token expiry. Then test every profile against the selected engine with owner-provided infrastructure and Android devices. The plugin documents VLESS, VMess, Trojan, Shadowsocks, and Hysteria URL parsing; a protocol label in the admin panel alone does not guarantee profile compatibility.


## Supported protocol boundary

The pinned Android dependency is `flutter_v2ray_client` 3.5.0, which embeds Xray. The current server API therefore accepts only VLESS, VMess, Trojan, and Shadowsocks profile schemes. Hysteria/Hysteria2, TUIC, and WireGuard are not enabled in the current client path. A Sing-box migration is a separate decision: the inspected `flutter_singbox_client` Android plugin is GPL-3.0-only, so its copyleft obligations must be assessed before using it in an ad-supported distributable app. The current Xray plugin is MIT-licensed. Do not advertise or accept a protocol just because the backend can store its name.


## Native socket protection hardening — 2026-11-25

The owned `flutter_v2ray_client` fork was patched and pinned to commit `d50467c1510edf740cae80d4556e3c4512cd4354`. Its native socket protector now fails closed when the service listener is absent, the descriptor is invalid, the callback throws, or Android `protect(fd)` returns false. JUnit test source was added for these cases. The app dependency pin is updated in `app/pubspec.yaml`.

This patch does **not** prove successful tunnel traffic and does not fix the candidate's immediate CONNECTED state transition, bypass-subnet routing, or IPv6 sinkhole policy. The native AAR's exact source/build provenance and redistribution notices also remain unverified. Build and test results after the patch are pending.


## Native status and data-plane distinction

The plugin's `CONNECTED` callback is currently emitted after the native `startLoop()` call returns and the manager sets its internal state. It confirms native core startup, not end-to-end TUN traffic. The exposed server-delay method calls the core's outbound delay measurement; it is useful as a server-reachability signal but is not proof that arbitrary Android app packets traverse the TUN. A dedicated data-plane probe and physical-device traffic tests are still required.

## Native AAR license-chain review

The plugin repository has a top-level MIT license, but that does not settle the terms for the bundled native AAR. The upstream AndroidLibXrayLite source/API lineage declares LGPL-3.0 and its inspected dependency manifest references Xray-core, whose repository license is MPL-2.0. The exact AAR source commit/build provenance and complete dependency notices are not established in the candidate repository. Do not treat the native engine as cleared for redistribution in a closed-source/ad-supported APK until provenance is verified and LGPL/MPL obligations receive legal review.

## Integration state — 2026-11-25

The Xray plugin is already integrated at source level; it does not need to be copied into the app again. `app/pubspec.yaml` pins the owned fork at `89fdab138073333eb0eaf03ac2e16dbde874be1c`. `VpnService` owns initialization, permission, profile conversion, connect/disconnect, and native status stream; `HomeScreen` consumes that stream. CI generates the Android Gradle project under `app/android` when absent and now includes the plugin's JUnit test task before APK packaging.

The latest Gradle dependency-layout correction and app pin are committed, but no CI run after those commits has been verified. Do not claim the latest plugin compiles, its unit tests pass, or the APK builds until a successful workflow artifact is inspected. A native `CONNECTED` event remains only a core-start signal, not proof of tunneled internet traffic.

## Data-plane verification implementation — 2026-11-25

VpnService.connect() now waits for the native CONNECTED callback and then performs up to three HTTPS requests to api.ipify.org, validating the returned IPv4 address before the connection call returns successfully. Failure triggers a best-effort engine stop and returns a data-plane verification error. When an existing session is restored after app recreation, HomeScreen performs the same probe before showing Connected and stops the session if verification fails.

This is an initial IPv4/TCP-over-HTTPS reachability gate, not a complete leak or protocol test. It does not independently prove DNS privacy, IPv6 tunneling, UDP forwarding, kill-switch behavior, or long-term stability. It also has not yet been executed on a physical device with an authorized working profile.

## CI workflow hardening — 2026-11-25

The Android job runs from the app directory, resolves Flutter dependencies there, and generates app/android only when absent. The plugin package name is flutter_v2ray_client, matching the Gradle test task :flutter_v2ray_client:testDebugUnitTest. Formatting is checked without mutating source files and includes both lib and test; the Flutter test runner is skipped only if no Dart test files exist. The APK artifact path is relative to the repository workspace and points to app/build/app/outputs/flutter-apk/app-debug.apk.

Workflow commits f43291b3305183dc31391020f2a16a275cf32d76 and a2758b8a6fc9602c2dd4097c1f450a96d33f5eff are committed and the final workflow content was fetched again. GitHub Actions run status is not yet available through the current run lookup (which only returns pull-request-triggered runs); no build, JUnit, or APK success is claimed.

## Vox partner integration — 2026-11-25

- Added a server-side Vox API client in `backend/app/vox_client.py`; the partner key is read from the backend-only `VOX_API_KEY` environment variable and is never sent to the Android app.
- Added public VLESS location metadata at `GET /api/v1/vox/locations` and protected fresh profile delivery at `GET /api/v1/vox/config`. The config endpoint requires an approved NOVA device token and returns `Cache-Control: no-store`.
- Each NOVA installation identity maps to a deterministic Vox `external_id` (`nova_<device_id>`); Vox user creation is idempotent. The app now merges Vox VLESS locations into its server picker and fetches a fresh profile immediately before each connection attempt.
- This first phase exposes **VLESS + Reality only** because the currently pinned Android engine is Xray-based. WireGuard and AmneziaWG are not yet wired into the Android data plane and must not be advertised as working.
- The partner API key has not yet been configured in the hosting environment, and no live Vox user/config has been created or fetched. CI for the integration is pending; no build, real connection, or traffic-throughput result is claimed.
- Relevant commits in `HamidHamid`: backend client `952628a4609edaca73c5253e07e0a3f797650a3b`; route wiring `7b4708bf19af31d42b19e2091ab69bed44e47633`; app integration `698ff5a5bc3376477388e3dace4be8a08500db04`; latest app test `b7ff9bed96d61662bcbfa07bf548d3f47930f429`.
