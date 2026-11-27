#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"
LOG="$ROOT/NOVA-BUILD.log"

exec > >(tee "$LOG") 2>&1

echo "=== NOVA VPN Android build started ==="
date -u
cd "$APP_DIR"

if [ ! -d android ]; then
  echo "Generating Android platform files..."
  flutter create --platforms=android --org=com.novavpn --project-name=app --no-pub .
fi

echo "Accepting Android SDK licenses..."
yes | sdkmanager --licenses >/dev/null || true
yes | flutter doctor --android-licenses >/dev/null || true

echo "Resolving Flutter packages..."
flutter pub get

echo "Generating launcher icons..."
dart run flutter_launcher_icons

echo "Building debug APK..."
flutter build apk --debug --dart-define=API_BASE_URL=https://nova-vpn-clinet-db.onrender.com

APK="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
test -s "$APK"
cp "$APK" "$ROOT/NOVA-VPN-debug.apk"

echo "=== BUILD SUCCESS ==="
ls -lh "$ROOT/NOVA-VPN-debug.apk"
