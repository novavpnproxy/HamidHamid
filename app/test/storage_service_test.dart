import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nova_vpn_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('favorite servers can be added and removed', () async {
    final storage = StorageService();

    expect(await storage.readFavoriteServerIds(), isEmpty);
    expect(await storage.toggleFavoriteServer('server-a'), isTrue);
    expect(await storage.readFavoriteServerIds(), ['server-a']);
    expect(await storage.toggleFavoriteServer('server-a'), isFalse);
    expect(await storage.readFavoriteServerIds(), isEmpty);
  });

  test('recent servers are unique, newest first, and bounded to twenty', () async {
    final storage = StorageService();

    for (var index = 0; index < 22; index++) {
      await storage.recordRecentServer('server-$index');
    }
    await storage.recordRecentServer('server-5');

    final recent = await storage.readRecentServerIds();
    expect(recent, hasLength(20));
    expect(recent.first, 'server-5');
    expect(recent.toSet(), hasLength(20));
    expect(recent, isNot(contains('server-0')));
  });
}
