// Widget duman testi — web'in tests/smoke.spec.ts felsefesinin eşleniği:
// uygulama kabuğu açılıyor mu, offline mod ve sözlük durumu görünüyor mu,
// sürüm kapısı doğru ekrana yönlendiriyor mu.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

void main() {
  testWidgets('açılış: offline mod + sözlük durumu görünür', (tester) async {
    final services = AppServices(
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      supabase: null,
      versionGate: VersionGateStatus.ok,
    );
    await tester.pumpWidget(KelimekiApp(services: services));
    expect(find.text('Kelimeki'), findsOneWidget);
    expect(find.textContaining('offline mod'), findsOneWidget);
    await tester.pump(); // FutureBuilder çözülsün
    expect(find.text('Sözlük: 3 kelime'), findsOneWidget);
    expect(find.textContaining('Motor testi'), findsOneWidget);
  });

  testWidgets('sürüm kapısı: updateRequired tüm uygulamanın yerine geçer',
      (tester) async {
    final services = AppServices(
      dictionary: Future.value(SetWordSource(const ['ab'])),
      supabase: null,
      versionGate: VersionGateStatus.updateRequired,
    );
    await tester.pumpWidget(KelimekiApp(services: services));
    expect(find.text('Güncelleme Gerekli'), findsOneWidget);
    expect(find.textContaining('Sözlük'), findsNothing);
  });
}
