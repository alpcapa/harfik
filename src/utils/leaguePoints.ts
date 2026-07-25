// Kelimeki — bir oyun sonucundan Sanal Lig (SL) puanı hesaplama
// GameHistoryModal ve SharedGamePage arasında paylaşılan tek kaynak.
import type { GamePlayerSnapshot } from '../lib/database.types';

/**
 * Bir oyuncunun bu oyundan kazandığı Sanal Lig puanı — leaderboard/
 * player_stats view'larıyla aynı formül: teslim → -2, 1. → +2, 2. (yalnızca
 * 2 kişilik değilse) → +1, diğerleri 0.
 */
export function leaguePoints(rank: number, playerCount: number, surrendered?: boolean): number {
  if (surrendered) return -2;
  if (rank === 1) return 2;
  if (rank === 2 && playerCount !== 2) return 1;
  return 0;
}

export function formatLeaguePoints(points: number): string {
  return points > 0 ? `+${points}` : points < 0 ? `${points}` : '-';
}

/**
 * `players` final sıralamasına göre (aktifler puana göre azalan, teslim
 * olanlar en sonda) diziliymiş durumda — burada yalnızca eşit puanlı (ve
 * aynı teslim durumundaki) bitişik oyunculara aynı sırayı vererek gerçek
 * "rank"i (dizideki ham pozisyon değil) çıkarıyoruz. Aksi halde beraberlikte
 * 2. sıradaki oyuncu, 1.yle aynı puanı almasına rağmen SL sütununda 0
 * gösteriyordu.
 */
export function computeRanks(players: GamePlayerSnapshot[]): number[] {
  let rank = 1;
  let prevScore: number | null = null;
  let prevSurrendered = false;
  return players.map((p, i) => {
    if (prevScore === null || p.score !== prevScore || !!p.surrendered !== prevSurrendered) {
      rank = i + 1;
    }
    prevScore = p.score;
    prevSurrendered = !!p.surrendered;
    return rank;
  });
}
