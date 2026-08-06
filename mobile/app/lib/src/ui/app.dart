// Kök widget — sürüm kapısına göre ya güncelleme ekranı ya uygulama.
import 'package:flutter/material.dart';

import '../bootstrap.dart';
import '../config/version_gate.dart';
import 'home_screen.dart';
import 'update_required_screen.dart';

class KelimekiApp extends StatelessWidget {
  final AppServices services;
  const KelimekiApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimeki',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0891B2)),
        useMaterial3: true,
        // Web tailwind fontFamily.sans = Space Grotesk; sayfa zemini web'de
        // BEYAZ (colors.bg) — soluk gri değil (gölge dengesi buna bağlı,
        // kullanıcı karşılaştırması 6 Ağustos 2026).
        fontFamily: 'SpaceGrotesk',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: services.versionGate == VersionGateStatus.updateRequired
          ? const UpdateRequiredScreen()
          : HomeScreen(services: services),
    );
  }
}
