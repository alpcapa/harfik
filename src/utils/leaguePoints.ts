// Kelimeki — bir oyun sonucundan k-lig (SL) puanı hesaplama
// GameHistoryModal ve SharedGamePage arasında paylaşılan tek kaynak.
import type { AiLevel, GamePlayerSnapshot } from '../lib/database.types';

/**
 * Bir oyuncunun bu oyundan kazandığı k-lig puanı — sunucudaki
 * `league_points_for()` SQL fonksiyonuyla ve portun `league_points.dart`ıyla
 * AYNI tablo (ROADMAP 23.0; `npm run verify-league-points` üçünü kilitler):
 *
 *   | Seviye | 1. sıra | 2. sıra (yalnız 4 kişilik) | Teslim |
 *   | Kolay  |   1     |   0                        |  -2    |
 *   | Normal |   2     |   1                        |  -2    |
 *   | Zor    |   4     |   2                        |  -2    |
 *
 * `level` yoksa (`undefined`/`null` — seviyesiz eski kayıtlar, TÜM Canlı
 * oyunlar) Normal: sunucunun `coalesce(p_ai_level, 'normal')` sözleşmesi.
 * ⚠ `level`e VARSAYILAN DEĞER VERME (`level = 'normal'`): `verify-league-points`
 * ariteyi `leaguePoints.length` ile okuyor ve JS varsayılanlı parametreyi
 * saymaz — betik "Faz 3 öncesi" sanıp seviyeleri sınamaz.
 * ⚠ Gövde Dart eşiyle SATIR SATIR aynı dallanma: betik iki dosyanın sayı
 * dizisini karşılaştırıyor.
 */
export function leaguePoints(
  rank: number,
  playerCount: number,
  surrendered?: boolean,
  level?: AiLevel | null,
): number {
  if (surrendered) return -2;
  const kolay = level === 'kolay';
  const zor = level === 'zor';
  if (rank === 1) return kolay ? 1 : zor ? 4 : 2;
  if (rank === 2 && playerCount !== 2) return kolay ? 0 : zor ? 2 : 1;
  return 0;
}

export function formatLeaguePoints(points: number): string {
  return points > 0 ? `+${points}` : points < 0 ? `${points}` : '-';
}

/**
 * `players`'ın dizideki sırasından BAĞIMSIZ, `src/utils/ranking.ts`'teki
 * `rankPlayers` ile aynı kuralı (aktifler puana göre azalan, teslim olanlar
 * puanlarından bağımsız her zaman en sonda, kendi aralarında yine puana göre
 * azalan; eşit puanlı ve aynı teslim durumundaki bitişik oyuncular aynı
 * sırayı paylaşır) kendi içinde uygulayıp her oyuncu için gerçek "rank"i
 * hesaplar. Dönüş dizisi `players`'la AYNI (orijinal) indekslemeyi korur —
 * çağıran `players[i]`/`ranks[i]` şeklinde eşleyebilir, girdinin önceden
 * sıralanmış olması gerekmez.
 *
 * Önceden bu fonksiyon girdinin ZATEN sıralı olduğunu varsayıyordu (yalnızca
 * bitişik eşitlikleri birleştiriyordu) — bu kırılgan kontrat, sunucu
 * tarafında `players` jsonb'sini koltuk sırasıyla (skorsuz) yazan bir kod
 * yolunda gerçek bir üretim hatasına yol açmıştı (bkz. CLAUDE.md,
 * `fix_online_finish_players_order`). Fonksiyonun kendisi artık bu
 * varsayıma bağlı değil.
 */
export function computeRanks(players: GamePlayerSnapshot[]): number[] {
  const withIndex = players.map((p, index) => ({ p, index }));
  const active = withIndex
    .filter((x) => !x.p.surrendered)
    .sort((a, b) => b.p.score - a.p.score);
  const surrendered = withIndex
    .filter((x) => x.p.surrendered)
    .sort((a, b) => b.p.score - a.p.score);
  const ordered = [...active, ...surrendered];

  const ranks = new Array<number>(players.length);
  let rank = 1;
  let prevScore: number | null = null;
  let prevSurrendered = false;
  ordered.forEach((x, pos) => {
    if (prevScore === null || x.p.score !== prevScore || !!x.p.surrendered !== prevSurrendered) {
      rank = pos + 1;
    }
    prevScore = x.p.score;
    prevSurrendered = !!x.p.surrendered;
    ranks[x.index] = rank;
  });
  return ranks;
}
