// Kelimeki — Supabase şema tipleri (elle yazıldı; MCP erişimi açılınca
// `generate_typescript_types` ile otomatik üretilebilir).

import type { BonusType, Tile } from '../game/types';

export type GameResult = 'win' | 'lose' | 'tie';

export type Gender = 'female' | 'male' | 'unspecified';

export interface Profile {
  id: string;
  username: string;
  first_name: string;
  last_name: string;
  display_name: string | null;
  avatar_url: string | null;
  agreed_to_terms: boolean;
  is_admin: boolean;
  created_at: string;
  updated_at: string;
  gender: Gender | null;
  /** ISO tarih (yyyy-mm-dd) — `<input type="date">`'in doğal formatı. */
  birth_date: string | null;
  /** Bir arkadaş davet linkiyle katıldıysa, linki oluşturan kullanıcı (ilk temas, değişmez). */
  invited_by: string | null;
  /** Pazarlama iletişimi almayı kabul etti mi — kayıt formundaki opsiyonel ikinci onay kutusu. */
  marketing_consent: boolean;
  /** `marketing_consent` true olduğu andaki (kayıt anındaki) sunucu zaman damgası — false ise null. */
  marketing_consent_at: string | null;
}

// ── Arkadaşlık sistemi ──────────────────────────────────────────────────────

/** `list_friends` RPC çıktısındaki tek satır (kabul edilmiş arkadaşlık). */
export interface FriendRow {
  friend_id: string;
  name: string;
  avatar_url: string | null;
  since: string | null;
}

/** `list_incoming_friend_requests` RPC çıktısındaki tek satır (bana gelen, bekleyen istek). */
export interface IncomingFriendRequest {
  requester_id: string;
  name: string;
  avatar_url: string | null;
  created_at: string;
}

/** İki kullanıcı arasındaki mevcut arkadaşlık ilişkisi — bkz. `fetchFriendRelation`. */
export type FriendRelation = 'accepted' | 'pending_outgoing' | 'pending_incoming';

/**
 * `search_users_for_friend` RPC çıktısındaki tek satır. `relation`, aranan
 * kişiyle aramızdaki mevcut ilişkiyi gösterir — UI bu duruma göre "Ekle" /
 * "İstek Gönderildi" / "Kabul Et" / "Arkadaşsınız" gösterir.
 */
export interface FriendSearchResult {
  id: string;
  name: string;
  avatar_url: string | null;
  relation: FriendRelation | null;
}

// ── Canlı oyun (Faz 2 — davet/kabul) ────────────────────────────────────────

/**
 * `online_games.slots` dizisindeki tek koltuk — index 0 her zaman kurucu.
 * `name`/`avatar_url`/`relation`/`invite_status`, yalnızca
 * `list_my_online_games` RPC'sinin döndürdüğü (sunucu tarafında
 * zenginleştirilmiş) satırlarda dolu olur — `createOnlineGame`'e giden
 * istemci tarafı `slots`'ta bu alanlar hiç yok.
 * `relation`, `search_users_for_friend`'daki aynı sözlüğü kullanır, artı
 * çağıranın kendi koltuğu için `'self'`.
 * `invite_status`, o koltuktaki kişinin kendi `game_invites` durumu —
 * kurucunun koltuğunda hiç davet satırı olmadığından her zaman `null`dur
 * (o koltuk `user_id === game.created_by` ile ayırt edilir).
 */
export type OnlineGameSlot =
  | {
      type: 'human';
      user_id: string;
      name?: string;
      avatar_url?: string | null;
      relation?: FriendRelation | 'self' | null;
      invite_status?: 'pending' | 'accepted' | 'declined' | null;
    }
  | { type: 'ai' };

export type OnlineGameStatus = 'pending' | 'active' | 'finished' | 'abandoned';

/** `list_my_online_games` RPC çıktısındaki tek satır. */
export interface OnlineGame {
  id: string;
  created_by: string;
  player_count: 2 | 4;
  status: OnlineGameStatus;
  slots: OnlineGameSlot[];
  created_at: string;
  /** Çağıran kurucu mu yoksa davetli mi. */
  my_role: 'creator' | 'invitee';
  /** Çağıran davetliyse kendi davet durumu; kurucuysa null. */
  my_invite_status: 'pending' | 'accepted' | 'declined' | null;
  /** Çağıran davetliyse `game_invites.id` (respond_to_game_invite'a geçilir); kurucuysa null. */
  my_invite_id: string | null;
}

// ── Canlı oyun (Faz 3 — gerçek zamanlı senkron oynanış) ─────────────────────

/**
 * `online_game_states.players` dizisindeki tek oyuncu — src/game/types.ts'teki
 * `Player` ile aynı alanlar, ama `rack: Tile[]` yerine `rackCount: number`.
 * Rakibin elindeki harfler bu satırdan ASLA okunamaz (bkz. online_game_secrets,
 * ayrı ve tamamen kilitli bir tablo).
 */
export interface OnlinePlayerPublic {
  name: string;
  corners: number[];
  colorIndex: number;
  isAI: boolean;
  surrendered: boolean;
  rackCount: number;
  score: number;
  bestMoveScore: number;
  longestWord: string;
  moveCount: number;
  moveScoreSum: number;
}

/** `online_game_states` tablosundaki satır — bir Canlı oyunun herkese (katılımcılara) açık anlık state'i. */
export interface OnlineGameStatePublic {
  online_game_id: string;
  board: (Tile | null)[][];
  bonuses: Record<string, BonusType>;
  players: OnlinePlayerPublic[];
  current: number;
  turn_count: number;
  consecutive_passes: number;
  is_game_over: boolean;
  end_reason: 'normal' | 'surrender' | null;
  last_move_cells: [number, number][];
  bag_count: number;
  started_at: string;
  updated_at: string;
}

/** `online_game_moves` tablosundaki tek satır (audit log / hamle geçmişi). */
export interface OnlineMoveRow {
  id: string;
  online_game_id: string;
  turn: number;
  player_index: number;
  player_user_id: string | null;
  action: 'play' | 'pass' | 'exchange' | 'surrender';
  words: string[];
  word_scores: { word: string; score: number; x2: boolean; x3: boolean }[] | null;
  points: number;
  lost_shares: { to: number; amount: number }[] | null;
  tile_count: number;
  placements: { r: number; c: number; letter: string; wild?: boolean; wildLetter?: string }[] | null;
  finish_joker_count: number;
  bingo: boolean;
  created_at: string;
}

/** Bir oyuncu için, submit_move'a gönderilecek tek taş yerleştirmesi. */
export interface OnlineMovePlacement {
  r: number;
  c: number;
  letter: string;
  wild?: boolean;
  wildLetter?: string;
}

/** Bir oyunun bitişindeki tek bir oyuncu satırı (final sıralamasında). */
export interface GamePlayerSnapshot {
  name: string;
  score: number;
  is_ai: boolean;
  /** Bu oyuncu oyunu bitirmeden teslim oldu mu (dolduysa; eski kayıtlarda yok). */
  surrendered?: boolean;
  /**
   * Oyuncunun sabit koltuk/renk kimliği (PLAYER_COLORS indeksi) — final
   * sıralamasındaki konumuyla (rank) KARIŞTIRILMAMALI. Bu alan eklenmeden
   * önceki kayıtlarda yok; GameHistoryModal isimden ("Yapay Zeka N") tahmin
   * eder.
   */
  colorIndex?: number;
}

/**
 * `games.board_snapshot`'taki tek bir dolu hücre — bkz. `src/utils/boardSnapshot.ts`
 * (üretim: `serializeBoardSnapshot`, geri yükleme: `buildSnapshotGameState`).
 * Boş hücreler hiç tutulmaz; bonus bölgesi/köşe düzeni sabitlerden
 * (`game/constants.ts`) türetildiğinden ayrıca saklanmaz.
 */
export interface BoardSnapshotTile {
  r: number;
  c: number;
  /** Görünen harf (joker ise oynanırken seçilen harf). */
  l: string;
  /** Sahibinin koltuk/renk indeksi (`GamePlayerSnapshot.colorIndex`). */
  o: number;
  /** Joker olarak mı oynandı? Değilse alan hiç yok (false yazılmaz). */
  w?: boolean;
}

export interface Game {
  id: string;
  user_id: string | null;
  player_score: number;
  ai_score: number;
  result: GameResult;
  /** Oyuncunun oyunu bitirdiği sıra (1 = birinci). Eski kayıtlarda bilinmiyorsa null. */
  rank: number | null;
  turn_count: number;
  player_count: number;
  move_count: number | null;
  best_move_score: number | null;
  longest_word: string | null;
  /** Bu oyunda oynanan hamlelerin brüt puanları toplamı (ortalama hamle puanı için). */
  move_points_sum: number | null;
  /** Oyuncu oyunu bitirmeden (logoya basıp) terk etti mi? */
  surrendered: boolean;
  /** Final sıralamasına göre tüm oyuncular ve puanları. Eski kayıtlarda null. */
  players: GamePlayerSnapshot[] | null;
  /**
   * Oyunun bittiği andaki tahtanın kompakt anlık görüntüsü — `GameHistoryModal`'da
   * bir oyuna tıklanınca (`fetchGameBoardSnapshot`) lazy olarak çekilip
   * `GameBoardPreview` ile render edilir. Bu sütun eklenmeden önceki kayıtlarda
   * (ve terk edilip hiç bitmemiş oyunlarda zaten hiç kayıt olmadığından bu
   * durum oluşmaz) null.
   */
  board_snapshot: BoardSnapshotTile[] | null;
  /** Herkese açık `/game/:id` linkiyle görülebilir mi (`set_game_shared` RPC'si ile bir kere true olur, geri alınamaz). */
  shared: boolean;
  /**
   * Doluysa bu kayıt bir Canlı (çok hesaplı, `online_games`) oyundan geldi —
   * `submit_move` RPC'si oyun bitince her insan katılımcı için sunucu
   * tarafında yazar, client hiç insert etmez (bkz. NewGame'in bunu
   * içermemesi). `GameHistoryModal` bu kartları görsel olarak ayırt etmek
   * için kullanır.
   */
  online_game_id: string | null;
  created_at: string;
}

/**
 * `get_shared_game` RPC'sinin döndürdüğü, herkese açık (girişsiz dahil)
 * `/game/:id` sayfasının ihtiyaç duyduğu minimum alan seti — skor/kelime
 * gibi başka hiçbir kişisel veri yok. `shared=true` olmayan ya da var
 * olmayan bir id için RPC boş döner (bkz. `fetchSharedGame`, `SharedGamePage`).
 */
export interface SharedGameData {
  board_snapshot: BoardSnapshotTile[] | null;
  players: GamePlayerSnapshot[] | null;
  player_count: number;
  created_at: string;
}

/** games tablosuna eklenecek yeni kayıt. */
export type NewGame = Pick<
  Game,
  'player_score' | 'ai_score' | 'result' | 'rank' | 'turn_count' | 'player_count'
> & {
  /**
   * İstemci tarafında üretilen uuid. Offline kuyruklamada, bağlantı geri
   * gelince aynı kaydın tekrar denenmesi durumunda sunucu tarafında
   * yinelenmeyi (duplicate insert) engellemek için kullanılır — bkz.
   * `saveGame` (lib/api.ts) ve `gameSync.ts`.
   */
  id?: string;
  /**
   * Oyunun gerçekten bittiği an (istemci saati, ISO 8601). Offline/misafir
   * kuyruklamada kayıt sunucuya çok sonra ulaşabildiğinden, sunucunun
   * `insert` anındaki `now()` varsayılanı yerine bu değer kullanılır — böylece
   * oyun geçmişi gerçek oynanma sırasına göre görünür.
   */
  created_at?: string;
  user_id?: string | null;
  move_count?: number | null;
  best_move_score?: number | null;
  longest_word?: string | null;
  move_points_sum?: number | null;
  surrendered?: boolean;
  players?: GamePlayerSnapshot[];
  board_snapshot?: BoardSnapshotTile[];
};

/** Oyun geçmişi listesinde gösterilecek alanlar. */
export type GameHistoryEntry = Pick<
  Game,
  | 'id'
  | 'created_at'
  | 'player_count'
  | 'players'
  | 'player_score'
  | 'ai_score'
  | 'rank'
  | 'surrendered'
  | 'online_game_id'
> & {
  /**
   * Bu isteği yapan (oturum açan) kullanıcının bu oyunu beğenip beğenmediği —
   * `game_likes` tablosu üzerinden, hedef kullanıcıdan (kartı görüntülenen
   * kişi) bağımsız hesaplanır. Bkz. `fetchMyGames`.
   */
  liked_by_me: boolean;
  /** Bu oyunu toplam kaç kullanıcının beğendiği (`game_like_stats` RPC'si). */
  like_count: number;
};

/**
 * Bir oyunu beğenen kullanıcılardan biri (`game_likers` RPC çıktısı, en yeni
 * beğeni önce). `GameHistoryModal`'da beğeni sayısına dokununca gösterilen
 * listede kullanılır — satıra tıklanınca `PlayerScoreCard` açılabilsin diye
 * `PlayerSummary`'ye çevrilir (bkz. `gameLikerToPlayerSummary`).
 */
export interface GameLiker {
  user_id: string;
  display_name: string | null;
  first_name: string | null;
  avatar_url: string | null;
}

/** Bir kelimenin sözlük kaydı (word_meaning RPC çıktısı). */
export interface WordMeaning {
  word: string;
  pos: string | null;
  meanings: string[];
}

export interface LeaderboardRow {
  user_id: string;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  display_name: string | null;
  avatar_url: string | null;
  best_score: number;
  total_score: number;
  games_played: number;
  wins: number;
}

export interface MyLeaderboardRank {
  rank: number;
  total_score: number;
}

export interface PlayerStats {
  user_id: string;
  player_count: number;
  games_played: number;
  wins: number;
  losses: number;
  ties: number;
  best_score: number;
  avg_score: number;
  avg_move_score: number | null;
  best_move_score: number | null;
  longest_word: string | null;
  first_places: number;
  second_places: number;
  /**
   * Lig puanı (oyun içi ham skorların toplamı değil): 4 kişilikte 1.=2,
   * 2.=1, 3./4.=0; 2 kişilikte sadece 1.=2, 2.=0 (tek rakipli oyunda ikinci
   * olmak kaybetmekle aynı şey olduğundan puan getirmez). Beraber
   * bitirenler grubun en iyi sırasının puanını paylaşır (2 kişilik tam
   * beraberlikte ikisi de rank=1 olur, ikisi de 2 alır). Teslim olunan
   * oyunlar sıradan bağımsız olarak sabit -2 puan getirir.
   */
  total_score: number;
  /** Oyuncunun bitirmeden terk ettiği (teslim olduğu) oyun sayısı. */
  surrendered_count: number;
}

// ── Admin paneli ────────────────────────────────────────────────────────────

/** admin_list_members RPC çıktısındaki tek satır (auth.users + profiles). */
export interface AdminMember {
  id: string;
  email: string | null;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  display_name: string | null;
  is_admin: boolean;
  signup_channel: 'direct' | 'form';
  created_at: string;
  last_sign_in_at: string | null;
  banned_until: string | null;
}

export type AdminActivityGranularity = 'day' | 'week' | 'month' | 'year';

/**
 * admin_user_activity_series RPC çıktısındaki tek kova (Büyüme > Kullanıcı
 * grafiği). `signups`, o kovada oluşturulan yeni hesap sayısı (`auth.users`).
 * `guest_visits`, misafir (girişsiz) tarayıcıların o kovadaki DISTINCT anonim
 * kimlik sayısı (`guest_visits` tablosu, bkz. `src/utils/visitTracking.ts`)
 * — kayıt olmadan gelip bakan/oynayan benzersiz ziyaretçi sayısına kaba bir
 * yaklaşık (aynı kişi farklı cihaz/gizli sekme kullanırsa ayrı sayılır).
 */
export interface AdminUserActivityPoint {
  bucket: string;
  signups: number;
  guest_visits: number;
}

/**
 * admin_guest_source_breakdown RPC çıktısındaki tek satır (Büyüme >
 * Kullanıcı) — son N gün içinde bir `?ref=` kaynağından (bkz.
 * `src/utils/visitTracking.ts`) kaç benzersiz misafir ziyaretçi geldiğini
 * gösterir. `?ref=` ile hiç gelinmemiş ziyaretler `source: 'direkt'` olarak
 * gruplanır.
 */
export interface AdminGuestSourceRow {
  source: string;
  visitors: number;
}

/**
 * admin_guest_device_breakdown RPC çıktısındaki tek satır (Büyüme >
 * Kullanıcı) — son N gün içinde bir cihaz tipinden (`getDeviceType`, bkz.
 * `src/utils/visitTracking.ts`) kaç benzersiz misafir ziyaretçi geldiğini
 * gösterir.
 */
export interface AdminGuestDeviceRow {
  device_type: string;
  visitors: number;
}

/**
 * admin_guest_standalone_breakdown RPC çıktısındaki tek satır (Büyüme >
 * Kullanıcı) — son N gün içinde ana ekrana eklenip bağımsız (standalone)
 * modda mı, yoksa normal tarayıcıda mı gelindiğine göre kaç benzersiz
 * misafir ziyaretçi olduğunu gösterir (bkz. `isStandaloneDisplay`,
 * `src/utils/visitTracking.ts`).
 */
export interface AdminGuestStandaloneRow {
  is_standalone: boolean;
  visitors: number;
}

/** admin_game_activity_series'in p_scope parametresi: Toplam/Kayıtlı/Misafir kombosu. */
export type AdminGameScope = 'total' | 'registered' | 'guest';

/**
 * admin_game_activity_series RPC çıktısındaki tek kova (Büyüme > Oyun grafiği).
 * `games_finished` yalnızca gerçekten sonuna kadar oynanıp (bag+raf
 * boşalarak ya da pas turuyla) biten, teslimle bitmemiş oyunları sayar
 * (`games_finished_same_session`/`games_finished_multi_session` bu toplamın
 * kırılımı). `games_surrendered`, aynı `completed=true` kümesinden ama
 * bir/birden fazla oyuncunun teslim olmasıyla aktif oyuncu sayısı 1'e
 * düşüp aniden biten oyunları ayrı sayar (`GameState.endReason ===
 * 'surrender'`) — bunlar genelde saniyeler içinde geldiğinden "Bitirilen"e
 * karışmaz. `games_abandoned` 7 gün hareketsizlik sonrası terk edilmiş
 * sayılıp silinen oyunları (bkz. `gameStorage.ts` `ABANDON_TIMEOUT_MS`) ayrı
 * bir seride tutar. avg_duration_* alanları da yalnızca teslimsiz tamamlanan
 * oyunlar üzerinden hesaplanır ve o kovada hiç biten oyun yoksa null döner
 * (0 değil). same_session: hiç kapatılıp devam ettirilmemiş oyunlar;
 * multi_session: en az bir kez kapatılıp localStorage'dan devam ettirilmiş
 * oyunlar (bkz. `GameState.multiSession`). Bucket'lar İstanbul yerel gününe
 * göre kesilir (`admin_game_istanbul_tz_and_surrender_split` migration'ı).
 * "Başlatılan" (eski `game_starts`) hiçbir yerde ihtiyaç görülmediği için
 * 20 Temmuz 2026'da tamamen kaldırıldı (tablo dahil).
 */
export interface AdminGameActivityPoint {
  bucket: string;
  games_finished: number;
  games_finished_same_session: number;
  games_finished_multi_session: number;
  games_surrendered: number;
  games_abandoned: number;
  avg_duration_seconds: number | null;
  avg_duration_same_session_seconds: number | null;
  avg_duration_multi_session_seconds: number | null;
}

/**
 * admin_engagement_activity_series RPC çıktısındaki tek kova (Büyüme > Oyun
 * grafiği). `likes`, o kovada atılan beğeni sayısı (`game_likes.created_at`).
 * `shares`, o kovada İLK KEZ paylaşılan oyun sayısı (`games.shared_at`) —
 * `shared_at` bu RPC'nin eklendiği migration'dan (25 Temmuz 2026) önce
 * paylaşılmış oyunlarda null olduğundan, o eski paylaşımlar hiçbir kovaya
 * girmez (ama `admin_engagement_totals`'taki toplam paylaşılan oyun sayısına
 * dahildir). Bucket'lar diğer admin_*_activity_series fonksiyonlarıyla aynı
 * şekilde İstanbul yerel gününe göre kesilir.
 */
export interface AdminEngagementActivityPoint {
  bucket: string;
  likes: number;
  shares: number;
}

/**
 * admin_engagement_totals RPC çıktısı (Büyüme > Oyun) — tüm zamanların
 * toplam beğeni sayısı ve toplam paylaşılan oyun sayısı (`shared_at`'ten
 * bağımsız, migration öncesi paylaşımlar dahil).
 */
export interface AdminEngagementTotals {
  total_likes: number;
  total_shared_games: number;
}

/**
 * admin_friend_activity_series RPC çıktısındaki tek kova (Büyüme > Kullanıcı).
 * `requests_sent`, o kovada gönderilen arkadaşlık isteği sayısı
 * (`friend_requests.created_at`) — karşılıklı istek durumunda otomatik kabul
 * olan satırlar da burada bir "istek" olarak sayılır. `friendships_formed`,
 * o kovada `accepted` durumuna geçen (`responded_at`) satır sayısı — yani o
 * dönemde kurulan yeni arkadaşlık sayısı. Bucket'lar diğer
 * admin_*_activity_series fonksiyonlarıyla aynı şekilde İstanbul yerel
 * gününe göre kesilir.
 */
export interface AdminFriendActivityPoint {
  bucket: string;
  requests_sent: number;
  friendships_formed: number;
}

/**
 * admin_friend_totals RPC çıktısı (Büyüme > Kullanıcı) — tüm zamanların
 * arkadaşlık/istek/davet linki sayıları. `total_invite_signups`,
 * `profiles.invited_by` dolu olan (bir arkadaş davet linkiyle katılmış)
 * kullanıcı sayısı — "arkadaş daveti ile gelen kayıt" metriği.
 */
export interface AdminFriendTotals {
  total_friendships: number;
  total_pending_requests: number;
  total_invite_links: number;
  total_invite_signups: number;
}

/** "Görüş Bildir" formunun hangi bağlamdan gönderildiği. */
export type FeedbackSource = 'game_end' | 'general';

/** "user": kullanıcının gönderdiği geri bildirim; "admin": admin panelinden (Mesaj Gönder) başlatılan mesaj. */
export type FeedbackOrigin = 'user' | 'admin';

/** feedback tablosundaki tek satır (admin panelinden okunur). */
export interface AdminFeedbackRow {
  id: string;
  user_id: string | null;
  email: string | null;
  message: string;
  handled: boolean;
  created_at: string;
  source: FeedbackSource;
  reply: string | null;
  replied_at: string | null;
  replied_by: string | null;
  origin: FeedbackOrigin;
  subject: string | null;
  related_to: string | null;
}
