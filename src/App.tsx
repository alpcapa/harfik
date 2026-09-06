// Kelimeki — ana uygulama: kurulum, çok oyunculu sıra akışı ve düzen
import { useEffect, useMemo, useReducer, useRef, useState } from 'react';
import type { MouseEvent as ReactMouseEvent } from 'react';
import { GameHeader } from './components/GameHeader';
import { Board } from './components/Board';
import { Rack } from './components/Rack';
import { GameOver } from './components/GameOver';
import { UserMenu } from './components/UserMenu';
import { TermsModal } from './components/TermsModal';
import { PrivacyModal } from './components/PrivacyModal';
import { AuthModal } from './components/AuthModal';
import { Setup } from './components/Setup';
import { AddToHomeScreen } from './components/AddToHomeScreen';
import { LandscapeHint } from './components/LandscapeHint';
import { LeagueRewardsHost, requestLeagueRewardCheck } from './components/LeagueRewardsHost';
import { MeaningModal } from './components/MeaningModal';
import { RemainingTilesModal } from './components/RemainingTilesModal';
import { MoveHistoryModal } from './components/MoveHistoryModal';
import { WildcardModal } from './components/WildcardModal';
import { HelpModal } from './components/HelpModal';
import { FeedbackModal } from './components/FeedbackModal';
import { LogoMark } from './components/LogoMark';
import { ResetPasswordModal } from './components/ResetPasswordModal';
import { createInitialState, gameReducer, isFirstMove } from './game/gameReducer';
import type { PlayerSetup } from './game/gameReducer';
import { preloadWordSet, isWordSetReady } from './data/wordSetLoader';
import { calcScore, computeInvasionSplit, formatInvalidWordsReason, validatePlacement, validatePlacementStructural } from './utils/validator';
import { loadGameState, saveGameState, clearGameState, takePendingAbandonedGame, ABANDON_TIMEOUT_MS } from './utils/gameStorage';
import type { SavedGame } from './utils/gameStorage';
import type { MirroredSave, ServerRowLike } from './utils/cloudSaveMirror';
import {
  classifyCloudSaves,
  mergeOfflineCloudSaves,
  putMirroredSave,
  removeMirroredSave,
  pendingMirroredSaves,
  readCloudSaveCache,
  writeCloudSaveCache,
  queueCloudSaveDelete,
  pendingCloudSaveDeletes,
  unqueueCloudSaveDelete,
} from './utils/cloudSaveMirror';
import { buildGameRecord } from './utils/gameRecord';
import { markQuickStartSeen } from './utils/onboarding';
import { swallowNextClick } from './utils/ghostClick';
import { useBoardZoom } from './hooks/useBoardZoom';
import { getFormedWords, getFullWordAt, key } from './utils/board';
import { nearbyDraftCell } from './utils/draftRescue';
import type { AiLevel, GameState, Tile as TileModel } from './game/types';
import { aiLevelOf } from './utils/aiLevel';
import { Tile } from './components/Tile';
import { trLower } from './utils/turkish';
import { PLAYER_COLORS, SIZE } from './game/constants';
import {
  fetchMeaning,
  isValidWordRemote,
  isSupabaseConfigured,
  logGameFinish,
  logGameStart,
  logGuestVisit,
  logDeviceVisit,
  acceptFriendInvite,
  listLocalGameSaves,
  upsertLocalGameSave,
  deleteLocalGameSave,
  claimAbandonedLocalGameSave,
} from './lib/api';
import { saveGameDurable, flushPendingGames } from './utils/gameSync';
import { setActivelyPlaying } from './lib/pwa';
import { flushPendingFeedback } from './utils/feedbackSync';
import { takePendingInviteToken } from './utils/friendInvite';
import {
  getOrCreateAnonId,
  visitAlreadyLoggedToday,
  markVisitLoggedToday,
  deviceVisitAlreadyLoggedToday,
  markDeviceVisitLoggedToday,
  getStoredUtmSource,
  getDeviceType,
  getDeviceModel,
  getOsVersion,
  isStandaloneDisplay,
} from './utils/visitTracking';
import type { LocalGameSave, OnlineGame, WordMeaning } from './lib/database.types';
import { OnlineGameScreen } from './components/OnlineGameScreen';
import { useAuth } from './hooks/useAuth';
import { useModalA11y } from './hooks/useModalA11y';
import { useAppIconBadge } from './hooks/useAppIconBadge';

const AI_THINK_MS = 1100;
// Sürüklemenin "tıklama" değil gerçek bir sürükleme sayılması için gereken
// minimum işaretçi hareketi (piksel). FARE ile PARMAK aynı değeri
// KULLANAMAZ: 22 Ağustos 2026'da ölçüldü — 6px'lik tek eşik altında, parmak
// 6px oynayan bir dokunuş "sürükleme" sayılıp aynı hücrede bittiğinden
// HİÇBİR ŞEY yapmıyordu (raf taşı seçilmiyor, konmuş taş geri alınmıyor,
// joker penceresi açılmıyor) — kullanıcıya "dokunuşum işlemedi" olarak
// görünen sessiz bir kayıp. Platform normları 6'nın üstünde: Android/Chrome
// touch slop 8px, iOS ~10pt, Flutter kTouchSlop 18. Fare tarafı bilerek
// DEĞİŞMEDİ (imleç titremez, 6px orada doğru his).
const DRAG_THRESHOLD_MOUSE = 6;
const DRAG_THRESHOLD_TOUCH = 10;
/** Jestin kaynağına göre eşik — fare 6, parmak/kalem 10. */
const dragThresholdFor = (pointerType: string) =>
  pointerType === 'mouse' ? DRAG_THRESHOLD_MOUSE : DRAG_THRESHOLD_TOUCH;

/// BIRAKMA anındaki karar eşiği — yukarıdaki hayalet eşiğinden AYRI.
///
/// NEDEN VAR (27 Ağustos 2026, kullanıcı uygulamada İKİNCİ kez bildirdi:
/// *"Hâlâ tahtaya koyulan taşı her zaman alamıyorum. 1-2 denemeden sonra
/// alabiliyorum."*): 10 px (Android touch slop) hayaleti GÖSTERMEK için
/// doğru bir sınır ama BIRAKMA kararı için fazla dar — parmak o kadarını
/// istemeden aşıyor ve dokunuş sürükleme sayılıp sessizce kayboluyordu.
///
/// Portta ölçüldü (taslak taşa dokunup bırakma): 6 px kayma → geri alındı;
/// **12 px ve 20 px kayma → HİÇBİR ŞEY olmadı**. Raf tarafı da aynı:
/// titreşimli dokunuşta taş seçilemiyordu bile.
///
/// 24, tahta hücresinin (~26 px) hemen altında: bir hücreden az giden bir
/// jest zaten bir hedef ifade edemiyor.
const TAP_SLOP_ON_RELEASE = 24;

// Sürüklenen taşın görseli, parmağın altında kalıp görüşü engellememesi için
// işaretçinin bu kadar üzerinde çizilir.
const DRAG_LIFT = 30;

type DragSource =
  | { kind: 'rack'; index: number; tile: TileModel }
  | { kind: 'placed'; r: number; c: number; tile: TileModel };

const MESSAGE_COLORS: Record<string, string> = {
  ok: 'text-green',
  err: 'text-red',
  warn: 'text-gold',
  '': 'text-muted',
};

export default function App() {
  const { user, profile, profileLoading, loading: authLoading, passwordRecovery, clearPasswordRecovery } = useAuth();
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);

  // Yarım kalan yerel (YZ) oyun — artık otomatik açılmıyor (bkz. Setup.tsx'teki
  // "Devam Eden Oyun" satırı): Setup her zaman ilk görülen ekran olsun ki
  // oyuncu Arkadaşınla sekmesindeki bekleyen davetleri/sırasını da görebilsin.
  // Kayıt burada ayrı bir state'te tutulup Setup'a iletilir; RESUME_SAVED
  // dispatch edilene kadar `state`'e hiç dokunmaz.
  const [savedGame, setSavedGame] = useState<SavedGame | null>(() => loadGameState());

  // Girişli kullanıcının devam eden YZ oyunları — `local_game_saves`
  // tablosundan (bkz. src/lib/api.ts). Yukarıdaki `savedGame`'in aksine
  // (misafir/localStorage, tek slot) burada birden fazla oyun aynı anda
  // "devam eden" sayılabilir ve herhangi bir cihazdan erişilebilir. Misafir
  // kullanıcılar için her zaman null kalır — Setup bu durumda mevcut tekil
  // (savedGame) davranışı aynen kullanmaya devam eder.
  const [cloudSaves, setCloudSaves] = useState<LocalGameSave[] | null>(null);
  // Şu an reducer'da oynanmakta olan oyunun sunucudaki `local_game_saves.id`si
  // — girişli bir kullanıcı için doludur (yeni oyunda ilk state değişiminde
  // tembelce üretilir, sunucudan devam edilen bir oyunda ise handleResumeCloudSave
  // tarafından dispatch'ten ÖNCE atanır). Oyun bitince/terk edilince null'a
  // döner ki bir sonraki oyun yeni bir id alsın.
  const activeSaveIdRef = useRef<string | null>(null);
  // Girişli kullanıcının autosave'i (aşağıdaki effect) debounce'lu — taş
  // seçmek dahil her dispatch'te ağ isteği atmamak için. `saveChainRef` ayrıca
  // ardışık çağrıları SERİLEŞTİRİR (bir öncekinin cevabını beklemeden yenisini
  // başlatmaz) ki gecikmiş bir eski istek, sonra tamamlanan daha yeni bir
  // isteği ezip cihazlar-arası devamda eski state'i göstermesin.
  const saveDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const saveChainRef = useRef<Promise<unknown>>(Promise.resolve());
  // `local_game_saves`e yazan HER işlem (upsert VE silme) bu kuyruğa girmeli
  // — yalnızca upsert'ler serileşirse, doğrudan atılan bir silme uçuştaki bir
  // upsert'i "geçip" satırın yeniden yazılmasına yol açabilir. Ayrıca
  // `refreshCloudSaves` listeyi çekmeden önce bu kuyruğun boşalmasını bekler
  // (aşağı bkz.) — silme ile listeleme arasındaki yarışı da bu kapatıyor.
  const enqueueSaveWrite = <T,>(run: () => Promise<T>): Promise<T> => {
    const next = saveChainRef.current.catch(() => {}).then(run);
    saveChainRef.current = next;
    return next;
  };

  // Bir oyunu ÖNCE yerel aynaya, sonra sunucuya yazar (write-behind — bkz.
  // `cloudSaveMirror.ts`). Yerel yazma neredeyse her zaman başarılı olduğundan
  // sunucu erişilemese bile hamle kaybolmaz; sunucuya yazılınca ayna silinir,
  // yani normal (online) akışta ayna hep boş kalır.
  const writeCloudSave = async (id: string, uid: string, snapshot: GameState): Promise<boolean> => {
    const mirrored = putMirroredSave(id, uid, snapshot);
    const ok = await upsertLocalGameSave(id, uid, snapshot);
    if (ok) {
      removeMirroredSave(id);
      return true;
    }
    if (!mirrored) {
      // İkisi de başarısız — bu state HİÇBİR YERDE yok. Sessizce yutmak,
      // kullanıcının hamlesini kaybettiğini hiç fark etmemesi demek.
      console.error('[Kelimeki] KAYIP: oyun ne sunucuya ne yerel aynaya yazılabildi.');
    }
    return false;
  };

  // Sunucudan silinemeyen kaydı kalıcı kuyruğa alır ki bir sonraki senkronda
  // tekrar denensin (aksi halde sunucudaki bitmemiş kopya listede "devam eden
  // oyun" olarak geri gelirdi). Ayna da her durumda temizlenir — silinmesi
  // istenen bir oyunu ayna diriltmemeli.
  const deleteCloudSave = async (id: string, uid: string): Promise<void> => {
    removeMirroredSave(id);
    const ok = await deleteLocalGameSave(id);
    if (ok) unqueueCloudSaveDelete(id, uid);
    else queueCloudSaveDelete(id, uid);
  };
  // Misafirin yarıda bırakılmış `savedGame`'ini girişten sonra hesaba
  // taşıyan effect'in (aşağıda) StrictMode/mükerrer-çalışma kilidi.
  const migratingSavedGameRef = useRef(false);

  // Sınıflandırmanın ürettiği satırı UI'ın beklediği `LocalGameSave` şekline
  // çevirir. `created_at` gerçek sunucu değeri değil oyunun başlangıç anı —
  // Setup bu alanı okumuyor (yalnızca `updated_at`/`state` kullanılıyor), ama
  // tipi doldurmak gerekiyor.
  const toLocalGameSave = (uid: string, r: ServerRowLike): LocalGameSave => ({
    id: r.id,
    user_id: uid,
    state: r.state,
    player_count: r.state.players.length,
    created_at: r.state.startedAt,
    updated_at: new Date(r.updatedAt).toISOString(),
  });

  // Terk edilmiş bir kayıt için gecikmeli teslim kaydı (-2 k-lig cezası) +
  // anonim telemetri. Yalnızca gerçekten başlamış (turnCount>=2) oyunlar
  // cezalandırılır; hiç oynanmamış bir kayıt sessizce silinir, ne ceza ne
  // telemetri üretir. İki çağıranı var (sunucudan iddia edilen satır ve
  // yalnızca-aynada kalmış oyun) — mantığın iki kopyaya ayrışmaması için
  // ortak.
  const penalizeAbandonedSave = (abandoned: GameState, lastActiveMs: number, uid: string) => {
    if (abandoned.turnCount < 2) return;
    const durationSeconds = Math.max(
      0,
      Math.round((lastActiveMs - Date.parse(abandoned.startedAt)) / 1000),
    );
    // Terk anı = son etkinlik + 7 gün. Bu fonksiyonun KOŞTUĞU an değil:
    // buraya ancak kullanıcı uygulamayı yeniden açınca geliniyor ve o an
    // haftalar sonra olabilir. Damgalanmazsa bir haftalık terkler "bugün"e
    // yazılır (4 Eylül 2026, sahada görüldü: bir kullanıcının 19 kaydı tek
    // bir saniyeye düştü, panelde "dün 38 teslim" diye göründü).
    const finishedAtMs = lastActiveMs + ABANDON_TIMEOUT_MS;
    void logGameFinish(
      abandoned.players.length,
      durationSeconds,
      abandoned.multiSession,
      true,
      uid,
      finishedAtMs,
    );
    const record = buildGameRecord(abandoned, true, 0, finishedAtMs);
    if (record) void saveGameDurable(record);
  };

  // Sunucuya ulaşılamadığında liste: son başarılı önbellek + ayna bindirmesi.
  // Kullanıcı uçak modunda Setup'a dönünce oyunlarını GÖREBİLMELİ (veri zaten
  // güvende ama "kayboldu" gibi duruyordu) ve onlara devam edebilmeli.
  //
  // **Yalnızca aynayı göstermek YETMEZ:** o zaman offline oynanmamış diğer
  // oyunlar listeden düşerdi — bir sorunu başkasıyla değişmiş olurduk.
  //
  // **Bu dalda CEZA HİÇ uygulanmaz:** 7 günü dolmuş bir satırın gerçekten terk
  // edilip edilmediği sunucuyla doğrulanmadan bilinemez (başka bir cihaz
  // oynamış olabilir) ve `claimAbandonedLocalGameSave`'in yarış koruması
  // offline çalışamaz. Süresi geçmiş satır listeye de ALINMAZ — kullanıcıyı,
  // bir sonraki çevrimiçi listelemede silinecek bir oyuna devam ettirmeyelim.
  const buildOfflineCloudSaves = (
    uid: string,
    mirrors: MirroredSave[],
    cutoffMs: number,
  ): LocalGameSave[] | null => {
    const rows = mergeOfflineCloudSaves(readCloudSaveCache(uid), mirrors, cutoffMs);
    return rows === null ? null : rows.map((r) => toLocalGameSave(uid, r));
  };

  // Girişli kullanıcının cloudSaves listesini sunucudan tazeler; bu arada 7
  // gün hareketsiz kalmış (ABANDON_TIMEOUT_MS) kayıtları da atomik olarak
  // "iddia edip" (claimAbandonedLocalGameSave) siler ve — tıpkı localStorage'daki
  // terk edilme akışıyla (aşağıdaki mount effect'i) BİREBİR AYNI mantıkla —
  // gerçekten başlamış (turnCount>=2) olanlar için gecikmeli bir teslim kaydı
  // (-2 k-lig cezası) oluşturur. `state === 'setup'` her göründüğünde
  // (App.tsx'teki phase effect'i) tetiklenir.
  const refreshCloudSaves = async () => {
    if (!user || !isSupabaseConfigured) {
      setCloudSaves(null);
      return;
    }
    // Bekleyen yazma varsa (özellikle `handleLogoClick`'in hiç oynanmamış
    // oyunu silmesi — o silme, ABANDON dispatch'inden ÖNCE kuyruğa girer)
    // önce onun bitmesini bekle. Aksi halde bu liste sorgusu silme sunucuda
    // commit edilmeden dönüp az önce silinen kaydı "Devam Edenler"de bir kez
    // gösterir; kullanıcı sekme değiştirip dönene kadar orada kalırdı.
    await saveChainRef.current.catch(() => {});
    const cutoffMs = Date.now() - ABANDON_TIMEOUT_MS;
    const cutoffIso = new Date(cutoffMs).toISOString();

    // (1) Bekleyen aynaları sunucuya it — LİSTELEMEDEN ÖNCE, ki liste zaten
    // güncellenmiş satırları görsün. Süresi DOLMUŞ aynayı bilerek İTMİYORUZ:
    // sunucu `updated_at`i bugüne çekerdi ve 7 gün kuralı sessizce
    // atlatılırdı ("oyunu açıp interneti kapatıp 10 gün sonra dönersem?").
    // Öyle bir ayna aşağıdaki döngüye bırakılır; orada son etkinlik anı
    // max(sunucu, ayna) olarak değerlendirilip ceza uygulanır.
    for (const m of pendingMirroredSaves(user.id)) {
      if (m.savedAt <= cutoffMs) continue;
      await enqueueSaveWrite(() => writeCloudSave(m.id, user.id, m.state));
    }
    // (2) Bekleyen silmeler — yazmalardan SONRA (silme aynayı zaten
    // temizliyor), listelemeden ÖNCE (aksi halde liste birazdan silinecek
    // satırı bir kez daha gösterirdi).
    for (const id of pendingCloudSaveDeletes(user.id)) {
      await enqueueSaveWrite(() => deleteCloudSave(id, user.id));
    }

    const saves = await listLocalGameSaves();
    const mirrors = pendingMirroredSaves(user.id);

    if (saves === null) {
      // Sunucuya ulaşılamadı — son başarılı liste + ayna bindirmesiyle çiz.
      // Ceza BU DALDA HİÇ uygulanmaz (bkz. buildOfflineCloudSaves).
      setCloudSaves(buildOfflineCloudSaves(user.id, mirrors, cutoffMs));
      return;
    }

    // Ne yapılacağının kararı saf bir fonksiyonda (test edilebilir olsun diye);
    // burada yalnızca o kararın G/Ç'si var.
    const plan = classifyCloudSaves(
      saves.map((s) => ({ id: s.id, state: s.state, updatedAt: Date.parse(s.updated_at) })),
      mirrors,
      cutoffMs,
    );

    // Güvenlik ağı: normalde bir oyun bitince (isGameOver) sunucudaki satırı da
    // silen autosave effect'i devreye girer — ama o silme isteği (ör. sekme
    // kapanınca) hiç ulaşmamış olabilir. Böyle yarım kalmış kayıtlar fırsatçı
    // biçimde temizlenir, listeye hiç girmez.
    for (const id of plan.finished) void enqueueSaveWrite(() => deleteCloudSave(id, user.id));
    for (const id of plan.orphanFinished) removeMirroredSave(id);

    const stillActive = plan.active.map((r) => toLocalGameSave(user.id, r));

    // Süresi dolmuş sunucu satırları: bu cihaz (ya da aynı anda başka bir
    // cihaz) "iddia" etmeyi dener. Başka biri zaten silmişse null döner.
    for (const row of plan.expired) {
      const claimedState = await claimAbandonedLocalGameSave(row.id, cutoffIso);
      if (!claimedState) continue;
      // Ayna da gitmeli: aksi halde satır silindikten sonra bir sonraki
      // açılışta "yalnızca aynada var" sanılıp oyun DİRİLİR — hem ceza
      // yazılmış hem oyun devam ediyor olurdu.
      removeMirroredSave(row.id);
      penalizeAbandonedSave(claimedState, row.updatedAt, user.id);
    }

    // Sunucunun HİÇ görmediği (tamamen offline açılmış) oyunlar — yalnızca
    // aynada varlar; iddia edilecek bir satır yok, ayna cihaza özel olduğundan
    // yarış da yok, doğrudan cezaya çevrilir.
    for (const m of plan.orphanExpired) {
      removeMirroredSave(m.id);
      penalizeAbandonedSave(m.state, m.savedAt, user.id);
    }

    // Offline'da listeyi çizebilmek için son BAŞARILI sonucu sakla — sunucu
    // satırlarını değil BİRLEŞTİRİLMİŞ sonucu (ayna bindirmesi uygulanmış hâli).
    writeCloudSaveCache(
      user.id,
      plan.active.map((r) => ({ id: r.id, state: r.state, updatedAt: r.updatedAt })),
    );
    setCloudSaves(stillActive);
  };

  // Setup ekranı her göründüğünde (ilk açılış ya da bir oyundan ABANDON ile
  // dönüldüğünde) listeyi tazele — LiveGamesTab'ın kendi mount'ında yaptığı
  // süpürmeyle aynı "hafif" desen (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6").
  useEffect(() => {
    if (state.phase === 'setup') void refreshCloudSaves();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.phase, user?.id]);

  // Her render'da yeniden tanımlanan `refreshCloudSaves`'in en güncel hâlini
  // tutar — aşağıdaki dinleyici effect'i bu yüzden her render'da yeniden
  // abone olmak zorunda kalmıyor (useAppIconBadge'deki `refreshAllRef` deseni).
  const refreshCloudSavesRef = useRef(refreshCloudSaves);
  refreshCloudSavesRef.current = refreshCloudSaves;

  // Setup'ta BEKLERKEN de tazele. Yukarıdaki effect yalnızca `state.phase`
  // ya da kullanıcı değişince çalışıyor — yani uygulama arka planda günlerce
  // durup öne döndüğünde (mobil PWA'da tipik) 7 günlük terk-edilme süpürmesi
  // hiç tetiklenmiyordu; kayıt ancak tam bir yeniden yüklemede süpürülüyordu
  // (4 Ağustos 2026'da TESTING.md bölüm 4 koşulurken fark edildi). Ceza
  // gecikiyordu, kaybolmuyordu — ama Canlı taraf (`LiveGamesTab`) baştan beri
  // bu dinleyicilere sahip olduğundan iki süpürme arasında tutarsızlık vardı.
  // Aynı 300ms'lik debounce: masaüstünde sekmeye dönüş visibilitychange +
  // focus'u (bazen online'ı da) neredeyse aynı anda tetikliyor.
  useEffect(() => {
    if (state.phase !== 'setup' || !user) return;
    let timeout: number | null = null;
    const schedule = () => {
      if (timeout != null) window.clearTimeout(timeout);
      timeout = window.setTimeout(() => {
        timeout = null;
        void refreshCloudSavesRef.current();
      }, 300);
    };
    const onVisibility = () => {
      if (document.visibilityState === 'visible') schedule();
    };
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('focus', schedule);
    window.addEventListener('online', schedule);
    return () => {
      if (timeout != null) window.clearTimeout(timeout);
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('focus', schedule);
      window.removeEventListener('online', schedule);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.phase, user?.id]);

  // Misafirken (girişsiz) yarıda bırakılmış (localStorage'daki tekil
  // `savedGame` slotu) bir YZ oyunu, kişi AYNI cihazda sonradan giriş/kayıt
  // olursa hesabına taşınır — kullanıcının "üye olursa oyunları altına
  // alınır" beklentisiyle örtüşsün diye. Öncesinde bu migrasyon hiç yoktu:
  // yalnızca BİTMİŞ oyunlar `gameSync.ts`'teki çevrimdışı kuyrukla hesaba
  // işleniyordu (bkz. "Bitmiş oyunların offline/misafir kuyruğu") — hâlâ
  // devam eden/bitmemiş bir misafir kaydı için hiçbir yol yoktu, giriş
  // yapılınca kayıt sessizce görünmez oluyordu (Setup'ın misafir dalı
  // `!user`, girişli dalı ise yalnızca `cloudSaves`'i okuduğundan). Artık
  // `user` dolduğunda (girişsizken zaten mevcut olan) `savedGame`
  // `local_game_saves`'e yeni bir satır olarak yükleniyor, localStorage'daki
  // eski kayıt silinip `savedGame` temizleniyor (bir sonraki oyunun kendi
  // sunucu satırını normal akıştan almasına engel olmasın diye) ve
  // `cloudSaves` listesi tazelenip "Devam Eden Oyunlar"da anında görünür
  // hâle geliyor. `migratingSavedGameRef`, StrictMode'un dev'de bu effect'i
  // art arda iki kez çalıştırmasında (`upsertLocalGameSave`'e her seferinde
  // YENİ bir rastgele id üretildiğinden, korumasız iki mükerrer satıra yol
  // açardı) senkron bir kilit görevi görüyor — `aiTriggeringRef`
  // (OnlineGameScreen.tsx) ile aynı desen.
  //
  // 1 Ağustos 2026 — bulunan hata: 1. oyuncunun adı taşınmıyordu. Misafirken
  // oyun `Setup.tsx`'in `doStart`'ıyla `players[0].name: 'Misafir'` olarak
  // kuruluyor (`accountName || 'Misafir'`) ve bu literal string doğrudan
  // `GameState`'e gömülüyor. Oyun içindeyken (`state.phase==='play'`) giriş
  // yapılırsa bunu düzelten ayrı bir `RENAME_PLAYER` efekti var (aşağıda,
  // "Oyun devam ederken giriş yapılırsa..."), ama misafir logoya basıp
  // Setup'a DÖNDÜKTEN sonra giriş yaparsa o efekt `state.phase!=='play'`
  // olduğundan hiç çalışmıyor — bu migration `savedGame.state`'i OLDUĞU GİBİ
  // yüklüyordu, yani `players[0].name` sonsuza dek `"Misafir"` kalıyor,
  // Setup'taki "Devam Eden Oyunlar" listesi de bunu doğrudan state'ten
  // okuduğundan (`Sıra: ${...name}`) hesap gerçek isimle eşleşse bile
  // kalıcı olarak "Sıra: Misafir" gösteriyordu. Düzeltme: yüklemeden önce
  // aynı isim hesabı (profil → display_name/first_name → e-posta öneki,
  // Setup.tsx'teki `accountName` ile birebir aynı mantık) yapılıp 1.
  // oyuncunun adı güncel hesap adıyla değiştiriliyor. `profileLoading` bitene
  // kadar effect bilerek bekletiliyor — aksi halde profil henüz gelmeden
  // hesaplanan `accountName` `null` kalıp yine "Misafir" ile yüklenebilirdi;
  // migration tamamlanınca `savedGame` zaten `null`'a döndüğünden bu ek
  // bağımlılık ikinci bir yüklemeye yol açmıyor (`!savedGame` koruması).
  useEffect(() => {
    if (!user || !isSupabaseConfigured || !savedGame || migratingSavedGameRef.current) return;
    if (profileLoading) return;
    migratingSavedGameRef.current = true;
    const id = crypto.randomUUID();
    const accountName =
      profile?.display_name || profile?.first_name || (user.email ? user.email.split('@')[0] : null);
    const p0 = savedGame.state.players[0];
    const stateToUpload =
      accountName && p0 && !p0.isAI && p0.name !== accountName
        ? {
            ...savedGame.state,
            players: savedGame.state.players.map((p, i) => (i === 0 ? { ...p, name: accountName } : p)),
          }
        : savedGame.state;
    // BİLEREK `writeCloudSave` DEĞİL, doğrudan upsert: bu yolun kendi
    // dayanıklılığı zaten var (başarısızlıkta `savedGame` olduğu gibi kalır,
    // bir sonraki mount'ta tekrar denenir). Aynaya da yazsaydık aynı oyun hem
    // misafir slotunda hem aynada durur, liste onu bir de "yalnızca aynada
    // olan oyun" sanıp MÜKERRER gösterirdi.
    void enqueueSaveWrite(() => upsertLocalGameSave(id, user.id, stateToUpload))
      .then((ok) => {
        // Yalnızca sunucuya GERÇEKTEN yazıldığı doğrulanınca yerel/bellek
        // kopyaları silinir — aksi halde (ağ/RLS hatası) `savedGame` olduğu
        // gibi bırakılır, bir sonraki girişte/mount'ta migrasyon tekrar
        // denenir. `upsertLocalGameSave` hatayı yutup sessizce `false`
        // dönebildiğinden bu kontrol olmadan başarısız bir yazım bile
        // "başarılı" sayılıp oyunun tek kopyası da silinmiş olurdu.
        if (!ok) {
          console.error('[Kelimeki] Misafir oyunu hesaba taşınamadı, tekrar denenecek.');
          return;
        }
        clearGameState();
        setSavedGame(null);
        void refreshCloudSaves();
      })
      .finally(() => {
        migratingSavedGameRef.current = false;
      });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id, profileLoading]);

  // Kelime listesi main.tsx'te tetiklenen ayrı chunk'tan yükleniyor —
  // hazır olana kadar hamle doğrulama/YZ turu tetiklenmemeli (bkz.
  // wordSetLoader.ts). Setup ekranında kuruluma harcanan birkaç saniye
  // içinde neredeyse her zaman zaten tamamlanmış olur.
  const [wordsReady, setWordsReady] = useState(isWordSetReady());
  useEffect(() => {
    if (wordsReady) return;
    let cancelled = false;
    let retryTimer: ReturnType<typeof setTimeout> | undefined;
    const attempt = () => {
      preloadWordSet()
        .then(() => {
          if (!cancelled) setWordsReady(true);
        })
        .catch((err) => {
          // Bir kerelik ağ hatasında sonsuza dek "Yükleniyor…" kilidinde
          // kalınmasın diye birkaç saniye sonra otomatik tekrar deneniyor
          // (preloadWordSet artık başarısızlıkta kendi önbelleğini
          // temizleyip yeniden denemeye izin veriyor, bkz. wordSetLoader.ts).
          console.error('[Kelimeki] Kelime listesi yüklenemedi, tekrar denenecek:', err);
          if (!cancelled) retryTimer = setTimeout(attempt, 5000);
        });
    };
    attempt();
    return () => {
      cancelled = true;
      if (retryTimer) clearTimeout(retryTimer);
    };
  }, [wordsReady]);

  // Misafir (girişsiz) ziyaretleri admin panelinin Büyüme > Kullanıcı
  // grafiğindeki "Ziyaret" serisi için günde bir kez anonim olarak
  // bildirir (bkz. src/utils/visitTracking.ts). Oturum durumu netleşmeden
  // (authLoading sırasında) göndermiyoruz — yoksa az sonra girişli olduğu
  // anlaşılacak bir kullanıcı da yanlışlıkla misafir sayılabilir.
  useEffect(() => {
    if (!isSupabaseConfigured || authLoading || user) return;
    if (visitAlreadyLoggedToday()) return;
    const anonId = getOrCreateAnonId();
    if (!anonId) return;
    markVisitLoggedToday();
    void logGuestVisit(
      anonId,
      getStoredUtmSource(),
      getDeviceType(),
      isStandaloneDisplay(),
      getOsVersion(),
      getDeviceModel(),
    );
  }, [authLoading, user]);

  // Cihaz/OS pingi — yukarıdaki misafir-ziyaret effect'inden BİLEREK AYRI:
  // o yalnızca oturum KAPALIYKEN ateşlenip Kaynak Hunisi'ni besliyor (huni
  // bilinçli olarak misafir-only kalmalı, bkz. CLAUDE.md "Huni BAŞTAN SONA
  // misafire indi"), bu ise hiçbir huniyi beslemeden GİRİŞLİ dahil TÜM
  // ziyaretleri admin panelinin "Cihaz" dökümü için sayar (24 Ağustos 2026,
  // kullanıcı isteği: "Cihaz datası gelen tüm insanların — girişli veya
  // girişsiz — hangi cihazlardan geldiğini görmek için; girişliler kişisel
  // bilgi olarak ilişkilendirilmeden, anonim sayılmalı"). `device_visits`e
  // yazılan satır `user_id` TAŞIMAZ — yalnızca cihazdaki anonim `anon_id`.
  // Kendi ayrı günlük damgasını (`deviceVisitAlreadyLoggedToday`) kullanır;
  // yukarıdaki effect'in damgasıyla paylaşılsaydı biri ötekini bastırabilirdi.
  useEffect(() => {
    if (!isSupabaseConfigured || authLoading) return;
    if (deviceVisitAlreadyLoggedToday()) return;
    const anonId = getOrCreateAnonId();
    if (!anonId) return;
    markDeviceVisitLoggedToday();
    void logDeviceVisit(anonId, getDeviceType(), getOsVersion(), getDeviceModel());
  }, [authLoading]);

  // Devam eden oyunu (phase==='play', bitmemiş) her değişiklikte kaydeder.
  // Girişli kullanıcı için hedef `local_game_saves` (sunucu — cihazlar arası,
  // çoklu oyun); misafir için (ya da Supabase yapılandırılmamışsa) mevcut
  // localStorage tekil-slot davranışı AYNEN kalır. Girişli kullanıcıda
  // localStorage'a hiç yazılmaz — sunucu tek doğruluk kaynağı olduğundan iki
  // ayrı yerde aynı oyunun mükerrer terk-edilme cezasına yol açması
  // engellenir; olası bir eski (giriş öncesi) localStorage kaydı da burada
  // temizlenir. `savedGame` doluyken (misafir, henüz RESUME_SAVED ile
  // açılmamış bir kayıt Setup'ta bekliyorken) clearGameState() ÇAĞIRILMAZ —
  // aksi halde bu effect ilk render'da kaydı kullanıcı hiç görmeden anında
  // silerdi.
  useEffect(() => {
    if (state.phase === 'play' && !state.isGameOver) {
      // Girişli kullanıcıda giriş ÖNCESİNDEN kalmış olabilecek misafir
      // kaydını her hâlükârda temizle — sunucu tek doğruluk kaynağı.
      if (user && isSupabaseConfigured) clearGameState();
      // ⚠ HENÜZ BAŞLAMAMIŞ OYUN (turnCount<2) HİÇ KALICILAŞTIRILMAZ.
      // 31 Ağustos 2026, bir kullanıcı bildirdi: *"oyundayken hiç hamle
      // yapmadan giriş yaparsan YZ oyunlar 1 gösteriyor ve oyun orada
      // bekliyor"*. Öncesinde bu effect turnCount'a BAKMADAN yazıyordu ve
      // hiç oynanmamış kaydı silmek `handleLogoClick`e bırakılmıştı — yani
      // TEK bir çıkış yolunda yapılan telafi edici bir eylemdi. Başka her
      // çıkış (yeniden yükleme, sekme/uygulama kapatma, giriş yapıp farklı
      // gezinme) hayalet bir "Devam Eden Oyun" bırakıyordu.
      // ÖLÇÜLDÜ — misafir yolu Playwright'ta birebir üretildi: oyunda
      // localStorage'a `turnCount: 0` yazılıyor, sayfa yeniden yüklenince
      // kayıt duruyor, Setup "Devam Eden…" satırını ve "Yapay Zeka ile 1"
      // rozetini gösteriyor. Bulut yolu üretim verisinde doğrulandı: 83
      // kaydın 5'i turnCount<2, 5 ayrı kullanıcıda, en eskisi 31 Temmuz.
      // Yazmamak telafiyi gereksiz kılıyor — her çıkış yolu kendiliğinden
      // doğru oluyor. Kaybedilen tek şey "insan ilk hamlesini yaptı, YZ
      // henüz cevap vermedi" penceresi; bu proje o durumu ZATEN atılabilir
      // sayıyor (`handleLogoClick` onu siliyor, 7 günlük -2 cezası da
      // `turnCount<2` kayıtlara hiç uygulanmıyor). Eşik projenin her yerde
      // kullandığı "gerçekten başladı" eşiğiyle AYNI.
      if (state.turnCount < 2) return;
      if (user && isSupabaseConfigured) {
        if (!activeSaveIdRef.current) activeSaveIdRef.current = crypto.randomUUID();
        const id = activeSaveIdRef.current;
        const uid = user.id;
        const snapshot = state;
        if (saveDebounceRef.current) clearTimeout(saveDebounceRef.current);
        saveDebounceRef.current = setTimeout(() => {
          saveDebounceRef.current = null;
          void enqueueSaveWrite(() => writeCloudSave(id, uid, snapshot));
        }, 600);
      } else {
        saveGameState(state);
      }
      return;
    }
    if (saveDebounceRef.current) {
      clearTimeout(saveDebounceRef.current);
      saveDebounceRef.current = null;
    }
    if (state.isGameOver) {
      // Oyun gerçekten bitti — sunucudaki devam-eden kaydı (varsa) sil.
      // Bekleyen bir debounce'lu kayıt varsa (yukarıda az önce temizlendi)
      // artık gönderilmeyecek — devam kaydını silme işleminin ardından
      // gecikmeli/eski bir upsert'in onu diriltmesi istenmez.
      if (activeSaveIdRef.current && user) {
        const id = activeSaveIdRef.current;
        const uid = user.id;
        void enqueueSaveWrite(() => deleteCloudSave(id, uid));
        activeSaveIdRef.current = null;
      } else if (activeSaveIdRef.current) {
        activeSaveIdRef.current = null;
      }
      if (!savedGame) clearGameState();
      return;
    }
    // Kurulum ekranına dönüldü (ABANDON). turnCount>=2 olan (gerçekten
    // başlamış) bir oyun için girişli kullanıcının sunucudaki kaydı BİLEREK
    // silinmez — "Devam Eden Oyun" listesinde kalmaya devam eder; ref yalnızca
    // bir sonraki oyunun yeni bir id alması için sıfırlanır. turnCount<2 iken
    // kayıt zaten `handleLogoClick` (App.tsx) tarafından dispatch'ten ÖNCE
    // silinip `activeSaveIdRef.current` null'landığından burada tekrar
    // silinecek bir şey kalmaz (bkz. 1 Ağustos 2026 notu, handleLogoClick).
    // Misafir için mevcut davranış aynen korunur: `savedGame` doluysa
    // (henüz Setup'ta gösterilmemiş bir kayıt) localStorage silinmez.
    activeSaveIdRef.current = null;
    if (!savedGame) clearGameState();
  }, [state, savedGame, user]);

  // Offline nedeniyle sunucuya kaydedilemeyip kuyruğa alınmış bitmiş oyun
  // sonuçlarını (bkz. gameSync.ts) bağlantı geri gelir gelmez tekrar
  // göndermeyi dener: açılışta, `online` olayında ve giriş durumu
  // değiştiğinde (offline'da kullanılan eski oturum süresi dolup kullanıcı
  // yeniden giriş yaptığında da).
  useEffect(() => {
    void flushPendingGames();
    window.addEventListener('online', flushPendingGames);
    return () => window.removeEventListener('online', flushPendingGames);
  }, [user]);

  // Bir arkadaşlık davet linkinden (/davet/:token, FriendInvitePage.tsx)
  // gelip oturum açan kullanıcı için bekleyen bir davet token'ı varsa burada
  // işler — normalde FriendInvitePage bunu kendisi kabul eder, ama e-posta
  // doğrulaması açıkken taze bir kayıt doğrulama linkine tıklanana kadar
  // oturum açmaz ve o link genelde /davet/:token'a değil uygulamanın köküne
  // döner; bu fallback o durumda daveti yine de kaybetmemeyi sağlar (bkz.
  // friendInvite.ts'teki read-then-clear kuyruk).
  useEffect(() => {
    if (!user) return;
    const token = takePendingInviteToken();
    if (token) void acceptFriendInvite(token).catch((err) => console.error('acceptFriendInvite (pending token):', err));
  }, [user]);

  // Offline nedeniyle gönderilemeyip kuyruğa alınmış "Görüş Bildir" mesajlarını
  // (bkz. feedbackSync.ts) bağlantı geri gelir gelmez tekrar dener. Oyun
  // kayıtlarının aksine oturum durumuna bağlı değildir (anonim gönderim
  // serbest), bu yüzden yalnızca açılışta ve `online` olayında çalışır.
  useEffect(() => {
    void flushPendingFeedback();
    window.addEventListener('online', flushPendingFeedback);
    return () => window.removeEventListener('online', flushPendingFeedback);
  }, []);

  // Yukarıdaki lazy init sırasında (loadGameState) 7 gün hareketsizlik
  // yüzünden süresi dolmuş sayılıp silinen bir oyun varsa, o kayıt burada
  // (mount'ta, bir kez) teslim olarak işlenir. Kuyruk read-then-clear
  // olduğundan StrictMode'un dev'de effect'i iki kez çalıştırması
  // zararsızdır — ikinci okuma boş döner.
  useEffect(() => {
    const pending = takePendingAbandonedGame();
    // Oyun gerçekten başlamışsa (turnCount>=2 — en az bir tam hamle
    // alışverişi) bu, hesap sahibi için gecikmeli bir teslim sayılır — -2
    // k-lig cezası uygulanır. Bu artık hesap sahibinin -2 alabileceği TEK
    // yol: logo tıklaması artık anlık teslim istemiyor (bkz.
    // handleLogoClick), yalnızca bu 7 günlük süre aşımı devreye giriyor.
    // Misafirse (o an giriş yoksa) saveGameDurable normal bitişteki gibi
    // kaydı offline kuyruğa alır, kişi ileride giriş/kayıt olursa hesabına
    // işlenir. Hiç oynanmamış (turnCount<2) bir kayıt ceza almadığından
    // telemetriye de hiç girmez.
    if (pending?.state && pending.state.turnCount >= 2) {
      // `expiredAtMs` terk anını (son etkinlik + 7 gün) taşır; bu effect'in
      // koştuğu an DEĞİL. Alan yoksa (bu değişiklikten önce kuyruğa girmiş
      // kayıt) eski davranışa, yani "şimdi"ye düşülür.
      const finishedAtMs = pending.expiredAtMs;
      void logGameFinish(
        pending.playerCount,
        pending.durationSeconds,
        pending.multiSession,
        true,
        undefined,
        finishedAtMs,
      );
      const record = buildGameRecord(pending.state, true, 0, finishedAtMs);
      if (record) void saveGameDurable(record);
    }
  }, []);

  // Oynanan kelime(ler)e tıklanınca gösterilen anlam penceresi. Bir hamlede
  // birden fazla kelime oluştuysa hepsi listelenir.
  const [meaning, setMeaning] = useState<{
    entries: { word: string; data: WordMeaning | null; loading: boolean }[];
  } | null>(null);

  // Torba (kalan taşlar) penceresi.
  const [showTiles, setShowTiles] = useState(false);

  // Oyun geçmişi penceresi (tüm oyuncuların hamleleri) — hem oynarken
  // Board'daki linkten, hem oyun bitince GameOver ekranından açılabilir.
  const [showHistory, setShowHistory] = useState(false);

  // Oyun bitince GameOver ekranından açılabilen "Görüş Bildir" formu.
  const [showFeedback, setShowFeedback] = useState(false);

  // Admin'in gönderdiği e-postalardaki ("noreply — cevap için tıklayın")
  // linkten (?contact=1) açılan genel "Görüş Bildir" formu — oyun fazından
  // bağımsız (bkz. supabase/functions/_shared/email.ts, buildSupportReplyNoticeHtml).
  // Link'e gömülü ?re=<id> varsa (hangi mesaja cevaben geldiği), yeni geri
  // bildirim o mesaja bağlanabilsin diye contactRelatedTo'da tutulur.
  const [showContactFeedback, setShowContactFeedback] = useState(false);
  const [contactRelatedTo, setContactRelatedTo] = useState<string | null>(null);
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('contact') !== '1') return;
    setShowContactFeedback(true);
    setContactRelatedTo(params.get('re'));
    params.delete('contact');
    params.delete('re');
    const rest = params.toString();
    window.history.replaceState(null, '', window.location.pathname + (rest ? `?${rest}` : ''));
  }, []);

  // Karşılama katmanının (18 Ağustos 2026) "Giriş" butonundan gelen istek.
  // `AuthModal`'ı açan state `UserMenu`'nün İÇİNDE (`setModal('auth')`) ve
  // dışarıdan tetiklenecek bir yolu yok; katman da React ağacının DIŞINDA
  // (statik HTML, bkz. src/landing/). Aradaki köprü olarak `?contact=1`'in
  // BİREBİR aynı kalıbı kullanılıyor: parametre okunur, pencere açılır,
  // parametre `history.replaceState` ile URL'den temizlenir.
  const [showLoginModal, setShowLoginModal] = useState(false);
  // Katmanın alt satırındaki hukuki bağlantılar da AYNI köprüden geçiyor
  // (`?kosullar=1` / `?gizlilik=1`) — o iki pencere `Setup.tsx`'in kendi
  // state'inde yaşadığından dışarıdan açılamıyor, bu yüzden burada ayrıca
  // render ediliyorlar. Üç parametre tek effect'te okunuyor: aynı anda
  // yalnızca biri gelebilir ve hepsi tek bir `replaceState` ile temizlenmeli.
  const [landingLegal, setLandingLegal] = useState<'terms' | 'privacy' | null>(null);
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const giris = params.get('giris') === '1';
    const kosullar = params.get('kosullar') === '1';
    const gizlilik = params.get('gizlilik') === '1';
    if (!giris && !kosullar && !gizlilik) return;
    if (giris) setShowLoginModal(true);
    if (kosullar) setLandingLegal('terms');
    else if (gizlilik) setLandingLegal('privacy');
    params.delete('giris');
    params.delete('kosullar');
    params.delete('gizlilik');
    const rest = params.toString();
    window.history.replaceState(null, '', window.location.pathname + (rest ? `?${rest}` : ''));
  }, []);

  // Oyun sonu ekranı kapatıldı mı (X'e basıldı mı) — board'u görmek için.
  const [gameOverDismissed, setGameOverDismissed] = useState(false);
  useEffect(() => {
    if (state.isGameOver) setGameOverDismissed(false);
  }, [state.isGameOver]);

  // Joker taş konurken hangi harfe dönüşeceğini seçme penceresi. `editing`
  // doluyken taş rafta değil tahtada zaten duruyor — seçim rafa yeni bir
  // PLACE_TILE değil, mevcut hücrenin wildLetter'ını güncelleyen SET_WILD_LETTER'a gider.
  const [pendingWild, setPendingWild] = useState<
    { r: number; c: number; rackIndex?: number; editing?: boolean } | null
  >(null);

  // Pas geçme onay popup'ı.
  const [showPassConfirm, setShowPassConfirm] = useState(false);
  /**
   * Oyun bitince "Tekrar Oyna" onayı. Canlı taraftaki (OnlineGameScreen)
   * aynı butonun yerel karşılığı — orada davet gönderildiğinden onay şart,
   * burada da AYNI konumda duran OYNA butonu oyun bitince altındaki
   * parmakla birlikte anlam değiştirdiğinden kazara dokunuşa karşı aynı
   * koruma uygulanıyor (bkz. kök CLAUDE.md, "Tekrar Oyna").
   */
  const [showRematchConfirm, setShowRematchConfirm] = useState(false);

  // Setup ekranında "Oyunu Başlat" tıklandığında Tutorial ilk kez
  // görülmemişse, oyun ekranı açılır açılmaz burada gösterilir.
  const [showPostStartTutorial, setShowPostStartTutorial] = useState(false);

  /**
   * YEREL (YZ) bir oyunun BAŞLATILMASI — `START` dispatch eden İKİ yer de
   * (Setup'ın "Oyunu Başlat"ı ve oyun sonu "Tekrar Oyna") buradan geçer.
   *
   * Tek bir yardımcıda toplanmasının sebebi telemetri: `game_starts`
   * satırını yazan yer burası (bkz. `logGameStart`, ROADMAP #9). İki çağrı
   * yerini ayrı ayrı yamamak, ileride üçüncü bir başlatma yolu eklendiğinde
   * sessizce eksik sayıma yol açardı — huninin "Başlayan" adımı da o gün
   * kimseye söylemeden bozulurdu.
   *
   * `RESUME_SAVED` BİLEREK dahil DEĞİL: devam eden bir oyuna dönmek yeni bir
   * başlangıç değil, aksi halde aynı oyun her cihaz/oturum dönüşünde tekrar
   * sayılırdı.
   */
  const startLocalGame = (players: PlayerSetup[], aiLevel?: AiLevel) => {
    // Zorluk (ROADMAP #23 Faz 3): Normal payload'a GİRMEZ — Faz 2 sözleşmesi
    // "alan yok = Normal" (eski kayıtlar, golden'lar, port codec'i, bulut
    // kaydı, `games.ai_level` null); `'normal'` yazmak aynı şeyi ikinci bir
    // biçimde söylemek olurdu. Yalnızca Kolay/Zor state'e yazılır; oyun
    // boyunca değişmez (değiştiren action YOK).
    dispatch({ type: 'START', players, ...(aiLevel && aiLevel !== 'normal' ? { aiLevel } : {}) });
    // Yeni oyun/rövanş zoom'u sıfırlar (port `_handleRematch` ile aynı).
    boardZoom.reset();
    // Fire-and-forget: telemetri hatası oyunu etkilemez.
    // `!user` = misafir başlangıcı — huninin "Başlayan" adımı yalnızca bunları
    // sayıyor (bkz. `logGameStart` ve `game_starts.is_guest`).
    void logGameStart(players.length, getOrCreateAnonId(), getStoredUtmSource(), !user);
  };

  // Setup'taki "Devam Eden Oyun" satırına tıklanınca: kaydı reducer'a
  // uygulayıp `savedGame`'i temizler — bundan sonra yukarıdaki save/clear
  // effect'i tamamen `state`e göre çalışır (bkz. o effect'teki not).
  const handleResumeSavedGame = () => {
    if (!savedGame) return;
    dispatch({ type: 'RESUME_SAVED', state: savedGame.state });
    setSavedGame(null);
  };

  // Girişli kullanıcının `cloudSaves` listesindeki bir satıra tıklanınca:
  // `activeSaveIdRef`'i (dispatch'ten ÖNCE) bu kaydın id'sine sabitler ki
  // yukarıdaki autosave effect'i yeni bir satır açmak yerine AYNI satırı
  // güncellemeye devam etsin — sonra reducer'a uygulanır ve listeden çıkarılır.
  const handleResumeCloudSave = (save: LocalGameSave) => {
    activeSaveIdRef.current = save.id;
    dispatch({ type: 'RESUME_SAVED', state: save.state });
    setCloudSaves((prev) => (prev ? prev.filter((s) => s.id !== save.id) : prev));
  };

  // Logo tıklaması artık her durumda (onay sorulmadan) doğrudan Setup'a
  // döner — Canlı oyundaki "←"in aynısı (bkz. OnlineGameScreen.tsx). Oyun
  // gerçekten "başlamışsa" (turnCount>=2 — en az bir tam hamle alışverişi;
  // eski "Çık" akışındaki gameStarted eşiğiyle AYNI, bilerek korundu),
  // mevcut `state` aynen `loadGameState()`'in ürettiği şekle (`SavedGame`)
  // sarılıp `savedGame`'e yazılır — bu, save/clear effect'inin (yukarı)
  // `clearGameState()` çağırmasını engeller (savedGame artık dolu) VE
  // Setup'ta "Devam Eden Oyun" satırını hemen gösterir; `handleResumeSavedGame`
  // tıklanınca kaldığı yerden aynen devam eder. Hesap sahibi hiç dönmezse
  // 7 günlük terk edilme kuralı (gameStorage.ts) gecikmeli -2 cezasını
  // zaten otomatik uyguluyor. Henüz başlamamışsa (hiç hamle yokken ya da
  // hesap sahibi ilk hamlesini yapıp karşı taraf henüz cevap vermemişken)
  // `savedGame` hiç doldurulmaz — save/clear effect bu durumda ABANDON
  // sonrası `clearGameState()`'i çağırıp localStorage'daki autosave
  // kaydını da temizler, yani Setup'ta hiçbir "Devam Eden Oyun" izi
  // kalmaz ve gecikmeli ceza da hiç devreye girmez.
  //
  // 1 Ağustos 2026 — girişli kullanıcı için de aynı "hiç iz bırakma" davranışı:
  // öncesinde bu turnCount<2 dalı yalnızca misafiri (localStorage) kapsıyordu,
  // girişli kullanıcının `local_game_saves` satırı BİLİNÇLİ OLARAK silinmiyordu
  // (7 günlük süpürmeye bırakılıyordu, bkz. refreshCloudSaves). Kullanıcı
  // isteğiyle bu asimetri kaldırıldı: hiç başlamamış (turnCount<2) bir oyunu
  // terk eden girişli kullanıcının sunucudaki kaydı da burada HEMEN silinir —
  // "Devam Eden Oyunlar" listesinde 7 gün boyunca öylesine açılıp hiç
  // oynanmamış bir satır olarak beklemez. turnCount>=2 olan (gerçekten
  // başlamış) oyunlar bu değişiklikten etkilenmedi, eskisi gibi listede kalır.
  //
  // 3 Ağustos 2026 (regresyon düzeltmesi) — `else if` dalına `turnCount < 2`
  // koşulu eklendi. Kritik #1 düzeltmesi ilk daldan girişli kullanıcıyı
  // çıkarınca (`!user || !isSupabaseConfigured`), turnCount>=2 olan girişli
  // oyunlar da bu dala düşüp sunucudaki kaydın SİLİNMESİNE yol açıyordu —
  // yani devam eden gerçek bir oyunu logoya basarak terk etmek onu "Devam
  // Eden Oyunlar"dan tamamen yok ediyor, üstelik 7 günlük gecikmeli -2
  // cezasını da (silinen bir kayıt terk edilmiş sayılamayacağı için)
  // atlatıyordu. Dalın kapsamı, en baştaki niyetine (yalnızca hiç
  // oynanmamış kayıtları anında sil) geri çekildi.
  const handleLogoClick = () => {
    const abandoningMidGame = state.phase === 'play' && !state.isGameOver;
    if (abandoningMidGame && state.turnCount >= 2 && (!user || !isSupabaseConfigured)) {
      // Yalnızca misafir için: girişli kullanıcının kaydı zaten sunucuda
      // (`local_game_saves`, autosave effect'i) duruyor ve `cloudSaves`
      // üzerinden gösteriliyor — `savedGame`'i burada da doldurmak, hesap
      // çıkışından sonra bu oyunun "misafirin devam eden oyunu" olarak
      // başka birine (ya da sonraki misafir oturumuna) sızmasına yol açardı,
      // çünkü `[user?.id]` değişince `savedGame` hiçbir yerde temizlenmiyor.
      setSavedGame({ state, savedAt: Date.now() });
    } else if (
      abandoningMidGame &&
      state.turnCount < 2 &&
      user &&
      isSupabaseConfigured &&
      activeSaveIdRef.current
    ) {
      const id = activeSaveIdRef.current;
      // Bekleyen (henüz ateşlenmemiş) debounce'lu upsert'i ÖNCE iptal et —
      // aksi halde silme kuyruğa girdikten sonra o zamanlayıcı ateşlenip
      // satırı yeniden yazabilirdi. (Aşağıdaki ABANDON dispatch'i zaten
      // save/clear effect'i üzerinden de iptal ediyor; burada senkron olarak
      // yapmak sıralamayı effect'lerin çalışma anından bağımsız kılıyor.)
      if (saveDebounceRef.current) {
        clearTimeout(saveDebounceRef.current);
        saveDebounceRef.current = null;
      }
      void enqueueSaveWrite(() => deleteCloudSave(id, user.id));
      activeSaveIdRef.current = null;
    }
    dispatch({ type: 'ABANDON' });
  };

  // Kurulum ekranındaki üst sekme: yerel (2/4 kişilik, anında başlar) ya da
  // Canlı (arkadaş daveti/kabulü — Faz 2). Bilinçli olarak Setup'ın kendi
  // 2/4 kişilik seçicisinin içine değil, onun yanına ayrı bir sekme olarak
  // eklendi — iki mod farklı zihinsel modeller taşıyor (bkz. proje notları).
  const [mainView, setMainView] = useState<'local' | 'live'>('local');
  // Çıkışta (ve doğrudan hesap değişiminde) sekme seçimi varsayılana döner.
  // Bu bileşen çıkışta unmount OLMADIĞINDAN `mainView` aksi halde bir sonraki
  // oturuma taşınıyordu: Canlı sekmesindeyken çıkıp başka bir hesapla giren
  // kullanıcı, Canlı'da hiçbir bekleyen işi olmasa da (ve rozet 0 iken)
  // doğrudan "Arkadaşınla > Devam Edenler" ile karşılaşıyordu — üstelik
  // Setup'taki giriş varsayılanı (`applyLoginDefaultOnce`) yalnızca 'live'e
  // GEÇİREBİLDİĞİNDEN, yani hiçbir zaman 'local'e geri çekmediğinden, bu
  // taşınan seçimi düzeltebilecek bir şey yoktu.
  //
  // Sıfırlama BİLEREK yalnızca "önceden girişliydi" durumunda çalışır
  // (`prev !== null`): misafirken "Arkadaşınla" sekmesine girip oradaki
  // uyarıdan giriş yapan kullanıcı (null → hesap) tam da Canlı'yı görmek
  // istediğinden o sekmede bırakılır. Karar `user` REFERANSINA değil
  // `user.id`'ye bakar — `useAuth` her `onAuthStateChange` olayında
  // (TOKEN_REFRESHED dahil) yeni bir `User` nesnesi veriyor, referansa
  // bakmak saatler sonra kullanıcıyı habersizce sekmeden atardı.
  const lastAuthUserIdRef = useRef<string | null>(user?.id ?? null);
  useEffect(() => {
    const id = user?.id ?? null;
    const prev = lastAuthUserIdRef.current;
    if (prev === id) return;
    lastAuthUserIdRef.current = id;
    if (prev !== null) setMainView('local');
  }, [user]);

  // Açık olan Canlı oyun (Faz 3, 4. adım) — Setup/LiveGamesTab'daki "Devam
  // Eden" bir oyuna dokununca dolar; doluyken tüm normal kurulum/yerel oyun
  // ağacının yerine OnlineGameScreen render edilir (aşağıya bkz.).
  const [onlineGame, setOnlineGame] = useState<OnlineGame | null>(null);

  // Kullanıcı değişince (çıkış/farklı hesapla giriş — aynı sekmede hesap
  // değiştirme testlerinde ortaya çıktı) açık kalan bir Canlı oyun ekranı
  // otomatik kapanmalı; aksi halde yeni oturum açan kişi, eski kullanıcının
  // o an içinde olduğu oyuna (o oyunun katılımcısıysa) doğrudan düşüyordu —
  // Setup/Canlı sekmesi hiç görünmeden.
  useEffect(() => {
    setOnlineGame(null);
  }, [user?.id]);

  // Service worker güncellemesinin (`pwa.ts`) kullanıcıyı GERÇEKTEN oyun
  // ekranındayken kesintiye uğratmasını önlemek için "şu an aktif oynanıyor
  // mu" bayrağı — yerel 'play' fazı ya da açık bir Canlı oyun ekranı.
  useEffect(() => {
    setActivelyPlaying((state.phase === 'play' && !state.isGameOver) || !!onlineGame);
  }, [state.phase, state.isGameOver, onlineGame]);

  // "Ana Ekrana Ekle" ile kurulan PWA ikonu üzerinde (masaüstü/dock/görev
  // çubuğu) kırmızı yuvarlak/beyaz sayı rozeti — Setup'taki sekme
  // rozetleriyle AYNI mantık, ama App.tsx seviyesinde (hangi ekran açık
  // olursa olsun) çalışsın diye ayrı bir hook'ta (bkz. useAppIconBadge.ts).
  // `localSaveCount` Setup.tsx'teki formülle birebir aynı: girişli
  // kullanıcıda `cloudSaves`'in uzunluğu, misafirde tekil `savedGame`
  // kaydının 0/1'i. `isOnSetupScreen`, hem yerel oyundan ("Çık"/ABANDON,
  // state.phase 'play'→'setup') hem bir Canlı oyundan ("←", onlineGame
  // null'a döner) Setup'a dönüşü kapsar — ikisi de ayrı state olduğundan
  // (`state.phase` Canlı oyun ekranındayken hiç değişmiyor) sadece
  // `state.phase`'i izlemek Canlı dönüşünü kaçırırdı.
  const localSaveCount = user ? (cloudSaves?.length ?? 0) : savedGame ? 1 : 0;
  const isOnSetupScreen = state.phase === 'setup' && !onlineGame;
  useAppIconBadge(user?.id, localSaveCount, isOnSetupScreen);

  // Rakip köşeye giriş onay popup'ı.
  const [invasionConfirm, setInvasionConfirm] = useState<
    { ownerName: string; ownerPts: number }[] | null
  >(null);

  // Bu iki dahili onay popup'ı Modal.tsx'i kullanmıyor (kendi basit
  // işaretlemeleri var) ama aynı odak hapsi/Escape/geri-dönüş davranışını
  // paylaşıyor.
  const passConfirmRef = useModalA11y(showPassConfirm, () => setShowPassConfirm(false));
  const invasionConfirmRef = useModalA11y(!!invasionConfirm, () => setInvasionConfirm(null));

  // Sunucu kelime doğrulaması sırasında true — butonu devre dışı bırakır.
  const [validating, setValidating] = useState(false);
  /**
   * Son "Oyna" denemesinin sunucu kaynaklı reddi — `OnlineGameScreen`'deki
   * `submitError`in yerel karşılığı, aynı gerekçeyle (14 Ağustos 2026).
   *
   * Buradaki TEK ulaşılabilir dal sunucu sözlüğünün kelimeyi reddetmesi:
   * `moveStatus` YEREL sözlükle hesaplandığından, iki sözlük ayrışırsa
   * (`src/data/words.ts` ↔ `public.words`, ayrı üretilen iki kaynak) taslak
   * yerelde geçerli görünür, aşağıdaki "Oyna tuşuyla kelimeyi onayla."
   * türetilir ve sunucunun "… sözlükte yok" mesajı hiç görünmeden hamle
   * sessizce gerçekleşmez. Mobil portun yerel ekranında bu dal YOK (tüm
   * sözlük pakette, sunucuya hiç sorulmuyor) — bu yüzden orası bilerek
   * değişmedi.
   */
  const [submitError, setSubmitError] = useState<string | null>(null);
  // Sunucu doğrulaması başarılıysa true; reducer'a skipWordCheck iletilir.
  const pendingSkipWordCheck = useRef(false);

  // ── Taş sürükleme (fare + dokunmatik) ───────────────────────────────────
  // Jest sırasında değişen anlık veri `dragRef`de tutulur (her pointer
  // olayında render tetiklemeden okunup güncellenir); `ghost` yalnızca
  // gerçek bir sürükleme başladığında (eşik aşılınca) set edilir ve
  // sürüklenen taşın parmak/imleci takip eden görselini tetikler.
  // Tahta yakınlaştırması (1 Eylül 2026, kullanıcı kararı: "her yerde aynı
  // deneyim"). Sürükleme sürerken pan HİÇ başlamaz — `dragRef` bayrağı
  // portun hit-test sırasının web karşılığı (bkz. useBoardZoom).
  // İkinci argüman: tahta ŞU AN ekranda mı — `App` Setup'ı da render
  // ettiğinden tanıtım balonunun sayacı orada artmamalı (bkz. useBoardZoom).
  const boardZoom = useBoardZoom(
    () => dragRef.current !== null,
    state.phase !== 'setup',
  );
  const dragRef = useRef<{
    source: DragSource;
    startX: number;
    startY: number;
    moved: boolean;
  } | null>(null);
  const [ghost, setGhost] = useState<{
    x: number;
    y: number;
    source: DragSource;
    overKey: string | null;
    overValid: boolean;
  } | null>(null);

  // Bir taş sürüklemesi sürerken (raftan ya da tahtadan) dokunmatik
  // tarayıcının sayfayı kaydırmasını engelle. `touch-action: none` çoğu
  // durumda yeterli ama parmak hızlı hareket ettiğinde ya da pointer
  // capture bazı tarayıcılarda güvenilmez olduğunda devreye girmeyebiliyor;
  // bu, sürükleme sırasında kaydırmayı kesin olarak engelleyen bir yedek.
  useEffect(() => {
    const preventScrollWhileDragging = (e: TouchEvent) => {
      if (dragRef.current) e.preventDefault();
    };
    document.addEventListener('touchmove', preventScrollWhileDragging, { passive: false });
    return () => document.removeEventListener('touchmove', preventScrollWhileDragging);
  }, []);

  // Ana ekrana eklenmiş (standalone) uygulamada bir taş sürüklenirken
  // uygulama arka plana düşerse (bildirim, kontrol merkezi, ekran kilidi
  // vb.) WebKit bazen `pointerup`/`pointercancel` olayını hiç göndermiyor —
  // sürüklenen taşın hayalet görseli ekranda asılı kalıp arayüz kilitleniyor
  // (oyun state'i etkilenmiyor, sadece görsel). Sayfa görünürlüğü/odağı
  // değiştiğinde sürükleme hâlâ sürüyorsa burada elle temizleniyor.
  useEffect(() => {
    const clearStuckDrag = () => {
      if (dragRef.current) {
        dragRef.current = null;
        setGhost(null);
      }
    };
    document.addEventListener('visibilitychange', clearStuckDrag);
    window.addEventListener('blur', clearStuckDrag);
    return () => {
      document.removeEventListener('visibilitychange', clearStuckDrag);
      window.removeEventListener('blur', clearStuckDrag);
    };
  }, []);

  const openMeaning = (words: string[]) => {
    const unique = [...new Set(words)];
    if (unique.length === 0) return;
    setMeaning({
      entries: unique.map((word) => ({ word, data: null, loading: true })),
    });
    for (const word of unique) {
      void fetchMeaning(word).then((data) => {
        setMeaning((cur) =>
          cur
            ? {
                entries: cur.entries.map((e) =>
                  e.word === word ? { ...e, data, loading: false } : e,
                ),
              }
            : cur,
        );
      });
    }
  };


  // Oyun bitince giriş yapmış kullanıcının sonucunu kaydet (YZ'ye karşı oyunlar
  // dahil). 1. oyuncu zaten teslim olarak ayrıldıysa kaydı o an tutulmuştur —
  // burada tekrar kaydetmeyiz.
  useEffect(() => {
    if (!state.isGameOver || state.phase !== 'play') return;
    if (state.players[0]?.surrendered) return;
    const record = buildGameRecord(state, false);
    // Kayıt sunucuya düşünce k-lig ödül kontrolü — games INSERT trigger'ı
    // (`games_award_league_rewards`) ödülü aynı transaction'da açtığından
    // hemen ardından çekmek güvenli. Misafirde kayıt kuyruğa girer, kontrol
    // boş döner; ödül girişten sonraki flush'ta açılıp ilk kontrolde görünür.
    if (record) void saveGameDurable(record).then(() => requestLeagueRewardCheck());
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.isGameOver]);

  // Oyun bitince (misafir dahil, kompozisyon fark etmeksizin) anonim
  // başlatma/bitirme + süre sayaçları için admin panelinin Büyüme > Oyun
  // grafiğine veri sağlar — skor/kelime gibi kişisel veri içermez.
  useEffect(() => {
    if (!state.isGameOver || state.phase !== 'play') return;
    const durationSeconds = Math.max(0, Math.round((Date.now() - Date.parse(state.startedAt)) / 1000));
    // user?.id zaten useAuth()'tan biliniyor — logGameFinish'in kendi
    // içinde AYRICA bir getUser() ağ turu yapmasını (yukarıdaki
    // saveGameDurable/buildGameRecord effect'iyle aynı anda tetiklendiğinden
    // gereksiz ikinci bir round-trip olurdu) önlemek için geçiliyor.
    void logGameFinish(
      state.players.length,
      durationSeconds,
      state.multiSession,
      state.endReason === 'surrender',
      user?.id ?? null,
    );
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.isGameOver]);

  // Oyun devam ederken giriş yapılırsa 1. oyuncunun adını güncelle.
  useEffect(() => {
    if (state.phase !== 'play') return;
    const accountName =
      profile?.display_name ||
      profile?.first_name ||
      (user?.email && !profileLoading ? user.email.split('@')[0] : null);
    if (!accountName) return;
    const p0 = state.players[0];
    if (p0 && !p0.isAI && p0.name !== accountName) {
      dispatch({ type: 'RENAME_PLAYER', index: 0, name: accountName });
    }
  }, [user, profile, profileLoading, state.phase]);

  // YZ sırası: kısa bir düşünme gecikmesiyle otomatik oyna.
  const aiTurn =
    state.phase === 'play' &&
    !state.isGameOver &&
    !!state.players[state.current]?.isAI;
  useEffect(() => {
    if (!aiTurn || !wordsReady) return;
    const t = setTimeout(() => dispatch({ type: 'AI_PLAY' }), AI_THINK_MS);
    return () => clearTimeout(t);
  }, [aiTurn, wordsReady, state.current, state.turnCount]);

  // Taslak değiştiği an son "Oyna" denemesinin reddi geçmişe aittir
  // (OnlineGameScreen'deki `placedSignature` effect'iyle aynı).
  const placedSignature = Object.entries(state.placed)
    .map(([k, t]) => `${k}:${t.letter}${t.wildLetter ?? ''}`)
    .sort()
    .join('|');
  useEffect(() => {
    setSubmitError(null);
  }, [placedSignature]);

  // Oyna'ya basmadan önce, tahtaya konan taşların anlık geçerlilik/puan
  // çerçevesi (yeşil/kırmızı). Yerel sözlükle kontrol edilir; sunucu
  // doğrulaması yalnızca Oyna'ya basınca (handlePlay) çalışır.
  const moveStatus = useMemo(() => {
    const placedKeys = Object.keys(state.placed);
    if (placedKeys.length === 0 || !wordsReady) return null;
    const current = state.players[state.current];
    if (!current) return null;

    const result = validatePlacement(
      state.board,
      state.placed,
      state.current,
      current.corners,
      isFirstMove(state),
    );
    // Oluşan tüm kelimelerin hücrelerini birleştir; Board bunun etrafına
    // tek, boşluksuz bir dış çerçeve çizer (ortak hücrelerde iç çizgi olmaz).
    const formed = getFormedWords(state.board, state.placed);
    const cells = formed.length > 0
      ? formed.flatMap((f) => f.coords)
      : (placedKeys.map((k) => k.split(',').map(Number)) as [number, number][]);

    return {
      valid: result.valid,
      reason: result.reason,
      cells,
      score: calcScore(state.board, state.placed, state.bonuses),
    };
    // state.bonuses eklendi — calcScore onu okuyor, önceden eksikti (şu ana
    // kadar zararsızdı çünkü bonuses yalnızca oyun başında bir kez kurulup
    // SYNC_ONLINE_STATE dışında hiç değişmiyor, o durumda da state.board
    // zaten aynı anda değişip memoyu tetikliyordu).
  }, [state.placed, state.board, state.players, state.current, state.bonuses, wordsReady]);

  // Oyna'ya basmadan önce, geçersiz bir hamle varsa sebebini canlı olarak
  // alttaki mesaj alanında göster — oyuncu Oyna'ya basmadan neden geçersiz
  // olduğunu (köşe kuralı, sözlük vb.) hemen görsün.
  // GEÇERLİ taslakta metin state.message'tan OKUNMAZ, durumdan TÜRETİLİR
  // (6 Ağustos 2026, kullanıcı Canlı oyunda buldu ama sınıf ortaktı):
  // state.message "son yazan kazanır" bir alan — taslak dururken raftan taş
  // seçmeden boş hücreye dokunmak PLACE_TILE guard'ının "Önce bir harf seç."
  // metnini üstüne yazıyor, satır da moveStatus geçerli diye bunu YEŞİL
  // basıyordu (metin/renk çelişkisi). Geçerli taslak = her zaman
  // "Oyna tuşuyla kelimeyi onayla." — bayat imperatif mesaj gölgede kalır.
  // `submitError` türetilen nottan ÖNCE gelir — taslak yerelde geçerli
  // kalsa bile sunucunun reddi görünmek zorunda (bkz. tanımındaki gerekçe).
  const liveMessage = moveStatus && !moveStatus.valid && moveStatus.reason
    ? moveStatus.reason
    : submitError ?? (moveStatus?.valid
      ? 'Oyna tuşuyla kelimeyi onayla.'
      : state.message);
  const liveMessageType = moveStatus && !moveStatus.valid && moveStatus.reason
    ? 'err'
    : submitError
      ? 'err'
      : moveStatus?.valid
        ? 'ok'
        : state.messageType;

  // ── Şifre sıfırlama ────────────────────────────────────────────────────────
  // Sıfırlama e-postasındaki bağlantı tıklanıp bu sekmede recovery oturumu
  // açıldıysa, yeni şifre belirlenene kadar kurulum/oyun ekranlarının önüne geçer.
  if (passwordRecovery) {
    // Modalın ARKASI logo taşır — bomboş DEĞİL (29 Ağustos 2026, kullanıcı
    // cihazda bildirdi: *"Şifre değiştirme modalının arkası boş ekran. En
    // azından kelimeki logosu görünmeli."*). Bu ekrana kullanıcı bir
    // E-POSTA LİNKİNDEN düşüyor, yani uygulamayı henüz görmemiş olabilir:
    // beyaz bir sayfa üstünde şifre isteyen bir kutu, kimlik avı ekranından
    // ayırt edilemez. Logo, "doğru yerdesin"in en ucuz kanıtı.
    //
    // Boyut Setup'ın logosuyla AYNI (52) — bu ekran onun kardeşi, farklı bir
    // ölçü iki ekranı birbirine yabancılaştırırdı.
    return (
      <div className="min-h-[100dvh] w-full flex flex-col items-center justify-center gap-6">
        <LogoMark height={52} />
        <ResetPasswordModal onDone={clearPasswordRecovery} />
      </div>
    );
  }

  // ── Canlı oyun ekranı (Faz 3, 4. adım) ────────────────────────────────────
  // Kurulum/yerel oyun ağacının tamamen önüne geçer — Canlı oyunun state'i
  // Supabase'te yaşıyor, yerel `state`/`dispatch`'le hiç ilgisi yok.
  if (onlineGame && user) {
    return <OnlineGameScreen game={onlineGame} myUserId={user.id} onBack={() => setOnlineGame(null)} />;
  }

  // ── Kurulum ekranı ─────────────────────────────────────────────────────────
  if (state.phase === 'setup') {
    // Yalnızca GİRİŞSİZ (misafir) kullanıcıya gösterilir — bkz. aşağıdaki
    // yorum. `authLoading` sırasında da `false`: `UserMenu`'nün kendi
    // GİRİŞ/avatar kararıyla aynı "önce bilmeden gösterme" deseni.
    const showTanitimLink = !authLoading && !user;
    return (
      <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
        <div
          className={`w-full max-w-[460px] flex items-center px-3.5 pt-3 ${
            showTanitimLink ? 'justify-between' : 'justify-end'
          }`}
        >
          {/* Karşılama sayfasına dönüş (18 Ağustos 2026, kullanıcı isteği:
              "Hemen Oynaya basınca geri gelemiyorsun"). Katman DOM'dan
              siliniyor (bkz. main.tsx), dolayısıyla geri dönmenin tek yolu
              tam bir yeniden yükleme — `?tanitim=1` kapıya "bu sefer katmanı
              göster" diyen tek sinyal (bkz. scripts/landing-plugin.js).

              Düğme ÇIPLAK bir ok karakteri (18 Ağustos 2026, aynı gün ikinci
              tur, kullanıcı kararı) — erişilebilir ad `aria-label` üzerinden
              ("Tanıtım sayfası") doğru anlatılıyor, yalnızca GÖRÜNÜR metin
              sadeleşti. Punto/kutu `Modal.tsx`'in ✕ kapatma butonuyla AYNI
              ölçek (`text-lg`/`text-xl` bandı, `w-7 h-7` dokunma kutusu) —
              kullanıcı "bit kadar" (10px) bulunca aynı gün bir sonraki turda
              büyütüldü, icat edilmiş yeni bir sayı değil, projedeki mevcut
              köşe-ikon dilinin tekrarı.

              Glyph `←` (ok Unicode karakteri) → düz `<` (18 Ağustos 2026,
              aynı gün beşinci tur, kullanıcı: "O oku sevmedim. < kullan
              yerine") — yalnızca görünen KARAKTER değişti, `aria-label`/
              davranış/boyut AYNI kaldı.

              YALNIZCA GİRİŞSİZ kullanıcıda render ediliyor (aynı gün, üçüncü
              tur — kullanıcı sordu: "girişli kullanıcıda da geri ok çıkmamalı,
              öyle değil mi?"). Sebep: `?tanitim=1` dönen-kullanıcı sinyallerini
              (oturum DAHİL) bilerek atlıyor, yani girişli biri bu düğmeye
              basarsa `Landing.tsx`'in statik (auth'tan habersiz) başlığındaki
              GİRİŞ butonunu görüyordu — kendi oturumu açıkken bile. Katmanı
              auth-farkında yapmak (`Landing.tsx`'in "hiçbir hook/tarayıcı
              globali YOK" temel kısıtını ihlal ederdi) yerine, bu escape
              hatch'in girişli bir kullanıcı için zaten bir değeri olmadığı
              (kapı zaten girişliyi hiç göstermeden uygulamaya alıyor —
              düğme yalnızca `?tanitim=1` ile bunu BİLEREK deliyor) kabul
              edilip düğme koşulsuz gizlendi. `authLoading` sırasında da
              gizli — `UserMenu`'nün kendi GİRİŞ/avatar kararıyla aynı
              "önce bilmeden gösterme" deseni. */}
          {showTanitimLink && (
            <a
              href="/?tanitim=1"
              aria-label="Tanıtım sayfası"
              className="shrink-0 w-7 h-7 flex items-center justify-center rounded font-mono text-xl leading-none text-muted active:scale-90 transition-transform"
            >
              &lt;
            </a>
          )}
          <UserMenu />
        </div>
        <main className="w-full flex flex-col items-center">
          <Setup
            mainView={mainView}
            onMainViewChange={setMainView}
            onOpenLiveGame={setOnlineGame}
            savedGame={savedGame}
            onResumeGame={handleResumeSavedGame}
            cloudSaves={user ? cloudSaves : null}
            onResumeCloudSave={handleResumeCloudSave}
            onStart={(players, showTutorial, aiLevel) => {
              startLocalGame(players, aiLevel);
              if (showTutorial) setShowPostStartTutorial(true);
            }}
          />
        </main>
        <AddToHomeScreen />
        <LandscapeHint />
        {/* k-lig kutlama banner'ı — Setup'ta her zaman gösterilebilir
            (girişte/geçmişe dönük backfill'de bekleyen ödüller burada çıkar). */}
        <LeagueRewardsHost />
        {showContactFeedback && (
          <FeedbackModal
            source="general"
            relatedTo={contactRelatedTo}
            fromEmailLink
            onClose={() => setShowContactFeedback(false)}
          />
        )}
        {showLoginModal && <AuthModal onClose={() => setShowLoginModal(false)} />}
        {landingLegal === 'terms' && <TermsModal onClose={() => setLandingLegal(null)} />}
        {landingLegal === 'privacy' && <PrivacyModal onClose={() => setLandingLegal(null)} />}
      </div>
    );
  }

  // ── Oyun ekranı ──────────────────────────────────────────────────────────────
  const me = state.players[state.current];
  // Harf rafı: sıra bir insanda ise (aynı cihazdan sırayla oynanan hotseat
  // modunda birden fazla insan olabilir) HER ZAMAN o anki insanın kendi
  // rafı gösterilir; sıra bir YZ'deyse onun gizli tutulması gereken rafı
  // asla gösterilmez, bunun yerine ilk insan oyuncuya düşülür.
  const rackPlayer = me.isAI ? (state.players.find((p) => !p.isAI) ?? me) : me;
  const rackColor = PLAYER_COLORS[rackPlayer.colorIndex];

  // Raftan bir taş ya da tahtaya bu tur konmuş bir taş sürüklenmeye başlanır.
  const beginDrag = (source: DragSource, e: React.PointerEvent) => {
    if (!canAct || state.swapMode) return;
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // Nadir durumlarda (ör. pointerId zaten geçersiz) atabilir —
      // releasePointerCapture'daki aynı toleransla simetrik, sürüklemenin
      // kendisi yakalama olmadan da çalışmaya devam eder.
    }
    dragRef.current = { source, startX: e.clientX, startY: e.clientY, moved: false };
  };

  // Bırakma hedefini (varsa) bulur: tahta hücresi ya da raf alanı.
  const dropTargetsAt = (x: number, y: number) => {
    const el = document.elementFromPoint(x, y);
    const cellEl = el?.closest('[data-cell]') as HTMLElement | null;
    const rackEl = el?.closest('[data-rack]') as HTMLElement | null;
    return { cellEl, rackEl };
  };

  // Sürüklenen taş, parmağın DRAG_LIFT kadar üzerinde çizilir (görüşü
  // engellemesin diye). Tahtanın en üst satırı ekranın üst kısmına (başlığa)
  // yakınsa bu kaldırma, işaretçinin hedef noktasını tahtanın dışına
  // (başlığın üzerine) taşıyabilir — özellikle bir oyuncunun ilk hamlede
  // değmesi gereken köşe hücresi tam üst satırdaysa, bu hücreye asla
  // bırakılamaz hale gelirdi. Kaldırılmış noktayı tahtanın üst kenarının
  // altında tutmak için kırpılır; görsel taş ve bırakma hedefi hep aynı
  // (kırpılmış) noktayı kullanır, ikisi asla ayrışmaz.
  const liftedPoint = (clientY: number) => {
    // En üst satırın (r=0) hücresi, kaldırılmış noktanın hâlâ bir
    // `[data-cell]` içinde kalması için kullanılır — tahtanın kendi kap
    // elemanının üst kenarı iç dolgu (padding) içerdiğinden, o kenara göre
    // kırpmak noktayı hücre olmayan bir bölgeye düşürebilirdi.
    const topRowEl = document.querySelector('[data-cell="0,0"]') as HTMLElement | null;
    const minY = topRowEl ? topRowEl.getBoundingClientRect().top + 1 : -Infinity;
    return Math.max(clientY - DRAG_LIFT, minY);
  };

  const isCellFreeFor = (source: DragSource, r: number, c: number) => {
    if (source.kind === 'placed' && source.r === r && source.c === c) return false;
    return !state.board[r][c] && !state.placed[key(r, c)];
  };

  const moveDrag = (e: React.PointerEvent) => {
    const d = dragRef.current;
    if (!d) return;
    if (!d.moved) {
      const dist = Math.hypot(e.clientX - d.startX, e.clientY - d.startY);
      if (dist < dragThresholdFor(e.pointerType)) return;
      d.moved = true;
    }
    const liftedY = liftedPoint(e.clientY);
    const { cellEl } = dropTargetsAt(e.clientX, liftedY);
    let overKey: string | null = null;
    let overValid = false;
    if (cellEl?.dataset.cell) {
      const [r, c] = cellEl.dataset.cell.split(',').map(Number);
      overKey = key(r, c);
      overValid = isCellFreeFor(d.source, r, c);
    }
    setGhost({ x: e.clientX, y: liftedY, source: d.source, overKey, overValid });
  };

  const endDrag = (e: React.PointerEvent) => {
    const d = dragRef.current;
    dragRef.current = null;
    setGhost(null);
    if (!d) return;
    try {
      (e.target as Element).releasePointerCapture?.(e.pointerId);
    } catch {
      // yakalama zaten bırakılmış olabilir — yok sayılır.
    }

    // Sürükleme değil DOKUNUŞ olarak işle — hem "hiç kıpırdamadı" dalı hem
    // titreşimli dokunuş dalı buradan geçer, davranışları AYRIŞMASIN diye.
    const dokunusOlarakIsle = () => {
      if (d.source.kind === 'rack') {
        // Raf dokunuşu tahta çifti oluşturamaz (zoom kapsamı yalnızca tahta).
        boardZoom.markUnpairable();
        dispatch({ type: 'SELECT_TILE', index: d.source.index });
      } else {
        // Çiftin İKİNCİSİYSE geri alma yutulur ve zoom değişir — ilk dokunuş
        // taşı koyduysa parmağın altındaki hücre artık boş değildir, ikinci
        // vuruş o taşı geri ALMASIN.
        if (boardZoom.registerCellTap(e.clientX, e.clientY)) return;
        tapPlacedTile(d.source.r, d.source.c, true);
      }
    };

    if (!d.moved) {
      // Hareket yok: sıradan bir dokunuş/tık — eski davranış korunur.
      //
      // ⚠ Bu dal 1 Eylül 2026'ya kadar aşağıdaki `dokunusOlarakIsle`nin
      // KOPYASIYDI (aynı iki satır, iki yerde). Zoom kapısı eklenirken
      // yalnızca biri güncellendi ve hareketsiz çift dokunuş sessizce
      // çalışmadı — Playwright testi yakaladı. Kopya kaldırıldı: iki dal
      // artık TEK gövdeden geçiyor (portun `_endTileDrag`ı da öyle).
      //
      // Tahtaya konmuş bir taşta joker ise harfi değiştirme penceresi
      // açılır (geri alma hâlâ sürükleyerek ya da modaldeki "Geri Al"
      // butonuyla mümkün), değilse doğrudan geri alınır. Pencere BU
      // pointerup içinde açıldığından, dokunmatikte hemen ardından gelen
      // uyumluluk (compat) click'i artık hücrenin değil YENİ AÇILAN
      // modalın üstüne düşüyor — ölçüldü (22 Ağustos 2026): parmağın
      // konumuna göre ya harf ızgarasındaki bir taşa basıp jokeri sessizce
      // başka bir harfe çeviriyor (kullanıcının bildirdiği "A, C oldu") ya
      // da zemine düşüp modalı anında kapatıyor ("pencere hiç açılmadı").
      // O tek click `tapPlacedTile` içinde yutuluyor.
      dokunusOlarakIsle();
      return;
    }

    // TİTREŞİMLİ DOKUNUŞ: eşik aşıldı ama jest hiçbir yere GİTMEDİ (ya da
    // raf taşı hâlâ rafın üstünde bırakıldı) — bu bir bırakma değil,
    // dokunuş. Gerekçe ve ölçümler `TAP_SLOP_ON_RELEASE`ın yanında.
    const rafinUstunde =
      d.source.kind === 'rack' && !!dropTargetsAt(e.clientX, e.clientY).rackEl;
    if (
      rafinUstunde ||
      Math.hypot(e.clientX - d.startX, e.clientY - d.startY) <
        TAP_SLOP_ON_RELEASE
    ) {
      dokunusOlarakIsle();
      return;
    }

    // Gerçek bir sürükleme oldu — bırakılan hücrenin altındaki "hayalet"
    // click olayını yut (yoksa yanlışlıkla o hücrenin onClick'ini tetikler).
    // Aynı koruma sürükleme sonunda AÇILAN pencere için de gerekiyor:
    // raftan sürüklenen bir joker aşağıda `setPendingWild` ile pencere açıyor.
    swallowNextClick();
    // Önceki dokunuş kaydı bayatladı: sürüklemeden sonraki dokunuş onunla
    // çift oluşturup zoom'u kazara açmasın.
    boardZoom.markUnpairable();

    const { cellEl, rackEl } = dropTargetsAt(e.clientX, liftedPoint(e.clientY));
    if (cellEl?.dataset.cell) {
      const [r, c] = cellEl.dataset.cell.split(',').map(Number);
      if (isCellFreeFor(d.source, r, c)) {
        if (d.source.kind === 'rack') {
          if (d.source.tile.letter === '?') {
            setPendingWild({ r, c, rackIndex: d.source.index });
          } else {
            dispatch({ type: 'PLACE_TILE', r, c, rackIndex: d.source.index });
          }
        } else {
          dispatch({
            type: 'MOVE_PLACED_TILE',
            from: { r: d.source.r, c: d.source.c },
            to: { r, c },
          });
        }
      }
    } else if (rackEl && d.source.kind === 'placed') {
      dispatch({ type: 'RECALL_CELL', r: d.source.r, c: d.source.c });
    }
  };

  const cancelDrag = () => {
    dragRef.current = null;
    setGhost(null);
  };

  /// Tahtaya BU turda konmuş bir taşa dokunma davranışı — tek kaynak.
  /// `swallow`: dokunuşun pointer akışından geldiği durumda (endDrag)
  /// ardından gelen uyumluluk click'i yutulmalı; tıklama akışından
  /// (handleCellClick'in ıskalama kurtarması) çağrılırken yutulacak bir
  /// şey YOK — orada zaten click'in içindeyiz.
  const tapPlacedTile = (r: number, c: number, swallow: boolean) => {
    const tile = state.placed[key(r, c)];
    if (!tile) return;
    // ⚠ YUTMA HER İKİ DAL İÇİN DE ŞART — 28 Ağustos 2026'da bir kullanıcı
    // bildirdi: *"tahtaya konan taşı geri almak için tıkladığında 2 harf
    // birden geri geliyor"*. Yutma eskiden yalnızca joker dalındaydı;
    // sıradan taş dalında compat click BOŞALMIŞ hücreye düşüyor ve orada
    // HİÇBİR ŞEY yapmadığı için zararsız sanılıyordu. Parça 151 (27 Ağustos)
    // boş hücre kurtarmasını ekleyince o click İŞ YAPAR hâle geldi: kurtarma
    // komşudaki taslak taşı bulup ONU da geri alıyor.
    //
    // ÖLÇÜLDÜ (Chromium, hasTouch+isMobile, 390×844; masaüstü faresinde
    // GÖRÜNMEZ — orada click'in hedefi az önce sökülen taş düğümü olduğundan
    // React onu hiçbir fiber'a eşleyemiyor ve olay sessizce düşüyor):
    //   tapPlacedTile 0,1 → handleCellClick 0,1 → kurtarma 0,0 → tapPlacedTile 0,0
    // raf 5 → 7. Doğru davranış 5 → 6.
    //
    // Yutmanın koşulu jestin KAYNAĞI, dalın türü değil: pointer akışından
    // gelen her dokunuş DOM'u değiştiriyor (taş sökülüyor ya da pencere
    // açılıyor), yani ardından gelen compat click her hâlükârda BAŞKA bir
    // öğenin üstüne düşüyor.
    if (swallow) swallowNextClick();
    // Taşa dokunuş çift dokunuş BAŞLATAMAZ (yalnızca ikincisi olarak
    // yutulabilir — o kapı çağıranlarda). Joker penceresinin zoom'la
    // ilişkisi YOK: eskisi gibi anında açılır.
    boardZoom.markUnpairable();
    if (tile.wild) {
      setPendingWild({ r, c, editing: true });
    } else {
      dispatch({ type: 'RECALL_CELL', r, c });
    }
  };

  const handleCellClick = (r: number, c: number, e: ReactMouseEvent) => {
    // ── Çift dokunuşla zoom (bkz. src/utils/boardZoom.ts) ────────────────
    // Dokunuşun kendi işleminden ÖNCE sorulur: bir çiftin İKİNCİSİYSE işlem
    // yutulur ve zoom değişir — ilk dokunuşun yaptığı iş (koyulan taş dahil)
    // OLDUĞU GİBİ KALIR. Çift yalnızca BOŞ kareye dokunuşla başlar.
    if (!state.board[r][c]) {
      if (boardZoom.registerCellTap(e.clientX, e.clientY)) return;
      if (!state.placed[key(r, c)]) boardZoom.registerPairable(e.clientX, e.clientY);
    } else {
      boardZoom.markUnpairable();
    }
    // Tahtada duran bir taşa (hangi hamlede oynandığına bakılmaksızın)
    // tıklanırsa, o hücreden geçen kelime(ler)in anlamı gösterilir.
    // ⚠ TASLAK HAMLE VARKEN ANLAM AÇILMAZ (24 Ağustos 2026, kullanıcı
    // cihazda bildirdi): *"2 kelimenin birleştiği yere bir taş koyup deneme
    // yaparken (oynaya basmadan) koyduğum taşın üstüne basıp geri almaya
    // çalıştığımda oradaki daha önce bulunan kelimelerin anlamları açıldı...
    // Bu zaten yanlış, kelime anlamı deneme yapılırken hiç açılmamalı."*
    //
    // Tahta hücresi ~24 px — parmağın temas MERKEZİ nişan alınan noktanın
    // altına düştüğünden, taslak taşını geri almak için dokunan kullanıcı
    // sık sık KOMŞU (oynanmış) taşa isabet ediyor. Hücreyi büyütmek mümkün
    // değil (ızgara ölçüsü kuralın kendisi), ama ıskalamayı ZARARSIZ yapmak
    // mümkün: taslak sürerken anlam penceresi hiç açılmaz. Dahası, o
    // dokunuş komşusundaki taslak taşına yönlendirilir (ıskalama kurtarma,
    // `src/utils/draftRescue.ts`) — kullanıcının asıl niyeti oydu. Taslak
    // boşken (rakibin sırası ya da kendi sıranda henüz taş koymadan)
    // davranış DEĞİŞMEDİ.
    if (state.board[r][c]) {
      if (Object.keys(state.placed).length > 0) {
        // Iskalama kurtarma: taslak sürerken oynanmış taş ZATEN ölü, o
        // yüzden alanı komşusundaki taslak taşına devredilir. Belirsizlikte
        // tahmin YOK (bkz. `src/utils/draftRescue.ts`).
        const target = nearbyDraftCell(
          SIZE,
          r,
          c,
          (rr, cc) => !!state.placed[key(rr, cc)],
          { x: e.clientX, y: e.clientY },
          (rr, cc) =>
            document
              .querySelector(`[data-cell="${rr},${cc}"]`)
              ?.getBoundingClientRect() ?? null,
        );
        if (target) tapPlacedTile(target[0], target[1], false);
        return;
      }
      const words = [
        getFullWordAt(state.board, {}, r, c, 0, 1),
        getFullWordAt(state.board, {}, r, c, 1, 0),
      ].filter((w) => w.length >= 2);
      openMeaning(words);
      return;
    }
    if (state.isGameOver || me.isAI || state.swapMode) return;

    // BOŞ hücreye ıskalayan dokunuş da kurtarılır — YALNIZCA hiçbir raf taşı
    // SEÇİLİ DEĞİLKEN (27 Ağustos 2026, kullanıcı uygulamada bildirdi:
    // *"tahtaya konan taşı kaldırmak için ilk tıklama yakalamıyor. İkincide
    // ya da üçüncüde yakalanıyor."*). Portta ölçüldü: hücre 26 px ve parmağın
    // temas MERKEZİ nişan noktasının altında kaldığından ıskalama BİR ALT
    // hücreye düşüyor; o hücre boşsa eskiden hiçbir şey olmuyordu (dahası
    // "Önce bir harf seç." yazıyordu — geri almaya çalışana alakasız bir
    // uyarı).
    //
    // 24 Ağustos'ta boş hücrelerin bilerek dışarıda bırakılma gerekçesi
    // ("kelimeyi dizerken yan hücreye harf koymak zorlaşmasın") YALNIZCA
    // seçili taş varken geçerli; seçim yokken boş hücreye tıklamak zaten
    // hiçbir iş yapmıyor, yani kurtarmanın bedeli sıfır. Koşul bu yüzden dar.
    if (state.selectedTile === null && Object.keys(state.placed).length > 0) {
      const target = nearbyDraftCell(
        SIZE,
        r,
        c,
        (rr, cc) => !!state.placed[key(rr, cc)],
        { x: e.clientX, y: e.clientY },
        (rr, cc) =>
          document
            .querySelector(`[data-cell="${rr},${cc}"]`)
            ?.getBoundingClientRect() ?? null,
      );
      if (target) {
        tapPlacedTile(target[0], target[1], false);
        return;
      }
    }

    const sel = state.selectedTile !== null ? me.rack[state.selectedTile] : null;
    if (sel && sel.letter === '?') {
      // Joker taş: hangi harfe dönüşeceği seçilene kadar taş konmaz.
      // Modal AÇILDI → çift dokunuş zinciri kırılır (portun aynı dalıyla
      // hizalı): joker penceresi açıkken ikinci dokunuş tahtaya değil
      // pencereye düşer, zincirin diri kalması sonraki gerçek dokunuşu
      // yanlışlıkla "çift" yapardı (Playwright bunu yakaladı).
      boardZoom.markUnpairable();
      setPendingWild({ r, c });
      return;
    }
    dispatch({ type: 'PLACE_TILE', r, c });
  };

  const canAct = !state.isGameOver && !me.isAI;

  const handlePlay = async () => {
    if (!wordsReady) return;
    // Rakip köşeye giriş tespiti.
    const placedCoords = Object.keys(state.placed).map(
      (k) => k.split(',').map(Number) as [number, number],
    );
    const { shares } = computeInvasionSplit(
      placedCoords,
      state.current,
      state.players,
      potentialScore,
      state.board,
    );
    const invasion = shares.length > 0
      ? shares.map((s) => ({ ownerName: state.players[s.index].name, ownerPts: s.amount }))
      : null;

    // Sunucu kelime doğrulaması (Supabase yapılandırılmışsa).
    if (isSupabaseConfigured) {
      const structural = validatePlacementStructural(
        state.board,
        state.placed,
        state.current,
        me.corners,
        isFirstMove(state),
      );
      if (structural.valid && structural.words && structural.words.length > 0) {
        setValidating(true);
        let serverOk = true;
        const invalidWords: string[] = [];
        try {
          // Kelimeler birbirinden bağımsız doğrulandığından sıralı
          // (for…await) yerine paralel çalıştırılabilir — çoklu kelimeli bir
          // hamlede gereksiz gecikmeyi önler.
          const results = await Promise.all(
            structural.words.map((word) => isValidWordRemote(trLower(word))),
          );
          results.forEach((result, i) => {
            if (result === false) {
              invalidWords.push(structural.words![i]);
            } else if (result === null) {
              // Sunucu hatası — yerel sözlüğe düş.
              serverOk = false;
            }
          });
        } catch (err) {
          // isValidWordRemote normalde Supabase hatasını yakalayıp `null`
          // döner (yukarıdaki dal), ama beklenmedik bir throw (ör. tam ağ
          // kopukluğu) burada yakalanmazsa hamle hiçbir dispatch/hata mesajı
          // olmadan askıda kalırdı — aynı `result === null` dalı gibi yerel
          // doğrulamaya düşülüyor.
          console.error('[Kelimeki] Sunucu kelime doğrulaması başarısız:', err);
          serverOk = false;
        } finally {
          setValidating(false);
        }
        if (serverOk) {
          if (invalidWords.length > 0) {
            setSubmitError(formatInvalidWordsReason(invalidWords));
            return;
          }
          // Tüm kelimeler sunucuda onaylandı, yerel kontrol atla.
          pendingSkipWordCheck.current = true;
          if (invasion) { setInvasionConfirm(invasion); return; }
          dispatch({ type: 'PLAY', skipWordCheck: true });
          return;
        }
      }
    }

    // Supabase yoksa veya yapısal kontrol başarısızsa yerel doğrulama (reducer).
    // Hamle zaten geçersizse (`moveStatus.valid` false) köşe-vergisi onayını
    // hiç göstermeden doğrudan PLAY'e düş — reducer doğru hata mesajıyla
    // reddedecek; aksi halde kullanıcı zaten reddedilecek bir hamle için
    // gereksiz bir "rakip bölgesine giriyorsun" onayı görürdü.
    pendingSkipWordCheck.current = false;
    if (invasion && moveStatus?.valid) { setInvasionConfirm(invasion); } else { dispatch({ type: 'PLAY' }); }
  };

  // Pas, sırayı tümüyle harcadığı için onay ister.
  const handlePass = () => setShowPassConfirm(true);

  const potentialScore = moveStatus?.score ?? 0;

  const dragHiddenKey = ghost && ghost.source.kind === 'placed'
    ? key(ghost.source.r, ghost.source.c)
    : null;
  const dragHiddenIndex = ghost && ghost.source.kind === 'rack' ? ghost.source.index : null;

  return (
    <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
      <GameHeader state={state} onLogoClick={handleLogoClick} />

      <main className="w-full flex flex-col items-center">
      <Board
        state={state}
        onCellClick={handleCellClick}
        moveStatus={moveStatus}
        onOpenHistory={() => setShowHistory(true)}
        // Zorluk rozeti alt şeritte, "Hamleler"in yanında (6 Eylül 2026,
        // kullanıcı isteği). Yerel oyun her zaman YZ oyunu → her seviyede
        // (Normal dahil); OnlineGameScreen bu prop'u GEÇİRMEZ.
        aiLevel={aiLevelOf(state.aiLevel)}
        // Aynı HelpModal'ı Tutorial da kullanıyor; kapanışta
        // `markQuickStartSeen()` çağrıldığından elle açmak da "görüldü"
        // sayılır — Setup'ın "Nasıl oynanır?" linkiyle aynı kural.
        onOpenHelp={() => setShowPostStartTutorial(true)}
        dragHiddenKey={dragHiddenKey}
        tileLifted={ghost !== null}
        dragOverKey={ghost?.overKey ?? null}
        dragOverValid={ghost?.overValid ?? false}
        onTilePointerDown={(r, c, e) =>
          beginDrag({ kind: 'placed', r, c, tile: state.placed[key(r, c)] }, e)
        }
        onTilePointerMove={moveDrag}
        onTilePointerUp={endDrag}
        onTilePointerCancel={cancelDrag}
        zoomHint={boardZoom.hint}
        zoom={boardZoom.zoom}
        viewportRef={boardZoom.viewportRef}
        onBoardPointerDown={boardZoom.onPointerDown}
        onBoardPointerMove={boardZoom.onPointerMove}
        onBoardPointerUp={boardZoom.onPointerUp}
        onBoardPointerCancel={boardZoom.onPointerCancel}
      />

      <div className="w-full max-w-[680px] px-3 pb-3 pt-1 flex flex-col gap-1.5">
        {/* `min-h-[30px] flex items-center`: mesaj satırı Flutter portundaki
            sabit 30px'lik kutunun (SizedBox+Center) eşleniği — kullanıcı iki
            ekranı yan yana koyup tahta↔raf boşluğunu web'de DAR buldu ve
            portun değerini seçti (17 Ağustos 2026). ÖLÇÜLDÜ: eski `min-h-[15px]`
            bağlayıcı değildi, gerçek yükseklik satır yüksekliğinden geliyordu
            (16.5 + py-0.5 = 20.5), yani tahta kartının altı ile raf arası
            web'de 30.5 / portta 40 idi. `min-h` (sabit `h` DEĞİL): mesaj iki
            satıra taşarsa kutu büyüsün, kırpılmasın — port orada `maxLines: 2`
            ile kesiyor, tek satırlık normal durumda ikisi birebir aynı. */}
        <div
          className={`text-[11px] font-mono font-bold text-center min-h-[30px] py-0.5 flex items-center justify-center ${
            MESSAGE_COLORS[liveMessageType]
          }`}
        >
          {liveMessage}
        </div>

        <div className="flex gap-1.5 items-stretch">
          <div className="flex-1 min-w-0">
            <Rack
              tiles={rackPlayer.rack}
              selectedTile={state.selectedTile}
              onSelect={(i) => {
                if (me.isAI) return;
                if (state.swapMode) dispatch({ type: 'TOGGLE_SWAP_TILE', index: i });
                else dispatch({ type: 'SELECT_TILE', index: i });
              }}
              title={rackPlayer.name}
              color={rackColor}
              swapMode={state.swapMode}
              swapSelection={state.swapSelection}
              draggable={canAct}
              dragHiddenIndex={dragHiddenIndex}
              onTilePointerDown={(i, e) =>
                beginDrag({ kind: 'rack', index: i, tile: rackPlayer.rack[i] }, e)
              }
              onTilePointerMove={moveDrag}
              onTilePointerUp={endDrag}
              onTilePointerCancel={cancelDrag}
            />
          </div>
          {!state.swapMode && (
            state.isGameOver ? (
              <button
                onClick={() => setShowRematchConfirm(true)}
                className="btn-raised shrink-0 px-5 rounded-lg font-sans text-[15px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97]"
              >
                Tekrar Oyna
              </button>
            ) : (
              <button
                disabled={!canAct || validating || !wordsReady}
                onClick={() => { void handlePlay(); }}
                className="btn-raised shrink-0 px-5 rounded-lg font-sans text-[12px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97] disabled:opacity-35 disabled:cursor-not-allowed"
              >
                {!wordsReady ? 'Yükleniyor…' : validating ? 'Kontrol…' : 'Oyna'}
              </button>
            )
          )}
        </div>

        {state.swapMode ? (
          <div className="flex gap-1.5">
            <button
              disabled={!canAct || state.swapSelection.length === 0}
              onClick={() => dispatch({ type: 'CONFIRM_SWAP' })}
              className="btn-raised-gold flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-gold text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Değiştir{state.swapSelection.length > 0 ? ` (${state.swapSelection.length})` : ''}
            </button>
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'TOGGLE_SWAP_MODE' })}
              className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-muted border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Vazgeç
            </button>
          </div>
        ) : (
          <div className="flex gap-1.5">
            <button
              disabled={!canAct}
              onClick={handlePass}
              className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Pas Geç
            </button>
            <button
              disabled={!canAct || state.bag.length === 0}
              onClick={() => dispatch({ type: 'TOGGLE_SWAP_MODE' })}
              className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Değiştir
            </button>
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'SHUFFLE_RACK' })}
              className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Karıştır
            </button>
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'RECALL_ALL' })}
              className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Geri Al
            </button>
            <button
              onClick={() => setShowTiles(true)}
              className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform"
            >
              Torba <span className="text-[13px] text-accent">{state.bag.length}</span>
            </button>
          </div>
        )}
      </div>
      </main>

      {invasionConfirm && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div
            ref={invasionConfirmRef}
            role="dialog"
            aria-modal="true"
            aria-label="Sınır ihlali onayı"
            tabIndex={-1}
            className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
          >
            <p className="text-base font-bold text-text font-sans">Sınır İhlali!</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              Bu hamleden kazanacağın{' '}
              <strong className="text-green">{potentialScore}</strong>{' '}
              puanın{' '}
              {invasionConfirm.map((inv, i) => (
                <span key={i}>
                  <strong className="text-red">{inv.ownerPts}</strong> puanı{' '}
                  <strong>{inv.ownerName}</strong> kullanıcısına
                  {i < invasionConfirm.length - 1 ? ', ' : ' '}
                </span>
              ))}
              vergi olarak gidecek.
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  const skip = pendingSkipWordCheck.current;
                  pendingSkipWordCheck.current = false;
                  setInvasionConfirm(null);
                  dispatch({ type: 'PLAY', skipWordCheck: skip });
                }}
                className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Oyna
              </button>
              <button
                onClick={() => setInvasionConfirm(null)}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Vazgeç
              </button>
            </div>
          </div>
        </div>
      )}

      {showPassConfirm && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div
            ref={passConfirmRef}
            role="dialog"
            aria-modal="true"
            aria-label="Pas geçme onayı"
            tabIndex={-1}
            className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
          >
            <p className="text-base font-bold text-text font-sans">Pas Geçiyorsun!</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              Pas geçmek istediğinden emin misin? Sıran diğer oyuncuya geçer.
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  setShowPassConfirm(false);
                  dispatch({ type: 'PASS' });
                }}
                className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Pas Geç
              </button>
              <button
                onClick={() => setShowPassConfirm(false)}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Vazgeç
              </button>
            </div>
          </div>
        </div>
      )}

      {showRematchConfirm && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none">
            <p className="text-base font-bold text-text font-sans">Tekrar Oyna</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              {state.players.length} kişilik, Yapay Zeka'ya karşı yeni bir oyun başlatılacak. Emin
              misin?
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  setShowRematchConfirm(false);
                  // Aynı kadro: biten oyunun oyuncu adları/YZ bayrakları
                  // Setup'ın `doStart`'ının ürettiğinin AYNISI, yeniden
                  // hesaplamaya gerek yok.
                  // Aynı ZORLUK da: rövanş biten oyunun seviyesini taşır,
                  // Setup'a dönmeden Kolay'dan Normal'e geçilemez.
                  startLocalGame(state.players.map((p) => ({ name: p.name, isAI: p.isAI })), state.aiLevel);
                }}
                className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Tekrar Oyna
              </button>
              <button
                onClick={() => setShowRematchConfirm(false)}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Vazgeç
              </button>
            </div>
          </div>
        </div>
      )}

      {meaning && (
        <MeaningModal entries={meaning.entries} onClose={() => setMeaning(null)} />
      )}

      {showTiles && (
        <RemainingTilesModal state={state} myIndex={0} onClose={() => setShowTiles(false)} />
      )}

      {pendingWild && (
        <WildcardModal
          title={pendingWild.editing ? 'Jokeri Hangi Harfe Çevir?' : undefined}
          onSelect={(letter) => {
            if (pendingWild.editing) {
              dispatch({ type: 'SET_WILD_LETTER', r: pendingWild.r, c: pendingWild.c, wildLetter: letter });
            } else {
              dispatch({
                type: 'PLACE_TILE',
                r: pendingWild.r,
                c: pendingWild.c,
                wildLetter: letter,
                rackIndex: pendingWild.rackIndex,
              });
            }
            setPendingWild(null);
          }}
          onRecall={
            pendingWild.editing
              ? () => {
                  dispatch({ type: 'RECALL_CELL', r: pendingWild.r, c: pendingWild.c });
                  setPendingWild(null);
                }
              : undefined
          }
          onClose={() => setPendingWild(null)}
        />
      )}

      {ghost && (
        <div
          className="fixed z-[300] pointer-events-none"
          style={{
            left: ghost.x,
            top: ghost.y,
            width: 46,
            height: 46,
            transform: 'translate(-50%, -50%) scale(1.1)',
            filter: 'drop-shadow(0 10px 16px rgba(0,0,0,0.35))',
          }}
        >
          <Tile
            tile={ghost.source.tile}
            variant={ghost.source.kind === 'rack' ? 'rack' : 'placed'}
            color={ghost.source.kind === 'placed' ? PLAYER_COLORS[me.colorIndex] : undefined}
          />
        </div>
      )}

      <GameOver
        show={state.isGameOver && !gameOverDismissed}
        players={state.players}
        turnCount={state.turnCount}
        aiLevel={aiLevelOf(state.aiLevel)}
        onOpenHistory={() => setShowHistory(true)}
        onOpenFeedback={() => setShowFeedback(true)}
        onClose={() => {
          setGameOverDismissed(true);
          setShowFeedback(true);
        }}
      />

      {showHistory && (
        <MoveHistoryModal state={state} onClose={() => setShowHistory(false)} />
      )}

      {showFeedback && (
        <FeedbackModal onClose={() => setShowFeedback(false)} source="game_end" />
      )}

      {showContactFeedback && (
        <FeedbackModal
          source="general"
          relatedTo={contactRelatedTo}
          fromEmailLink
          onClose={() => setShowContactFeedback(false)}
        />
      )}

      {showPostStartTutorial && (
        <HelpModal
          onClose={() => {
            markQuickStartSeen();
            setShowPostStartTutorial(false);
          }}
        />
      )}
      <LandscapeHint />
      {/* k-lig kutlama banner'ı — oyun SÜRERKEN bastırılır (odak çalmasın),
          oyun bitince suppress düşer ve bekleyen kutlama otomatik gösterilir
          (oyun-bitti kaydının ardından requestLeagueRewardCheck de tetikler). */}
      <LeagueRewardsHost suppress={state.phase === 'play' && !state.isGameOver} />
    </div>
  );
}
