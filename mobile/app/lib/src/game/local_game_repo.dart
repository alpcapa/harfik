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
//   web'in gecikmeli teslim kaydıyla (buildGameRecord(state, true, 0) → -2)
//   aynı KARARI verir: yalnızca turnCount >= 2 olan oyunlar pending_queue'ya
//   (finished-game, TTL 7 gün) bir teslim kaydı olarak girer — sunucuya
//   flush senkron fazının işi, payload tam GameState taşır ki flush fazı
//   gerçek `games` satırını (buildGameRecord portu) oradan üretebilsin.
import 'dart:convert';

import 'package:kelimeki_core/kelimeki_core.dart';

import '../data/write_queue.dart';
import '../storage/app_storage.dart';
import '../storage/local_save_store.dart';
import '../storage/pending_event_store.dart' show abandonedGameKind;
import '../storage/pending_queue_store.dart' show finishedGameKind;
import '../util/uuid.dart';
import 'game_controller.dart';

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

  /// Süresi dolmuş kayıtlardan doğan terk olaylarını tüketir (read-then-clear,
  /// atomik). Web'in takePendingAbandonedGame akışıyla aynı karar: yalnızca
  /// gerçekten başlamış (turnCount >= 2) oyunlar için gecikmeli bir teslim
  /// kaydı kuyruklanır; hiç oynanmamış kayıt iz bırakmadan düşer.
  /// Döndürdüğü sayı: kuyruklanan ceza kaydı adedi (test/teşhis için).
  Future<int> drainAbandonedGames() async {
    final events = await storage.events.takeAll(abandonedGameKind);
    var queued = 0;
    for (final e in events) {
      try {
        final stateJson =
            (jsonDecode(e['state'] as String) as Map).cast<String, Object?>();
        final state = gameStateFromJson(stateJson);
        if (state.turnCount < 2) continue;
        await storage.queue.enqueue(
          kind: finishedGameKind,
          id: uuidV4(),
          payload: {
            'type': 'abandoned-surrender',
            'savedAt': e['savedAt'],
            'state': stateJson,
          },
        );
        queued++;
      } catch (_) {
        // Çözülemeyen olay sessizce düşer — kayıt zaten karantina
        // disiplininden geçmiş bir kopyaydı, ceza uydurulamaz.
      }
    }
    return queued;
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
