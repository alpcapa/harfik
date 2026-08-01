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
import { Board } from './Board';
import { Rack } from './Rack';
import { GameHeader } from './GameHeader';
import { GameOver } from './GameOver';
import { MeaningModal } from './MeaningModal';
import { RemainingTilesModal } from './RemainingTilesModal';
import { MoveHistoryModal } from './MoveHistoryModal';
import { WildcardModal } from './WildcardModal';
import { FeedbackModal } from './FeedbackModal';
import { ChatModal, type ChatParticipant } from './ChatModal';
import { Avatar } from './Avatar';
import { Tile as TileComponent } from './Tile';
import { createInitialState, gameReducer, isFirstMove, type Action } from '../game/gameReducer';
import { isWordSetReady } from '../data/wordSetLoader';
import { PLAYER_COLORS, jokerFinishBonus } from '../game/constants';
import {
  calcScore,
  calcWordRawScores,
  computeInvasionSplit,
  formatInvalidWordsReason,
  validatePlacement,
  validatePlacementStructural,
} from '../utils/validator';
import { getFormedWords, getFullWordAt, key } from '../utils/board';
import { trLower } from '../utils/turkish';
import { hasSeenChatIntro, markChatIntroSeen, getChatLastReadAt, markChatRead } from '../utils/onboarding';
import {
  checkOnlineGameTurnTimeout,
  fetchMeaning,
  fetchOnlineGameMessages,
  fetchOnlineGameMoves,
  fetchOnlineGameState,
  getMyOnlineRack,
  isSupabaseConfigured,
  isValidWordRemote,
  sendOnlineGameMessage,
  submitMove,
  subscribeOnlineGameMessages,
  subscribeOnlineGameState,
  triggerAiTurn,
} from '../lib/api';
import type { GameState, HistoryEntry, Tile as TileModel } from '../game/types';
import type { OnlineGame, OnlineGameMessageRow, OnlineGameSlot, OnlineMoveRow, WordMeaning } from '../lib/database.types';

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

// App.tsx'teki DRAG_THRESHOLD/DRAG_LIFT ile aynı değerler.
const DRAG_THRESHOLD = 6;
const DRAG_LIFT = 30;

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
  const [busy, setBusy] = useState(false);
  const [validating, setValidating] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [showTiles, setShowTiles] = useState(false);
  const [showFeedback, setShowFeedback] = useState(false);
  const [gameOverDismissed, setGameOverDismissed] = useState(false);
  const [showPassConfirm, setShowPassConfirm] = useState(false);
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

  // ── Taş sürükleme (App.tsx'teki sistemle birebir aynı) ─────────────────
  const dragRef = useRef<{ source: DragSource; startX: number; startY: number; moved: boolean } | null>(null);
  const [ghost, setGhost] = useState<{
    x: number;
    y: number;
    source: DragSource;
    overKey: string | null;
    overValid: boolean;
  } | null>(null);
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

  useEffect(() => {
    if (mySlotIndex < 0) return;
    let cancelled = false;
    const refresh = async () => {
      const [publicState, myRack, rows] = await Promise.all([
        fetchOnlineGameState(game.id),
        getMyOnlineRack(game.id),
        fetchOnlineGameMoves(game.id),
      ]);
      if (cancelled || !publicState) return;
      dispatch({ type: 'SYNC_ONLINE_STATE', publicState, myRack, mySlotIndex });
      setMoveRows(rows);
      setLoaded(true);

      if (!publicState.is_game_over && !aiTriggeringRef.current) {
        const currentSlot = game.slots[publicState.current];
        if (currentSlot?.type === 'ai') {
          aiTriggeringRef.current = true;
          triggerAiTurn(game.id)
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
        checkOnlineGameTurnTimeout(game.id)
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
    const onForeground = () => {
      if (document.visibilityState === 'visible') void refresh();
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
    void fetchOnlineGameMessages(game.id).then((rows) => {
      if (cancelled) return;
      setChatMessages(rows);
      // Bu cihazda daha önce (bir önceki ziyarette) nereye kadar okunduğu
      // bilinmiyorsa (hiç yok) ya da o andan SONRA gelen, kendisinin
      // GÖNDERMEDİĞİ bir mesaj varsa — sohbet kapalıyken de "Mesajlaşma"
      // butonunda kırmızı nokta çıksın diye (bkz. onboarding.ts).
      const lastReadAt = getChatLastReadAt(game.id);
      const unread = rows.filter(
        (r) => r.sender_user_id !== myUserId && (!lastReadAt || r.created_at > lastReadAt)
      ).length;
      setUnreadCount(unread);
    });
    const unsubscribe = subscribeOnlineGameMessages(game.id, (row) => {
      setChatMessages((cur) => (cur.some((m) => m.id === row.id) ? cur : [...cur, row]));
      setShowChat((open) => {
        if (!open) {
          setNewMessagePopup(row);
          setUnreadCount((n) => n + 1);
        }
        return open;
      });
    });
    return () => {
      cancelled = true;
      unsubscribe();
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
      if (d.source.kind === 'rack') {
        dispatch({ type: 'SELECT_TILE', index: d.source.index });
      } else if (d.source.tile.wild) {
        setPendingWild({ r: d.source.r, c: d.source.c, editing: true });
      } else {
        dispatch({ type: 'RECALL_CELL', r: d.source.r, c: d.source.c });
      }
      return;
    }

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

  const handleCellClick = (r: number, c: number) => {
    if (state.board[r][c]) {
      const words = [
        getFullWordAt(state.board, {}, r, c, 0, 1),
        getFullWordAt(state.board, {}, r, c, 1, 0),
      ].filter((w) => w.length >= 2);
      openMeaning(words);
      return;
    }
    if (!canEdit || state.swapMode) return;
    const sel = state.selectedTile !== null ? me.rack[state.selectedTile] : null;
    if (sel && sel.letter === '?') {
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
    const shares = row.lost_shares ?? [];
    const bonusNote =
      shares.length > 0
        ? ` (${shares.map((s) => `${s.amount} puanı ${state.players[s.to]?.name ?? 'Oyuncu'} kaptı`).join(', ')})`
        : '';
    const pts = row.points - finishBonus;
    return {
      message: `${moverName}: +${pts} puan${bonusNote}${finishBonusNote} Kelimeler: ${row.words.join(', ')}`,
      messageType: 'ok',
    };
  }, [moveRows, state.players]);

  // Sunucu/doğrulama hatası bir SET_MESSAGE ile burada anlık olarak
  // (bir sonraki senkrona kadar) `state.message`'a yazılır — doluysa o,
  // yukarıdaki hesaplanan son-hamle mesajının önüne geçer. Oyun bittiyse
  // (endGame'in yerel karşılığı) gameReducer.ts'teki `endGame()` gibi bu her
  // şeyin önüne geçip kesin olarak "Oyun bitti." gösterir — son hamlenin
  // sonucu değil (o GameOver ekranının arkasında kalır).
  const liveMessage = moveStatus && !moveStatus.valid && moveStatus.reason
    ? moveStatus.reason
    : state.isGameOver
      ? 'Oyun bitti.'
      : state.message || lastMoveMessage.message;
  const liveMessageType = moveStatus && !moveStatus.valid && moveStatus.reason
    ? 'err'
    : moveStatus?.valid
      ? 'ok'
      : state.isGameOver
        ? ''
        : state.message
          ? state.messageType
          : lastMoveMessage.messageType;

  const handlePlay = async () => {
    if (!wordsReady || !canAct || busy || !me) return;
    const placedCoords = Object.keys(state.placed).map((k) => k.split(',').map(Number) as [number, number]);
    if (placedCoords.length === 0) return;

    const structural = validatePlacementStructural(state.board, state.placed, state.current, me.corners, isFirstMove(state));
    let words = structural.words ?? [];
    if (!structural.valid) {
      dispatch({ type: 'SET_MESSAGE', message: structural.reason ?? 'Geçersiz hamle.', messageType: 'err' });
      return;
    }

    if (isSupabaseConfigured && words.length > 0) {
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
        dispatch({ type: 'SET_MESSAGE', message: formatInvalidWordsReason(invalidWords), messageType: 'err' });
        return;
      }
      if (!serverOk) {
        const local = validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
        if (!local.valid) {
          dispatch({ type: 'SET_MESSAGE', message: local.reason ?? 'Geçersiz hamle.', messageType: 'err' });
          return;
        }
        words = local.words ?? words;
      }
    } else {
      const local = validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
      if (!local.valid) {
        dispatch({ type: 'SET_MESSAGE', message: local.reason ?? 'Geçersiz hamle.', messageType: 'err' });
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
        dispatch({ type: 'SET_MESSAGE', message: err instanceof Error ? err.message : 'Hamle gönderilemedi.', messageType: 'err' });
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
      dispatch({ type: 'SET_MESSAGE', message: err instanceof Error ? err.message : 'Hata oluştu.', messageType: 'err' });
    } finally {
      setBusy(false);
    }
  };

  const handleConfirmSwap = async () => {
    if (!canAct || busy || !me || state.swapSelection.length === 0) return;
    const letters = state.swapSelection.map((i) => me.rack[i].letter);
    setBusy(true);
    try {
      await submitMove(game.id, { action: 'exchange', exchangeLetters: letters });
      dispatch({ type: 'TOGGLE_SWAP_MODE' });
    } catch (err) {
      dispatch({ type: 'SET_MESSAGE', message: err instanceof Error ? err.message : 'Hata oluştu.', messageType: 'err' });
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
      <div className="min-h-[100dvh] w-full flex items-center justify-center">
        <p className="text-sm text-muted font-mono">Yükleniyor…</p>
      </div>
    );
  }

  const historyState = { ...state, moveHistory: buildMoveHistory(moveRows) };
  const tilesState = { ...state, current: mySlotIndex };
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

  return (
    <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
      <GameHeader state={state} onLogoClick={onBack} />

      <main className="w-full flex flex-col items-center">
        <Board
          state={state}
          onCellClick={handleCellClick}
          moveStatus={moveStatus}
          onOpenHistory={() => setShowHistory(true)}
          onOpenMessaging={handleOpenMessaging}
          hasUnreadMessage={unreadCount > 0}
          dragHiddenKey={dragHiddenKey}
          dragOverKey={ghost?.overKey ?? null}
          dragOverValid={ghost?.overValid ?? false}
          onTilePointerDown={(r, c, e) => beginDrag({ kind: 'placed', r, c, tile: state.placed[key(r, c)] }, e)}
          onTilePointerMove={moveDrag}
          onTilePointerUp={endDrag}
          onTilePointerCancel={cancelDrag}
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
            <div
              className={`text-[11px] font-mono font-bold text-center min-h-[15px] py-0.5 ${MESSAGE_COLORS[liveMessageType]}`}
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
                  onClick={onBack}
                  className="btn-raised shrink-0 px-5 rounded-lg font-sans text-[15px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97]"
                >
                  Canlı Listesi
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

      {meaning && <MeaningModal entries={meaning.entries} onClose={() => setMeaning(null)} />}
      {showTiles && <RemainingTilesModal state={tilesState} onClose={() => setShowTiles(false)} />}
      {showHistory && <MoveHistoryModal state={historyState} onClose={() => setShowHistory(false)} />}

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
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative">
            <button
              onClick={() => closeMessagePopup()}
              aria-label="Kapat"
              className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
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
    </div>
  );
}
