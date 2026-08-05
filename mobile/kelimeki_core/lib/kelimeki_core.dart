/// Kelimeki oyun motoru — saf Dart. Web istemcisindeki src/game + src/utils
/// motorunun birebir portu; davranış paritesi golden vector'larla doğrulanır
/// (mobile/CLAUDE.md).
///
/// Bu paket Flutter'a, dart:io'ya, dart:ui'ye ve ağa BAĞIMLI DEĞİLDİR ve
/// öyle kalmalıdır: sözlük [WordSource], rastgelelik [Rng], saat
/// `GameEngine.nowIso` olarak dışarıdan enjekte edilir.
library kelimeki_core;

export 'src/actions.dart';
export 'src/ai/find_move.dart' show findAIMove;
export 'src/constants.dart';
export 'src/data/tiles.dart';
export 'src/dictionary/word_source.dart';
export 'src/engine/bag.dart';
export 'src/engine/reducer.dart';
export 'src/model/game_state.dart';
export 'src/model/history_entry.dart';
export 'src/model/player.dart';
export 'src/model/results.dart';
export 'src/model/tile.dart';
export 'src/model/types.dart';
export 'src/online/online_state.dart';
export 'src/rng.dart';
export 'src/rules/board.dart'
    show createEmptyBoard, cellKey, parseKey, tileLetter, getFormedWords;
export 'src/rules/league_points.dart';
export 'src/rules/ranking.dart';
export 'src/rules/validator.dart';
export 'src/serialize/codec.dart';
export 'src/text/turkish.dart';
