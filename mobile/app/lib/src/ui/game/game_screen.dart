// Oynanabilir oyun ekranı — App.tsx'in oyun görünümünün çekirdeği: skor
// satırı + tahta (canlı geçerlilik çerçevesiyle) + mesaj + raf/OYNA + web
// buton düzeni (Pas Geç/Değiştir/Karıştır/Geri Al/Torba; swap modunda
// Değiştir (N)/Vazgeç) + GameOver modalı. Parça parça plan gereği BİLİNÇLİ
// eksikler (mobile/CLAUDE.md): GameHeader'ın gerçek görsel dili,
// sürükle-bırak, kelime anlamı modalı, hamle geçmişi, kaydet/yükle.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../game/game_controller.dart';
import '../../game/move_status.dart';
import 'board_widget.dart';
import 'game_header.dart';
import 'game_over_modal.dart';
import 'player_colors.dart';
import 'rack_widget.dart';
import 'remaining_tiles_modal.dart';
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

  /// GameOver modalı bu isGameOver geçişi için zaten gösterildi mi
  /// (web gameOverDismissed'in eşleniği — kapatınca tahta görünür kalır).
  bool _gameOverShown = false;

  PlayerColor _colorOf(int i) =>
      playerColors[state.players[i].colorIndex % playerColors.length];

  bool get _canAct =>
      !state.isGameOver &&
      state.players.isNotEmpty &&
      !state.players[state.current].isAI;

  /// Web rackPlayer kuralı: sıra YZ'deyse raf yine İNSANIN rafını gösterir.
  int get _rackIndex {
    if (state.players.isEmpty) return 0;
    if (!state.players[state.current].isAI) return state.current;
    final human = state.players.indexWhere((p) => !p.isAI);
    return human >= 0 ? human : state.current;
  }

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
        // Oyun bittiği an GameOver modalı bir kez gösterilir; KAPAT ile
        // kapatınca tahta görünür kalır (web gameOverDismissed davranışı).
        if (state.isGameOver && !_gameOverShown) {
          _gameOverShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showGameOverModal(context, state);
          });
        } else if (!state.isGameOver && _gameOverShown) {
          _gameOverShown = false;
        }

        final moveStatus = computeMoveStatus(state, widget.words);
        // Web liveMessage kuralı: geçersiz hamlenin sebebi anlık gösterilir,
        // geçerliyse mevcut mesaj yeşile döner.
        final liveMessage = (moveStatus != null &&
                !moveStatus.valid &&
                moveStatus.reason != null)
            ? moveStatus.reason!
            : state.message;
        final liveKind = (moveStatus != null &&
                !moveStatus.valid &&
                moveStatus.reason != null)
            ? MessageKind.err
            : (moveStatus?.valid ?? false)
                ? MessageKind.ok
                : state.messageType;

        final me = state.players.isEmpty ? null : state.players[state.current];

        return Scaffold(
          backgroundColor: Colors.white, // web sayfa zemini (colors.bg)
          body: SafeArea(
            child: Column(
              children: [
                // Gerçek başlık: logo (dokunuş = oyundan çık) + skor kutuları
                // (GameHeader.tsx portu, akıcı clamp sistemiyle).
                GameHeader(
                  state: state,
                  onLogoTap: () => Navigator.of(context).pop(),
                ),
                // Web akışıyla aynı: tahta → mesaj → raf → butonlar yukarıdan
                // aşağı dizilir, artan boşluk EN ALTA düşer (önceden tahta
                // Expanded'ta tek başınaydı ve boşluk tahta ile mesajın
                // ARASINA giriyordu); kısa ekranda tamamı kaydırılabilir.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
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
                        // Mesaj satırı web'deki gibi tahtanın ALTINDA, rafın üstünde
                        // (App.tsx: Board → liveMessage → Rack; font-mono 11px bold).
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: SizedBox(
                            height: 30,
                            child: Center(
                              child: Text(
                                state.isGameOver ? 'Oyun bitti.' : liveMessage,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'SpaceMono',
                                  fontWeight: FontWeight.bold,
                                  color: _messageColor(state.isGameOver
                                      ? MessageKind.none
                                      : liveKind),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (me != null) ...[
                          // Web düzeni: Raf + (Oyna | Yeni Oyun) yan yana; swap
                          // modunda sağdaki buton hiç görünmez (App.tsx ~1281).
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            // IntrinsicHeight: buton raf kartıyla aynı boya uzasın
                            // (stretch, Column içinde sınırsız yükseklikte patlar).
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: RackWidget(
                                      tiles: state.players[_rackIndex].rack,
                                      selectedTile: state.selectedTile,
                                      onSelect: (i) {
                                        if (!_canAct) return;
                                        controller.dispatch(state.swapMode
                                            ? ToggleSwapTileAction(i)
                                            : SelectTileAction(i));
                                      },
                                      title: state.players[_rackIndex].name,
                                      color: _colorOf(_rackIndex),
                                      swapMode: state.swapMode,
                                      swapSelection: state.swapSelection,
                                    ),
                                  ),
                                  if (!state.swapMode) ...[
                                    const SizedBox(width: 8),
                                    // Raf boyuna uzadığından şekil sabitlenir — aksi
                                    // halde Material'ın stadium varsayılanı butonu
                                    // dev bir daireye çevirir (web: rounded-lg).
                                    state.isGameOver
                                        ? FilledButton(
                                            style: _playButtonStyle,
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('YENİ\nOYUN',
                                                textAlign: TextAlign.center),
                                          )
                                        : FilledButton(
                                            style: _playButtonStyle,
                                            onPressed: _canAct &&
                                                    state.placed.isNotEmpty
                                                ? () => _handlePlay(moveStatus)
                                                : null,
                                            child: const Text('OYNA'),
                                          ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: state.swapMode
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                                0xFFB7791F), // web gold
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: _canAct &&
                                                  state.swapSelection.isNotEmpty
                                              ? () => controller.dispatch(
                                                  const ConfirmSwapAction())
                                              : null,
                                          child: Text(state
                                                  .swapSelection.isNotEmpty
                                              ? 'DEĞİŞTİR (${state.swapSelection.length})'
                                              : 'DEĞİŞTİR'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: _canAct
                                              ? () => controller.dispatch(
                                                  const ToggleSwapModeAction())
                                              : null,
                                          child: const Text('VAZGEÇ'),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _SmallButton(
                                          label: 'PAS GEÇ',
                                          onPressed:
                                              _canAct ? _handlePass : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _SmallButton(
                                          label: 'DEĞİŞTİR',
                                          onPressed: _canAct &&
                                                  state.bag.isNotEmpty
                                              ? () => controller.dispatch(
                                                  const ToggleSwapModeAction())
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _SmallButton(
                                          label: 'KARIŞTIR',
                                          onPressed: _canAct
                                              ? () => controller.dispatch(
                                                  const ShuffleRackAction())
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _SmallButton(
                                          label: 'GERİ AL',
                                          onPressed:
                                              _canAct && state.placed.isNotEmpty
                                                  ? () => controller.dispatch(
                                                      const RecallAllAction())
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _SmallButton(
                                          label: 'TORBA ${state.bag.length}',
                                          // Web'de Torba hiç disable olmaz — YZ'nin
                                          // sırasında/oyun bitince de açılabilir.
                                          onPressed: () =>
                                              showRemainingTilesModal(
                                                  context, state, _rackIndex),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
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

/// Rafın yanındaki OYNA/YENİ OYUN — web'in `rounded-lg px-5 bg-accent`
/// görünümü; raf kartı boyuna uzasa da köşe yarıçapı sabit kalır.
final ButtonStyle _playButtonStyle = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF2563EB),
  foregroundColor: Colors.white, // web: text-white
  padding: const EdgeInsets.symmetric(horizontal: 20),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  textStyle: const TextStyle(
    // ButtonStyle.textStyle tema fontunu MİRAS ALMAZ — fontFamily
    // verilmezse testlerde Ahem bloklarına düşer (bkz. mobile/CLAUDE.md).
    fontFamily: 'SpaceGrotesk',
    fontSize: 13,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  ),
);

/// Alt sıradaki dar aksiyon butonları — web btn-raised-neutral'ın 11px
/// bold/uppercase görünümüne yakın kompakt buton (gerçek nömorfik buton
/// dili sonraki "GameHeader görsel dili" parçasının işi).
class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _SmallButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        minimumSize: const Size(0, 36),
        side: const BorderSide(color: Color(0xFFDCE2EA)),
        foregroundColor: const Color(0xFF1B2430),
        backgroundColor: const Color(0xFFF5F7FA),
        // Web btn-raised-neutral: rounded-md — Material'ın hap (stadium)
        // varsayılanı değil.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
