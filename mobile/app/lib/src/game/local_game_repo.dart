// Devam eden yerel (YZ) oyunun kalıcılık üst katmanı — web App.tsx'teki
// autosave/terk akışlarının Flutter eşleniği. Depolama mekaniği
// LocalSaveStore'da; BU katman politika:
//
// - Otomatik kayıt: oyun `play` fazında ve bitmemişken HER state değişiminde
//   (web'in localStorage autosave'i). turnCount eşiği YOK — web'de de
//   autosave koşulsuz yazar; eşik yalnızca ÇIKIŞTA iz bırakma kararında.
// - Oyun bitince slot silinir (web: isGameOver → clearGameState).
// - Bilinçli çıkışta (logo) `turnCount < 2` ise slot İZ BIRAKMADAN silinir
//   (web handleLogoClick'in aynı eşiği/gerekçesi: hiç oynanmamış oyun ne
//   "Devam Eden Oyun" olur ne 7 günlük cezaya konu olabilir); `>= 2` ise
//   autosave'in son yazdığı kayıt "Devam Eden Oyun" olarak kalır.
// - PORT_BRIEF §7: local_saves'e giden HER yazma tablonun TEK
//   TableWriteQueue'sundan geçer, HER okuma kuyruk boşalana kadar bekler —
//   web'deki DELETE/SELECT yarışı yapısal olarak imkânsız.
// - Terk edilme cezası: LocalSaveStore.load süresi dolan kaydı
//   pending_events'e taşır; `drainAbandonedGames` bu olayları tüketip
//   ÇAĞIRANA verir — cezaya çevirme (buildGameRecord(state, surrendered:
//   true, surrenderingIndex: 0) + saveDurable + logFinish) `GamesRepo`'da,
//   bulut terk yoluyla AYNI noktada birleşir (web'de de tek fonksiyon).
import 'dart:convert';

import 'package:kelimeki_core/kelimeki_core.dart';

import '../data/write_queue.dart';
import '../storage/app_storage.dart';
import '../storage/local_save_store.dart';
import '../storage/pending_event_store.dart' show abandonedGameKind;
import 'game_controller.dart';

/// 7 günü dolup terk olayına dönüşmüş bir misafir kaydı — çağıran bunu -2
/// cezalı teslim kaydına çevirir (bulut tarafındaki AbandonedCloudSave'in
/// yerel eşleniği).
class AbandonedLocalGame {
  final GameState state;

  /// Kaydın son yazılma anı — oyun süresi bundan ve `startedAt`'ten
  /// hesaplanır (web durationSeconds).
  final int savedAtMs;
  const AbandonedLocalGame({required this.state, required this.savedAtMs});
}

class LocalGameRepo {
  final AppStorage storage;

  /// local_saves tablosunun TEK yazma kuyruğu (PORT_BRIEF §7).
  final TableWriteQueue _savesQueue = TableWriteQueue();

  LocalGameRepo(this.storage);

  Future<bool> hasSave() =>
      _savesQueue.read(() => storage.saves.exists(guestSaveSlot));

  Future<int?> savedAtMs() =>
      _savesQueue.read(() => storage.saves.savedAtMs(guestSaveSlot));

  /// Kaydı yükler — null: kayıt yok / süresi dolup terk olayına dönüştü /
  /// bozuk olup karantinaya taşındı (üçünde de slot temiz, bkz.
  /// LocalSaveStore.load).
  Future<GameState?> loadSave() =>
      _savesQueue.read(() => storage.saves.load(guestSaveSlot));

  /// Misafir slotunu siler — bulut migrasyonu (CloudSaveRepo.migrateGuestSave)
  /// kaydın sunucuya yazıldığını DOĞRULADIKTAN sonra çağırır.
  Future<void> clearSave() =>
      _savesQueue.enqueue(() => storage.saves.clear(guestSaveSlot));

  /// Süresi dolmuş kayıtlardan doğan terk olaylarını tüketir (read-then-clear,
  /// atomik) ve çağırana verir — ceza kaydına çevirmek ÇAĞIRANIN işi
  /// (`GamesRepo.recordAbandoned`), böylece yerel ve bulut terk yolları
  /// web'deki gibi TEK bir buildGameRecord+saveGameDurable+logGameFinish
  /// noktasında birleşir. Çözülemeyen olay sessizce düşer — kayıt zaten
  /// karantina disiplininden geçmiş bir kopyaydı, ceza uydurulamaz.
  Future<List<AbandonedLocalGame>> drainAbandonedGames() async {
    final events = await storage.events.takeAll(abandonedGameKind);
    final result = <AbandonedLocalGame>[];
    for (final e in events) {
      try {
        final stateJson =
            (jsonDecode(e['state'] as String) as Map).cast<String, Object?>();
        result.add(AbandonedLocalGame(
          state: gameStateFromJson(stateJson),
          savedAtMs: (e['savedAt'] as num).toInt(),
        ));
      } catch (_) {
        // yut
      }
    }
    return result;
  }

  /// Bir oyunu kalıcılığa bağlar — controller yaşadığı sürece autosave.
  GameSession attach(GameController controller) =>
      GameSession._(controller, storage.saves, _savesQueue);
}

class GameSession {
  final GameController controller;
  final LocalSaveStore _saves;
  final TableWriteQueue _queue;
  bool _detached = false;

  GameSession._(this.controller, this._saves, this._queue) {
    controller.addListener(_onChange);
    _onChange(); // mevcut state'i hemen yaz (restore edilmiş oyun dahil)
  }

  void _onChange() {
    if (_detached) return;
    final s = controller.state;
    if (s.phase == GamePhase.play && !s.isGameOver) {
      _queue.enqueue(() => _saves.save(guestSaveSlot, s));
    } else if (s.isGameOver) {
      _queue.enqueue(() => _saves.clear(guestSaveSlot));
    }
  }

  /// Bilinçli çıkış (logo/YENİ OYUN ile ekrandan ayrılma). Web
  /// handleLogoClick eşiği: hiç oynanmamış (turnCount < 2) bitmemiş oyun iz
  /// bırakmadan silinir; başlamış oyun autosave'iyle "Devam Eden Oyun"
  /// olarak kalır. Dönen future tüm bekleyen yazmalar bitince çözülür.
  Future<void> end() {
    final s = controller.state;
    detach();
    if (s.phase == GamePhase.play && !s.isGameOver && s.turnCount < 2) {
      _queue.enqueue(() => _saves.clear(guestSaveSlot));
    }
    return _queue.idle;
  }

  void detach() {
    if (_detached) return;
    _detached = true;
    controller.removeListener(_onChange);
  }
}
