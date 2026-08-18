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

/// Material ikon fontu SDK önbelleğinde yaşar, uygulama asset'i değildir —
/// yüklenmezse `Icons.*` (joker yıldızı, modal ✕, YZ robotu) ekran
/// görüntülerinde boş kutuya döner. Gerçek cihazda sorun yok; bu yalnızca
/// görüntülerin temsili olması için (6 Ağustos 2026, hamle geçmişi
/// parçasında fark edildi).
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/root/flutter';
  await _loadFamily('MaterialIcons',
      ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

/// Emoji de uygulama asset'i DEĞİL — platform sağlar (iOS Apple Color Emoji,
/// Android Noto Color Emoji). Test ortamında yoksa kurallar ekranındaki
/// 🎯🏠🔗… ikonları boş kutuya döner; ekran görüntüsü temsili olsun diye
/// SDK'nın/konteynerin Noto Color Emoji'si yüklenir (Material ikonlarındaki
/// aynı ders).
Future<void> _loadEmoji() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/root/flutter';
  await _loadFamily('Noto Color Emoji', [
    '$root/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  ]);
}

/// Uygulamanın üç font ailesini (web tailwind eşlenikleri) + Material
/// ikonlarını + emoji yükler.
Future<void> loadAppFonts() async {
  await _loadMaterialIcons();
  await _loadEmoji();
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
  // Yalnızca k-lig rütbe rozetinde kullanılıyor — yüklenmezse mührün harfi
  // Ahem bloğuna döner ve mürekkep-ortalama testi (rank_seal) anlamsızlaşır.
  await _loadFamily('MPlusRounded1c',
      ['assets/fonts/MPLUSRounded1c-ExtraBold-subset.ttf']);
}

/// Eski ad — çağıranlar için geriye dönük sarmalayıcı (SDK Roboto'suna artık
/// gerek yok; uygulama fontları yükleniyor).
Future<void> loadRobotoIfAvailable() => loadAppFonts();
