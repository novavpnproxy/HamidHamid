import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NovaHelpScreen extends StatelessWidget {
  const NovaHelpScreen({super.key, required this.language, required this.lightTheme, this.privacyOnly = false, this.termsOnly = false});
  final String language;
  final bool lightTheme;
  final bool privacyOnly;
  final bool termsOnly;
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
    ? 'Nova VPN برای ساخت حساب کاربری، نام، شماره تلفن یا ایمیل شخصی از شما درخواست نمی‌کند. برنامه یک شناسه تصادفی و پایدار برای نصب ایجاد می‌کند و آن را در فضای امن دستگاه نگه می‌دارد. هنگام ثبت دستگاه، این شناسه به سرور Nova ارسال می‌شود. سرور آن را همراه زمان اولین و آخرین مراجعه و وضعیت مجاز یا مسدود بودن دستگاه در پایگاه داده نگه می‌دارد. از همین شناسه برای شناسایی نصب شما نزد سرویس زیرساخت VPN یعنی Vox نیز استفاده می‌شود.\n\nبرای دریافت تنظیمات اتصال، اطلاعاتی مانند شناسه نصب، کشور/موقعیت انتخابی، پروتکل و شماره دستگاه به سرویس Vox فرستاده می‌شود. ترافیکی که از تونل VPN عبور می‌دهید از زیرساخت سرور VPN عبور می‌کند؛ بنابراین ارائه‌دهنده زیرساخت و شبکه و شرکت‌های میزبان آن ممکن است نشانی IP و فراداده‌های فنی اتصال را طبق سامانه‌ها و سیاست‌های خود پردازش کنند. کد فعلی Nova در پایگاه داده برنامه، محتوای صفحات وب یا تاریخچه مرور شما را ذخیره نمی‌کند؛ اما این موضوع به معنی ناشناس‌بودن کامل در برابر ارائه‌دهنده سرور، وب‌سایت مقصد یا شرکت میزبان نیست.\n\nسرویس Nova روی زیرساخت میزبانی و پایگاه داده شخص ثالث اجرا می‌شود؛ این شرکت‌ها ممکن است داده‌های فنی درخواست‌ها و گزارش‌های عملیاتی را برای امنیت و نگهداری سرویس پردازش کنند. زمان نگهداری و جزئیات گزارش‌های زیرساختی تابع تنظیمات و سیاست‌های همان ارائه‌دهندگان است و در کد برنامه به‌طور کامل قابل تعیین نیست.\n\nدر نسخه فعلی، کد برنامه شامل SDK تبلیغاتی موبایل نیست. اگر تبلیغات یا پیوندهای تبلیغاتی شخص ثالث در نسخه‌ای فعال شوند، آن ارائه‌دهنده ممکن است هنگام نمایش یا بازشدن تبلیغ، داده‌های فنی مانند IP، شناسه‌های تبلیغاتی یا اطلاعات تعامل را طبق سیاست خودش دریافت کند. پیش از فعال‌سازی چنین تبلیغاتی باید نام ارائه‌دهنده و سیاست مربوط اعلام شود.\n\nاز ارسال اطلاعات حساس در پیام‌های پشتیبانی خودداری کنید. برای پرسش‌های حریم خصوصی با mynovavpnproxy@gmail.com تماس بگیرید.'
    : 'Nova VPN does not ask you for a name, phone number, or personal email address to create an account. The app creates a random, persistent installation identifier and stores it in the device secure storage. When the device registers, this identifier is sent to Nova’s server. The server stores it in its database together with the first-seen time, last-seen time, and whether the device is enabled or blocked. The same identifier is used to identify your installation with Vox, the VPN infrastructure service.\n\nTo obtain connection profiles, information such as the installation identifier, selected country/location, protocol, and device number is sent to Vox. Traffic routed through the VPN tunnel passes through the VPN server infrastructure. The infrastructure and network provider, and their hosting providers, may therefore process your IP address and technical connection metadata under their own systems and policies. The current Nova application code does not store the content of web pages or your browsing history in the app database; this does not mean you are fully anonymous to the server provider, destination websites, or hosting companies.\n\nNova runs on third-party hosting and database infrastructure. Those providers may process technical request data and operational logs for security and service maintenance. Log retention and the exact contents of infrastructure logs depend on those providers’ settings and policies and cannot be fully determined from the app code.\n\nThe current app code does not include a mobile advertising SDK. If third-party ads or advertising links are enabled in a future version, the advertising provider may receive technical data such as IP address, advertising identifiers, or interaction data when an ad is displayed or opened, subject to its own policy. The provider and relevant policy should be disclosed before such ads are enabled.\n\nPlease do not send sensitive information in support messages. For privacy questions, contact mynovavpnproxy@gmail.com';

  String get termsText => fa
    ? '''به Nova VPN خوش آمدید. با نصب، باز کردن یا استفاده از برنامه، این شرایط را می‌پذیرید. اگر با آن‌ها موافق نیستید، از برنامه استفاده نکنید.

۱. ماهیت سرویس
Nova VPN ابزاری برای ایجاد اتصال VPN و عبور دادن بخشی از ترافیک اینترنت دستگاه از سرورهای در دسترس برنامه است. دسترسی به سرورها و امکانات ممکن است با توجه به وضعیت فنی، ظرفیت، نگهداری یا محدودیت‌های شبکه تغییر کند.

۲. استفاده مجاز
شما متعهد هستید از برنامه برای فعالیت‌های غیرقانونی، نقض حقوق دیگران، کلاهبرداری، انتشار بدافزار، حمله یا اختلال در سامانه‌ها، ارسال هرزنامه یا دور زدن تدابیر امنیتی با هدف آسیب‌رسانی استفاده نکنید. مسئولیت فعالیت‌هایی که از طریق دستگاه و اتصال شما انجام می‌شود بر عهده خود شماست.

۳. دسترسی و پایداری
برای سرویس، سرعت، دسترس‌پذیری یا اتصال بدون وقفه تضمین نمی‌شود. ممکن است اتصال به دلیل وضعیت اینترنت شما، سرور، تعمیرات یا عوامل خارج از کنترل ما قطع یا محدود شود. در صورت امکان، برای رفع مشکل سرور دیگری را امتحان کنید.

۴. حریم خصوصی و داده‌های فنی
برای جزئیات داده‌هایی که ممکن است هنگام استفاده پردازش شوند، صفحه «سیاست حفظ حریم خصوصی» را بخوانید. این شرایط جایگزین آن سیاست نیست.

۵. تبلیغات و اشتراک
برخی امکانات ممکن است رایگان و همراه با تبلیغات ارائه شوند. قابلیت خرید اشتراک در حال حاضر فعال نیست. اگر در آینده اشتراک یا پرداختی ارائه شود، قیمت، مدت، امکانات و شرایط آن پیش از خرید جداگانه اعلام خواهد شد.

۶. تغییر یا توقف سرویس
ممکن است برای نگهداری، امنیت، بهبود یا دلایل فنی، بخش‌هایی از برنامه یا سرویس تغییر کنند، موقتاً متوقف شوند یا در آینده ارائه نشوند.

۷. مسئولیت و محدودیت‌ها
شما باید قوانین قابل‌اعمال در محل استفاده خود را رعایت کنید. Nova VPN مجوزی برای انجام فعالیت غیرقانونی ایجاد نمی‌کند. تا حدی که قانون اجازه می‌دهد، سرویس بدون تضمین‌های صریح یا ضمنی ارائه می‌شود و مسئولیت خسارت‌های ناشی از استفاده نادرست، قطع اینترنت یا عوامل خارج از کنترل سرویس بر عهده ارائه‌دهنده نیست.

۸. تغییر شرایط و تماس
ممکن است این شرایط به‌روزرسانی شوند؛ نسخه جدید در همین صفحه منتشر می‌شود. ادامه استفاده پس از انتشار تغییرات به معنی پذیرش نسخه به‌روز‌شده است. برای پرسش یا گزارش مشکل با mynovavpnproxy@gmail.com تماس بگیرید.

تاریخ آخرین به‌روزرسانی: ۲۸ نوامبر ۲۰۲۶'''
    : '''Welcome to Nova VPN. By installing, opening, or using the app, you agree to these terms. If you do not agree, do not use the app.

1. Service description
Nova VPN is a tool that creates a VPN connection and routes some of your device’s internet traffic through servers made available by the app. Server and feature availability may change due to technical conditions, capacity, maintenance, or network restrictions.

2. Acceptable use
You agree not to use the app for unlawful activity, infringement of others’ rights, fraud, malware distribution, attacks or disruption of systems, spam, or bypassing security measures for harmful purposes. You are responsible for activity carried out through your device and connection.

3. Availability and performance
No guarantee is made regarding speed, availability, or uninterrupted connectivity. Connections may be interrupted or limited by your internet service, server conditions, maintenance, or factors beyond our control. If needed, try another available server.

4. Privacy and technical data
For details about data that may be processed when using the app, read the Privacy Policy page. These terms do not replace that policy.

5. Ads and subscriptions
Some features may be provided free of charge and supported by advertising. Subscription purchases are not currently enabled. If subscriptions or payments are introduced later, their price, duration, features, and conditions will be disclosed before purchase.

6. Changes or discontinuation
Parts of the app or service may be changed, temporarily suspended, or discontinued for maintenance, security, improvement, or technical reasons.

7. Responsibility and limitations
You must comply with laws applicable where you use the service. Nova VPN does not authorize unlawful activity. To the extent permitted by law, the service is provided without express or implied warranties, and the provider is not responsible for harm caused by misuse, internet outages, or factors outside the service’s control.

8. Changes and contact
These terms may be updated; the latest version will be published on this page. Continued use after changes are published means you accept the updated terms. For questions or problem reports, contact mynovavpnproxy@gmail.com.

Last updated: November 28, 2026''';

  Future<void> contact(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: 'mynovavpnproxy@gmail.com', queryParameters: {'subject': 'Nova VPN Support'});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fa ? 'برنامه ایمیل در دسترس نیست. ایمیل: mynovavpnproxy@gmail.com' : 'No email app is available. Email: mynovavpnproxy@gmail.com')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = privacyOnly ? (fa ? 'سیاست حفظ حریم خصوصی' : 'Privacy Policy') : (termsOnly ? (fa ? 'شرایط استفاده از خدمات' : 'Terms of Service') : (fa ? 'سؤالات متداول' : 'Frequently Asked Questions'));
    final questions = fa ? faFaq : enFaq;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, foregroundColor: fg, title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: privacyOnly || termsOnly
          ? [Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF34313D))), child: SelectableText(termsOnly ? termsText : privacyText, style: TextStyle(color: fg, fontSize: 13, height: 1.8)))]
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
                    title: Text('${e.key + 1}. ${e.value[0]}', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
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
