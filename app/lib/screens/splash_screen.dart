import 'dart:async';

import 'package:flutter/material.dart';

import 'loading_screen.dart';
import '../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;
  bool _lightTheme = false;

  @override
  void initState() {
    super.initState();
    StorageService().readLightTheme().then((value) {
      if (mounted) setState(() => _lightTheme = value);
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: .90, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Keep the logo page, then show the dedicated four-second loading page.
    _timer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoadingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _lightTheme ? const Color(0xFFF2F7FF) : const Color(0xFF091321),
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _lightTheme
                  ? const [Color(0xFFF9FCFF), Color(0xFFEAF3FF), Color(0xFFDCEBFF)]
                  : const [Color(0xFF101A2B), Color(0xFF091321), Color(0xFF07101C)],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Image.asset(
                      'assets/brand/nova_logo_new.jpg',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'JEYRAN GROUP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.2,
                        color: const Color(0xFFFF454F),
                        shadows: [
                          Shadow(color: Color(0xCCFF2638), blurRadius: 16),
                          Shadow(color: Color(0x99FF2638), blurRadius: 26),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اینترنت آزاد را با ما تجربه کنید',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF168DCE),
                        shadows: [
                          Shadow(color: Color(0x66249FFF), blurRadius: 13),
                        ],
                      ),
                    ),
                    const Spacer(flex: 4),
                    _SplashBrandFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}


class _SplashBrandFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('30071366', textDirection: TextDirection.ltr,
                style: TextStyle(color: Color(0xFF36B9FF), fontSize: 14,
                    fontWeight: FontWeight.w900, letterSpacing: 2.2)),
            SizedBox(height: 3),
            Text('4.6.6.0', textDirection: TextDirection.ltr,
                style: TextStyle(color: Color(0xFF36B9FF), fontSize: 12,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ],
        ),
      );
}
