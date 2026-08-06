// Minimal OYNANABİLİR oyun ekranı — App.tsx'in oyun görünümünün çekirdeği:
// skor satırı + mesaj + tahta (canlı geçerlilik çerçevesiyle) + raf +
// Oyna/Pas Geç/Geri Al/Karıştır. Parça parça plan gereği BİLİNÇLİ eksikler
// (mobile/CLAUDE.md): GameHeader'ın gerçek görsel dili, taş değiştirme
// (swap) akışı, sürükle-bırak, kelime anlamı modalı, GameOver ekranı
// (şimdilik basit bant), kaydet/yükle bağlantısı.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../game/game_controller.dart';
import '../../game/move_status.dart';
import 'board_widget.dart';
import 'player_colors.dart';
import 'rack_widget.dart';
import 'wild_letter_sheet.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  final WordSource words;
  const GameScreen({super.key, required this.controller, required this.words});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get controller => widget.controller;
  GameState get state => controller.state;

  PlayerColor _colorOf(int i) =>
      playerColors[state.players[i].colorIndex % playerColors.length];

  bool get _canAct =>
      !state.isGameOver &&
      state.players.isNotEmpty &&
      !state.players[state.current].isAI;

  Future<void> _handleCellTap(int r, int c) async {
    final k = cellKey(r, c);
    if (state.board[r][c] != null) {
      // Kelime anlamı modalı sonraki parçaların işi — şimdilik dokunuş yok.
      return;
    }
    final placedTile = state.placed[k];
    if (placedTile != null) {
      // Web davranışı: joker olmayan yerleştirilmiş taşa dokunmak geri alır;
      // jokere dokunmak seçiciyi 'editing' modunda yeniden açar.
      if (!_canAct) return;
      if (placedTile.wild) {
        final choice = await showWildLetterSheet(context, editing: true);
        if (choice == null) return;
        if (choice.recallRequested) {
          controller.dispatch(RecallCellAction(r: r, c: c));
        } else if (choice.letter != null) {
          controller.dispatch(
              SetWildLetterAction(r: r, c: c, wildLetter: choice.letter!));
        }
      } else {
        controller.dispatch(RecallCellAction(r: r, c: c));
      }
      return;
    }
    if (!_canAct || state.swapMode) return;

    final selIdx = state.selectedTile;
    final sel = (selIdx != null &&
            selIdx >= 0 &&
            selIdx < state.players[state.current].rack.length)
        ? state.players[state.current].rack[selIdx]
        : null;
    if (sel != null && sel.letter == '?') {
      // Joker: harf seçilene kadar taş konmaz (web pendingWild akışı).
      final choice = await showWildLetterSheet(context);
      if (choice?.letter == null) return;
      controller
          .dispatch(PlaceTileAction(r: r, c: c, wildLetter: choice!.letter));
      return;
    }
    controller.dispatch(PlaceTileAction(r: r, c: c));
  }

  Future<void> _handlePlay(MoveStatus? moveStatus) async {
    // Bölge vergisi onayı — web invasionConfirm akışı: hamle GEÇERLİYSE ve
    // vergi payı varsa Oyna'dan önce sorulur.
    final score = moveStatus?.score ?? 0;
    if (moveStatus != null && moveStatus.valid) {
      final placedCoords = [for (final k in state.placed.keys) parseKey(k)];
      final split = computeInvasionSplit(
          placedCoords, state.current, state.players, score, state.board);
      if (split.shares.isNotEmpty) {
        final parts = split.shares
            .map((s) =>
                '${s.amount} puanı ${state.players[s.index].name} kullanıcısına')
            .join(', ');
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sınır İhlali!'),
            content: Text(
                'Bu hamleden kazanacağın $score puanın $parts vergi olarak gidecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('VAZGEÇ'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OYNA'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    controller.dispatch(const PlayAction());
  }

  Future<void> _handlePass() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pas Geç'),
        content: const Text('Sıranı pas geçmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('PAS GEÇ'),
          ),
        ],
      ),
    );
    if (ok == true) controller.dispatch(const PassAction());
  }

  Color _messageColor(MessageKind kind) => switch (kind) {
        MessageKind.err => const Color(0xFFE0483A),
        MessageKind.ok => const Color(0xFF1FA05C),
        MessageKind.warn => const Color(0xFFD97706),
        MessageKind.none => const Color(0xFF5B6472),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final moveStatus = computeMoveStatus(state, widget.words);
        // Web liveMessage kuralı: geçersiz hamlenin sebebi anlık gösterilir,
        // geçerliyse mevcut mesaj yeşile döner.
        final liveMessage =
            (moveStatus != null && !moveStatus.valid && moveStatus.reason != null)
                ? moveStatus.reason!
                : state.message;
        final liveKind =
            (moveStatus != null && !moveStatus.valid && moveStatus.reason != null)
                ? MessageKind.err
                : (moveStatus?.valid ?? false)
                    ? MessageKind.ok
                    : state.messageType;

        final me = state.players.isEmpty ? null : state.players[state.current];

        return Scaffold(
          backgroundColor: const Color(0xFFEDF1F7),
          appBar: AppBar(title: const Text('Kelimeki')),
          body: SafeArea(
            child: Column(
              children: [
                // Basit skor satırı (gerçek GameHeader sonraki parça).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      for (var i = 0; i < state.players.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: _colorOf(i).zone,
                              border: Border.all(
                                color: _colorOf(i).base,
                                width: i == state.current ? 2 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  state.players[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _colorOf(i).text,
                                  ),
                                ),
                                Text(
                                  '${state.players[i].score}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _colorOf(i).text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(
                        state.isGameOver ? 'Oyun bitti.' : liveMessage,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _messageColor(
                              state.isGameOver ? MessageKind.none : liveKind),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: BoardWidget(
                      state: state,
                      moveOverlay: moveStatus == null
                          ? null
                          : MoveOverlay(
                              valid: moveStatus.valid,
                              cells: moveStatus.cells,
                              score: moveStatus.score,
                            ),
                      onCellTap: _handleCellTap,
                    ),
                  ),
                ),
                if (me != null && !state.isGameOver) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: RackWidget(
                      tiles: me.rack,
                      selectedTile: state.selectedTile,
                      onSelect: (i) =>
                          _canAct ? controller.dispatch(SelectTileAction(i)) : null,
                      title: me.name,
                      color: _colorOf(state.current),
                      swapMode: state.swapMode,
                      swapSelection: state.swapSelection,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _canAct && state.placed.isNotEmpty
                                ? () => _handlePlay(moveStatus)
                                : null,
                            child: const Text('OYNA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _canAct ? _handlePass : null,
                            child: const Text('PAS GEÇ'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _canAct && state.placed.isNotEmpty
                                ? () =>
                                    controller.dispatch(const RecallAllAction())
                                : null,
                            child: const Text('GERİ AL'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _canAct
                                ? () =>
                                    controller.dispatch(const ShuffleRackAction())
                                : null,
                            child: const Text('KARIŞTIR'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (state.isGameOver)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('KAPAT'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
