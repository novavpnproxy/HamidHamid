# NOVA VPN build and engine progress log

Last updated: 2026-11-24

## Scope

Active implementation repository: `mynovavpnproxy1/HamidHamid`, branch `main`.
This log records verified repository changes and test evidence. A GitHub commit is not proof of a successful APK or VPN traffic.

## Five-stage execution plan

| Stage | Scope | Status |
|---|---|---|
| 1 | Audit engine integration, Android project configuration, and build pipeline | Complete (repository-level) |
| 2 | Fix source/dependency/Android integration issues found by audit | Complete for the current CI baseline; analyzer and Flutter tests pass |
| 3 | Produce a debug APK through CI and retain the artifact | Complete; CI artifact downloaded and APK archive integrity verified |
| 4 | Test a valid owner-supplied profile on a physical Android device (TCP, DNS, IPv4/IPv6, UDP, upload/download) | Blocked until APK and authorized working profile/device test |
| 5 | Review stability, security, performance evidence, then determine release readiness | Not started |

## Verified findings on 2026-11-24

- The app pins `flutter_v2ray_client` 3.5.0 to Git commit `138faaddc216ef2b2960a0acd265151f065234e3`.
- The selected plugin uses Xray native TUN on Android. This is the existing engine integration; this work is not a claim that a new independent engine has been implemented.
- The repository does not commit an Android Gradle project. The CI workflow generates Android platform files using `flutter create` before dependency resolution/build.
- Latest prior CI run #88 (run ID `45160753236`, commit `e295639731eeffda37ca57224a1de4e1dc648157`) passed backend tests but failed Flutter analysis. Flutter tests and APK build were skipped.
- The prior analyzer errors were:
  - `const_with_non_const` at `app/lib/screens/splash_screen.dart:76` because `Image.asset` was nested in a const Column.
  - `undefined_identifier` for `Image` in `app/test/widget_test.dart`, caused by the missing direct Flutter SDK dependency in `app/pubspec.yaml`.
- Applied changes:
  - Commit `41c30924484b6e36ce6b1a9df7d43c61b4044ff6`: added `flutter: sdk: flutter` to app dependencies.
  - Commit `0f1899cf8e1d252f70246c3799c6256591266ea9`: removed the invalid const from the splash Column.
- Both edited files were fetched again from `main` and their new blob SHAs verified:
  - `app/pubspec.yaml`: `3e2d03098eec1e75259b0bbbc73aa19438159bf3`
  - `app/lib/screens/splash_screen.dart`: `ef00896fbda5a1a3e51f49e1e1c397cea73b611e`
- CI run #90 (run ID `45413283642`, commit `0f1899cf8e1d252f70246c3799c6256591266ea9`) completed: backend tests passed; Flutter formatting passed; Flutter analysis failed on one remaining error: `Image` was referenced in `app/test/widget_test.dart` without importing `package:flutter/material.dart`. Flutter tests and APK build were skipped.
- Fixed the remaining test import in commit `e8159305b88be8d24c41e8bf159f861c8304ca80`; resulting blob SHA for `app/test/widget_test.dart` is `b4a05b469e46d6164d441e4060fac317f0bb8442`.
- CI run #91 (run ID `45416056741`, commit `e8159305b88be8d24c41e8bf159f861c8304ca80`) completed with `success`. Both jobs passed. The Flutter job passed dependency resolution, Dart formatting, Flutter analysis, Flutter tests, Android debug APK build, and artifact upload; the backend tests job also passed.
- Artifact `nova-vpn-debug-apk` (artifact ID `14931878171`) was downloaded. ZIP size: `125,958,438` bytes; GitHub artifact digest: `sha256:b2fcfd1b55faec98734abed67e85b2dbf8124814e8a06ebcaef96f1ad6b64f52`. ZIP integrity test passed and contains `app-debug.apk` (276,391,896 bytes). Extracted APK SHA-256: `57bb1c1e63a46dc25e52bf0a3de7f7097f060a45b9a86b90eab01e5ee1273353`.
- This is a debug APK, not a release build. Its large size is consistent with debug Flutter assets and multiple ABI libraries; size optimization is a separate later task.

## JumpJump visual reference audit — 2026-11-24

- Reviewed both Library recordings end-to-end by extracting and inspecting frames at one-second intervals: `screen-۲۰۲۶۱۱۱۵-۱۱۰۰۱۲.mp4` (720x1612, 111.756944s; 112 sampled frames) and `screen-۲۰۲۶۱۱۱۱-۱۶۲۰۰۹.mp4` (720x1612, 53.540800s; 54 sampled frames). Also inspected the five individual screen captures `chart-1(1).png`–`chart-5(1).png`.
- Reviewed the timestamped extracted screenshots and individual screen captures, including the main/disconnected screen, connecting globe/progress state, country/location picker, expanded city/server rows, connected state with IP/rates/timer, settings, account prompt, and ad interruptions.
- Excluded NOVA logo/mockup/splash assets `1000143671.png`, `1000143673.png`, `1000279624*.png`, and `1000313396.png` from JumpJump reference evidence. The Library Favorites collection is not to be mixed with JumpJump screenshots. The in-app JumpJump location selector's own `مورد علاقه` tab is a real visible feature and must be treated separately.
- Reference observations and a detailed screen-to-code mapping are saved in the Library file `/NOVA_JUMPJUMP_REFERENCE_AUDIT.md`.
- Current NOVA UI mismatch confirmed in `app/lib/screens/home_screen.dart`, `app/lib/screens/server_list_screen.dart`, and `app/lib/screens/settings_screen.dart`: home hierarchy/control shape differs; location picker lacks the three tabs and inline expanded server rows/favorites/recent; settings are still minimal.
- JumpJump decompiled source confirms Flutter: its `MainActivity.smali` extends `FlutterActivity`; `lib/arm64-v8a/libapp.so` contains compiled AOT app code. Original editable Dart widget source is not present in the decompiled repository, so NOVA's Dart UI must be reconstructed from the recording/screenshots, not copied from smali.
- JumpJump Flutter assets include its own logo/status/server/VIP/empty-state artwork and Lottie loading/network assets. These are reference evidence only; do not copy JumpJump branding or third-party ad creatives into NOVA.
- No NOVA UI code was changed as part of this reference audit. Next: map the observed UI into NOVA widgets while preserving current VPN service, API, storage, and failover logic; verify actual functionality before presenting any control as working.

## JumpJump-informed UI implementation — feature branch

Working branch: `ui/jumpjump-reference` (kept separate from `main` pending validation).

Verified code changes:
- `f9f85e4ecbeb0c3955f2c165e121bfbe90652ae1`: persist favorite server IDs and a bounded, newest-first recent-server list.
- `6fb59a534bde7119745866115fe304f68744b4e6`: rebuild the location picker with Locations/Favorites/Recent tabs, expandable countries, individual server rows and favorite controls.
- `8b8cd812cc061c2c981f1f44a5c6b312ae5c2b37`: fix server-row title fallback.
- `37816c08c9eb80ab657d99cb66047843bb35b2e5`: rebuild home layout with a horizontal power capsule, server-selection overlay, ad-slot placeholder, connected metrics and a distinct connection-progress view.
- `95691bdb61157ca24ac84bcbceabdfc0497c0e8b`: add connection-cancel handling and remove unused helpers.
- `ff416dd6085db346c1bfa24f91add2a5c9e0ab64`: retain displayed upload/download byte totals.
- `1d09bcd865edf054d1c369f9e482ba7099c6b64`: restyle settings; unfinished capabilities are visibly marked as unavailable/coming soon rather than presented as working.
- `1c5af90e5485526b4b0b641b8e3d52bf088e98e8`: add persistence tests for favorite add/remove and recent ordering/limit.

Engine boundary: no changes were made to `VpnService`, `flutter_v2ray_client`, Xray TUN integration, API profile delivery, or failover logic.

CI evidence:
- Run #96 (`45441014948`) failed only at analysis because the new layout stopped displaying `_uploadedBytes` and `_downloadedBytes`; the exact warning lines were inspected.
- Run #97 (`45441605606`) and run #98 (`45441975162`) were cancelled by the workflow's cancel-in-progress policy when newer commits arrived; they are not test failures.
- Run #99 (`45442033543`) targets commit `1c5af90e5485526b4b0b641b8e3d52bf088e98e8`. Dart formatting and analyzer have passed; Flutter tests have passed; backend tests have passed. Android debug APK build and upload were still in progress at the time of this update.
- The prior successful baseline APK remains run #91; it does not include this feature-branch UI.

Implementation limitations:
- The ad area is only a placeholder; no ad SDK/provider is integrated.
- Premium/account flows, network mode, split tunneling, reset and network diagnosis are not implemented. Settings rows are marked unavailable rather than made into inert controls.
- VIP markers are not shown because the current server API/model has no verified VIP field.
- No public IP is shown because no verified public-IP source is exposed in the current client.
- Favorites and Recent storage are implemented, but exact reference-app tab contents/empty states were not established by the video.
- No physical-device install or live tunnel traffic test has been performed.

## Explicitly not verified

- A successful CI debug APK artifact has been downloaded and verified for archive integrity. It has not yet been installed or tested on a physical device.
- No live VPN tunnel has been tested with an owner-authorized working profile.
- A native `CONNECTED` callback is not proof of internet traffic.
- No speed, latency, packet-loss, DNS, IPv6, or battery-performance claim is made.
- No production backend URL/profile has been supplied and verified as live in this log.
- Exact contents/empty states of JumpJump's Favorites and Recent tabs and exact ad timing/trigger conditions have not yet been established.

## Next actions

1. Begin the JumpJump-informed UI implementation on a separate feature branch, starting with the home screen hierarchy and location selector.
2. Preserve `VpnService`, `ApiService`, storage, connection failover, and current Xray TUN integration unless a separately verified defect requires a change.
3. Add Favorites/Recent persistence only with explicit, testable behavior; do not invent the unseen contents of the reference app's Favorites/Recent tabs.
4. Run CI after each coherent UI milestone and verify the artifact before claiming a build.
5. Install the debug APK on an Android device and test with an authorized working profile; verify TCP, DNS, IPv4/IPv6, UDP, upload/download, and disconnect behavior.
6. Record measured results and only then assess release readiness.


## User-requested visual refinements — 2026-11-24

The user's two current NOVA screenshots were reviewed against the previously audited JumpJump reference media in Library:
- Primary reference recording: `screen-۲۰۲۶۱۱۱۵-۱۱۰۰۱۲.mp4` (111.76 seconds).
- Supplemental recording: `screen-۲۰۲۶۱۱۱۱-۱۶۲۰۰۹.mp4` (53.54 seconds).
- Reference evidence includes the country/location selector, expanded server rows with outlined/selected stars, Favorites/Recent tabs, the animated connection state, and the branded home layout. JumpJump branding and third-party ad creatives remain excluded.

Committed changes on `ui/jumpjump-reference`:
- `1ed312dc18843ea83a5126d2a681610e4b4bcc6e`: make the country/location picker more dimensional with thicker blue borders, gradient cards, expanded-state glow, clearer server counts and an explicit Persian instruction explaining the star.
- `54cdf2b6f06342cf51f169321a79ca56ec8ce982`: increase contrast of the inactive server favorite star so it is visible before selection.
- The server-row star and cross-country Favorites tab were already implemented and persist server IDs through `StorageService`; tapping the star adds/removes that exact server ID, and the Favorites list resolves those IDs against the fetched server list. No separate favorite data model was introduced.
- `e8dbf1db61cafb54c7811770ff76115dbe7cd24e`: add a gentle repeating blue halo animation to NOVA's home connection control to reduce the static appearance. Connection behavior is unchanged.
- `b9c435676f4a5df86038b8669b216025c5177c29` and `828cc8d9fbf349a728def1b7ba07167b4d54f739`: configure Android launcher icon generation from NOVA's existing `assets/brand/nova_logo_dark.jpg`, using a dark navy adaptive-icon background. The CI workflow now runs `dart run flutter_launcher_icons` before formatting/analyzing/building.

Validation status for these latest visual refinements:
- CI has not yet been polled for the commits above; do not call the refinements build-verified until the new workflow finishes.
- Run #99 (`45442033543`) did finish successfully and uploaded artifact `nova-vpn-debug-apk`, ID `14944906406`, for commit `1c5af90e5485526b4b0b641b8e3d52bf088e98e8`. This artifact predates the current visual refinements and launcher-icon generation change.
- The user's supplied screenshots show the currently installed APK appearance; they are not evidence that the latest commits have been installed.

- `0f2f3502f7d09d8df5233e3231ae0f2058f9debf`: align the home header with the NOVA identity by displaying the existing NOVA logo asset and a bilingual privacy/speed/security tagline; shift the home background to the navy palette. No JumpJump brand artwork was copied.

## Follow-up review and visual refinements — 2026-11-27

- Re-opened the two Library JumpJump recordings for a fresh visual review: primary `screen-۲۰۲۶۱۱۱۵-۱۱۰۰۱۲.mp4` (111.76 s) and supplemental `screen-۲۰۲۶۱۱۱۱-۱۶۲۰۰۹.mp4` (53.54 s). The connecting state uses a rotating dotted globe with the reference app wordmark centered, changing connection text/progress, and a bottom stay-on-page prompt.
- Compared the reference with the current feature-branch implementation. NOVA already has a separate branded connection screen, cancel control, dynamic selected location, attempt progress, and a stay-on-page prompt. Its prior orbit-ring graphic was visually unlike the dotted globe in the reference.
- Updated `app/lib/widgets/nova_animations.dart` in commit `4a61a5a64bad843b884bc024cbc37e13ccef51e4`: replaced the three orbital rings/core with a rotating 3D field of luminous dots and an independently branded NOVA wordmark. The NOVA name and blue/cyan/purple palette remain; no JumpJump branding or ad artwork was copied.
- Updated `app/lib/screens/home_screen.dart` in commit `8c38642492ceeeb9a3c76afc67ddeac3beb4b8da`: increased the visible auto-disconnect countdown font from 15 to 18, a modest size increase. The actual timeout remains two hours; timer start/reset/expiry logic was not changed.
- Re-fetched both edited files from `ui/jumpjump-reference` `main` was not modified. The new animation and timer font values were confirmed in GitHub responses.
- Branding review: `JEYRAN GROUP` is correctly spelled and remains on the splash screen as previously requested; it is not intended as a Home footer. No unrelated footer/date text was added.
- Existing behavior review: the connection screen still uses real engine status, selected server, failover attempt count, and cancellation; the countdown still starts on `CONNECTED` and resets on `DISCONNECTED`. The countdown is in-process and is not a persistent background timer if Android kills the app.
- Validation limitation: no Flutter analyzer, widget tests, APK build, or physical-device test was run for these two commits in this session. Do not describe the new animation as compile-verified or device-tested until a supported build environment runs those checks. GitHub Actions quota is not assumed available.


## 2026-11-27 — Nova UI refinement and verified Android build

- Rebased the working implementation on the current mainline engine/backend behavior rather than replacing the working Vox integration with the older UI branch. Preserved the Vox client, Vox-backed profile delivery, Render environment configuration, API tests, and the engine's active data-plane verification.
- Kept the existing connection engine and fallback path. Auto failover treats only HTTP 401/403/429 and VPN permission failures as fatal; server-specific errors continue to the next candidate.
- Updated disconnect handling to issue repeated native stop requests and wait for a fresh DISCONNECTED status, with a 15-second timeout, instead of treating a stale UI state as a completed disconnect.
- Updated the connection UI: four rotating cyan/blue/violet/magenta neon rings around the NOVA core; a minimum three-second connecting transition that remains visible until connection finishes; a wider, shorter horizontal power control; and a larger countdown shown as MM:SS from 120:00 to 00:00.
- Updated the splash to four seconds and retained the exact dedication text JEYRAN GROUP. Settings contact remains mynovavpnproxy@gmail.com. Favorites/Recent server selection remains enabled.
- Changed the V2Ray plugin dependency to the public fork at https://github.com/khadamatvanezafatejeyran-bot/flutter_v2ray_client.git, pinned to 138faaddc216ef2b2960a0acd265151f065234e3, so CI can resolve it without private-repository credentials.
- Fixed the particle-splash widget test to assert the NOVA particle logo and branding, and corrected the missing closing brace in app/lib/app.dart.
- Automated validation passed on workflow run 45940131730: backend pytest, Dart formatting, Flutter analyzer, Flutter tests, and Android debug APK build.
- Optimized release-mode build passed on workflow run 45941067703. Artifact: nova-vpn-arm64-release-apk (artifact ID 15173381096). Extracted APK size: 135,618,009 bytes; SHA-256: 87fe617e7da3a9c3a52593e2a1bccf5ed9646f5f414ff399175ac2ec54c62f5c.
- Source branch: novavpnproxy/HamidHamid:restore/nova-working-source. Pull request #1 is open; main remains unchanged. Do not merge until the new APK is installed and the actual VPN connection, Auto fallback, and one-tap disconnect are verified on-device.
