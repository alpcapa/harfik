// Oyun sonu ekranı — src/components/GameOver.tsx portu.
// Kazanan başlığı (beraberlikte altın "BERABERE"), rankPlayers sırasıyla
// oyuncu listesi (Kalan/Toplam sütunları, Teslim rozeti), toplam hamle.
// Web'deki iki link de portlandı: "Oyun Geçmişi" + "Görüş Bildir"
// ([onFeedback] verilmezse — bazı testler — ikincisi hiç çizilmez).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'modal_shell.dart';
import 'move_history_modal.dart';
import 'player_badge.dart';
import 'player_colors.dart';

Future<void> showGameOverModal(BuildContext context, GameState state,
    {VoidCallback? onFeedback}) {
  return showDialog<void>(
    context: context,
    builder: (context) => GameOverModal(state: state, onFeedback: onFeedback),
  );
}

class GameOverModal extends StatelessWidget {
  final GameState state;

  /// "Görüş Bildir" linki — web GameOver `onOpenFeedback`.
  final VoidCallback? onFeedback;

  const GameOverModal({super.key, required this.state, this.onFeedback});

  @override
  Widget build(BuildContext context) {
    final ranked = rankPlayers(state.players);
    final top = ranked.first;
    final tie = ranked.length > 1 && ranked[1].rank == top.rank;
    final winColor = playerColors[top.player.colorIndex % playerColors.length];

    // Web `<Modal title="" onClose={onClose}>` — başlık boş, kapatma
    // yalnızca sağ üstteki ✕ (bkz. Modal.tsx). Bottom "KAPAT" düğmesi
    // web'de hiç yok; KModal'ın ✕'i tek kapatma yolu.
    return KModal(
      title: '',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tie ? 'BERABERE' : '${trUpper(top.player.name)} KAZANDI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.bold,
              fontSize: 26,
              letterSpacing: 2,
              color: tie ? const Color(0xFFB7791F) : winColor.base,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white, // web bg
              border: Border.all(color: const Color(0xFFDCE2EA)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ColHeader('KALAN', width: 34),
                    SizedBox(width: 16),
                    _ColHeader('TOPLAM', width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                for (final r in ranked) ...[
                  _PlayerRow(entry: r),
                  const SizedBox(height: 10),
                ],
                const Divider(height: 1, color: Color(0xFFDCE2EA)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Toplam hamle',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF5A6673)),
                    ),
                    Text(
                      '${state.turnCount}',
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF5A6673),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => showMoveHistoryModal(context, state),
                child: const Text(
                  'OYUN GEÇMİŞİ',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Color(0xFF5A6673),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (onFeedback != null)
                TextButton(
                  onPressed: onFeedback,
                  child: const Text(
                    'GÖRÜŞ BİLDİR',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Color(0xFF5A6673),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  final double width;
  const _ColHeader(this.label, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.5,
          color: Color(0xFF5A6673),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final RankedPlayer entry;
  const _PlayerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = entry.player;
    final col = playerColors[p.colorIndex % playerColors.length];
    var remaining = 0;
    for (final t in p.rack) {
      remaining += t.pts;
    }
    return Row(
      children: [
        PlayerBadge(index: entry.index, colorIndex: p.colorIndex, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${entry.rank}. ${p.name}',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 15, color: Color(0xFF1B2430)),
                ),
              ),
              if (p.surrendered)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    '(TESLİM)',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            remaining > 0 ? '-$remaining' : '',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 13,
              color: Color(0xFF5A6673),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 48,
          child: Text(
            '${p.score}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: col.base,
            ),
          ),
        ),
      ],
    );
  }
}
