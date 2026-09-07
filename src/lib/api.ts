// Kelimeki — Supabase veri erişim katmanı
//
// Tüm fonksiyonlar Supabase yapılandırılmamışsa güvenli biçimde boş/no-op
// döner, böylece oyun çevrimdışı da çalışır.
//
// Dosyanın boyutu (~70 fonksiyon, `if (!supabase) return ...` + `console.error`
// kalıbının neredeyse her fonksiyonda tekrarı) kod incelemesinde ("Orta"
// bulgu) bilinçli olarak ele alınmadı — sebep tembellik değil, gerçek bir
// risk/fayda hesabı: fonksiyonların dönüş tipleri/hata semantiği birbirinden
// belirgin şekilde farklı (kimi `null` döner, kimi boş dizi, kimi fırlatır,
// kimi `false`/`0` — bkz. #21/#40/#42/#43'teki fix'ler, tam da bu farkın
// nerede bilinçli nerede kazara olduğunu ayırt etmenin kendisi zaman aldı).
// Tek bir genel `withSupabase` sarmalayıcısına zorlamak ya hepsini tek bir
// dönüş sözleşmesine indirger (birçok çağrı yerinde davranış değişikliği
// riski) ya da sarmalayıcı kendisi neredeyse her fonksiyon için ayrı bir
// varyant taşımak zorunda kalır (kazanç şüpheli). Bu incelemede zaten
// somut, gerçek hataları olan fonksiyonlar (bkz. yukarıdaki High/Medium
// fix'ler) tek tek düzeltildi; kalan tekrar yalnızca bir okunabilirlik
// notu, ayrı bir davranış riski taşımıyor.
import { FunctionsHttpError } from '@supabase/supabase-js';
import type { RealtimeChannel } from '@supabase/supabase-js';
import type { HeadToHead } from '../utils/headToHead';
import { supabase, isSupabaseConfigured } from './supabase';
import type {
  AdminActivationStats,
  AdminActivePlayersPoint,
  AdminActivityGranularity,
  AdminChatReportRow,
  AdminMemberActivityLogRow,
  AdminEngagementActivityPoint,
  AdminEngagementTotals,
  AdminAiBalanceRow,
  AdminFeedbackRow,
  AdminFriendActivityPoint,
  AdminFriendTotals,
  AdminGameActivityPoint,
  AdminGameScope,
  AdminGameSourceType,
  AdminAppVersionRow,
  AdminPushVersionRow,
  AdminClientErrorRow,
  AdminSourceFunnelRow,
  AdminDeviceBreakdownRow,
  AdminGuestDeviceRow,
  AdminGuestStandaloneRow,
  AdminMember,
  AdminPlatformRow,
  AdminRetentionCell,
  AdminUserActivityPoint,
  BoardSnapshotTile,
  ClientPlatform,
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
  LeagueReward,
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
import { CLIENT_PLATFORM } from '../utils/platform';
import { trCompare, trLower } from '../utils/turkish';
import { getOrCreateAnonId, getStoredUtmSource } from '../utils/visitTracking';
import { isNetworkError } from '../utils/offlineNotice';
import { reportClientError } from '../utils/errorReporting';
import type { GameState, HistoryEntry, Tile } from '../game/types';

// ── Geçici ağ hatasında sessiz yeniden deneme ──────────────────────────────
//
// NEDEN (21 Ağustos 2026, gerçek vaka): Bir kullanıcı sırası KENDİSİNDEYKEN
// uygulamayı açtı ve "Devam eden bir Canlı oyunun yok." gördü; oyun ancak
// ~9 dakika sonra kendiliğinden belirdi. Sunucu logları tertemizdi —
// `list_my_online_games` o oturumda 16 kez çağrılmış, 16'sı da 200 dönmüş VE
// oyunu içermişti (kanıt: her birinin hemen ardından gelen
// `online_game_states?...in.(<id>)` isteği; `fetchOnlineGameTurns` boş id
// listesinde hiç istek atmaz, yani o istek listenin dolu olduğunu kanıtlar).
// Demek ki düşen istek sunucuya HİÇ ULAŞMAMIŞTI: telefon oturum ortasında
// iki IP arasında geçmişti (WiFi ↔ hücresel) ve geçiş uçuştaki `fetch`'i
// iptal etmişti. Böyle bir istek sunucu tarafında hiç iz bırakmaz — logların
// temiz görünmesi bu yüzden hatayı ÇÜRÜTMÜYOR.
//
// Asıl kusur ağ değişimi DEĞİL, isteğin bir daha denenmemesiydi: bu okuma
// yollarının hiçbirinde retry yoktu (projedeki tek retry `wordSetLoader`) ve
// `loadGames`'i yeniden tetikleyen tek şey öne dönüş ya da bir Realtime
// olayıydı — ekrana bakıp bekleyen birinde ikisi de olmuyor. Nadir bir olay
// böylece KALICI bir yanlış ekrana dönüşüyordu.
//
// KURAL: yalnızca ağ katmanı hataları (cevabın hiç gelmediği durum)
// tekrarlanır. Sunucunun KENDİ reddi (401/403/RLS/iş kuralı) ASLA — o bir
// karar, hata değil (aynı ilke: `friendlyAuthMessage`, `isNetworkError`).
// Yalnızca OKUMA yollarında kullanılır; `submit_move` gibi yazmalar buradan
// GEÇMEZ (yazma idempotensi ayrı bir iş, bkz. `p_move_id`).
const RETRY_DELAYS_MS = [400, 1200];

/**
 * Supabase `{data,error}` sonucundaki hata ağ katmanından mı geliyor?
 *
 * `isNetworkError` bir `Error` ya da METİN bekliyor: PostgrestError düz bir
 * nesne olduğundan doğrudan geçilseydi `String(err)` "[object Object]" olur
 * ve kalıp HİÇBİR ZAMAN eşleşmezdi (sessizce "retry yok"a düşerdik).
 * postgrest-js ağ hatasını `message: "TypeError: Load failed"` gibi
 * sarmaladığından mesajın KENDİSİNİ veriyoruz.
 */
function isNetworkFailure(error: { message?: string } | null | undefined): boolean {
  if (!error) return false;
  return isNetworkError(error.message ?? '');
}

/** Ağ katmanında düşen bir okumayı `RETRY_DELAYS_MS` kadar yeniden dener. */
async function retryOnNetworkFailure<T extends { error: { message?: string } | null }>(
  islem: () => PromiseLike<T>,
): Promise<T> {
  let sonuc = await islem();
  for (const gecikme of RETRY_DELAYS_MS) {
    if (!isNetworkFailure(sonuc.error)) return sonuc;
    await new Promise((r) => setTimeout(r, gecikme));
    sonuc = await islem();
  }
  return sonuc;
}


const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/**
 * removeFriend/fetchFriendRelation gibi bir kimliği ham bir PostgREST
 * `.or()` filtre string'ine gömen fonksiyonlarda kullanılıyor — parametre
 * her zaman bir uuid (ör. `user.id`, başka bir profilin id'si) olduğundan
 * risk düşük (kod incelemesi, "Düşük" bulgu), ama virgül/parantez gibi
 * PostgREST filtre söz dizimine özel karakterler taşıyan bir değer
 * filtreyi kırıp beklenmeyen ek koşullar enjekte edebilirdi — bu kontrol
 * o ihtimali baştan eler.
 */
function assertUuid(id: string, label: string): void {
  if (!UUID_RE.test(id)) throw new Error(`Geçersiz ${label}.`);
}

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
  // Yerel (Yapay Zeka'ya karşı) oyunlarda surrendered:true artık YALNIZCA
  // 7 günlük terk-edilme akışından gelir (manuel/anlık teslim yolu 29
  // Temmuz 2026'da kaldırıldı) — yani bu bayrak tek başına "bu kayıt bir
  // terk-edilme cezası" anlamına geliyor. `error.code==='23505'` (zaten
  // kaydedilmiş, tekrar deneme) dalında ÇAĞRILMIYOR ki kuyruktan yeniden
  // denenen bir kayıt aynı bildirimi iki kez göndermesin.
  if (game.surrendered && data?.id) {
    void notifyLocalGameAbandoned(data.id, game.player_count);
  }
  return data?.id ?? null;
}

/**
 * `saveGame`'in az önce GERÇEKTEN yeni kaydettiği (terk edilmiş) bir yerel
 * oyun için hesap sahibine -2 k-lig cezasını bildiren bir e-posta gönderir
 * (`notify-local-game-abandoned` Edge Function'ı). Best-effort/
 * fire-and-forget — kayıt zaten oluşmuş olduğundan bir e-posta hatası
 * kullanıcıya hiç yansıtılmaz, yalnızca loglanır. `gameId`, Edge Function'ın
 * gerçekten böyle bir satır olduğunu (kendi hesabına ait, surrendered=true,
 * yerel/online_game_id null) doğrulayabilmesi için geçiliyor — önceden
 * yalnızca çıplak bir `player_count` alıp hiçbir doğrulama yapmadan mail
 * gönderiyordu (kod incelemesi: kullanıcı kendine sahte "-2 puan" maili
 * gönderebiliyordu, düşük etkili ama tasarım simetrisi bozuktu).
 */
async function notifyLocalGameAbandoned(gameId: string, playerCount: number): Promise<void> {
  if (!supabase) return;
  try {
    await invokeEdgeFunction('notify-local-game-abandoned', { game_id: gameId, player_count: playerCount });
  } catch (err) {
    console.error('[Kelimeki] notifyLocalGameAbandoned hatası:', (err as Error).message);
  }
}

/**
 * Bir oyunun bittiğini, ne kadar sürdüğünü ve tek/çok oturumlu olup
 * olmadığını kaydeder — giriş yapmış ya da misafir, fark etmez. Tamamen
 * anonim/sayaç amaçlıdır (skor/kelime gibi kişisel veri yok); asıl skor
 * kaydı hâlâ yalnızca giriş yapmış kullanıcılar için `saveGame`/`games`
 * tablosu üzerinden yürür. `multiSession`,
 * `GameState.multiSession`'dan gelir — oyun bitmeden en az bir kez
 * tarayıcı/uygulama kapatılıp devam ettirildiyse true. `endedBySurrender`
 * true ise oyun normal yoldan (bag+raf boşalarak ya da pas turuyla)
 * bitmemiş, teslim sayılmıştır — admin panelinin Büyüme > Oyun grafiği
 * bunları "Bitirilen" sayısına/ortalama süresine değil ayrı bir "Teslim"
 * serisine koyar (teslim, gerçek oyun süresini yansıtmaz). Yerel/YZ
 * oyunlarında teslimin TEK kaynağı 7 günlük süre aşımıdır (bkz.
 * `gameStorage.ts` `takePendingAbandonedGame` ve App.tsx'teki
 * `refreshCloudSaves`) — manuel/anlık teslim yolu 29 Temmuz 2026'da
 * kaldırıldığından, "kendi isteğiyle terk etme" diye ayrı bir durum artık
 * yok; süresi dolmadan gerçekten bırakılan (turnCount<2) bir oyun ise hiç
 * kaydedilmez, çünkü ceza da almaz.
 *
 * `userId` opsiyonel — çağıran zaten `useAuth()`'tan bir `user.id` biliyorsa
 * (App.tsx'teki oyun bitiş akışında olduğu gibi, aynı anda `saveGameDurable`
 * ile birlikte çağrılıyor) burada AYRICA bir `getUser()` ağ turu yapılmasın
 * diye geçilebilir; verilmezse eskisi gibi `getUser()`'dan okunur. Bu alan
 * yalnızca anonim bir sayaç tablosuna (`game_finishes`) yazılıyor — RLS zaten
 * gerçek `auth.uid()`'i kendi tarafında doğruladığından, çağıranın önbellekte
 * tuttuğu bir id'ye güvenmek burada bir güvenlik zafiyeti yaratmıyor.
 *
 * `utm_source` (22 Ağustos 2026) BURADAN, çağırandan DEĞİL okunuyor —
 * `logGameStart`'ın aksine. Sebep: bu fonksiyonun ÜÇ çağrı yeri var
 * (`App.tsx`'te normal bitiş, misafir kuyruğu ve bulut kaydı süpürmesi) ve
 * üçü de aynı değeri geçerdi; birini atlamak NULL yazardı, NULL ise bu
 * sözleşmede "bu istemci damgalamıyor" (bugün: Flutter portu) demek, yani
 * huninin "bilinmiyor" satırını sessizce şişirirdi. Değer cihazda
 * ilk-temasta donduğundan (`captureUtmSource`) çağrı anında okumak doğru.
 * `?ref=` hiç yoksa açıkça `'direkt'` yazılır — `logGameStart`/`signUp` ile
 * AYNI sözleşme; üçü ayrışırsa Kaynak Hunisi'nin adımları kıyaslanamaz olur.
 *
 * `anon_id` (31 Ağustos 2026) YALNIZCA `user_id` NULL iken yazılır — huninin
 * "Bitiren Cihaz" (`finishers`) sayacı için. Bu bir stil tercihi DEĞİL, bir
 * GİZLİLİK DEĞİŞMEZİ: `PrivacyModal` bölüm 6 anonim cihaz kodu için
 * "hesabınızla ASLA eşleştirilmez" diyor ve ikisini aynı satıra koymak tam
 * olarak o eşleştirmeyi yapardı. Sunucu bunu iki katmanda zorluyor (BEFORE
 * INSERT trigger + CHECK), yani burada bir hata kaydı DÜŞÜRMEZ — ama tek
 * savunma hattı sunucu OLMAMALI, `normalizeRoute`/`_mask_route` ikilisiyle
 * aynı duruş. `utm_source` gibi bu da ÇAĞIRANDAN değil buradan okunuyor:
 * fonksiyonun üç çağrı yeri var, birini atlamak sessizce eksik sayardı.
 */
export async function logGameFinish(
  playerCount: number,
  durationSeconds: number,
  multiSession: boolean,
  endedBySurrender = false,
  userId?: string | null,
  /**
   * Bitişin gerçekten olduğu an (epoch ms). Verilmezse sunucunun `now()`
   * varsayılanı kalır — normal bitişte doğrusu budur.
   *
   * ⚠ Terk-edilme yolunda VERİLMESİ ZORUNLU: orada satır, sürenin dolduğu an
   * değil kullanıcının uygulamayı bir sonraki açtığı an yazılıyor. Bkz.
   * `buildGameRecord`in aynı parametresi — ikisi AYNI anı taşımalı, yoksa
   * `games` ile `game_finishes` farklı günlere düşer.
   */
  finishedAtMs?: number,
): Promise<void> {
  if (!supabase) return;
  let resolvedUserId = userId;
  if (resolvedUserId === undefined) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    resolvedUserId = user?.id ?? null;
  }

  const { error } = await supabase
    .from('game_finishes')
    .insert({
      user_id: resolvedUserId,
      anon_id: resolvedUserId ? null : getOrCreateAnonId(),
      player_count: playerCount,
      duration_seconds: durationSeconds,
      multi_session: multiSession,
      ended_by_surrender: endedBySurrender,
      utm_source: getStoredUtmSource() ?? 'direkt',
      ...(finishedAtMs != null
        ? { created_at: new Date(finishedAtMs).toISOString() }
        : {}),
    });
  if (error) {
    console.error('[Kelimeki] logGameFinish hatası:', error.message);
  }
}

/**
 * Başlatılan bir YEREL (YZ'ye karşı) oyunu anonim olarak kaydeder —
 * `game_starts` tablosu, admin panelindeki Kaynak Hunisi'nin "Başlayan"
 * adımı için (ROADMAP #9, 21 Ağustos 2026).
 *
 * NEDEN VAR: huninin son adımı bugüne kadar kördü. Yalnızca BİTMİŞ oyun
 * kaydediliyordu, yerel oyunun medyan süresi 18,1 dakika, ve "Oyun" sütunu
 * misafir oyunlarını tanım gereği hiç göremiyor (`games` satırı yalnızca
 * girişli kullanıcı için açılıyor) — yani reklamdan gelen soğuk trafikte
 * "0 oyun" büyük olasılıkla "kimse BİTİRMEDİ" demekti, "kimse oynamadı"
 * değil. İkisi tamamen farklı aksiyon gerektiriyor.
 *
 * ⚠ `user_id` GÖNDERİLMEZ ve tabloda böyle bir kolon YOK — bilinçli bir
 * gizlilik kararı: `PrivacyModal` bölüm 6, anonim cihaz kodu için
 * "hesabınızla ASLA eşleştirilmez" diyor, `anon_id` ile `user_id`'yi aynı
 * satıra koymak tam olarak o eşleştirmeyi yapardı.
 *
 * `isGuest` (22 Ağustos 2026) o kararı BOZMUYOR: bir bayrak hangi hesap
 * olduğunu söylemez, dolayısıyla anon kodu bir hesapla eşleştirmeye izin
 * vermez. Huninin "Başlayan" adımı bununla misafire iniyor — "Gelen" zaten
 * yalnızca oturum kapalıyken yazıldığından tablo ilk kez tek bir kitleyi
 * ölçüyor. Sunucu `is_guest is true` filtreliyor, yani NULL (damgalamayan
 * istemci ya da eski satır) misafir SAYILMAZ; bu yüzden alan opsiyonel
 * DEĞİL — çağıran her zaman gerçek durumu geçmek zorunda.
 *
 * `utmSource` HİÇ NULL GÖNDERİLMEZ: `?ref=` yoksa bile açıkça `'direkt'`
 * yazılır (`signUp`'taki aynı sözleşme). Sunucuda null yalnızca
 * "damgalamayan istemci" (bugün Flutter portu) anlamına gelir ve
 * 'bilinmiyor' olarak sayılır — bu ayrım olmadan port satırları 'direkt'
 * satırını sessizce şişirirdi.
 *
 * Fire-and-forget: telemetri hatası oyunu ASLA etkilemez (`logGameFinish`/
 * `setOnlineGamePlatform` ile aynı duruş).
 */
export async function logGameStart(
  playerCount: number,
  anonId: string | null,
  utmSource: string | null,
  isGuest: boolean,
): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('game_starts').insert({
    anon_id: anonId,
    player_count: playerCount,
    utm_source: utmSource ?? 'direkt',
    is_guest: isGuest,
    // 23 Ağustos 2026: sürüm dağılımı (`admin_app_version_breakdown`).
    // `platform` bu tabloda YOKTU — `app_version` tek başına ios ile
    // android'i ayıramaz. `app_version` web'de BİLEREK null: web'in sürümü
    // derleme sha'sıyla zaten tekil, uydurma bir değer dağılımı kirletirdi.
    platform: CLIENT_PLATFORM,
    app_version: null,
  });
  if (error) {
    console.error('[Kelimeki] logGameStart hatası:', error.message);
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
 * Ekrana Ekleme" dökümleri için. `osVersion`/`deviceModel` (aynı dosyadaki
 * `getOsVersion`/`getDeviceModel`) iyi niyetle (best-effort) okunan,
 * şimdilik hiçbir ekranda gösterilmeyen ek alanlar — `null` gelmesi normal.
 */
export async function logGuestVisit(
  anonId: string,
  utmSource: string | null,
  deviceType: 'ios' | 'android' | 'desktop',
  isStandalone: boolean,
  osVersion: string | null,
  deviceModel: string | null,
): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('guest_visits').insert({
    anon_id: anonId,
    utm_source: utmSource,
    device_type: deviceType,
    is_standalone: isStandalone,
    os_version: osVersion,
    device_model: deviceModel,
  });
  if (error) {
    console.error('[Kelimeki] logGuestVisit hatası:', error.message);
  }
}

/**
 * Girişli VEYA girişsiz HER ziyareti tamamen anonim olarak `device_visits`e
 * kaydeder — admin panelinin Büyüme > Kullanıcı "Cihaz" dökümü için.
 * `logGuestVisit`ten BİLEREK AYRI: o yalnızca oturum KAPALIYKEN çağrılıp
 * Kaynak Hunisi'ni besliyor (huni bilinçli olarak misafir-only, bkz.
 * `source_funnel_guest_only` migration'ı); bu ise huniyi hiç beslemeden,
 * yalnızca "gelen tüm insanlar hangi cihaz/OS'ten geliyor" sorusu için
 * girişli kullanıcıları da kapsar (24 Ağustos 2026, kullanıcı isteği).
 * `anonId` `guest_visits`teki ile AYNI cihaz kimliği (localStorage) —
 * `user_id` BİLEREK gönderilmez/taşınmaz, kayıt hiçbir hesapla
 * eşleştirilemez (`device_visits_insert_any` RLS politikası hem `anon` hem
 * `authenticated` rolünden insert'e izin verir).
 */
export async function logDeviceVisit(
  anonId: string,
  deviceType: 'ios' | 'android' | 'desktop',
  osVersion: string | null,
  deviceModel: string | null,
): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.from('device_visits').insert({
    anon_id: anonId,
    device_type: deviceType,
    os_version: osVersion,
    device_model: deviceModel,
  });
  if (error) {
    console.error('[Kelimeki] logDeviceVisit hatası:', error.message);
  }
}

/**
 * Liderlik tablosunu sayfalı biçimde döner. `Leaderboard` bileşeni önce ilk
 * 10'u, sonra kaydırdıkça `offset`'i artırarak listenin sonuna kadar lazy-load
 * ile devam eder.
 *
 * **Kaynak `leaderboard` DEĞİL `k_lig_siralama`** (20 Ağustos 2026): sıra artık
 * sunucuda tek bir yerde hesaplanıyor (`sira`), eşit puanlılar OHP'ye göre
 * ayrışıyor. Öncesinde sıralama YALNIZCA `total_score`'a göreydi; eşitlikte
 * satır sırası Postgres'in keyfine kalıyordu ve SORGUDAN SORGUYA
 * DEĞİŞEBİLİYORDU — yani `.range()` ile sayfalanan bu listede bir satır iki
 * kez görünebilir ya da hiç görünmeyebilirdi. Ekrandaki sıra numarası da
 * dizideki indeksten (`i + 1`) değil bu kolondan geliyor, çünkü aynı sayıyı
 * `my_leaderboard_rank` de bu view'dan okuyor.
 */
export async function fetchLeaderboard(limit = 10, offset = 0): Promise<LeaderboardRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('k_lig_siralama')
    .select('*')
    .order('sira', { ascending: true })
    .range(offset, offset + limit - 1);
  if (error) {
    console.error('[Kelimeki] fetchLeaderboard hatası:', error.message);
    return [];
  }
  return (data as LeaderboardRow[]) ?? [];
}

/**
 * Oturum açan kullanıcının k-lig sırasını döner — listedeki (`fetchLeaderboard`)
 * sayıyla BİREBİR AYNI olmak zorunda: ikisi de `k_lig_siralama` view'ından
 * okuyor. Öncesinde RPC `rank()` kullanıyordu, yani eşit puanlı herkese AYNI
 * sırayı veriyordu (Bobola listede 13., kendi kartında "#10" görünüyordu).
 */
export async function fetchMyLeaderboardRank(userId: string): Promise<MyLeaderboardRank | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('my_leaderboard_rank', { p_user_id: userId });
  if (error) {
    console.error('[Kelimeki] fetchMyLeaderboardRank hatası:', error.message);
    return null;
  }
  const row = Array.isArray(data) ? data[0] : null;
  return row
    ? {
        rank: Number(row.rank),
        total_score: Number(row.total_score),
        avg_move_score: row.avg_move_score == null ? null : Number(row.avg_move_score),
      }
    : null;
}

/**
 * Verilen kullanıcıların k-lig TOPLAM PUANLARINI toplu döner — isimlerin
 * yanına konan rütbe mührü (`RankSeal` + `tierFor`) için. Sayfa başına TEK
 * sorgu; satır başına istek atılmaz.
 *
 * **Yeni bir migration GEREKMEDİ:** `leaderboard` view'ı zaten
 * `security_invoker = false` ile `profiles`/`games`in kilitli RLS'ini
 * bypass edip girişli herkese açık ve tam olarak bu iki kolonu taşıyor.
 * `total_score` ödül puanlarını (`league_rewards`) da İÇERİR — yani mühür,
 * hesap menüsündeki/Skor Kartı'ndaki k-lig puanıyla aynı sayıdan türüyor.
 * (Mod bazlı `player_stats` toplamı bu sayıyı VERMEZ, bkz. kök CLAUDE.md'nin
 * 17 Ağustos 2026'daki "parantezli puan" notu.)
 *
 * **View `games`e INNER JOIN yapıyor**, yani hiç oyun bitirmemiş bir
 * kullanıcı sonuçta YOKTUR — çağıran eksik id'yi 0 (Çaylak) saymalı.
 * Dönüş `null` ise "henüz bilinmiyor" demektir (yapılandırılmamış istemci ya
 * da ağ hatası) ve o durumda mühür HİÇ çizilmemeli — aksi halde herkes bir
 * an Çaylak görünür.
 */
export async function fetchRankScores(userIds: string[]): Promise<Map<string, number> | null> {
  if (!supabase) return null;
  const ids = Array.from(new Set(userIds.filter(Boolean)));
  if (ids.length === 0) return new Map();
  const { data, error } = await supabase
    .from('leaderboard')
    .select('user_id,total_score')
    .in('user_id', ids);
  if (error) {
    console.error('[Kelimeki] fetchRankScores hatası:', error.message);
    return null;
  }
  const map = new Map<string, number>();
  for (const row of (data as { user_id: string; total_score: number | null }[]) ?? []) {
    map.set(row.user_id, Number(row.total_score ?? 0));
  }
  return map;
}

/**
 * Oturum açan kullanıcının henüz görmediği k-lig ödül/rütbe kayıtları —
 * kutlama banner'ı (LeagueRewardsHost) için. RLS SELECT'i tüm girişli
 * kullanıcılara açık olduğundan (rütbe herkese görünür lig verisinin
 * parçası) filtre client'ta `eq(user_id)` ile daraltılıyor; `seen_at`
 * yalnızca `mark_league_rewards_seen` RPC'siyle yazılabilir.
 */
export async function fetchUnseenLeagueRewards(userId: string): Promise<LeagueReward[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('league_rewards')
    .select('*')
    .eq('user_id', userId)
    .is('seen_at', null)
    .order('created_at', { ascending: true });
  if (error) {
    console.error('[Kelimeki] fetchUnseenLeagueRewards hatası:', error.message);
    return [];
  }
  return (data as LeagueReward[]) ?? [];
}

/** Çağıranın TÜM görülmemiş ödül kayıtlarını görüldü işaretler (banner "Devam"ı). */
export async function markLeagueRewardsSeen(): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('mark_league_rewards_seen');
  if (error) {
    console.error('[Kelimeki] markLeagueRewardsSeen hatası:', error.message);
  }
}

/**
 * Kafa kafaya: çağıran ile [otherUserId] arasında oynanmış **2 kişilik**
 * Canlı oyunların sayısı ve kazanma dağılımı (`head_to_head_stats` RPC'si,
 * 3 Eylül 2026).
 *
 * **Neden RPC:** `fetchMyGames` sayfalı (20'şer), iki kişi arasındaki TÜM
 * oyunları istemcide saymak geçmişin tamamını sayfalamak olurdu. Ayrıca
 * donmuş `games.players` anlık görüntüsü `user_id` taşımadığından istemci
 * ancak İSİMLE eşleyebilirdi ve takma adlar değiştirilebiliyor — sunucuda
 * `online_games.slots` gerçek `user_id` taşıyor.
 *
 * ⚠ Sonuç ÇAĞIRANIN bakış açısından: `wins` = çağıran kazandı,
 * `losses` = bakılan kişi kazandı. Bar bunu ters okuyor (bkz.
 * `utils/headToHead.ts`).
 *
 * Kendi kartına bakarken RPC 0 döner (sunucuda `p_other <> auth.uid()`).
 */
export async function fetchHeadToHead(
  otherUserId: string,
): Promise<HeadToHead | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('head_to_head_stats', {
    p_other: otherUserId,
  });
  if (error) {
    console.error('[Kelimeki] fetchHeadToHead hatası:', error.message);
    return null;
  }
  // `returns table(...)` → tek satırlık dizi.
  const row = (data as HeadToHead[] | null)?.[0];
  if (!row) return null;
  return {
    games: row.games ?? 0,
    wins: row.wins ?? 0,
    losses: row.losses ?? 0,
    draws: row.draws ?? 0,
  };
}

/**
 * Bitişini GÖRMEDİĞİM Canlı oyunlarımın `games.id`'leri (3 Eylül 2026).
 *
 * Kullanıcı isteği: hamleni yapıp uygulamayı kapatıyorsun, sen yokken rakip
 * oynuyor ve oyun bitiyor — bitiş modalını hiç görmüyorsun. Bunun uygulama
 * içi karşılığı "Son Oynananlar" sekmesindeki kırmızı sayı + satırdaki
 * "Oyun Bitti (Yeni)" rozeti. Push BİLEREK seçilmedi (*"oyun bitti mesajı
 * atmak işin dozunu kaçırabilir"*).
 *
 * ⚠ `null` = BİLİNMİYOR (istek düştü) — boş dizi DEĞİL. Ayrım bu kod
 * tabanında üç kez ders olmuş bir şeyin aynısı: boş dönmek rozeti sessizce
 * kaybettirir ve kullanıcı haberi HİÇ görmez (bkz. `fetchPendingLiveGameCounts`).
 */
export async function fetchUnseenFinishedGames(): Promise<string[] | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('unseen_finished_online_games');
  if (error) {
    console.error('[Kelimeki] fetchUnseenFinishedGames hatası:', error.message);
    return null;
  }
  // `returns setof uuid` → düz dizi.
  return (data as string[] | null) ?? [];
}

/**
 * Biten Canlı oyun(lar)ı "gördüm" olarak işaretler.
 *
 * @param onlineGameId Verilirse YALNIZCA o oyun (bitiş modalı gösterildi);
 *   verilmezse görülmemiş TÜM oyunlar ("Son Oynananlar" sekmesi ziyaret
 *   edildi). İki yol da şart — gerekçe migration'ın başlığında.
 * @returns İşlem sunucuya ULAŞTI mı. `false` iken çağıran rozeti yerelde
 *   SIFIRLAMAMALI: sunucuda hâlâ görülmemiş duruyor, bir sonraki tazelemede
 *   geri gelir ve rozet "kayboldu sonra döndü" diye tuhaf görünür.
 */
export async function markGameFinishesSeen(onlineGameId?: string): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.rpc('mark_game_finishes_seen', {
    p_online_game_id: onlineGameId ?? null,
  });
  if (error) {
    console.error('[Kelimeki] markGameFinishesSeen hatası:', error.message);
    return false;
  }
  return true;
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
 * Skor kartındaki "Y:59/C:E" satırı için BAŞKA bir oyuncunun yaşını ve
 * cinsiyetini okur.
 *
 * Neden ayrı bir RPC: `profiles`in SELECT RLS'i kilitli — bir kullanıcı
 * yalnızca KENDİ satırını okuyabiliyor, ve başkasının kartını besleyen
 * kaynakların (k-lig view'ı, `list_friends`, `game_likers`, çevrimiçi oyun
 * oyuncuları, `admin_list_members`) hiçbiri bu iki alanı taşımıyor.
 *
 * ⚠ RPC ham `birth_date`i DEĞİL türetilmiş yaşı döndürür — kart yalnızca yaşı
 * gösteriyor, doğum GÜNÜNÜ yayınlamak gösterilenden fazla veri açardı.
 * Yaş tanımı `calculateAge` ile aynı ("tamamlanmış yıl").
 */
export async function fetchProfileAgeGender(
  userId: string,
): Promise<{ age: number | null; gender: Gender | null }> {
  const empty = { age: null, gender: null };
  if (!supabase) return empty;
  const { data, error } = await supabase.rpc('get_profile_age_gender', {
    p_user_id: userId,
  });
  if (error) {
    console.error('[Kelimeki] fetchProfileAgeGender hatası:', error.message);
    return empty;
  }
  const row = Array.isArray(data) ? data[0] : null;
  if (!row) return empty;
  return {
    age: row.age == null ? null : Number(row.age),
    gender: (row.gender as Gender | null) ?? null,
  };
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
  // `failed`: sorgu GERÇEKTEN başarısız oldu mu — boş listeden AYRI taşınır.
  // İkisi de `games: []` üretiyor ama kullanıcıya söylenecek şey farklı:
  // çevrimdışı birine "Henüz kayıtlı bir oyunun yok." demek, oyunlarının
  // silindiğini düşündürür (uygulama kurulabilir bir PWA olduğundan bu
  // gerçek bir senaryo — `cloudSaveMirror` işinde de aynı gerekçe kabul
  // edilmişti). `fetchGameBoardSnapshot`/`fetchGameMoves` bu ayrımı zaten
  // yapıyordu; 14 Ağustos 2026'da liste yoluna da uygulandı (önce mobil
  // portta bulundu, bkz. `mobile/CLAUDE.md` Parça 90).
  //
  // Supabase yapılandırılmamışsa ya da GERÇEKTEN oturum yoksa `failed` FALSE
  // kalır — onlar bir hata değil, uygulamanın bilinçli offline/misafir hâli.
): Promise<{ games: GameHistoryEntry[]; hasMore: boolean; failed: boolean }> {
  if (!supabase) return { games: [], hasMore: false, failed: false };
  // `getUser()` DEĞİL `getSession()` — 14 Ağustos 2026'da cihaz testinde
  // bulunan hata: `getUser()` her çağrıda `GET /auth/v1/user`'a gidiyor
  // (auth-js kaynağından doğrulandı), yani ÇEVRİMDIŞIYKEN `viewer` null
  // dönüyor. `ScoreCard` `userId` prop'u geçmediğinden `targetUid`
  // undefined kalıyor ve akış aşağıdaki erken dönüşe düşüp "hiç oyunun
  // yok" gösteriyordu — `failed` bayrağı devreye girmeden ÖNCE, yani bu
  // fonksiyonun asıl düzeltmesini tamamen atlatarak.
  //
  // `getSession()` oturumu YEREL depodan okuyor (ağ yok), ki burada
  // doğrusu da bu: uid yalnızca bir sorgu FİLTRESİ olarak kullanılıyor,
  // gerçek yetkilendirme sunucuda RLS'te — üstelik `fetchMyGames` zaten
  // dışarıdan keyfi bir `userId` kabul ediyor (başkasının kartı böyle
  // açılıyor), yani uid'nin doğrulanmış olması hiçbir zaman bir güvenlik
  // sınırı değildi. Yan fayda: her sayfa yüklemesinden bir ağ turu düştü.
  //
  // Ayrım artık kesin: misafirde `getSession()` hatasız `session: null`
  // döner (`failed: false` — doğru), süresi geçmiş bir token'ı çevrimdışı
  // tazeleyemediğinde ise hata döner (`failed: true` — o da doğru).
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
  const viewer = sessionData.session?.user ?? null;
  const targetUid = userId ?? viewer?.id;
  if (!targetUid) return { games: [], hasMore: false, failed: !!sessionError };

  // `ai_level` 6 Eylül 2026'dan beri seçiliyor (ROADMAP #23 Faz 1; SELECT
  // grant'i o migration'da verildi) — kartlar puanı bununla hesaplıyor
  // (Faz 3). Beğenilenler dalı (`list_liked_games`) da aynı gün döndürmeye
  // başladı (`20260906130756`), iki dal aynı `Row` şeklini paylaşıyor.
  const cols =
    'id, created_at, player_count, players, player_score, ai_score, rank, surrendered, online_game_id, user_id, ai_level';
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
      return { games: [], hasMore: false, failed: true };
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
      return { games: [], hasMore: false, failed: true };
    }
    const all = (data as Row[]) ?? [];
    rows = all.slice(0, limit);
    hasMore = all.length > limit;
  }

  // Kartın TÜM rozetleri tek toplu RPC'den geliyor (sayfa başına bir
  // gidiş-dönüş). `message_count` 10 Ağustos 2026'dan beri satırdan
  // okunAMIYOR: o kolon istemci rollerinden kaldırıldı, çünkü "X ile Y şu
  // oyunda N mesajlaştı" da bir üstveri ve rozet zaten yalnızca
  // katılımcının açabildiği bir kontroldü. RPC katılımcı/admin değilse 0
  // döner → rozet hiç çizilmez (bkz. `chat_count_participants_only`).
  // `has_moves` de buradan geliyor (12 Ağustos 2026): hamle dökümü
  // (`games.moves`) satır başına ~6.8 KB olduğundan liste sorgusuna
  // GİRMİYOR, ama ikonu çizip çizmeyeceğimize karar vermek için "var mı"
  // bilgisi lazım — RPC bunu `moves is not null` olarak döndürüyor, ek bir
  // gidiş-dönüş yok. `message_count`in aksine katılımcı kapısı YOK: `moves`
  // kolonunun kendisi zaten istemciye açık ve `board_snapshot`ın
  // anlattığından fazlasını söylemiyor.
  const stats = new Map<
    string,
    {
      likeCount: number;
      likedByMe: boolean;
      messageCount: number;
      hasMoves: boolean;
    }
  >();
  if (viewer && rows.length > 0) {
    const { data: likeStats } = await supabase.rpc('game_like_stats', {
      p_game_ids: rows.map((r) => r.id),
    });
    for (const s of (likeStats as {
      game_id: string;
      like_count: number;
      liked_by_me: boolean;
      message_count: number;
      has_moves: boolean;
    }[]) ?? []) {
      stats.set(s.game_id, {
        likeCount: Number(s.like_count),
        likedByMe: s.liked_by_me,
        messageCount: Number(s.message_count ?? 0),
        hasMoves: s.has_moves === true,
      });
    }
  }

  return {
    games: rows.map((r) => ({
      ...r,
      liked_by_me: stats.get(r.id)?.likedByMe ?? false,
      like_count: stats.get(r.id)?.likeCount ?? 0,
      message_count: stats.get(r.id)?.messageCount ?? 0,
      has_moves: stats.get(r.id)?.hasMoves ?? false,
    })),
    hasMore,
    failed: false,
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
 * Bir oyunun bitişteki tahta anlık görüntüsünü döner — `fetchMyGames`'in
 * liste sorgusuna DAHİL EDİLMEZ (satır başına birkaç KB'a varabildiğinden
 * sayfa yükünü şişirmesin diye); yalnızca `GameHistoryModal`'da bir oyuna
 * tıklanıp genişletildiğinde ayrıca çekilir. `null`
 * dönüşü "bu oyun için hiç kaydedilmemiş" anlamına gelir (eski kayıtlar).
 * Gerçek bir ağ/DB hatasında (önceden sessizce `null`'a düşüp "kaydedilmemiş"
 * ile ayırt edilemiyordu, kalıcı olarak retry edilemiyordu — bkz. kod
 * incelemesi) artık fırlatıyor; çağıran (`GameHistoryModal`) bunu ayrı bir
 * hata durumuyla ele alıp yeniden deneme imkânı sunuyor.
 */
export async function fetchGameBoardSnapshot(gameId: string): Promise<BoardSnapshotTile[] | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('games')
    .select('board_snapshot')
    .eq('id', gameId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data?.board_snapshot as BoardSnapshotTile[] | null) ?? null;
}

/**
 * Bir oyunun DONDURULMUŞ tam hamle dökümü — `fetchGameBoardSnapshot` ile
 * BİREBİR aynı desen: liste sorgusuna dahil değil (satır başına ~7 KB),
 * yalnızca hamle geçmişi ikonuna basılınca çekilip önbelleğe alınır.
 *
 * `null` = "bu oyun için hiç kaydedilmemiş" (kolon eklenmeden önce biten
 * yerel oyunlar — kurtarılamaz). Gerçek ağ/DB hatasında FIRLATIR ki çağıran
 * bunu "kaydedilmemiş"ten ayırıp yeniden deneme sunabilsin.
 *
 * Sohbetin (`fetchGameMessages`) aksine ayrı bir yetki kapısı YOK: hamleler
 * bir oyun verisi, kullanıcı yazışması değil — `board_snapshot`la aynı
 * sınıf ve aynı görünürlükte (bkz. `games_moves_snapshot` migration'ının
 * gizlilik notu).
 */
export async function fetchGameMoves(gameId: string): Promise<HistoryEntry[] | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('games')
    .select('moves')
    .eq('id', gameId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data?.moves as HistoryEntry[] | null) ?? null;
}

/** `fetchGameMessages` dönüşü — yetki bilgisi İÇERİKTEN ayrı taşınır ki UI
 *  "sohbet boş" ile "görme yetkin yok"u ayırt edebilsin. */
export interface GameChatArchive {
  allowed: boolean;
  messages: GameChatMessage[];
}

/**
 * Bitmiş bir Canlı oyunun dondurulmuş sohbet kaydını döner —
 * `fetchGameBoardSnapshot` ile birebir aynı desen: `fetchMyGames`'in liste
 * sorgusuna dahil edilmez (bkz. `message_count`), yalnızca `GameHistoryModal`
 * (sohbet rozetine tıklanınca `GameChatHistoryModal`) lazy çeker. Yerel/YZ
 * oyunlarında (Oyun İçi Mesajlaşma — Faz 1 kapsam dışı) her zaman boş döner.
 *
 * 10 Ağustos 2026'dan beri `games.messages` DOĞRUDAN OKUNAMIYOR: o kolon
 * istemci rollerinden kaldırıldı (`game_chat_archive_participants_only`
 * migration'ı), çünkü `games`in SELECT politikası satır sahipliğine değil
 * yalnızca "oturum var mı"ya bakıyor — k-lig → oyuncu kartı → "Tüm Oyunlar"
 * zincirinden (ya da doğrudan API'den) başkasının yazışmaları okunabiliyordu.
 * Okuma artık katılımcı/admin kapılı `game_chat_archive` RPC'sinden geçiyor.
 */
export async function fetchGameMessages(gameId: string): Promise<GameChatArchive> {
  if (!supabase) return { allowed: true, messages: [] };
  const { data, error } = await supabase.rpc('game_chat_archive', { p_game_id: gameId });
  if (error) {
    console.error('[Kelimeki] fetchGameMessages hatası:', error.message);
    return { allowed: true, messages: [] };
  }
  const row = data as { allowed?: boolean; messages?: GameChatMessage[] } | null;
  return { allowed: row?.allowed ?? false, messages: row?.messages ?? [] };
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
 *
 * Karşı taraftan zaten bekleyen bir istek varsa `handle_friend_request_insert`
 * trigger'ı insert'i doğrudan 'accepted'a çevirir — dönüş değeri bunu
 * çağırana bildirir ki (FriendsModal.tsx) UI "İstek Gönderildi" yerine
 * doğrudan "Arkadaşsınız" göstersin (önceden bu ayrım kaybolup her zaman
 * "pending_outgoing" gösteriliyordu, iki taraf zaten arkadaş olmuşken bile).
 */
export async function sendFriendRequest(targetId: string): Promise<'pending' | 'accepted'> {
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
  const status: 'pending' | 'accepted' = data?.status === 'accepted' ? 'accepted' : 'pending';
  if (status === 'pending') {
    void notifyFriendRequest(targetId);
  }
  return status;
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
// Adı "arkadaşlıktan çıkar" gibi dursa da aslında iki taraf arasındaki
// friend_requests satırını durumdan (accepted/pending) bağımsız siler —
// bu yüzden hem gerçek bir arkadaşlığı sonlandırmak (FriendsModal
// handleConfirmRemove) hem de HENÜZ kabul edilmemiş, kendi gönderdiğin bir
// isteği iptal etmek (FriendsModal handleConfirmCancel) için aynı fonksiyon
// kullanılıyor — isimlendirme kafa karıştırıcı olabilir ama bug değil.
export async function removeFriend(friendId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  assertUuid(friendId, 'kullanıcı kimliği');
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
  if (!UUID_RE.test(targetId)) return null;
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
    // `code` KORUNUYOR: `accept_friend_invite` üç durumu `raise exception`
    // ile bilerek reddediyor (kendi linki, geçersiz token, oturum yok) ve
    // plpgsql'in `raise exception`ı SQLSTATE **P0001** üretiyor (canlıda
    // ölçüldü). Çağıran bu koda bakarak "kalıcı ret" ile "geçici arıza"yı
    // ayırabiliyor — mesaj metnine bakmak yerine, çünkü metin değişebilir
    // (aynı gerekçe `mapAuthError`'da da yazılı).
    const hata = new Error(error.message) as Error & { code?: string };
    hata.code = error.code;
    throw hata;
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
 * Bu hata OTURUMUN DÜŞMÜŞ olmasından mı kaynaklanıyor? `authenticated`'e
 * kilitli bir RPC/tablo, geçerli bir JWT olmadan çağrılırsa PostgREST
 * `permission denied for function …` (42501) döner — yani rol `anon`
 * kalmıştır. Süresi geçmiş bir token, arka planda henüz tamamlanmamış bir
 * yenileme ya da başka bir sekmede yapılan çıkış bunu üretebilir.
 */
function isAuthStateError(err: { code?: string; message: string }): boolean {
  if (err.code === '42501' || err.code === 'PGRST301') return true;
  return /permission denied|jwt (expired|is invalid)|invalid claim/i.test(err.message);
}

/**
 * Oturum GERÇEKTEN var mı? `getSession()` yerel depodan okur, AĞA GİTMEZ
 * (auth-js kaynağından doğrulandı; `fetchMyGames`'in 14 Ağustos 2026
 * düzeltmesi de tam bu ayrım üzerineydi).
 */
async function hasValidSession(): Promise<boolean> {
  if (!supabase) return false;
  try {
    const { data, error } = await supabase.auth.getSession();
    if (error || !data.session) return false;
    const exp = (data.session as { expires_at?: number }).expires_at;
    return !exp || exp * 1000 > Date.now();
  } catch {
    return false;
  }
}

/**
 * Canlı liste ailesinin (üç çağrı yeri) ortak hata bildirimi.
 *
 * NEDEN GEREKLİ (23 Ağustos 2026, panelin ilk gerçek verisi): oturumu düşmüş
 * bir istemcide bu çağrılar `permission denied for function
 * list_my_online_games` üretiyor ve telemetriye "hata" olarak düşüyordu. Bu
 * bir BUG DEĞİL, beklenen bir auth durumu — kullanıcı zaten bir sonraki
 * `onAuthStateChange` olayında çıkış yapmış sayılacak.
 *
 * ⚠ AMA aynı mesaj GERÇEK bir dağıtım hatasının da yüzü olabilir: bir
 * fonksiyon `drop`+`create` edildikten sonra `grant` unutulursa oturumu olan
 * herkes aynı mesajı alır (bu projede bir kez yaşandı — bkz. CLAUDE.md,
 * `fix_withdraw_report_wrong_overload`). İkisini ayıran TEK şey oturumun
 * varlığıdır, mesaj değil: oturum VARKEN gelen bir "permission denied"
 * raporlanır, oturumsuz gelen elenir. Mesaja bakıp körlemesine filtrelemek
 * o hata sınıfını sessizce gizlerdi.
 */
function reportLiveListError(err: { code?: string; message: string }, context: string): void {
  if (!isAuthStateError(err)) {
    reportClientError(err.message, 'manual', context);
    return;
  }
  void hasValidSession().then((ok) => {
    if (ok) reportClientError(err.message, 'manual', context);
  });
}

/**
 * Oturum açan kullanıcının taraf olduğu (kurduğu ya da davet edildiği) tüm
 * Canlı oyunları döner (`list_my_online_games` RPC'si) — en yeni önce.
 */
export async function listMyOnlineGames(): Promise<OnlineGame[] | null> {
  // Yapılandırılmamış istemci bir HATA DEĞİL, uygulamanın bilinçli offline
  // hâli — `fetchMyGames`'in `failed:false` kararıyla aynı (14 Ağustos 2026).
  if (!supabase) return [];
  const client = supabase;
  const { data, error } = await retryOnNetworkFailure(() => client.rpc('list_my_online_games'));
  if (error) {
    console.error('[Kelimeki] listMyOnlineGames hatası:', error.message);
    reportLiveListError(error, 'list_my_online_games');
    // `null` = "bilmiyoruz", `[]` = "sunucu boş dedi". Bu ayrım olmadan
    // çağıran ikisini karıştırıp "Devam eden bir Canlı oyunun yok." basıyordu.
    return null;
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
 * BİTMİŞ bir Canlı oyunun koltuklarını (`online_games.slots`) döner —
 * oyun geçmişindeki "Tekrar Oyna" rövanş kadrosunu buradan kuruyor.
 *
 * NEDEN AYRI BİR OKUMA GEREKİYOR (4 Eylül 2026): geçmiş kaydının kendi
 * oyuncu anlık görüntüsü (`games.players` → `GamePlayerSnapshot`) yalnızca
 * `name`/`score`/`is_ai` taşıyor, **`user_id` YOK** — isim kimlik değil ve
 * `create_online_game` koltuk başına `user_id` istiyor. Biten oyunun
 * `online_games` satırı silinmediği için (canlıda 71 `finished` satır
 * ölçüldü) kadro oradan çözülebiliyor.
 *
 * RLS zaten kapıyı tutuyor (`online_games_select_party`): yalnızca oyunu
 * KURAN ya da davet edilmiş olan okuyabilir. Kabul edilmiş davet satırları
 * silinmediğinden (canlıda 91 `accepted`) davet edilen taraf da rövanş
 * açabiliyor — yani buton kurucuyla sınırlı değil.
 *
 * Erişim yoksa ya da satır gitmişse `null` döner; çağıran bunu "rövanş
 * kurulamadı" olarak gösterir, sessizce yutmaz.
 */
export async function fetchFinishedGameSlots(
  onlineGameId: string,
): Promise<OnlineGameSlot[] | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('online_games')
    .select('slots')
    .eq('id', onlineGameId)
    .maybeSingle();
  if (error) {
    console.error('[Kelimeki] fetchFinishedGameSlots hatası:', error.message);
    return null;
  }
  const slots = (data as { slots?: OnlineGameSlot[] } | null)?.slots;
  return Array.isArray(slots) && slots.length > 0 ? slots : null;
}

/**
 * Verilen aktif Canlı oyunların her biri için "sırası kimde" (`current`
 * koltuk indeksi) bilgisini tek sorguda döner — `LiveGamesTab`'ın "Sıra
 * sende" rozetini ve `Setup`'taki "Arkadaşınla" sekmesindeki bekleyen
 * sayısını hesaplamak için kullanılır. `online_game_states`e doğrudan okuma
 * (RPC değil) — RLS zaten yalnızca katılımcının erişebileceği satırları döner.
 */
export async function fetchOnlineGameTurns(gameIds: string[]): Promise<Record<string, number> | null> {
  if (!supabase || gameIds.length === 0) return {};
  const client = supabase;
  const { data, error } = await retryOnNetworkFailure(() =>
    client.from('online_game_states').select('online_game_id, current').in('online_game_id', gameIds),
  );
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameTurns hatası:', error.message);
    reportLiveListError(error, 'fetch_online_game_turns');
    // Boş harita dönmek "sıra kimde bilinmiyor"u "sıra rakipte"ye çeviriyordu
    // (`turns[g.id] === mySlotIndex(g)` false kalır) — listeden daha kötü bir
    // hata: kullanıcıya YANLIŞ bir gerçeklik anlatıp beklemesine yol açar.
    return null;
  }
  const map: Record<string, number> = {};
  for (const row of (data ?? []) as { online_game_id: string; current: number }[]) {
    map[row.online_game_id] = row.current;
  }
  return map;
}

/** `fetchOnlineGameGlances` çıktısındaki tek oyun — liste kartının "bakışta" gösterdikleri. */
export interface OnlineGameGlance {
  /** Sırası gelen oyuncunun zaman aşımı son tarihi (`turn_deadline`); state henüz kurulmadıysa null. */
  deadline: string | null;
  /**
   * Koltuk sırasıyla anlık puanlar (`players[].score`) — kartın avatar
   * şeridinin altındaki puan satırı (6 Eylül 2026, bkz. `utils/scoreLine.ts`).
   */
  scores: number[];
}

/**
 * Verilen aktif Canlı oyunların her biri için sırası gelen oyuncunun son
 * hamle tarihini (`turn_deadline`) ve koltuk sırasıyla anlık puanları
 * (`players[].score`) döner — `LiveGamesTab`'ın "kalan süre" göstergesi ve
 * kart altı puan satırı için. İkisi AYNI satırdan okunuyor, bu yüzden tek
 * sorgu (6 Eylül 2026'ya kadar yalnızca `turn_deadline` seçiliyordu; puan
 * satırı eklenirken ikinci bir `online_game_states` isteği açmak yerine
 * seçime `players` eklendi — `fetchOnlineGameTurns` zaten aynı tabloya
 * ayrı bir istek atıyor, üçüncüsü olmasın). Süre dolan bir koltuk
 * `check_turn_timeout` çağrılana kadar otomatik teslim olmaz (bkz.
 * `checkOnlineGameTurnTimeout`), bu fonksiyon yalnızca OKUR, hiçbir şeyi
 * tetiklemez.
 */
export async function fetchOnlineGameGlances(
  gameIds: string[],
): Promise<Record<string, OnlineGameGlance> | null> {
  if (!supabase || gameIds.length === 0) return {};
  const client = supabase;
  const { data, error } = await retryOnNetworkFailure(() =>
    client
      .from('online_game_states')
      .select('online_game_id, turn_deadline, players')
      .in('online_game_id', gameIds),
  );
  if (error) {
    console.error('[Kelimeki] fetchOnlineGameGlances hatası:', error.message);
    reportLiveListError(error, 'fetch_online_game_deadlines');
    return null;
  }
  const map: Record<string, OnlineGameGlance> = {};
  for (const row of (data ?? []) as {
    online_game_id: string;
    turn_deadline: string | null;
    players: { score?: number }[] | null;
  }[]) {
    map[row.online_game_id] = {
      deadline: row.turn_deadline,
      scores: (row.players ?? []).map((p) => (typeof p.score === 'number' ? p.score : 0)),
    };
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

/**
 * Bu oyunda ÇAĞIRANIN hangi istemciden oynadığını kaydeder
 * (`online_game_clients`, oyun+kullanıcı başına tek satır, upsert). Yerel
 * oyunlarda platformu `games.platform` taşıyor ama Canlı oyunlarda o satırı
 * SUNUCU (`_finish_online_game_records`) yazdığından istemcinin kim olduğu
 * oraya hiç ulaşmıyor — bu yüzden Canlı taraf ayrı bir tabloya, oyun
 * açılırken bir kez yazıyor (mobil lansmanı ölçülebilsin diye, 14 Ağustos
 * 2026).
 *
 * `submit_move`e bir parametre EKLENMEDİ bilinçli olarak: o, projenin en
 * kritik ve en uzun RPC'si ve lansman öncesi imzasını değiştirmenin riski
 * kazancından büyük. Ayrıca telemetri olduğundan tamamen fire-and-forget —
 * RPC yetkisiz/geçersiz girdide sessizce no-op döner (exception fırlatmaz),
 * burada da hata yalnızca loglanır: bir telemetri hatası hiçbir zaman oyunu
 * etkilemez.
 */
export async function setOnlineGamePlatform(gameId: string): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('set_online_game_platform', {
    p_game_id: gameId,
    p_platform: CLIENT_PLATFORM,
  });
  if (error) console.error('[Kelimeki] setOnlineGamePlatform hatası:', error.message);
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

// ── Oyun İçi Mesajlaşma — Faz 2: sessize alma / raporlama ─────────────────
// Sessize almak mesajı gizlemez (tüm sohbet herkese aynı kalır) — yalnızca
// "yeni mesaj" popup'ını/okunmamış rozetini o gönderen için bastırır (bkz.
// OnlineGameScreen.tsx). Rapor etmek otomatik olarak hedefi de sessize
// alır; ikisi de karşı tarafa hiçbir şekilde yansımaz (bkz. CLAUDE.md).

/**
 * Çağıranın sessize aldığı TÜM kullanıcı id'lerini döner (yalnızca kendi
 * kayıtları, RLS). Sorgu bilinçli olarak `online_game_id`'ye göre
 * FİLTRELENMİYOR: 3 Ağustos 2026'dan beri sessize alma kişi bazlı kalıcı bir
 * durum — bir kişiyi bir oyunda susturduysan onunla açtığın SONRAKİ
 * oyunlarda da susturulmuş kalır (bkz. `person_scoped_chat_moderation`
 * migration'ı). Satırlar hâlâ hangi oyunda başladığını taşır, yalnızca
 * kapsam kişiye taşındı.
 */
export async function fetchMyChatMutes(): Promise<Set<string>> {
  if (!supabase) return new Set();
  const { data, error } = await supabase
    .from('online_game_message_mutes')
    .select('muted_user_id');
  if (error) {
    console.error('[Kelimeki] fetchMyChatMutes hatası:', error.message);
    return new Set();
  }
  return new Set((data ?? []).map((r) => r.muted_user_id as string));
}

/**
 * Çağıranın AKTİF (geri çekilmemiş) rapor açtığı TÜM kullanıcı id'lerini
 * döner — bayrak rozeti bu sete bakar (mute tablosuna değil), çünkü rapor
 * geri çekilse bile mute bağımsız olarak sürebilir. `fetchMyChatMutes` ile
 * aynı gerekçeyle oyuna göre filtrelenmiyor: bir kişiyi rapor ettiysen
 * bayrak onunla oynadığın her oyunda görünür.
 */
export async function fetchMyActiveChatReports(): Promise<Set<string>> {
  if (!supabase) return new Set();
  const { data, error } = await supabase
    .from('online_game_chat_reports')
    .select('reported_user_id')
    .is('withdrawn_at', null);
  if (error) {
    console.error('[Kelimeki] fetchMyActiveChatReports hatası:', error.message);
    return new Set();
  }
  return new Set((data ?? []).map((r) => r.reported_user_id as string));
}

/**
 * Biten bir oyunun sohbet ARŞİVİ (`GameChatHistoryModal`) için: çağıranın o
 * oyundaki hangi RENK İNDEKSİNDEKİ oyuncuyu sessize aldığı/rapor ettiği.
 * Dondurulmuş `games.messages` satırları bilerek `sender_user_id`
 * taşımadığından (girişli herkes okuyabildiği için, bkz. `GameChatMessage`)
 * kimlik istemciye hiç gelmiyor — RPC doğrudan cevabı, yani renk indeksi
 * bazında bayrakları döndürüyor. Katılımcı olmayan biri (ör. başkasının
 * beğendiği bir oyunu açan) boş liste alır.
 */
export async function fetchFinishedGameChatFlags(
  onlineGameId: string,
): Promise<{ muted: Set<number>; reported: Set<number> }> {
  const empty = { muted: new Set<number>(), reported: new Set<number>() };
  if (!supabase) return empty;
  const { data, error } = await supabase.rpc('chat_flags_for_finished_game', {
    p_online_game_id: onlineGameId,
  });
  if (error) {
    console.error('[Kelimeki] fetchFinishedGameChatFlags hatası:', error.message);
    return empty;
  }
  const rows = (data ?? []) as { color_index: number; muted: boolean; reported: boolean }[];
  return {
    muted: new Set(rows.filter((r) => r.muted).map((r) => r.color_index)),
    reported: new Set(rows.filter((r) => r.reported).map((r) => r.color_index)),
  };
}

/** Bir katılımcıyı sessize alır/sessizden çıkarır (RPC: atomik, katılımcı kontrolü sunucuda). */
/**
 * Arkadaş listesinden moderasyon durumunu yönetebilmek için: sessize
 * alınan/şikayet edilen her kişi için bir de **kaynak oyun id'si** döndürür.
 *
 * NEDEN GAME ID GEREKİYOR (14 Ağustos 2026, kullanıcı isteğiyle eklendi):
 * `mute_online_game_participant` katılımcılık kontrolünü (`is_online_game_
 * participant`) `p_muted` dalından ÖNCE yapıyor — yani SESSİZDEN ÇIKARMA
 * bile geçerli bir ortak oyun id'si istiyor. Arkadaş listesinde böyle bir
 * bağlam yok; ama mute/rapor satırının KENDİSİ `online_game_id` taşıyor ve
 * o satır ancak ikisi de o oyunun katılımcısıyken yazılabildiğinden
 * (RPC insert'te zorluyor) provenance olarak kullanılabilir. Sunucuda
 * hiçbir değişiklik gerekmiyor.
 *
 * `fetchMyChatMutes`/`fetchMyActiveChatReports` (yalnızca id kümesi
 * döndüren, oyun ekranının kullandığı sürümler) BİLEREK dokunulmadan
 * duruyor — orada oyun id'si zaten elde.
 */
export async function fetchMyChatModeration(): Promise<{
  muted: Map<string, string>;
  reported: Map<string, string>;
}> {
  const empty = { muted: new Map<string, string>(), reported: new Map<string, string>() };
  if (!supabase) return empty;
  const [m, r] = await Promise.all([
    supabase.from('online_game_message_mutes').select('muted_user_id, online_game_id'),
    supabase
      .from('online_game_chat_reports')
      .select('reported_user_id, online_game_id')
      .is('withdrawn_at', null),
  ]);
  if (m.error) console.error('[Kelimeki] fetchMyChatModeration (mutes) hatası:', m.error.message);
  if (r.error) console.error('[Kelimeki] fetchMyChatModeration (reports) hatası:', r.error.message);
  const muted = new Map<string, string>();
  for (const row of (m.data ?? []) as { muted_user_id: string; online_game_id: string }[]) {
    if (!muted.has(row.muted_user_id)) muted.set(row.muted_user_id, row.online_game_id);
  }
  const reported = new Map<string, string>();
  for (const row of (r.data ?? []) as { reported_user_id: string; online_game_id: string }[]) {
    if (!reported.has(row.reported_user_id)) reported.set(row.reported_user_id, row.online_game_id);
  }
  return { muted, reported };
}

export async function setChatMute(gameId: string, targetUserId: string, muted: boolean): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('mute_online_game_participant', {
    p_game_id: gameId,
    p_target_user_id: targetUserId,
    p_muted: muted,
  });
  if (error) throw new Error(error.message);
}

/** Bir katılımcıyı admine rapor eder (aynı zamanda otomatik sessize alır — bkz. RPC gövdesi). */
export async function reportChatParticipant(gameId: string, targetUserId: string, reason: string): Promise<void> {
  if (!supabase) return;
  const trimmed = reason.trim();
  if (trimmed.length === 0 || trimmed.length > 500) {
    throw new Error('Rapor nedeni 1-500 karakter arasında olmalı.');
  }
  const { error } = await supabase.rpc('report_online_game_participant', {
    p_game_id: gameId,
    p_target_user_id: targetUserId,
    p_reason: trimmed,
  });
  if (error) throw new Error(error.message);
}

/**
 * Bir kişiye karşı açık TÜM raporları geri çeker — hangi oyunda açıldığından
 * bağımsız (tek RPC, hepsi birden). Bayrak 3 Ağustos 2026'dan beri kişi
 * bazlı olduğundan yalnızca içinde bulunulan oyunun raporunu geri çekmek onu
 * söndürmezdi; RPC de bu yüzden artık `p_game_id` almıyor (yalnızca
 * çağıranın KENDİ raporlarına dokunduğundan bir oyun bağlamına ihtiyacı yok).
 */
export async function withdrawChatReports(targetUserId: string): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('withdraw_online_game_chat_reports', {
    p_target_user_id: targetUserId,
  });
  if (error) throw new Error(error.message);
}

/**
 * `online_games`/`game_invites`/`online_game_states`'teki HERHANGİ bir
 * değişiklikte `onChange`'i tetikler (Realtime) — LiveGamesTab'ın liste/rozet
 * verisini (davet gönderildi/kabul edildi/reddedildi, oyun active'e geçti,
 * sıra ilerledi vb.) yeniden çekmesi için.
 *
 * **`online_game_states` 4 Ağustos 2026'da eklendi:** öncesinde yalnızca ilk
 * iki tablo dinleniyordu, ama `submit_move` normal bir hamlede `online_games`'e
 * HİÇ dokunmuyor (yalnızca oyun bitince `status='finished'` yazıyor) — yani
 * "rakip oynadı, sıra sana geçti" hiçbir Realtime olayı üretmiyordu. Sonuç:
 * Setup'taki "Arkadaşınla (N)" rozeti sıra kullanıcıya geçtiğinde
 * güncellenmiyor, ancak foreground'a dönüş/yeniden mount ile düzeliyordu;
 * PWA ikon rozeti ise kendi 10 dakikalık interval'i sayesinde er geç
 * yakaladığından ikisi görünür şekilde ayrışıyordu. Tablo zaten
 * `supabase_realtime` publication'ındaydı (`online_game_states_realtime`
 * migration'ı), ek bir migration gerekmedi.
 *
 * Bu ekleme olay hacmini artırdığından (taraf olunan her oyundaki her hamle)
 * TÜM tüketiciler `onChange`'i debounce etmeli — LiveGamesTab baştan beri
 * ediyordu, Setup ve useAppIconBadge'e aynı 300ms'lik desen bu değişiklikle
 * eklendi.
 *
 * `subscribeOnlineGameState`'in aynı deseni, ama tek bir
 * oyuna değil çağıranın TARAF OLDUĞU tüm oyunlara bağlı olduğundan bir
 * `filter` verilmiyor — RLS (`online_games_select_party`/
 * `game_invites_select_party`) zaten yalnızca kendi satırlarını yayınlar,
 * postgres_changes bunu normal select gibi uyguluyor. Dönen fonksiyon
 * aboneliği iptal eder — bileşen unmount olduğunda çağrılmalı.
 *
 * **TEK KANAL, ÇOK DİNLEYİCİ (5 Eylül 2026 — performans geçişi).** Bu
 * fonksiyonun ÜÇ çağıranı var ve üçü aynı anda canlı olabiliyor: `Setup`
 * ("Arkadaşınla (N)" rozeti), `LiveGamesTab` (liste) ve `useAppIconBadge`
 * (uygulama ikonu rozeti). Öncesinde her çağrı KENDİ kanalını açıyordu
 * (`crypto.randomUUID` ile benzersiz ad) — yani tek bir kullanıcı için
 * 3 kanal × 3 tablo = **9 ayrı Realtime aboneliği**.
 *
 * Bedeli ölçüldü: sunucuda WAL'daki her satır değişikliği, o değişikliği
 * gören HER abonelik için ayrı ayrı RLS'ten geçiriliyor
 * (`realtime.apply_rls`) ve bu tek başına veritabanının toplam yürütme
 * süresinin **%75,8'i** (`pg_stat_statements`, 69 günlük pencere:
 * 3,38 M çağrı / 18.327 s). Yani abonelik sayısı doğrudan çarpan.
 *
 * Çözüm çağıranları DEĞİŞTİRMİYOR: imza ve dönen "iptal et" fonksiyonu
 * aynı kaldı, kanal içeride referans sayımıyla paylaşılıyor. Sonuç 9 → 3
 * abonelik. Kanal adı yine benzersiz (sabit ad, oturum kapanıp yeniden
 * açıldığında eski topic'e çarpabilirdi) ama artık kullanıcı başına BİR
 * tane üretiliyor.
 */
type MyGamesListener = { onChange: () => void; onResubscribe?: () => void };

let myGamesChannel: RealtimeChannel | null = null;
const myGamesListeners = new Set<MyGamesListener>();

export function subscribeMyOnlineGames(
  onChange: () => void,
  onResubscribe?: () => void,
): () => void {
  if (!supabase) return () => {};
  const client = supabase;
  const listener: MyGamesListener = { onChange, onResubscribe };
  myGamesListeners.add(listener);

  if (!myGamesChannel) {
    // İLK `SUBSCRIBED` atlanır, 2.'den itibaren `onResubscribe` çağrılır.
    //
    // NEDEN (21 Ağustos 2026): Ağ değişiminin en doğrudan sinyali soketin
    // kopup yeniden bağlanmasıdır — IP değişince websocket düşer, kütüphane
    // yeniden bağlanır. O aralıkta yayınlanan olaylar KALICI OLARAK kaybolur
    // (Realtime canlı bir akış, kuyruk değil), yani yeniden bağlanma anı tam
    // olarak "gerçeği yeniden oku" anıdır — projenin `useOnlineStatus`/sohbet/
    // bulut senkronunda üç kez öğrendiği aynı ders. İlk aboneliği atlamak
    // şart: o, mount'taki `loadGames`in hemen ardından gelir ve aynı isteği
    // ikinci kez attırırdı.
    //
    // Paylaşılan kanalda bu kural DİNLEYİCİ başına değil KANAL başına
    // işliyor ve doğrusu bu: kanal zaten bağlıyken katılan bir dinleyici
    // (ör. `LiveGamesTab` sonradan açıldığında) kendi ilk yüklemesini
    // mount'ta zaten yapıyor — ona "yeniden bağlandık, tazele" demek o
    // isteği ikinci kez attırırdı. Soket gerçekten kopup döndüğünde ise
    // O ANDAKİ tüm dinleyiciler haber alır.
    let subscribedOnce = false;
    const fanOut = () => {
      for (const l of myGamesListeners) l.onChange();
    };
    myGamesChannel = client
      .channel(`my_online_games_${crypto.randomUUID()}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'online_games' }, fanOut)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'game_invites' }, fanOut)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'online_game_states' }, fanOut)
      .subscribe((status) => {
        if (status !== 'SUBSCRIBED') return;
        if (subscribedOnce) for (const l of myGamesListeners) l.onResubscribe?.();
        subscribedOnce = true;
      });
  }

  return () => {
    myGamesListeners.delete(listener);
    if (myGamesListeners.size > 0 || !myGamesChannel) return;
    const channel = myGamesChannel;
    myGamesChannel = null;
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
  // `invokeEdgeFunction` (diğer tüm Edge Function çağrılarının kullandığı
  // ortak sarmalayıcı) `play-ai-turn`'ün döndürdüğü gerçek hata gövdesini
  // okuyup fırlatır — önceden burada doğrudan `supabase.functions.invoke`
  // kullanılıp yalnızca jenerik "Edge Function returned a non-2xx status
  // code" loglanıyordu, asıl hata (RLS reddi, oyun bulunamadı vb.) hiç
  // görünmüyordu (bkz. kod incelemesi). Çağıran (OnlineGameScreen) zaten
  // kendi `.catch()`'iyle bu reddi ele alıyor.
  const data = await invokeEdgeFunction<{ played?: boolean } | null>('play-ai-turn', { game_id: gameId });
  return { played: !!data?.played };
}

/**
 * Kelimeyi sunucu tarafında doğrular (is_valid_word RPC). Supabase
 * yapılandırılmamışsa null döner; çağıran yerel sözlüğe düşmelidir.
 */
export async function isValidWordRemote(word: string): Promise<boolean | null> {
  if (!supabase) return null;
  // fetchMeaning ile tutarlı olsun diye normalizasyon burada da (çağıranın
  // önceden trLower yapmış olmasına güvenmeden) uygulanıyor — idempotent,
  // mevcut çağrı yerlerinin (zaten trLower'lı geçiyorlar) davranışını değiştirmez.
  const { data, error } = await supabase.rpc('is_valid_word', {
    p_word: trLower(word),
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

/**
 * Tüm kayıtlı kullanıcıları döner (yalnızca is_admin=true için, RPC içinde
 * kontrol edilir) — sayfalama yok, arama/sıralama client-side. Kod
 * incelemesinde ("Orta" bulgu) bilinçli olarak ertelendi: bu yazıldığı anda
 * yalnızca ~20 kayıtlı kullanıcı/~7 geri bildirim var, sunucu tarafı
 * sayfalama (RPC imza değişikliği + CSV export'un "ekranda görüneni indir"
 * semantiğini bozması riskiyle) şu an gerçek bir sorunu çözmeyen erken bir
 * optimizasyon olurdu. Hacim gerçekten büyüyünce (ör. yüzlerce satır) aynı
 * desenle (fetchOnlineGameTurns'teki gibi offset/limit) eklenmeli.
 */
export async function fetchAdminMembers(): Promise<AdminMember[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_list_members');
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  return (data as AdminMember[]) ?? [];
}

/**
 * Bir kullanıcı hesabını devre dışı bırakır/aktif eder (yalnızca admin —
 * `admin_set_user_banned` RPC'si, `auth.users.banned_until`'ı günceller).
 * Devre dışı bırakılan kullanıcı bir sonraki giriş/token yenilemede
 * reddedilir; hâlâ geçerli olan kısa ömürlü access token'lar süresi
 * dolana kadar çalışmaya devam edebilir (Supabase Auth'un standart ban
 * davranışı, anlık oturum kesme kapsam dışı).
 */
export async function setUserBanned(userId: string, banned: boolean): Promise<void> {
  if (!supabase) return;
  const { error } = await supabase.rpc('admin_set_user_banned', { p_user_id: userId, p_banned: banned });
  if (error) throw new Error(error.message);
  // Her iki yönde de bir bildirim e-postası gönderilir — dondurulan kişi
  // giriş yapamadığından hesabının donduğunu/tekrar açıldığını yalnızca
  // bu mailden öğrenebilir.
  if (banned) {
    void notifyAccountBanned(userId);
  } else {
    void notifyAccountUnbanned(userId);
  }
}

/**
 * `setUserBanned(true)`'un az önce dondurduğu hesaba, süresiz dondurulduğunu
 * bildiren bir e-posta gönderir (`notify-account-banned` Edge Function'ı).
 * Best-effort/fire-and-forget: hesap zaten dondurulmuş olduğundan bir
 * e-posta hatası admin'e hiç yansıtılmaz, yalnızca loglanır.
 */
async function notifyAccountBanned(userId: string): Promise<void> {
  if (!supabase) return;
  try {
    await invokeEdgeFunction('notify-account-banned', { user_id: userId });
  } catch (err) {
    console.error('[Kelimeki] notifyAccountBanned hatası:', (err as Error).message);
  }
}

/**
 * `setUserBanned(false)`'un az önce dondurmasını kaldırdığı hesaba, hesabın
 * tekrar aktif olduğunu bildiren bir e-posta gönderir (`notify-account-unbanned`
 * Edge Function'ı) — dondurulmuş kişi giriş yapamadığından itirazını yalnızca
 * genel "Görüş Bildir" formundan iletebiliyor, admin haklı bulup dondurmayı
 * kaldırdığında bunu bir e-postayla öğrenmesi gerekiyor. Best-effort/
 * fire-and-forget, aynı hata toleransı.
 */
async function notifyAccountUnbanned(userId: string): Promise<void> {
  if (!supabase) return;
  try {
    await invokeEdgeFunction('notify-account-unbanned', { user_id: userId });
  } catch (err) {
    console.error('[Kelimeki] notifyAccountUnbanned hatası:', (err as Error).message);
  }
}

/**
 * Bir üyenin (oynadığı oyunlar HARİÇ) kritik hesap geçmişini kronolojik
 * (en yeni önce) döner — Admin Paneli > Üyeler > skor kartının en
 * altındaki "Kayıtlar" bölümü (`admin_get_member_activity_log` RPC'si).
 */
export async function fetchAdminMemberActivityLog(userId: string): Promise<AdminMemberActivityLogRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_get_member_activity_log', { p_user_id: userId });
  if (error) {
    console.error('[Kelimeki] fetchAdminMemberActivityLog hatası:', error.message);
    return [];
  }
  return (data as AdminMemberActivityLogRow[]) ?? [];
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
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
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
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
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
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
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
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  const row = (data as AdminEngagementTotals[] | null)?.[0];
  return row ?? null;
}

/**
 * YZ zorluk dengesi: yerel (Yapay Zeka'ya karşı) oyunlarda insanın
 * kazanma/berabere/kaybetme dağılımı, oyuncu sayısı bazında (yalnızca
 * admin — Büyüme > Oyun). Teslim satırları hariç; ayrıntı ve okuma
 * referansı için bkz. `AdminAiBalanceRow`.
 */
export async function fetchAdminAiBalance(): Promise<AdminAiBalanceRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_ai_balance');
  if (error) {
    // Diğer admin fetcher'larıyla aynı sözleşme: hatayı YUTMA, panelin
    // .catch(setError) zincirine bırak.
    throw new Error(error.message);
  }
  return (data as AdminAiBalanceRow[] | null) ?? [];
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
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
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
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  const row = (data as AdminFriendTotals[] | null)?.[0];
  return row ?? null;
}

/**
 * Aktif oyuncu serisi (yalnızca admin — Büyüme > Kullanıcı): kova içi benzersiz
 * aktif üye + kovanın sonunda biten 28 günlük yuvarlanan pencere. "Aktif"in
 * tanımı ve bunun neden bilerek "MAU" olmadığı: `AdminActivePlayersPoint`.
 */
export async function fetchAdminActivePlayersSeries(
  periods: number,
  granularity: AdminActivityGranularity,
): Promise<AdminActivePlayersPoint[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_active_players_series', {
    p_periods: periods,
    p_granularity: granularity,
  });
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // hata yutulursa admin gerçek bir RPC/izin hatasını asla göremez.
    throw new Error(error.message);
  }
  return (data as AdminActivePlayersPoint[]) ?? [];
}

/**
 * Retention kohortları (yalnızca admin — Büyüme > Kullanıcı): kayıt haftasına
 * göre, uzun (long) biçimde hücreler. Yalnızca TAMAMLANMIŞ haftalar döner —
 * gerekçesi `AdminRetentionCell`'de.
 */
export async function fetchAdminRetentionCohorts(cohorts = 8): Promise<AdminRetentionCell[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_retention_cohorts', { p_cohorts: cohorts });
  if (error) {
    throw new Error(error.message);
  }
  return (data as AdminRetentionCell[]) ?? [];
}

/**
 * Aktivasyon istatistikleri (yalnızca admin — Büyüme > Kullanıcı): kaç üye hiç
 * oyun bitirmemiş ve ilk oyuna kadar ne kadar sürmüş. Aktivasyonun aktif
 * oyuncudan neden FARKLI tanımlı olduğu: `AdminActivationStats`.
 */
export async function fetchAdminActivationStats(): Promise<AdminActivationStats | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('admin_activation_stats');
  if (error) {
    throw new Error(error.message);
  }
  const row = (data as AdminActivationStats[] | null)?.[0];
  return row ?? null;
}

/**
 * İstemci hata telemetrisinin gruplanmış dökümü (yalnızca admin — Hatalar
 * sekmesi, ROADMAP #3). Ayrıntılı sözleşme: `AdminClientErrorRow`.
 */
export async function fetchAdminClientErrors(
  days = 7,
  platform: ClientPlatform | null = null,
): Promise<AdminClientErrorRow[]> {
  if (!supabase) return [];
  // Platform elemesi SUNUCUDA (ROADMAP #11): satırlar (kind, message) ile
  // gruplandığından ve `platforms` bir `string_agg` olduğundan, burada
  // elemek `occurrences`/`devices` sayılarını öteki platformları da içerdiği
  // hâlde bırakırdı — panelin bütün değeri o iki sayı.
  const { data, error } = await supabase.rpc('admin_client_errors', {
    p_days: days,
    p_platform: platform,
  });
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor — hatayı
    // yutup boş dizi dönmek gerçek bir RPC/izin hatasını gizlerdi.
    throw new Error(error.message);
  }
  return (data as AdminClientErrorRow[]) ?? [];
}

/**
 * Kaynak hunisi: son `days` gün içinde kaynak başına kişi → üye → oyun
 * (yalnızca admin — Büyüme > Kullanıcı). `admin_guest_source_breakdown`
 * RPC'sinin yerini aldı (o RPC veritabanında duruyor ama artık çağrılmıyor); ilk sütun onunla AYNI sayıyı taşır, üzerine iki adım ekler.
 * Ayrıntılı sözleşme: `AdminSourceFunnelRow`.
 */
export async function fetchAdminSourceFunnel(days = 30): Promise<AdminSourceFunnelRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_source_funnel', { p_days: days });
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor — hatayı
    // yutup boş dizi dönmek gerçek bir RPC/izin hatasını gizlerdi.
    throw new Error(error.message);
  }
  return (data as AdminSourceFunnelRow[]) ?? [];
}

/**
 * Son `days` gün içinde cihaz tipi (mobil/masaüstü) başına benzersiz
 * MİSAFİR (girişsiz) ziyaretçi sayısını döner (yalnızca admin).
 *
 * 24 Ağustos 2026'dan beri admin panelindeki "Cihaz" tablosu bunu ÇAĞIRMIYOR
 * — o artık `fetchAdminDeviceBreakdown`'a (girişli+girişsiz tümü) geçti.
 * Bu fonksiyon/RPC BİLEREK SİLİNMEDİ (`fetchAdminPlatformBreakdown`'ın
 * "kod duruyor, çağrılmıyor" hâliyle aynı desen) — `guest_visits.device_type`
 * hâlâ yazılıyor ve ileride yalnızca misafir tarafını görmek gerekirse hazır.
 */
export async function fetchAdminGuestDeviceBreakdown(days = 30): Promise<AdminGuestDeviceRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_guest_device_breakdown', { p_days: days });
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  return (data as AdminGuestDeviceRow[]) ?? [];
}

/**
 * Son `days` gün içinde cihaz tipi (iOS/Android/masaüstü) başına benzersiz
 * ziyaretçi sayısını döner — GİRİŞLİ VE GİRİŞSİZ tüm ziyaretleri kapsar
 * (yalnızca admin — Büyüme > Kullanıcı "Cihaz" tablosu). `device_visits`
 * tablosundan okur; `fetchAdminGuestDeviceBreakdown`'ın (misafir-only)
 * yerini 24 Ağustos 2026'da bu aldı.
 */
export async function fetchAdminDeviceBreakdown(days = 30): Promise<AdminDeviceBreakdownRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_device_breakdown', { p_days: days });
  if (error) {
    throw new Error(error.message);
  }
  return (data as AdminDeviceBreakdownRow[]) ?? [];
}

/**
 * Son `days` günde YEREL oyun açan istemcilerin sürüm dökümü (yalnızca
 * admin — Büyüme > Kullanıcı). `app_config.mobile_min_supported_version`
 * eşiğini yükseltmenin güvenli olup olmadığını gösteren tek veri.
 */
export async function fetchAdminAppVersionBreakdown(days = 30): Promise<AdminAppVersionRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_app_version_breakdown', { p_days: days });
  if (error) {
    throw new Error(error.message);
  }
  return (data as AdminAppVersionRow[]) ?? [];
}

/**
 * Son `days` günde uygulamayı AÇAN kişilerin sürüm dökümü (yalnızca admin —
 * Büyüme > Kullanıcı).
 *
 * `fetchAdminAppVersionBreakdown`in YERİNE geçmiyor, YANINA geliyor; ikisi
 * farklı soru cevaplıyor ve kapsamları da farklı:
 *   · o     → "hangi sürümden kaç OYUN açıldı" (misafir dahil, izin
 *              gerekmez, ama yalnızca YEREL oyunlar)
 *   · bu    → "hangi sürümde kaç KİŞİ var" (giriş + bildirim izni gerekir,
 *              ama oyun oynamak gerekmez)
 *
 * Pencere `push_tokens.updated_at`e bakıyor; token her açılışta
 * hizalandığından bu fiilen "son N günde uygulamayı açan kişi" demek.
 */
export async function fetchAdminPushVersionBreakdown(days = 30): Promise<AdminPushVersionRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_push_version_breakdown', { p_days: days });
  if (error) {
    throw new Error(error.message);
  }
  return (data as AdminPushVersionRow[]) ?? [];
}

/**
 * Son `days` günde biten oyunların istemci (platform) dökümü — kaç oyun ve
 * kaç ayrı üye (yalnızca admin — Büyüme > Kullanıcı).
 *
 * İki kaynaktan çözülüyor: yerel oyunlarda `games.platform` (istemci
 * yazıyor), Canlı oyunlarda `online_game_clients` (o satırı sunucu
 * yazdığından istemcinin kim olduğu oraya ulaşmıyor). Kolondan önce biten
 * oyunlar `'bilinmiyor'` olarak toplanır.
 *
 * ŞU AN HİÇBİR YERDEN ÇAĞRILMIYOR (15 Ağustos 2026) — ölü kod DEĞİL,
 * bilinçli bir bekleme: admin panelindeki "Platform" tablosu kaldırıldı
 * (kolon 14 Ağustos'ta eklendiğinden oyunların ezici çoğunluğu hâlâ
 * "Bilinmiyor"du), ama VERİ TOPLAMA sürüyor. Uygulamalar mağazaya çıkınca
 * döküm web/iOS/Android/diğer olarak yeniden yapılandırılıp bu sarmalayıcı
 * tekrar bağlanacak. Silmeden önce o karara bak.
 */
export async function fetchAdminPlatformBreakdown(days = 30): Promise<AdminPlatformRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_platform_breakdown', { p_days: days });
  if (error) throw new Error(error.message);
  return (data as AdminPlatformRow[]) ?? [];
}

/**
 * Son `days` gün içinde ana ekrana eklenip eklenmediğine (standalone) göre
 * benzersiz misafir ziyaretçi sayısını döner (yalnızca admin — Büyüme >
 * Kullanıcı).
 *
 * ŞU AN HİÇBİR YERDEN ÇAĞRILMIYOR (15 Ağustos 2026) — "Ana Ekrana Ekleme"
 * tablosu kullanıcı kararıyla kaldırıldı. Gerekçe metrik değil YAPISAL:
 * `guest_visits` yalnızca GİRİŞSİZKEN yazılıyor (RLS insert'i yalnız `anon`
 * rolüne açık), oysa PWA'yı ana ekrana ekleyenler tipik olarak girişli
 * kullanıcılar — yani bu döküm hedef kitleyi hiçbir zaman ölçemezdi.
 * Doğru ölçüm, kurulum bilgisini girişli kullanıcı için de kaydetmeyi
 * gerektirir; o da yeni bir kişisel veri alanı demek, `PrivacyModal` ile
 * birlikte ayrıca karara bağlanmalı. `is_standalone` yazılmaya devam ediyor.
 */
export async function fetchAdminGuestStandaloneBreakdown(days = 30): Promise<AdminGuestStandaloneRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_guest_standalone_breakdown', { p_days: days });
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  return (data as AdminGuestStandaloneRow[]) ?? [];
}

/**
 * Tüm geri bildirim mesajlarını döner (RLS: yalnızca is_admin=true
 * okuyabilir) — sayfalama yok, bkz. `fetchAdminMembers`'daki aynı gerekçe
 * (bilinçli erteleme notu).
 */
export async function fetchAdminFeedback(): Promise<AdminFeedbackRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('feedback')
    .select(
      'id, user_id, email, message, handled, created_at, source, reply, replied_at, replied_by, origin, subject, related_to',
    )
    .order('created_at', { ascending: false });
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  return (data as AdminFeedbackRow[]) ?? [];
}

// ── destek@ kutusu ("Zoho" rozeti) ──────────────────────────────────────────
//
// Bunlar bir posta kutusu API'si DEĞİL. `destek@kelimeki.com`'a gelen cevaplar
// Zoho'da okunur; `support_inbox` yalnızca "yeni cevap var" haberini taşır
// (gövde saklanmaz — bkz. migration ve `inbound-email` Edge Function'ı).
// Rozet bu sayaca, tıklama da Zoho'ya gider.

/**
 * Admin'in henüz "Zoho" rozetine tıklamadığı (yani `seen_at` boş) gelen cevap
 * sayısı. Hata YUTULMUYOR — `fetchAdminFeedback`'teki aynı gerekçe: sessizce
 * 0 dönmek, gerçek bir izin/RPC hatasını "kutu boş" gibi gösterirdi.
 */
export async function fetchSupportInboxUnseenCount(): Promise<number> {
  if (!supabase) return 0;
  const { count, error } = await supabase
    .from('support_inbox')
    .select('id', { count: 'exact', head: true })
    .is('seen_at', null);
  if (error) throw new Error(error.message);
  return count ?? 0;
}

/**
 * Bekleyen tüm satırları "görüldü" işaretler — admin rozete tıklayıp Zoho'ya
 * gittiği an çağrılır.
 *
 * ⚠ "Görüldü" burada "Zoho'da OKUNDU" demek DEĞİL, "admin'e haber verildi"
 * demek: kutunun gerçek okunmuşluk durumunu Zoho biliyor, biz bilemeyiz.
 * Rozetin işi bir kez dürtmek; ikinci kez dürtmesi gürültü olurdu.
 */
export async function markSupportInboxSeen(): Promise<void> {
  if (!supabase) return;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { error } = await supabase
    .from('support_inbox')
    .update({ seen_at: new Date().toISOString(), seen_by: user?.id ?? null })
    .is('seen_at', null);
  if (error) throw new Error(error.message);
}

/**
 * Admin'i bekleyen işlerin toplam sayısını döner — `UserMenu`'deki "Admin
 * Paneli" satırının yanındaki kırmızı rozet için. ÜÇ kaynağın toplamı:
 * okunmamış geri bildirim (`feedback`, "Gelen Kutusu") + okunmamış şikayet
 * (`online_game_chat_reports`, "Şikayetler") + haber verilmemiş destek cevabı
 * (`support_inbox`, "Zoho"), yani paneldeki üç sayacın toplamı. İki filtre de `AdminDashboard`'daki
 * `unhandledFeedbackCount`/`chatReports.filter(r => !r.handled)` ile BİREBİR
 * aynı (`handled=false`) — rozetteki sayı ile panelin içindeki sayılar hiçbir
 * zaman ayrışmamalı. Admin'in KENDİ gönderdiği mesajlar (`origin='admin'`)
 * `handled: true` ile eklendiğinden doğal olarak sayılmıyor. Geri çekilen
 * şikayetler ise sayılmaya DEVAM ediyor (4 Ağustos 2026,
 * `withdraw_report_keeps_unhandled` migration'ı) — geri çekme raporlayanın
 * kararıdır, admin'in incelemesi yerine geçmez; admin ne olduğunu görüp
 * kendi iradesiyle okundu işaretlemeli.
 *
 * `fetchAdminFeedback`/`fetchAdminChatReports` tüm satırları çektiğinden,
 * yalnızca bir sayı için onları çağırmak (menü her açıldığında tüm geçmişi
 * indirmek) gereksiz olurdu; bu yüzden `head: true` ile yalnızca `count`
 * isteniyor, hiç satır gövdesi dönmüyor.
 *
 * **Yalnızca admin için çağrılmalı** (`UserMenu` bunu `profile.is_admin` ile
 * güvenceye alıyor): `feedback`'in RLS'i admin olmayana zaten 0 döndürür, ama
 * `online_game_chat_reports_select_admin_or_own` politikası kişinin KENDİ
 * gönderdiği şikayetleri de görmesine izin verdiğinden, admin olmayan bir
 * çağıran burada kendi bekleyen şikayetlerini sayardı — bu rozetin anlamı
 * değil.
 */
export async function fetchAdminPendingCount(): Promise<number> {
  if (!supabase) return 0;
  const [feedbackRes, reportsRes, inboxRes] = await Promise.all([
    supabase.from('feedback').select('id', { count: 'exact', head: true }).eq('handled', false),
    supabase
      .from('online_game_chat_reports')
      .select('id', { count: 'exact', head: true })
      .eq('handled', false),
    // ÜÇÜNCÜ KAYNAK (26 Ağustos 2026): destek@'e gelen ve admin'e henüz haber
    // verilmemiş cevaplar. Bu satır ilk yazıldığında ATLANMIŞTI ve sonuç, bu
    // projede adı konmuş bir hata sınıfıydı (bkz. `docs/decisions/
    // components-account.md` → CountBadge, "rozet zinciri yukarı takip
    // edilmedi"):
    // panelin İÇİNDEKİ "Zoho" rozeti sayıyor ama DIŞARIDAKİ "Admin Paneli"
    // rozeti saymıyordu — yani admin, paneli açmayı akıl edene kadar gelen
    // cevaptan haberdar olmuyordu, ki bildirimin tek amacı buydu.
    supabase.from('support_inbox').select('id', { count: 'exact', head: true }).is('seen_at', null),
  ]);
  if (feedbackRes.error) {
    console.error('[Kelimeki] fetchAdminPendingCount (feedback) hatası:', feedbackRes.error.message);
  }
  if (reportsRes.error) {
    console.error('[Kelimeki] fetchAdminPendingCount (şikayet) hatası:', reportsRes.error.message);
  }
  if (inboxRes.error) {
    console.error('[Kelimeki] fetchAdminPendingCount (destek kutusu) hatası:', inboxRes.error.message);
  }
  return (feedbackRes.count ?? 0) + (reportsRes.count ?? 0) + (inboxRes.count ?? 0);
}

/**
 * Bir geri bildirim mesajını okundu/okunmadı işaretler (yalnızca admin).
 * `AdminDashboard`'daki iyimser (optimistic) UI güncellemesi başarısızlıkta
 * geri alınabilsin diye başarı/başarısızlığı `boolean` olarak döner —
 * `toggleGameLike`'daki (`GameHistoryModal`) aynı desen.
 */
export async function markFeedbackHandled(id: string, handled: boolean): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.from('feedback').update({ handled }).eq('id', id);
  if (error) {
    console.error('[Kelimeki] markFeedbackHandled hatası:', error.message);
    return false;
  }
  return true;
}

/** Tüm sohbet şikayetlerini döner (yalnızca admin — admin_list_chat_reports RPC'si). */
export async function fetchAdminChatReports(): Promise<AdminChatReportRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_list_chat_reports');
  if (error) {
    // Admin panelindeki .catch(setError) zinciri buna güveniyor —
    // önceden burada [] /null dönülüp hata yutuluyordu, admin gerçek
    // bir RPC/izin hatasını asla göremiyordu (bkz. kod incelemesi).
    throw new Error(error.message);
  }
  return (data as AdminChatReportRow[]) ?? [];
}

/**
 * Bir şikayeti okundu/okunmadı işaretler (yalnızca admin). `markFeedbackHandled`
 * ile aynı gerekçeyle başarı/başarısızlığı `boolean` olarak döner.
 */
export async function markChatReportHandled(id: string, handled: boolean): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.rpc('admin_mark_chat_report_handled', { p_id: id, p_handled: handled });
  if (error) {
    console.error('[Kelimeki] markChatReportHandled hatası:', error.message);
    return false;
  }
  return true;
}

/** Bitmiş bir Canlı oyunun tam sohbet dökümünü döner (yalnızca admin, yalnızca bitmiş oyunlar). */
export async function fetchAdminFinishedGameChat(onlineGameId: string): Promise<GameChatMessage[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_get_finished_game_chat', { p_online_game_id: onlineGameId });
  if (error) {
    console.error('[Kelimeki] fetchAdminFinishedGameChat hatası:', error.message);
    return [];
  }
  return (data as GameChatMessage[]) ?? [];
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
async function invokeEdgeFunction<T = unknown>(name: string, body: Record<string, unknown>): Promise<T> {
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
  return data as T;
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

// ── Hesap silme (uygulama içi yol) ──────────────────────────────────────────
//
// Play/Apple, hesap açtıran uygulamalarda uygulama İÇİNDEN başlatılabilen bir
// silme yolu istiyor (`/hesap-silme/` sayfası yalnızca Data safety formuna
// verilen TALEP adresidir, işi yapan taraf burası).
//
// İki uç DEĞİL, tek Edge Function: `delete-my-account`. Kimlik çağıranın kendi
// JWT'siyle doğrulanıyor, silinen her zaman O kullanıcı — istemci bir kullanıcı
// kimliği GÖNDERMİYOR. Asıl kaskadın (`delete_account_cascade` RPC'si) execute
// yetkisi `authenticated` rolünden geri alınmış durumda, yani bu yol dışından
// çağrılamıyor.

/** `delete-my-account`in döndürdüğü rapor. Alan adları sunucudakiyle birebir. */
export interface AccountDeletionReport {
  ok: boolean;
  dryRun: boolean;
  hesap: { id: string; email: string | null; ad: string | null };
  silinecek: Record<string, number>;
  anonimlestirilecek: Record<string, number>;
  kimliksizlestirilecek: Record<string, number>;
  eslenemeyen_games_satiri: number;
  hesapSilindi?: boolean;
}

/**
 * KURU ÇALIŞTIRMA — hiçbir şey silmez, yalnızca ne silineceğini/neyin
 * anonimleştirileceğini sayar. Onay penceresi bunu açılışta çağırıp
 * kullanıcıya gösteriyor: geri dönüşü olmayan bir işlemde "ne kaybedeceğim"
 * sorusunun cevabı tahmin değil ÖLÇÜM olmalı.
 */
export async function previewAccountDeletion(): Promise<AccountDeletionReport> {
  return invokeEdgeFunction<AccountDeletionReport>('delete-my-account', { dryRun: true });
}

/**
 * GERÇEK SİLME — geri alınamaz. `confirm` dizesi sunucunun beklediği son
 * bariyer (kazara bir gövdesiz istek hiçbir şey silmesin diye; sunucu tarafı
 * `dryRun`ı varsayılan olarak true kabul ediyor).
 */
export async function deleteMyAccount(): Promise<AccountDeletionReport> {
  return invokeEdgeFunction<AccountDeletionReport>('delete-my-account', {
    dryRun: false,
    confirm: 'HESABIMI SIL',
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
  /**
   * Mesajın GERÇEKTEN yazıldığı an (ISO). Verilmezse sunucunun `now()`
   * varsayılanı kalır — anlık gönderimde doğrusu budur.
   *
   * ⚠ Offline kuyruktan gönderirken VERİLMESİ ZORUNLU: kuyruktaki mesaj
   * günler sonra iletilebilir ve damgalanmazsa admin panelinde yazıldığı
   * güne değil İLETİLDİĞİ güne düşer. Kuyruk bu değeri zaten tutuyordu
   * (TTL için), yalnızca göndermiyordu — bkz. `feedbackSync.ts`.
   */
  createdAt?: string,
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
    ...(createdAt ? { created_at: createdAt } : {}),
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
/**
 * Supabase Auth (GoTrue) hatalarını Türkçeye çevirir.
 *
 * 4 Ağustos 2026'da bulundu: `AuthModal`/`ResetPasswordModal`/
 * `AccountSettingsModal` yakaladıkları hatanın `message`'ını OLDUĞU GİBİ
 * ekrana basıyordu — yani Türkçe bir uygulamada kullanıcı "User is banned",
 * "Invalid login credentials", "Email not confirmed" gibi ham İngilizce
 * metinler görüyordu. (Dondurulmuş bir hesapla giriş denenirken fark edildi;
 * bu yalnızca dondurmaya özgü değil, TÜM auth hataları aynı yoldan geçiyordu.)
 *
 * Önce `code` (GoTrue'nun `error_code`'u) denenir — mesaj metni sürümler
 * arasında değişebilir, kod daha kararlıdır. Kod tanınmazsa mesaj metnine
 * göre eşleme yapılır. İkisi de tutmazsa `null` dönülür ve çağıran orijinal
 * mesajı gösterir: bilmediğimiz bir hatayı uydurma bir Türkçe cümleyle
 * gizlemek, hata ayıklamayı imkânsız kılardı.
 *
 * ÖNEMLİ: bu fonksiyon yalnızca Supabase kaynaklı hatalara uygulanmalı.
 * Formların kendi doğrulama hataları (`throw new Error('Ad zorunludur.')`)
 * zaten Türkçe — `code` taşımadıklarından ve mesajları eşleşmediğinden
 * buradan olduğu gibi geçerler.
 */
export function friendlyAuthMessage(err: unknown): string | null {
  const e = err as { code?: string; message?: string } | null;
  const code = e?.code;
  const msg = e?.message ?? '';

  const byCode: Record<string, string> = {
    invalid_credentials: 'E-posta ya da şifre hatalı.',
    // Kullanıcıyı "Görüş Bildir"e yönlendirmiyoruz: o form girişsiz bir
    // ziyaretçiye Setup'ta hiç görünmüyor (yalnızca Kullanım Koşulları/
    // Gizlilik modallerinin içine gömülü bir bağlantı), dolayısıyla eyleme
    // dönüşmezdi. `notify-account-banned` her dondurmada zaten gerekçeyi ve
    // çalışan bir iletişim bağlantısını (?contact=1) içeren bir e-posta
    // gönderiyor — doğru yönlendirme orası.
    //
    // BİLİNÇLİ KARAR (4 Ağustos 2026) — bu mesaj küçük bir bilgi sızıntısı
    // içeriyor ve öyle KALIYOR. Gerçek uçla ölçüldü (pg_net ile
    // /auth/v1/token'a dört senaryo): kayıtlı olmayan e-posta ve kayıtlı ama
    // yanlış şifre `invalid_credentials` dönerken, DONDURULMUŞ bir hesap
    // ŞİFRE DOĞRU MU YANLIŞ MI FARK ETMEKSİZİN `user_banned` dönüyor. Yani
    // birinin e-postasını bilen biri, şifresini bilmeden o hesabın
    // dondurulduğunu öğrenebilir.
    //
    // "Önce şifreyi doğrula, sonra ban'a bak" sırası istemci tarafında
    // KURULAMAZ: GoTrue şifreyi hiç doğrulamadan `user_banned` döndürdüğünden
    // bize ulaşan yanıtta şifrenin doğru olup olmadığı bilgisi yok. Üç seçenek
    // değerlendirildi: (1) olduğu gibi bırakmak, (2) dondurulmuşta da genel
    // "e-posta ya da şifre hatalı" göstermek, (3) service-role bir Edge
    // Function'da pgcrypto `crypt()` ile kendi bcrypt doğrulamamızı yazmak.
    // (2) gerçekten dondurulmuş kullanıcıyı yanıltırdı (şifresini yanlış
    // yazdığını sanıp defalarca denerdi); (3) kimlik doğrulamasız bir
    // şifre-doğrulama ucu açıp GoTrue'nun rate limiting'ini devre dışı
    // bırakacağından kapattığı sızıntıdan daha büyük bir risk üretirdi.
    // Sızıntının değeri düşük — sıradan hesap sayımı (enumeration) hâlâ
    // engelli, yalnızca "kayıtlı + dondurulmuş" ayırt edilebiliyor ve bunun
    // için hedefin e-postasını zaten bilmek gerekiyor.
    user_banned: 'Hesabınız donduruldu. Gerekçesi ve itiraz yolu e-posta adresinize gönderildi.',
    email_not_confirmed: 'E-posta adresini henüz doğrulamadın. Gelen kutunu (ve spam klasörünü) kontrol et.',
    user_already_exists: 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı ya da şifreni sıfırlamayı dene.',
    email_exists: 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı ya da şifreni sıfırlamayı dene.',
    weak_password: 'Şifre çok zayıf. En az 6 karakter kullan.',
    same_password: 'Yeni şifre eskisiyle aynı olamaz.',
    otp_expired: 'Bağlantının süresi dolmuş. Yeni bir bağlantı iste.',
    over_email_send_rate_limit: 'Çok fazla e-posta isteği gönderildi. Birkaç dakika sonra tekrar dene.',
    over_request_rate_limit: 'Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar dene.',
    signup_disabled: 'Şu anda yeni kayıt alınmıyor.',
    validation_failed: 'Girdiğin bilgilerde bir hata var, kontrol et.',
  };
  if (code && byCode[code]) return byCode[code];

  // `code` yoksa (eski supabase-js sürümleri / bazı uçlar) mesaja bak.
  const byMessage: [RegExp, string][] = [
    [/user is banned/i, byCode.user_banned],
    [/invalid login credentials/i, byCode.invalid_credentials],
    [/email not confirmed/i, byCode.email_not_confirmed],
    [/user already registered|already been registered/i, byCode.user_already_exists],
    [/password should be at least/i, byCode.weak_password],
    [/new password should be different/i, byCode.same_password],
    [/token has expired or is invalid/i, byCode.otp_expired],
    [/for security purposes|rate limit/i, byCode.over_request_rate_limit],
    [/unable to validate email address|invalid format/i, 'Geçerli bir e-posta adresi gir.'],
  ];
  for (const [re, text] of byMessage) {
    if (re.test(msg)) return text;
  }
  return null;
}

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
          // Büyüme > Kullanıcı funnel'ının "üye"/"oyun" adımları buna
          // dayanıyor (`profiles.signup_utm_source`, 16 Ağustos 2026).
          // `?ref=` HİÇ yoksa bile AÇIKÇA 'direkt' gönderiliyor: sunucuda
          // null, "bu istemci hiç damgalamadı" (eski üyeler, web dışı
          // istemciler) anlamına geliyor ve funnel'da "Bilinmiyor"a
          // düşüyor — uygulama kayıtları "Direkt"i şişirmesin diye.
          utmSource: getStoredUtmSource() ?? 'direkt',
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
    /** İşlemsel-ama-tercih-edilebilir bildirim maillerini (arkadaşlık isteği,
     * oyun daveti, süre uyarısı vb.) alma tercihi — marketing_consent'ten
     * ayrı, `AccountSettingsModal`'daki ikinci checkbox. */
    email_notifications_enabled?: boolean;
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
  // `...patch` İLK sırada yayılıyor ki gender/birth_date/marketing_consent/
  // email_notifications_enabled gibi alanlar da (önceden bu yedek yolda
  // sessizce kayboluyordu — kod incelemesiyle bulundu) satıra geçsin; hemen
  // ardından id/username/first_name/last_name/display_name/avatar_url
  // AÇIKÇA üzerine yazılıyor ki bunlar `patch`'te eksikse (undefined)
  // aşağıdaki hesaplanmış varsayılanları ezmesinler.
  if (!data || data.length === 0) {
    const firstName = patch.first_name ?? '';
    const lastName = patch.last_name ?? '';
    const fallbackNickname = user.email ? user.email.split('@')[0] : user.id;
    const { error: createErr } = await supabase.from('profiles').insert({
      ...patch,
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
// MIME/boyut kontrolü asıl UI çağrı yerinde (AccountSettingsModal.onPickFile)
// zaten yapılıyor — burada ikinci bir savunma katmanı olarak tekrarlanıyor,
// çünkü uploadAvatar paylaşılan bir kütüphane fonksiyonu ve ileride başka
// bir çağrı yeri bu kontrolü atlayabilir.
// GİRİŞ sınırı (kullanıcının seçebileceği azami dosya). 13 Ağustos 2026'da
// 2 MB'dan 10 MB'a çıkarıldı: tipik telefon fotoğrafı 2-12 MB arasında
// (iPhone HEIC 1.5-3, iPhone JPEG 2-4, Android 50-200MP 3-12) ve kullanıcı
// galerisinde 2 MB altı fotoğraf bulamadığını bildirdi. SAKLANAN boyut bundan
// bağımsız — `shrinkAvatar` yüklemeden önce ~512 px'e indiriyor.
const MAX_AVATAR_BYTES = 10 * 1024 * 1024;
// Küçültülmüş avatarın azami kenar uzunluğu; avatar en fazla 36-64 px
// gösteriliyor, DPR 3'te bile ~192 px — 512 bol bir pay.
const AVATAR_MAX_EDGE = 512;
// Bunun altındaki dosyalar olduğu gibi yüklenir (yeniden kodlamak onları
// büyütebilir).
const AVATAR_SHRINK_THRESHOLD = 400 * 1024;

/**
 * Yüklemeden ÖNCE küçültür. Avatar hiçbir zaman 96 px'den büyük
 * gösterilmediğinden 10 MB'lık bir orijinali depolamak ve her açılışta
 * indirmek israf olurdu; giriş sınırını yükseltmenin tek başına yanlış
 * çözüm olmasının sebebi bu.
 *
 * Kare KIRPMA yok — avatar zaten `object-cover` ile dairesel gösteriliyor,
 * kırpma görüntüleme anında oluyor (mobil port da aynı kararı taşıyor).
 * Çözülemeyen bir dosyada orijinal döner: küçültme bir iyileştirme,
 * yükleme yolunu kırmamalı.
 */
async function shrinkAvatar(file: File): Promise<Blob> {
  if (file.size <= AVATAR_SHRINK_THRESHOLD) return file;
  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, AVATAR_MAX_EDGE / Math.max(bitmap.width, bitmap.height));
    if (scale >= 1) {
      bitmap.close();
      return file;
    }
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      bitmap.close();
      return file;
    }
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, 'image/jpeg', 0.85),
    );
    // Beklenmedik şekilde büyüdüyse orijinali koru.
    if (!blob || blob.size >= file.size) return file;
    return blob;
  } catch {
    return file;
  }
}
const EXT_BY_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

export async function uploadAvatar(file: File): Promise<string> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  if (!file.type.startsWith('image/')) throw new Error('Lütfen bir görsel dosyası seç.');
  if (file.size > MAX_AVATAR_BYTES) throw new Error('Görsel 10 MB’den küçük olmalı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');

  // Dosya adındaki uzantı yerine gerçek MIME tipinden türetiliyor —
  // uzantısız/yanıltıcı bir dosya adı (ör. "photo", "resim.jpeg.txt")
  // önceden path'e olduğu gibi (ör. "avatar.photo") yazılıyordu.
  // Yüklemeden ÖNCE küçült — 10 MB yalnızca "ne seçebilirsin"i belirler,
  // saklanan her zaman küçük hâlidir.
  const body = await shrinkAvatar(file);
  const contentType = body.type || file.type;
  const ext = EXT_BY_MIME[contentType] ?? 'png';
  const path = `${user.id}/avatar.${ext}`;

  const { error: upErr } = await supabase.storage
    .from('avatars')
    .upload(path, body, { upsert: true, contentType });
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

/**
 * Çağıranın tüm devam eden yerel (YZ) oyun kayıtları, en son güncellenen önce.
 *
 * Ağ/RLS hatasında **`null`** döner, boş dizi DEĞİL — çağıran "liste alınamadı"
 * ile "hiç oyunun yok"u ayırt edebilsin diye (12 Ağustos 2026). Eskiden hatada
 * `[]` dönüyordu ve çevrimdışı kullanıcı Setup'ta boş bir liste görüyordu:
 * devam eden oyunları kaybolmuş gibi duruyor ve onlara devam edemiyordu. Aynı
 * ayrım Flutter portunda da var (`CloudSaveRepo.list` → null, Parça 43).
 */
export async function listLocalGameSaves(): Promise<LocalGameSave[] | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('local_game_saves')
    .select('*')
    .order('updated_at', { ascending: false });
  if (error) {
    console.error('[Kelimeki] listLocalGameSaves hatası:', error.message);
    return null;
  }
  return (data as LocalGameSave[]) ?? [];
}

/**
 * Bir yerel oyunu sunucuya kaydeder (id yeni ise ekler, varsa günceller —
 * `upsert`). `id` her oyun için App.tsx'te bir kez üretilip aynı oyun
 * bitene/terk edilene kadar sabit kalır, böylece art arda gelen her hamle
 * aynı satırı günceller.
 */
export async function upsertLocalGameSave(id: string, userId: string, state: GameState): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.from('local_game_saves').upsert({
    id,
    user_id: userId,
    state,
    player_count: state.players.length,
  });
  if (error) {
    console.error('[Kelimeki] upsertLocalGameSave hatası:', error.message);
    return false;
  }
  return true;
}

/**
 * Bir yerel oyun kaydını siler — oyun normal biçimde bitince ya da 7 günlük
 * terk edilme süpürmesi tarafından çağrılır.
 *
 * Başarıyı **döner**: çağıran, silinemeyen id'yi kalıcı bir kuyruğa yazıp
 * sonraki senkronda tekrar deneyebilsin diye (12 Ağustos 2026). Eskiden `void`
 * dönüyordu, yani offline biten bir oyunun "bu satır silinmeli" bilgisi
 * hiçbir yerde kalmıyor ve sunucudaki bitmemiş kopya listede "devam eden
 * oyun" olarak geri geliyordu.
 */
export async function deleteLocalGameSave(id: string): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.from('local_game_saves').delete().eq('id', id);
  if (error) {
    console.error('[Kelimeki] deleteLocalGameSave hatası:', error.message);
    return false;
  }
  return true;
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
