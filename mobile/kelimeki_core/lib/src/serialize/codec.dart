// Kelimeki core — GameState JSON codec'i.
//
// Biçim, web'in localStorage/golden-vector kanonik biçimiyle BİREBİR aynıdır:
// opsiyonel alanlar yalnızca doluyken yazılır (Tile/HistoryEntry.toJson) —
// golden vector derin karşılaştırması bu sözleşmeye dayanır.
//
// "Parse, don't validate": fromJson ya tamamen geçerli bir GameState üretir
// ya da fırlatır — yarım/null'lu bir state hiçbir zaman oluşamaz. Depolama
// katmanı (uygulama) bu fırlatmayı yakalayıp kaydı karantinaya alır
// (mobile/CLAUDE.md, kalıcılık tasarımı).
import '../model/game_state.dart';
import '../model/history_entry.dart';
import '../model/player.dart';
import '../model/tile.dart';
import '../model/types.dart';

Map<String, Object?> gameStateToJson(GameState s) => {
      'phase': s.phase.json,
      'startedAt': s.startedAt,
      'multiSession': s.multiSession,
      'endReason': s.endReason.json,
      'board': [
        for (final row in s.board)
          [for (final cell in row) cell?.toJson()],
      ],
      'bag': [for (final t in s.bag) t.toJson()],
      'bonuses': {for (final e in s.bonuses.entries) e.key: 'tw'},
      'placed': {for (final e in s.placed.entries) e.key: e.value.toJson()},
      'players': [for (final p in s.players) p.toJson()],
      'current': s.current,
      'selectedTile': s.selectedTile,
      'swapMode': s.swapMode,
      'swapSelection': s.swapSelection,
      'turnCount': s.turnCount,
      'consecutivePasses': s.consecutivePasses,
      'isGameOver': s.isGameOver,
      'message': s.message,
      'messageType': s.messageType.json,
      'lastMoveCells': [
        for (final c in s.lastMoveCells) [c.$1, c.$2],
      ],
      'moveHistory': [for (final h in s.moveHistory) h.toJson()],
      // Web JSON.stringify'ı `undefined` alanı hiç yazmaz — aynı sözleşme.
      if (s.aiLevel != null) 'aiLevel': s.aiLevel!.json,
    };

GameState gameStateFromJson(Map<String, Object?> j) => GameState(
      phase: GamePhaseJson.parse(j['phase'] as String),
      startedAt: j['startedAt'] as String,
      multiSession: j['multiSession'] as bool,
      endReason: EndReasonJson.parse(j['endReason'] as String),
      board: [
        for (final row in j['board'] as List)
          [
            for (final cell in row as List)
              cell == null
                  ? null
                  : Tile.fromJson((cell as Map).cast<String, Object?>()),
          ],
      ],
      bag: [
        for (final t in j['bag'] as List)
          Tile.fromJson((t as Map).cast<String, Object?>()),
      ],
      bonuses: {
        for (final e in (j['bonuses'] as Map).entries)
          e.key as String: BonusType.tw,
      },
      placed: {
        for (final e in (j['placed'] as Map).entries)
          e.key as String: Tile.fromJson((e.value as Map).cast<String, Object?>()),
      },
      players: [
        for (final p in j['players'] as List)
          Player.fromJson((p as Map).cast<String, Object?>()),
      ],
      current: j['current'] as int,
      selectedTile: j['selectedTile'] as int?,
      swapMode: j['swapMode'] as bool,
      swapSelection: [for (final i in j['swapSelection'] as List) i as int],
      turnCount: j['turnCount'] as int,
      consecutivePasses: j['consecutivePasses'] as int,
      isGameOver: j['isGameOver'] as bool,
      message: j['message'] as String,
      messageType: MessageKindJson.parse(j['messageType'] as String),
      lastMoveCells: [
        for (final c in j['lastMoveCells'] as List)
          ((c as List)[0] as int, c[1] as int),
      ],
      moveHistory: [
        for (final h in j['moveHistory'] as List)
          HistoryEntry.fromJson((h as Map).cast<String, Object?>()),
      ],
      // Toleranslı: eski web/port kayıtlarında alan yok → null (= Normal).
      aiLevel: AiLevelJson.parseOrNull(j['aiLevel'] as String?),
    );
