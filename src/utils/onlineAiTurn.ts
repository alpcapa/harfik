// Kelimeki — Canlı oyunlarda YZ koltuğunun sırasını arka planda tetikler
// (Faz 3, Adım 5 — CLAUDE.md'deki plan). Dedike bir sunucu süreci yok:
// herhangi bir katılımcının cihazı uygulamayı her açtığında (App.tsx'teki
// diğer arka plan işleriyle — flushPendingGames/logGuestVisit — aynı
// desende) kendi aktif Canlı oyunlarını tarar; sırası bir YZ koltuğunda
// olan bir oyun bulursa `play-ai-turn` Edge Function'ını tetikler — YZ'nin
// hamlesi TAMAMEN sunucuda hesaplanır, rafı hiçbir zaman bu istemciye (ya
// da başka hiçbir istemciye) gönderilmez. Birden fazla istemci aynı anda
// tetiklerse `submit_move`'un kendi satır kilidi çifte gönderimi zaten
// engeller — burada ekstra bir kilitleme mekanizmasına gerek yok.
import { fetchOnlineGameState, listMyOnlineGames, triggerAiTurn } from '../lib/api';

// Bir oyunda art arda birden fazla YZ turu birikmiş olabilir (ör. kimse
// uzun süre açmadıysa) — güvenlik için üst sınır, pratikte tek bir YZ
// koltuğu olduğundan (bkz. online_game_ai_slot_rule migration'ı) genelde
// bir kez döner.
const MAX_AI_TURNS_PER_GAME = 4;

export async function triggerPendingAiTurns(): Promise<void> {
  let games;
  try {
    games = await listMyOnlineGames();
  } catch (err) {
    console.error('[Kelimeki] triggerPendingAiTurns hatası:', err);
    return;
  }
  const active = games.filter((g) => g.status === 'active');
  for (const game of active) {
    for (let i = 0; i < MAX_AI_TURNS_PER_GAME; i++) {
      const publicState = await fetchOnlineGameState(game.id);
      if (!publicState || publicState.is_game_over) break;
      const slot = game.slots[publicState.current];
      if (!slot || slot.type !== 'ai') break;
      const { played } = await triggerAiTurn(game.id);
      if (!played) break;
    }
  }
}
