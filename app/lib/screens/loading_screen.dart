import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/nova_animations.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _timer;
  bool _lightTheme = false;

  @override
  void initState() {
    super.initState();
    StorageService().readLightTheme().then((value) {
      if (mounted) setState(() => _lightTheme = value);
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _lightTheme ? const Color(0xFFF2F7FF) : const Color(0xFF091321),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _lightTheme
                  ? const [Color(0xFFF9FCFF), Color(0xFFEAF3FF), Color(0xFFDCEBFF)]
                  : const [Color(0xFF101A2B), Color(0xFF091321), Color(0xFF07101C)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: NovaWordParticleAnimation(
                          width: MediaQuery.sizeOf(context).width - 36,
                          lightTheme: _lightTheme,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'NOVA VPN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _lightTheme ? const Color(0xFF173B65) : const Color(0xFFF7FBFF),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.2,
                      shadows: [
                        Shadow(color: Color(0xFF42DFFF), blurRadius: 12),
                        Shadow(color: Color(0xFF4D7CFF), blurRadius: 24),
                        Shadow(color: Color(0xFFFFFFFF), blurRadius: 5),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'اتصال هوشمند، سریع و امن',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: const Color(0xFFFF4655),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Color(0xFFFF2638), blurRadius: 14),
                        Shadow(color: Color(0x99FF2638), blurRadius: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  NovaOrbitNAnimation(size: 112, lightTheme: _lightTheme),
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 92,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      backgroundColor: Color(0xFF1D2B49),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF35A8FF),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  const _LoadingBrandFooter(),
                ],
              ),
            ),
          ),
        ),
      );
}


class _LoadingBrandFooter extends StatelessWidget {
  const _LoadingBrandFooter();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('30071366', textDirection: TextDirection.ltr,
              style: TextStyle(color: Color(0xFF36B9FF), fontSize: 14,
                  fontWeight: FontWeight.w900, letterSpacing: 2.2)),
          SizedBox(height: 3),
          Text('4.6.6.0', textDirection: TextDirection.ltr,
              style: TextStyle(color: Color(0xFF36B9FF), fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ]),
      );
}
