// PORT_BRIEF §7'den porta taşınan iki değişmezin testleri
// (write_queue.dart / account_scope.dart başlık yorumlarına bkz.).
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/auth/account_scope.dart';
import 'package:kelimeki/src/data/write_queue.dart';

void main() {
  group('TableWriteQueue', () {
    test('DELETE/SELECT yarışı: kuyruklu okuma silinmiş satırı GÖRMEZ',
        () async {
      // Web'deki hatanın minyatürü: "sunucu" tablosuna yavaş bir DELETE
      // gönderilir, hemen ardından liste çekilir. Kuyruksuz okuma bayat
      // satırı görür; kuyruklu okuma silinmeyi bekler.
      final rows = <String>{'game-1'};
      final q = TableWriteQueue();

      // Yavaş DELETE (ağ gecikmesi simülasyonu)
      final delete = q.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        rows.remove('game-1');
      });

      // Aynı tick'te kuyruksuz okuma — yarışın kendisi (bilerek bayat)
      expect(rows.contains('game-1'), isTrue);

      // Kuyruklu okuma bekleyen yazmayı await eder
      final listed = await q.read(() async => rows.toList());
      expect(listed, isEmpty);
      await delete;
    });

    test('yazmalar sırayla; hata kuyruğu kilitlemez', () async {
      final log = <String>[];
      final q = TableWriteQueue();
      final f1 = q.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        log.add('a');
      });
      final f2 = q.enqueue(() async {
        log.add('b');
        throw StateError('yazma hatası');
      });
      final f3 = q.enqueue(() async => log.add('c'));
      await f1;
      await expectLater(f2, throwsStateError); // hata çağırana yansır
      await f3;
      expect(log, ['a', 'b', 'c']); // araya girme yok, kilitlenme yok
    });
  });

  group('AccountScope', () {
    test('tokenRefreshed (aynı id, taze nesne) sıfırlama TETİKLEMEZ', () {
      final scope = AccountScope();
      var resets = 0;
      scope.registerReset(() => resets++);

      expect(scope.onAuthEvent('user-a'), isFalse); // ilk olay: mount yolu
      // supabase_flutter tokenRefreshed'i saatte bir taze User nesnesiyle
      // yayınlar — karar id'ye baktığından hepsi no-op olmalı.
      for (var i = 0; i < 5; i++) {
        expect(scope.onAuthEvent('user-a'), isFalse);
      }
      expect(resets, 0);
    });

    test('gerçek hesap değişimi (çıkış dahil) sıfırlamaları koşar', () {
      final scope = AccountScope();
      final log = <String?>[];
      scope.registerReset(() => log.add(scope.currentUserId));

      scope.onAuthEvent('user-a'); // ilk olay
      expect(scope.onAuthEvent(null), isTrue); // çıkış → sıfırla
      expect(scope.onAuthEvent(null), isFalse); // tekrarı no-op
      expect(scope.onAuthEvent('user-b'), isTrue); // ikinci hesap → sıfırla
      expect(log, [null, 'user-b']);
    });
  });
}
