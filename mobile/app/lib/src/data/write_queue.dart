// Tablo başına serileşmiş yazma kuyruğu — PORT_BRIEF §7 değişmezi
// (6 Ağustos 2026, web'deki local_game_saves DELETE/SELECT yarışının dersi):
//
//   "Satır sahibi tablo başına TEK serileşmiş yazma yolu; o satır için
//    bekleyen yazma çözülmeden okuma yapılmaz."
//
// Yarış React'e özgü değildi — aynı şemaya yazan HER istemci (Flutter dahil)
// üretir: DELETE ile hemen ardından gelen liste SELECT'i sunucuda eşzamanlı
// işlenip silinmemiş satırı bir kez daha gösterebilir. Web'deki
// `enqueueSaveWrite` (src/App.tsx, #224) deseninin Dart eşleniği.
//
// KURAL (depolama/senkron fazı bunun üzerine kurulur): `local_game_saves`
// gibi satır sahibi bir tabloya giden HER yazma `enqueue` üzerinden, o
// tabloyu listeleyen HER okuma `read` üzerinden (ya da önce `idle` await
// edilerek) gitmek zorunda. Kuyruğu atlayan tek bir çağrı bile yarışı
// geri getirir.
class TableWriteQueue {
  Future<void> _tail = Future<void>.value();

  /// Yazmayı kuyruğun sonuna ekler; önceki tüm yazmalar bitmeden başlamaz.
  /// Hata, ÇAĞIRANA aynen yansır ama kuyruğu kilitlemez — sonraki yazmalar
  /// çalışmaya devam eder (web'deki kuyruk da hatada durmuyor; duran bir
  /// kuyruk sessizce sonsuza dek bayat okuma demek olurdu).
  Future<T> enqueue<T>(Future<T> Function() write) {
    final result = _tail.then((_) => write());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Şu ana kadar kuyruklanmış TÜM yazmalar çözülene kadar bekler.
  Future<void> get idle => _tail;

  /// Okumadan önce bekleyen yazmaların bitmesini garanti eder.
  Future<T> read<T>(Future<T> Function() query) async {
    await idle;
    return query();
  }
}
