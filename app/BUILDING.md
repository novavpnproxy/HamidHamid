# NOVA VPN Android build

The Android debug APK is built by the `NOVA VPN CI` workflow from this branch.

## Local build

From the `app` directory:

```bash
flutter pub get
dart run flutter_launcher_icons
dart format lib test
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://nova-vpn-db.onrender.com
```

The APK output is:

`build/app/outputs/flutter-apk/app-debug.apk`

## Runtime configuration

- `API_BASE_URL` must be the HTTPS backend URL.
- The VOX partner API key remains on the backend and must never be included in the Android application.
- VOX location metadata is public; fetching a private VLESS profile requires an approved device token.
- A successful Android build does not prove that a VPN tunnel carries traffic. Verify profile retrieval, engine connection, and real traffic separately.
