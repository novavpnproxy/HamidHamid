import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';
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
    _scale = Tween<double>(begin: .94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Show one complete branded splash for four seconds, then open the app.
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  TextStyle _neonStyle({
    required double fontSize,
    required Color color,
    required double letterSpacing,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: letterSpacing,
        color: color,
        shadows: [
          Shadow(color: color.withValues(alpha: .95), blurRadius: 9),
          Shadow(color: color.withValues(alpha: .75), blurRadius: 20),
          Shadow(color: color.withValues(alpha: .48), blurRadius: 34),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor:
            _lightTheme ? const Color(0xFFF2F7FF) : const Color(0xFF071321),
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _lightTheme
                  ? const [
                      Color(0xFFF9FCFF),
                      Color(0xFFEAF3FF),
                      Color(0xFFDCEBFF),
                    ]
                  : const [
                      Color(0xFF101A2B),
                      Color(0xFF091321),
                      Color(0xFF050D18),
                    ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    Text(
                      'NOVA VPN',
                      textAlign: TextAlign.center,
                      style: _neonStyle(
                        fontSize: 27,
                        color: const Color(0xFF38CFFF),
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(38),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38CFFF)
                                .withValues(alpha: .40),
                            blurRadius: 38,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFFF33)
                                .withValues(alpha: .22),
                            blurRadius: 52,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/brand/nova_logo_new.jpg',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'JEYRAN GROUP',
                      textAlign: TextAlign.center,
                      style: _neonStyle(
                        fontSize: 20,
                        color: const Color(0xFFFF4655),
                        letterSpacing: 2.8,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      'اینترنت آزاد را با هم تجربه کنیم',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: _neonStyle(
                        fontSize: 16,
                        color: const Color(0xFF38CFFF),
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(flex: 2),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '30071366',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: Color(0xFF38CFFF),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF38CFFF),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '4.6.6.0',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: Color(0xFFFFFF33),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFFF33),
                                  blurRadius: 13,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
