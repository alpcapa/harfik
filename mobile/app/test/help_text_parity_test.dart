// "Nasıl Oynanır?" metninin web ↔ port paritesi.
//
// NEDEN VAR: `help_modal.dart`ın başlığı "kural metinleri web'den BİREBİR
// kopyalanmıştır, özetlenmez" diyor — ama `legal_modals.dart`ta olduğu gibi
// bunu ZORLAYAN hiçbir şey yoktu. Orada bedeli ağırdı: web'in Gizlilik
// metni 10 Ağustos'ta düzeltildi, port ESKİ (ve artık yanlış) cümleyi dört
// gün daha taşıdı ve kullanıcıya kendi verisi hakkında gerçek olmayan bir
// şey söyledi (bkz. `legal_text_test.dart`). Aynı sınıf risk burada da
// duruyordu; 14 Ağustos 2026 denetiminde kapatıldı.
//
// NEDEN "Son güncelleme" VEKİLİ KULLANILMIYOR: `HelpModal.tsx`te öyle bir
// damga yok (hukuki metinlerin aksine). Onun yerine metnin YAPISI vekil
// alınıyor — bölüm başlıkları ve Hızlı Başlangıç maddeleri. Bunlar web'de
// makine-okunur bir biçimde duruyor (`<Section title="…">`,
// `<QuickItem icon="…">`) ve asıl korkulan hata sınıfını tam olarak
// yakalıyor: **web'e yeni bir bölüm/madde eklenip porta eklenmemesi.**
// Parça 66'da eklenen "Rütbeler ve Ödüller" bölümü tam bu şekilde
// kaçabilirdi.
//
// NE YAKALAMAZ (dürüst sınır): var olan bir paragrafın İÇİNDEKİ bir
// cümlenin değişmesi. Tam metin karşılaştırması JSX ↔ Dart arasında
// kırılgan olur (web cümleyi `<strong>`larla parçalıyor, port `**` ile
// işaretliyor; biri `{BINGO_BONUS}` diğeri `$bingoBonus` gömüyor). O
// ayrışma için elle denetim gerekiyor — 14 Ağustos denetiminde 11/11 bölüm,
// 9/9 madde ve paragrafların ezici çoğunluğu birebir çıktı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final web = File('../../src/components/HelpModal.tsx').readAsStringSync();
  final port = File('lib/src/ui/game/help_modal.dart').readAsStringSync();

  test('web\'deki HER bölüm başlığı portta da var', () {
    final titles = RegExp(r'<Section title="([^"]+)"')
        .allMatches(web)
        .map((m) => m.group(1)!)
        .toList();

    // Regex'in kendisi bir varsayım — web JSX'i yeniden düzenlenirse sessizce
    // 0 başlık bulup test "geçebilir". Alt sınır bunu engelliyor.
    expect(titles.length, greaterThanOrEqualTo(11),
        reason: 'web HelpModal.tsx\'te <Section title="…"> bulunamadı ya da '
            'beklenenden az — JSX yeniden düzenlendiyse bu testin regex\'i '
            'güncellenmeli (sessizce "geçmesin" diye alt sınır var).');

    for (final t in titles) {
      expect(port, contains("'$t'"),
          reason: 'Web\'de "$t" bölümü var, portta YOK. Kural metinleri '
              'birebir taşınmak zorunda — yeni bir bölüm eklenirse '
              'help_modal.dart da aynı PR\'da güncellenmeli.');
    }
  });

  test('web\'deki HER Hızlı Başlangıç maddesi portta da var', () {
    final icons = RegExp(r'<QuickItem icon="([^"]+)">')
        .allMatches(web)
        .map((m) => m.group(1)!)
        .toList();

    expect(icons.length, greaterThanOrEqualTo(9),
        reason: 'web HelpModal.tsx\'te <QuickItem icon="…"> bulunamadı ya da '
            'beklenenden az — regex güncellenmeli.');

    for (final icon in icons) {
      expect(port, contains(icon),
          reason: 'Web\'in Hızlı Başlangıç listesinde $icon maddesi var, '
              'portta YOK.');
    }
  });

  test('rütbe tablosu ELLE yazılmıyor — iki taraf da kendi listesinden çiziyor',
      () {
    // Dördüncü bir elle senkron kopya açmamak bilinçli bir karar (tablo zaten
    // SQL ↔ leagueRank.ts ↔ league_rank.dart olarak ÜÇ kopya). Biri bu ekrana
    // sabit bir tablo yazarsa eşik/ödül değişiminde ilk sessizce ayrışacak yer
    // orası olur.
    expect(web, contains('RANK_TIERS'),
        reason: 'web "Rütbeler ve Ödüller" tablosunu RANK_TIERS\'ten '
            'çizmeli, elle yazmamalı.');
    expect(port, contains('kRankTiers'),
        reason: 'port aynı tabloyu kRankTiers\'ten çizmeli.');
  });

  test('bingo bonusu iki tarafta da motordan okunuyor, sabit yazılmıyor', () {
    expect(web, contains('BINGO_BONUS'));
    expect(port, contains('bingoBonus'));
  });
}
