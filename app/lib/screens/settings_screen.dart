import 'package:flutter/material.dart';

import '../services/app_localizations.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  String _language = 'fa';
  bool _lightTheme = false;
  Set<String> _selectedTunnelApps = <String>{};
  List<Map<String, String>> _installedApps = <Map<String, String>>[];
  bool _loadingApps = false;

  bool get _fa => _language == 'fa' || _language == 'fa-AF';
  bool get _rtl => NovaLocalizations.isRtl(_language);
  String _t(String key) => NovaLocalizations.text(_language, key);

  @override
  void initState() {
    super.initState();
    _storage.readLanguage().then((value) {
      if (mounted) setState(() => _language = value);
    });
    _storage.readLightTheme().then((value) {
      if (mounted) setState(() => _lightTheme = value);
    });
    _storage.readTunnelApps().then((value) {
      if (mounted) setState(() => _selectedTunnelApps = value.toSet());
    });
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(5, 18, 5, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8E8C98),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _settingsCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _lightTheme ? const Color(0xFFFFFFFF) : const Color(0xFF191820),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _lightTheme ? const Color(0xFFD8E3F0) : const Color(0xFF2B2933)),
        ),
        child: Column(children: children),
      );

  Widget _comingSoonRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      ListTile(
        enabled: false,
        leading: Icon(icon, color: const Color(0xFF777580), size: 20),
        title: Text(
          title,
          style: TextStyle(
              color: _lightTheme ? const Color(0xFF314762) : const Color(0xFFB4B2BD), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: _lightTheme ? const Color(0xFF71839B) : const Color(0xFF777580), fontSize: 10),
        ),
        trailing: Text(
          _t('soon'),
          style: TextStyle(color: _lightTheme ? const Color(0xFF8192A8) : const Color(0xFF66646F), fontSize: 9),
        ),
        dense: true,
      );

  Future<void> _openSplitTunneling() async {
    if (_loadingApps) return;
    setState(() => _loadingApps = true);
    try {
      final values = await Future.wait([
        VpnService().getInstalledApps(),
        _storage.readTunnelApps(),
      ]);
      if (!mounted) return;
      _installedApps = values[0] as List<Map<String, String>>;
      _selectedTunnelApps = (values[1] as List<String>).toSet();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_fa ? 'فهرست برنامه‌های گوشی دریافت نشد.' : 'Could not load phone apps.')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _loadingApps = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var selected = Set<String>.from(_selectedTunnelApps);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: _lightTheme ? const Color(0xFFF9FCFF) : const Color(0xFF191F2C),
            title: Text(_fa ? 'تونل برنامه‌های گوشی' : 'Per-app VPN',
                style: TextStyle(color: _lightTheme ? const Color(0xFF20334D) : Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              height: 430,
              child: Column(
                children: [
                  Text(
                    _fa
                        ? 'فقط برنامه‌های علامت‌خورده از VPN عبور می‌کنند. اگر هیچ برنامه‌ای انتخاب نشود، VPN برای همه برنامه‌ها فعال است.'
                        : 'Only checked apps use the VPN. If none are selected, the VPN is used by all apps.',
                    style: TextStyle(color: _lightTheme ? const Color(0xFF49688F) : const Color(0xFFB8C7DD), fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _installedApps.isEmpty
                        ? Center(child: Text(_fa ? 'برنامه قابل انتخابی پیدا نشد.' : 'No launchable apps found.'))
                        : ListView.builder(
                            itemCount: _installedApps.length,
                            itemBuilder: (context, index) {
                              final app = _installedApps[index];
                              final packageName = app['packageName'] ?? '';
                              return CheckboxListTile(
                                dense: true,
                                value: selected.contains(packageName),
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    selected.add(packageName);
                                  } else {
                                    selected.remove(packageName);
                                  }
                                }),
                                title: Text(app['appName'] ?? packageName,
                                    style: TextStyle(color: _lightTheme ? const Color(0xFF20334D) : const Color(0xFFE8F0FC), fontSize: 13)),
                                subtitle: Text(packageName,
                                    style: TextStyle(color: _lightTheme ? const Color(0xFF71839B) : const Color(0xFF818FA4), fontSize: 9)),
                                secondary: const Icon(Icons.apps_rounded, color: Color(0xFF4D91FF)),
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_fa ? 'انصراف' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await _storage.writeTunnelApps(selected.toList());
                  if (mounted) setState(() => _selectedTunnelApps = selected);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: Text(_fa ? 'ذخیره' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeTheme(bool value) async {
    await _storage.writeLightTheme(value);
    if (mounted) setState(() => _lightTheme = value);
  }

  Future<void> _changeLanguage(String? value) async {
    if (value == null) return;
    await _storage.writeLanguage(value);
    if (mounted) setState(() => _language = value);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: _lightTheme ? const Color(0xFFF2F6FC) : const Color(0xFF100F15),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: _fa ? 'بستن' : 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFB8B6C1)),
                    ),
                    const Spacer(),
                    Text(
                      _fa ? 'تنظیمات' : 'Settings',
                      style: const TextStyle(
                        color: Color(0xFFF0EFF4),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(Icons.tune_rounded,
                        color: _lightTheme ? const Color(0xFF49688F) : const Color(0xFFE0DFE6), size: 20),
                  ],
                ),
                _sectionTitle(_fa ? 'حساب کاربری' : 'Account'),
                _settingsCard([
                  _comingSoonRow(
                    icon: Icons.person_add_alt_1_rounded,
                    title: _fa ? 'عضو شدن' : 'Join',
                    subtitle: _fa
                        ? 'ساخت و مدیریت حساب کاربری به‌زودی'
                        : 'Account creation and management coming soon',
                  ),
                ]),

                _sectionTitle(_fa ? 'شبکه' : 'Network'),
                _settingsCard([
                  ListTile(
                    leading: const Icon(Icons.call_split_rounded, color: Color(0xFF4D91FF), size: 20),
                    title: Text(_fa ? 'تونل برنامه‌های گوشی' : 'Per-app VPN',
                        style: TextStyle(color: _lightTheme ? const Color(0xFF263B59) : const Color(0xFFE0DFE7), fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      _loadingApps
                          ? (_fa ? 'در حال دریافت برنامه‌ها…' : 'Loading apps…')
                          : _selectedTunnelApps.isEmpty
                              ? (_fa ? 'همه برنامه‌ها از VPN استفاده می‌کنند' : 'All apps use the VPN')
                              : (_fa ? '${_selectedTunnelApps.length} برنامه انتخاب شده' : '${_selectedTunnelApps.length} apps selected'),
                      style: TextStyle(color: _lightTheme ? const Color(0xFF71839B) : const Color(0xFF9A98A5), fontSize: 10),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8192A8)),
                    onTap: _openSplitTunneling,
                    dense: true,
                  ),
                ]),
                _sectionTitle(_fa ? 'نمایش' : 'Appearance'),
                _settingsCard([
                  SwitchListTile(
                    secondary: Icon(
                      _lightTheme ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: const Color(0xFF4D91FF),
                      size: 20,
                    ),
                    title: Text(
                      _fa ? 'حالت روشن' : 'Light theme',
                      style: TextStyle(
                        color: _lightTheme ? const Color(0xFF263B59) : const Color(0xFFE0DFE7),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _fa ? 'با خاموش کردن، حالت تیره فعال می‌شود' : 'Turn off to use the dark theme',
                      style: TextStyle(
                        color: _lightTheme ? const Color(0xFF71839B) : const Color(0xFF9A98A5),
                        fontSize: 10,
                      ),
                    ),
                    value: _lightTheme,
                    activeColor: const Color(0xFF2878E8),
                    onChanged: _changeTheme,
                    dense: true,
                  ),
                ]),
                _sectionTitle(_fa ? 'برنامه' : 'Application'),
                _settingsCard([
                  ListTile(
                    leading: const Icon(Icons.language_rounded,
                        color: Color(0xFF7EA6FF), size: 20),
                    title: Text(
                      _fa ? 'زبان' : 'Language',
                      style: TextStyle(
                          color: _lightTheme ? const Color(0xFF263B59) : const Color(0xFFE0DFE7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    trailing: DropdownButton<String>(
                      value: _language,
                      dropdownColor: _lightTheme ? const Color(0xFFFFFFFF) : const Color(0xFF24222B),
                      underline: const SizedBox.shrink(),
                      style: TextStyle(
                          color: _lightTheme ? const Color(0xFF263B59) : const Color(0xFFE0DFE7), fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                        DropdownMenuItem(value: 'az', child: Text('Azərbaycan')),
                        DropdownMenuItem(value: 'ur', child: Text('اردو')),
                        DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                        DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                        DropdownMenuItem(value: 'zh', child: Text('中文')),
                        DropdownMenuItem(value: 'ja', child: Text('日本語')),
                        DropdownMenuItem(value: 'ko', child: Text('한국어')),
                        DropdownMenuItem(value: 'id', child: Text('Bahasa Indonesia')),
                        DropdownMenuItem(value: 'ms', child: Text('Bahasa Melayu')),
                        DropdownMenuItem(value: 'th', child: Text('ไทย')),
                        DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                        DropdownMenuItem(value: 'tl', child: Text('Filipino')),
                        DropdownMenuItem(value: 'ru', child: Text('Русский')),
                        DropdownMenuItem(value: 'uk', child: Text('Українська')),
                        DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                        DropdownMenuItem(value: 'pt', child: Text('Português')),
                        DropdownMenuItem(value: 'it', child: Text('Italiano')),
                        DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
                        DropdownMenuItem(value: 'pl', child: Text('Polski')),
                        DropdownMenuItem(value: 'sv', child: Text('Svenska')),
                        DropdownMenuItem(value: 'no', child: Text('Norsk')),
                        DropdownMenuItem(value: 'da', child: Text('Dansk')),
                        DropdownMenuItem(value: 'fi', child: Text('Suomi')),
                        DropdownMenuItem(value: 'el', child: Text('Ελληνικά')),
                        DropdownMenuItem(value: 'he', child: Text('עברית')),
                        DropdownMenuItem(value: 'fa-AF', child: Text('دری')),
                        DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
                        DropdownMenuItem(value: 'ro', child: Text('Română')),
                        DropdownMenuItem(value: 'cs', child: Text('Čeština')),
                        DropdownMenuItem(value: 'hu', child: Text('Magyar')),
                        DropdownMenuItem(value: 'sr', child: Text('Српски')),
                      ],
                      onChanged: _changeLanguage,
                    ),
                    dense: true,
                  ),
                  const Divider(height: 1, color: Color(0xFF2B2933)),
                  ListTile(
                    leading: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF4D91FF),
                      size: 20,
                    ),
                    title: Text(
                      _fa ? 'تماس با ما' : 'Contact us',
                      style: TextStyle(
                        color: _lightTheme
                            ? const Color(0xFF263B59)
                            : const Color(0xFFE0DFE7),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const SelectableText(
                      'mynovavpnproxy@gmail.com',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Color(0xFF4D91FF),
                        fontSize: 12,
                      ),
                    ),
                    dense: true,
                  ),
                  const Divider(height: 1, color: Color(0xFF2B2933)),
                  _comingSoonRow(
                    icon: Icons.help_outline_rounded,
                    title: _fa ? 'سؤالات متداول' : 'Frequently asked questions',
                    subtitle: _fa
                        ? 'راهنمای برنامه در حال آماده‌سازی است'
                        : 'The app guide is being prepared',
                  ),
                  const Divider(height: 1, color: Color(0xFF2B2933)),
                  _comingSoonRow(
                    icon: Icons.privacy_tip_outlined,
                    title: _fa ? 'سیاست حفظ حریم خصوصی' : 'Privacy policy',
                    subtitle: _fa
                        ? 'پیش از انتشار عمومی باید تکمیل شود'
                        : 'Must be completed before public release',
                  ),
                  const Divider(height: 1, color: Color(0xFF2B2933)),
                  _comingSoonRow(
                    icon: Icons.description_outlined,
                    title: _fa ? 'شرایط استفاده از خدمات' : 'Terms of service',
                    subtitle: _fa
                        ? 'پیش از انتشار عمومی باید تکمیل شود'
                        : 'Must be completed before public release',
                  ),
                  const Divider(height: 1, color: Color(0xFF2B2933)),
                  ListTile(
                    enabled: false,
                    leading: const Icon(Icons.info_outline_rounded,
                        color: Color(0xFF777580), size: 20),
                    title: Text(
                      _fa ? 'نسخه برنامه' : 'App version',
                      style: const TextStyle(
                          color: Color(0xFFB4B2BD), fontSize: 13),
                    ),
                    trailing: const Text('0.1.0',
                        style: TextStyle(
                            color: Color(0xFF777580), fontSize: 11)),
                    dense: true,
                  ),
                ]),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'NOVA VPN',
                    style: TextStyle(
                      color: (_lightTheme ? const Color(0xFF617B9D) : const Color(0xFF777580)).withValues(alpha: .8),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
