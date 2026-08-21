// ROADMAP #3 — istemci hata telemetrisinin KARAR mantığı.
//
// Ağ/Supabase yok: `ClientErrorSink` sahtesi tüm politika katmanını gerçek
// akışla sınıyor (portun her yerindeki gateway deseni). Buradaki her testin
// bir negatif eşi var — kural kaldırılırsa test GERÇEKTEN düşmeli.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/error_reporter.dart';

class _FakeSink implements ClientErrorSink {
  final List<Map<String, Object?>> sent = [];
  bool fail = false;

  @override
  Future<void> send(Map<String, Object?> record) async {
    sent.add(record);
    if (fail) throw Exception('sink patladı');
  }
}

/// `isNetworkError`'a düşen gerçek bir kalıp (bkz. util/offline_notice.dart).
class _NetworkError implements Exception {
  @override
  String toString() => 'ClientException: Failed host lookup: kelimeki.com';
}

void main() {
  late _FakeSink sink;

  setUp(() {
    errorReporter.resetForTests();
    sink = _FakeSink();
    errorReporter.configure(sink: sink, anonId: Future.value('anon-1'));
  });

  test('yapılandırılmamışken hiç göndermez', () async {
    errorReporter.resetForTests();
    errorReporter.report(Exception('bir şey'));
    await Future<void>.delayed(Duration.zero);
    expect(sink.sent, isEmpty);
  });

  test('kayıt derleme/platform/anon alanlarını taşır', () async {
    errorReporter.report(Exception('patladı'), context: 'test_ctx');
    await Future<void>.delayed(Duration.zero);
    expect(sink.sent, hasLength(1));
    final r = sink.sent.single;
    expect(r['kind'], ClientErrorKind.manual);
    expect(r['message'], contains('[test_ctx]'));
    expect(r['anon_id'], 'anon-1');
    // Yol portta ekran adı değil sabit bir işaret — token/uuid sızmasın diye.
    expect(r['route'], 'app');
    expect(r.containsKey('build'), isTrue);
    expect(r.containsKey('platform'), isTrue);
  });

  test('aynı imza İKİNCİ kez gönderilmez', () async {
    errorReporter.report(Exception('aynı hata'));
    await Future<void>.delayed(Duration.zero);
    errorReporter.report(Exception('aynı hata'));
    await Future<void>.delayed(Duration.zero);
    expect(sink.sent, hasLength(1));
  });

  test('oturum başına en fazla 10 kayıt (çökme döngüsü koruması)', () async {
    for (var i = 0; i < 25; i++) {
      errorReporter.report(Exception('hata $i'));
      await Future<void>.delayed(Duration.zero);
    }
    expect(sink.sent, hasLength(10));
  });

  test('OTOMATİK yakalamada ağ hatası ELENİR', () async {
    errorReporter.report(_NetworkError(), kind: ClientErrorKind.zone);
    await Future<void>.delayed(Duration.zero);
    expect(sink.sent, isEmpty);
  });

  test('MANUEL bildirimde ağ hatası ELENMEZ — cloud_save "KAYIP" vakası', () async {
    // Bu, filtrenin `kind != manual` koşulunun tek sebebi: orada sinyal
    // hatanın kendisi değil, aynanın da yazılamamış olması.
    errorReporter.report(_NetworkError(), context: 'cloud_save_repo.upsert');
    await Future<void>.delayed(Duration.zero);
    expect(sink.sent, hasLength(1));
  });

  test('mesaj 500, yığın 4000 karakterde kırpılır', () async {
    errorReporter.report(
      Exception('x' * 2000),
      stack: StackTrace.fromString('y' * 9000),
    );
    await Future<void>.delayed(Duration.zero);
    final r = sink.sent.single;
    expect((r['message']! as String).length, 500);
    expect((r['stack']! as String).length, 4000);
  });

  test('hedef fırlatırsa uygulama etkilenmez ve sonraki rapor yine gider',
      () async {
    sink.fail = true;
    errorReporter.report(Exception('ilk'));
    await Future<void>.delayed(Duration.zero);
    sink.fail = false;
    errorReporter.report(Exception('ikinci'));
    await Future<void>.delayed(Duration.zero);
    expect(sink.sent.map((r) => r['message']), [
      contains('ilk'),
      contains('ikinci'),
    ]);
  });
}
