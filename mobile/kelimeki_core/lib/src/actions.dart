// Kelimeki core — reducer action'ları (src/game/gameReducer.ts Action portu).
import 'model/game_state.dart';
import 'model/tile.dart';
import 'model/types.dart';
import 'online/online_state.dart';

/// Kurulumda bir oyuncunun ayarı.
class PlayerSetup {
  final String name;
  final bool isAI;
  const PlayerSetup({required this.name, required this.isAI});
}

sealed class GameAction {
  const GameAction();
}

class InitAction extends GameAction {
  const InitAction();
}

class AbandonAction extends GameAction {
  const AbandonAction();
}

class StartAction extends GameAction {
  final List<PlayerSetup> players;
  const StartAction(this.players);
}

class SelectTileAction extends GameAction {
  final int index;
  const SelectTileAction(this.index);
}

class PlaceTileAction extends GameAction {
  final int r;
  final int c;
  final String? wildLetter;
  final int? rackIndex;
  const PlaceTileAction({required this.r, required this.c, this.wildLetter, this.rackIndex});
}

class MovePlacedTileAction extends GameAction {
  final int fromR, fromC, toR, toC;
  const MovePlacedTileAction({
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
  });
}

class RecallCellAction extends GameAction {
  final int r, c;
  const RecallCellAction({required this.r, required this.c});
}

class SetWildLetterAction extends GameAction {
  final int r, c;
  final String wildLetter;
  const SetWildLetterAction({required this.r, required this.c, required this.wildLetter});
}

class RecallAllAction extends GameAction {
  const RecallAllAction();
}

class ShuffleRackAction extends GameAction {
  const ShuffleRackAction();
}

class ToggleSwapModeAction extends GameAction {
  const ToggleSwapModeAction();
}

class ToggleSwapTileAction extends GameAction {
  final int index;
  const ToggleSwapTileAction(this.index);
}

class ConfirmSwapAction extends GameAction {
  const ConfirmSwapAction();
}

class PlayAction extends GameAction {
  final bool skipWordCheck;
  const PlayAction({this.skipWordCheck = false});
}

class SetMessageAction extends GameAction {
  final String message;
  final MessageKind messageType;
  const SetMessageAction({required this.message, required this.messageType});
}

class PassAction extends GameAction {
  const PassAction();
}

class AiPlayAction extends GameAction {
  const AiPlayAction();
}

class RenamePlayerAction extends GameAction {
  final int index;
  final String name;
  const RenamePlayerAction({required this.index, required this.name});
}

class SurrenderAction extends GameAction {
  final int index;
  const SurrenderAction(this.index);
}

class SyncOnlineStateAction extends GameAction {
  final OnlineGameStatePublic publicState;
  final List<Tile> myRack;
  final int mySlotIndex;
  const SyncOnlineStateAction({
    required this.publicState,
    required this.myRack,
    required this.mySlotIndex,
  });
}

class ResumeSavedAction extends GameAction {
  final GameState state;
  const ResumeSavedAction(this.state);
}
