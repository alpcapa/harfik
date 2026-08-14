// Kelimeki — insan oyuncunun (her zaman 1. oyuncu — hesap sahibi) oyun sonu
// kaydını (NewGame) oluşturur. App.tsx'ten saf bir fonksiyon olarak çıkarıldı
// ki hem canlı akış (kullanıcı "Çık"a bastığında, güncel reducer state'iyle)
// hem de arka plandaki 7 gün terk-edilme temizliği (gameStorage.ts'ten
// localStorage'da bulunan, artık süresi dolmuş bir GameState'le) aynı
// mantığı paylaşabilsin — surrenderingIndex olmadan çağrılırsa normal (teslim
// olunmadan) bitişi, verilirse o oyuncunun teslim olmasını temsil eder.
import type { GameState } from '../game/types';
import type { GameResult, NewGame } from '../lib/database.types';
import { rankPlayers } from './ranking';
import { serializeBoardSnapshot } from './boardSnapshot';
import { CLIENT_PLATFORM } from './platform';

export function buildGameRecord(
  state: GameState,
  surrendered: boolean,
  surrenderingIndex?: number,
): NewGame | null {
  // Anlık teslim olma akışında bu, SURRENDER dispatch edilmeden HEMEN önce
  // (hâlâ eski state ile) çağrılır — o yüzden teslim olacak oyuncu burada
  // elle surrendered:true/score:0 olarak işaretlenir, yoksa rankPlayers onu
  // hâlâ aktifmiş gibi puanına göre sıralar.
  const effectivePlayers =
    surrenderingIndex != null
      ? state.players.map((p, i) =>
          i === surrenderingIndex ? { ...p, surrendered: true, score: 0 } : p,
        )
      : state.players;
  const human = effectivePlayers[0];
  if (!human || human.isAI) return null;
  const opponents = effectivePlayers.slice(1);
  if (opponents.length === 0) return null;
  const bestOpponentScore = Math.max(...opponents.map((p) => p.score));
  const ranked = rankPlayers(effectivePlayers);
  const humanEntry = ranked.find((r) => r.index === 0)!;
  const rank = humanEntry.rank;
  const tiedForFirst = ranked.filter((r) => r.rank === 1).length;
  const result: GameResult = surrendered
    ? 'lose'
    : rank > 1
      ? 'lose'
      : tiedForFirst > 1
        ? 'tie'
        : 'win';
  const players = ranked.map((r) => ({
    name: r.player.name,
    score: r.player.score,
    is_ai: r.player.isAI,
    surrendered: r.player.surrendered,
    colorIndex: r.player.colorIndex,
  }));
  return {
    id: crypto.randomUUID(),
    created_at: new Date().toISOString(),
    player_score: human.score,
    ai_score: bestOpponentScore,
    result,
    rank,
    turn_count: state.turnCount,
    player_count: state.players.length,
    move_count: human.moveCount || null,
    best_move_score: human.bestMoveScore || null,
    best_word_score: human.bestWordScore || null,
    longest_word: human.longestWord || null,
    move_points_sum: human.moveScoreSum || null,
    surrendered,
    players,
    board_snapshot: serializeBoardSnapshot(state.board),
    // Tam hamle dökümü — "Tüm Oyunlarım"daki hamle geçmişi ikonu bunu
    // gösterir. Yerel oyunlarda tek kaynak burası: `moveHistory` yalnızca
    // `GameState`te yaşıyor ve oyun bitince kayboluyor. Alan KIRPILMAZ
    // (`invasionFrom` vergi satırları dahil) — modal onları kart olarak
    // göstermiyor ama toplam puana katıyor, atılırlarsa toplamlar bozulur.
    moves: state.moveHistory,
    // İstemci platformu — mobil lansmanının ölçülebilmesi için (14 Ağustos
    // 2026). Değer `platform.ts`ten geliyor (web'de sabit 'web'); Flutter
    // portunun karşılığı `game_record.dart`'ta `currentPlatform` (ios/android/
    // app-web). Canlı oyunlarda bu satırı SUNUCU yazdığından orada null
    // kalır — platform `online_game_clients`ten çözülür.
    platform: CLIENT_PLATFORM,
  };
}
