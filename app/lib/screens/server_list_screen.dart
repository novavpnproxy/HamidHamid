import 'package:flutter/material.dart';

import '../models/vpn_server.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Location picker. Server profiles remain private and are never exposed here.
class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key, required this.language});
  final String language;

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  late Future<List<VpnServer>> _servers;
  final Set<String> _expandedCountries = <String>{};
  Set<String> _favoriteIds = <String>{};
  List<String> _recentIds = <String>[];
  int _tab = 0;
  bool _savedListsLoaded = false;

  bool get _fa => widget.language == 'fa';

  @override
  void initState() {
    super.initState();
    _servers = _api.fetchServers();
    _loadSavedLists();
  }

  Future<void> _loadSavedLists() async {
    final values = await Future.wait([
      _storage.readFavoriteServerIds(),
      _storage.readRecentServerIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _favoriteIds = values[0].toSet();
      _recentIds = values[1];
      _savedListsLoaded = true;
    });
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  String _countryName(VpnServer server) =>
      (_fa ? server.countryNameFa : server.countryNameEn) ??
      server.countryNameEn ??
      server.countryCode ??
      (_fa ? 'موقعیت نامشخص' : 'Unknown location');

  String _locationName(VpnServer server) =>
      (_fa ? server.locationNameFa : server.locationNameEn) ??
      server.locationNameEn ??
      (_fa ? 'موقعیت دیگر' : 'Other location');

  String _flag(String? code) {
    if (code == null || code.length != 2) return '🌐';
    final normalized = code.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '🌐';
    return String.fromCharCodes(
      normalized.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
    );
  }

  Map<String, List<VpnServer>> _group(List<VpnServer> servers) {
    final groups = <String, List<VpnServer>>{};
    for (final server in servers) {
      final code = server.countryCode;
      if (!server.locationVerified || code == null || code.length != 2) {
        continue;
      }
      (groups[code] ??= <VpnServer>[]).add(server);
    }
    return groups;
  }

  Future<void> _toggleFavorite(VpnServer server) async {
    final added = await _storage.toggleFavoriteServer(server.id);
    if (!mounted) return;
    setState(() {
      if (added) {
        _favoriteIds.add(server.id);
      } else {
        _favoriteIds.remove(server.id);
      }
    });
  }

  Future<void> _select(VpnServer server) async {
    await _storage.recordRecentServer(server.id);
    if (!mounted) return;
    Navigator.of(context).pop<VpnServer>(server);
  }

  Widget _tabChip(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Center(child: Text(label, maxLines: 1)),
          selected: selected,
          onSelected: (_) => setState(() => _tab = index),
          showCheckmark: false,
          backgroundColor: const Color(0xFF111D34),
          selectedColor: const Color(0xFF315FD7),
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFFB9C5DD),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: selected ? const Color(0xFF6C91FF) : const Color(0xFF263754),
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        ),
      ),
    );
  }

  Widget _serverRow(VpnServer server, {String? title}) {
    final favorite = _favoriteIds.contains(server.id);
    final rowTitle = title ??
        (server.name.trim().isNotEmpty ? server.name : _locationName(server));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: const Color(0xFF101D33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: favorite ? const Color(0xFF4567A5) : const Color(0xFF263A59),
            width: favorite ? 1.5 : 1.1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _select(server),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsetsDirectional.only(start: 10, end: 14),
        child: Row(
          children: [
            IconButton(
              tooltip: favorite
                  ? (_fa ? 'حذف از علاقه‌مندی‌ها' : 'Remove from favorites')
                  : (_fa ? 'افزودن به علاقه‌مندی‌ها' : 'Add to favorites'),
              visualDensity: VisualDensity.compact,
              onPressed: () => _toggleFavorite(server),
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: favorite ? const Color(0xFFFFC83D) : const Color(0xFF9DAFCB),
                size: 21,
              ),
            ),
            const Icon(Icons.person_outline_rounded,
                color: Color(0xFF35C78A), size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: _fa ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  color: Color(0xFFE2E1E7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(_flag(server.countryCode), style: const TextStyle(fontSize: 21)),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _automaticRow() => InkWell(
        onTap: () => Navigator.of(context).pop<VpnServer>(null),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF26252D), width: .7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF777680), size: 20),
              const SizedBox(width: 12),
              const Icon(Icons.public_rounded,
                  color: Color(0xFF4C91FF), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_fa ? 'پیش‌فرض' : 'Automatic',
                        style: const TextStyle(
                            color: Color(0xFFE4E3E9),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(_fa ? 'انتخاب خودکار سرور' : 'Choose a server automatically',
                        style: const TextStyle(color: Color(0xFF777680), fontSize: 10)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF66656E)),
            ],
          ),
        ),
      );

  Widget _countryRow(String code, List<VpnServer> servers) {
    final expanded = _expandedCountries.contains(code);
    final first = servers.first;
    final favoriteCount =
        servers.where((server) => _favoriteIds.contains(server.id)).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: expanded
                ? const [Color(0xFF142B4C), Color(0xFF0D1B31)]
                : const [Color(0xFF121F35), Color(0xFF0D192B)],
          ),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: expanded
                ? const Color(0xFF5687F4)
                : const Color(0xFF30496D),
            width: expanded ? 2.2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F65C8).withValues(alpha: expanded ? .20 : .09),
              blurRadius: expanded ? 18 : 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() {
                if (expanded) {
                  _expandedCountries.remove(code);
                } else {
                  _expandedCountries.add(code);
                }
              }),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(15, 13, 16, 13),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF243A5D),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFFB9D0FF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_countryName(first),
                              style: const TextStyle(
                                  color: Color(0xFFF0F4FC),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(
                            _fa
                                ? '${servers.length} سرور قابل انتخاب • ${favoriteCount} مورد علاقه'
                                : '${servers.length} available servers • ${favoriteCount} favorites',
                            style: const TextStyle(
                                color: Color(0xFFA7B8D3), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fa ? 'برای دیدن سرورها لمس کنید' : 'Tap to view servers',
                            style: const TextStyle(
                                color: Color(0xFF6FA0FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_flag(code), style: const TextStyle(fontSize: 27)),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 14),
                child: Divider(
                    height: 1, thickness: 1, color: const Color(0xFF45658F)),
              ),
              ...servers.map((server) => _serverRow(
                    server,
                    title: server.name.trim().isEmpty
                        ? _locationName(server)
                        : server.name,
                  )),
              const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }

  Widget _savedList(List<VpnServer> servers, {required bool favorites}) {
    final ids = favorites ? _favoriteIds.toList() : _recentIds;
    final byId = {for (final server in servers) server.id: server};
    final visible = ids.map((id) => byId[id]).whereType<VpnServer>().toList();
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                favorites ? Icons.star_border_rounded : Icons.history_rounded,
                color: const Color(0xFF55545D),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                favorites
                    ? (_fa ? 'هنوز سروری به علاقه‌مندی‌ها اضافه نشده است.' : 'No favorite servers yet.')
                    : (_fa ? 'هنوز موقعیتی انتخاب نشده است.' : 'No recent locations yet.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9998A2), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: visible.map((server) => _serverRow(server)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _fa ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFF071020),
          body: SafeArea(
            child: FutureBuilder<List<VpnServer>>(
              future: _servers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || !_savedListsLoaded) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5A8FFF)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fa
                                ? 'دریافت موقعیت‌ها ممکن نیست. اتصال اینترنت را بررسی کنید.'
                                : 'Could not load locations. Check your internet connection.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFE0DFE5)),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => setState(() => _servers = _api.fetchServers()),
                            child: Text(_fa ? 'تلاش دوباره' : 'Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final servers = snapshot.data ?? const <VpnServer>[];
                final groups = _group(servers);
                final countries = groups.keys.toList()
                  ..sort((a, b) => _countryName(groups[a]!.first)
                      .compareTo(_countryName(groups[b]!.first)));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 18, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFFB9B8C1)),
                          ),
                          const Spacer(),
                          Text(_fa ? 'مکان' : 'Location',
                              style: const TextStyle(
                                  color: Color(0xFFF1F0F5),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          const Icon(Icons.public_rounded,
                              color: Color(0xFFE0DFE7), size: 20),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          _tabChip(_fa ? 'مکان‌ها' : 'Locations', 0),
                          _tabChip(_fa ? 'مورد علاقه' : 'Favorites', 1),
                          _tabChip(_fa ? 'اخیر' : 'Recent', 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (_tab == 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 12),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_rounded,
                                color: Color(0xFF78A5FF), size: 17),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fa
                                    ? 'برای افزودن هر سرور به مورد علاقه‌ها، ستارهٔ کنار همان سرور را لمس کنید.'
                                    : 'Tap the star beside any server to save it to Favorites.',
                                style: const TextStyle(
                                    color: Color(0xFF9EAFCA), fontSize: 11, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _tab == 1
                          ? _savedList(servers, favorites: true)
                          : _tab == 2
                              ? _savedList(servers, favorites: false)
                              : ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    _automaticRow(),
                                    if (countries.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(28),
                                        child: Text(
                                          _fa
                                              ? 'هنوز موقعیت فعالی ثبت نشده است.'
                                              : 'No active locations are available yet.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Color(0xFF9998A2)),
                                        ),
                                      ),
                                    for (final code in countries)
                                      _countryRow(code, groups[code]!),
                                  ],
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}
