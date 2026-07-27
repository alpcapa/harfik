// Kelimeki — Supabase veri erişim katmanı
//
// Tüm fonksiyonlar Supabase yapılandırılmamışsa güvenli biçimde boş/no-op
// döner, böylece oyun çevrimdışı da çalışır.
import { FunctionsHttpError } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from './supabase';
import type {
  AdminActivityGranularity,
  AdminEngagementActivityPoint,
  AdminEngagementTotals,
  AdminFeedbackRow,
  AdminFriendActivityPoint,
  AdminFriendTotals,
  AdminGameActivityPoint,
  AdminGameScope,
  AdminGuestSourceRow,
  AdminGuestDeviceRow,
  AdminGuestStandaloneRow,
  AdminMember,
  AdminUserActivityPoint,
  BoardSnapshotTile,
  FeedbackSource,
  FriendRelation,
  FriendRow,
  FriendSearchResult,
  GameHistoryEntry,
  GameLiker,
  Gender,
  IncomingFriendRequest,
  LeaderboardRow,
  MyLeaderboardRank,
  NewGame,
  PlayerStats,
  Profile,
  SharedGameData,
  WordMeaning,
} from './database.types';
import { getLocalMeaning } from '../data/meanings';
import { trLower } from '../utils/turkish';

/**
 * Tamamlanan bir oyunu kaydeder (oturum açıksa). Eklenen kaydın id'sini döner.
 *
 * `game.id` verilmişse (bkz. `gameSync.ts`'deki offline kuyruk) bu, o kayıt
 * için sabit/istemci tarafında üretilmiş bir uuid'dir: bağlantı kesikken
 * yapılan bir deneme sunucuya ulaşmış ama cevabı istemciye dönmemiş olabilir
 * — bu durumda kuyruk aynı kaydı `id` sabit kalacak şekilde tekrar dener.
 * `games.id` birincil anahtar olduğundan ikinci deneme "23505" (unique
 * violation) hatası alır; bu, "zaten kaydedildi" anlamına geldiğinden hata
 * değil BAŞARI sayılır — aksi halde kayıt kuyrukta sonsuza dek kalır.
 */
export async function saveGame(game: NewGame): Promise<string | null> {
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null; // yalnızca oturum açanların skoru kaydedilir

  const { data, error } = await supabase
    .from('games')
    .insert({ ...game, user_id: user.id })
    .select('id')
    .single();
  if (error) {
    if (error.code === '23505' && game.id) return game.id;
    console.error('[Kelimeki] saveGame hatası:', error.message);
    return null;
  }
  return data?.id ?? null;
}

/**
 * Bir oyunun bittiğini, ne kadar sürdüğünü ve tek/çok oturumlu olup
 * olmadığını kaydeder — giriş yapmış ya da misafir, fark etmez. Tamamen
 * anonim/sayaç amaçlıdır (skor/kelime gibi kişisel veri yok); asıl skor
 * kaydı hâlâ yalnızca giriş yapmış kullanıcılar için `saveGame`/`games`
 * tablosu üzerinden yürür. `multiSession`,
 * `GameState.multiSession`'dan gelir — oyun bitmeden en az bir kez
 * tarayıcı/uygulama kapatılıp devam ettirildiyse true. `completed=false`,
 * oyunun normal biçimde bitmediğini, 7 gün hareketsizlik sonrası terk
 * edilmiş sayılıp silindiğini belirtir (bkz. `gameStorage.ts`
 * `takePendingAbandonedGame`) — admin panelinin Büyüme grafiği bu iki
 * durumu ayrı gösterir. `endedBySurrender`, `GameState.endReason ===
 * 'surrender'`'dan gelir — bir/birden fazla oyuncunun teslim olmasıyla
 * aktif oyuncu sayısı 1'e düşüp oyunun aniden bitmesi; bu tür oyunlar
 * `completed=true` olsa da "Bitirilen" sayısına/ortalama süresine değil
 * ayrı bir "Teslim" serisine dahil edilir (teslim genelde saniyeler içinde
 * geldiğinden gerçek oyun süresini yansıtmaz).
 */
export async function logGameFinish(
  playerCount: number,
  durationSeconds: number,
  multiSession: boolean,
  completed = true,
  endedBySurrender = false,
): Promise<void> {
  if (!supabase) return;
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase
    .from('game_finishes')
    .insert({
      user_id: user?.id ?? null,
      player_count: playerCount,
      duration_seconds: durationSeconds,
      multi_session: multiSession,
      completed,
      ended_by_surrender: endedBySurrender,
    });
  if (error) {
    console.error('[Kelimeki] logGameFinish hatası:', error.message);
  }
}

/**
 * Misafir (girişsiz) bir ziyareti anonim olarak kaydeder — admin panelinin
 * Büyüme > Kullanıcı grafiğindeki "Ziyaret" serisi için (bkz.
 * `src/utils/visitTracking.ts`). `anonId`, cihazda `localStorage`'da
 * saklanan rastgele bir uuid'dir; hiçbir kişisel veri taşımaz. Çağıran
 * (App.tsx) yalnızca oturum açık DEĞİLKEN ve günde bir kez çağırır — sunucu
 * tarafı da yalnızca `anon` rolünden (girişsiz) insert'e izin verir
 * (`guest_visits_insert_anon` RLS politikası). `utmSource`, cihazda ilk
 * temas (first-touch) olarak saklanan `?ref=` etiketidir (bkz.
 * `captureUtmSource`/`getStoredUtmSource`) — `?ref=` ile hiç gelinmemişse
 * `null` gönderilir ve admin RPC'sinde "direkt" olarak sayılır. `deviceType`
 * ve `isStandalone`, `src/utils/visitTracking.ts`'teki `getDeviceType`/
 * `isStandaloneDisplay`'den gelir — admin panelindeki ayrı "Cihaz" ve "Ana
 * Ekrana Ekleme" dökümleri için.
 */
export async function logGuestVisit(
  anonId: string,
  utmSource: string | null,
  deviceType: 'mobile' | 'desktop',
  isStandalone: boolean,
): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase
    .from('guest_visits')
    .insert({ anon_id: anonId, utm_source: utmSource, device_type: deviceType, is_standalone: isStandalone });
  if (error) {
    console.error('[Kelimeki] logGuestVisit hatası:', error.message);
  }
}

/**
 * Liderlik tablosunu sayfalı biçimde döner (toplam puana göre azalan).
 * `Leaderboard` bileşeni önce ilk 10'u, sonra kaydırdıkça `offset`'i
 * artırarak listenin sonuna kadar lazy-load ile devam eder.
 */
export async function fetchLeaderboard(limit = 10, offset = 0): Promise<LeaderboardRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('leaderboard')
    .select('*')
    .order('total_score', { ascending: false })
    .range(offset, offset + limit - 1);
  if (error) {
    console.error('[Kelimeki] fetchLeaderboard hatası:', error.message);
    return [];
  }
  return (data as LeaderboardRow[]) ?? [];
}

/** Oturum açan kullanıcının toplam puana göre sırasını döner. */
export async function fetchMyLeaderboardRank(userId: string): Promise<MyLeaderboardRank | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('my_leaderboard_rank', { p_user_id: userId });
  if (error) {
    console.error('[Kelimeki] fetchMyLeaderboardRank hatası:', error.message);
    return null;
  }
  const row = Array.isArray(data) ? data[0] : null;
  return row ? { rank: Number(row.rank), total_score: Number(row.total_score) } : null;
}

/**
 * Belirli bir oyuncunun (varsayılan: oturum açan kullanıcı) belirli oyuncu
 * sayısındaki istatistik özetini döner. `userId` verilirse (admin panelindeki
 * oyuncu detay görünümü) o kullanıcının istatistiği döner — `player_stats`
 * view'ı `games` tablosundaki herkese-açık select politikasını (leaderboard
 * için) miras aldığından bu ekstra bir yetki gerektirmez.
 */
export async function fetchPlayerStats(
  playerCount: number,
  userId?: string,
): Promise<PlayerStats | null> {
  if (!supabase) return null;
  let uid = userId;
  if (!uid) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return null;
    uid = user.id;
  }

  const { data, error } = await supabase
    .from('player_stats')
    .select('*')
    .eq('user_id', uid)
    .eq('player_count', playerCount)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchPlayerStats hatası:', error.message);
    return null;
  }
  return (data as PlayerStats) ?? null;
}

/**
 * Belirli bir oyuncunun (varsayılan: oturum açan kullanıcı) belirli oyuncu
 * sayısındaki oyunlarını sayfalı biçimde döner (en yeni önce),
 * `GameHistoryModal`'ın kaydırdıkça yüklemesi (lazy load) için. `hasMore`,
 * bir sonraki sayfanın olup olmadığını bildirir. `userId` verilirse (admin
 * panelindeki ya da Sanal Lig'den açılan oyuncu detayı) o kullanıcının
 * geçmişi döner — `games` tablosunun SELECT politikası herhangi bir girişli
 * kullanıcıya açık olduğundan (herkes herkesin oyununu görüp beğenebilsin/
 * paylaşabilsin diye) bu ekstra bir yetki gerektirmez.
 *
 * `favoritesOnly` verilirse dönen liste artık hedef kullanıcının SAHİP
 * OLDUĞU oyunlar değil, hedef kullanıcının BEĞENDİĞİ oyunlardır (`game_likes`
 * tablosu üzerinden — sahiplik fark etmez, kendi oyunu da başkasının oyunu
 * da olabilir; `GameHistoryModal` zaten oyuncu isimlerini gösterdiğinden bu
 * ayrım oradan belli olur). Sıralama bu durumda beğenilme anına göredir.
 *
 * Her satırdaki `liked_by_me`, hedef kullanıcıdan BAĞIMSIZ olarak, bu isteği
 * yapan (oturum açan) kullanıcının o oyunu beğenip beğenmediğini gösterir —
 * böylece başka birinin kartına bakarken bile kalp ikonu kendi beğeni
 * durumunu yansıtır ve tıklanabilir kalır. `like_count`, o oyunu toplam kaç
 * kullanıcının beğendiğini gösterir (`game_like_stats` RPC'si, tek sorguda
 * her ikisini birden döner).
 */
export async function fetchMyGames(
  playerCount: number,
  offset: number,
  limit = 20,
  userId?: string,
  favoritesOnly = false,
): Promise<{ games: GameHistoryEntry[]; hasMore: boolean }> {
  if (!supabase) return { games: [], hasMore: false };
  const {
    data: { user: viewer },
  } = await supabase.auth.getUser();
  const targetUid = userId ?? viewer?.id;
  if (!targetUid) return { games: [], hasMore: false };

  const cols = 'id, created_at, player_count, players, player_score, ai_score, rank, surrendered';
  type Row = Omit<GameHistoryEntry, 'liked_by_me' | 'like_count'>;
  let rows: Row[];
  let hasMore: boolean;

  if (favoritesOnly) {
    const { data, error } = await supabase
      .from('game_likes')
      .select(`created_at, games!inner(${cols})`)
      .eq('user_id', targetUid)
      .eq('games.player_count', playerCount)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit); // limit+1 satır: sonraki sayfa var mı anlamak için
    if (error) {
      console.error('[Kelimeki] fetchMyGames (favoriler) hatası:', error.message);
      return { games: [], hasMore: false };
    }
    const liked = (data as unknown as { games: Row }[]) ?? [];
    rows = liked.slice(0, limit).map((r) => r.games);
    hasMore = liked.length > limit;
  } else {
    const { data, error } = await supabase
      .from('games')
      .select(cols)
      .eq('user_id', targetUid)
      .eq('player_count', playerCount)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit);
    if (error) {
      console.error('[Kelimeki] fetchMyGames hatası:', error.message);
      return { games: [], hasMore: false };
    }
    const all = (data as Row[]) ?? [];
    rows = all.slice(0, limit);
    hasMore = all.length > limit;
  }

  const stats = new Map<string, { likeCount: number; likedByMe: boolean }>();
  if (viewer && rows.length > 0) {
    const { data: likeStats } = await supabase.rpc('game_like_stats', {
      p_game_ids: rows.map((r) => r.id),
    });
    for (const s of (likeStats as { game_id: string; like_count: number; liked_by_me: boolean }[]) ?? []) {
      stats.set(s.game_id, { likeCount: Number(s.like_count), likedByMe: s.liked_by_me });
    }
  }

  return {
    games: rows.map((r) => ({
      ...r,
      liked_by_me: stats.get(r.id)?.likedByMe ?? false,
      like_count: stats.get(r.id)?.likeCount ?? 0,
    })),
    hasMore,
  };
}

/**
 * Bir oyunu oturum açan kullanıcı için beğenip beğenmediğini tersine çevirir
 * (`toggle_game_like` RPC'si — `game_likes` tablosunda yalnızca çağıranın
 * kendi satırını ekleyip/silen bir fonksiyon; beğenme sahiplik oyunun
 * kendisiyle değil beğenen kişiyle ilgili olduğundan HERHANGİ bir oyun
 * üzerinde çalışır, yalnızca kendi oyunlarınla sınırlı değil). Başarısızsa
 * (ör. çevrimdışı) `null` döner — çağıran iyimser güncellemeyi geri almalı.
 */
export async function toggleGameLike(gameId: string): Promise<boolean | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('toggle_game_like', { p_game_id: gameId });
  if (error) {
    console.error('[Kelimeki] toggleGameLike hatası:', error.message);
    return null;
  }
  return data as boolean;
}

/**
 * Bir oyunu beğenen kullanıcıları (en yeni önce) döner — `GameHistoryModal`'da
 * beğeni sayısına dokununca açılan "Beğenenler" listesi için (`game_likers`
 * RPC'si, security definer: `profiles` tablosunun kendi SELECT RLS'i
 * başkalarının adını okumaya izin vermediğinden gerekiyor, tıpkı
 * `leaderboard` view'ının aynı sebeple RLS'i bypass etmesi gibi).
 */
export async function fetchGameLikers(gameId: string): Promise<GameLiker[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('game_likers', { p_game_id: gameId });
  if (error) {
    console.error('[Kelimeki] fetchGameLikers hatası:', error.message);
    return [];
  }
  return (data as GameLiker[]) ?? [];
}

/**
 * Tek bir oyunun bitişteki tahta anlık görüntüsünü döner — `fetchMyGames`'in
 * liste sorgusuna DAHİL EDİLMEZ (satır başına birkaç KB'a varabildiğinden
 * sayfa yükünü şişirmesin diye); yalnızca `GameHistoryModal`'da bir oyuna
 * tıklanıp genişletildiğinde ayrıca çekilir. Bu sütun eklenmeden önceki
 * kayıtlarda null.
 */
export async function fetchGameBoardSnapshot(gameId: string): Promise<BoardSnapshotTile[] | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('games')
    .select('board_snapshot')
    .eq('id', gameId)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchGameBoardSnapshot hatası:', error.message);
    return null;
  }
  return (data?.board_snapshot as BoardSnapshotTile[] | null) ?? null;
}

/**
 * Bir oyunu herkese açık `/game/:id` linkiyle görülebilir işaretler
 * (`set_game_shared` RPC'si — artık sahiplik gerektirmiyor, herhangi bir
 * girişli kullanıcı gördüğü herhangi bir oyunu paylaşabilir; geri alınamaz
 * bir bayrak). "Paylaş" aksiyonuna her basışta çağrılır; idempotent
 * olduğundan zaten paylaşılmış bir oyunda zararsızdır.
 */
export async function markGameShared(gameId: string): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.rpc('set_game_shared', { p_game_id: gameId });
  if (error) {
    console.error('[Kelimeki] markGameShared hatası:', error.message);
    return false;
  }
  return true;
}

/**
 * Herkese açık `/game/:id` sayfası (bkz. `SharedGamePage`) için bir oyunun
 * paylaşılan verisini döner — `get_shared_game` RPC'si yalnızca
 * `shared=true` olan bir oyun için veri döner (RLS'i security-definer içinde
 * kendi kontrolüyle bypass eder), girişsiz de çağrılabilir. Paylaşılmamış ya
 * da var olmayan bir id için `null`.
 */
export async function fetchSharedGame(gameId: string): Promise<SharedGameData | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('get_shared_game', { p_game_id: gameId });
  if (error) {
    console.error('[Kelimeki] fetchSharedGame hatası:', error.message);
    return null;
  }
  const row = Array.isArray(data) ? data[0] : null;
  return (row as SharedGameData | null) ?? null;
}

/** Oturum açan oyuncunun profilini döner. */
export async function fetchMyProfile(): Promise<Profile | null> {
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchMyProfile hatası:', error.message);
    return null;
  }
  return (data as Profile) ?? null;
}

// ── Arkadaşlık sistemi ───────────────────────────────────────────────────────

/**
 * Nickname/ad ile mevcut Kelimeki kullanıcılarını arar (en az 2 karakter,
 * en fazla 20 sonuç) — `search_users_for_friend` RPC'si (security definer,
 * `profiles`'ın kendi kilitli SELECT RLS'ini bypass eder, tıpkı
 * `game_likers`/`leaderboard` gibi). E-posta hiçbir zaman dönmez. Her
 * sonuçtaki `relation`, UI'ın doğru butonu (Ekle/İstek Gönderildi/Kabul Et/
 * Arkadaşsınız) gösterebilmesi için mevcut ilişkiyi bildirir.
 */
export async function searchUsersForFriend(query: string): Promise<FriendSearchResult[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('search_users_for_friend', { p_query: query });
  if (error) {
    console.error('[Kelimeki] searchUsersForFriend hatası:', error.message);
    return [];
  }
  return (data as FriendSearchResult[]) ?? [];
}

/**
 * Bir kullanıcıya arkadaşlık isteği gönderir (doğrudan tablo insert'i —
 * `friend_requests_insert_self` RLS politikası yalnızca kendi adına eklemeye
 * izin verir). Karşı taraftan zaten bekleyen bir istek varsa sunucudaki
 * `handle_friend_request_insert` trigger'ı bunu otomatik olarak karşılıklı
 * kabule çevirir. Hiçbir e-posta bildirimi gönderilmez — yalnızca uygulama
 * içi (in-app) görünür, maliyet/gürültü yaratmasın diye.
 */
export async function sendFriendRequest(targetId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');
  const { error } = await supabase
    .from('friend_requests')
    .insert({ user_id: user.id, friend_id: targetId });
  if (error) throw new Error(error.message);
}

/** Bana gelen bir isteği kabul eder (`accepted`'a çeker) ya da reddeder (satırı siler). */
export async function respondFriendRequest(requesterId: string, accept: boolean): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');

  if (accept) {
    const { error } = await supabase
      .from('friend_requests')
      .update({ status: 'accepted', responded_at: new Date().toISOString() })
      .eq('user_id', requesterId)
      .eq('friend_id', user.id);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabase
      .from('friend_requests')
      .delete()
      .eq('user_id', requesterId)
      .eq('friend_id', user.id);
    if (error) throw new Error(error.message);
  }
}

/** Arkadaşlıktan çıkarır (kabul edilmiş satırı siler — her iki taraf da çağırabilir). */
export async function removeFriend(friendId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');
  const { error } = await supabase
    .from('friend_requests')
    .delete()
    .or(`and(user_id.eq.${user.id},friend_id.eq.${friendId}),and(user_id.eq.${friendId},friend_id.eq.${user.id})`);
  if (error) throw new Error(error.message);
}

/** Kabul edilmiş arkadaş listesini döner (en son kabul edilen önce). */
export async function fetchFriends(): Promise<FriendRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('list_friends');
  if (error) {
    console.error('[Kelimeki] fetchFriends hatası:', error.message);
    return [];
  }
  return (data as FriendRow[]) ?? [];
}

/**
 * Oturum açan kullanıcı ile verilen kullanıcı arasındaki arkadaşlık ilişkisini
 * döner — `PlayerScoreCard`'daki arkadaş ekle/çıkar simgesi için. RPC değil,
 * `friend_requests` tablosunu doğrudan sorgular: `friend_requests_select_own`
 * RLS politikası zaten yalnızca ilişkinin taraflarından biri (auth.uid())
 * olunca satırı görmeye izin veriyor, sorgu her zaman çağıranı içerdiğinden
 * bu koşul otomatik sağlanır. Kendi kartına bakarken ya da girişsizken null.
 */
export async function fetchFriendRelation(targetId: string): Promise<FriendRelation | null> {
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user || user.id === targetId) return null;

  const { data, error } = await supabase
    .from('friend_requests')
    .select('user_id, status')
    .or(`and(user_id.eq.${user.id},friend_id.eq.${targetId}),and(user_id.eq.${targetId},friend_id.eq.${user.id})`)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchFriendRelation hatası:', error.message);
    return null;
  }
  if (!data) return null;
  if (data.status === 'accepted') return 'accepted';
  return data.user_id === user.id ? 'pending_outgoing' : 'pending_incoming';
}

/** Bana gelen, henüz cevaplanmamış arkadaşlık isteklerini döner (`UserMenu` rozeti bu sayıyı kullanır). */
export async function fetchIncomingFriendRequests(): Promise<IncomingFriendRequest[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('list_incoming_friend_requests');
  if (error) {
    console.error('[Kelimeki] fetchIncomingFriendRequests hatası:', error.message);
    return [];
  }
  return (data as IncomingFriendRequest[]) ?? [];
}

/**
 * Oturum açan kullanıcının kalıcı/reusable davet linkinin token'ını döner —
 * ilk çağrıda oluşturur, sonrakilerde aynı token'ı geri verir
 * (`create_friend_invite_link` RPC'si). Bu link WhatsApp/SMS/DM gibi
 * kanallardan paylaşılabilir; henüz Kelimeki üyesi olmayan biri de
 * tıklayıp kayıt olduktan sonra otomatik arkadaş olur — asıl kullanıcı
 * kazanım (büyüme) mekanizması bu.
 */
export async function createFriendInviteLink(): Promise<string | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('create_friend_invite_link');
  if (error) {
    console.error('[Kelimeki] createFriendInviteLink hatası:', error.message);
    return null;
  }
  return (data as string) ?? null;
}

/** `/davet/:token` sayfasının girişsiz de gösterebileceği önizleme bilgisi ("X seni davet ediyor"). */
export async function fetchFriendInviteInfo(token: string): Promise<string | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('get_friend_invite_info', { p_token: token });
  if (error) {
    console.error('[Kelimeki] fetchFriendInviteInfo hatası:', error.message);
    return null;
  }
  const row = Array.isArray(data) ? data[0] : null;
  return row?.inviter_name ?? null;
}

/**
 * Bir davet linkini kabul eder — çağıran girişli olmalı. Arkadaşlığı
 * doğrudan `accepted` olarak açar (link tıklaması zaten bilinçli bir onay,
 * pending beklemeye gerek yok), linkin `use_count`'unu artırır ve ilk kezse
 * `profiles.invited_by`'ı doldurur. Davet edenin adını döner.
 */
export async function acceptFriendInvite(token: string): Promise<string | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('accept_friend_invite', { p_token: token });
  if (error) {
    console.error('[Kelimeki] acceptFriendInvite hatası:', error.message);
    throw new Error(error.message);
  }
  const row = Array.isArray(data) ? data[0] : null;
  return row?.inviter_name ?? null;
}

/**
 * Kelimeyi sunucu tarafında doğrular (is_valid_word RPC). Supabase
 * yapılandırılmamışsa null döner; çağıran yerel sözlüğe düşmelidir.
 */
export async function isValidWordRemote(word: string): Promise<boolean | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('is_valid_word', {
    p_word: word,
  });
  if (error) {
    console.error('[Kelimeki] isValidWordRemote hatası:', error.message);
    return null;
  }
  return Boolean(data);
}

/**
 * Bir kelimenin sözlük anlamlarını döner. Önce Supabase'i (word_meaning RPC)
 * dener; yapılandırılmamışsa ya da kayıt yoksa yerel sözlüğe (meanings.json)
 * düşer. Hiçbir yerde bulunamazsa null döner.
 */
export async function fetchMeaning(word: string): Promise<WordMeaning | null> {
  // Tahtadaki harfler büyük olabilir; Türkçe kurallarıyla küçült (İ→i, I→ı).
  const norm = trLower(word);
  if (supabase) {
    const { data, error } = await supabase.rpc('word_meaning', {
      p_word: norm,
    });
    if (error) {
      console.error('[Kelimeki] fetchMeaning hatası:', error.message);
    } else if (Array.isArray(data) && data.length > 0) {
      const row = data[0] as WordMeaning;
      if (Array.isArray(row.meanings) && row.meanings.length > 0) {
        return {
          word: row.word,
          pos: row.pos,
          meanings: row.meanings,
        };
      }
    }
  }
  // Yerel yedek.
  const local = await getLocalMeaning(norm);
  if (local) {
    return { word: norm, pos: local.pos, meanings: local.meanings };
  }
  return null;
}

// ── Admin paneli ────────────────────────────────────────────────────────────

/** Tüm kayıtlı kullanıcıları döner (yalnızca is_admin=true için, RPC içinde kontrol edilir). */
export async function fetchAdminMembers(): Promise<AdminMember[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_list_members');
  if (error) {
    console.error('[Kelimeki] fetchAdminMembers hatası:', error.message);
    return [];
  }
  return (data as AdminMember[]) ?? [];
}

/** Son `periods` kova için yeni kayıt sayısını döner (yalnızca admin — Büyüme > Kullanıcı). */
export async function fetchAdminUserActivitySeries(
  periods: number,
  granularity: AdminActivityGranularity,
): Promise<AdminUserActivityPoint[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_user_activity_series', {
    p_periods: periods,
    p_granularity: granularity,
  });
  if (error) {
    console.error('[Kelimeki] fetchAdminUserActivitySeries hatası:', error.message);
    return [];
  }
  return (data as AdminUserActivityPoint[]) ?? [];
}

/**
 * Son `periods` kova için oyun başlatma/bitirme sayılarını ve ortalama oyun
 * süresini döner (yalnızca admin — Büyüme > Oyun). `scope` Toplam/Kayıtlı/
 * Misafir kombosuna, `playerCount` Toplam/2/4 kişilik kırılımına karşılık
 * gelir (null = tüm oyuncu sayıları).
 */
export async function fetchAdminGameActivitySeries(
  periods: number,
  granularity: AdminActivityGranularity,
  scope: AdminGameScope,
  playerCount: number | null,
): Promise<AdminGameActivityPoint[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_game_activity_series', {
    p_periods: periods,
    p_granularity: granularity,
    p_scope: scope,
    p_player_count: playerCount,
  });
  if (error) {
    console.error('[Kelimeki] fetchAdminGameActivitySeries hatası:', error.message);
    return [];
  }
  return (data as AdminGameActivityPoint[]) ?? [];
}

/**
 * Son `periods` kova için beğeni (game_likes) ve paylaşma (games.shared_at —
 * yalnızca ilk paylaşım anı) sayılarını döner (yalnızca admin — Büyüme >
 * Oyun). `shared_at` eklenmeden önce paylaşılmış oyunlar bu seride hiçbir
 * kovaya girmez (bkz. `fetchAdminEngagementTotals`).
 */
export async function fetchAdminEngagementActivitySeries(
  periods: number,
  granularity: AdminActivityGranularity,
): Promise<AdminEngagementActivityPoint[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_engagement_activity_series', {
    p_periods: periods,
    p_granularity: granularity,
  });
  if (error) {
    console.error('[Kelimeki] fetchAdminEngagementActivitySeries hatası:', error.message);
    return [];
  }
  return (data as AdminEngagementActivityPoint[]) ?? [];
}

/**
 * Tüm zamanların toplam beğeni sayısını ve toplam paylaşılan oyun sayısını
 * döner (yalnızca admin — Büyüme > Oyun).
 */
export async function fetchAdminEngagementTotals(): Promise<AdminEngagementTotals | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('admin_engagement_totals');
  if (error) {
    console.error('[Kelimeki] fetchAdminEngagementTotals hatası:', error.message);
    return null;
  }
  const row = (data as AdminEngagementTotals[] | null)?.[0];
  return row ?? null;
}

/**
 * Son `periods` kova için gönderilen arkadaşlık isteği ve kurulan
 * arkadaşlık sayılarını döner (yalnızca admin — Büyüme > Kullanıcı).
 */
export async function fetchAdminFriendActivitySeries(
  periods: number,
  granularity: AdminActivityGranularity,
): Promise<AdminFriendActivityPoint[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_friend_activity_series', {
    p_periods: periods,
    p_granularity: granularity,
  });
  if (error) {
    console.error('[Kelimeki] fetchAdminFriendActivitySeries hatası:', error.message);
    return [];
  }
  return (data as AdminFriendActivityPoint[]) ?? [];
}

/**
 * Tüm zamanların arkadaşlık/istek/davet linki sayılarını döner (yalnızca
 * admin — Büyüme > Kullanıcı).
 */
export async function fetchAdminFriendTotals(): Promise<AdminFriendTotals | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('admin_friend_totals');
  if (error) {
    console.error('[Kelimeki] fetchAdminFriendTotals hatası:', error.message);
    return null;
  }
  const row = (data as AdminFriendTotals[] | null)?.[0];
  return row ?? null;
}

/**
 * Son `days` gün içinde kaynak (`?ref=` etiketi) başına benzersiz misafir
 * ziyaretçi sayısını döner (yalnızca admin — Büyüme > Kullanıcı). `?ref=`
 * ile hiç gelinmemiş ziyaretler "direkt" olarak gruplanır.
 */
export async function fetchAdminGuestSourceBreakdown(days = 30): Promise<AdminGuestSourceRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_guest_source_breakdown', { p_days: days });
  if (error) {
    console.error('[Kelimeki] fetchAdminGuestSourceBreakdown hatası:', error.message);
    return [];
  }
  return (data as AdminGuestSourceRow[]) ?? [];
}

/**
 * Son `days` gün içinde cihaz tipi (mobil/masaüstü) başına benzersiz
 * misafir ziyaretçi sayısını döner (yalnızca admin — Büyüme > Kullanıcı).
 */
export async function fetchAdminGuestDeviceBreakdown(days = 30): Promise<AdminGuestDeviceRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_guest_device_breakdown', { p_days: days });
  if (error) {
    console.error('[Kelimeki] fetchAdminGuestDeviceBreakdown hatası:', error.message);
    return [];
  }
  return (data as AdminGuestDeviceRow[]) ?? [];
}

/**
 * Son `days` gün içinde ana ekrana eklenip eklenmediğine (standalone) göre
 * benzersiz misafir ziyaretçi sayısını döner (yalnızca admin — Büyüme >
 * Kullanıcı).
 */
export async function fetchAdminGuestStandaloneBreakdown(days = 30): Promise<AdminGuestStandaloneRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_guest_standalone_breakdown', { p_days: days });
  if (error) {
    console.error('[Kelimeki] fetchAdminGuestStandaloneBreakdown hatası:', error.message);
    return [];
  }
  return (data as AdminGuestStandaloneRow[]) ?? [];
}

/** Tüm geri bildirim mesajlarını döner (RLS: yalnızca is_admin=true okuyabilir). */
export async function fetchAdminFeedback(): Promise<AdminFeedbackRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('feedback')
    .select(
      'id, user_id, email, message, handled, created_at, source, reply, replied_at, replied_by, origin, subject, related_to',
    )
    .order('created_at', { ascending: false });
  if (error) {
    console.error('[Kelimeki] fetchAdminFeedback hatası:', error.message);
    return [];
  }
  return (data as AdminFeedbackRow[]) ?? [];
}

/** Bir geri bildirim mesajını okundu/okunmadı işaretler (yalnızca admin). */
export async function markFeedbackHandled(id: string, handled: boolean): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('feedback').update({ handled }).eq('id', id);
  if (error) console.error('[Kelimeki] markFeedbackHandled hatası:', error.message);
}

/** Bir geri bildirim mesajını siler (yalnızca admin). */
export async function deleteFeedback(id: string): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('feedback').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

/** Admin Edge Function'larını (feedback-reply, admin-send-message) çağırır — hata
 * durumunda Edge Function'ın döndürdüğü JSON gövdesini okuyup gerçek mesajı fırlatır
 * (supabase-js `functions.invoke` bunu otomatik yapmıyor). */
async function invokeAdminFunction(name: string, body: Record<string, unknown>): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const { data, error } = await supabase.functions.invoke(name, { body });
  if (error) {
    if (error instanceof FunctionsHttpError) {
      let detail: string | undefined;
      try {
        detail = (await error.context.json())?.error;
      } catch {
        // gövde JSON değilse yoksay, aşağıda generic mesaj kullanılır
      }
      throw new Error(detail || error.message);
    }
    throw new Error(error.message);
  }
  if (data?.error) throw new Error(data.error);
}

/**
 * Bir geri bildirime yanıt gönderir — `feedback-reply` Edge Function'ı
 * çağırır, bu da yanıtı Brevo Transactional API ile gönderenin e-postasına
 * iletir ve başarılıysa `feedback.reply`/`replied_at`/`replied_by`'ı kaydeder
 * (yalnızca admin; e-postası olmayan geri bildirimler yanıtlanamaz).
 */
export async function sendFeedbackReply(
  feedbackId: string,
  reply: string,
  recipientName?: string,
): Promise<void> {
  await invokeAdminFunction('feedback-reply', {
    feedback_id: feedbackId,
    reply,
    recipient_name: recipientName,
  });
}

/**
 * Admin panelinin Üyeler tablosundan bir üyeye serbest metinli mesaj
 * gönderir — `admin-send-message` Edge Function'ı, konu/gövdeyi Brevo
 * Transactional API ile iletir (yalnızca admin) ve `feedback` tablosuna
 * `origin: 'admin'` olarak kaydeder (kime ne yazıldığı Geri Bildirim
 * sekmesinde görünsün diye).
 */
export async function sendMemberMessage(
  toUserId: string,
  toEmail: string,
  toName: string,
  subject: string,
  message: string,
): Promise<void> {
  await invokeAdminFunction('admin-send-message', {
    to_user_id: toUserId,
    to_email: toEmail,
    to_name: toName,
    subject,
    message,
  });
}

// ── Geri bildirim ───────────────────────────────────────────────────────────

/**
 * Kullanıcıdan gelen görüş/şikayet mesajını kaydeder (girişli ya da anonim).
 * `relatedTo`, e-postadaki "cevap için tıklayın" linkine gömülü bir referans
 * (?contact=1&re=<id>) varsa bu yeni mesajı önceki mesaja bağlar.
 */
export async function submitFeedback(
  message: string,
  email: string | undefined,
  source: FeedbackSource,
  relatedTo?: string | null,
): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { error } = await supabase.from('feedback').insert({
    user_id: user?.id ?? null,
    email: email?.trim() || user?.email || null,
    message: message.trim(),
    source,
    related_to: relatedTo ?? null,
  });
  if (error) throw new Error(error.message);
}

// ── Auth yardımcıları ───────────────────────────────────────────────────────

export async function signUp(
  email: string,
  password: string,
  firstName: string,
  lastName: string,
  nickname?: string,
  termsAccepted = false,
  channel: 'direct' | 'form' = 'direct',
  gender?: Gender | null,
  birthDate?: string | null,
) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  // sharedxp_pending_profile formatı trigger tarafından okunur (camelCase).
  // display_name üst seviyede gönderilir çünkü trigger onu doğrudan
  // raw_user_meta_data->>'display_name' olarak okuyor (e-posta doğrulaması
  // açıkken signUp() session döndürmez, bu yüzden aşağıdaki update'e
  // güvenilemez — nickname'in kaybolmaması için metadata'da baştan olmalı).
  // gender/birthDate de aynı sebeple burada (trigger tarafında,
  // handle_new_user), oturum açılmasını bekleyen bir update'te değil.
  const result = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        sharedxp_pending_profile: {
          firstName,
          lastName,
          agreedToTerms: termsAccepted,
          gender: gender || null,
          birthDate: birthDate || null,
        },
        signup_channel: channel,
        ...(nickname ? { display_name: nickname } : {}),
      },
    },
  });
  // Oturum hemen açıldıysa (e-posta doğrulaması kapalı) kabul zamanını yaz.
  if (!result.error && result.data.session) {
    await supabase
      .from('profiles')
      .update({ agreed_to_terms: termsAccepted })
      .eq('id', result.data.session.user.id);
  }
  return result;
}

export async function signIn(email: string, password: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.signInWithPassword({ email, password });
}

export async function signOut() {
  if (!supabase) return;
  await supabase.auth.signOut();
}

// ── Profil güncelleme ────────────────────────────────────────────────────────

/** Oturum açan oyuncunun profilini günceller. Profil yoksa oluşturur. */
export async function updateProfile(
  patch: {
    first_name?: string;
    last_name?: string;
    display_name?: string | null;
    avatar_url?: string;
    gender?: Gender | null;
    birth_date?: string | null;
  },
): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');

  const { data, error } = await supabase
    .from('profiles')
    .update(patch)
    .eq('id', user.id)
    .select('id');
  if (error) throw new Error(error.message);

  // Profil satırı henüz oluşturulmamışsa kayıt aç.
  if (!data || data.length === 0) {
    const firstName = patch.first_name ?? '';
    const lastName = patch.last_name ?? '';
    const { error: createErr } = await supabase.from('profiles').insert({
      id: user.id,
      username: user.email ? user.email.split('@')[0] : user.id,
      first_name: firstName,
      last_name: lastName,
      display_name: patch.display_name ?? null,
      avatar_url: patch.avatar_url ?? null,
    });
    if (createErr) throw new Error(createErr.message);
  }
}

/** Oturum açan kullanıcının e-postasını değiştirir (doğrulama gerekebilir). */
export async function updateEmail(email: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.updateUser({ email });
}

/** Şifre sıfırlama e-postası gönderir. Bağlantı tıklanınca uygulamanın köküne döner. */
export async function sendPasswordReset(email: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin,
  });
}

/**
 * PASSWORD_RECOVERY oturumunda (sıfırlama e-postasındaki bağlantı tıklandıktan
 * sonra) yeni şifreyi belirler — eski şifre gerekmez, oturum linkin kendisiyle
 * zaten doğrulanmıştır.
 */
export async function setNewPassword(newPassword: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.updateUser({ password: newPassword });
}

/**
 * Profil fotoğrafını `avatars` depolama kovasına yükler, profildeki
 * avatar_url'i günceller ve genel (public) URL'i döner.
 */
export async function uploadAvatar(file: File): Promise<string> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');

  const ext = (file.name.split('.').pop() || 'png').toLowerCase();
  const path = `${user.id}/avatar.${ext}`;

  const { error: upErr } = await supabase.storage
    .from('avatars')
    .upload(path, file, { upsert: true, contentType: file.type });
  if (upErr) throw new Error(upErr.message);

  const { data } = supabase.storage.from('avatars').getPublicUrl(path);
  // Önbelleği atlamak için sürüm parametresi ekle (aynı yol üzerine yazılır).
  const url = `${data.publicUrl}?v=${Date.now()}`;
  await updateProfile({ avatar_url: url });
  return url;
}

export { isSupabaseConfigured };
