// Kelimeki — kullanıcının bekleyen Canlı oyun davetleri + sırası kendisinde
// olan aktif oyun sayısı. Bu hesap önceden Setup.tsx'teki "Arkadaşınla (N)"
// rozeti ile useAppIconBadge.ts'teki uygulama ikonu rozetinde ayrı ayrı
// kopyalanmıştı (kod incelemesi, dead-code/tekrar bulgusu) — tek yerde
// toplandı.
import { fetchOnlineGameTurns, listMyOnlineGames } from '../lib/api';

export interface PendingLiveGameCounts {
  /** Henüz yanıtlanmamış, çağırana gönderilmiş davet sayısı. */
  inviteCount: number;
  /** `status==='active'` olan oyunlardan sırası çağıranda olanların sayısı. */
  myTurnCount: number;
}

export async function fetchPendingLiveGameCounts(): Promise<PendingLiveGameCounts> {
  const rows = await listMyOnlineGames();
  const inviteCount = rows.filter(
    (g) => g.my_role === 'invitee' && g.my_invite_status === 'pending',
  ).length;
  const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
  if (activeIds.length === 0) {
    return { inviteCount, myTurnCount: 0 };
  }
  const turns = await fetchOnlineGameTurns(activeIds);
  const myTurnCount = rows.filter((g) => {
    if (g.status !== 'active') return false;
    const idx = g.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
    return turns[g.id] === idx;
  }).length;
  return { inviteCount, myTurnCount };
}
