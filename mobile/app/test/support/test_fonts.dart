// flutter_test, pubspec'te bildirilen fontları OTOMATİK YÜKLEMEZ — varsayılan
// Ahem tüm metinleri blok çizer (6 Ağustos 2026'da ekran görüntüleri bir an
// tamamen bloklara dönünce öğrenildi). Ekran görüntüsü üreten testler
// uygulamanın GERÇEK fontlarını (Nunito/SpaceGrotesk/SpaceMono) asset
// dosyalarından FontLoader'la yükler.
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> _loadFamily(String family, List<String> assetPaths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in assetPaths) {
    final f = File(p);
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      any = true;
    }
  }
  if (any) await loader.load();
}

/// Uygulamanın üç font ailesini yükler (web tailwind eşlenikleri).
Future<void> loadAppFonts() async {
  await _loadFamily('Nunito', ['assets/fonts/Nunito-ExtraBold.ttf']);
  await _loadFamily('SpaceGrotesk', [
    'assets/fonts/SpaceGrotesk-Regular.ttf',
    'assets/fonts/SpaceGrotesk-Medium.ttf',
    'assets/fonts/SpaceGrotesk-SemiBold.ttf',
    'assets/fonts/SpaceGrotesk-Bold.ttf',
  ]);
  await _loadFamily('SpaceMono', [
    'assets/fonts/SpaceMono-Regular.ttf',
    'assets/fonts/SpaceMono-Bold.ttf',
  ]);
}

/// Eski ad — çağıranlar için geriye dönük sarmalayıcı (SDK Roboto'suna artık
/// gerek yok; uygulama fontları yükleniyor).
Future<void> loadRobotoIfAvailable() => loadAppFonts();
