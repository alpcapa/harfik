// Kelimeki — Canlı oyun ekranı (Faz 3, 4. adım): Board/Rack/GameHeader'ı
// gerçek zamanlı Supabase state'ine bağlar. Yerel (hotseat) oyun ekranının
// (App.tsx) aynı bileşenlerini ve aynı doğrulama/puanlama fonksiyonlarını
// (validator.ts) yeniden kullanır — fark, "Oyna"/"Pas Geç"/"Değiştir"in
// artık `gameReducer`'ın PLAY/PASS/CONFIRM_SWAP'ını değil `submit_move`
// RPC'sini (src/lib/api.ts) çağırması, ve tahtanın/skorların yerelden değil
// `online_game_states`'ten (Realtime abonelikle) gelmesi.
//
// Taş sürükleme (fare + dokunmatik) App.tsx'teki sistemin birebir aynısı —
// bkz. oradaki "Taş sürükleme" bölümündeki yorumlar, burada tekrarlanmadı.
//
// Teslim olma manuel değil, zaman aşımlı: üstteki logo hâlâ yalnızca
// Canlı listesine döner, oyunu bitirmez — sırası gelen oyuncu 48 saat
// içinde hamle yapmazsa `check_turn_timeout` RPC'si onu otomatik teslim
// eder (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6", checkOnlineGameTurnTimeout
// aşağıdaki refresh() döngüsünden çağrılır).
import { useEffect, useMemo, useReducer, useRef, useState } from 'react';
import type { MouseEvent as ReactMouseEvent } from 'react';
import { Board } from './Board';
import { Rack } from './Rack';
import { GameHeader } from './GameHeader';
import { GameOver } from './GameOver';
import { MeaningModal } from './MeaningModal';
import { RemainingTilesModal } from './RemainingTilesModal';
import { PlayerScoreCard, type PlayerSummary } from './PlayerScoreCard';
import { MoveHistoryModal } from './MoveHistoryModal';
import {
  OFFLINE_LIVE_TITLE,
  OFFLINE_LIVE_BODY,
  OFFLINE_MOVE_NOTICE,
  OFFLINE_BACK_LABEL,
  isNetworkError,
} from '../utils/offlineNotice';
import { WildcardModal } from './WildcardModal';
import { FeedbackModal } from './FeedbackModal';
import { LeagueRewardsHost } from './LeagueRewardsHost';
import { ChatModal, type ChatParticipant } from './ChatModal';
import { Avatar } from './Avatar';
import { Tile as TileComponent } from './Tile';
import { createInitialState, gameReducer, isFirstMove, type Action } from '../game/gameReducer';
import { isWordSetReady } from '../data/wordSetLoader';
import { BINGO_BONUS, PLAYER_COLORS, SIZE, jokerFinishBonus } from '../game/constants';
import {
  calcScore,
  calcWordRawScores,
  computeInvasionSplit,
  formatInvalidWordsReason,
  validatePlacement,
  validatePlacementStructural,
} from '../utils/validator';
import { getFormedWords, getFullWordAt, key } from '../utils/board';
import { nearbyDraftCell } from '../utils/draftRescue';
import { buildRematchSlots, rematchHasAi, rematchOpponentNames } from '../utils/rematchSlots';
import { trLower } from '../utils/turkish';
import { hasSeenChatIntro, markChatIntroSeen, getChatLastReadAt, markChatRead } from '../utils/onboarding';
import { swallowNextClick } from '../utils/ghostClick';
import { useBoardZoom } from '../hooks/useBoardZoom';
import {
  checkOnlineGameTurnTimeout,
  createOnlineGame,
  fetchMeaning,
  fetchMyActiveChatReports,
  fetchMyChatMutes,
  fetchOnlineGameMessages,
  fetchOnlineGameMoves,
  fetchOnlineGameState,
  getMyOnlineRack,
  isValidWordRemote,
  markGameFinishesSeen,
  sendOnlineGameMessage,
  setOnlineGamePlatform,
  submitMove,
  subscribeOnlineGameMessages,
  subscribeOnlineGameState,
  triggerAiTurn,
} from '../lib/api';
import { ChatSettingsModal } from './ChatSettingsModal';
import { HelpModal } from './HelpModal';
import type { GameState, HistoryEntry, Tile as TileModel } from '../game/types';
import type { OnlineGame, OnlineGameMessageRow, OnlineGameSlot, OnlineMoveRow, WordMeaning } from '../lib/database.types';
import { reportClientError } from '../utils/errorReporting';

interface OnlineGameScreenProps {
  game: OnlineGame;
  myUserId: string;
  onBack: () => void;
}

const MESSAGE_COLORS: Record<string, string> = {
  ok: 'text-green',
  err: 'text-red',
  warn: 'text-gold',
  '': 'text-muted',
};

// App.tsx'teki eşik/kaldırma değerleriyle BİREBİR aynı — gerekçe orada
// (fare 6, parmak/kalem 10; tek eşik dokunmatikte sessiz kayıp üretiyordu).
const DRAG_THRESHOLD_MOUSE = 6;
const DRAG_THRESHOLD_TOUCH = 10;
const dragThresholdFor = (pointerType: string) =>
  pointerType === 'mouse' ? DRAG_THRESHOLD_MOUSE : DRAG_THRESHOLD_TOUCH;

/// BIRAKMA anındaki karar eşiği — `src/App.tsx` ile aynı sayı ve aynı
/// gerekçe (ölçümler orada yazılı): 10 px hayaleti göstermek için doğru ama
/// bırakma kararı için fazla dar, parmak o kadarını istemeden aşıyor.
const TAP_SLOP_ON_RELEASE = 24;
const DRAG_LIFT = 30;

/**
 * `promise` bir süre içinde sonuçlanmazsa reddeden bir sarmalayıcı — asıl
 * isteği iptal etmez, yalnızca çağıranın (burada `aiTriggeringRef`/
 * `timeoutCheckingRef` gibi "devam ediyor" bayraklarının) sonsuza dek askıda
 * kalmasını önler. Ağ isteği gerçekten çok geç dönerse bile bayrak zamanında
 * sıfırlanır, bir sonraki refresh tekrar deneyebilir.
 */
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Zaman aşımı (${ms}ms)`)), ms);
    promise.then(
      (v) => {
        clearTimeout(timer);
        resolve(v);
      },
      (e) => {
        clearTimeout(timer);
        reject(e);
      },
    );
  });
}

type DragSource =
  | { kind: 'rack'; index: number; tile: TileModel }
  | { kind: 'placed'; r: number; c: number; tile: TileModel };

/** online_game_moves satırlarını GameState.moveHistory ile aynı şekle çevirir (appendMoveHistory, gameReducer.ts, ile birebir aynı desen). */
function buildMoveHistory(rows: OnlineMoveRow[]): HistoryEntry[] {
  const entries: HistoryEntry[] = [];
  for (const row of rows) {
    const entry: HistoryEntry = { turn: row.turn, player: row.player_index, words: row.words, points: row.points };
    if (row.word_scores) entry.wordScores = row.word_scores;
    if (row.finish_joker_count) entry.finishJokerCount = row.finish_joker_count;
    if (row.bingo) entry.bingo = true;
    if (row.action !== 'play') entry.action = row.action;
    if (row.action === 'exchange') entry.tileCount = row.tile_count;
    if (row.lost_shares && row.lost_shares.length > 0) {
      entry.lostShares = row.lost_shares;
    }
    entries.push(entry);
    for (const s of row.lost_shares ?? []) {
      entries.push({ turn: row.turn, player: s.to, words: row.words, points: s.amount, invasionFrom: row.player_index });
    }
  }
  return entries;
}

export function OnlineGameScreen({ game, myUserId, onBack }: OnlineGameScreenProps) {
  // Sarmalayıcı reducer'dan (aşağıda) önce lazım — sade bir hesap
  // olduğundan (`game.slots` en fazla 4 öğe) useMemo'ya gerek yok.
  const mySlotIndex = game.slots.findIndex((s) => s.type === 'human' && s.user_id === myUserId);

  // NÖBETÇİ (27 Ağustos 2026) — koltuk indeksi POZİSYONELDİR, yani `slots`
  // dizisinin uzunluğu `player_count` ile birebir olmak ZORUNDA. O gün
  // `list_my_online_games` bir slotu ÇOĞALTIYORDU (`friend_requests` karşılıklı
  // çift → `jsonb_agg` aynı slotu iki kez yazıyordu) ve sonraki tüm indeksler
  // kayıyordu: oyuncu KENDİ köşesine taş koyamıyor, BAŞKASININ köşesine
  // koyunca "geçerli" görüyor ama sunucu haklı olarak reddediyordu.
  // Hata SESSİZDİ — hiçbir yerde iz bırakmadı, teşhis elle SQL koşularak
  // yapıldı. RPC düzeltildi; bu kontrol tekrarını GÖRÜNÜR kılıyor.
  const slotCountMismatch = game.slots.length !== game.player_count;
  useEffect(() => {
    if (!slotCountMismatch) return;
    reportClientError(
      new Error(
        `online_game slots uzunluğu player_count ile uyuşmuyor: ` +
          `${game.slots.length} ≠ ${game.player_count} (oyun ${game.id})`,
      ),
      'manual',
      'online_game.slot_count_mismatch',
    );
  }, [slotCountMismatch, game.slots.length, game.player_count, game.id]);
  const mySlotIndexRef = useRef(mySlotIndex);
  mySlotIndexRef.current = mySlotIndex;

  // gameReducer.ts'teki PLACE_TILE/RECALL_CELL/RECALL_ALL/SHUFFLE_RACK gibi
  // salt yerel düzenleme action'ları hep `state.current`'ın (SIRASI GELEN
  // oyuncunun) rafı üzerinden işler — yerel hotseat/YZ oyununda bu doğru
  // varsayım, çünkü UI zaten yalnızca sırası gelen oyuncunun düzenleme
  // yapmasına izin verir. Online'da ise sıra bende olmasa bile (rakibi/
  // YZ'yi beklerken egzersiz amaçlı taş yerleştirme, bkz. `canEdit`)
  // düzenleme yapabildiğimden, gameReducer'ı bu action'lar için `current`'ı
  // geçici olarak KENDİ koltuğuma (mySlotIndex) sabitleyerek çağırıp,
  // sonucun `current` alanını gerçek sunucu sırasına geri yüklüyoruz —
  // aksi halde PLACE_TILE gibi bir action, benim değil SIRASI GELEN
  // oyuncunun (sahte/dolgu) rafından taş düşürmeye çalışırdı. Tek istisna
  // `SYNC_ONLINE_STATE`: `current`'ı GERÇEKTEN sunucudan gelen değere göre
  // belirleyen tek action, ona hiç dokunulmuyor. `PLAY`/`PASS`/
  // `CONFIRM_SWAP` gibi sırayı gerçekten ilerleten action'lar bu ekrandan
  // hiç dispatch edilmiyor (`submitMove` RPC'si kullanılıyor, bkz. dosya
  // başı yorumu) — yani bu sarmalama yalnızca yukarıdaki düzenleme
  // action'ları için anlamlı, `current`'ı asıl değiştiren hiçbir action
  // burada bu yoldan geçmiyor. Ref üzerinden okunuyor ki `useReducer`'a
  // geçilen fonksiyon referansı hep sabit kalsın.
  const onlineGameReducerRef = useRef((state: GameState, action: Action): GameState => {
    const idx = mySlotIndexRef.current;
    if (action.type === 'SYNC_ONLINE_STATE' || idx < 0 || state.current === idx) {
      return gameReducer(state, action);
    }
    const next = gameReducer({ ...state, current: idx }, action);
    return { ...next, current: state.current };
  });

  const [state, dispatch] = useReducer(onlineGameReducerRef.current, undefined, createInitialState);
  const [moveRows, setMoveRows] = useState<OnlineMoveRow[]>([]);
  const [loaded, setLoaded] = useState(false);
  // İlk yükleme başarısız olduysa — "ekranı koru" davranışı yalnızca
  // TAZELEMEDE doğru; ilk yüklemede korunacak bir şey yok ve ekran beyaz
  // "Yükleniyor…"da asılı kalıyordu (14 Ağustos 2026, cihaz testi).
  const [loadFailed, setLoadFailed] = useState(false);
  // `refresh` effect'in içinde tanımlı ve bağımlılıkları `[game.id,
  // mySlotIndex]` — `loaded`ı closure'dan okumak İLK render'ın (false)
  // değerine saplanırdı; "yüklenmiş ekranı koru" kararı bu ref'ten veriliyor.
  const loadedRef = useRef(false);
  // Panelin "Tekrar Dene"si effect'in içindeki refresh'i çağırabilsin diye
  // (App.tsx'teki `refreshCloudSavesRef` deseni).
  const refreshRef = useRef<() => void>(() => {});
  const [busy, setBusy] = useState(false);
  const [validating, setValidating] = useState(false);
  /**
   * SON gönderim denememin sonucu — `state.message`'tan AYRI tutuluyor
   * (14 Ağustos 2026, cihaz testi: uçak modunda OYNA'ya basınca hiçbir şey
   * olmuyordu).
   *
   * Sebep: aşağıdaki `myTurnValidNote` (6 Ağustos 2026) "geçerli taslak +
   * sıra sende" iken mesaj satırını KOŞULSUZ türetiyor — bu, bayat
   * `state.message`'ların satırı ele geçirmesini engellemek için doğru bir
   * kural, ama gönderim hatasını da yutuyordu: hamle reddedilince taşlar
   * tahtada kaldığından taslak HÂLÂ geçerli oluyor ve `SET_MESSAGE` ile
   * yazılan hata hiçbir zaman görünmüyordu. Hata BAYAT DEĞİL — kullanıcının
   * az önce bastığı butonun sonucu, dolayısıyla türetilen nottan önce gelir.
   *
   * Taslak her değiştiğinde sıfırlanır (aşağıdaki effect): kullanıcı taşı
   * oynatmaya başladığı an hata artık geçmişe aittir. `state.message`'a
   * yazmak yerine ayrı bir state olması, reducer'ın (motor dosyası — golden
   * vector paritesi) hiç değişmemesini de sağlıyor.
   */
  const [submitError, setSubmitError] = useState<string | null>(null);
  // Taslağın imzası — hücre + harf (joker harfi değişince de tazelensin diye
  // `wildLetter` dahil). Değiştiği an son gönderimin hatası geçmişe aittir.
  const placedSignature = Object.entries(state.placed)
    .map(([k, t]) => `${k}:${t.letter}${t.wildLetter ?? ''}`)
    .sort()
    .join('|');
  useEffect(() => {
    setSubmitError(null);
  }, [placedSignature]);
  const [showHistory, setShowHistory] = useState(false);
  // Tahtanın alt şeridindeki "Nasıl Oynanır?" linki (14 Ağustos 2026) —
  // yerel ekranda Tutorial'ın state'i yeniden kullanılıyor, burada öyle bir
  // state olmadığından kendi bayrağı var.
  const [showHelp, setShowHelp] = useState(false);
  const [showTiles, setShowTiles] = useState(false);
  // Header'daki skor kutusuna dokunulan oyuncunun skor kartı.
  const [scoreCardPlayer, setScoreCardPlayer] = useState<PlayerSummary | null>(null);
  const [showFeedback, setShowFeedback] = useState(false);
  const [gameOverDismissed, setGameOverDismissed] = useState(false);

  // Bitiş modalını GÖRDÜ → bu oyun için "Son Oynananlar"da "YENİ" rozeti
  // çıkmasın (3 Eylül 2026). Bunu yapmazsak oyunu bitiren hamleyi yapan
  // kişi — yani modalı gözüyle gören kişi — kendi oyunu için de haber
  // rozeti alırdı.
  //
  // ⚠ TEK oyun işaretleniyor, toplu DEĞİL: o sırada görülmemiş BAŞKA
  // oyunları da temizlemek, kullanıcının hiç görmediği haberleri sessizce
  // yutardı.
  //
  // Sonucuna bakılmıyor: düşerse işaret sunucuda durur ve kullanıcı bu oyun
  // için bir kez fazladan "YENİ" görür — zararsız yön. Tersi (görmediğini
  // görülmüş saymak) bilgi kaybı olurdu.
  // Ref bir boolean DEĞİL, işaretlenen oyunun kimliği: bileşen açıkken
  // başka bir oyuna geçilirse (bildirimden yönlendirme) boolean ikinci oyunu
  // sessizce atlardı.
  const finishMarkedRef = useRef<string | null>(null);
  useEffect(() => {
    if (!state.isGameOver || finishMarkedRef.current === game.id) return;
    finishMarkedRef.current = game.id;
    void markGameFinishesSeen(game.id);
  }, [state.isGameOver, game.id]);
  const [showPassConfirm, setShowPassConfirm] = useState(false);
  /**
   * Oyun bitince "Tekrar Oyna" akışı: onay → aynı kadroyla yeni bir Canlı
   * oyun kur (insan koltuklarına davet gider) → sonuç. `error` dolu olan
   * `sent` fazı sunucunun reddini (ör. artık arkadaş değilseniz) gösterir.
   */
  const [rematch, setRematch] = useState<
    | { phase: 'confirm' }
    | { phase: 'busy' }
    | { phase: 'sent'; names: string[]; withAi: boolean }
    | { phase: 'error'; message: string }
    | null
  >(null);
  const [pendingWild, setPendingWild] = useState<
    { r: number; c: number; rackIndex?: number; editing?: boolean } | null
  >(null);
  const [invasionConfirm, setInvasionConfirm] = useState<{
    list: { ownerName: string; ownerPts: number }[];
    score: number;
    onConfirm: () => void;
  } | null>(null);
  const [meaning, setMeaning] = useState<{ entries: { word: string; data: WordMeaning | null; loading: boolean }[] } | null>(
    null,
  );

  // Oyun İçi Mesajlaşma — Faz 1 (yalnızca Canlı oyunlar).
  const [chatMessages, setChatMessages] = useState<OnlineGameMessageRow[]>([]);
  const [showChat, setShowChat] = useState(false);
  const [showChatIntro, setShowChatIntro] = useState(false);
  const [newMessagePopup, setNewMessagePopup] = useState<OnlineGameMessageRow | null>(null);
  const [unreadCount, setUnreadCount] = useState(0);

  // Oyun İçi Mesajlaşma — Faz 2 (sessize alma / raporlama).
  const [showChatSettings, setShowChatSettings] = useState(false);
  // Doluysa Ayarlar paneli doğrudan bu kişinin detayıyla açılır — sohbetteki
  // bir 🚫/🚩 rozetine tıklanınca (bkz. handleOpenParticipantSettings).
  const [chatSettingsInitialParticipant, setChatSettingsInitialParticipant] = useState<string | null>(null);
  const [mutedUserIds, setMutedUserIds] = useState<Set<string>>(new Set());
  const [reportedUserIds, setReportedUserIds] = useState<Set<string>>(new Set());
  // Realtime insert handler'ı mount anında sabitlenen bir closure içinde
  // çalıştığından ([game.id, mySlotIndex, myUserId] bağımlılığı), güncel
  // mute setini oradan okuyabilmek için bir ref aynası tutuluyor — aksi
  // halde her (un)mute'ta tüm sohbet aboneliğinin sökülüp yeniden
  // kurulması gerekirdi (mesaj kaçırma riski, dragRef/suppressClickRef ile
  // aynı "ref aynası" deseni).
  const mutedUserIdsRef = useRef<Set<string>>(new Set());
  useEffect(() => {
    mutedUserIdsRef.current = mutedUserIds;
  }, [mutedUserIds]);

  // ── Taş sürükleme (App.tsx'teki sistemle birebir aynı) ─────────────────
  const dragRef = useRef<{ source: DragSource; startX: number; startY: number; moved: boolean } | null>(null);
  // Tahta yakınlaştırması — App.tsx ile AYNI hook, aynı davranış
  // (bkz. src/utils/boardZoom.ts; iki ekranın deseni paylaşma kuralı).
  const boardZoom = useBoardZoom(() => dragRef.current !== null);
  const [ghost, setGhost] = useState<{
    x: number;
    y: number;
    source: DragSource;
    overKey: string | null;
    overValid: boolean;
  } | null>(null);

  useEffect(() => {
    const preventScrollWhileDragging = (e: TouchEvent) => {
      if (dragRef.current) e.preventDefault();
    };
    document.addEventListener('touchmove', preventScrollWhileDragging, { passive: false });
    return () => document.removeEventListener('touchmove', preventScrollWhileDragging);
  }, []);

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

  // YZ turunu tetiklemenin TEK yolu burası — bilinçli olarak uygulama
  // açılışına/mount'a bağlı ayrı bir arka plan taraması YOK (eski
  // `App.tsx`'teki `triggerPendingAiTurns`, `src/utils/onlineAiTurn.ts,
  // kaldırıldı): sıra bir YZ koltuğuna geçtiği an, o değişikliği yapan
  // insan oyuncunun kendi bu ekranı zaten `online_game_states`'e abone
  // olduğundan (`subscribeOnlineGameState`), kendi hamlesinin Realtime
  // yankısı `refresh()`'i hemen tetikler — YZ'nin sırası "uygulama tekrar
  // açılana kadar" değil, 3. oyuncunun hamlesinin hemen ardından otomatik
  // oynanır. Birden fazla istemci (ör. başka bir katılımcının ekranı da
  // açıksa) aynı anda tetiklese de `submit_move`'un satır kilidi çifte
  // oynamayı zaten engelliyor; `aiTriggeringRef` yalnızca bu sekmenin kendi
  // ardışık refresh'lerinin (focus/visibility gibi) henüz sonuçlanmamış
  // aynı YZ turunu gereksiz yere tekrar tetiklemesini önlüyor.
  const aiTriggeringRef = useRef(false);
  // check_turn_timeout no-op'tur süre dolmadıysa — burada da aynı "kendi
  // ardışık refresh'lerini üst üste bindirme" korumasını taşıyor.
  const timeoutCheckingRef = useRef(false);

  // Platform telemetrisi (14 Ağustos 2026) — bu oyunda BU kullanıcının hangi
  // istemciden (web/ios/android/app-web) oynadığını oyun başına bir kez
  // yazar. Yerel oyunlarda bu bilgi `games.platform` ile geliyor ama Canlı'da
  // o satırı sunucu yazdığından istemci oraya hiç ulaşamıyor; mobil lansmanı
  // ölçülebilsin diye ayrı bir tablo (`online_game_clients`) kullanılıyor.
  // BİLEREK refresh() döngüsünün DIŞINDA, kendi effect'inde: telemetri, oyun
  // durumu senkronuyla aynı kod yolunu paylaşmamalı (bir hatası oyunu
  // etkilemesin) ve her Realtime olayında tekrar yazılmasının anlamı yok —
  // upsert olduğundan mükerrer çağrı zararsız, sadece gereksiz.
  useEffect(() => {
    if (mySlotIndex < 0) return;
    void setOnlineGamePlatform(game.id);
  }, [game.id, mySlotIndex]);

  useEffect(() => {
    if (mySlotIndex < 0) return;
    let cancelled = false;
    // İlk yükleme düşerse ekran kendi kendini onarır — kullanıcı "Tekrar
    // Dene"ye basmak ZORUNDA kalmasın (LiveGamesTab'daki aynı merdiven ve
    // aynı gerekçe, 21 Ağustos 2026). Buradaki 10 dakikalık periyodik tarama
    // bu iş için fazla seyrek: ağ birkaç saniyede geri geldiğinde kullanıcı
    // hâlâ hata panelinde oturuyor olurdu.
    const AUTO_RETRY_STEPS_MS = [3000, 8000, 20000, 30000];
    let autoRetryStep = 0;
    let autoRetryTimer: number | null = null;
    const clearAutoRetry = () => {
      if (autoRetryTimer != null) {
        window.clearTimeout(autoRetryTimer);
        autoRetryTimer = null;
      }
    };
    const scheduleAutoRetry = () => {
      if (autoRetryTimer != null || cancelled) return;
      if (document.visibilityState !== 'visible') return;
      const step = Math.min(autoRetryStep, AUTO_RETRY_STEPS_MS.length - 1);
      autoRetryStep = step + 1;
      autoRetryTimer = window.setTimeout(() => {
        autoRetryTimer = null;
        void refresh();
      }, AUTO_RETRY_STEPS_MS[step]);
    };
    const refresh = async () => {
      // Üç çağrının HEPSİ bu try'ın içinde olmak ZORUNDA: `getMyOnlineRack`
      // hatada `throw` ediyor (`fetchOnlineGameState`/`fetchOnlineGameMoves`
      // ise null/[] dönüyor). İlk sürümde yalnızca "null döndü" dalı ele
      // alınmıştı ve çevrimdışıyken rack çağrısı ÖNCE fırladığından
      // `Promise.all` reddediliyor, `setLoadFailed` satırına hiç
      // ulaşılmıyordu — ekran yine sonsuz "Yükleniyor…"da kalıyordu
      // (kullanıcı cihazda bildirdi, 14 Ağustos 2026). Portun `loadGame`'i
      // üçünü de tek bir try/catch'e aldığından orada bu delik yoktu; testim
      // de o yüzden geçmişti. Hangi çağrının nasıl başarısız olduğu
      // kullanıcı için önemsiz — "yükleyemedik" tek bir sonuç.
      let publicState: Awaited<ReturnType<typeof fetchOnlineGameState>> = null;
      let myRack: TileModel[] = [];
      let rows: OnlineMoveRow[] = [];
      try {
        [publicState, myRack, rows] = await Promise.all([
          fetchOnlineGameState(game.id),
          getMyOnlineRack(game.id),
          fetchOnlineGameMoves(game.id),
        ]);
      } catch (err) {
        console.error('[Kelimeki] Canlı oyun durumu alınamadı:', err);
        publicState = null;
      }
      if (cancelled) return;
      if (!publicState) {
        // Sunucuya ulaşılamadı. Zaten yüklenmiş bir ekran varsa ona
        // DOKUNMUYORUZ (bayat veri, hiç veriden iyidir); yüklenmemişse
        // kullanıcıyı sonsuz "Yükleniyor…"da bırakmak yerine anlatıyoruz.
        if (!loadedRef.current) setLoadFailed(true);
        scheduleAutoRetry();
        return;
      }
      dispatch({ type: 'SYNC_ONLINE_STATE', publicState, myRack, mySlotIndex });
      setMoveRows(rows);
      loadedRef.current = true;
      setLoaded(true);
      setLoadFailed(false);
      clearAutoRetry();
      autoRetryStep = 0;

      if (!publicState.is_game_over && !aiTriggeringRef.current) {
        const currentSlot = game.slots[publicState.current];
        if (currentSlot?.type === 'ai') {
          aiTriggeringRef.current = true;
          withTimeout(triggerAiTurn(game.id), 20000)
            .catch((err) => console.error('[Kelimeki] triggerAiTurn (OnlineGameScreen) hatası:', err))
            .finally(() => {
              aiTriggeringRef.current = false;
            });
        }
      }

      // Sırası gelen oyuncunun 48 saatlik süresi dolduysa otomatik teslim
      // eder (no-op'tur dolmadıysa) — herhangi bir katılımcının ekranı
      // açıkken bu taramayı yapması, oyunun kalıcı olarak asılı kalmasını
      // önler (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6").
      if (!publicState.is_game_over && !timeoutCheckingRef.current) {
        timeoutCheckingRef.current = true;
        withTimeout(checkOnlineGameTurnTimeout(game.id), 20000)
          .catch((err) => console.error('[Kelimeki] checkOnlineGameTurnTimeout (OnlineGameScreen) hatası:', err))
          .finally(() => {
            timeoutCheckingRef.current = false;
          });
      }
    };
    void refresh();
    const unsubscribe = subscribeOnlineGameState(game.id, () => {
      void refresh();
    });
    // Ekran kilitlenip/sekme arka plana alınınca Realtime websocket'i
    // askıya alınabiliyor (özellikle iOS Safari'de) — o sırada gelen bir
    // hamle olayı sessizce kaçırılır (postgres_changes canlı bir akıştır,
    // kaçırılan olay tekrar oynatılmaz). Ön plana/çevrimiçi'ye dönüldüğünde
    // emniyet için elle bir kez daha senkronize ediyoruz — önceden bunun
    // tek yolu sekmeden çıkıp tekrar girmekti.
    // Masaüstünde sekmeye dönüş genelde visibilitychange+focus'u (bazen
    // online'ı da) neredeyse aynı anda tetikliyor — kısa bir pencerede
    // birden fazlasını tek bir refresh()'e indirger.
    let lastForegroundRefresh = 0;
    const onForeground = () => {
      if (document.visibilityState !== 'visible') return;
      const now = Date.now();
      if (now - lastForegroundRefresh < 1000) return;
      lastForegroundRefresh = now;
      void refresh();
    };
    refreshRef.current = () => {
      // Elle deneme merdiveni sıfırlar: başarısız olursa otomatik zincir en
      // baştan (3s) sürsün, 30s'lik son basamaktan değil.
      clearAutoRetry();
      autoRetryStep = 0;
      void refresh();
    };
    document.addEventListener('visibilitychange', onForeground);
    window.addEventListener('focus', onForeground);
    window.addEventListener('online', onForeground);
    // Ekran açık kalıp hiçbir hamle/foreground olayı gerçekleşmezse (ör.
    // biri bekleme ekranını saatlerce açık bırakırsa) zaman aşımı hiç
    // taranmaz — bu periyodik tarama (foreground/realtime yoksa bile) o
    // süreyi kısaltır. 48 saatlik pencereye göre sık olması gerekmiyor.
    const intervalId = window.setInterval(() => void refresh(), 10 * 60 * 1000);
    return () => {
      cancelled = true;
      unsubscribe();
      document.removeEventListener('visibilitychange', onForeground);
      window.removeEventListener('focus', onForeground);
      window.removeEventListener('online', onForeground);
      window.clearInterval(intervalId);
      clearAutoRetry();
    };
  }, [game.id, mySlotIndex]);

  // Oyun İçi Mesajlaşma — Faz 1: online_game_states'in Realtime aboneliğinden
  // BAĞIMSIZ ayrı bir effect/kanal (farklı tablo) — ilk yükte tüm sohbeti
  // çeker, sonrasında yeni mesajları INSERT olayıyla dinler. Sohbet penceresi
  // kapalıyken gelen bir mesaj hem "yeni mesaj" popup'ını tetikler hem de
  // Mesajlaşma butonundaki okunmamış rozetini artırır.
  useEffect(() => {
    if (mySlotIndex < 0) return;
    let cancelled = false;
    // Mute/rapor setleri ile mesaj listesi BİRLİKTE (Promise.all) çekiliyor
    // ki baloncukların yanındaki 🚫/🚩 rozetleri mesajlarla AYNI anda
    // görünsün — ikisi ayrı/bağımsız fetch olsaydı hangisinin önce bittiği
    // garanti olmadığından, soğuk yüklemede rozetsiz bir an oluşabilirdi.
    // (Okunmamış sayacı 15 Ağustos 2026'dan beri mute'a bakmıyor, aşağı bkz.)
    // Ön plana dönüşte de çağrılabilsin diye bir fonksiyona alındı — aşağıya
    // bkz. Realtime kanalı askıya alınırsa kaçırılan mesaj kalıcı olarak
    // kaybolduğundan ilk yükleme tek başına yetmiyor.
    const loadMessages = () => {
      void Promise.all([
      // Kişi bazlı (oyuna göre filtrelenmez) — bu kişiyi başka bir oyunda
      // sessize almış/rapor etmişsem burada da işaretli gelir.
      fetchMyChatMutes(),
      fetchMyActiveChatReports(),
      fetchOnlineGameMessages(game.id),
    ]).then(([mutes, reported, rows]) => {
      if (cancelled) return;
      setMutedUserIds(mutes);
      setReportedUserIds(reported);
      setChatMessages(rows);
      // Bu cihazda bu oyun için "en son okunan mesaj" damgası hiç yoksa
      // (ör. bu özellik yeni devreye girdi ya da oyun ekranı bu cihazda
      // hiç açılmadı), mevcut TÜM geçmişi "okunmamış" saymak yanlış
      // pozitif üretiyordu — kullanıcı çoktan görmüş olabileceği eski
      // mesajlar için de kırmızı nokta çıkıyordu. Bunun yerine ilk
      // hesaplamada mevcut son mesaja (yoksa şu ana) kadar okunmuş kabul
      // edilip damga oradan başlatılıyor; kırmızı nokta yalnızca BUNDAN
      // SONRA gelecek gerçek yeni mesajlar için çıkar — geç giriş
      // özelliği (bkz. CLAUDE.md) bir sonraki ziyarette olduğu gibi çalışmaya devam eder.
      const lastReadAt = getChatLastReadAt(game.id);
      if (lastReadAt === null) {
        const seedAt =
          rows.length > 0
            ? rows.reduce((a, b) => (a.created_at > b.created_at ? a : b)).created_at
            : new Date().toISOString();
        markChatRead(game.id, seedAt);
        setUnreadCount(0);
        return;
      }
      // Sessize alma kırmızı noktayı ETKİLEMEZ (15 Ağustos 2026, kullanıcı
      // kararı) — mute yalnızca POPUP'ı bastırır. Gerekçe: oyunu bölen ve
      // taciz vektörü olan şey popup; alttaki nokta rahatsız etmiyor, üstelik
      // kullanıcı susturduğu kişinin ne yazdığını görmek isteyebilir (şikayet
      // etmek için bile). Önceden mute ikisini birden bastırıyordu.
      const unread = rows.filter(
        (r) => r.sender_user_id !== myUserId && r.created_at > lastReadAt,
      ).length;
      setUnreadCount(unread);
      });
    };
    loadMessages();
    const unsubscribe = subscribeOnlineGameMessages(game.id, (row) => {
      setChatMessages((cur) => (cur.some((m) => m.id === row.id) ? cur : [...cur, row]));
      setShowChat((open) => {
        if (!open) {
          // Nokta HER gönderen için artar; popup yalnızca susturulmamış
          // kişiler için açılır (bkz. yukarıdaki gerekçe).
          setUnreadCount((n) => n + 1);
          if (!mutedUserIdsRef.current.has(row.sender_user_id)) setNewMessagePopup(row);
        }
        return open;
      });
    });
    // Oyun state'i üç yoldan kurtarılıyordu (Realtime + periyodik tarama +
    // ön plana dönüş, yukarıdaki effect) ama SOHBET yalnızca Realtime'a
    // bağlıydı — oysa kaçırılan olayın kalıcı olarak kaybolması (postgres_
    // changes canlı bir akıştır, tekrar oynatılmaz) her iki tablo için de
    // geçerli. Sonuç: sekme/ekran arka plandayken gelen mesaj hiç görünmüyor,
    // tek çare oyundan çıkıp tekrar girmekti — kullanıcı bunu iki cihazla
    // yazışırken bildirdi (14 Ağustos 2026): "web'den app'e atılan mesajlar
    // anında çıkmıyor, setup'a çıkıp girince geliyor". Aynı üçlü dinleyici +
    // aynı 1sn debounce buraya da kuruldu.
    // Popup BİLEREK tetiklenmiyor (yalnızca Realtime dalı açar) — arka planda
    // biriken beş mesaj için beş popup değil, tek bir okunmamış rozeti.
    let lastForegroundChatLoad = 0;
    const onForeground = () => {
      if (document.visibilityState !== 'visible') return;
      const now = Date.now();
      if (now - lastForegroundChatLoad < 1000) return;
      lastForegroundChatLoad = now;
      loadMessages();
    };
    document.addEventListener('visibilitychange', onForeground);
    window.addEventListener('focus', onForeground);
    window.addEventListener('online', onForeground);
    return () => {
      cancelled = true;
      unsubscribe();
      document.removeEventListener('visibilitychange', onForeground);
      window.removeEventListener('focus', onForeground);
      window.removeEventListener('online', onForeground);
    };
  }, [game.id, mySlotIndex, myUserId]);

  // Sohbet açıkken (ilk açılışta ya da zaten açıkken yeni bir mesaj daha
  // gelirse) görülen en son mesajı cihaza yazar — bir sonraki ziyarette
  // (yukarıdaki yükleme effect'i) kırmızı nokta yalnızca bundan SONRAKİ,
  // kendi göndermediği mesajlar için çıkar.
  useEffect(() => {
    if (!showChat || chatMessages.length === 0) return;
    const latest = chatMessages.reduce((a, b) => (a.created_at > b.created_at ? a : b));
    markChatRead(game.id, latest.created_at);
  }, [showChat, chatMessages, game.id]);

  // Popup'taki mesaj zaten doğrudan ekranda gösterildiğinden (görüldüğünden),
  // popup'ı kapatmak (✕/"Kapat"/"Cevap Ver" — üçü de) o mesajı ve öncesini
  // okunmuş sayar; aksi halde kırmızı nokta popup kapatıldıktan sonra da
  // kalıcı kalıyordu (kullanıcı zaten gördüğü mesajı "yeni" sanıyordu).
  const closeMessagePopup = () => {
    if (newMessagePopup) markChatRead(game.id, newMessagePopup.created_at);
    setNewMessagePopup(null);
    setUnreadCount(0);
  };

  const wordsReady = isWordSetReady();
  const me = state.players[mySlotIndex];
  const canAct = loaded && !state.isGameOver && state.current === mySlotIndex && !!me;
  // Sıra kendisinde olmasa bile (rakibi/YZ'yi beklerken) taş yerleştirip
  // kelime doğrulaması deneyebilsin diye — "Oyna"/"Pas Geç"/"Değiştir" gibi
  // sunucuya GÖNDERİM yapan eylemler hâlâ yalnızca `canAct` (gerçek sırası)
  // ile açılıyor, ama taş yerleştirme/geri alma/karıştırma gibi salt yerel
  // düzenleme eylemleri oyun bitmediği ve katılımcı olduğu sürece her zaman
  // serbest. Rakip oynayıp sıra değiştiğinde (`SYNC_ONLINE_STATE`'in
  // `turnAdvanced` dalı, gameReducer.ts) yerel deneme taşları otomatik
  // rafa döner ve `canAct` (dolayısıyla "Oyna") yeniden hesaplanır.
  const canEdit = loaded && !state.isGameOver && !!me;
  // Sıra bir YZ koltuğundaysa hamle sunucuda (play-ai-turn Edge Function,
  // kelime listesini önbelleğe almadıysa birkaç saniye sürebilir) hesaplanıyor
  // olabilir — aşağıdaki banner'da bunu bir insanın sırasını beklemekten
  // ayırt etmek için kullanılıyor (bkz. o banner'daki not).
  const isAiTurn = !canAct && !state.isGameOver && game.slots[state.current]?.type === 'ai';

  /**
   * Header'daki bir skor kutusuna dokunulunca o koltuğun skor kartını açar.
   * Kimlik `game.slots`'tan geliyor — `state.players` (online state'in
   * public kopyası) yalnızca görünen adı taşır, `user_id` taşımaz.
   * `GameHeader` YZ koltuklarını zaten tıklanabilir yapmıyor; buradaki
   * `type !== 'human'` kontrolü ikinci bir güvenlik ağı (ör. slot dizisi
   * beklenmedik şekilde kısa gelirse).
   *
   * `PlayerSummary`, `likerToPlayerSummary` (GameHistoryModal) ile aynı
   * desende dolduruluyor: sunucu `list_my_online_games`'te görünen adı
   * zaten kısa kimlik kuralıyla (soyad yok) hesapladığından `display_name`
   * olarak veriliyor, ad/soyad alanları boş bırakılıyor.
   */
  const handlePlayerBoxClick = (index: number) => {
    const slot = game.slots[index];
    if (!slot || slot.type !== 'human') return;
    setScoreCardPlayer({
      id: slot.user_id,
      username: null,
      first_name: null,
      last_name: null,
      display_name: slot.name ?? state.players[index]?.name ?? 'Oyuncu',
      avatar_url: slot.avatar_url ?? null,
    });
  };

  // Raftan bir taş ya da tahtaya bu tur konmuş bir taş sürüklenmeye başlanır.
  const beginDrag = (source: DragSource, e: React.PointerEvent) => {
    if (!canEdit || state.swapMode) return;
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // Bazı tarayıcılarda desteklenmeyebilir/hata verebilir — sürükleme
      // yakalama olmadan da (elementFromPoint tabanlı hedef tespitiyle) çalışır.
    }
    dragRef.current = { source, startX: e.clientX, startY: e.clientY, moved: false };
  };

  const dropTargetsAt = (x: number, y: number) => {
    const el = document.elementFromPoint(x, y);
    const cellEl = el?.closest('[data-cell]') as HTMLElement | null;
    const rackEl = el?.closest('[data-rack]') as HTMLElement | null;
    return { cellEl, rackEl };
  };

  const liftedPoint = (clientY: number) => {
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

    // Sürükleme değil DOKUNUŞ olarak işle — iki dal da buradan geçer.
    const dokunusOlarakIsle = () => {
      if (d.source.kind === 'rack') {
        // Raf dokunuşu tahta çifti oluşturamaz (zoom kapsamı yalnızca tahta).
        boardZoom.markUnpairable();
        dispatch({ type: 'SELECT_TILE', index: d.source.index });
      } else {
        // Çiftin İKİNCİSİYSE geri alma yutulur ve zoom değişir — ilk dokunuş
        // taşı koyduysa ikinci vuruş onu geri ALMASIN (App.tsx ile aynı).
        if (boardZoom.registerCellTap(e.clientX, e.clientY)) return;
        tapPlacedTile(d.source.r, d.source.c, true);
      }
    };

    if (!d.moved) {
      // ⚠ Bu dal `dokunusOlarakIsle`nin KOPYASIYDI; 1 Eylül 2026'da tek
      // gövdeye indi (App.tsx'teki aynı düzeltme — zoom kapısı yalnızca
      // kopyalardan birine eklenince hareketsiz çift dokunuş çalışmıyordu).
      // Joker penceresinin compat click'i `tapPlacedTile` içinde yutuluyor
      // (gerekçe: `src/utils/ghostClick.ts`).
      dokunusOlarakIsle();
      return;
    }

    // TİTREŞİMLİ DOKUNUŞ: eşik aşıldı ama jest hiçbir yere GİTMEDİ (ya da
    // raf taşı hâlâ rafın üstünde bırakıldı) — bırakma değil, dokunuş.
    // Gerekçe/ölçümler `src/App.tsx`teki `TAP_SLOP_ON_RELEASE` yanında.
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

    // Sürükleme bitişinin hayalet click'i (bırakılan hücrenin onClick'i
    // tetiklenmesin).
    swallowNextClick();
    // Sürüklemeden sonraki dokunuş, öncekiyle çift oluşturup zoom'u kazara
    // açmasın (App.tsx ile aynı).
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
          dispatch({ type: 'MOVE_PLACED_TILE', from: { r: d.source.r, c: d.source.c }, to: { r, c } });
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

  const openMeaning = (words: string[]) => {
    const unique = [...new Set(words)];
    if (unique.length === 0) return;
    setMeaning({ entries: unique.map((word) => ({ word, data: null, loading: true })) });
    for (const word of unique) {
      void fetchMeaning(word).then((data) => {
        setMeaning((cur) =>
          cur ? { entries: cur.entries.map((e) => (e.word === word ? { ...e, data, loading: false } : e)) } : cur,
        );
      });
    }
  };

  /// Tahtaya BU turda konmuş bir taşa dokunma davranışı — tek kaynak.
  /// `swallow`: dokunuş pointer akışından geliyorsa (endDrag) ardından
  /// gelen uyumluluk click'i yutulmalı; tıklama akışından (ıskalama
  /// kurtarma) çağrılırken yutulacak bir şey yok.
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
    // Taşa dokunuş çift dokunuş BAŞLATAMAZ; joker penceresi anında açılır.
    boardZoom.markUnpairable();
    if (tile.wild) {
      setPendingWild({ r, c, editing: true });
    } else {
      dispatch({ type: 'RECALL_CELL', r, c });
    }
  };

  const handleCellClick = (r: number, c: number, e: ReactMouseEvent) => {
    // Çift dokunuşla zoom — kapsam/gerekçe App.tsx'in aynı dalında.
    if (!state.board[r][c]) {
      if (boardZoom.registerCellTap(e.clientX, e.clientY)) return;
      if (!state.placed[key(r, c)]) boardZoom.registerPairable(e.clientX, e.clientY);
    } else {
      boardZoom.markUnpairable();
    }
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
    // mümkün: taslak sürerken anlam penceresi hiç açılmaz, dokunuş sessizce
    // yutulur ve kullanıcı yeniden dener. Taslak boşken (rakibin sırası,
    // ya da kendi sıranda henüz taş koymadan) davranış DEĞİŞMEDİ.
    if (state.board[r][c]) {
      if (Object.keys(state.placed).length > 0) {
        // Iskalama kurtarma — gerekçe `src/utils/draftRescue.ts`'te,
        // yerel oyun ekranıyla (App.tsx) aynı desen.
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
    if (!canEdit || state.swapMode) return;

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

  const moveStatus = useMemo(() => {
    const placedKeys = Object.keys(state.placed);
    if (placedKeys.length === 0 || !wordsReady || !me) return null;
    // Sıra kendisinde olmasa bile (egzersiz amaçlı deneme) doğru
    // sonuç için köşe/ilk-hamle kontrolleri `state.current`'a (o an
    // asıl sırası gelen oyuncu, ben olmayabilirim) değil HER ZAMAN
    // `mySlotIndex`e göre yapılmalı — `isFirstMove` da `state.current`'a
    // bakan genel bir yardımcı olduğundan burada `current`'ı geçici olarak
    // `mySlotIndex`e sabitleyen bir kopya üzerinden çağrılıyor (aynı desen
    // `tilesState`'te de kullanılıyor, aşağıda).
    const myTurnState = { ...state, current: mySlotIndex };
    const result = validatePlacement(state.board, state.placed, mySlotIndex, me.corners, isFirstMove(myTurnState));
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

  // `online_game_states` mesaj/messageType taşımaz (bkz. dosya başı yorumu) —
  // SYNC_ONLINE_STATE her senkronda bunları '' yapar. Yerel oyundaki gibi
  // ("Ironman, ilk hamleni köşenden yap" / "X: +9 puan Kelimeler: ...")
  // anlamlı bir mesaj göstermek için son hamleyi (moveRows) aynı
  // gameReducer.ts şablonlarıyla burada yeniden metne çeviriyoruz — henüz hiç
  // hamle yoksa (oyunun ilk turu) startGame'deki köşe uyarısının birebir aynısı.
  const lastMoveMessage = useMemo((): { message: string; messageType: '' | 'ok' | 'warn' | 'err' } => {
    if (moveRows.length === 0) {
      const starter = state.players[0]?.name ?? '';
      return { message: `${starter}, kendi köşenden bir kelime kur.`, messageType: '' };
    }
    const row = moveRows[moveRows.length - 1];
    const moverName = state.players[row.player_index]?.name ?? 'Oyuncu';
    if (row.action === 'pass') {
      return { message: `${moverName} pas geçti.`, messageType: 'warn' };
    }
    if (row.action === 'exchange') {
      return {
        message: `${moverName} ${row.tile_count} taş değiştirdi ve sırasını kullandı.`,
        messageType: 'warn',
      };
    }
    if (row.action === 'surrender') {
      return { message: `${moverName} teslim oldu.`, messageType: 'warn' };
    }
    const finishBonus = jokerFinishBonus(row.finish_joker_count);
    const finishBonusNote = finishBonus > 0 ? ` (jokerli bitiş bonusu +${finishBonus})` : '';
    // Bingo notu — reducer'ın PLAY şablonuyla BİREBİR aynı olmak zorunda
    // (bkz. gameReducer.ts). Bayrak zaten satırda geliyor; `BINGO_BONUS`
    // puanı `row.points`'in içinde, not yalnızca onu açıklıyor.
    const bingoNote = row.bingo ? ` (Bingo bonusu +${BINGO_BONUS})` : '';
    const shares = row.lost_shares ?? [];
    const bonusNote =
      shares.length > 0
        ? ` (${shares.map((s) => `${s.amount} puanı ${state.players[s.to]?.name ?? 'Oyuncu'} kaptı`).join(', ')})`
        : '';
    const pts = row.points - finishBonus;
    return {
      message: `${moverName}: +${pts} puan${bonusNote}${bingoNote}${finishBonusNote} Kelimeler: ${row.words.join(', ')}`,
      messageType: 'ok',
    };
  }, [moveRows, state.players]);

  // Sunucu/doğrulama hatası `state.message`'a DEĞİL `submitError`e yazılır
  // (bkz. o state'in tanımındaki gerekçe) ve türetilmiş notların önüne
  // geçer; `state.message` yalnızca reducer'ın kendi anlatımını taşır ve
  // doluysa hesaplanan son-hamle mesajının önüne geçer. Oyun bittiyse
  // (endGame'in yerel karşılığı) gameReducer.ts'teki `endGame()` gibi bu her
  // şeyin önüne geçip kesin olarak "Oyun bitti." gösterir — son hamlenin
  // sonucu değil (o GameOver ekranının arkasında kalır).
  //
  // Sıra kendisinde DEĞİLKEN geçerli bir kelime kurulduğunda mesaj özel
  // olarak eziliyor: `PLACE_TILE` (gameReducer.ts) `state.message`'a
  // koşulsuz "Oyna tuşuyla kelimeyi onayla." yazıyor, ama bu ekranda "Oyna"
  // yalnızca `canAct` iken aktif — üstelik "Sıra: X" bandı da taş
  // yerleştirilir yerleştirilmez gizleniyor (yukarıdaki JSX). Sonuç,
  // kullanıcıyı PASİF bir butona basmaya çağıran, sebebi hiçbir yerde
  // yazmayan çelişkili bir ekrandı — özelliği yazan kişiyi bile yanılttı
  // (3 Ağustos 2026, gerçek kullanım). Doğrulama geri bildirimi (Board'daki
  // yeşil dış hat + puan rozeti) aynen kalıyor, yalnızca çağrı yerini
  // butonun neden kapalı olduğuna bırakıyor. Geçersiz kelimede bu gerekmiyor
  // — orada "Oyna"nın kapalı olmasının sebebi zaten hata metninde yazıyor.
  const offTurnValidNote =
    moveStatus?.valid && !canAct && !state.isGameOver
      ? isAiTurn
        ? `Kelime geçerli — ${state.players[state.current]?.name ?? 'Yapay Zeka'} hamlesini hesaplıyor…`
        : `Kelime geçerli — Sıra: ${state.players[state.current]?.name ?? 'Rakip'}`
      : null;
  // Sıra kendisindeyken GEÇERLİ taslak da türetilir (6 Ağustos 2026,
  // kullanıcı ekran görüntüleriyle buldu): önceden metin state.message /
  // lastMoveMessage'a kalıyordu ve AYNI tahta durumu üç farklı şey
  // söyleyebiliyordu — (1) taş seçmeden boş hücreye dokununca PLACE_TILE
  // guard'ının yazdığı bayat "Önce bir harf seç." (üstelik yeşil), (2)
  // ekran değiştirip dönünce SYNC_ONLINE_STATE mesajı silip satır rakibin
  // SON hamlesine ("Esiner: +13 puan…") düşüyordu, (3) taşla yeniden
  // oynanınca "Oyna tuşuyla kelimeyi onayla." geri geliyordu. Geçerli
  // taslak + sıra sende = her zaman aynı türetilmiş metin; senkron/bayat
  // yazım sonucu değiştiremez (offTurnValidNote'un kardeş kuralı).
  const myTurnValidNote =
    moveStatus?.valid && canAct && !state.isGameOver
      ? 'Oyna tuşuyla kelimeyi onayla.'
      : null;
  // `submitError` türetilmiş notlardan ÖNCE gelir (bkz. tanımındaki gerekçe):
  // taslak geçerli kalsa bile son gönderimin hatası görünmek zorunda.
  const liveMessage = moveStatus && !moveStatus.valid && moveStatus.reason
    ? moveStatus.reason
    : state.isGameOver
      ? 'Oyun bitti.'
      : submitError ?? offTurnValidNote ?? myTurnValidNote ?? (state.message || lastMoveMessage.message);
  const liveMessageType = moveStatus && !moveStatus.valid && moveStatus.reason
    ? 'err'
    : state.isGameOver
      ? ''
      : submitError
        ? 'err'
        : offTurnValidNote
          ? 'warn'
          : moveStatus?.valid
            ? 'ok'
            : state.message
              ? state.messageType
              : lastMoveMessage.messageType;

  const handlePlay = async () => {
    if (!wordsReady || !canAct || busy || !me) return;
    const placedCoords = Object.keys(state.placed).map((k) => k.split(',').map(Number) as [number, number]);
    // `placedCoords.length === 0` için sessiz bir erken dönüş BİLEREK YOK
    // (14 Ağustos 2026, cihaz testi): boş taslakta dönmek, hemen aşağıdaki
    // `validatePlacementStructural`ın ürettiği "Harf yerleştirilmedi."
    // mesajını ulaşılamaz kılıyordu — OYNA hiçbir şey yapmıyor, mesaj
    // satırında bir önceki metin ("Taşlar rafa geri alındı") duruyordu.
    // Yerel oyunda (App.tsx) böyle bir guard hiç yoktu: orası PLAY'i
    // reducer'a dispatch ediyor, reducer da aynı validator'dan geçip mesajı
    // yazıyor. Mobil port bu kararı Parça 88'de zaten almıştı
    // (online_game_screen.dart `_handlePlay` — oradaki yorum da bunu anlatıyor).
    const structural = validatePlacementStructural(state.board, state.placed, state.current, me.corners, isFirstMove(state));
    let words = structural.words ?? [];
    if (!structural.valid) {
      setSubmitError(structural.reason ?? 'Geçersiz hamle.');
      return;
    }

    // Bu ekran yalnızca Supabase gerçekten yapılandırılmışken (Canlı oyun bir
    // hesap gerektirir) hiç mount edilmediğinden, App.tsx'ten kopyalanan
    // isSupabaseConfigured kontrolü burada her zaman true'ydu — kaldırıldı.
    if (words.length > 0) {
      setValidating(true);
      const invalidWords: string[] = [];
      let serverOk = true;
      try {
        for (const w of words) {
          const result = await isValidWordRemote(trLower(w));
          if (result === false) invalidWords.push(w);
          else if (result === null) {
            serverOk = false;
            break;
          }
        }
      } finally {
        setValidating(false);
      }
      if (serverOk && invalidWords.length > 0) {
        setSubmitError(formatInvalidWordsReason(invalidWords));
        return;
      }
      if (!serverOk) {
        const local = validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
        if (!local.valid) {
          setSubmitError(local.reason ?? 'Geçersiz hamle.');
          return;
        }
        words = local.words ?? words;
      }
    } else {
      const local = validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
      if (!local.valid) {
        setSubmitError(local.reason ?? 'Geçersiz hamle.');
        return;
      }
      words = local.words ?? words;
    }

    const basePts = calcScore(state.board, state.placed, state.bonuses);
    const { shares } = computeInvasionSplit(placedCoords, state.current, state.players, basePts, state.board);

    const doSubmit = async () => {
      const wordScores = calcWordRawScores(state.board, state.placed, state.bonuses);
      const placements = Object.entries(state.placed).map(([k, tile]) => {
        const [r, c] = k.split(',').map(Number);
        return { r, c, letter: tile.letter, wild: tile.wild, wildLetter: tile.wildLetter };
      });
      setBusy(true);
      try {
        await submitMove(game.id, {
          action: 'play',
          placements,
          words,
          wordScores,
          basePoints: basePts,
          lostShares: shares.map((s) => ({ to: s.index, amount: s.amount })),
        });
      } catch (err) {
        // Ağ katmanı hatası → ne olduğunu anlatan metin; sunucunun KENDİ
        // reddi ("Sıra sende değil." gibi) olduğu gibi gösterilir.
        setSubmitError(
          isNetworkError(err)
            ? OFFLINE_MOVE_NOTICE
            : err instanceof Error
              ? err.message
              : 'Hamle gönderilemedi.',
        );
      } finally {
        setBusy(false);
      }
    };

    if (shares.length > 0) {
      setInvasionConfirm({
        list: shares.map((s) => ({ ownerName: state.players[s.index].name, ownerPts: s.amount })),
        score: basePts,
        onConfirm: doSubmit,
      });
    } else {
      await doSubmit();
    }
  };

  const handlePass = async () => {
    if (!canAct || busy) return;
    setBusy(true);
    try {
      await submitMove(game.id, { action: 'pass' });
    } catch (err) {
      setSubmitError(
        isNetworkError(err)
          ? OFFLINE_MOVE_NOTICE
          : err instanceof Error
            ? err.message
            : 'Hata oluştu.',
      );
    } finally {
      setBusy(false);
    }
  };

  /**
   * "Tekrar Oyna": biten oyunun kadrosunu AYNEN yeni bir Canlı oyuna taşır.
   * Sıralama kuralı ve `create_online_game`in üç kısıtı ORTAK dosyada —
   * `src/utils/rematchSlots.ts` (aynı mantık oyun geçmişindeki "Tekrar
   * Oyna"da da kullanılıyor; kopyalanırsa ayrışır).
   */
  const opponentNames = rematchOpponentNames(game.slots, myUserId);
  const hasAiSlot = rematchHasAi(game.slots);

  const handleRematch = async () => {
    setRematch({ phase: 'busy' });
    try {
      await createOnlineGame(game.player_count as 2 | 4, buildRematchSlots(game.slots, myUserId));
      setRematch({ phase: 'sent', names: opponentNames, withAi: hasAiSlot });
    } catch (err) {
      setRematch({ phase: 'error', message: err instanceof Error ? err.message : 'Davet gönderilemedi.' });
    }
  };

  const handleConfirmSwap = async () => {
    if (!canAct || busy || !me || state.swapSelection.length === 0) return;
    // ⚠ `swapSelection` seçildiği ANDAKİ rafın indeksleri. Araya sunucudan
    // bir durum güncellemesi girdiyse indeks sınır dışına düşebilir; burada
    // `me.rack[i].letter` okumak `TypeError` fırlatır ve bu satır `try`
    // bloğunun DIŞINDA olduğundan hata yakalanmadan kaçar. Eksik harfle
    // göndermek de YANLIŞ olurdu — o yüzden filtrelemiyoruz, gönderimi
    // İPTAL ediyoruz; kullanıcı güncel rafta yeniden seçer. Port bu
    // korumayı baştan beri taşıyordu (`online_game_screen.dart`), web'de
    // yoktu (5 Eylül 2026 hata avı geçişi, #25).
    if (state.swapSelection.some((i) => i < 0 || i >= me.rack.length)) return;
    const letters = state.swapSelection.map((i) => me.rack[i].letter);
    setBusy(true);
    try {
      await submitMove(game.id, { action: 'exchange', exchangeLetters: letters });
      dispatch({ type: 'TOGGLE_SWAP_MODE' });
    } catch (err) {
      setSubmitError(
        isNetworkError(err)
          ? OFFLINE_MOVE_NOTICE
          : err instanceof Error
            ? err.message
            : 'Hata oluştu.',
      );
    } finally {
      setBusy(false);
    }
  };

  if (mySlotIndex < 0) {
    return (
      <div className="min-h-[100dvh] w-full flex flex-col items-center justify-center gap-4 px-4 text-center">
        <p className="text-sm text-muted font-mono">Bu oyunun katılımcısı değilsin.</p>
        <button
          onClick={onBack}
          className="btn-raised py-2.5 px-6 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px]"
        >
          Geri Dön
        </button>
      </div>
    );
  }

  if (!loaded || !me) {
    return (
      <div className="min-h-[100dvh] w-full flex items-center justify-center px-4">
        {loadFailed ? (
          <div className="shadow-raised bg-panel border border-border rounded-2xl p-6 w-full max-w-sm flex flex-col gap-3 text-center">
            <p className="text-base font-bold text-text font-sans">{OFFLINE_LIVE_TITLE}</p>
            <p className="text-sm text-text font-sans leading-relaxed">{OFFLINE_LIVE_BODY}</p>
            <button
              onClick={() => {
                setLoadFailed(false);
                refreshRef.current();
              }}
              className="btn-raised w-full py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Tekrar Dene
            </button>
            <button
              onClick={onBack}
              className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-muted underline underline-offset-2"
            >
              ← {OFFLINE_BACK_LABEL}
            </button>
          </div>
        ) : (
          <p className="text-sm text-muted font-mono">Yükleniyor…</p>
        )}
      </div>
    );
  }

  const historyState = { ...state, moveHistory: buildMoveHistory(moveRows) };
  const dragHiddenKey = ghost && ghost.source.kind === 'placed' ? key(ghost.source.r, ghost.source.c) : null;
  const dragHiddenIndex = ghost && ghost.source.kind === 'rack' ? ghost.source.index : null;

  // Oyun İçi Mesajlaşma — Faz 1: gönderen user_id'sini isim/avatar/renge
  // çevirmek için — isim/avatar `game.slots`'un zenginleştirilmiş halinden
  // (list_my_online_games), renk sunucudaki güncel `state.players`'tan
  // (koltuk indeksi `game.slots` ile `state.players` arasında AYNIDIR).
  const chatParticipants: ChatParticipant[] = game.slots
    .map((s, seatIdx) => ({ s, seatIdx }))
    .filter((x): x is { s: Extract<OnlineGameSlot, { type: 'human' }>; seatIdx: number } => x.s.type === 'human')
    .map(({ s, seatIdx }) => ({
      userId: s.user_id,
      name: s.name ?? 'Oyuncu',
      avatarUrl: s.avatar_url ?? null,
      colorIndex: state.players[seatIdx]?.colorIndex ?? seatIdx,
    }));
  const chatSender = newMessagePopup
    ? chatParticipants.find((p) => p.userId === newMessagePopup.sender_user_id)
    : null;

  const handleOpenMessaging = () => {
    if (hasSeenChatIntro()) {
      setShowChat(true);
      setUnreadCount(0);
    } else {
      setShowChatIntro(true);
    }
  };

  // Oyun İçi Mesajlaşma — Faz 2: ChatSettingsModal'daki eylemlerden sonra
  // yerel state'i güncelleyen callback'ler — RPC zaten sunucuda kalıcı
  // hâle getirdi, burada yalnızca UI'ı (rozetler + realtime filtre için
  // kullanılan ref aynası) senkron tutuyoruz.
  const handleChatMuteChange = (targetUserId: string, muted: boolean) => {
    setMutedUserIds((cur) => {
      const next = new Set(cur);
      if (muted) next.add(targetUserId);
      else next.delete(targetUserId);
      return next;
    });
  };
  const handleChatReported = (targetUserId: string) => {
    setReportedUserIds((cur) => new Set(cur).add(targetUserId));
    handleChatMuteChange(targetUserId, true);
  };
  const handleChatReportWithdrawn = (targetUserId: string) => {
    setReportedUserIds((cur) => {
      const next = new Set(cur);
      next.delete(targetUserId);
      return next;
    });
  };
  // Mesajdaki bir 🚫/🚩 rozetine tıklanınca — Ayarlar panelini o kişinin
  // detayıyla doğrudan açar, listeyi atlar (kullanıcı isteği: "sessize
  // aldığını hatırlayıp basıp tekrar açabilsin").
  const handleOpenParticipantSettings = (userId: string) => {
    setChatSettingsInitialParticipant(userId);
    setShowChatSettings(true);
  };

  return (
    <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
      {/* Skor kutusuna dokunmak o oyuncunun skor kartını açar (kullanıcı
          isteği, 3 Ağustos 2026). Yalnızca Canlı oyunda — yerel/YZ ekranı
          (App.tsx) bu prop'u hiç geçmediğinden orada kutular eskisi gibi
          tıklanamaz kalıyor. YZ koltukları GameHeader'ın kendi `isAI`
          kontrolüyle zaten dışarıda. */}
      <GameHeader state={state} onLogoClick={onBack} onPlayerClick={handlePlayerBoxClick} />

      <main className="w-full flex flex-col items-center">
        <Board
          state={state}
          onCellClick={handleCellClick}
          moveStatus={moveStatus}
          onOpenHistory={() => setShowHistory(true)}
          onOpenHelp={() => setShowHelp(true)}
          onOpenMessaging={handleOpenMessaging}
          unreadMessageCount={unreadCount}
          dragHiddenKey={dragHiddenKey}
          dragOverKey={ghost?.overKey ?? null}
          dragOverValid={ghost?.overValid ?? false}
          onTilePointerDown={(r, c, e) => beginDrag({ kind: 'placed', r, c, tile: state.placed[key(r, c)] }, e)}
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
          {/* Sıra kendisinde değilken taş yerleştirmeye başlayınca (egzersiz/
              deneme, bkz. `canEdit`) bu banner yerine aşağıdaki mesaj satırı
              devreye giriyor — Board'daki geçerlilik/skor rozetiyle birlikte
              tıpkı sıra kendisindeymiş gibi anlık geri bildirim veriyor.
              Henüz hiç taş yerleştirmediyse (`!moveStatus`) banner kalıyor,
              böylece kimin sırası olduğu her zaman net kalıyor. */}
          {!canAct && !state.isGameOver && !moveStatus ? (
            <div className="shadow-raised flex items-center justify-center gap-2 rounded-md border border-red/40 bg-red/10 px-4 py-3">
              {isAiTurn && (
                <span className="w-2 h-2 rounded-full bg-red animate-pulse shrink-0" aria-hidden />
              )}
              <span className="font-mono text-[11px] font-bold uppercase tracking-[1px] text-red">
                {isAiTurn
                  ? `${state.players[state.current]?.name ?? 'Yapay Zeka'} hamlesini hesaplıyor…`
                  : `Sıra: ${state.players[state.current]?.name ?? 'Rakip'} — oynaması bekleniyor`}
              </span>
            </div>
          ) : (
            /* Yükseklik App.tsx'teki kardeşiyle BİREBİR aynı olmak zorunda —
               gerekçe ve ölçüm orada yazılı (17 Ağustos 2026, port paritesi). */
            <div
              className={`text-[11px] font-mono font-bold text-center min-h-[30px] py-0.5 flex items-center justify-center ${MESSAGE_COLORS[liveMessageType]}`}
            >
              {liveMessage}
            </div>
          )}

          <div className="flex gap-1.5 items-stretch">
            <div className="flex-1 min-w-0">
              <Rack
                tiles={me.rack}
                selectedTile={state.selectedTile}
                onSelect={(i) => {
                  if (state.swapMode) {
                    if (!canAct) return;
                    dispatch({ type: 'TOGGLE_SWAP_TILE', index: i });
                  } else {
                    if (!canEdit) return;
                    dispatch({ type: 'SELECT_TILE', index: i });
                  }
                }}
                title={me.name}
                color={PLAYER_COLORS[me.colorIndex]}
                draggable={canEdit}
                dragHiddenIndex={dragHiddenIndex}
                onTilePointerDown={(i, e) => beginDrag({ kind: 'rack', index: i, tile: me.rack[i] }, e)}
                onTilePointerMove={moveDrag}
                onTilePointerUp={endDrag}
                onTilePointerCancel={cancelDrag}
                swapMode={state.swapMode}
                swapSelection={state.swapSelection}
              />
            </div>
            {!state.swapMode && (
              state.isGameOver ? (
                <button
                  onClick={() => setRematch({ phase: 'confirm' })}
                  className="btn-raised shrink-0 px-5 rounded-lg font-sans text-[15px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97]"
                >
                  Tekrar Oyna
                </button>
              ) : (
                <button
                  disabled={!canAct || busy || validating || !wordsReady}
                  onClick={() => { void handlePlay(); }}
                  className="btn-raised shrink-0 px-5 rounded-lg font-sans text-[12px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97] disabled:opacity-35 disabled:cursor-not-allowed"
                >
                  {!wordsReady ? 'Yükleniyor…' : validating ? 'Kontrol…' : busy ? 'Gönderiliyor…' : 'Oyna'}
                </button>
              )
            )}
          </div>

          {state.swapMode ? (
            <div className="flex gap-1.5">
              <button
                disabled={!canAct || busy || state.swapSelection.length === 0}
                onClick={() => { void handleConfirmSwap(); }}
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
                disabled={!canAct || busy}
                onClick={() => setShowPassConfirm(true)}
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
                disabled={!canEdit}
                onClick={() => dispatch({ type: 'SHUFFLE_RACK' })}
                className="btn-raised-neutral flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
              >
                Karıştır
              </button>
              <button
                disabled={!canEdit}
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
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none">
            <p className="text-base font-bold text-text font-sans">Sınır İhlali!</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              Bu hamleden kazanacağın <strong className="text-green">{invasionConfirm.score}</strong> puanın{' '}
              {invasionConfirm.list.map((inv, i) => (
                <span key={i}>
                  <strong className="text-red">{inv.ownerPts}</strong> puanı <strong>{inv.ownerName}</strong> kullanıcısına
                  {i < invasionConfirm.list.length - 1 ? ', ' : ' '}
                </span>
              ))}
              vergi olarak gidecek.
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  const cb = invasionConfirm.onConfirm;
                  setInvasionConfirm(null);
                  void cb();
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
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none">
            <p className="text-base font-bold text-text font-sans">Pas Geçiyorsun!</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              Pas geçmek istediğinden emin misin? Sıran diğer oyuncuya geçer.
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  setShowPassConfirm(false);
                  void handlePass();
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

      {rematch && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none">
            <p className="text-base font-bold text-text font-sans">Tekrar Oyna</p>
            {rematch.phase === 'sent' ? (
              <>
                <p className="text-sm text-text font-sans leading-relaxed">Davetiniz gönderilmiştir.</p>
                <p className="text-xs text-muted font-mono leading-relaxed">
                  {rematch.names.join(', ')} yanıt verince oyun başlayacak.
                  {rematch.withAi && ' 4. koltuk Yapay Zeka.'}
                </p>
                <button
                  onClick={onBack}
                  className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
                >
                  Tamam
                </button>
              </>
            ) : rematch.phase === 'error' ? (
              <>
                <p className="text-sm text-red font-sans leading-relaxed">{rematch.message}</p>
                <button
                  onClick={() => setRematch(null)}
                  className="btn-raised-neutral py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
                >
                  Kapat
                </button>
              </>
            ) : (
              <>
                <p className="text-sm text-text font-sans leading-relaxed">
                  {opponentNames.join(', ')} ile aynı kadroda yeni bir oyun açılacak ve davet
                  gönderilecek.
                  {hasAiSlot && ' 4. koltuk yine Yapay Zeka olacak.'} Emin misin?
                </p>
                <div className="flex gap-2 mt-1">
                  <button
                    disabled={rematch.phase === 'busy'}
                    onClick={() => void handleRematch()}
                    className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-35"
                  >
                    {rematch.phase === 'busy' ? 'Gönderiliyor…' : 'Tekrar Oyna'}
                  </button>
                  <button
                    disabled={rematch.phase === 'busy'}
                    onClick={() => setRematch(null)}
                    className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-35"
                  >
                    Vazgeç
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {scoreCardPlayer && (
        <PlayerScoreCard member={scoreCardPlayer} onClose={() => setScoreCardPlayer(null)} />
      )}
      {meaning && <MeaningModal entries={meaning.entries} onClose={() => setMeaning(null)} />}
      {showTiles && (
        <RemainingTilesModal state={state} myIndex={mySlotIndex} onClose={() => setShowTiles(false)} />
      )}
      {showHistory && <MoveHistoryModal state={historyState} onClose={() => setShowHistory(false)} />}

      {showHelp && <HelpModal onClose={() => setShowHelp(false)} />}

      {showChatIntro && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none">
            <p className="text-base font-bold text-text font-sans">Oyun içi mesajlaşmaya hoşgeldiniz!</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              Buradan gruba mesaj atabilirsiniz. Mesaj herkesin ekranında popup şeklinde gözükür. Haydi, ilk mesajını gönder!
            </p>
            <button
              onClick={() => {
                markChatIntroSeen();
                setShowChatIntro(false);
                setShowChat(true);
                setUnreadCount(0);
              }}
              className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Devam
            </button>
          </div>
        </div>
      )}

      {newMessagePopup && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] px-6 pb-6 pt-12 flex flex-col gap-4 outline-none relative">
            <button
              onClick={() => closeMessagePopup()}
              aria-label="Kapat"
              className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none tap-expand w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
            >
              ✕
            </button>
            <div className="flex items-center gap-2">
              <Avatar url={chatSender?.avatarUrl} name={chatSender?.name ?? 'Oyuncu'} size={28} />
              <p className="text-sm font-bold text-text font-sans">{chatSender?.name ?? 'Oyuncu'}</p>
            </div>
            <p className="text-sm text-text font-sans leading-relaxed break-words">{newMessagePopup.message}</p>
            <div className="flex gap-2">
              <button
                onClick={() => {
                  closeMessagePopup();
                  setShowChat(true);
                }}
                className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Cevap Ver
              </button>
              <button
                onClick={() => closeMessagePopup()}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Kapat
              </button>
            </div>
          </div>
        </div>
      )}

      {showChat && (
        <ChatModal
          messages={chatMessages}
          participants={chatParticipants}
          myUserId={myUserId}
          onSend={(text) => sendOnlineGameMessage(game.id, text)}
          onClose={() => setShowChat(false)}
          onOpenSettings={() => {
            setChatSettingsInitialParticipant(null);
            setShowChatSettings(true);
          }}
          mutedUserIds={mutedUserIds}
          reportedUserIds={reportedUserIds}
          onOpenParticipantSettings={handleOpenParticipantSettings}
        />
      )}

      {showChatSettings && (
        <ChatSettingsModal
          gameId={game.id}
          participants={chatParticipants.filter((p) => p.userId !== myUserId)}
          mutedUserIds={mutedUserIds}
          reportedUserIds={reportedUserIds}
          onMuteChange={handleChatMuteChange}
          onReported={handleChatReported}
          onWithdrawn={handleChatReportWithdrawn}
          initialParticipantId={chatSettingsInitialParticipant}
          onClose={() => {
            setShowChatSettings(false);
            setChatSettingsInitialParticipant(null);
          }}
        />
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
          <TileComponent
            tile={ghost.source.tile}
            variant={ghost.source.kind === 'rack' ? 'rack' : 'placed'}
            color={ghost.source.kind === 'placed' && me ? PLAYER_COLORS[me.colorIndex] : undefined}
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

      {showFeedback && <FeedbackModal source="game_end" onClose={() => setShowFeedback(false)} />}

      {/* k-lig kutlama banner'ı — oyun sürerken bastırılır; oyun bitince
          suppress düşer ve host otomatik kontrol edip bekleyen kutlamayı
          gösterir (sunucu, games satırlarını bitişle aynı transaction'da
          yazdığından ek bir gecikme/tetikleyici gerekmez). */}
      <LeagueRewardsHost suppress={!state.isGameOver} />
    </div>
  );
}
