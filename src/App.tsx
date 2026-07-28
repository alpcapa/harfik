// Kelimeki — ana uygulama: kurulum, çok oyunculu sıra akışı ve düzen
import { useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { GameHeader } from './components/GameHeader';
import { Board } from './components/Board';
import { Rack } from './components/Rack';
import { GameOver } from './components/GameOver';
import { UserMenu } from './components/UserMenu';
import { Setup } from './components/Setup';
import { AddToHomeScreen } from './components/AddToHomeScreen';
import { LandscapeHint } from './components/LandscapeHint';
import { MeaningModal } from './components/MeaningModal';
import { RemainingTilesModal } from './components/RemainingTilesModal';
import { MoveHistoryModal } from './components/MoveHistoryModal';
import { WildcardModal } from './components/WildcardModal';
import { HelpModal } from './components/HelpModal';
import { FeedbackModal } from './components/FeedbackModal';
import { ResetPasswordModal } from './components/ResetPasswordModal';
import { createInitialState, gameReducer, isFirstMove } from './game/gameReducer';
import { preloadWordSet, isWordSetReady } from './data/wordSetLoader';
import { calcScore, computeInvasionSplit, formatInvalidWordsReason, validatePlacement, validatePlacementStructural } from './utils/validator';
import { loadGameState, saveGameState, clearGameState, takePendingAbandonedGame } from './utils/gameStorage';
import type { SavedGame } from './utils/gameStorage';
import { buildGameRecord } from './utils/gameRecord';
import { markQuickStartSeen } from './utils/onboarding';
import { getFormedWords, getFullWordAt, key } from './utils/board';
import type { Tile as TileModel } from './game/types';
import { Tile } from './components/Tile';
import { trLower } from './utils/turkish';
import { PLAYER_COLORS } from './game/constants';
import { fetchMeaning, isValidWordRemote, isSupabaseConfigured, logGameFinish, logGuestVisit, acceptFriendInvite } from './lib/api';
import { saveGameDurable, flushPendingGames } from './utils/gameSync';
import { flushPendingFeedback } from './utils/feedbackSync';
import { takePendingInviteToken } from './utils/friendInvite';
import {
  getOrCreateAnonId,
  visitAlreadyLoggedToday,
  markVisitLoggedToday,
  captureUtmSource,
  getStoredUtmSource,
  getDeviceType,
  isStandaloneDisplay,
} from './utils/visitTracking';
import type { OnlineGame, WordMeaning } from './lib/database.types';
import { OnlineGameScreen } from './components/OnlineGameScreen';
import { useAuth } from './hooks/useAuth';
import { useModalA11y } from './hooks/useModalA11y';

const AI_THINK_MS = 1100;
// Sürüklemenin "tıklama" değil gerçek bir sürükleme sayılması için gereken
// minimum işaretçi hareketi (piksel).
const DRAG_THRESHOLD = 6;
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

  // Kelime listesi main.tsx'te tetiklenen ayrı chunk'tan yükleniyor —
  // hazır olana kadar hamle doğrulama/YZ turu tetiklenmemeli (bkz.
  // wordSetLoader.ts). Setup ekranında kuruluma harcanan birkaç saniye
  // içinde neredeyse her zaman zaten tamamlanmış olur.
  const [wordsReady, setWordsReady] = useState(isWordSetReady());
  useEffect(() => {
    if (wordsReady) return;
    preloadWordSet().then(() => setWordsReady(true));
  }, [wordsReady]);

  // Sosyal medya/tanıtım linklerindeki ?ref= parametresini (varsa) cihaza
  // ilk temas olarak kaydeder — oturum durumundan bağımsız, sayfa her
  // yüklendiğinde çalışmalı ki paylaşılan linkle gelen biri daha auth
  // durumu netleşmeden kaynağını kaybetmesin.
  useEffect(() => {
    captureUtmSource();
  }, []);

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
    void logGuestVisit(anonId, getStoredUtmSource(), getDeviceType(), isStandaloneDisplay());
  }, [authLoading, user]);

  // Devam eden oyunu (phase==='play', bitmemiş) her değişiklikte
  // localStorage'a yaz — sekme/uygulama kapatılıp açılınca kaldığı yerden
  // devam edilebilsin. Oyun bitince ya da kurulum ekranına dönülünce kayıt
  // silinir. `savedGame` doluyken (henüz RESUME_SAVED ile açılmamış bir
  // kayıt Setup'ta bekliyorken) clearGameState() ÇAĞIRILMAZ — aksi halde bu
  // effect ilk render'da (state.phase henüz 'setup') kaydı kullanıcı hiç
  // görmeden anında silerdi.
  useEffect(() => {
    if (state.phase === 'play' && !state.isGameOver) {
      saveGameState(state);
    } else if (!savedGame) {
      clearGameState();
    }
  }, [state, savedGame]);

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
    if (token) void acceptFriendInvite(token).catch(() => {});
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
  // yüzünden terk edilmiş sayılıp silinen bir oyun varsa, o kayıt burada
  // (mount'ta, bir kez) sunucuya "tamamlanmadı" olarak bildirilir. Kuyruk
  // read-then-clear olduğundan StrictMode'un dev'de effect'i iki kez
  // çalıştırması zararsızdır — ikinci okuma boş döner.
  useEffect(() => {
    const pending = takePendingAbandonedGame();
    if (pending) {
      void logGameFinish(pending.playerCount, pending.durationSeconds, pending.multiSession, false);
      // Oyun gerçekten başlamışsa (aşağıdaki gameStarted'la aynı eşik:
      // turnCount>=2) bu, hesap sahibi için gecikmeli bir teslim sayılır —
      // oyun içindeki "Çık" ile aynı -2 Sanal Lig cezası uygulanır. Misafirse
      // (o an giriş yoksa) saveGameDurable normal bitişteki gibi kaydı
      // offline kuyruğa alır, kişi ileride giriş/kayıt olursa hesabına işlenir.
      if (pending.state && pending.state.turnCount >= 2) {
        const record = buildGameRecord(pending.state, true, 0);
        if (record) void saveGameDurable(record);
      }
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
  // bağımsız (bkz. supabase/functions/_shared/email.ts, buildNoreplyNoticeHtml).
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

  // Oyun sonu ekranı kapatıldı mı (X'e basıldı mı) — board'u görmek için.
  const [gameOverDismissed, setGameOverDismissed] = useState(false);
  useEffect(() => {
    if (state.isGameOver) setGameOverDismissed(false);
  }, [state.isGameOver]);

  // Joker taş konurken hangi harfe dönüşeceğini seçme penceresi.
  const [pendingWild, setPendingWild] = useState<
    { r: number; c: number; rackIndex?: number } | null
  >(null);

  // Oyundan çıkış onay popup'ı.
  const [showExitConfirm, setShowExitConfirm] = useState(false);

  // Pas geçme onay popup'ı.
  const [showPassConfirm, setShowPassConfirm] = useState(false);

  // Setup ekranında "Oyunu Başlat" tıklandığında Tutorial ilk kez
  // görülmemişse, oyun ekranı açılır açılmaz burada gösterilir.
  const [showPostStartTutorial, setShowPostStartTutorial] = useState(false);

  // Setup'taki "Devam Eden Oyun" satırına tıklanınca: kaydı reducer'a
  // uygulayıp `savedGame`'i temizler — bundan sonra yukarıdaki save/clear
  // effect'i tamamen `state`e göre çalışır (bkz. o effect'teki not).
  const handleResumeSavedGame = () => {
    if (!savedGame) return;
    dispatch({ type: 'RESUME_SAVED', state: savedGame.state });
    setSavedGame(null);
  };

  // Kurulum ekranındaki üst sekme: yerel (2/4 kişilik, anında başlar) ya da
  // Canlı (arkadaş daveti/kabulü — Faz 2). Bilinçli olarak Setup'ın kendi
  // 2/4 kişilik seçicisinin içine değil, onun yanına ayrı bir sekme olarak
  // eklendi — iki mod farklı zihinsel modeller taşıyor (bkz. proje notları).
  const [mainView, setMainView] = useState<'local' | 'live'>('local');

  // Açık olan Canlı oyun (Faz 3, 4. adım) — Setup/LiveGamesTab'daki "Aktif"
  // bir oyuna dokununca dolar; doluyken tüm normal kurulum/yerel oyun
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

  // Rakip köşeye giriş onay popup'ı.
  const [invasionConfirm, setInvasionConfirm] = useState<
    { ownerName: string; ownerPts: number }[] | null
  >(null);

  // Bu üç dahili onay popup'ı Modal.tsx'i kullanmıyor (kendi basit
  // işaretlemeleri var) ama aynı odak hapsi/Escape/geri-dönüş davranışını
  // paylaşıyor.
  const exitConfirmRef = useModalA11y(showExitConfirm, () => setShowExitConfirm(false));
  const passConfirmRef = useModalA11y(showPassConfirm, () => setShowPassConfirm(false));
  const invasionConfirmRef = useModalA11y(!!invasionConfirm, () => setInvasionConfirm(null));

  // Sunucu kelime doğrulaması sırasında true — butonu devre dışı bırakır.
  const [validating, setValidating] = useState(false);
  // Sunucu doğrulaması başarılıysa true; reducer'a skipWordCheck iletilir.
  const pendingSkipWordCheck = useRef(false);

  // ── Taş sürükleme (fare + dokunmatik) ───────────────────────────────────
  // Jest sırasında değişen anlık veri `dragRef`de tutulur (her pointer
  // olayında render tetiklemeden okunup güncellenir); `ghost` yalnızca
  // gerçek bir sürükleme başladığında (eşik aşılınca) set edilir ve
  // sürüklenen taşın parmak/imleci takip eden görselini tetikler.
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
  // Gerçek bir sürükleme bitişinin hemen ardından gelen "hayalet" click
  // olayını yutmak için (bırakılan hücrenin altındaki onClick'i tetiklemesin).
  const suppressClickRef = useRef(false);

  useEffect(() => {
    const swallow = (e: MouseEvent) => {
      if (suppressClickRef.current) {
        suppressClickRef.current = false;
        e.stopPropagation();
        e.preventDefault();
      }
    };
    document.addEventListener('click', swallow, true);
    return () => document.removeEventListener('click', swallow, true);
  }, []);

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
    if (record) void saveGameDurable(record);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.isGameOver]);

  // Oyun bitince (misafir dahil, kompozisyon fark etmeksizin) anonim
  // başlatma/bitirme + süre sayaçları için admin panelinin Büyüme > Oyun
  // grafiğine veri sağlar — skor/kelime gibi kişisel veri içermez.
  useEffect(() => {
    if (!state.isGameOver || state.phase !== 'play') return;
    const durationSeconds = Math.max(0, Math.round((Date.now() - Date.parse(state.startedAt)) / 1000));
    void logGameFinish(state.players.length, durationSeconds, state.multiSession, true, state.endReason === 'surrender');
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
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.placed, state.board, state.players, state.current, wordsReady]);

  // Oyna'ya basmadan önce, geçersiz bir hamle varsa sebebini canlı olarak
  // alttaki mesaj alanında göster — oyuncu Oyna'ya basmadan neden geçersiz
  // olduğunu (köşe kuralı, sözlük vb.) hemen görsün. Geçerliyse aynı mesaj
  // ("Oyna tuşuyla kelimeyi onayla.") yeşile döner.
  const liveMessage = moveStatus && !moveStatus.valid && moveStatus.reason
    ? moveStatus.reason
    : state.message;
  const liveMessageType = moveStatus && !moveStatus.valid && moveStatus.reason
    ? 'err'
    : moveStatus?.valid
      ? 'ok'
      : state.messageType;

  // ── Şifre sıfırlama ────────────────────────────────────────────────────────
  // Sıfırlama e-postasındaki bağlantı tıklanıp bu sekmede recovery oturumu
  // açıldıysa, yeni şifre belirlenene kadar kurulum/oyun ekranlarının önüne geçer.
  if (passwordRecovery) {
    return (
      <div className="min-h-[100dvh] w-full flex items-center justify-center">
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
    return (
      <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
        <div className="w-full max-w-[460px] flex items-center justify-end px-3.5 pt-3">
          <UserMenu />
        </div>
        <main className="w-full flex flex-col items-center">
          <Setup
            mainView={mainView}
            onMainViewChange={setMainView}
            onOpenLiveGame={setOnlineGame}
            savedGame={savedGame}
            onResumeGame={handleResumeSavedGame}
            onStart={(players, showTutorial) => {
              dispatch({ type: 'START', players });
              if (showTutorial) setShowPostStartTutorial(true);
            }}
          />
        </main>
        <AddToHomeScreen />
        <LandscapeHint />
        {showContactFeedback && (
          <FeedbackModal
            source="general"
            relatedTo={contactRelatedTo}
            onClose={() => setShowContactFeedback(false)}
          />
        )}
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
  // Hesap sahibi teslim olduysa artık hiçbir kontrolü yok — oyun bitene
  // kadar (isGameOver) rafı/aksiyon butonlarını göstermek yerine sade bir
  // "izliyorsun" bandı gösterilir. Oyun gerçekten bitince (isGameOver) normal
  // "Yeni Oyun Aç" akışına düşülür.
  const spectating = rackPlayer.surrendered && !state.isGameOver;

  // Raftan bir taş ya da tahtaya bu tur konmuş bir taş sürüklenmeye başlanır.
  const beginDrag = (source: DragSource, e: React.PointerEvent) => {
    if (!canAct || state.swapMode) return;
    e.currentTarget.setPointerCapture(e.pointerId);
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
      if (dist < DRAG_THRESHOLD) return;
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

    if (!d.moved) {
      // Hareket yok: sıradan bir dokunuş/tık — eski davranış korunur.
      if (d.source.kind === 'rack') {
        dispatch({ type: 'SELECT_TILE', index: d.source.index });
      } else {
        dispatch({ type: 'RECALL_CELL', r: d.source.r, c: d.source.c });
      }
      return;
    }

    // Gerçek bir sürükleme oldu — bırakılan hücrenin altındaki "hayalet"
    // click olayını yut (yoksa yanlışlıkla o hücrenin onClick'ini tetikler).
    // Dokunmatikte belirgin hareketten sonra tarayıcı genelde hiç click
    // üretmez, bu yüzden bayrak bir sonraki tick'te kendini temizler —
    // aksi halde sonraki (ilgisiz) bir dokunuşu sessizce yutabilirdi.
    suppressClickRef.current = true;
    setTimeout(() => {
      suppressClickRef.current = false;
    }, 0);

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

  const handleCellClick = (r: number, c: number) => {
    // Tahtada duran bir taşa (hangi hamlede oynandığına bakılmaksızın)
    // tıklanırsa, o hücreden geçen kelime(ler)in anlamı gösterilir.
    if (state.board[r][c]) {
      const words = [
        getFullWordAt(state.board, {}, r, c, 0, 1),
        getFullWordAt(state.board, {}, r, c, 1, 0),
      ].filter((w) => w.length >= 2);
      openMeaning(words);
      return;
    }
    if (state.isGameOver || me.isAI || state.swapMode) return;

    const sel = state.selectedTile !== null ? me.rack[state.selectedTile] : null;
    if (sel && sel.letter === '?') {
      // Joker taş: hangi harfe dönüşeceği seçilene kadar taş konmaz.
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
          for (const word of structural.words) {
            const result = await isValidWordRemote(trLower(word));
            if (result === false) {
              invalidWords.push(word);
            } else if (result === null) {
              // Sunucu hatası — yerel sözlüğe düş.
              serverOk = false;
              break;
            }
          }
        } finally {
          setValidating(false);
        }
        if (serverOk) {
          if (invalidWords.length > 0) {
            dispatch({
              type: 'SET_MESSAGE',
              message: formatInvalidWordsReason(invalidWords),
              messageType: 'err',
            });
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

  // Logodaki "Çık" onayının kimi teslim edeceği: önce sırası gelen (hâlâ
  // oyunda olan) insan oyuncu — hotseat'te herkes kendi sırasında teslim
  // olabilsin diye. Sırası AI'daysa ya da o oyuncu zaten teslim olduysa,
  // hesap sahibi (1. oyuncu, hâlâ oyundaysa) hedeflenir. İkisi de uygun
  // değilse (ör. herkes zaten ayrıldı) artık teslim edilecek biri yok —
  // buton yalnızca anasayfaya döner.
  const exitTargetIndex = (() => {
    const cur = state.players[state.current];
    if (cur && !cur.isAI && !cur.surrendered) return state.current;
    const p0 = state.players[0];
    if (p0 && !p0.isAI && !p0.surrendered) return 0;
    return null;
  })();
  const exitTargetPlayer = exitTargetIndex !== null ? state.players[exitTargetIndex] : null;
  // Bu teslimden sonra en az 2 oyuncu hâlâ oyunda kalacaksa (yoksa oyun anında biter).
  const othersWillContinue =
    state.players.filter((p) => !p.surrendered).length - 1 > 1;
  // Oyun "başlamış" sayılır: hesap sahibi (her zaman ilk hamleyi yapan 0.
  // oyuncu) ilk hamlesini yapmış VE bir sonraki oyuncu (genelde YZ) buna
  // cevap vermiş — yani en az 2 yarım-hamle oynanmış. Bundan önce (hiç
  // hamle yokken ya da hesap sahibi ilk hamlesini yapıp karşı taraf henüz
  // cevap vermemişken) logodan çıkmak, girişsiz kullanıcının çıkışıyla
  // aynı şekilde puansız/kayıtsız olmalı — henüz gerçek bir oyun olmadı.
  const gameStarted = state.turnCount >= 2;
  // Çıkış onay popup'ının başlığı. Hotseat dalı (insan olmayan hesap sahibi
  // dışında bir oyuncunun teslim olması) şu an hiç tetiklenmediğinden
  // (bkz. Setup.tsx — 1. oyuncu dışında herkes her zaman YZ) başlıksız bırakıldı.
  const exitDialogTitle =
    state.isGameOver || !exitTargetPlayer
      ? 'Oyun Bitti!'
      : !user || (exitTargetIndex === 0 && !gameStarted)
        ? 'Çıkış!'
        : exitTargetIndex === 0
          ? 'Teslim Oluyorsun!'
          : null;

  const dragHiddenKey = ghost && ghost.source.kind === 'placed'
    ? key(ghost.source.r, ghost.source.c)
    : null;
  const dragHiddenIndex = ghost && ghost.source.kind === 'rack' ? ghost.source.index : null;

  return (
    <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
      <GameHeader
        state={state}
        onLogoClick={() => setShowExitConfirm(true)}
        exitDisabled={spectating}
      />

      <main className="w-full flex flex-col items-center">
      <Board
        state={state}
        onCellClick={handleCellClick}
        moveStatus={moveStatus}
        onOpenHistory={() => setShowHistory(true)}
        dragHiddenKey={dragHiddenKey}
        dragOverKey={ghost?.overKey ?? null}
        dragOverValid={ghost?.overValid ?? false}
        onTilePointerDown={(r, c, e) =>
          beginDrag({ kind: 'placed', r, c, tile: state.placed[key(r, c)] }, e)
        }
        onTilePointerMove={moveDrag}
        onTilePointerUp={endDrag}
        onTilePointerCancel={cancelDrag}
      />

      <div className="w-full max-w-[680px] px-3 pb-3 pt-1 flex flex-col gap-1.5">
        <div
          className={`text-[11px] font-mono font-bold text-center min-h-[15px] py-0.5 ${
            MESSAGE_COLORS[liveMessageType]
          }`}
        >
          {liveMessage}
        </div>

        {spectating ? (
          <div className="shadow-raised flex items-center justify-between gap-2 rounded-md border border-border bg-panel px-4 py-3">
            <span className="font-mono text-[11px] font-bold uppercase tracking-[1px] text-muted">
              Teslim oldun — oyunu izliyorsun
            </span>
            <button
              onClick={() => setShowTiles(true)}
              className="btn-raised-neutral shrink-0 py-1.5 px-3 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform"
            >
              Torba <span className="text-[13px] text-accent">{state.bag.length}</span>
            </button>
          </div>
        ) : (
          <>
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
                    onClick={() => dispatch({ type: 'INIT' })}
                    className="btn-raised shrink-0 px-5 rounded-lg font-sans text-[15px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97]"
                  >
                    Yeni Oyun Aç
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
          </>
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

      {showExitConfirm && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div
            ref={exitConfirmRef}
            role="dialog"
            aria-modal="true"
            aria-label="Çıkış onayı"
            tabIndex={-1}
            className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
          >
            {exitDialogTitle && (
              <p className="text-base font-bold text-text font-sans">{exitDialogTitle}</p>
            )}
            <p className="text-sm text-text font-sans leading-relaxed">
              {state.isGameOver || !exitTargetPlayer
                ? 'Anasayfaya dönmek istediğinden emin misin?'
                : !user || (exitTargetIndex === 0 && !gameStarted)
                  ? 'Bu oyundan çıkmak istediğine emin misin?'
                  : exitTargetIndex === 0
                    ? 'Emin misin? Teslim olursan oyun bu şekilde kaydedilir ve Sanal Lig puanından 2 puan düşülür.'
                    : `${exitTargetPlayer.name} teslim olmak istediğine emin misin?${othersWillContinue ? ' Oyuna diğer oyuncular devam edebilir.' : ''}`}
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  setShowExitConfirm(false);
                  // Giriş yapılmamışsa hiçbir oyun tipi için kayıt tutulmadığından
                  // (kademeli teslim/oyun sonu ekranının anlamı olmadığından)
                  // doğrudan kurulum ekranına dön — oyun kaç kişilik olursa olsun.
                  // Aynı şekilde, hesap sahibi henüz gerçek bir hamle alışverişi
                  // olmadan (bkz. gameStarted) çıkarsa da ceza/kayıt yok.
                  if (
                    state.isGameOver ||
                    exitTargetIndex === null ||
                    !user ||
                    (exitTargetIndex === 0 && !gameStarted)
                  ) {
                    dispatch({ type: 'ABANDON' });
                    return;
                  }
                  if (exitTargetIndex === 0) {
                    const record = buildGameRecord(state, true, 0);
                    if (record) void saveGameDurable(record);
                  }
                  dispatch({ type: 'SURRENDER', index: exitTargetIndex });
                }}
                className="btn-raised-red flex-1 py-2.5 rounded-md bg-red text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Çık
              </button>
              <button
                onClick={() => setShowExitConfirm(false)}
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

      {meaning && (
        <MeaningModal entries={meaning.entries} onClose={() => setMeaning(null)} />
      )}

      {showTiles && (
        <RemainingTilesModal state={state} onClose={() => setShowTiles(false)} />
      )}

      {pendingWild && (
        <WildcardModal
          onSelect={(letter) => {
            dispatch({
              type: 'PLACE_TILE',
              r: pendingWild.r,
              c: pendingWild.c,
              wildLetter: letter,
              rackIndex: pendingWild.rackIndex,
            });
            setPendingWild(null);
          }}
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
    </div>
  );
}
