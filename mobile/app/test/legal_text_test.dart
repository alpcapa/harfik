// Hukuki metinlerin web ↔ port tazeliği.
//
// NEDEN VAR (13 Ağustos 2026 denetimi): `legal_modals.dart`ın başlığı
// "METİNLER WEB'DEN BİREBİR KOPYALANMIŞTIR … web metni değişirse buraya da
// aynen taşınmalı" diyor — ama bunu ZORLAYAN hiçbir şey yoktu ve gerçekten
// kaçtı: 10 Ağustos 2026'da `game_chat_archive_participants_only`
// migration'ı sohbet arşivini katılımcı+admin'e kilitledi, web'in Gizlilik
// Politikası buna göre düzeltildi ("YALNIZCA o oyunun katılımcılarına …"),
// port ise ESKİ ve artık YANLIŞ olan "tüm kayıtlı kullanıcılara açık"
// cümlesini taşımaya devam etti. Yani uygulama kullanıcıya kendi verisi
// hakkında gerçek olmayan bir şey söylüyordu.
//
// Tam metin karşılaştırması kırılgan olurdu (satır kaydırma/kaçış farkları),
// bu yüzden test web'in KENDİ "Son güncelleme" tarihini kaynak dosyadan
// okuyup portunkiyle karşılaştırıyor: web metni her değiştiğinde o tarih de
// değişiyor (projenin yerleşik disiplini), dolayısıyla bu tek alan
// "port bayat mı?" sorusunun güvenilir vekili. `color_tokens_test.dart`ın
// tailwind'i okuyan deseninin aynısı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `Son güncelleme: 10 Ağustos 2026` → `10 Ağustos 2026`
String? _lastUpdated(String source) {
  final m = RegExp(r'Son güncelleme:\s*([0-9]{1,2}\s+\p{L}+\s+[0-9]{4})',
          unicode: true)
      .firstMatch(source);
  return m?.group(1);
}

void main() {
  final port = File('lib/src/ui/auth/legal_modals.dart').readAsStringSync();

  // Portta iki tarih var (Koşullar önce, Gizlilik sonra) — sırayla.
  final portDates = RegExp(r'Son güncelleme:\s*([0-9]{1,2}\s+\p{L}+\s+[0-9]{4})',
          unicode: true)
      .allMatches(port)
      .map((m) => m.group(1))
      .toList();

  test('Kullanım Koşulları: portun "Son güncelleme" tarihi web ile aynı', () {
    final web =
        File('../../src/components/TermsModal.tsx').readAsStringSync();
    expect(_lastUpdated(web), isNotNull,
        reason: 'web TermsModal.tsx içinde "Son güncelleme" bulunamadı — '
            'metin yeniden düzenlendiyse bu testin regex\'i güncellenmeli');
    expect(portDates.first, _lastUpdated(web),
        reason: 'Web Kullanım Koşulları güncellenmiş ama port almamış. '
            'legal_modals.dart web metnini BİREBİR taşımak zorunda.');
  });

  test('Gizlilik Politikası: portun "Son güncelleme" tarihi web ile aynı', () {
    final web =
        File('../../src/components/PrivacyModal.tsx').readAsStringSync();
    expect(_lastUpdated(web), isNotNull);
    expect(portDates.last, _lastUpdated(web),
        reason: 'Web Gizlilik Politikası güncellenmiş ama port almamış — '
            '10 Ağustos 2026\'da tam bu şekilde kaçtı (sohbet arşivi '
            'görünürlüğü katılımcıya kilitlendi, port eski cümleyi taşımaya '
            'devam etti).');
  });

  test('sohbet arşivi görünürlüğü: port ARTIK YANLIŞ olan cümleyi taşımıyor',
      () {
    // Bu iddia tarihten bağımsız olarak da korunmalı: sunucu 10 Ağustos'tan
    // beri arşivi katılımcı+admin'e kilitliyor (`game_chat_archive`).
    expect(port, contains('YALNIZCA o oyunun'),
        reason: 'Gizlilik metni sohbet arşivinin yalnızca katılımcılara ve '
            'yönetici ekibine açık olduğunu söylemeli.');
    expect(port.contains('skor/tahta görünürlüğüyle aynı şekilde'), isFalse,
        reason: 'Eski (ve artık yanlış) "tüm kayıtlı kullanıcılara açık" '
            'ifadesi hâlâ portta.');
  });
}
