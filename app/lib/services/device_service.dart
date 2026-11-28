import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:stable_device_id/stable_device_id.dart';

import '../storage/secure_storage_service.dart';

class DeviceService {
  DeviceService({SecureStorageService? storage})
      : _storage = storage ?? const SecureStorageService();

  final SecureStorageService _storage;

  /// Stable app-scoped platform ID, hashed to the backend's 64-hex format.
  /// On Android this uses ANDROID_ID and survives ordinary app reinstalls.
  Future<String> getStableDeviceId() async {
    final platformId = await StableDeviceId.getId();
    return sha256.convert(utf8.encode('nova-vpn:$platformId')).toString();
  }

  Future<String> getOrCreateDeviceId() async {
    // Keep an existing legacy ID so current Vox external IDs do not change.
    final saved = await _storage.readDeviceId();
    if (saved != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(saved)) {
      return saved;
    }

    // New installations use the stable platform ID instead of a random
    // install-scoped UUID, so reinstalling does not create another Vox user.
    final id = await getStableDeviceId();
    await _storage.writeDeviceId(id);
    return id;
  }

  Future<void> clear() async {
    await _storage.clearDeviceId();
  }
}
