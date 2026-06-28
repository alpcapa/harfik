// Harfik — ana uygulama: kurulum, çok oyunculu sıra akışı ve düzen
import { useEffect, useReducer, useState } from 'react';
import { GameHeader } from './components/GameHeader';
import { Board } from './components/Board';
import { Rack } from './components/Rack';
import { GameOver } from './components/GameOver';
import { UserMenu } from './components/UserMenu';
import { Setup } from './components/Setup';
import { MeaningModal } from './components/MeaningModal';
import { createInitialState, gameReducer } from './game/gameReducer';
import { calcScore } from './utils/validator';
import { key } from './utils/board';
import { trUpper } from './utils/turkish';
import { PLAYER_COLORS } from './game/constants';
import { fetchMeaning } from './lib/api';
import type { WordMeaning } from './lib/database.types';

const AI_THINK_MS = 1100;

const MESSAGE_COLORS: Record<string, string> = {
  ok: 'text-green',
  err: 'text-red',
  warn: 'text-gold',
  '': 'text-muted',
};

export default function App() {
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);

  // Oynanan kelime(ler)e tıklanınca gösterilen anlam penceresi. Bir hamlede
  // birden fazla kelime oluştuysa hepsi listelenir.
  const [meaning, setMeaning] = useState<{
    entries: { word: string; data: WordMeaning | null; loading: boolean }[];
  } | null>(null);

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

  // YZ sırası: kısa bir düşünme gecikmesiyle otomatik oyna.
  const aiTurn =
    state.phase === 'play' &&
    !state.isGameOver &&
    !!state.players[state.current]?.isAI;
  useEffect(() => {
    if (!aiTurn) return;
    const t = setTimeout(() => dispatch({ type: 'AI_PLAY' }), AI_THINK_MS);
    return () => clearTimeout(t);
  }, [aiTurn, state.current, state.turnCount]);

  // ── Kurulum ekranı ─────────────────────────────────────────────────────────
  if (state.phase === 'setup') {
    return (
      <div className="min-h-[100dvh] w-full flex flex-col items-center overflow-x-hidden">
        <div className="w-full max-w-[460px] flex items-center justify-end px-3.5 pt-3">
          <UserMenu />
        </div>
        <Setup onStart={(players) => dispatch({ type: 'START', players })} />
      </div>
    );
  }

  // ── Oyun ekranı ──────────────────────────────────────────────────────────────
  const me = state.players[state.current];
  const myColor = PLAYER_COLORS[me.colorIndex];

  const handleCellClick = (r: number, c: number) => {
    const k = key(r, c);
    // Son oynanan kelimenin harfine tıklanırsa anlamını göster. Aynı hamlede
    // oluşan tüm kelimeleri (tıklanan önce gelir) listele.
    const lw = state.lastWords[k];
    if (lw) {
      const words = [
        lw.word,
        ...Object.values(state.lastWords)
          .filter((w) => w.by === lw.by)
          .map((w) => w.word),
      ];
      openMeaning(words);
      return;
    }
    if (state.isGameOver || me.isAI || state.swapMode) return;
    if (state.placed[k]) {
      dispatch({ type: 'RECALL_CELL', r, c });
      return;
    }
    if (state.board[r][c]) return;

    let wildLetter: string | undefined;
    const sel = state.selectedTile !== null ? me.rack[state.selectedTile] : null;
    if (sel && sel.letter === '?') {
      const l = window.prompt('Joker hangi harf olsun? (Türkçe)');
      wildLetter = trUpper(l || 'A');
    }
    dispatch({ type: 'PLACE_TILE', r, c, wildLetter });
  };

  const canAct = !state.isGameOver && !me.isAI;

  // Pas, sırayı tümüyle harcadığı için onay ister.
  const handlePass = () => {
    const placed = Object.keys(state.placed).length > 0;
    const msg = placed
      ? 'Pas geçilsin mi? Tahtaya koyduğun taşlar rafa geri alınır ve sıran geçer.'
      : 'Pas geçmek istediğine emin misin? Sıran karşı tarafa geçer.';
    if (window.confirm(msg)) dispatch({ type: 'PASS' });
  };

  const placedCount = Object.keys(state.placed).length;
  const potentialScore =
    placedCount > 0 ? calcScore(state.board, state.placed, state.bonuses) : 0;

  return (
    <div className="h-[100dvh] w-full flex flex-col items-center overflow-hidden">
      <GameHeader state={state} />

      <div className="flex-1 min-h-0 w-full flex items-center justify-center">
        <Board
          state={state}
          onCellClick={handleCellClick}
          potentialScore={placedCount > 0 ? potentialScore : null}
        />
      </div>

      <div className="w-full max-w-[680px] px-3 pb-3 pt-1 flex flex-col gap-1.5 shrink-0">
        <div
          className={`text-[11px] font-mono text-center min-h-[15px] py-0.5 ${
            MESSAGE_COLORS[state.messageType]
          }`}
        >
          {state.message}
        </div>

        <div className="flex gap-1.5 items-stretch">
          <div className="flex-1 min-w-0">
            <Rack
              tiles={me.rack}
              selectedTile={state.selectedTile}
              onSelect={(i) => {
                if (me.isAI) return;
                if (state.swapMode) dispatch({ type: 'TOGGLE_SWAP_TILE', index: i });
                else dispatch({ type: 'SELECT_TILE', index: i });
              }}
              title={me.name}
              color={myColor}
              swapMode={state.swapMode}
              swapSelection={state.swapSelection}
            />
          </div>
          {!state.swapMode && (
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'PLAY' })}
              className="shrink-0 px-5 rounded-lg font-sans text-[12px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Oyna
            </button>
          )}
        </div>

        {state.swapMode ? (
          <div className="flex gap-1.5">
            <button
              disabled={!canAct || state.swapSelection.length === 0}
              onClick={() => dispatch({ type: 'CONFIRM_SWAP' })}
              className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-gold text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Değiştir{state.swapSelection.length > 0 ? ` (${state.swapSelection.length})` : ''}
            </button>
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'TOGGLE_SWAP_MODE' })}
              className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-muted border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Vazgeç
            </button>
          </div>
        ) : (
          <div className="flex gap-1.5">
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'RECALL_ALL' })}
              className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Geri Al
            </button>
            <button
              disabled={!canAct}
              onClick={handlePass}
              className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-muted border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Pas
            </button>
            <button
              disabled={!canAct}
              onClick={() => dispatch({ type: 'SHUFFLE_RACK' })}
              className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Karıştır
            </button>
            <button
              disabled={!canAct || state.bag.length === 0}
              onClick={() => dispatch({ type: 'TOGGLE_SWAP_MODE' })}
              className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              Değiştir
            </button>
          </div>
        )}
      </div>

      {meaning && (
        <MeaningModal entries={meaning.entries} onClose={() => setMeaning(null)} />
      )}

      <GameOver
        show={state.isGameOver}
        players={state.players}
        turnCount={state.turnCount}
        onRestart={() => dispatch({ type: 'INIT' })}
      />
    </div>
  );
}
