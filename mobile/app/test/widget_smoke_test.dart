// Widget duman testi — web'in tests/smoke.spec.ts felsefesinin eşleniği:
// uygulama kabuğu Setup ekranıyla açılıyor mu, teşhis satırı (offline mod +
// sözlük durumu) görünüyor mu, sürüm kapısı doğru ekrana yönlendiriyor mu.
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

void main() {
  testWidgets('açılış: Setup ekranı + offline mod + sözlük durumu görünür',
      (tester) async {
    final services = AppServices(
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      supabase: null,
      versionGate: VersionGateStatus.ok,
    );
    await tester.pumpWidget(KelimekiApp(services: services));
    expect(find.text('OYUN TİPİ'), findsOneWidget);
    await tester.pump(); // FutureBuilder'lar çözülsün
    expect(find.textContaining('offline mod'), findsOneWidget);
    expect(find.textContaining('Sözlük: 3 kelime'), findsOneWidget);
    expect(find.text('OYUNU BAŞLAT'), findsOneWidget);
  });

  testWidgets('sürüm kapısı: updateRequired tüm uygulamanın yerine geçer',
      (tester) async {
    final services = AppServices(
      dictionary: Future.value(SetWordSource(const ['ab'])),
      meanings: MeaningStore(bundle: rootBundle),
      supabase: null,
      versionGate: VersionGateStatus.updateRequired,
    );
    await tester.pumpWidget(KelimekiApp(services: services));
    expect(find.text('Güncelleme Gerekli'), findsOneWidget);
    expect(find.text('OYUN TİPİ'), findsNothing);
  });
}
