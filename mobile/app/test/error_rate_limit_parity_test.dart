// Hata telemetrisinin HIZ SINIRI sayıları — web ↔ port ELLE SENKRON, web
// KANONİK kaynaktır (`layout_parity_test.dart` ile aynı desen).
//
// NEDEN VAR (31 Ağustos 2026, ROADMAP #10): sınır süreç ömründen ZAMAN
// penceresine taşındı. ROADMAP'in kendi tuzak listesi bunu adıyla söylüyordu:
// *"İKİ istemci birden — biri değişip öteki kalırsa web ile app farklı
// davranır."* Sayı çifti derleyicinin göremeyeceği bir değişmez; tek koruma
// bu test.
//
// ⚠ DÖRT KOPYA karşılaştırılıyor, iki değil. Üretim sayıları testlerde de
// tekrarlanıyor (web betiğinde `PENCERE_MS`, Dart testinde `_pencere`) —
// üretimde pencere değişip testtekiler kalırsa testler YANLIŞ bir şeyi
// doğrulamaya devam ederdi. Bu projenin kayıtlı dersi: bir sayının kaydı
// birden çok yerde durursa biri güncellenirken öteki kalır.
//
// ⚠ EN ÖNEMLİ KURAL: bir değer BULUNAMAZSA test DÜŞER, geçmez (`pick`
// bunu zorluyor) — "yeşil ama hiçbir şey kanıtlamayan" test olmasın diye.
import 'package:flutter_test/flutter_test.dart';

import 'support/web_source.dart';

/// `60 * 60 * 1000` gibi bir çarpım ifadesini sayıya çevirir. Kaynakta düz bir
/// sayı yerine çarpım DURUYOR çünkü okunurluğu ondan geliyor; testin sayıyı
/// yeniden yazması yerine ifadeyi çözmesi doğru olanı.
int _carpim(String ifade) =>
    ifade.split('*').map((p) => int.parse(p.trim())).reduce((a, b) => a * b);

void main() {
  final webKaynak = readRepoFile('src/utils/errorReporting.ts');
  final dartKaynak =
      readRepoFile('mobile/app/lib/src/data/error_reporter.dart');
  final webBetik = readRepoFile('scripts/verify-error-reporting.ts');
  final dartTest =
      readRepoFile('mobile/app/test/error_reporter_test.dart');

  test('pencere başına kayıt tavanı web ile aynı', () {
    final web = int.parse(pick(
      webKaynak,
      RegExp(r'const MAX_PER_WINDOW = (\d+);'),
      'errorReporting.ts içinde MAX_PER_WINDOW',
    ));
    final port = int.parse(pick(
      dartKaynak,
      RegExp(r'const int _maxPerWindow = (\d+);'),
      'error_reporter.dart içinde _maxPerWindow',
    ));
    expect(port, web);
  });

  test('pencere uzunluğu web ile aynı', () {
    final web = _carpim(pick(
      webKaynak,
      RegExp(r'const WINDOW_MS = ([\d* ]+);'),
      'errorReporting.ts içinde WINDOW_MS',
    ));
    final port = _carpim(pick(
      dartKaynak,
      RegExp(r'const int _windowMs = ([\d* ]+);'),
      'error_reporter.dart içinde _windowMs',
    ));
    expect(port, web);

    // Testlerdeki kopyalar da aynı pencereyi anlatmalı — yoksa üretim
    // değişince testler eski pencereyi doğrulamaya devam eder.
    final betikKopyasi = _carpim(pick(
      webBetik,
      RegExp(r'const PENCERE_MS = ([\d* ]+);'),
      'verify-error-reporting.ts içinde PENCERE_MS',
    ));
    expect(betikKopyasi, web, reason: 'web betiğindeki pencere kopyası bayat');

    final saat = int.parse(pick(
      dartTest,
      RegExp(r'const Duration _pencere = Duration\(hours: (\d+)\);'),
      'error_reporter_test.dart içinde _pencere',
    ));
    expect(saat * 60 * 60 * 1000, web,
        reason: 'Dart testindeki pencere kopyası bayat');
  });
}
