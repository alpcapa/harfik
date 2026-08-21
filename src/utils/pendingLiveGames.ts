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

/**
 * Sayılar bilinmiyorsa (istek ağ katmanında düştü) `null` döner — `0` DEĞİL.
 *
 * Ayrım kritik (21 Ağustos 2026): `0` dönmek yalnızca rozeti kaybettirmiyor,
 * `Setup.tsx`'teki `applyLoginDefaultOnce`'ı da TÜKETİYORDU — yani başarısız
 * tek bir istek, "girişte sırası sendeyse Canlı sekmesini aç" kararını o
 * oturum için kalıcı olarak yakıyordu. Bu, CLAUDE.md'de kayıtlı 5 Ağustos
 * 2026 hatasının aynısı (orada karar BAYAT veriyle veriliyordu, burada
 * BAŞARISIZ veriyle): tek seferlik kararlar yalnızca BAŞARILI veriyle
 * tüketilmeli.
 */
export async function fetchPendingLiveGameCounts(): Promise<PendingLiveGameCounts | null> {
  const rows = await listMyOnlineGames();
  if (rows === null) return null;
  // `g.status === 'pending'` şartı LiveGamesTab'daki `invites` kovasıyla
  // BİREBİR aynı olmak zorunda — aksi halde süresi dolup iptal edilmiş
  // (`abandoned`) bir davet rozetleri şişirir: Setup'taki "Arkadaşınla (N)",
  // PWA ikon rozeti, ve girişte otomatik Canlı sekmesine geçiren
  // `inviteCount > 0` koşulu (4 Ağustos 2026'da ikisi birlikte düzeltildi).
  const inviteCount = rows.filter(
    (g) => g.my_role === 'invitee' && g.my_invite_status === 'pending' && g.status === 'pending',
  ).length;
  const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
  if (activeIds.length === 0) {
    return { inviteCount, myTurnCount: 0 };
  }
  const turns = await fetchOnlineGameTurns(activeIds);
  // Sıra bilinmiyorsa sayı da bilinmiyor. `inviteCount`'u tek başına dönmek
  // mümkündü ama eksik bir toplam rozeti sessizce KÜÇÜLTÜRDÜ; "bilmiyoruz"
  // deyip son bilineni korumak dürüst olan.
  if (turns === null) return null;
  const myTurnCount = rows.filter((g) => {
    if (g.status !== 'active') return false;
    const idx = g.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
    return turns[g.id] === idx;
  }).length;
  return { inviteCount, myTurnCount };
}
