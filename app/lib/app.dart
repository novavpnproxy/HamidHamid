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
        home: const SplashScreen(),
      );
}
