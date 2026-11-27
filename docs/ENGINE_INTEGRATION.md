# Android engine integration status

The client now depends on `flutter_v2ray_client` 3.5.0 and has an adapter that initializes the engine, requests Android VPN permission, starts/stops a tunnel, and listens to engine status callbacks. The UI only enters the Connected state after receiving the plugin's `CONNECTED` event.

The backend now supports device registration, administrator approval, and short-lived client tokens. On first connection, the app registers its device; an administrator must approve it in `/admin` before profile delivery. Missing or invalid tokens return 401 and unapproved devices return 403. The app then requests the profile just in time over HTTPS. No actual server/profile has been provided, and no device build or live tunnel test has been performed.

Before public launch, deploy the backend behind HTTPS, configure the app's `API_BASE_URL`, add rate limiting and abuse controls at the edge, and validate revocation and token expiry. Then test every profile against the selected engine with owner-provided infrastructure and Android devices. The plugin documents VLESS, VMess, Trojan, Shadowsocks, and Hysteria URL parsing; a protocol label in the admin panel alone does not guarantee profile compatibility.


## Supported protocol boundary

The pinned Android dependency is `flutter_v2ray_client` 3.5.0, which embeds Xray. The current server API therefore accepts only VLESS, VMess, Trojan, and Shadowsocks profile schemes. Hysteria/Hysteria2, TUIC, and WireGuard are not enabled in the current client path. A Sing-box migration is a separate decision: the inspected `flutter_singbox_client` Android plugin is GPL-3.0-only, so its copyleft obligations must be assessed before using it in an ad-supported distributable app. The current Xray plugin is MIT-licensed. Do not advertise or accept a protocol just because the backend can store its name.
