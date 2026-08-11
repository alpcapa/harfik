// Oyundaki tüm oyuncuların hamle/puan geçmişi —
// src/components/MoveHistoryModal.tsx portu. Veri tamamen
// `GameState.moveHistory`'den gelir (motorla birlikte portlandı, golden
// vector'larla doğrulandı) — yeni bir asset/ağ çağrısı yok.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'modal_shell.dart';
import '../tokens.dart';

const Color _text = kText;
const Color _muted = kMuted;
const Color _accent = kAccent;
const Color _green = kGreen;
const Color _red = kRed;
const Color _gold = kGold;
const Color _border = kBorder;

Future<void> showMoveHistoryModal(BuildContext context, GameState state) {
  return showDialog<void>(
    context: context,
    builder: (context) => MoveHistoryModal(state: state),
  );
}

class MoveHistoryModal extends StatelessWidget {
  final GameState state;
  const MoveHistoryModal({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = state.moveHistory;
    var total = 0;
    for (final e in entries) {
      total += e.points;
    }
    // Vergi geliri satırları ayrı kart olarak gösterilmez (web'deki aynı
    // gerekçe: aynı hamle zaten oynayanın satırında anlatılıyor) ve hamle
    // sayısına da katılmaz.
    final display = [
      for (final e in entries)
        if (e.invasionFrom == null) e
    ];
    final scoringMoveCount = display.where((e) => e.action == null).length;

    return KModal(
      title: 'Oyun Geçmişi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: 'Bu oyunda kazanılan $scoringMoveCount hamle ve puanları. '
                  'Toplam ',
              children: [
                TextSpan(
                  text: '$total',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
                const TextSpan(text: ' puan.'),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              height: 1.6,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          if (display.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Henüz kazanılmış bir puan yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: _muted,
                ),
              ),
            )
          else
            // Web: max-h-72 overflow-y-auto — kabuğun kendi kaydırması zaten
            // var, burada yalnızca yükseklik sınırı korunur (en yeni üstte).
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 288),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = display.length - 1; i >= 0; i--) ...[
                      if (i < display.length - 1) const SizedBox(height: 6),
                      _EntryCard(entry: display[i], state: state),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final HistoryEntry entry;
  final GameState state;
  const _EntryCard({required this.entry, required this.state});

  String? get _plainLabel {
    switch (entry.action) {
      case 'pass':
        return 'Pas geçti';
      case 'exchange':
        return '${entry.tileCount} taş değiştirdi';
      case 'surrender':
        return 'Teslim oldu';
    }
    final ws = entry.wordScores;
    if (ws != null && ws.isNotEmpty) return null; // kelime rozetleriyle çizilir
    return entry.words.isNotEmpty ? entry.words.join(', ') : '—';
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final playerName =
        e.player < state.players.length ? state.players[e.player].name : '?';
    final lost = e.lostShares ?? const <LostShare>[];
    final isInvasionLoss = lost.isNotEmpty;
    final jokerCount = e.finishJokerCount ?? 0;
    final label = _plainLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, // web bg-bg
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${e.turn + 1}. $playerName',
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (label != null)
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      )
                    else
                      _WordScoreLine(scores: e.wordScores!),
                  ],
                ),
              ),
              if (e.action == null) ...[
                if (e.bingo) ...[
                  const _Badge(
                      label: 'Bingo', color: _gold), // +BINGO_BONUS rozeti
                  const SizedBox(width: 4),
                ],
                if (jokerCount > 0) ...[
                  // Yıldız glyph'i Space Mono'da yok (web'de tarayıcı yedek
                  // fontundan basar) — taş jokerindeki aynı çözüm: Material
                  // ikonu (bkz. tile_widget.dart).
                  _Badge(
                    color: _accent,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < (jokerCount >= 2 ? 2 : 1); i++)
                          const Icon(Icons.star, size: 9, color: _accent),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (isInvasionLoss) ...[
                  const _Badge(label: 'Sınır İhlali', color: _red),
                  const SizedBox(width: 4),
                ],
                Text(
                  '+${e.points}',
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _green,
                  ),
                ),
              ],
            ],
          ),
          if (isInvasionLoss)
            _note(
              lost
                  .map((s) =>
                      '${s.amount} puanı ${s.to < state.players.length ? state.players[s.to].name : '?'} kaptı')
                  .join(', '),
              _red,
            ),
          if (jokerCount > 0)
            _note(
              '${jokerCount >= 2 ? 'Çift' : 'Tek'} yıldız ile biterek '
              '+${jokerFinishBonus(jokerCount)} puan kazandı.',
              _accent,
            ),
          if (e.bingo)
            _note(
              '7 harfi birden koyup +$bingoBonus puan Bingo Bonus kazandı.',
              _gold,
            ),
        ],
      ),
    );
  }

  Widget _note(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 9,
            height: 1.3,
            color: color,
          ),
        ),
      );
}

/// Kelime kelime "SÖZCÜK (puan ×2)" satırı — puan çarpansız (ham) toplam,
/// rozet çarpanı gösterir (web'deki aynı ayrım).
class _WordScoreLine extends StatelessWidget {
  final List<WordScore> scores;
  const _WordScoreLine({required this.scores});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: 12,
      height: 1,
      fontWeight: FontWeight.bold,
      color: _text,
    );
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < scores.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${scores[i].word} (${scores[i].score}', style: style),
              if (scores[i].x3)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: _MultiplierBadge(tier: 3),
                )
              else if (scores[i].x2)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: _MultiplierBadge(tier: 2),
                ),
              Text(i < scores.length - 1 ? '),' : ')', style: style),
            ],
          ),
      ],
    );
  }
}

/// Web'deki küçük renkli rozet (Bingo / ★ / Sınır İhlali) — 8px mono,
/// rengin %10 zemini ve %40 çerçevesi.
class _Badge extends StatelessWidget {
  /// Metin rozeti (Bingo / Sınır İhlali) — `child` verilmişse yok sayılır.
  final String? label;
  final Widget? child;
  final Color color;
  const _Badge({this.label, this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child ??
          Text(
            label!,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              height: 1.2,
              color: color,
            ),
          ),
    );
  }
}

/// ×2 / ×3 kelime çarpanı rozeti — tahtadaki bonus bölgesiyle aynı gradyan.
class _MultiplierBadge extends StatelessWidget {
  final int tier;
  const _MultiplierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tier == 3
              ? const [Color(0xFFFDBA74), Color(0xFFF97316)]
              : const [Color(0xFFFDE68A), Color(0xFFFBBF24)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '×$tier',
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1,
          color: Color(0xFF7C2D12),
        ),
      ),
    );
  }
}
