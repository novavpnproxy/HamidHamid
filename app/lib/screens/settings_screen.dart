import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  String _language = 'fa';
  bool _lightTheme = false;

  bool get _fa => _language == 'fa';

  @override
  void initState() {
    super.initState();
    _storage.readLanguage().then((value) {
      if (mounted) setState(() => _language = value);
    });
    _storage.readLightTheme().then((value) {
      if (mounted) setState(() => _lightTheme = value);
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
          _fa ? 'به‌زودی' : 'Soon',
          style: TextStyle(color: _lightTheme ? const Color(0xFF8192A8) : const Color(0xFF66646F), fontSize: 9),
        ),
        dense: true,
      );

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
        textDirection: _fa ? TextDirection.rtl : TextDirection.ltr,
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
                  _comingSoonRow(
                    icon: Icons.call_split_rounded,
                    title: _fa ? 'تونل برنامه‌های گوشی' : 'Per-app VPN',
                    subtitle: _fa
                        ? 'انتخاب برنامه‌هایی که از VPN استفاده می‌کنند'
                        : 'Choose which phone apps use the VPN',
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
