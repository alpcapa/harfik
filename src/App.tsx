// Harfik — ana uygulama: kurulum, çok oyunculu sıra akışı ve düzen
import { useEffect, useReducer, useState } from 'react';
import { GameHeader } from './components/GameHeader';
import { Board } from './components/Board';
import { Rack } from './components/Rack';
import { GameOver } from './components/GameOver';
import { AccountBar } from './components/AccountBar';
import { Setup } from './components/Setup';
import { Leaderboard } from './components/Leaderboard';
import { MeaningModal } from './components/MeaningModal';
import { createInitialState, gameReducer } from './game/gameReducer';
import { calcScore } from './utils/validator';
import { key } from './utils/board';
import { PLAYER_COLORS } from './game/constants';
import { useAuth } from './hooks/useAuth';
import { fetchMeaning } from './lib/api';
import type { WordMeaning } from './lib/database.types';

const AI_THINK_MS = 1100;

const MESSAGE_COLORS: Record<string, string> = {
  ok: 'text-green',
  err: 'text-red',
  warn: 'text-gold',
  '': 'text-muted',
};

const LEGEND = [
  { label: '2×K', bg: '#E4F6EA', border: '1px solid #16A34A' },
  { label: '3×K', bg: '#FCEBDC', border: '1px solid #D97706' },
  { label: '2×H', bg: '#E1ECFD', border: '1px solid #2563EB' },
  { label: '3×H', bg: '#F0E6FB', border: '1px solid #7C3AED' },
];

export default function App() {
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);
  const { configured } = useAuth();
  const [showLeaderboard, setShowLeaderboard] = useState(false);

  // Oynanan bir kelimeye tıklanınca gösterilen anlam penceresi.
  const [meaning, setMeaning] = useState<{
    word: string;
    data: WordMeaning | null;
    loading: boolean;
  } | null>(null);

  const openMeaning = (word: string) => {
    setMeaning({ word, data: null, loading: true });
    void fetchMeaning(word).then((data) => {
      setMeaning((cur) =>
        cur && cur.word === word ? { word, data, loading: false } : cur,
      );
    });
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
      <div className="min-h-screen w-full flex flex-col items-center overflow-x-hidden">
        <Setup onStart={(players) => dispatch({ type: 'START', players })} />
        <AccountBar />
      </div>
    );
  }

  // ── Oyun ekranı ──────────────────────────────────────────────────────────────
  const me = state.players[state.current];
  const myColor = PLAYER_COLORS[me.colorIndex];

  const handleCellClick = (r: number, c: number) => {
    const k = key(r, c);
    // Son oynanan kelimenin harfine tıklanırsa anlamını göster.
    const lw = state.lastWords[k];
    if (lw) {
      openMeaning(lw.word);
      return;
    }
    if (state.isGameOver || me.isAI) return;
    if (state.placed[k]) {
      dispatch({ type: 'RECALL_CELL', r, c });
      return;
    }
    if (state.board[r][c]) return;

    let wildLetter: string | undefined;
    const sel = state.selectedTile !== null ? me.rack[state.selectedTile] : null;
    if (sel && sel.letter === '?') {
      const l = window.prompt('Joker hangi harf olsun? (Türkçe)');
      wildLetter = (l || 'A').toUpperCase();
    }
    dispatch({ type: 'PLACE_TILE', r, c, wildLetter });
  };

  const canAct = !state.isGameOver && !me.isAI;

  const placedCount = Object.keys(state.placed).length;
  const potentialScore =
    placedCount > 0 ? calcScore(state.board, state.placed, state.bonuses) : 0;

  return (
    <div className="min-h-screen w-full flex flex-col items-center overflow-x-hidden">
      <GameHeader
        players={state.players}
        current={state.current}
        bagCount={state.bag.length}
        showLeaderboard={configured}
        onLeaderboard={() => setShowLeaderboard(true)}
      />

      <div className="w-full max-w-[460px] flex items-center justify-center px-3.5 py-1.5 text-[10px] font-mono tracking-[1px] uppercase">
        <span className="font-bold" style={{ color: myColor.base }}>
          Sıra: {me.name}
          {me.isAI && ' (düşünüyor…)'}
        </span>
      </div>

      <Board state={state} onCellClick={handleCellClick} />

      <div className="w-full max-w-[460px] px-2 pb-3 flex flex-col gap-2">
        <div
          className={`text-[11px] font-mono text-center min-h-[15px] py-0.5 ${
            MESSAGE_COLORS[state.messageType]
          }`}
        >
          {state.message}
        </div>

        {placedCount > 0 && (
          <div className="text-center font-mono text-[12px] text-gold tracking-[0.5px]">
            Potansiyel puan: <span className="font-bold">+{potentialScore}</span>
          </div>
        )}

        <Rack
          tiles={me.rack}
          selectedTile={state.selectedTile}
          onSelect={(i) => !me.isAI && dispatch({ type: 'SELECT_TILE', index: i })}
          title={me.isAI ? `${me.name} (YZ)` : me.name}
          color={myColor}
        />

        <div className="flex gap-2 justify-center flex-wrap py-1">
          {LEGEND.map((item) => (
            <div
              key={item.label}
              className="text-[8px] font-mono flex items-center gap-[3px] text-muted"
            >
              <span
                className="w-2 h-2 rounded-[1px]"
                style={{ background: item.bg, border: item.border }}
              />
              {item.label}
            </div>
          ))}
        </div>

        <div className="flex gap-1.5">
          <button
            disabled={!canAct}
            onClick={() => dispatch({ type: 'PLAY' })}
            className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
          >
            Oyna
          </button>
          <button
            disabled={!canAct}
            onClick={() => dispatch({ type: 'RECALL_ALL' })}
            className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-text border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
          >
            Geri Al
          </button>
          <button
            disabled={!canAct}
            onClick={() => dispatch({ type: 'PASS' })}
            className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-panel text-muted border border-border active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
          >
            Pas
          </button>
        </div>
      </div>

      {meaning && (
        <MeaningModal
          word={meaning.word}
          data={meaning.data}
          loading={meaning.loading}
          onClose={() => setMeaning(null)}
        />
      )}

      {showLeaderboard && <Leaderboard onClose={() => setShowLeaderboard(false)} />}

      <GameOver
        show={state.isGameOver}
        players={state.players}
        turnCount={state.turnCount}
        onRestart={() => dispatch({ type: 'INIT' })}
      />
    </div>
  );
}
