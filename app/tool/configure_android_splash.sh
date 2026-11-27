#!/usr/bin/env bash
set -euo pipefail

RES="android/app/src/main/res"
mkdir -p "$RES/drawable" "$RES/drawable-v21" "$RES/values" "$RES/values-night" "$RES/values-v31" "$RES/values-night-v31"

cat > "$RES/drawable/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#091321" />
        </shape>
    </item>
</layer-list>
XML
cp "$RES/drawable/launch_background.xml" "$RES/drawable-v21/launch_background.xml"

cat > "$RES/values/styles.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionModeOverlay">true</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">#091321</item>
    </style>
</resources>
XML

cat > "$RES/values-night/styles.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionModeOverlay">true</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#091321</item>
    </style>
</resources>
XML

for variant in values-v31 values-night-v31; do
  parent="@android:style/Theme.Material.Light.NoActionBar"
  if [[ "$variant" == "values-night-v31" ]]; then
    parent="@android:style/Theme.Material.NoActionBar"
  fi
  cat > "$RES/$variant/styles.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="$parent">
        <item name="android:windowSplashScreenBackground">#091321</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>
        <item name="android:windowSplashScreenAnimationDuration">0</item>
        <item name="android:windowBackground">#091321</item>
        <item name="android:windowNoTitle">true</item>
    </style>
    <style name="NormalTheme" parent="$parent">
        <item name="android:windowBackground">#091321</item>
    </style>
</resources>
XML
done

echo "NOVA native launch background configured."
