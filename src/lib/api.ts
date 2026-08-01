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
  AdminGameSourceType,
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
  GameChatMessage,
  GameHistoryEntry,
  GameLiker,
  Gender,
  IncomingFriendRequest,
  LeaderboardRow,
  LocalGameSave,
  MyLeaderboardRank,
  NewGame,
  OnlineGame,
  OnlineGameMessageRow,
  OnlineGameSlot,
  OnlineGameStatePublic,
  OnlineMovePlacement,
  OnlineMoveRow,
  PlayerStats,
  Profile,
  SharedGameData,
  WordMeaning,
} from './database.types';
import { getLocalMeaning } from '../data/meanings';
import { trCompare, trLower } from '../utils/turkish';
import type { GameState, Tile } from '../game/types';

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
 * sayısındaki istatistik özetini döner. `playerCount='all'` verilirse (Skor
 * Kartı'ndaki "Genel" sekmesi) 2 ve 4 kişilik TÜM oyunların toplamı
 * `player_stats_overall` view'ından gelir — bu ayrı bir view, çünkü
 * `avg_move_score` (ağırlıklı ortalama) ve `longest_word` gibi alanlar iki
 * ayrı (player_count bazlı) satırdan client-side doğru birleştirilemez, ham
 * `games` satırlarından yeniden hesaplanmaları gerekir; dönen nesnede
 * `player_count` alanı anlamsız olduğundan `0` ile dolduruluyor (UI hiçbir
 * yerde okumuyor). `userId` verilirse (admin panelindeki oyuncu detay
 * görünümü) o kullanıcının istatistiği döner — her iki view de `games`
 * tablosundaki herkese-açık select politikasını (leaderboard için) miras
 * aldığından bu ekstra bir yetki gerektirmez.
 */
export async function fetchPlayerStats(
  playerCount: number | 'all',
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

  if (playerCount === 'all') {
    const { data, error } = await supabase
      .from('player_stats_overall')
      .select('*')
      .eq('user_id', uid)
      .maybeSingle();
    if (error) {
      console.error('[Kelimeki] fetchPlayerStats (all) hatası:', error.message);
      return null;
    }
    return data ? ({ ...data, player_count: 0 } as PlayerStats) : null;
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
 * panelindeki ya da k-lig'den açılan oyuncu detayı) o kullanıcının
 * geçmişi döner — `games` tablosunun SELECT politikası herhangi bir girişli
 * kullanıcıya açık olduğundan (herkes herkesin oyununu görüp beğenebilsin/
 * paylaşabilsin diye) bu ekstra bir yetki gerektirmez.
 *
 * `favoritesOnly` verilirse dönen liste artık hedef kullanıcının SAHİP
 * OLDUĞU oyunlar değil, hedef kullanıcının BEĞENDİĞİ oyunlardır (`list_liked_games`
 * RPC'si — sahiplik fark etmez, kendi oyunu da başkasının oyunu da olabilir;
 * `GameHistoryModal` zaten oyuncu isimlerini gösterdiğinden bu ayrım oradan
 * belli olur). Sıralama bu durumda beğenilme anına göredir. Bir Canlı oyunda
 * (`online_game_id` dolu) her insan katılımcı için AYRI bir `games` satırı
 * olduğundan (bkz. CLAUDE.md "Canlı Oyun — Faz 3"), RPC beğenilen satır
 * hangisi olursa olsun hedef kullanıcının KENDİ katılımcı satırını (varsa)
 * tercih ederek döner — aksi halde `GameHistoryModal`'daki "bu satır benim"
 * varsayımı (meIndex/güncel takma isim ikamesi) başka birinin satırını
 * gösterirken yanlış oyuncuyu "ben" sanabilirdi.
 *
 * Her satırdaki `liked_by_me`, hedef kullanıcıdan BAĞIMSIZ olarak, bu isteği
 * yapan (oturum açan) kullanıcının o oyunu beğenip beğenmediğini gösterir —
 * böylece başka birinin kartına bakarken bile kalp ikonu kendi beğeni
 * durumunu yansıtır ve tıklanabilir kalır. `like_count`, o oyunu toplam kaç
 * kullanıcının beğendiğini gösterir (`game_like_stats` RPC'si, tek sorguda
 * her ikisini birden döner).
 */
export async function fetchMyGames(
  playerCount: number | null,
  offset: number,
  limit = 20,
  userId?: string,
  favoritesOnly = false,
  // undefined: filtre yok. true: yalnızca Canlı (online_game_id dolu — bkz.
  // "Canlı Oyun — Faz 3" `games.online_game_id`). false: yalnızca yerel/Yapay
  // Zeka oyunları (online_game_id null). `RecentGamesSection`'ın "Yapay Zeka
  // ile"/"Arkadaşınla" sekmelerindeki "Son Oynadıklarım" widget'ı için.
  onlineOnly?: boolean,
): Promise<{ games: GameHistoryEntry[]; hasMore: boolean }> {
  if (!supabase) return { games: [], hasMore: false };
  const {
    data: { user: viewer },
  } = await supabase.auth.getUser();
  const targetUid = userId ?? viewer?.id;
  if (!targetUid) return { games: [], hasMore: false };

  const cols =
    'id, created_at, player_count, players, player_score, ai_score, rank, surrendered, online_game_id, message_count, user_id';
  type Row = Omit<GameHistoryEntry, 'liked_by_me' | 'like_count'>;
  let rows: Row[];
  let hasMore: boolean;

  // playerCount===null: Skor Kartı'ndaki "Genel" sekmesinden "Tüm Oyunları
  // Gör" — 2/4 kişilik fark etmeksizin tüm oyunları listeler, `.eq` filtresi
  // hiç uygulanmaz.
  if (favoritesOnly) {
    const { data, error } = await supabase.rpc('list_liked_games', {
      p_user_id: targetUid,
      p_player_count: playerCount,
      p_offset: offset,
      p_limit: limit,
    });
    if (error) {
      console.error('[Kelimeki] fetchMyGames (favoriler) hatası:', error.message);
      return { games: [], hasMore: false };
    }
    const liked = (data as (Row & { liked_at: string })[]) ?? [];
    rows = liked.slice(0, limit);
    hasMore = liked.length > limit;
  } else {
    let query = supabase.from('games').select(cols).eq('user_id', targetUid);
    if (playerCount !== null) query = query.eq('player_count', playerCount);
    if (onlineOnly === true) query = query.not('online_game_id', 'is', null);
    else if (onlineOnly === false) query = query.is('online_game_id', null);
    const { data, error } = await query
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
 * Bitmiş bir Canlı oyunun dondurulmuş sohbet kaydını döner —
 * `fetchGameBoardSnapshot` ile birebir aynı desen: `fetchMyGames`'in liste
 * sorgusuna dahil edilmez (bkz. `message_count`), yalnızca `GameHistoryModal`
 * (sohbet rozetine tıklanınca `GameChatHistoryModal`) lazy çeker. Yerel/YZ
 * oyunlarında (Oyun İçi Mesajlaşma — Faz 1 kapsam dışı) her zaman boş döner.
 */
export async function fetchGameMessages(gameId: string): Promise<GameChatMessage[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('games')
    .select('messages')
    .eq('id', gameId)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchGameMessages hatası:', error.message);
    return [];
  }
  return (data?.messages as GameChatMessage[] | null) ?? [];
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
  return ((data as FriendSearchResult[]) ?? []).sort((a, b) => trCompare(a.name, b.name));
}

/**
 * Arama kutusu boşken "Ara & Ekle" sekmesinde gösterilen, tüm üyelerin
 * alfabetik/sayfalı listesi — `list_users_for_friend` RPC'si (security
 * definer, `search_users_for_friend` ile aynı şekli/gerekçeyi paylaşır ama
 * bilerek ayrı bir fonksiyon: arama en az 2 karakter/20 sonuç kısıtını
 * korurken bu, `Leaderboard`'daki lazy-load deseniyle (offset/limit)
 * kaydırdıkça tüm üyelere ulaşabiliyor).
 */
export async function listUsersForFriend(offset: number, limit: number): Promise<FriendSearchResult[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('list_users_for_friend', {
    p_offset: offset,
    p_limit: limit,
  });
  if (error) {
    console.error('[Kelimeki] listUsersForFriend hatası:', error.message);
    return [];
  }
  return ((data as FriendSearchResult[]) ?? []).sort((a, b) => trCompare(a.name, b.name));
}

/**
 * Bir kullanıcıya arkadaşlık isteği gönderir (doğrudan tablo insert'i —
 * `friend_requests_insert_self` RLS politikası yalnızca kendi adına eklemeye
 * izin verir). Karşı taraftan zaten bekleyen bir istek varsa sunucudaki
 * `handle_friend_request_insert` trigger'ı bunu otomatik olarak karşılıklı
 * kabule çevirir. 29 Temmuz 2026'ya kadar bu tamamen uygulama-içi (in-app)
 * kalıyordu — hiç e-posta gönderilmiyordu (maliyet/gürültü kaygısı,
 * `friends_system` migration'ı). Kullanıcı geri bildirimiyle bu karardan
 * dönüldü: alıcı uygulamayı hiç açmazsa istekten habersiz kalıyordu. Artık,
 * insert karşılıklı otomatik kabulle SONUÇLANMADIYSA (hâlâ 'pending'),
 * `notify-friend-request` Edge Function'ı ile alıcıya işlemsel bir e-posta
 * bildirimi gönderilir (`marketing_consent`'e bağlı değil — bkz. CLAUDE.md).
 */
export async function sendFriendRequest(targetId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');
  const { data, error } = await supabase
    .from('friend_requests')
    .insert({ user_id: user.id, friend_id: targetId })
    .select('status')
    .single();
  if (error) throw new Error(error.message);
  if (data?.status === 'pending') {
    void notifyFriendRequest(targetId);
  }
}

/**
 * `sendFriendRequest`'in az önce açtığı isteği alıcıya e-posta ile bildirir
 * (`notify-friend-request` Edge Function'ı). Best-effort/fire-and-forget:
 * istek zaten gönderilmiş olduğundan bir e-posta hatası kullanıcıya hiç
 * yansıtılmaz, yalnızca loglanır.
 */
async function notifyFriendRequest(friendId: string): Promise<void> {
  if (!supabase) return;
  try {
    await invokeEdgeFunction('notify-friend-request', { friend_id: friendId });
  } catch (err) {
    console.error('[Kelimeki] notifyFriendRequest hatası:', (err as Error).message);
  }
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

/** Kabul edilmiş arkadaş listesini döner — isme göre alfabetik sıralı (RPC
 * en son kabul edilene göre döner, `trCompare` ile client tarafında yeniden
 * sıralanır). */
export async function fetchFriends(): Promise<FriendRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('list_friends');
  if (error) {
    console.error('[Kelimeki] fetchFriends hatası:', error.message);
    return [];
  }
  return ((data as FriendRow[]) ?? []).sort((a, b) => trCompare(a.name, b.name));
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

// ── Canlı oyun (Faz 2 — davet/kabul) ────────────────────────────────────────

/**
 * Yeni bir Canlı oyun kurar (`create_online_game` RPC'si). `slots`, index
 * 0'ı çağıranın kendisi olacak şekilde tam koltuk kompozisyonunu taşır —
 * insan koltukları için gerçek (ve zaten arkadaş olunan) bir `user_id`, YZ
 * koltukları için sadece `{type:'ai'}`. İnsan koltuklarındaki her arkadaş
 * için sunucu tarafında bir `game_invites` satırı açılır; hiç insan
 * davetlisi yoksa oyun beklemeden doğrudan `active` olur. Oluşan oyunun
 * id'sini döner. 29 Temmuz 2026'dan beri açılan her davetliye ayrıca
 * `notify-game-invite` Edge Function'ı ile işlemsel bir e-posta bildirimi
 * de gönderilir (bkz. `sendFriendRequest`'teki aynı gerekçe) — 7 günlük
 * davet zaman aşımından (`online_game_invite_expiry`) önce davetlinin
 * uygulamayı hiç açmadan davetten habersiz kalmasını önlemek için.
 */
export async function createOnlineGame(
  playerCount: 2 | 4,
  slots: OnlineGameSlot[]
): Promise<string> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const { data, error } = await supabase.rpc('create_online_game', {
    p_player_count: playerCount,
    p_slots: slots,
  });
  if (error) throw new Error(error.message);
  const gameId = data as string;
  void notifyGameInvite(gameId);
  return gameId;
}

/**
 * `createOnlineGame`'in az önce açtığı davetleri e-posta ile bildirir
 * (`notify-game-invite` Edge Function'ı). Best-effort/fire-and-forget —
 * oyun zaten kurulmuş olduğundan bir e-posta hatası kullanıcıya hiç
 * yansıtılmaz, yalnızca loglanır.
 */
async function notifyGameInvite(gameId: string): Promise<void> {
  if (!supabase) return;
  try {
    await invokeEdgeFunction('notify-game-invite', { online_game_id: gameId });
  } catch (err) {
    console.error('[Kelimeki] notifyGameInvite hatası:', (err as Error).message);
  }
}

/**
 * Oturum açan kullanıcının taraf olduğu (kurduğu ya da davet edildiği) tüm
 * Canlı oyunları döner (`list_my_online_games` RPC'si) — en yeni önce.
 */
export async function listMyOnlineGames(): Promise<OnlineGame[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('list_my_online_games');
  if (error) {
    console.error('[Kelimeki] listMyOnlineGames hatası:', error.message);
    return [];
  }
  return (data as OnlineGame[]) ?? [];
}

/**
 * Bana gelen bir Canlı oyun davetini kabul/red eder
 * (`respond_to_game_invite` RPC'si). Kabul edilince, o oyundaki tüm
 * davetler artık kabul edilmişse oyun sunucu tarafında `active`'e geçer.
 */
export async function respondToGameInvite(inviteId: string, accept: boolean): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const { error } = await supabase.rpc('respond_to_game_invite', {
    p_invite_id: inviteId,
    p_accept: accept,
  });
  if (error) throw new Error(error.message);
}

// ── Canlı oyun (Faz 3 — gerçek zamanlı senkron oynanış) ─────────────────────

/** Bir Canlı oyunun katılımcılara açık anlık state'i (`online_game_states`). */
export async function fetchOnlineGameState(gameId: string): Promise<OnlineGameStatePublic | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('online_game_states')
    .select('*')
    .eq('online_game_id', gameId)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameState hatası:', error.message);
    return null;
  }
  return (data as OnlineGameStatePublic) ?? null;
}

/**
 * Verilen aktif Canlı oyunların her biri için "sırası kimde" (`current`
 * koltuk indeksi) bilgisini tek sorguda döner — `LiveGamesTab`'ın "Sıra
 * sende" rozetini ve `Setup`'taki "Arkadaşınla" sekmesindeki bekleyen
 * sayısını hesaplamak için kullanılır. `online_game_states`e doğrudan okuma
 * (RPC değil) — RLS zaten yalnızca katılımcının erişebileceği satırları döner.
 */
export async function fetchOnlineGameTurns(gameIds: string[]): Promise<Record<string, number>> {
  if (!supabase || gameIds.length === 0) return {};
  const { data, error } = await supabase
    .from('online_game_states')
    .select('online_game_id, current')
    .in('online_game_id', gameIds);
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameTurns hatası:', error.message);
    return {};
  }
  const map: Record<string, number> = {};
  for (const row of (data ?? []) as { online_game_id: string; current: number }[]) {
    map[row.online_game_id] = row.current;
  }
  return map;
}

/**
 * Verilen aktif Canlı oyunların her biri için sırası gelen oyuncunun son
 * hamle tarihini (`turn_deadline`) döner — `LiveGamesTab`'ın "kalan süre"
 * göstergesi için. Süre dolan bir koltuk `check_turn_timeout` çağrılana
 * kadar otomatik teslim olmaz (bkz. `checkOnlineGameTurnTimeout`), bu
 * fonksiyon yalnızca OKUR, hiçbir şeyi tetiklemez.
 */
export async function fetchOnlineGameDeadlines(gameIds: string[]): Promise<Record<string, string | null>> {
  if (!supabase || gameIds.length === 0) return {};
  const { data, error } = await supabase
    .from('online_game_states')
    .select('online_game_id, turn_deadline')
    .in('online_game_id', gameIds);
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameDeadlines hatası:', error.message);
    return {};
  }
  const map: Record<string, string | null> = {};
  for (const row of (data ?? []) as { online_game_id: string; turn_deadline: string | null }[]) {
    map[row.online_game_id] = row.turn_deadline;
  }
  return map;
}

/**
 * Sırası gelen oyuncunun 48 saatlik süresi dolduysa onu otomatik teslim
 * eder (`check_turn_timeout` RPC'si) — süre dolmadıysa no-op. Cron/arka
 * plan job'u yok (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6"), bu yüzden
 * herhangi bir katılımcının istemcisi (LiveGamesTab listeyi her açtığında,
 * OnlineGameScreen her refresh'te) bunu çağırarak "hafif" bir tarama
 * yapar — submit_move'un satır kilidiyle aynı desende olduğundan birden
 * fazla istemcinin aynı anda çağırması zararsız.
 */
export async function checkOnlineGameTurnTimeout(gameId: string): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('check_turn_timeout', { p_game_id: gameId });
  if (error) console.error('[Kelimeki] checkOnlineGameTurnTimeout hatası:', error.message);
}

/**
 * Bir Canlı oyun hâlâ `pending` durumundayken (en az bir davet
 * yanıtlanmamışken) 7 gün geçtiyse oyunu tamamen iptal eder
 * (`online_games.status='abandoned'`) — süre dolmadıysa no-op. Yerel
 * oyundaki `ABANDON_TIMEOUT_MS` ile aynı süre/gerekçe; kimseye ceza
 * uygulanmaz, oyun sadece listeden kalkar. `check_turn_timeout` ile aynı
 * "hafif" desen: herhangi bir tarafın istemcisi (kurucu ya da davetli,
 * yanıtlamış olsun olmasın) tetikleyebilir.
 */
export async function checkInviteExpiry(gameId: string): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('check_invite_expiry', { p_game_id: gameId });
  if (error) console.error('[Kelimeki] checkInviteExpiry hatası:', error.message);
}

/** Çağıranın KENDİ rafı (`get_my_online_rack` RPC'si) — başka hiçbir oyuncununki hiçbir zaman döndürülmez. */
export async function getMyOnlineRack(gameId: string): Promise<Tile[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('get_my_online_rack', { p_game_id: gameId });
  if (error) throw new Error(error.message);
  return (data as Tile[]) ?? [];
}

/** Bir Canlı oyunun tüm hamle geçmişi, en eskiden en yeniye (`online_game_moves`). */
export async function fetchOnlineGameMoves(gameId: string): Promise<OnlineMoveRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('online_game_moves')
    .select('*')
    .eq('online_game_id', gameId)
    .order('turn', { ascending: true })
    .order('created_at', { ascending: true });
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameMoves hatası:', error.message);
    return [];
  }
  return (data as OnlineMoveRow[]) ?? [];
}

export interface SubmitMovePayload {
  action: 'play' | 'pass' | 'exchange';
  placements?: OnlineMovePlacement[];
  exchangeLetters?: string[];
  words?: string[];
  wordScores?: { word: string; score: number; x2: boolean; x3: boolean }[];
  basePoints?: number;
  lostShares?: { to: number; amount: number }[];
}

/**
 * Sırası gelen oyuncunun hamlesini gönderir (`submit_move` RPC'si). Sunucu
 * sırayı ve taş sahipliğini kendisi doğrular, puan hesabına (basePoints/
 * words/wordScores/lostShares) client'ın hesapladığı gibi güvenir — bkz.
 * CLAUDE.md "Canlı Oyun — Faz 3" bölümündeki mimari not.
 */
export async function submitMove(gameId: string, payload: SubmitMovePayload): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const { error } = await supabase.rpc('submit_move', {
    p_game_id: gameId,
    p_action: payload.action,
    p_placements: payload.placements ?? null,
    p_exchange_letters: payload.exchangeLetters ?? null,
    p_words: payload.words ?? [],
    p_word_scores: payload.wordScores ?? null,
    p_base_points: payload.basePoints ?? 0,
    p_lost_shares: payload.lostShares ?? [],
  });
  if (error) throw new Error(error.message);
}

/**
 * `online_game_states` satırındaki her değişiklikte `onChange`'i tetikler
 * (Realtime). Dönen fonksiyon aboneliği iptal eder — bileşen unmount
 * olduğunda çağrılmalı. Supabase yapılandırılmamışsa no-op.
 */
export function subscribeOnlineGameState(gameId: string, onChange: () => void): () => void {
  if (!supabase) return () => {};
  const client = supabase;
  const channel = client
    .channel(`online_game_state_${gameId}`)
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'online_game_states', filter: `online_game_id=eq.${gameId}` },
      onChange,
    )
    .subscribe();
  return () => {
    void client.removeChannel(channel);
  };
}

/**
 * Bir Canlı oyunun devam eden grup sohbetindeki tüm mesajları en eskiden en
 * yeniye döner (`online_game_messages`) — `OnlineGameScreen`'in ilk yüklemesi
 * için. Oyun İçi Mesajlaşma — Faz 1, yalnızca Canlı oyunlarda kullanılır.
 */
export async function fetchOnlineGameMessages(gameId: string): Promise<OnlineGameMessageRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('online_game_messages')
    .select('*')
    .eq('online_game_id', gameId)
    .order('created_at', { ascending: true });
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameMessages hatası:', error.message);
    return [];
  }
  return (data as OnlineGameMessageRow[]) ?? [];
}

/**
 * Bir Canlı oyunun grup sohbetine yeni bir mesaj gönderir — RPC yok, doğrudan
 * RLS ile (`online_game_messages_insert_self`: gönderen kendi user_id'siyle
 * ve oyunun katılımcısı olarak insert edebilir). Sunucu tarafında 1-200
 * karakter kısıtı zaten zorlanıyor (`online_game_messages_len` check'i);
 * burada da aynı sınır tekrarlanır ki hata kullanıcıya sunucuya gitmeden
 * anında gösterilebilsin.
 */
export async function sendOnlineGameMessage(gameId: string, message: string): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const trimmed = message.trim();
  if (trimmed.length === 0 || trimmed.length > 200) {
    throw new Error('Mesaj 1-200 karakter arasında olmalı.');
  }
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');
  const { error } = await supabase
    .from('online_game_messages')
    .insert({ online_game_id: gameId, sender_user_id: user.id, message: trimmed });
  if (error) throw new Error(error.message);
}

/**
 * `online_game_messages`'a yeni bir satır eklendiğinde `onInsert`'i tetikler
 * (Realtime) — `subscribeOnlineGameState`'in birebir aynı deseni, ayrı bir
 * tablo/kanal üzerinde. Yalnızca INSERT dinlenir (mesajlar düzenlenmiyor/
 * silinmiyor, bkz. Faz 1 kapsam dışı notu). Dönen fonksiyon aboneliği iptal
 * eder — bileşen unmount olduğunda çağrılmalı.
 */
export function subscribeOnlineGameMessages(
  gameId: string,
  onInsert: (row: OnlineGameMessageRow) => void,
): () => void {
  if (!supabase) return () => {};
  const client = supabase;
  const channel = client
    .channel(`online_game_messages_${gameId}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'online_game_messages', filter: `online_game_id=eq.${gameId}` },
      (payload) => onInsert(payload.new as OnlineGameMessageRow),
    )
    .subscribe();
  return () => {
    void client.removeChannel(channel);
  };
}

/**
 * `online_games`/`game_invites`'taki HERHANGİ bir değişiklikte `onChange`'i
 * tetikler (Realtime) — LiveGamesTab'ın liste/rozet verisini (davet
 * gönderildi/kabul edildi/reddedildi, oyun active'e geçti vb.) yeniden
 * çekmesi için. `subscribeOnlineGameState`'in aynı deseni, ama tek bir
 * oyuna değil çağıranın TARAF OLDUĞU tüm oyunlara bağlı olduğundan bir
 * `filter` verilmiyor — RLS (`online_games_select_party`/
 * `game_invites_select_party`) zaten yalnızca kendi satırlarını yayınlar,
 * postgres_changes bunu normal select gibi uyguluyor. Dönen fonksiyon
 * aboneliği iptal eder — bileşen unmount olduğunda çağrılmalı. Setup ve
 * LiveGamesTab bunu AYNI ANDA (biri diğerinin çocuğu olarak) çağırabildiğinden
 * kanal adı her seferinde benzersiz üretiliyor — sabit bir isim iki
 * abonelik aynı topic'i paylaşırdı.
 */
export function subscribeMyOnlineGames(onChange: () => void): () => void {
  if (!supabase) return () => {};
  const client = supabase;
  const channel = client
    .channel(`my_online_games_${crypto.randomUUID()}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'online_games' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'game_invites' }, onChange)
    .subscribe();
  return () => {
    void client.removeChannel(channel);
  };
}

/**
 * Sırası bir YZ koltuğunda olan bir Canlı oyunu bir tur ilerletir
 * (`play-ai-turn` Edge Function'ı, Faz 3 Adım 5). YZ'nin gerçek rafı bu
 * çağrıda hiçbir zaman tarayıcıya dönmez — hamle tamamen sunucuda
 * hesaplanır, yanıt yalnızca başarı/durum bilgisi taşır (bkz.
 * `OnlineGameScreen.tsx`'teki `refresh()`, CLAUDE.md "Canlı Oyun — Faz 3").
 */
export async function triggerAiTurn(gameId: string): Promise<{ played: boolean }> {
  if (!supabase) return { played: false };
  const { data, error } = await supabase.functions.invoke('play-ai-turn', {
    body: { game_id: gameId },
  });
  if (error) {
    console.error('[Kelimeki] triggerAiTurn hatası:', error.message);
    return { played: false };
  }
  return { played: !!(data as { played?: boolean } | null)?.played };
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
 * Misafir kombosuna, `playerCount` Toplam/2/4 kişilik kırılımına, `source`
 * Toplam/Canlı/Yapay Zeka kombosuna (31 Temmuz 2026) karşılık gelir (null =
 * tüm oyuncu sayıları).
 */
export async function fetchAdminGameActivitySeries(
  periods: number,
  granularity: AdminActivityGranularity,
  scope: AdminGameScope,
  playerCount: number | null,
  source: AdminGameSourceType,
): Promise<AdminGameActivityPoint[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_game_activity_series', {
    p_periods: periods,
    p_granularity: granularity,
    p_scope: scope,
    p_player_count: playerCount,
    p_source: source,
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

/** Bir Edge Function'ı çağırır — hata durumunda Edge Function'ın döndürdüğü
 * JSON gövdesini okuyup gerçek mesajı fırlatır (supabase-js `functions.invoke`
 * bunu otomatik yapmıyor). Yalnızca admin fonksiyonlarına (feedback-reply,
 * admin-send-message) özgü değil — notify-friend-request/notify-game-invite
 * gibi herhangi bir kullanıcının çağırabileceği fonksiyonlarda da kullanılır. */
async function invokeEdgeFunction(name: string, body: Record<string, unknown>): Promise<void> {
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
  await invokeEdgeFunction('feedback-reply', {
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
  await invokeEdgeFunction('admin-send-message', {
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

/**
 * Takma ismin (Türkçe'ye duyarlı, büyük/küçük harf duyarsız) uygunluğunu
 * kontrol eder — `check_nickname_available` RPC'si oturum açıksa çağıranın
 * kendi mevcut ismini otomatik hariç tutar. Yalnızca canlı UX geri bildirimi
 * içindir; asıl doğruluk kaynağı `profiles_display_name_tr_lower_key` unique
 * index'i — bu kontrolü atlatan bir yarış durumu olsa bile kayıt sırasında
 * gerçek kısıt devreye girer.
 */
export async function checkNicknameAvailable(nickname: string): Promise<boolean> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const { data, error } = await supabase.rpc('check_nickname_available', {
    p_nickname: nickname,
  });
  if (error) throw new Error(error.message);
  return data === true;
}

/** Postgres'in unique-violation hatasını takma isim için okunur bir mesaja çevirir. */
function friendlyNicknameError(message: string | undefined): Error | null {
  if (message && /profiles_display_name_tr_lower_key|display_name/i.test(message) && /duplicate key|unique/i.test(message)) {
    return new Error('Bu takma isim zaten kullanılıyor. Farklı bir tane dene.');
  }
  return null;
}

export async function signUp(
  email: string,
  password: string,
  firstName: string,
  lastName: string,
  nickname: string,
  termsAccepted = false,
  channel: 'direct' | 'form' = 'direct',
  gender?: Gender | null,
  birthDate?: string | null,
  marketingConsent = false,
) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  // sharedxp_pending_profile formatı trigger tarafından okunur (camelCase).
  // display_name üst seviyede gönderilir çünkü trigger onu doğrudan
  // raw_user_meta_data->>'display_name' olarak okuyor (e-posta doğrulaması
  // açıkken signUp() session döndürmez, bu yüzden aşağıdaki update'e
  // güvenilemez — nickname'in kaybolmaması için metadata'da baştan olmalı).
  // gender/birthDate/marketingConsent de aynı sebeple burada (trigger
  // tarafında, handle_new_user), oturum açılmasını bekleyen bir update'te
  // değil — marketing_consent_at'in doğru (kayıt anındaki) zaman damgasını
  // taşıması için de bu şart, aksi halde e-posta doğrulaması açıkken hiç
  // yazılmayan agreed_to_terms'ün aynı eksikliğini tekrarlardık.
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
          marketingConsent,
        },
        signup_channel: channel,
        display_name: nickname,
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
  // AuthModal kayıttan önce checkNicknameAvailable ile kontrol ediyor; bu
  // yalnızca eşzamanlı bir yarış durumunda (iki kişi aynı anda aynı ismi
  // kapmaya çalışırsa) devreye giren bir güvenlik ağı.
  const friendlyErr = result.error ? friendlyNicknameError(result.error.message) : null;
  if (friendlyErr) return { ...result, error: friendlyErr } as typeof result;
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
    /**
     * `marketing_consent_at` burada YOK — kasıtlı: `trg_set_marketing_consent_at`
     * (marketing_consent_toggle_trigger migration'ı) bu alanı `marketing_consent`
     * geçişine göre sunucu tarafında (`now()`) otomatik yazıyor, client'ın
     * göndereceği herhangi bir değeri zaten yok sayardı.
     */
    marketing_consent?: boolean;
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
  if (error) throw friendlyNicknameError(error.message) ?? new Error(error.message);

  // Profil satırı henüz oluşturulmamışsa kayıt aç. display_name NOT NULL
  // olduğundan (nickname artık zorunlu) patch'te yoksa e-posta önekine düşer.
  if (!data || data.length === 0) {
    const firstName = patch.first_name ?? '';
    const lastName = patch.last_name ?? '';
    const fallbackNickname = user.email ? user.email.split('@')[0] : user.id;
    const { error: createErr } = await supabase.from('profiles').insert({
      id: user.id,
      username: fallbackNickname,
      first_name: firstName,
      last_name: lastName,
      display_name: patch.display_name ?? fallbackNickname,
      avatar_url: patch.avatar_url ?? null,
    });
    if (createErr) throw friendlyNicknameError(createErr.message) ?? new Error(createErr.message);
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

// ── Yerel (YZ) oyun — sunucu kaydı (girişli kullanıcılar, cihazlar arası) ───
//
// Misafirler hâlâ yalnızca localStorage (gameStorage.ts) kullanır — bu
// bölüm yalnızca girişli kullanıcıların devam eden YZ oyunlarını `local_game_saves`
// tablosunda tutar, böylece hangi cihazdan girerlerse girsin aynı oyuna devam
// edebilir ve aynı anda birden fazla oyun açık tutabilirler (bkz. CLAUDE.md).

/** Çağıranın tüm devam eden yerel (YZ) oyun kayıtları, en son güncellenen önce. */
export async function listLocalGameSaves(): Promise<LocalGameSave[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('local_game_saves')
    .select('*')
    .order('updated_at', { ascending: false });
  if (error) {
    console.error('[Kelimeki] listLocalGameSaves hatası:', error.message);
    return [];
  }
  return (data as LocalGameSave[]) ?? [];
}

/**
 * Bir yerel oyunu sunucuya kaydeder (id yeni ise ekler, varsa günceller —
 * `upsert`). `id` her oyun için App.tsx'te bir kez üretilip aynı oyun
 * bitene/terk edilene kadar sabit kalır, böylece art arda gelen her hamle
 * aynı satırı günceller.
 */
export async function upsertLocalGameSave(id: string, userId: string, state: GameState): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('local_game_saves').upsert({
    id,
    user_id: userId,
    state,
    player_count: state.players.length,
  });
  if (error) console.error('[Kelimeki] upsertLocalGameSave hatası:', error.message);
}

/** Bir yerel oyun kaydını siler — oyun normal biçimde bitince ya da 7 günlük terk edilme süpürmesi tarafından çağrılır. */
export async function deleteLocalGameSave(id: string): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('local_game_saves').delete().eq('id', id);
  if (error) console.error('[Kelimeki] deleteLocalGameSave hatası:', error.message);
}

/**
 * Bir yerel oyun kaydı `updatedBeforeIso`'dan daha eski (7 gün hareketsiz)
 * kalmışsa onu ATOMİK olarak siler ve silinen kaydın state'ini döner — hâlâ
 * güncel çıkarsa (ör. başka bir cihaz o arada oynadıysa) ya da başka bir
 * cihaz aynı anda zaten "iddia edip" silmişse `null` döner. Bu, `.delete()
 * .lt('updated_at', ...)` tek bir atomik sorgu olduğundan (satır kilidi)
 * ayrı bir RPC/kilitleme mekanizması gerekmez — `check_turn_timeout` ile
 * aynı "hafif" felsefe (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6").
 */
export async function claimAbandonedLocalGameSave(
  id: string,
  updatedBeforeIso: string,
): Promise<GameState | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('local_game_saves')
    .delete()
    .eq('id', id)
    .lt('updated_at', updatedBeforeIso)
    .select('state')
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] claimAbandonedLocalGameSave hatası:', error.message);
    return null;
  }
  return (data?.state as GameState) ?? null;
}

export { isSupabaseConfigured };
