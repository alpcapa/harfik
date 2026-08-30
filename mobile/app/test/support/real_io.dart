import 'package:flutter_test/flutter_test.dart';

/// Sahte zamanda ilerlemeyen GERÇEK I/O'ya (sqflite yazmaları, gerçek
/// `SharedPreferences`) gerçek zaman payı tanır ve arada sahte zonu pompalar.
///
/// **Neden gerekli:** sqflite her işlemin başında ~10 saniyelik bir
/// kilit-uyarı `Timer`'ı kurar ve işlem bitince iptal eder. Widget'ın
/// başlattığı yazma SAHTE zonda çalıştığından o `Timer` de sahte olur;
/// `pumpAndSettle` gerçek I/O'yu ilerletmediğinden iptal hiç gelmez ve
/// widget ağacı sökülünce test "A Timer is still pending" ile düşer.
///
/// **Neden TEK bir uyku YETMEZ (29 Ağustos 2026 — bu dosyanın doğuş
/// sebebi):** üç test dosyası da bunu `runAsync(200ms)` + TEK `pump()`
/// olarak kopyalamıştı ve `online_game_chat_test.dart`'ın "tanıtımı görmüş
/// kullanıcı bir daha görmez" testi CI'da `Pending timers` ile düştü
/// (`main`'de aynı anda yeşildi → flake). Kusur bütçenin küçüklüğü DEĞİL
/// deseni: I/O'lar ZİNCİRLİ. `_seedInitialUnread` önce `lastReadAt()`
/// okur, SONUCUNA göre `markRead()` yazar — yani ikinci I/O ancak
/// birincinin sahte-zon devamı `pump()`la akıtıldıktan sonra BAŞLIYOR.
/// Tek `pump()` bu zincirin yalnızca ilk halkasını kapatabilir; ikinci
/// yazmanın timer'ı bekler durumda kalır. Sabit uykuyu büyütmek bunu
/// çözmez, yalnızca yarışı gizler.
///
/// **Düzeltme:** gerçek zaman payı DİLİMLERE bölünüp her dilimin ardından
/// `pump()` çağrılıyor — böylece her tur bir sonraki halkayı başlatabiliyor
/// ve toplam bütçe de 200ms'den 500ms'ye çıkıyor (yük altındaki paylaşımlı
/// runner için). Hızlı koşucuda maliyet aynı kalır: dilimler zaten sırayla
/// bekleniyor.
///
/// ⚠ **DB'yi okuyarak "bitti mi" diye SORMA.** `runAsync` içinden aynı
/// `Database`e bir sorgu göndermek sezgisel olarak daha kesin durur ama
/// KİLİTLENİR: sqflite işlemleri seri işler, yani sorgu sahte zondaki
/// bekleyen yazmanın kilidini bekler; o yazmanın devamı ise ancak `pump()`
/// ile akar — `runAsync` sırasında sahte zon pompalanmadığından ikisi
/// birbirini bekler.
///
/// **Hangi testler buna muhtaç:** GERÇEK depoyla (`AppStorage.open` +
/// `databaseFactoryFfi`) çizen her ekran testi. Bugünkü üç çağıranı ve
/// yazmayı BAŞLATAN yer:
/// * `online_game_chat_test.dart` — `_loadChat` → `_seedInitialUnread`
///   (`lastReadAt` + `markRead`) ve modal açılışındaki `_markChatReadTo`.
/// * `setup_cloud_test.dart` — `_syncCloud` → `GamesRepo.flushPending` →
///   `PendingQueueStore.readAll`'ın TTL süpürmesi.
/// * `intro_screen_test.dart` — açılış bayraklarının okunması.
///
/// **`tearDown`'da depoyu kapatmak ÇÖZMEZ:** bekleyen-timer kontrolü test
/// GÖVDESİ biter bitmez, `tearDown`'dan ÖNCE çalışıyor — gerçek zaman
/// gövdenin İÇİNDE tanınmak zorunda.
///
/// ⚠ **Bu sınıf yerelde tek dosya koşarken GÖRÜNMEZ.** Yük altındaki
/// paylaşımlı CI runner'ı yakalıyor; "yerelde iki temiz koşu" hiçbir şey
/// kanıtlamaz (Parça 13'ün dersi).
///
/// Aynı sınıfın geçmişi: Parça 11 · 13 (50→200ms) · 64 · 74.
Future<void> drainRealIo(WidgetTester tester) async {
  const slice = Duration(milliseconds: 50);
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(slice));
    await tester.pump();
  }
}
