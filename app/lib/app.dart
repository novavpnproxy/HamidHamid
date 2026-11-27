import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

class NovaVpnApp extends StatelessWidget {
  const NovaVpnApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NOVA VPN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
            surface: const Color(0xFF101A2B),
          ),
          scaffoldBackgroundColor: const Color(0xFF091321),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF091321),
            elevation: 0,
          ),
        ),
        // Keep the ownership mark visible on every route and future screen.
        builder: (context, child) => Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 5),
                child: Text(
                  '30071366',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Color(0xFFFFD43B),
                    shadows: [
                      Shadow(
                        color: Color(0x99FFB300),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        home: const SplashScreen(),
      );
