// Kelimeki — Supabase şema tipleri (elle yazıldı; MCP erişimi açılınca
// `generate_typescript_types` ile otomatik üretilebilir).

import type { BonusType, GameState, HistoryEntry, Tile } from '../game/types';

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
  /**
   * Arkadaşlık isteği/hatırlatması, Canlı oyun daveti, süre uyarısı ve süre
   * aşımı/terk-edilme ceza bildirimi gibi işlemsel-ama-tercih-edilebilir
   * e-postaları alma tercihi (varsayılan açık) — `marketing_consent`'ten
   * TAMAMEN ayrı: hesap güvenliği/admin yazışması gibi zorunlu maillere
   * hiç etkisi yok, onlar bu bayrağa bakmadan her zaman gönderilir.
   */
  email_notifications_enabled: boolean;
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

// ── Yerel (YZ) oyun — sunucu kaydı (girişli kullanıcılar, cihazlar arası) ───

/**
 * `local_game_saves` tablosundaki satır — girişli bir kullanıcının devam eden
 * bir yerel (YZ) oyununun tam kaydı. Misafirler bu tabloya hiç yazmaz
 * (bkz. src/utils/gameStorage.ts, localStorage tabanlı tekil-slot kaydı).
 */
export interface LocalGameSave {
  id: string;
  user_id: string;
  state: GameState;
  player_count: number;
  created_at: string;
  updated_at: string;
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
  bestWordScore: number;
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

/**
 * `online_game_messages` tablosundaki tek satır — bir Canlı oyunun devam eden
 * (henüz bitmemiş) grup sohbetindeki tek mesaj. Yalnızca katılımcılar select
 * edebilir (`is_online_game_participant`); yazma da RPC'siz doğrudan RLS ile
 * (`sender_user_id = auth.uid()` + katılımcılık). Oyun İçi Mesajlaşma — Faz 1,
 * yalnızca Canlı (online) oyunlarda kullanılır.
 */
export interface OnlineGameMessageRow {
  id: string;
  online_game_id: string;
  sender_user_id: string;
  message: string;
  created_at: string;
}

/**
 * Oyun İçi Mesajlaşma — Faz 2: `admin_list_chat_reports` RPC'sinin çıktısı
 * (Admin panosu > Geri Bildirim > Şikayetler). `withdrawn_at` doluysa
 * raporu gönderen kişi geri çekmiş demektir (handled de otomatik true
 * olur) — admin arayüzü bunu "Geri Çekildi" olarak ayrı gösterir.
 * `game_finished` true değilse sohbet dökümü henüz görüntülenemez (v1
 * kapsamı — yalnızca bitmiş oyunlar).
 */
export interface AdminChatReportRow {
  id: string;
  online_game_id: string;
  reporter_user_id: string;
  reporter_name: string;
  reported_user_id: string;
  reported_name: string;
  reason: string;
  created_at: string;
  handled: boolean;
  withdrawn_at: string | null;
  game_finished: boolean;
}

/**
 * `admin_get_member_activity_log` RPC'sinin çıktısı — Admin panosu >
 * Üyeler > bir üyenin skor kartının en altındaki "Kayıtlar" bölümü.
 * Oynadığı oyunlar HARİÇ, hesabıyla ilgili kritik olayların (üye oluş,
 * hesap dondurma/kaldırma, admin ile mesaj geçmişi, rapor edilme/geri
 * çekilme) kronolojik (en yeni önce) dökümü. `detail` bazı satırlarda
 * (ör. "Üye Oldu") null olabilir.
 */
export interface AdminMemberActivityLogRow {
  kind: 'signup' | 'ban' | 'unban' | 'feedback_user' | 'feedback_admin' | 'feedback_replied' | 'report_received' | 'report_withdrawn';
  created_at: string;
  title: string;
  detail: string | null;
}

/**
 * `games.messages` jsonb'sindeki tek, dondurulmuş sohbet satırı —
 * `_finish_online_game_records` bir Canlı oyun bitince `online_game_messages`
 * tablosundaki tüm mesajları bu şekle indirgeyip her insan katılımcının
 * kendi `games` satırına aynen kopyalar (board_snapshot ile aynı desen).
 * `sender_user_id` bilerek YOK — board_snapshot'taki oyuncu isimleri gibi bu
 * da o andaki ismi dondurur, kimliğe geri bağlanmaz.
 */
export interface GameChatMessage {
  name: string;
  colorIndex: number;
  message: string;
  created_at: string;
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
  /**
   * Bu oyunda oynanan en yüksek puanlı TEK kelimenin (X2/X3 çarpanı dahil)
   * nihai puanı. `best_move_score`'dan farklı — o bir HAMLEnin (birden
   * fazla kelime + bonus içerebilir) toplam puanıdır.
   */
  best_word_score: number | null;
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
  /**
   * Bu oyunun (yalnızca Canlı oyunlarda dolu olur) dondurulmuş grup sohbeti —
   * `_finish_online_game_records` tarafından bitişte `online_game_messages`
   * tablosundan bir kerelik kopyalanır. Yerel/YZ oyunlarında her zaman null
   * (Oyun İçi Mesajlaşma — Faz 1 kapsam dışı). `GameHistoryModal`'ın liste
   * sorgusuna DAHİL EDİLMEZ (bkz. `message_count`), yalnızca sohbet rozetine
   * tıklanınca `fetchGameMessages` ile lazy çekilir.
   */
  messages: GameChatMessage[] | null;
  /**
   * `messages` dizisinin uzunluğu (generated sütun) — liste sorgusunu
   * şişirmeden sohbet rozetinin gösterilip gösterilmeyeceğine karar vermek
   * için. **10 Ağustos 2026'dan beri bu kolon istemci rollerinden KALDIRILDI**
   * (`chat_count_participants_only`): "X ile Y şu oyunda N mesajlaştı" da bir
   * üstveri ve rozet zaten yalnızca katılımcının açabildiği bir kontroldü.
   * Değer artık `game_like_stats` toplu RPC'sinden geliyor ve katılımcı/admin
   * değilsen 0 dönüyor (rozet hiç çizilmez).
   */
  message_count: number;
  /**
   * Bu oyunun DONDURULMUŞ tam hamle dökümü (`GameState.moveHistory` ile aynı
   * şekil) — "Tüm Oyunlarım"daki hamle geçmişi ikonu bunu gösterir.
   * Yerelde `buildGameRecord`, Canlı'da `_finish_online_game_records`
   * (`_online_moves_snapshot` yardımcısıyla) yazar. Dondurmanın iki sebebi:
   * yerelde `moveHistory` yalnızca `GameState`te yaşıyor ve oyun bitince
   * kayboluyor; Canlı'da `online_game_moves`un RLS'i yalnızca katılımcıya
   * açık, başkasının oyununu açan hamleleri göremezdi.
   * Bu kolon eklenmeden ÖNCE biten yerel oyunlarda `null` — kurtarılamaz
   * (kart "kaydedilmemiş" der); Canlı oyunlar migration'da geriye dönük
   * dolduruldu. `board_snapshot`/`messages` ile aynı gerekçeyle liste
   * sorgusuna DAHİL EDİLMEZ, yalnızca ikona basılınca `fetchGameMoves` ile
   * lazy çekilir.
   */
  moves: HistoryEntry[] | null;
  /**
   * `moves is not null` — hamle geçmişi ikonunun ÇİZİLİP çizilmeyeceği
   * (12 Ağustos 2026). `moves`un kendisi liste sorgusuna girmediğinden bu
   * karar `game_like_stats` toplu RPC'sinden geliyor (ek gidiş-dönüş yok).
   * **"YZ oyunlarında gösterme" gibi bir tür kontrolü DEĞİL:** kolon
   * eklenmeden önce biten yerel oyunlarda kurtarılacak veri olmadığı için
   * bugün YZ kartlarının hepsi `false`, ama bundan sonra bitenler `true`
   * olacak — kural her zaman "dökümü var mı", "hangi tür oyun" değil.
   */
  has_moves: boolean;
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

/**
 * Kaydı yazan istemci. `'app-web'`, Flutter portunun web TEST derlemesi —
 * ürün değil, geliştiricinin cihazsız test ortamı; gerçek web trafiğiyle
 * karışmasın diye bilerek ayrı bir değer (bkz. `mobile/CLAUDE.md`, "Web
 * Derlemesi — ÜRÜN DEĞİL, TEST ORTAMI").
 */
export type ClientPlatform = 'web' | 'ios' | 'android' | 'app-web';

/**
 * İstemci hata telemetrisinin GRUPLANMIŞ dökümü (`admin_client_errors`,
 * ROADMAP #3). Ham satır DÖNMEZ — panelin cevaplaması gereken soru "kaç
 * satır" değil "aynı hata kaç CİHAZDA, hangi DERLEMEDE".
 *
 * `message` imzadır (ilk 160 karakter): aynı hatanın farklı satır/sütun
 * numaralarıyla gelen kopyaları tek satırda toplar.
 *
 * `routes` normalleştirilmiş yollardır (`/davet/:token`) — ham token asla
 * saklanmaz; istemci normalleştiriyor, sunucuda ayrıca bir maskeleme
 * trigger'ı var.
 */
export interface AdminClientErrorRow {
  kind: string;
  message: string;
  occurrences: number;
  /** Benzersiz cihaz (`anon_id`) — `occurrences` ile KARIŞTIRILMAMALI. */
  devices: number;
  platforms: string;
  builds: string;
  /**
   * Bu gruptaki İSTEMCİ SÜRÜMLERİ (mobil `pubspec` sürümü), virgülle.
   *
   * `null` olabilir ve bu bir eksiklik DEĞİL: web sürüm göndermez (orada
   * derleme `build` sha'sıyla zaten tekil), yani yalnız web'den gelen bir
   * grupta alan boş kalır. Mağazada aynı anda birden çok sürüm yaşayacağı
   * için app tarafında bu, "hangi sürümde düzeldi?" sorusunun tek cevabı.
   */
  versions: string | null;
  routes: string;
  first_seen: string;
  last_seen: string;
  sample_stack: string | null;
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
  best_word_score?: number | null;
  longest_word?: string | null;
  move_points_sum?: number | null;
  surrendered?: boolean;
  players?: GamePlayerSnapshot[];
  board_snapshot?: BoardSnapshotTile[];
  moves?: HistoryEntry[];
  /**
   * Bu kaydı YAZAN istemci (14 Ağustos 2026) — mobil lansmanı ölçülebilsin diye.
   * Web her zaman `'web'`, Flutter portu `'ios'`/`'android'`/`'app-web'` yazar
   * (sonuncusu portun web TEST derlemesi — gerçek web trafiğini kirletmesin diye
   * ayrı bir değer). YALNIZCA yerel (YZ) oyunlarda dolu: Canlı oyunların `games`
   * satırını sunucu yazdığından orada null kalır ve platform ayrı bir tablodan
   * (`online_game_clients`, `setOnlineGamePlatform` ile yazılır) çözülür.
   * İstemcinin bu kolon üzerinde SELECT yetkisi YOK — yalnızca yazabilir.
   */
  platform?: ClientPlatform;
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
  | 'message_count'
  | 'has_moves'
  | 'user_id'
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
  /**
   * k-lig sırası — sunucuda (`k_lig_siralama` view'ı) hesaplanır: puan desc,
   * eşitse OHP desc, o da eşitse user_id. **Dizideki indeksten (`i + 1`)
   * TÜRETİLMEZ** — `my_leaderboard_rank` de aynı view'dan okuduğundan liste
   * ile "senin sıran"/Skor Kartı başlığı ancak böyle aynı sayıyı gösterir.
   */
  sira: number;
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
  /**
   * Ulaşılan en yüksek rütbe eşiği (0=Çaylak) — kutlama geçmişi kaydı.
   * Satırdaki mühür 12 Ağustos 2026'dan beri bundan DEĞİL güncel puandan
   * (`tierFor(total_score)`, "düşmeli" sürüm) çiziliyor.
   */
  rank_tier: number;
  /**
   * OHP — ortalama hamle puanı (hamle başına alınan ortalama puan).
   * `player_stats_overall.avg_move_score` ile BİREBİR AYNI ifadeden gelir
   * (ağırlıklı ortalama, 2 basamak): k-lig satırındaki OHP ile o oyuncunun
   * Skor Kartı'ndaki "Ortalama Hamle Puanı" AYNI sayı olmak zorunda, biri
   * değişirse öteki de. Hiç hamle verisi olmayan (eski) kayıtlarda null.
   */
  avg_move_score: number | null;
}

export interface MyLeaderboardRank {
  /** `k_lig_siralama.sira` ile AYNI sayı — bkz. `LeaderboardRow.sira`. */
  rank: number;
  total_score: number;
  /**
   * Bkz. `LeaderboardRow.avg_move_score` — "senin sıran" kısayolu da aynı
   * tabloda aynı kolonları çizdiğinden RPC bunu da döndürür (yoksa o tek
   * satırda OHP boş kalır ve tablo hizasız görünür).
   */
  avg_move_score: number | null;
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
  /**
   * Oynanan en yüksek puanlı TEK kelimenin (X2/X3 çarpanı dahil) nihai
   * puanı — tüm oyunlar arasında en yükseği (`max`). `best_move_score`'dan
   * farklı, o bir HAMLEnin toplam puanıdır.
   */
  best_word_score: number | null;
  longest_word: string | null;
  first_places: number;
  second_places: number;
  /** `online_game_id` boş olan (Yapay Zeka'ya karşı) oyun sayısı. */
  local_games_played: number;
  /** `online_game_id` dolu olan (Canlı/Arkadaşınla) oyun sayısı. */
  online_games_played: number;
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
  /**
   * Ulaşılan en yüksek rütbe eşiği (0=Çaylak, 50/100/200/500/1000 —
   * `league_rewards.kind='rank_up'` satırlarının max threshold'u).
   * 12 Ağustos 2026'dan beri UI gösterimi bunu KULLANMIYOR — rütbe artık
   * güncel puandan türetiliyor ("düşmeli" sürüm, `tierFor(total_score)`);
   * bu kolon yalnızca "hangi eşikler daha önce kutlandı" kaydı. YALNIZCA
   * `player_stats_overall` view'ında var — mod bazlı `player_stats`
   * satırlarında undefined (ödül/rütbe moda bölünemez).
   */
  rank_tier?: number;
  /**
   * total_score'a dahil edilen toplam oyun ödülü puanı (games_reward
   * satırlarının toplamı) — UI'da "Genel = sekmelerin toplamı + ödül"
   * farkını açıklamak için. Yalnızca `player_stats_overall`'da var.
   */
  bonus_points?: number;
}

/**
 * k-lig ödül/rütbe kayıtları (`league_rewards` tablosu) — üç tür:
 * `points_reward` (puan eşiği ödülü — rütbe eşikleriyle aynı liste, 50→+5 …
 * 1000→+100; 12 Ağustos 2026'ya kadar oyun sayısına bağlı `games_reward`dı),
 * `points_milestone` (her 100 puan kutlaması, points=0),
 * `rank_up` (rütbe eşiği aşımı, points=0),
 * `rank_down` (rütbe düşüş bildirimi, points=0 — diğerlerinin aksine
 * TEKRARLANABİLİR: aynı eşikten yeniden düşülürse sunucu `seen_at`'i
 * sıfırlar, üzgün banner yeniden gösterilir). `seen_at` banner'ın cihazdan
 * bağımsız "bir kez göster" işareti (bkz. LeagueRewardsHost).
 */
export interface LeagueReward {
  id: string;
  user_id: string;
  kind: 'points_reward' | 'points_milestone' | 'rank_up' | 'rank_down';
  threshold: number;
  points: number;
  seen_at: string | null;
  created_at: string;
}

// ── Admin paneli ────────────────────────────────────────────────────────────

/**
 * admin_list_members RPC çıktısındaki tek satır (auth.users + profiles).
 *
 * Kayıt formunun TÜM alanlarını + izinleri taşır (21 Ağustos 2026, kullanıcı
 * isteği). Değerler her çağrıda `profiles`ten CANLI okunuyor — dondurulmuş
 * bir anlık görüntü DEĞİL, yani üye Hesap Ayarları'ndan bir alanı sonradan
 * değiştirirse panel bir sonraki açılışta yeni değeri gösterir.
 */
export interface AdminMember {
  id: string;
  email: string | null;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  display_name: string | null;
  gender: Gender | null;
  /** ISO `yyyy-mm-dd`; girilmediyse null. */
  birth_date: string | null;
  avatar_url: string | null;
  /**
   * Kullanım Koşulları onayı. **21 Ağustos 2026'ya kadar bu alan YAPISAL
   * OLARAK hep `false`du** — `handle_new_user` metadata'daki `agreedToTerms`i
   * hiç okumuyordu ve onu yazan tek yol (istemcideki signUp-sonrası update)
   * yalnızca e-posta doğrulaması KAPALIYKEN koşuyordu. Trigger düzeltildi ve
   * mevcut satırlar `auth.users` metadata'sındaki GERÇEK kayıttan dolduruldu;
   * metadata'sı hiç olmayan (sistemin ilk) hesap bilerek `false` kaldı.
   */
  agreed_to_terms: boolean;
  marketing_consent: boolean;
  /** Onay/geri çekme anı — sunucudaki trigger yazar, istemci ASLA göndermez. */
  marketing_consent_at: string | null;
  /** İşlemsel bildirim tercihi (opt-OUT: varsayılanı açık). */
  email_notifications_enabled: boolean;
  is_admin: boolean;
  signup_channel: 'direct' | 'form';
  /** Kayıt anındaki ilk-temas kaynağı; null = bu istemci hiç damgalamadı. */
  signup_utm_source: string | null;
  /** Daveti gönderen üyenin adı (`profiles.invited_by` çözülmüş hâli). */
  invited_by_name: string | null;
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
 * admin_source_funnel RPC çıktısındaki tek satır (Büyüme > Kullanıcı) —
 * kaynak başına gelen → üye → başlayan → biten hunisi.
 *
 * TABLO BAŞTAN SONA MİSAFİR HUNİSİ (22 Ağustos 2026): "bir kanaldan gelip
 * HENÜZ ÜYE OLMADAN ürünü deneyen insanlar". `visitors` zaten öyleydi
 * (ziyaret kaydı yalnızca oturum kapalıyken yazılır); `starts`/`starters`
 * (`game_starts.is_guest is true`) ve `finishes` (`game_finishes.user_id is
 * null`) o gün aynı kitleye indi. Üye tarafı yalnızca `member_games`/
 * `players`ta ve o AYRI bir dimension (kayıt damgası).
 *
 * İki AYRI dimension yan yana duruyor, aralarında JOIN YOK: `visitors`/
 * `starts`/`starters`/`finishes` anonim cihaz tablolarının (`guest_visits`,
 * `game_starts`, `game_finishes`) kendi `utm_source`'undan, `signups`/
 * `member_games`/`players` ise kayıt anında profile damgalanan
 * `profiles.signup_utm_source`'tan geliyor (bkz. `20260816…_source_funnel`
 * ve `20260822…_source_funnel_finishes` migration'ları). Bu yüzden bir
 * kaynağın yalnızca ziyaretçisi ya da yalnızca üyesi olabilir.
 *
 * `'bilinmiyor'` = profil damgalanmamış (bu özellikten önceki üyeler ve
 * bugün Flutter portundan gelen kayıtlar); `'direkt'` = `?ref=` olmadan
 * web'den geliş. İkisi bilinçli olarak AYRI.
 *
 * Pencere her adıma KENDİ olay tarihinden uygulanır (kohort değil).
 */
export interface AdminSourceFunnelRow {
  source: string;
  visitors: number;
  /**
   * Pencerede o kaynaktan ÜYE OLMADAN başlatılan yerel (YZ) oyun ADEDİ —
   * `game_starts`, `is_guest is true` (ROADMAP #9 + 22 Ağustos 2026 misafir
   * indirmesi). NULL bayrak (22 Ağustos öncesi satır ya da damgalamayan
   * istemci) misafir SAYILMAZ ve geriye dönük doldurulamaz.
   * `games`ten (BİTMİŞ oyun) bilinçli olarak ayrı: yerel oyunun
   * medyan süresi 18,1 dakika olduğundan reklamdan gelen soğuk bir ziyaretçi
   * çoğu zaman oynar ama BİTİRMEZ; ayrıca `games` misafir oyunlarını tanım
   * gereği hiç görmez (o satır yalnızca girişli kullanıcı için açılır).
   */
  starts: number;
  /**
   * O oyunları başlatan BENZERSİZ MİSAFİR CİHAZ sayısı
   * (`game_starts.anon_id`, aynı `is_guest` filtresiyle — aksi halde oranın
   * payı ile paydası farklı kitlelerden gelirdi).
   * `visitors` ile AYNI kimlikten sayıldığından `starters / visitors` bu
   * tablodaki TEK gerçek cihaz-bazlı dönüşüm oranıdır — `signups`/`players`
   * ise `profiles.signup_utm_source` üzerinden gelir, yani ayrı bir dimension.
   * Tabloda yalnızca yüzde modunda (ve CSV'de) görünür.
   */
  starters: number;
  signups: number;
  /**
   * Pencerede o kaynaktan ÜYE OLMADAN bitirilen yerel (YZ) oyun ADEDİ —
   * `game_finishes`, `user_id is null` (22 Ağustos 2026). Tabloda "Biten"
   * sütunu; `starts` ("Başlayan") ile
   * çifttir ve ikisi AYNI popülasyonu ölçer (misafir dahil, cihaz bazlı,
   * `utm_source` damgalı), yani "başlayanların yüzde kaçı bitirdi" sorusu
   * ancak bu ikisiyle sorulabilir.
   *
   * ⚠ `member_games` ile KARIŞTIRMA: o, `profiles.signup_utm_source`
   * üzerinden gelen bambaşka bir dimension (yalnızca ÜYELERİN oyunları) ve
   * bu kolon eklenene kadar tablodaki "Oyun" sütunu oydu — bu yüzden
   * reklamdan gelen soğuk trafikte hep 0 görünüyordu (bkz. 22 Ağustos 2026,
   * Instagram: 47 başlayan / 3 üye / 0 üye-oyunu).
   *
   * Kolon 22 Ağustos 2026'da eklendi, GERİYE DÖNÜK DOLDURULAMAZ — ondan
   * önceki tüm bitişler `'bilinmiyor'` satırında toplanır.
   */
  finishes: number;
  /**
   * ÜYELERİN (profil damgası olanların) pencerede bitirdiği oyun ADEDİ —
   * eski "Oyun" sütunu. Tabloda GÖSTERİLMEZ, yalnızca CSV'de. `finishes` ile
   * çakışmıyor: bu, üyenin KAYIT damgasından gelir (hesabı takip eder), o
   * ise cihaz etiketinden ve yalnızca misafiri sayar. Üye tarafının kaynak
   * kırılımı bilinçli olarak yalnızca burada — cihaz etiketiyle ikinci bir
   * üye ölçüsü üretmek aynı sorunun iki farklı yanıtını doğururdu.
   */
  member_games: number;
  /**
   * O kaynağın damgasını taşıyan, pencerede EN AZ BİR oyun bitirmiş BENZERSİZ
   * kullanıcı sayısı — `member_games` (oyun ADEDİ) ile karıştırılmamalı.
   * "Üyelerin yüzde kaçı oyun oynamış" sorusu ancak bununla yanıtlanabilir;
   * oyun adedi bir kişinin 50 oyun oynamasıyla %100'ü kolayca aşardı. Tabloda
   * yalnızca CSV'de görünür.
   */
  players: number;
}

/**
 * admin_app_version_breakdown RPC çıktısındaki tek satır (Büyüme >
 * Kullanıcı) — son N günde hangi istemci sürümünden kaç YEREL oyun açıldığı.
 *
 * NEDEN VAR: `app_config.mobile_min_supported_version` kolu (zorunlu
 * güncelleme kapısı) bugüne kadar VERİSİZ kullanılıyordu — eşiği erken
 * yükseltmek güncel olmayan kullanıcıları uygulamadan kilitler, geç
 * yükseltmek düzeltilmiş bir hatayı sahada yaşatır.
 *
 * ⚠ `starts` OYUN AÇILIŞI sayar, KULLANICI değil. `devices` app tarafında
 * 0 kalır: port `anon_id` göndermiyor (web'in `visitTracking` damgasının
 * portu henüz yok). Bu yüzden panel `starts`ı gösteriyor.
 *
 * ⚠ Kapsam yalnızca YEREL (YZ) oyunlar — `game_starts`ın kendi kapsamı.
 */
export interface AdminAppVersionRow {
  /** `web` / `ios` / `android` / `app-web` / `bilinmiyor`. */
  platform: string;
  /** Mobil sürüm; web ve eski satırlarda `bilinmiyor`. */
  app_version: string;
  starts: number;
  devices: number;
  last_seen: string;
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
 * admin_platform_breakdown RPC çıktısındaki tek satır (Büyüme > Kullanıcı) —
 * son N günde biten oyunların hangi İSTEMCİDEN oynandığı.
 *
 * `guest_visits.device_type`ten TAMAMEN ayrı bir soru: o, oturum KAPALIYKEN
 * yazılıyor ve "tarayıcı mobil mi masaüstü mü" diyor; bu ise girişli
 * kullanıcının "app mi web mi" sorusunu yanıtlıyor — mobil lansmanı ancak
 * bununla ölçülebiliyor.
 *
 * `platform` bu kolonun eklenmesinden ÖNCE biten oyunlarda null; RPC onları
 * `'bilinmiyor'` olarak toplar (satır düşürmek toplamı yalancı yapardı).
 */
export interface AdminPlatformRow {
  platform: string;
  games: number;
  players: number;
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
 * admin_game_activity_series'in p_source parametresi: Toplam/Canlı/Yapay Zeka
 * kombosu (31 Temmuz 2026, `admin_game_activity_include_online` migration'ı).
 * 'local', Yapay Zeka'ya karşı yerel/aynı-cihaz oyunları (`game_finishes`
 * tablosu) kapsar; 'online' Canlı (gerçek çok kullanıcılı) oyunları (`games`
 * tablosundaki `online_game_id is not null` satırları, `online_game_id`
 * bazında tekilleştirilmiş) kapsar. 'online' seçiliyken `AdminGameScope`
 * 'guest' anlamsızdır — Canlı oyunda tüm katılımcılar girişlidir.
 */
export type AdminGameSourceType = 'total' | 'online' | 'local';

/**
 * admin_game_activity_series RPC çıktısındaki tek kova (Büyüme > Oyun grafiği).
 * `games_finished` yalnızca gerçekten sonuna kadar oynanıp (bag+raf
 * boşalarak ya da pas turuyla) biten, teslimle bitmemiş oyunları sayar
 * (`games_finished_same_session`/`games_finished_multi_session` bu toplamın
 * kırılımı). `games_surrendered`, aynı `completed=true` kümesinden ama
 * bir/birden fazla oyuncunun teslim olmasıyla aktif oyuncu sayısı 1'e
 * düşüp aniden biten oyunları ayrı sayar (`GameState.endReason ===
 * 'surrender'`, Canlı'da `check_turn_timeout`) — bunlar gerçek oyun süresini
 * yansıtmadığından "Bitirilen"e karışmaz. Yerelde teslimin tek kaynağı 7
 * günlük süre aşımı, Canlı'da 48 saatlik sıra aşımıdır; kullanıcının kendi
 * isteğiyle terk etmesi 29 Temmuz 2026'da kaldırıldığından ayrı bir "Terk"
 * serisi (eski `games_abandoned`) 3 Ağustos 2026'da tamamen kaldırıldı —
 * hiç oynanmamış (turnCount<2) bir kayıt artık ceza da telemetri de
 * üretmiyor. Medyan ve p90 alanları da yalnızca teslimsiz tamamlanan
 * oyunlar üzerinden hesaplanır ve o kovada hiç biten oyun yoksa null döner
 * (0 değil). same_session: hiç kapatılıp devam ettirilmemiş oyunlar;
 * multi_session: en az bir kez kapatılıp localStorage'dan devam ettirilmiş
 * oyunlar (bkz. `GameState.multiSession`). Bucket'lar İstanbul yerel gününe
 * göre kesilir (`admin_game_istanbul_tz_and_surrender_split` migration'ı).
 * "Başlatılan" (eski `game_starts`) hiçbir yerde ihtiyaç görülmediği için
 * 20 Temmuz 2026'da tamamen kaldırıldı (tablo dahil).
 *
 * **16 Ağustos 2026 — süre alanları ORTALAMADAN MEDYANA geçti**
 * (`admin_game_duration_median` migration'ı). Gerekçe canlıda ölçüldü:
 * dağılım aşırı çarpık, "tek oturumda" biten 200 yerel oyunda ortalama
 * 246,6 dk iken medyan 18,1 dk (13 kat) — 49 oyun 1 saatten, 7 oyun 1
 * GÜNDEN uzun (açık unutulmuş / Setup'a çıkılıp günler sonra dönülmüş).
 * Panel "ortalama oyun süresi ≈ 4 saat" diyordu, tipik oyun 18 dakika.
 * `p90_duration_seconds` medyanın gizlediği kuyruğu gösterir.
 * **Medyan iki kaynaktan BİRLEŞTİRİLEMEZ** (ortalama sum/count ile
 * kurulabiliyordu): RPC bu yüzden yerel + Canlı ham süreleri tek bir
 * union'da toplayıp percentile'ı orada hesaplıyor.
 *
 * `games_finished_same_session`/`_multi_session` sunucuda DURUYOR ama
 * istemci Oyun Sayısı grafiğinde artık ÇİZMİYOR (bkz. kök CLAUDE.md,
 * "Aynı Oturum / Çok Oturumlu kırılımı") — süre tarafında ise kırılım
 * kalıyor, yalnızca etiketi "Tek Oturumda / Günlere Yayılan" oldu.
 */
export interface AdminGameActivityPoint {
  bucket: string;
  games_finished: number;
  games_finished_same_session: number;
  games_finished_multi_session: number;
  games_surrendered: number;
  med_duration_seconds: number | null;
  med_duration_same_session_seconds: number | null;
  med_duration_multi_session_seconds: number | null;
  p90_duration_seconds: number | null;
}

/**
 * admin_ai_balance RPC çıktısındaki tek satır (Büyüme > Oyun, "YZ Dengesi").
 * Yerel (Yapay Zeka'ya karşı) oyunlarda İNSANIN sonuç dağılımı, oyuncu
 * sayısı bazında. Teslim olan satırlar HARİÇ — onlar bir beceri sonucu
 * değil, 7 günlük terk-edilme cezasının kaydı; içeri alınsalardı YZ
 * olduğundan güçlü görünürdü.
 *
 * Okurken referans nokta ŞART: rastgele bir sonuçta beklenen kazanma
 * oranı 2 kişilikte %50, 4 kişilikte %25'tir. Ölçüm anındaki değerler
 * (16 Ağustos 2026): 2 kişilik %57 (95/167), 4 kişilik %31 (29/93) —
 * yani insan iki modda da rastgelenin biraz üstünde, denge makul.
 *
 * `second_places` 17 Ağustos 2026'da eklendi: 4 kişilikte k-lig ikinciliğe
 * de puan verdiğinden (`player_stats`: rank=2 AND player_count<>2 THEN 1)
 * yalnızca birinciliğe bakmak "insan puan alıyor mu" sorusunun yarısını
 * ölçüyordu. Tanım `player_stats.second_places` ile BİREBİR aynı ifade
 * (`count(*) filter (where rank = 2)`) — aynı metriğin iki yerde sessizce
 * ayrışmaması için; biri değişirse öteki de değişmeli.
 *
 * 2 kişilikte bu alan DOLU ama ANLAMSIZ: orada rank=2 kaybetmekle aynı şey
 * (ölçüldü: 75 = losses) ve k-lig puanı getirmez — UI onu bilerek yalnızca
 * 4 kişilik satır için gösteriyor.
 */
export interface AdminAiBalanceRow {
  players: number;
  games: number;
  wins: number;
  ties: number;
  losses: number;
  second_places: number;
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

/**
 * admin_active_players_series RPC çıktısındaki tek kova (Büyüme > Kullanıcı).
 *
 * **"Aktif oyuncu" TANIMI (sunucuda `_admin_user_activity` view'ı, TEK kaynak):**
 * kullanıcı şu ÜRÜN eylemlerinden birini yaptığı an aktiftir — oyun bitirme,
 * Canlı hamle, Canlı sohbet mesajı, beğeni, arkadaşlık isteği, Canlı oyun kurma.
 *
 * `active_in_bucket`: o kovanın İÇİNDE aktif olan benzersiz kullanıcı (günlük
 * granülerlikte DAU, haftalıkta WAU).
 * `active_28d`: kovanın SONUNDA biten 28 günlük yuvarlanan pencerede aktif olan
 * benzersiz kullanıcı. 28 gün (30 değil) bilinçli — tam dört hafta olduğundan
 * hafta-içi/hafta-sonu dalgalanması pencereye eşit dağılır.
 *
 * **Bu "MAU" DEĞİL, bilerek:** girişli kullanıcı için "uygulamayı açtı" sinyali
 * şemada YOK (`guest_visits` yalnızca oturum kapalıyken yazılıyor,
 * `auth.users.last_sign_in_at` üzerine yazılan tek bir kolon, `auth.refresh_tokens`
 * ~26 günde budanıyor, `auth.audit_log_entries` boş — dördü de 14 Ağustos 2026'da
 * ölçüldü). Yani buradaki sayı uygulamayı açıp hiçbir şey yapmadan çıkanı SAYMAZ.
 * Gerekçenin tamamı migration başlığında: `20260814195803_admin_growth_retention_activation`.
 */
export interface AdminActivePlayersPoint {
  bucket: string;
  active_in_bucket: number;
  active_28d: number;
}

/**
 * admin_retention_cohorts RPC çıktısındaki tek HÜCRE (Büyüme > Kullanıcı) —
 * uzun (long) biçim: pivotlamayı istemci yapar.
 *
 * `cohort_week`: kaydın oluştuğu haftanın başı (İstanbul). `cohort_size`: o
 * haftada kaydolan üye sayısı. `week_offset`: kayıttan kaç hafta sonra (0 =
 * kayıt haftasının kendisi). `active_users`: o kohorttan, o hafta AKTİF olan
 * (yukarıdaki tanım) benzersiz üye sayısı.
 *
 * **Yalnızca TAMAMLANMIŞ haftalar döner** — penceresi henüz bitmemiş bir hafta
 * her zaman yapay olarak düşük görünür ve tablonun son köşegenini yalancı bir
 * "düşüş" gibi gösterirdi.
 */
export interface AdminRetentionCell {
  cohort_week: string;
  cohort_size: number;
  week_offset: number;
  active_users: number;
}

/**
 * admin_activation_stats RPC çıktısı (Büyüme > Kullanıcı) — "kayıt oldu ama hiç
 * oyun bitirmedi" ve ilk oyuna kadar geçen süre.
 *
 * **Aktivasyon, aktif oyuncudan FARKLI tanımlı ve bu bilinçli:** buradaki soru
 * "hiç oyun BİTİRDİ mi" (`games` satırı), "herhangi bir şey yaptı mı" değil.
 * Yalnızca arkadaşlık isteği göndermiş bir üye aktif oyuncu SAYILIR ama aktive
 * olmuş SAYILMAZ. İki farklı soru, iki farklı tanım — biri ötekine "tutarlılık"
 * gerekçesiyle uydurulMAMALI.
 *
 * `median_hours_to_first_game`, yalnızca aktive olmuş üyeler üzerinden hesaplanır
 * (hiç oynamayanlar medyanı sonsuza çekmesin diye) ve hiç aktivasyon yoksa null'dır.
 */
export interface AdminActivationStats {
  total_users: number;
  activated_users: number;
  never_activated: number;
  activated_same_day: number;
  activated_within_3_days: number;
  activated_later: number;
  median_hours_to_first_game: number | null;
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
