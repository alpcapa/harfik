// Golden vector action JSON'unu (scripts/generate-golden-vectors.ts'in
// serAction çıktısı) sealed GameAction'lara çözer. Yalnızca test/replay
// aracıdır — uygulama action'ları serileştirmez.
import 'package:kelimeki_core/kelimeki_core.dart';

GameAction decodeAction(Map<String, Object?> j) {
  final type = j['type'] as String;
  switch (type) {
    case 'INIT':
      return const InitAction();
    case 'ABANDON':
      return const AbandonAction();
    case 'START':
      return StartAction([
        for (final p in j['players'] as List)
          PlayerSetup(
            name: (p as Map)['name'] as String,
            isAI: p['isAI'] as bool,
          ),
      ]);
    case 'SELECT_TILE':
      return SelectTileAction(j['index'] as int);
    case 'PLACE_TILE':
      return PlaceTileAction(
        r: j['r'] as int,
        c: j['c'] as int,
        wildLetter: j['wildLetter'] as String?,
        rackIndex: j['rackIndex'] as int?,
      );
    case 'MOVE_PLACED_TILE':
      final from = (j['from'] as Map).cast<String, Object?>();
      final to = (j['to'] as Map).cast<String, Object?>();
      return MovePlacedTileAction(
        fromR: from['r'] as int,
        fromC: from['c'] as int,
        toR: to['r'] as int,
        toC: to['c'] as int,
      );
    case 'RECALL_CELL':
      return RecallCellAction(r: j['r'] as int, c: j['c'] as int);
    case 'SET_WILD_LETTER':
      return SetWildLetterAction(
        r: j['r'] as int,
        c: j['c'] as int,
        wildLetter: j['wildLetter'] as String,
      );
    case 'RECALL_ALL':
      return const RecallAllAction();
    case 'SHUFFLE_RACK':
      return const ShuffleRackAction();
    case 'TOGGLE_SWAP_MODE':
      return const ToggleSwapModeAction();
    case 'TOGGLE_SWAP_TILE':
      return ToggleSwapTileAction(j['index'] as int);
    case 'CONFIRM_SWAP':
      return const ConfirmSwapAction();
    case 'PLAY':
      return PlayAction(skipWordCheck: j['skipWordCheck'] == true);
    case 'SET_MESSAGE':
      return SetMessageAction(
        message: j['message'] as String,
        messageType: MessageKindJson.parse(j['messageType'] as String),
      );
    case 'PASS':
      return const PassAction();
    case 'AI_PLAY':
      return const AiPlayAction();
    case 'RENAME_PLAYER':
      return RenamePlayerAction(index: j['index'] as int, name: j['name'] as String);
    case 'SURRENDER':
      return SurrenderAction(j['index'] as int);
    case 'SYNC_ONLINE_STATE':
      return SyncOnlineStateAction(
        publicState: OnlineGameStatePublic.fromJson(
            (j['publicState'] as Map).cast<String, Object?>()),
        myRack: [
          for (final t in j['myRack'] as List)
            Tile.fromJson((t as Map).cast<String, Object?>()),
        ],
        mySlotIndex: j['mySlotIndex'] as int,
      );
    case 'RESUME_SAVED':
      return ResumeSavedAction(
          gameStateFromJson((j['state'] as Map).cast<String, Object?>()));
    default:
      throw ArgumentError('bilinmeyen action: $type');
  }
}
