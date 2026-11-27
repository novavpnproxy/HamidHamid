import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/vpn_server.dart';
import '../services/api_service.dart';
import '../services/connection_failover.dart';
import '../services/app_localizations.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
import 'server_list_screen.dart';
import 'settings_screen.dart';
import '../widgets/nova_animations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ConnectionUi { disconnected, connecting, connected, disconnecting, error }

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final VpnService _vpn = VpnService();
  late final AnimationController _pulseController;

  StreamSubscription<V2RayStatus>? _statusSubscription;
  _ConnectionUi _connection = _ConnectionUi.disconnected;
  VpnServer? _activeServer;
  VpnServer? _preferredServer;
  String _language = 'fa';
  bool _lightTheme = false;
  Timer? _autoDisconnectTimer;
  int _autoDisconnectRemainingSeconds = 2 * 60 * 60;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _uploadedBytes = 0;
  int _downloadedBytes = 0;
  int? _pingMs;
  bool _pingAttempted = false;
  String? _message;
  bool _busy = false;
  bool _showConnectingPage = false;
  DateTime? _connectingStartedAt;
  bool _failoverRunning = false;
  bool _cancelRequested = false;
  bool _selectedFavorite = false;
  int _currentAttempt = 0;
  int _attemptCount = 0;
  bool _refreshing = false;
  bool? _internetAvailable;
  HomeContent? _homeContent;
  int _announcementIndex = 0;
  int _homeAdIndex = 0;
  Timer? _homeRotationTimer;

  bool get _fa => _language == 'fa' || _language == 'fa-AF';
  bool get _rtl => NovaLocalizations.isRtl(_language);
  String _t(String key) => NovaLocalizations.text(_language, key);
  bool get _connected => _connection == _ConnectionUi.connected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _storage.readLanguage().then((language) {
      if (mounted) setState(() => _language = language);
    });
    _storage.readLightTheme().then((enabled) {
      if (mounted) setState(() => _lightTheme = enabled);
    });
    _statusSubscription = _vpn.statusChanges.listen(_onEngineStatus);
    _onEngineStatus(_vpn.currentStatus);
    // Reattach to the native status stream after app/process recreation and
    // restore the last selected server before rendering the home screen.
    unawaited(_initializeHomeState());
    // Refresh server metadata and test real internet reachability on launch.
    unawaited(_refreshHome());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The native VPN service continues broadcasting status while the app is
      // in the background. Refresh the saved server metadata on return.
      unawaited(_restoreSavedServer());
    }
  }

  Future<void> _initializeHomeState() async {
    try {
      await _vpn.initialize();
    } catch (_) {
      // A transient engine initialization error must not hide the saved server.
    }
    await _restoreSavedServer();
  }

  Future<void> _restoreSavedServer() async {
    try {
      final savedId = await _storage.readServerId();
      if (savedId == null || savedId.isEmpty) return;
      final servers = await _api.fetchServers();
      VpnServer? savedServer;
      for (final server in servers) {
        if (server.id == savedId) {
          savedServer = server;
          break;
        }
      }
      if (!mounted || savedServer == null) return;
      final favorites = await _storage.readFavoriteServerIds();
      if (!mounted) return;
      setState(() {
        _preferredServer = savedServer;
        if (_connection == _ConnectionUi.connected) {
          _activeServer = savedServer;
        }
        _selectedFavorite = favorites.contains(savedId);
      });
    } catch (_) {
      // Keep the persisted selection in storage; retry on the next resume.
    }
  }

  Future<bool> _checkInternetReachability() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(Uri.https('www.gstatic.com', '/generate_204'))
          .timeout(const Duration(seconds: 6));
      request.followRedirects = false;
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      await response.drain<void>();
      return response.statusCode == HttpStatus.noContent ||
          response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _refreshHome() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      final results = await Future.wait<Object?>([
        _checkInternetReachability(),
        _api.fetchServers().then<Object?>((servers) => servers).catchError(
              (_) => null,
            ),
      ]);
      if (!mounted) return;
      final serverListAvailable = results[1] is List<VpnServer>;
      setState(() {
        // A successful API response is also proof of working internet access.
        _internetAvailable =
            (results[0] as bool) || serverListAvailable;
      });
      await _refreshHomeContent();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _refreshHomeContent() async {
    try {
      final content = await _api.fetchHomeContent();
      if (!mounted) return;
      setState(() {
        _homeContent = content;
        _announcementIndex = 0;
        _homeAdIndex = 0;
      });
      _homeRotationTimer?.cancel();
      if (content.announcements.length > 1 || content.ads.length > 1) {
        _homeRotationTimer = Timer.periodic(const Duration(seconds: 7), (_) {
          if (!mounted) return;
          setState(() {
            if (content.announcements.length > 1) {
              _announcementIndex = (_announcementIndex + 1) % content.announcements.length;
            }
            if (content.adMode == 'manual' && content.ads.length > 1) {
              _homeAdIndex = (_homeAdIndex + 1) % content.ads.length;
            }
          });
        });
      }
    } catch (_) {
      // Keep the current home content if the backend is temporarily unavailable.
    }
  }

  Widget _buildAnnouncementBar() {
    final items = _homeContent?.announcements ?? const <HomeAnnouncement>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final index = _announcementIndex % items.length;
    return Container(
      height: 28,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _lightTheme ? const Color(0xFFE3F1FF) : const Color(0xFF17263B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _lightTheme ? const Color(0xFF8CB9E7) : const Color(0xFF314A70)),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(items[index].message, key: ValueKey(items[index].id), maxLines: 1,
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(color: _lightTheme ? const Color(0xFF1265A0) : const Color(0xFF75D9F2), fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAdPlaceholder() => Container(
        height: 104,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _lightTheme ? const Color(0xFFE8F1FC) : const Color(0xFF141B29),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _lightTheme ? const Color(0xFFB9D0EB) : const Color(0xFF344A6B), width: 1.2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.campaign_rounded, color: const Color(0xFF69A0FF), size: 27),
          const SizedBox(height: 5),
          Text(_fa ? 'جایگاه تبلیغات بنری' : 'Banner advertisement',
              style: TextStyle(color: _lightTheme ? const Color(0xFF49688F) : const Color(0xFF9EAFCA), fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _buildHomeAdPlacement() {
    final content = _homeContent;
    if (content == null) return _buildAdPlaceholder();
    if (content.adMode == 'network') {
      final smartLink = (content.networkCode ?? '').trim();
      final smartLinkUri = Uri.tryParse(smartLink);
      final validSmartLink = smartLinkUri != null &&
          smartLinkUri.scheme == 'https' &&
          smartLinkUri.host.isNotEmpty;
      return SizedBox(
        height: 104,
        width: double.infinity,
        child: Material(
          color: _lightTheme ? const Color(0xFFFFFFFF) : const Color(0xFF14131A),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: validSmartLink
                ? () async {
                    await launchUrl(
                      smartLinkUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _lightTheme
                      ? const Color(0xFFD5E0EF)
                      : const Color(0xFF24232C),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.ads_click_rounded,
                    color: validSmartLink
                        ? const Color(0xFF69A0FF)
                        : const Color(0xFF777680),
                    size: 25,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    validSmartLink
                        ? (_fa ? 'مشاهده تبلیغ' : 'View advertisement')
                        : (_fa
                            ? 'لینک تبلیغ در پنل تنظیم نشده است'
                            : 'Ad link is not configured'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF777680),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (content.ads.isEmpty) return _buildAdPlaceholder();
    final ad = content.ads[_homeAdIndex % content.ads.length];
    return SizedBox(
      height: 104,
      width: double.infinity,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(ad.targetUrl), mode: LaunchMode.externalApplication),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(ad.imageUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF141D2B), alignment: Alignment.center,
                child: Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )),
            Positioned(left: 0, right: 0, bottom: 0,
              child: Container(color: const Color(0x99000000), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
          ]),
        ),
      ),
    );
  }

  Widget _buildInternetIndicator() {
    final available = _internetAvailable;
    final color = available == null
        ? const Color(0xFF8792A5)
        : available
            ? const Color(0xFF20C982)
            : const Color(0xFFE34C5B);
    final icon = available == null
        ? Icons.sync_rounded
        : available
            ? Icons.check_rounded
            : Icons.close_rounded;
    final label = available == null
        ? (_fa ? 'در حال بررسی اینترنت' : 'Checking internet')
        : available
            ? (_fa ? 'اینترنت در دسترس است' : 'Internet available')
            : (_fa ? 'اینترنت در دسترس نیست' : 'Internet unavailable');
    return Tooltip(
      message: label,
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .16),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }

  void _onEngineStatus(V2RayStatus status) {
    if (!mounted) return;
    setState(() {
      _uploadSpeed = status.uploadSpeed;
      _downloadSpeed = status.downloadSpeed;
      _uploadedBytes = status.upload;
      _downloadedBytes = status.download;
      switch (status.state.toUpperCase()) {
        case 'CONNECTED':
          // Ignore late CONNECTED callbacks while a user-requested stop is
          // in progress. The disconnect flow must finish only on DISCONNECTED.
          if (_connection == _ConnectionUi.disconnecting) break;
          final wasConnected = _connection == _ConnectionUi.connected;
          _connection = _ConnectionUi.connected;
          if (!wasConnected) {
            _startAutoDisconnectTimer(
              elapsedSeconds: _elapsedConnectionSeconds(status.duration),
            );
          }
          _message = null;
          break;
        case 'CONNECTING':
          _connection = _ConnectionUi.connecting;
          break;
        case 'DISCONNECTING':
          _connection = _ConnectionUi.disconnecting;
          break;
        case 'DISCONNECTED':
          if (!_failoverRunning || _connection == _ConnectionUi.disconnecting) {
            _connection = _ConnectionUi.disconnected;
            _autoDisconnectTimer?.cancel();
            _autoDisconnectTimer = null;
            _autoDisconnectRemainingSeconds = 2 * 60 * 60;
            _uploadSpeed = 0;
            _downloadSpeed = 0;
            _uploadedBytes = 0;
            _downloadedBytes = 0;
            _pingMs = null;
            _pingAttempted = false;
            _activeServer = null;
          }
          break;
        case 'ERROR':
          if (!_failoverRunning) {
            _connection = _ConnectionUi.error;
            _message = _fa
                ? 'موتور VPN اتصال را برقرار نکرد.'
                : 'VPN engine failed to connect.';
          }
          break;
      }
    });
    if (status.state.toUpperCase() == 'CONNECTED' && !_pingAttempted) {
      _pingAttempted = true;
      unawaited(_refreshConnectedPing());
    }
  }

  Future<void> _refreshConnectedPing() async {
    try {
      final delay = await _vpn.getConnectedServerDelay();
      if (mounted && _connected) {
        setState(() => _pingMs = delay >= 0 ? delay : null);
      }
    } catch (_) {
      if (mounted && _connected) setState(() => _pingMs = null);
    }
  }

  String _formatAutoDisconnect(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  int _elapsedConnectionSeconds(String duration) {
    final parts = duration.split(':');
    if (parts.length != 3) return 0;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return 0;
    return (hours * 3600) + (minutes * 60) + seconds;
  }

  void _startAutoDisconnectTimer({int elapsedSeconds = 0}) {
    _autoDisconnectTimer?.cancel();
    final elapsed = elapsedSeconds.clamp(0, 2 * 60 * 60).toInt();
    _autoDisconnectRemainingSeconds = (2 * 60 * 60) - elapsed;
    _autoDisconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_connected) {
        timer.cancel();
        _autoDisconnectTimer = null;
        return;
      }
      if (_autoDisconnectRemainingSeconds <= 1) {
        timer.cancel();
        _autoDisconnectTimer = null;
        setState(() => _autoDisconnectRemainingSeconds = 0);
        unawaited(_disconnect());
        return;
      }
      setState(() => _autoDisconnectRemainingSeconds--);
    });
  }

  String _formatRate(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _autoDisconnectTimer?.cancel();
    _homeRotationTimer?.cancel();
    _statusSubscription?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _chooseServer() async {
    if (_busy || _connected) return;
    final selected = await Navigator.of(context).push<VpnServer>(
      MaterialPageRoute(
        builder: (_) => ServerListScreen(language: _language),
      ),
    );
    if (!mounted) return;
    if (selected == null) {
      await _storage.writeServerId('');
      if (!mounted) return;
      setState(() {
        _preferredServer = null;
        _selectedFavorite = false;
        _message = null;
      });
      return;
    }
    await _storage.writeServerId(selected.id);
    final favorites = await _storage.readFavoriteServerIds();
    if (mounted) {
      setState(() {
        _preferredServer = selected;
        _selectedFavorite = favorites.contains(selected.id);
        _message = null;
      });
    }
  }

  Future<void> _toggleConnection() async {
    if (_busy) return;
    if (_connected) {
      await _disconnect();
    } else {
      await _connectWithFallback();
    }
  }

  Future<void> _disconnect() async {
    _autoDisconnectTimer?.cancel();
    _autoDisconnectTimer = null;
    setState(() {
      _busy = true;
      _connection = _ConnectionUi.disconnecting;
      _message = null;
    });
    try {
      await _vpn.disconnect();
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.disconnected;
          _activeServer = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa ? 'قطع اتصال انجام نشد.' : 'Could not disconnect.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectWithFallback() async {
    _cancelRequested = false;
    _connectingStartedAt = DateTime.now();
    setState(() {
      _showConnectingPage = true;
      _busy = true;
      _failoverRunning = true;
      _connection = _ConnectionUi.connecting;
      _message = _fa ? 'در حال دریافت فهرست سرورها…' : 'Loading available servers…';
      _currentAttempt = 0;
      _attemptCount = 0;
    });

    try {
      // Fresh metadata is fetched each time so owner changes need no APK update.
      final servers = await _api.fetchServers();
      if (_cancelRequested) throw const _ConnectionCancelledException();
      if (!mounted) return;
      if (servers.isEmpty) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa
              ? 'در حال حاضر سرور فعالی وجود ندارد.'
              : 'No active servers are currently available.';
        });
        return;
      }

      final savedId = await _storage.readServerId();
      if (_cancelRequested) throw const _ConnectionCancelledException();
      if (!mounted) return;
      final preferredId = _preferredServer?.id ?? savedId;
      final savedServer = servers.where((server) => server.id == preferredId);
      final selectedServer = _preferredServer ??
          (savedServer.isEmpty ? null : savedServer.first);
      final selectedCountryCode = selectedServer?.countryCode;
      bool sameSelectedCity(VpnServer server) {
        if (selectedServer == null) return true;
        final selectedEn = (selectedServer.locationNameEn ?? '').trim().toLowerCase();
        final candidateEn = (server.locationNameEn ?? '').trim().toLowerCase();
        if (selectedEn.isNotEmpty && candidateEn.isNotEmpty) {
          return selectedEn == candidateEn;
        }
        final selectedFa = (selectedServer.locationNameFa ?? '').trim().toLowerCase();
        final candidateFa = (server.locationNameFa ?? '').trim().toLowerCase();
        if (selectedFa.isNotEmpty && candidateFa.isNotEmpty) {
          return selectedFa == candidateFa;
        }
        return (selectedEn.isNotEmpty && selectedEn == candidateEn) ||
            (selectedFa.isNotEmpty && selectedFa == candidateFa);
      }

      final countryServers = selectedCountryCode == null
          ? servers
          : servers.where((server) =>
              server.locationVerified &&
              server.countryCode == selectedCountryCode &&
              sameSelectedCity(server)).toList();
      if (countryServers.isEmpty) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa
              ? 'برای این کشور در حال حاضر سرور فعالی وجود ندارد.'
              : 'No active servers are available for this location.';
        });
        return;
      }
      final candidates = <VpnServer>[
        ...countryServers.where((server) => server.id == preferredId),
        ...countryServers.where((server) => server.id != preferredId),
      ];
      _attemptCount = candidates.length;

      final connectedServer = await connectWithFallback<VpnServer>(
        candidates: candidates,
        isFatal: (error) => _cancelRequested ||
            (error is ApiException &&
                (error.statusCode == 401 ||
                    error.statusCode == 403 ||
                    error.statusCode == 429)) ||
            error is VpnPermissionException,
        onAttempt: (server, index) {
          if (!mounted) return;
          setState(() {
            _currentAttempt = index + 1;
            _activeServer = server;
            _connection = _ConnectionUi.connecting;
            _message = index == 0
                ? (_fa ? 'در حال اتصال…' : 'Connecting…')
                : (_fa ? 'تلاش با سرور بعدی…' : 'Trying the next server…');
          });
        },
        attempt: (server) async {
          // Profile remains transient and is requested only for this attempt.
          if (_cancelRequested) throw const _ConnectionCancelledException();
          final profile = await _api.fetchServerConfig(server.id);
          if (_cancelRequested) throw const _ConnectionCancelledException();
          final tunnelApps = await _storage.readTunnelApps();
          await _vpn.connect(
            profile: profile,
            remark: server.name,
            allowedApps: tunnelApps.isEmpty ? null : tunnelApps,
          );
        },
      );

      if (_cancelRequested) throw const _ConnectionCancelledException();
      await _storage.writeServerId(connectedServer.id);
      final favorites = await _storage.readFavoriteServerIds();
      if (mounted) {
        setState(() {
          _activeServer = connectedServer;
          _preferredServer = connectedServer;
          _selectedFavorite = favorites.contains(connectedServer.id);
          _connection = _ConnectionUi.connected;
          _message = null;
        });
      }
    } on _ConnectionCancelledException {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.disconnected;
          _activeServer = null;
          _message = null;
        });
      }
    } on VpnPermissionException {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.disconnected;
          _message = _fa ? 'مجوز VPN داده نشد.' : 'VPN permission was denied.';
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = error.statusCode == 403
              ? (_fa
                  ? 'این دستگاه ثبت شده و منتظر تأیید مدیر است. پس از تأیید دوباره اتصال را بزنید.'
                  : 'This device is registered and awaiting administrator approval. Try connecting again after approval.')
              : (_fa
                  ? 'دریافت امن پروفایل از سمت سرویس در دسترس نیست.'
                  : 'Secure profile delivery is unavailable from the service.');
        });
      }
    } on AllCandidatesFailedException catch (error) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _activeServer = null;
          _message = _fa
              ? 'اتصال به هیچ‌یک از ${error.attemptedCount} سرور برقرار نشد.'
              : 'Could not connect to any of the ${error.attemptedCount} servers.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connection = _cancelRequested ? _ConnectionUi.disconnected : _ConnectionUi.error;
          _activeServer = null;
          _message = _cancelRequested
              ? null
              : (_fa ? 'اتصال VPN برقرار نشد.' : 'VPN connection failed.');
        });
      }
    } finally {
      _cancelRequested = false;
      _failoverRunning = false;
      final startedAt = _connectingStartedAt;
      if (startedAt != null) {
        final elapsed = DateTime.now().difference(startedAt);
        final remaining = const Duration(seconds: 3) - elapsed;
        if (remaining > Duration.zero) await Future.delayed(remaining);
      }
      _connectingStartedAt = null;
      if (mounted) {
        setState(() {
          _showConnectingPage = false;
          _busy = false;
        });
      }
    }
  }

  String get _stateLabel => switch (_connection) {
        _ConnectionUi.disconnected => _t('disconnected'),
        _ConnectionUi.connecting => _t('connecting'),
        _ConnectionUi.connected => _t('connected'),
        _ConnectionUi.disconnecting => _fa ? 'در حال قطع' : 'Disconnecting',
        _ConnectionUi.error => _fa ? 'خطا' : 'Error',
      };


  String _flag(String? code) {
    if (code == null || code.length != 2) return '🌐';
    final normalized = code.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '🌐';
    return String.fromCharCodes(
      normalized.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
    );
  }

  VpnServer? get _displayServer => _activeServer ?? _preferredServer;

  Future<void> _toggleSelectedFavorite() async {
    final selected = _displayServer;
    if (selected == null) return;
    final favorite = await _storage.toggleFavoriteServer(selected.id);
    if (mounted) setState(() => _selectedFavorite = favorite);
  }

  Future<void> _cancelConnection() async {
    if (!_busy || _connection != _ConnectionUi.connecting) return;
    _cancelRequested = true;
    if (mounted) {
      setState(() {
        _message = _fa ? 'در حال لغو اتصال…' : 'Cancelling connection…';
      });
    }
    try {
      await _vpn.disconnect();
    } catch (_) {
      // The in-flight attempt observes the cancellation flag and exits.
    }
  }

  Widget _buildConnectingPage() {
    final selected = _activeServer;
    final progress = _attemptCount > 0
        ? (_currentAttempt / _attemptCount).clamp(0.0, 1.0).toDouble()
        : null;
    return Scaffold(
      backgroundColor: const Color(0xFF071020),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: _fa ? 'لغو اتصال' : 'Cancel connection',
                    onPressed: _cancelConnection,
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFB8B7C0)),
                  ),
                  const Spacer(),
                  const Text('NOVA VPN  ·  0.1.0',
                      style: TextStyle(color: Color(0xFF686773), fontSize: 10)),
                ],
              ),
              const Spacer(),
              const NovaOrbitAnimation(size: 258),
              const SizedBox(height: 28),
              const Text('NOVA VPN',
                  style: TextStyle(
                    color: Color(0xFF5E91FF),
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  )),
              const SizedBox(height: 22),
              Text(_connection == _ConnectionUi.connected ? (_fa ? 'متصل شد' : 'Connected') : (_t('connecting')),
                  style: const TextStyle(
                      color: Color(0xFF4C91FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selected?.name ??
                        (_fa ? 'Auto Location' : 'Auto Location'),
                    style: const TextStyle(
                        color: const Color(0xFF54DDF5),
                        fontSize: 19,
                        fontWeight: FontWeight.w700),
                  ),
                  if (selected != null) ...[
                    const SizedBox(width: 9),
                    Text(_flag(selected.countryCode),
                        style: const TextStyle(fontSize: 20)),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _message ?? (_fa ? 'در حال آماده‌سازی اتصال…' : 'Preparing connection…'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9B99A5), fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF20202A),
                  color: const Color(0xFF42C9E8),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              if (_attemptCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _fa
                      ? 'تلاش $_currentAttempt از $_attemptCount'
                      : 'Attempt $_currentAttempt of $_attemptCount',
                  style: const TextStyle(color: Color(0xFF85838E), fontSize: 10),
                ),
              ],
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF191820),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF383640)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded,
                        color: Color(0xFFFFC34D), size: 17),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        _fa
                            ? 'لطفاً تا پایان اتصال در این صفحه بمانید'
                            : 'Please stay on this page while connecting',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFFFC34D), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showConnectingPage) {
      return Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: _buildConnectingPage(),
      );
    }

    final selected = _displayServer;
    final selectedName = selected?.name.trim().isNotEmpty == true
        ? selected!.name
        : (_fa ? 'Auto Location' : 'Auto Location');

    return Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _lightTheme ? const Color(0xFFF2F6FC) : const Color(0xFF0B0A10),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            color: const Color(0xFF42C9E8),
            backgroundColor: const Color(0xFF14131A),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Extra bottom clearance keeps the last controls comfortably
              // above Android's three-button navigation bar while scrolling.
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: _fa ? 'تنظیمات' : 'Settings',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                        final language = await _storage.readLanguage();
                        final lightTheme = await _storage.readLightTheme();
                        if (mounted) {
                          setState(() {
                            _language = language;
                            _lightTheme = lightTheme;
                          });
                        }
                      },
                      icon: const Icon(Icons.tune_rounded,
                          color: Color(0xFFB9C9E4), size: 25),
                    ),
                    const SizedBox(width: 8),
                    _buildInternetIndicator(),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('NOVA VPN',
                            style: TextStyle(
                                color: _lightTheme ? const Color(0xFF20334D) : const Color(0xFFF0F4FF),
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text(
                          _fa ? 'خصوصی  •  سریع  •  امن' : 'PRIVATE  •  FAST  •  SECURE',
                          style: const TextStyle(
                              color: Color(0xFF788CAB),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        'assets/brand/nova_logo_new.jpg',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'NOVA VPN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5C8FFF),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -.8,
                  ),
                ),
                if (_connected) ...[
                  const SizedBox(height: 7),
                  Column(
                    children: [
                      Text(
                        _fa ? 'زمان باقی‌مانده تا قطع خودکار' : 'Auto-disconnect in',
                        style: const TextStyle(
                          color: Color(0xFF8F8D99),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatAutoDisconnect(_autoDisconnectRemainingSeconds),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Color(0xFFFFC34D),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    return GestureDetector(
                      onTap: _busy ? null : _toggleConnection,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        width: 132,
                        height: 88,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(48),
                          color: _connected ? null : const Color(0xFF101D32),
                          gradient: _connected
                              ? const LinearGradient(
                                  colors: [Color(0xFF477EFF), Color(0xFF25C6D5)],
                                )
                              : null,
                          border: Border.all(
                            color: _connected
                                ? const Color(0xFF4D9AFF)
                                : const Color(0xFF344B70),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF367CFF).withValues(
                                  alpha: .07 + (pulse * .11)),
                              blurRadius: 18 + (pulse * 18),
                              spreadRadius: 1 + (pulse * 2),
                            ),
                          ],
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          alignment: _connected
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _lightTheme ? const Color(0xFFFFFFFF) : const Color(0xFFECEBF0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.power_settings_new_rounded,
                              color: Color(0xFF3B3A44),
                              size: 31,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  _connected
                      ? (_t('connected'))
                      : _stateLabel,
                  style: TextStyle(
                    color: _connected
                        ? const Color(0xFF159B70)
                        : (_lightTheme ? const Color(0xFF263B59) : const Color(0xFFB8B6C1)),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildHomeAdPlacement(),
                if (_homeContent?.announcements.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _buildAnnouncementBar(),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xB91B1A22),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF34323D)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .28),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t('selectServer'),
                              style: const TextStyle(
                                  color: Color(0xFFAAA8B3), fontSize: 10),
                            ),
                          ),
                          const Icon(Icons.list_alt_rounded,
                              color: Color(0xFF8C8A96), size: 17),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: const Color(0xFF0E0D14),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _busy || _connected ? null : _chooseServer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 7),
                            child: Row(
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: _fa ? 'علاقه‌مندی' : 'Favorite',
                                  onPressed: selected == null
                                      ? null
                                      : _toggleSelectedFavorite,
                                  icon: Icon(
                                    _selectedFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: _selectedFavorite
                                        ? const Color(0xFFFFC83D)
                                        : const Color(0xFF777680),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    selectedName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: _lightTheme ? const Color(0xFF243650) : const Color(0xFFE9E8EE),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_flag(selected?.countryCode),
                                    style: const TextStyle(fontSize: 22)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_connected) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ConnectionMetric(
                              label: _fa ? 'دریافت' : 'Download',
                              value: _formatRate(_downloadSpeed),
                              icon: Icons.south_rounded,
                            ),
                            _ConnectionMetric(
                              label: _fa ? 'ارسال' : 'Upload',
                              value: _formatRate(_uploadSpeed),
                              icon: Icons.north_rounded,
                            ),
                            _ConnectionMetric(
                              label: _fa ? 'پینگ' : 'Ping',
                              value: _pingMs == null ? '—' : '$_pingMs ms',
                              icon: Icons.speed_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fa
                              ? 'دریافت کل: ${_formatBytes(_downloadedBytes)}  ·  ارسال کل: ${_formatBytes(_uploadedBytes)}'
                              : 'Downloaded: ${_formatBytes(_downloadedBytes)}  ·  Uploaded: ${_formatBytes(_uploadedBytes)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF777680), fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30202A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF754052)),
                    ),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFFFC5D0), fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ConnectionCancelledException implements Exception {
  const _ConnectionCancelledException();
}
class _ConnectionMetric extends StatelessWidget {
  const _ConnectionMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF69A0FF)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      );
}
