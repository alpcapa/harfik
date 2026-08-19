// Renk paritesi — web'in `tailwind.config.js`'i KANONİK kaynaktır.
//
// Parça 54'ün regresyon koruması. Denetimde bulunan hata sınıfı şuydu: her
// dosya kendi `const Color _muted = ...` kopyasını taşıyordu ve bu kopyalar
// sessizce ayrıştı — `_red` iki farklı değere (#DC2626 / #E0483A), `_green`
// de öyle (#16A34A / #1FA05C) bölünmüştü. Ne derleyici ne widget testleri
// bunu görebiliyordu: iki değer de geçerli bir renk.
//
// Buradaki iki test o sınıfı YAPISAL olarak kapatıyor:
//  1) `tokens.dart` gerçekten tailwind paletiyle aynı mı (web bir rengi
//     değiştirirse port'un sessizce eski değerde kalmasını yakalar);
//  2) `lib/` altında token değerini TEKRAR YAZAN bir literal kaldı mı
//     (yeni bir yerel kopya açılmasını yakalar).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/tokens.dart';

/// Repo kökü — testler `mobile/app`'ten koşuyor.
final _root = Directory.current.path.endsWith('mobile/app')
    ? Directory('../..')
    : Directory('.');

/// `tailwind.config.js`'ten `ad: '#RRGGBB'` çiftlerini okur.
Map<String, int> _tailwindColors() {
  final src = File('${_root.path}/tailwind.config.js').readAsStringSync();
  final block = RegExp(r'colors:\s*\{(.*?)\n\s{6}\}', dotAll: true)
      .firstMatch(src)
      ?.group(1);
  expect(block, isNotNull,
      reason: 'tailwind.config.js içinde colors bloğu bulunamadı — '
          'dosyanın yapısı değiştiyse bu testin ayrıştırıcısı da güncellenmeli');
  final out = <String, int>{};
  for (final m
      in RegExp(r"'?([\w-]+)'?:\s*'#([0-9A-Fa-f]{6})'").allMatches(block!)) {
    out[m.group(1)!] = int.parse('FF${m.group(2)!}', radix: 16);
  }
  return out;
}

void main() {
  test('tokens.dart tailwind.config.js ile birebir aynı', () {
    final tw = _tailwindColors();
    // Portun kullandığı 11 token — web'de daha fazlası var (tile-* gibi,
    // porta ayrı yollardan girmişler); burada yalnızca tokens.dart'ın
    // iddia ettiği eşleşmeler doğrulanıyor.
    final claimed = <String, int>{
      'bg': kBg.toARGB32(),
      'panel': kPanel.toARGB32(),
      'border': kBorder.toARGB32(),
      'text': kText.toARGB32(),
      'muted': kMuted.toARGB32(),
      'accent': kAccent.toARGB32(),
      'gold': kGold.toARGB32(),
      'orange': kOrange.toARGB32(),
      'green': kGreen.toARGB32(),
      'red': kRed.toARGB32(),
      'void': kVoid.toARGB32(),
      // Parça 62: k-lig'in üç üst kademesi (Efsane/Uzaylı/Kozmik).
      'indigo': kIndigo.toARGB32(),
      'cyan': kCyan.toARGB32(),
      'gold-bright': kGoldBright.toARGB32(),
      // Parça 61: k-lig'in ilk kademesi (Çaylak) bu değeri taşıyor, yani
      // artık taşın dışında da kullanılıyor. Aşağıdaki "yerel kopya"
      // taramasına BİLEREK eklenmedi — gerekçe tokens.dart'ta yazılı.
      'tile-pts': kTilePts.toARGB32(),
    };
    for (final e in claimed.entries) {
      expect(tw[e.key], isNotNull,
          reason: '"${e.key}" tailwind.config.js\'te yok');
      expect(e.value, tw[e.key],
          reason: '"${e.key}" web ile ayrışmış — tailwind.config.js kanonik, '
              'tokens.dart ona uydurulmalı');
    }
  });

  test('lib/ altında token değerini tekrar yazan literal yok', () {
    // Bilinçli istisnalar:
    //  - tokens.dart      : tanımın kendisi;
    //  - player_colors.dart: oyuncu paleti AYRI bir kaynaktan gelir
    //    (`src/game/constants.ts`'teki PLAYER_COLORS) — iki değeri tesadüfen
    //    token'la aynı (#DC2626, #16A34A) ama anlamı farklı;
    //  - beyaz (#FFFFFF): `bg` ve `tile-bg` AYNI değere sahip, hangi token
    //    olduğu literalden anlaşılamaz — bu tarama beyazı hiç sorgulamaz.
    const skip = {'tokens.dart', 'player_colors.dart'};
    final values = <int, String>{
      kPanel.toARGB32(): 'kPanel',
      kBorder.toARGB32(): 'kBorder',
      kText.toARGB32(): 'kText',
      kMuted.toARGB32(): 'kMuted',
      kAccent.toARGB32(): 'kAccent',
      kGold.toARGB32(): 'kGold',
      kOrange.toARGB32(): 'kOrange',
      kGreen.toARGB32(): 'kGreen',
      kRed.toARGB32(): 'kRed',
      kVoid.toARGB32(): 'kVoid',
      kIndigo.toARGB32(): 'kIndigo',
      kCyan.toARGB32(): 'kCyan',
      kGoldBright.toARGB32(): 'kGoldBright',
    };
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (skip.contains(f.uri.pathSegments.last)) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)').allMatches(src)) {
        final v = int.parse(m.group(1)!, radix: 16);
        final token = values[v];
        if (token != null) offenders.add('${f.path}: 0x${m.group(1)} → $token');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Bu literaller tokens.dart\'taki sabitle AYNI değerde — '
            'yerel kopya açmak yerine token kullanılmalı (yoksa ikisi zamanla '
            'sessizce ayrışır, Parça 54\'te tam bu oldu):\n${offenders.join('\n')}');
  });

  test('tahtanın hamle renkleri token DEĞİL, yalnızca üç yerde', () {
    // `Board.tsx` `#1FA05C`/`#E0483A`'yı BİLİNÇLİ olarak sabit yazıyor —
    // token yeşili/kırmızısı değiller. Meşru kullanım: tahtanın dış hattı +
    // puan rozeti (board_widget) ve iki oyun ekranının sürükleme çerçevesi.
    // Buraya bir dördüncüsü eklenirse büyük ihtimalle token'la karıştırılmış
    // bir sapmadır (denetimde bulunan hatanın ta kendisi).
    expect(kMoveValid.toARGB32(), 0xFF1FA05C);
    expect(kMoveInvalid.toARGB32(), 0xFFE0483A);

    final users = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.uri.pathSegments.last == 'tokens.dart') continue;
      final src = f.readAsStringSync();
      if (src.contains('kMoveValid') || src.contains('kMoveInvalid')) {
        users.add(f.uri.pathSegments.last);
      }
    }
    expect(users, {
      'board_widget.dart',
      'game_screen.dart',
      'online_game_screen.dart',
    });
  });
}
