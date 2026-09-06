// Oyun sonu ekranı — src/components/GameOver.tsx portu.
// Kazanan başlığı (beraberlikte altın "BERABERE"), rankPlayers sırasıyla
// oyuncu listesi (Kalan/Toplam/k-lig sütunları, Teslim rozeti), toplam hamle.
//
// 20 Ağustos 2026 — ÜÇ sütun: en sağa k-lig katkısı eklendi (oyun
// kartlarındaki gibi, AYNI `leaguePoints`/`formatLeaguePoints`'tan). Ad artık
// kırpılıyor (`ellipsis` zaten vardı ama `Flexible` yerine `Expanded` ile
// alan garanti ediliyor). Genişlikler webde ölçülen mürekkebe göre: Kalan 32,
// Toplam 40 (skor "271" 20px mono'da 36.7px — 36'lık kutuda soldaki eksiye
// yapışıyordu), k-lig 24; aralar 4. Skor 22→20, başlık 10→9 (ad alanına ~8px).
// Web ile BİREBİR aynı sayılar — biri değişirse öteki de değişmeli.
// Web'deki iki link de portlandı: "Oyun Geçmişi" + "Görüş Bildir"
// ([onFeedback] verilmezse — bazı testler — ikincisi hiç çizilmez).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../text_scale.dart';
import 'modal_shell.dart';
import 'player_badge.dart';
import 'player_colors.dart';
import '../tokens.dart';
import '../ai_level_badge.dart';

Future<void> showGameOverModal(BuildContext context, GameState state,
    {required VoidCallback onOpenHistory,
    VoidCallback? onFeedback,
    AiLevel? aiLevel}) {
  return showDialog<void>(
    context: context,
    builder: (context) => GameOverModal(
        state: state,
        onOpenHistory: onOpenHistory,
        onFeedback: onFeedback,
        aiLevel: aiLevel),
  );
}

class GameOverModal extends StatelessWidget {
  final GameState state;

  /// "Oyun Geçmişi" linki — web GameOver `onOpenHistory`.
  ///
  /// Bilerek ZORUNLU bir callback: hangi `GameState`in hamle geçmişinin
  /// gösterileceğine EBEVEYN karar verir (web'in aynı ayrımı — `App.tsx`
  /// kendi `state`ini, `OnlineGameScreen.tsx` sunucu satırlarından türettiği
  /// `historyState`i geçiyor). Önceden bu widget doğrudan
  /// `showMoveHistoryModal(context, state)` çağırıyordu; Canlı oyunda o
  /// `state` reducer'ın state'i ve `moveHistory`si BOŞ olduğundan (hamleler
  /// sunucudan `online_game_moves` ile geliyor) oyun sonu modalından açılan
  /// geçmiş "Henüz kazanılmış bir puan yok." diyordu — aynı ekranın tahta
  /// altındaki "Hamleler" linki ise doğru listeyi gösteriyordu (14 Ağustos
  /// 2026, cihaz testi).
  final VoidCallback onOpenHistory;

  /// "Görüş Bildir" linki — web GameOver `onOpenFeedback`.
  final VoidCallback? onFeedback;

  /// Zorluk rozeti/puanı — YZ ekranı `aiLevelForBadge(state.aiLevel,
  /// isAiGame: true)` geçirir (her seviyede, Normal turuncu); Canlı ekran
  /// GEÇİRMEZ → rozet yok, puan Normal (web `GameOver.aiLevel` aynı).
  final AiLevel? aiLevel;

  const GameOverModal(
      {super.key,
      required this.state,
      required this.onOpenHistory,
      this.onFeedback,
      this.aiLevel});

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
              color: tie ? kGold : winColor.base,
            ),
          ),
          // Zorluk rozeti (ROADMAP #23 Faz 4) — web `<AiLevelBadge size="sm">`:
          // YZ oyununda her seviyede başlığın hemen altında; Canlı'da `aiLevel`
          // null → yok (`gap` bile açılmaz).
          if (aiLevel != null) ...[
            const SizedBox(height: 18),
            AiLevelBadge(level: aiLevel, size: AiLevelBadgeSize.sm),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white, // web bg
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Expanded(child: SizedBox()),
                    SizedBox(width: 4),
                    _ColHeader('KALAN', width: 29),
                    SizedBox(width: 8),
                    _ColHeader('TOPLAM', width: 37),
                    SizedBox(width: 4),
                    // Marka küçük harf — web'de satır `uppercase` olduğundan
                    // `normal-case` şart; burada zaten büyütme yok.
                    _ColHeader('k-lig', width: 20),
                  ],
                ),
                const SizedBox(height: 10),
                for (final r in ranked) ...[
                  _PlayerRow(
                      entry: r,
                      playerCount: state.players.length,
                      aiLevel: aiLevel),
                  const SizedBox(height: 10),
                ],
                const Divider(height: 1, color: kBorder),
                const SizedBox(height: 8),
                // Sayı etiketin YANINDA (önceden satırın iki ucundaydı) —
                // kullanıcı isteği, 20 Ağustos 2026; web ile aynı.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Toplam hamle',
                      style:
                          TextStyle(fontSize: 12, color: kMuted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.turnCount}',
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: kMuted,
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
                onPressed: onOpenHistory,
                child: const Text(
                  'OYUN GEÇMİŞİ',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: kMuted,
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
                      color: kMuted,
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
    // SINIF 3 (sarma) — kutu ölçekle büyür, sığmazsa metin küçülür ama
    // ASLA satır kırmaz (1 Eylül 2026: "KALAN" ölçek 1,3'te "KAL/AN"
    // oluyordu). Gerekçe: `ui/text_scale.dart`.
    return ScaledCell(
      width: width,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 9,
          // web `tracking-wide` = 0.025em → 9px'te 0.225 (önceden 0.5'ti,
          // sessiz bir sapmaydı; başlıklar bu yüzden webden genişti).
          letterSpacing: 0.225,
          color: kMuted,
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final RankedPlayer entry;
  final int playerCount;

  /// `GameState.aiLevel` — null = Normal (bugünkü tablo).
  final AiLevel? aiLevel;
  const _PlayerRow(
      {required this.entry, required this.playerCount, this.aiLevel});

  @override
  Widget build(BuildContext context) {
    final p = entry.player;
    final col = playerColors[p.colorIndex % playerColors.length];
    var remaining = 0;
    for (final t in p.rack) {
      remaining += t.pts;
    }
    // k-lig katkısı — oyun kartlarıyla AYNI fonksiyondan, yani kart ile Skor
    // Kartı/k-lig listesi sessizce ayrışamaz. Buradaki "-2" TESLİM cezasıdır;
    // soldaki "Kalan" sütunundaki eksi ise raf taşı düşümü — iki farklı şey,
    // bu yüzden iki ayrı sütun ve iki ayrı başlık.
    final points = leaguePoints(entry.rank, playerCount,
        surrendered: p.surrendered, aiLevel: aiLevel);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              PlayerBadge(
                  index: entry.index, colorIndex: p.colorIndex, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${entry.rank}. ${p.name}',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style:
                      const TextStyle(fontSize: 15, color: kText),
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
                      color: kRed,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        ScaledCell(
          width: 29,
          child: Text(
            remaining > 0 ? '-$remaining' : '',
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 13,
              color: kMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ScaledCell(
          width: 37,
          child: Text(
            '${p.score}',
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: col.base,
            ),
          ),
        ),
        const SizedBox(width: 4),
        ScaledCell(
          width: 20,
          child: Text(
            formatLeaguePoints(points),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: points > 0 ? kGreen : (points < 0 ? kRed : kMuted),
            ),
          ),
        ),
      ],
    );
  }
}
