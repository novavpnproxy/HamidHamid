import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _serverKey = 'nova.selected_server';
  static const _languageKey = 'nova.language';
  static const _lightThemeKey = 'nova.light_theme';
  static const _favoriteServersKey = 'nova.favorite_servers';
  static const _recentServersKey = 'nova.recent_servers';
  static const _tunnelAppsKey = 'nova.tunnel_apps';

  Future<String?> readServerId() async =>
      (await SharedPreferences.getInstance()).getString(_serverKey);

  Future<void> writeServerId(String id) async =>
      (await SharedPreferences.getInstance()).setString(_serverKey, id);

  Future<String> readLanguage() async =>
      (await SharedPreferences.getInstance()).getString(_languageKey) ?? 'fa';

  Future<void> writeLanguage(String language) async =>
      (await SharedPreferences.getInstance()).setString(_languageKey, language);

  Future<bool> readLightTheme() async =>
      (await SharedPreferences.getInstance()).getBool(_lightThemeKey) ?? false;

  Future<void> writeLightTheme(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_lightThemeKey, enabled);

  Future<List<String>> readFavoriteServerIds() async =>
      (await SharedPreferences.getInstance())
          .getStringList(_favoriteServersKey) ?? <String>[];

  Future<List<String>> readTunnelApps() async =>
      (await SharedPreferences.getInstance()).getStringList(_tunnelAppsKey) ?? <String>[];

  Future<void> writeTunnelApps(List<String> packageNames) async =>
      (await SharedPreferences.getInstance()).setStringList(_tunnelAppsKey, packageNames.toSet().toList());

  Future<List<String>> readRecentServerIds() async =>
      (await SharedPreferences.getInstance())
          .getStringList(_recentServersKey) ?? <String>[];

  Future<bool> toggleFavoriteServer(String serverId) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(_favoriteServersKey) ?? <String>[];
    final isFavorite = ids.contains(serverId);
    if (isFavorite) {
      ids.remove(serverId);
    } else {
      ids.insert(0, serverId);
    }
    await preferences.setStringList(_favoriteServersKey, ids);
    return !isFavorite;
  }

  Future<void> recordRecentServer(String serverId) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(_recentServersKey) ?? <String>[];
    ids.remove(serverId);
    ids.insert(0, serverId);
    if (ids.length > 20) ids.removeRange(20, ids.length);
    await preferences.setStringList(_recentServersKey, ids);
  }
}
