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
// Bilinçli kapsam dışı bırakma (CLAUDE.md'de belgelendi): Teslim olma
// (surrender) henüz yok — üstteki logo yalnızca Canlı listesine döner,
// oyunu bitirmez.
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
import { Tile as TileComponent } from './Tile';
import { createInitialState, gameReducer, isFirstMove } from '../game/gameReducer';
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
import {
  fetchMeaning,
  fetchOnlineGameMoves,
  fetchOnlineGameState,
  getMyOnlineRack,
  isSupabaseConfigured,
  isValidWordRemote,
  submitMove,
  subscribeOnlineGameState,
} from '../lib/api';
import type { HistoryEntry, Tile as TileModel } from '../game/types';
import type { OnlineGame, OnlineMoveRow, WordMeaning } from '../lib/database.types';

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
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);
  const [moveRows, setMoveRows] = useState<OnlineMoveRow[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [validating, setValidating] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [showTiles, setShowTiles] = useState(false);
  const [showFeedback, setShowFeedback] = useState(false);
  const [gameOverDismissed, setGameOverDismissed] = useState(false);
  const [showPassConfirm, setShowPassConfirm] = useState(false);
  const [pendingWild, setPendingWild] = useState<{ r: number; c: number; rackIndex?: number } | null>(null);
  const [invasionConfirm, setInvasionConfirm] = useState<{
    list: { ownerName: string; ownerPts: number }[];
    score: number;
    onConfirm: () => void;
  } | null>(null);
  const [meaning, setMeaning] = useState<{ entries: { word: string; data: WordMeaning | null; loading: boolean }[] } | null>(
    null,
  );

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

  const mySlotIndex = useMemo(
    () => game.slots.findIndex((s) => s.type === 'human' && s.user_id === myUserId),
    [game.slots, myUserId],
  );

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
    };
    void refresh();
    const unsubscribe = subscribeOnlineGameState(game.id, () => {
      void refresh();
    });
    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [game.id, mySlotIndex]);

  const wordsReady = isWordSetReady();
  const me = state.players[mySlotIndex];
  const canAct = loaded && !state.isGameOver && state.current === mySlotIndex && !!me;

  // Raftan bir taş ya da tahtaya bu tur konmuş bir taş sürüklenmeye başlanır.
  const beginDrag = (source: DragSource, e: React.PointerEvent) => {
    if (!canAct || state.swapMode) return;
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
    if (!canAct || state.swapMode) return;
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
    const result = validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
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

  return (
    <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
      <GameHeader state={state} onLogoClick={onBack} />

      <main className="w-full flex flex-col items-center">
        <Board
          state={state}
          onCellClick={handleCellClick}
          moveStatus={moveStatus}
          onOpenHistory={() => setShowHistory(true)}
          dragHiddenKey={dragHiddenKey}
          dragOverKey={ghost?.overKey ?? null}
          dragOverValid={ghost?.overValid ?? false}
          onTilePointerDown={(r, c, e) => beginDrag({ kind: 'placed', r, c, tile: state.placed[key(r, c)] }, e)}
          onTilePointerMove={moveDrag}
          onTilePointerUp={endDrag}
          onTilePointerCancel={cancelDrag}
        />

        <div className="w-full max-w-[680px] px-3 pb-3 pt-1 flex flex-col gap-1.5">
          {!canAct && !state.isGameOver ? (
            <div className="shadow-raised flex items-center justify-center rounded-md border border-red/40 bg-red/10 px-4 py-3">
              <span className="font-mono text-[11px] font-bold uppercase tracking-[1px] text-red">
                Sıra: {state.players[state.current]?.name ?? 'Rakip'} — oynaması bekleniyor
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
                  if (!canAct) return;
                  if (state.swapMode) dispatch({ type: 'TOGGLE_SWAP_TILE', index: i });
                  else dispatch({ type: 'SELECT_TILE', index: i });
                }}
                title={me.name}
                color={PLAYER_COLORS[me.colorIndex]}
                draggable={canAct}
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
