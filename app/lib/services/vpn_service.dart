import 'dart:async';
import 'dart:convert';

import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// رابط اپ با موتور VPN اندروید.
/// موفقیت اتصال فقط پس از دریافت وضعیت واقعی CONNECTED اعلام می‌شود.
class VpnService {
  VpnService._() : _engine = V2ray(onStatusChanged: _publishStatus);

  static final VpnService instance = VpnService._();

  factory VpnService() => instance;

  static final StreamController<V2RayStatus> _statuses =
      StreamController<V2RayStatus>.broadcast();

  static bool _initialized = false;
  static Future<void>? _initializing;
  static V2RayStatus _latestStatus = V2RayStatus();

  final V2ray _engine;
  bool _attemptInProgress = false;

  
  // برای آزمایش می‌توان موقتاً hours: 2 را به minutes: 2 تغییر داد.
  static const Duration _sessionLimit = Duration(hours: 2);

  static Timer? _sessionTimer;
  static bool _sessionStarted = false;
  static int _sessionGeneration = 0;

  static void _cancelSessionTimer() {
    _sessionGeneration++;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionStarted = false;
  }

  static void _startSessionTimer() {
    // موتور ممکن است چندین بار CONNECTED بفرستد.
    // زمان اتصال نباید با هر پیام از ابتدا محاسبه شود.
    if (_sessionStarted) return;

    _sessionStarted = true;
    final generation = ++_sessionGeneration;

    _sessionTimer = Timer(_sessionLimit, () {
      unawaited(_stopExpiredSession(generation));
    });
  }

  static Future<void> _stopExpiredSession(int generation) async {
    if (generation != _sessionGeneration || !_sessionStarted) {
      return;
    }

    try {
      await instance._engine.stopV2Ray();

      // وضعیت رابط کاربری را خود موتور اعلام می‌کند.
      // اینجا وضعیت ساختگی DISCONNECTED ارسال نمی‌کنیم.
    } catch (_) {
      // توقف ممکن است موقتاً خطا بدهد.
      // فقط برای همین اتصال دوباره تلاش می‌کنیم.
    }

    if (generation != _sessionGeneration || !_sessionStarted) {
      return;
    }

    // اگر موتور هنوز قطع‌شدن را اعلام نکرد، دوباره درخواست قطع بده.
    _sessionTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_stopExpiredSession(generation));
    });
  }
    static void _publishStatus(V2RayStatus status) {
    _latestStatus = status;

    switch (status.state.toUpperCase()) {
      case 'CONNECTED':
        _startSessionTimer();
        break;

      case 'DISCONNECTED':
        _cancelSessionTimer();
        break;
    }

    if (!_statuses.isClosed) {
      _statuses.add(status);
    }
  }

  Stream<V2RayStatus> get statusChanges => _statuses.stream;

  V2RayStatus get currentStatus => _latestStatus;

  /// Measures HTTPS response latency through the active VPN tunnel.
  Future<int> getConnectedServerDelay() =>
      _engine.getConnectedServerDelay();

  Future<void> initialize() async {
    if (_initialized) return;

    final pending = _initializing;
    if (pending != null) {
      await pending;
      return;
    }

    final initialization = _engine.initialize(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    _initializing = initialization;

    try {
      await initialization;
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> connect({
    required String profile,
    required String remark,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (_attemptInProgress) {
      throw const VpnConnectionBusyException();
    }

    _attemptInProgress = true;
    _cancelSessionTimer();

    try {
      await initialize();
      
      if (!await _engine.requestPermission()) {
        throw const VpnPermissionException();
      }

      final config = _toEngineConfig(profile);
      final connected = Completer<void>();
      final connectedFuture = connected.future;

      // خطای احتمالی را از زمان ساخت Completer مدیریت می‌کنیم؛ سپس همان Future
      // را پایین‌تر await می‌کنیم تا خطای اتصال به caller برگردد.
      connectedFuture.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );

      var sawConnecting = false;
      final subscription = statusChanges.listen((status) {
        final state = status.state.toUpperCase();

        if (state == 'CONNECTING') {
          sawConnecting = true;
        }

        if (state == 'CONNECTED' && !connected.isCompleted) {
          connected.complete();
        } else if ((state == 'ERROR' ||
                (state == 'DISCONNECTED' && sawConnecting)) &&
            !connected.isCompleted) {
          connected.completeError(const VpnConnectionException());
        }
      });

      try {
        await _engine.startV2Ray(
          remark: remark,
          config: config,
          blockedApps: null,
          bypassSubnets: null,
          proxyOnly: false,
          notificationDisconnectButtonName: 'DISCONNECT',
        );

        await connectedFuture.timeout(timeout);
      } on TimeoutException {
        await _stopPreservingFailure();
        throw const VpnConnectionTimeoutException();
      } catch (_) {
        await _stopPreservingFailure();
        // جزئیات خطای بومی ممکن است حاوی دادهٔ حساس پروفایل باشند.
        throw const VpnConnectionException();
      } finally {
        await subscription.cancel();
      }
    } finally {
      _attemptInProgress = false;
    }
  }

  String _toEngineConfig(String profile) {
    final value = profile.trim();

    if (value.isEmpty) {
      throw const FormatException('VPN profile is empty.');
    }

    if (value.contains('://')) {
      return V2ray.parseFromURL(value).getFullConfiguration();
    }

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'VPN profile must be a JSON object or supported share link.',
      );
    }

    return value;
  }

  Future<void> _stopPreservingFailure() async {
    try {
      await _engine.stopV2Ray();
    } catch (_) {
      // خطای توقف نباید جای خطای اصلی اتصال را بگیرد.
    }
  }

  Future<void> disconnect({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await initialize();

    final stopped = Completer<void>();
    // Subscribe before requesting stop so a fast DISCONNECTED event is not lost.
    final subscription = statusChanges.listen((status) {
      if (status.state.toUpperCase() == 'DISCONNECTED' &&
          !stopped.isCompleted) {
        stopped.complete();
      }
    });

    final deadline = DateTime.now().add(timeout);
    try {
      // Always send a stop command. A stale DISCONNECTED callback must not
      // prevent the native service from receiving an explicit stop request.
      while (!stopped.isCompleted) {
        await _engine.stopV2Ray();

        // Do not trust _latestStatus here: it may be a stale DISCONNECTED
        // value from before this stop request. Only the listener above may
        // complete this operation after receiving a fresh engine event.

        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw const VpnDisconnectTimeoutException();
        }

        // Some native service transitions need a second stop request.
        // Retry without requiring another user tap, while retaining a hard
        // timeout and waiting for the engine's actual DISCONNECTED event.
        final wait = remaining < const Duration(seconds: 2)
            ? remaining
            : const Duration(seconds: 2);
        await Future.any<void>([
          stopped.future,
          Future<void>.delayed(wait),
        ]);
      }

      await stopped.future.timeout(
        deadline.difference(DateTime.now()).isNegative
            ? Duration.zero
            : deadline.difference(DateTime.now()),
      );
    } on TimeoutException {
      throw const VpnDisconnectTimeoutException();
    } finally {
      await subscription.cancel();
    }
  }
}

class VpnPermissionException implements Exception {
  const VpnPermissionException();
}

class VpnConnectionBusyException implements Exception {
  const VpnConnectionBusyException();
}

class VpnConnectionException implements Exception {
  const VpnConnectionException();
}

class VpnConnectionTimeoutException implements Exception {
  const VpnConnectionTimeoutException();
}

class VpnDisconnectTimeoutException implements Exception {
  const VpnDisconnectTimeoutException();
}
