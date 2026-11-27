import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NovaHelpScreen extends StatelessWidget {
  const NovaHelpScreen({super.key, required this.language, required this.lightTheme, this.privacyOnly = false});
  final String language;
  final bool lightTheme;
  final bool privacyOnly;
  bool get fa => language == 'fa' || language == 'fa-AF';
  Color get bg => lightTheme ? const Color(0xFFF2F6FC) : const Color(0xFF100F15);
  Color get surface => lightTheme ? Colors.white : const Color(0xFF191820);
  Color get fg => lightTheme ? const Color(0xFF263B59) : const Color(0xFFE8E7EF);
  Color get muted => lightTheme ? const Color(0xFF71839B) : const Color(0xFFA09EAA);

  static const faFaq = <List<String>>[
    ['چگونه به VPN متصل شوم؟','وارد صفحه اصلی شوید، کشور موردنظر را انتخاب کنید و دکمه اتصال را لمس کنید. برنامه برای برقراری اتصال تلاش می‌کند.'],
    ['اگر VPN متصل نشد چه کار کنم؟','یک سرور دیگر انتخاب کنید، چند لحظه صبر کنید و دوباره اتصال را امتحان کنید. همچنین اتصال اینترنت گوشی را بررسی کنید.'],
    ['چرا سرعت اینترنت من پایین است؟','سرعت به کیفیت اینترنت شما، فاصله تا سرور، شلوغی شبکه و وضعیت سرور بستگی دارد. انتخاب سرور نزدیک‌تر ممکن است سرعت را بهتر کند.'],
    ['کدام کشور را انتخاب کنم؟','معمولاً سروری را انتخاب کنید که به موقعیت شما نزدیک‌تر است یا در برنامه عملکرد سریع‌تر و پایدارتری دارد.'],
    ['آیا استفاده از Nova VPN رایگان است؟','امکانات رایگان برنامه طبق شرایط سرویس ارائه می‌شود. ممکن است برای تأمین هزینه‌های سرویس، تبلیغات نمایش داده شود.'],
    ['چرا اتصال VPN قطع می‌شود؟','ضعف یا قطع اینترنت، تغییر شبکه، محدودیت‌های باتری گوشی یا ناپایداری سرور می‌تواند باعث قطع اتصال شود.'],
    ['قابلیت اتصال خودکار چیست؟','این قابلیت به برنامه اجازه می‌دهد برای برقراری اتصال، سرورهای در دسترس را به‌صورت خودکار انتخاب و امتحان کند.'],
    ['تایمر دو ساعته چه کاربردی دارد؟','تایمر زمان باقی‌مانده اتصال را نشان می‌دهد و پس از پایان دو ساعت، اتصال VPN را به‌صورت خودکار قطع می‌کند.'],
    ['قابلیت انتخاب برنامه‌ها برای عبور از VPN چیست؟','با این قابلیت مشخص می‌کنید کدام برنامه‌های گوشی از تونل VPN استفاده کنند. پس از تغییر انتخاب‌ها، اتصال را یک‌بار قطع و دوباره برقرار کنید.'],
    ['آیا می‌توانم سرور موردعلاقه‌ام را ذخیره کنم؟','بله. با استفاده از گزینه موردعلاقه کنار سرور، می‌توانید آن را ذخیره کنید تا بعداً سریع‌تر به آن دسترسی داشته باشید.'],
    ['آیا Nova VPN اطلاعات شخصی من را ذخیره می‌کند؟','Nova VPN برای ساخت حساب، نام، شماره تلفن یا نشانی ایمیل شخصی از شما درخواست نمی‌کند و این اطلاعات هویتی را جمع‌آوری نمی‌کند. برای ارائه و مدیریت اتصال، ممکن است برخی داده‌های فنی ضروری مانند شناسه فنی نصب یا وضعیت اتصال پردازش شود. جزئیات در سیاست حفظ حریم خصوصی توضیح داده شده است.'],
    ['چگونه با پشتیبانی تماس بگیرم؟','از طریق ایمیل mynovavpnproxy@gmail.com با تیم پشتیبانی Nova VPN تماس بگیرید.'],
  ];
  static const enFaq = <List<String>>[
    ['How do I connect to the VPN?','Open the home screen, choose a country, and tap connect. The app will attempt to establish the connection.'],
    ['What if the VPN does not connect?','Choose another server, wait briefly, and try again. Check that your phone has a working internet connection.'],
    ['Why is my internet speed slow?','Speed depends on your internet connection, distance to the server, network congestion, and server conditions. A closer server may perform better.'],
    ['Which country should I choose?','Usually choose a server closer to your location or one that shows better speed and stability in the app.'],
    ['Is Nova VPN free?','Free features are provided under the service conditions. Advertisements may be displayed to help support operating costs.'],
    ['Why does the VPN disconnect?','A weak or interrupted internet connection, network changes, battery restrictions, or server instability may cause disconnections.'],
    ['What does automatic connection do?','It lets the app automatically select and try available servers to establish a connection.'],
    ['What is the two-hour timer for?','The timer shows the remaining connection time and automatically disconnects the VPN after two hours.'],
    ['What is per-app VPN routing?','It lets you choose which phone apps use the VPN tunnel. Disconnect and reconnect after changing your selection.'],
    ['Can I save favorite servers?','Yes. Use the favorite option beside a server to save it for quicker access later.'],
    ['Does Nova VPN store my personal information?','Nova VPN does not ask you for a name, phone number, or personal email address to create an account, and does not collect those identity details. Essential technical data, such as an installation identifier or connection status, may be processed to provide and manage the VPN connection. See the Privacy Policy for details.'],
    ['How can I contact support?','Contact the Nova VPN support team at mynovavpnproxy@gmail.com.'],
  ];

  String get privacyText => fa
    ? 'Nova VPN برای ساخت حساب کاربری، نام، شماره تلفن یا نشانی ایمیل شخصی از شما درخواست نمی‌کند و این اطلاعات هویتی را جمع‌آوری نمی‌کند.\n\nبرای ارائه و مدیریت اتصال VPN، ممکن است داده‌های فنی ضروری مانند شناسه فنی نصب یا دستگاه، وضعیت اتصال و اطلاعات فنی خطا پردازش شود. این داده‌ها برای عیب‌یابی، امنیت و عملکرد سرویس به کار می‌روند و با اطلاعات هویتی مانند نام یا شماره تلفن متفاوت‌اند.\n\nاز وارد کردن اطلاعات حساس در پیام‌های پشتیبانی خودداری کنید. برای پرسش‌های مربوط به حریم خصوصی می‌توانید به mynovavpnproxy@gmail.com ایمیل بزنید.\n\nاین توضیحات باید با شیوه واقعی پردازش داده‌ها در نسخه منتشرشده و زیرساخت سرور هماهنگ باشد.'
    : 'Nova VPN does not ask you for a name, phone number, or personal email address to create an account, and does not collect those identity details.\n\nTo provide and manage the VPN connection, essential technical data such as an installation or device identifier, connection status, and technical error information may be processed. This data supports troubleshooting, security, and service operation; it is different from identity details such as your name or phone number.\n\nPlease do not include sensitive information in support messages. For privacy questions, email mynovavpnproxy@gmail.com.\n\nThis notice must remain consistent with the actual data processing performed by the released app and its server infrastructure.';

  Future<void> contact(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: 'mynovavpnproxy@gmail.com', queryParameters: {'subject': 'Nova VPN Support'});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fa ? 'برنامه ایمیل در دسترس نیست. ایمیل: mynovavpnproxy@gmail.com' : 'No email app is available. Email: mynovavpnproxy@gmail.com')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = privacyOnly ? (fa ? 'سیاست حفظ حریم خصوصی' : 'Privacy Policy') : (fa ? 'سؤالات متداول' : 'Frequently Asked Questions');
    final questions = fa ? faFaq : enFaq;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, foregroundColor: fg, title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: privacyOnly
          ? [Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF34313D))), child: SelectableText(privacyText, style: TextStyle(color: fg, fontSize: 13, height: 1.8)))]
          : [
              Text(fa ? 'پاسخ پرسش‌های رایج درباره اتصال و امکانات Nova VPN' : 'Answers to common questions about Nova VPN connections and features.', style: TextStyle(color: muted, fontSize: 12, height: 1.6)),
              const SizedBox(height: 12),
              ...questions.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF34313D))),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    iconColor: const Color(0xFF4D91FF),
                    collapsedIconColor: muted,
                    title: Text((e.key + 1).toString() + '. ' + e.value[0], style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
                    children: [
                      Align(alignment: AlignmentDirectional.centerStart, child: Text(e.value[1], style: TextStyle(color: muted, fontSize: 12, height: 1.7))),
                      if (e.key == 11) Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: () => contact(context), icon: const Icon(Icons.mail_outline_rounded, size: 17), label: const Text('mynovavpnproxy@gmail.com'))),
                    ],
                  ),
                ),
              )),
            ],
      ),
    );
  }
}
