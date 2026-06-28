// Harfik — ana uygulama: durum, sıra akışı ve düzen
import { useEffect, useReducer, useRef } from 'react';
import { GameHeader } from './components/GameHeader';
import { Board } from './components/Board';
import { Rack } from './components/Rack';
import { GameOver } from './components/GameOver';
import { AccountBar } from './components/AccountBar';
import { createInitialState, gameReducer } from './game/gameReducer';
import { key } from './utils/board';
import { useAuth } from './hooks/useAuth';
import { saveGame } from './lib/api';

const AI_THINK_MS = 1400;
const TOAST_MS = 2000;

const MESSAGE_COLORS: Record<string, string> = {
  ok: 'text-green',
  err: 'text-red',
  warn: 'text-gold',
  '': 'text-muted',
};

const LEGEND = [
  { label: '2×K', bg: '#1A3A1A', border: '1px solid #40C840' },
  { label: '3×K', bg: '#3A1A00', border: '1px solid #FF8000' },
  { label: '2×H', bg: '#001A3A', border: '1px solid #40A0FF' },
  { label: '3×H', bg: '#1A0030', border: '1px solid #C040FF' },
  { label: 'Çatlıyor', bg: '#1A1000', border: '1px dashed #5A3A00' },
  { label: 'Boşluk', bg: '#050708', border: '1px solid #111' },
];

export default function App() {
  const [state, dispatch] = useReducer(gameReducer, undefined, createInitialState);
  const { user } = useAuth();
  const savedRef = useRef(false);

  // Oyun bitince (oturum açıksa) sonucu bir kez kaydet.
  useEffect(() => {
    if (!state.isGameOver) {
      savedRef.current = false;
      return;
    }
    if (savedRef.current || !user) return;
    savedRef.current = true;
    const result =
      state.playerScore > state.aiScore
        ? 'win'
        : state.playerScore < state.aiScore
          ? 'lose'
          : 'tie';
    void saveGame({
      player_score: state.playerScore,
      ai_score: state.aiScore,
      result,
      turn_count: state.turnCount,
      best_word: state.bestWord || null,
    });
  }, [state.isGameOver, user, state.playerScore, state.aiScore, state.turnCount, state.bestWord]);

  // YZ sırası: kısa bir düşünme gecikmesiyle hamle yap.
  useEffect(() => {
    if (!state.playerTurn && !state.isGameOver) {
      const t = setTimeout(() => dispatch({ type: 'AI_PLAY' }), AI_THINK_MS);
      return () => clearTimeout(t);
    }
  }, [state.playerTurn, state.isGameOver]);

  // Evrim bildirimi otomatik kapansın.
  useEffect(() => {
    if (state.evolveToast) {
      const t = setTimeout(() => dispatch({ type: 'DISMISS_TOAST' }), TOAST_MS);
      return () => clearTimeout(t);
    }
  }, [state.evolveToast]);

  const handleCellClick = (r: number, c: number) => {
    if (!state.playerTurn || state.isGameOver) return;
    const k = key(r, c);
    if (state.placed[k]) {
      dispatch({ type: 'RECALL_CELL', r, c });
      return;
    }
    if (state.board[r][c]) return;

    let wildLetter: string | undefined;
    const sel =
      state.selectedTile !== null ? state.playerRack[state.selectedTile] : null;
    if (sel && sel.letter === '?') {
      const l = window.prompt('Joker hangi harf olsun? (Türkçe)');
      wildLetter = (l || 'A').toUpperCase();
    }
    dispatch({ type: 'PLACE_TILE', r, c, wildLetter });
  };

  const canAct = state.playerTurn && !state.isGameOver;

  const evolveColor =
    state.turnsUntilEvolve <= 1
      ? 'text-red'
      : state.turnsUntilEvolve <= 2
        ? 'text-gold'
        : 'text-muted';

  return (
    <div className="min-h-screen w-full flex flex-col items-center overflow-x-hidden">
      <GameHeader
        playerScore={state.playerScore}
        aiScore={state.aiScore}
        bagCount={state.bag.length}
      />

      <AccountBar />

      <div className="w-full max-w-[460px] flex items-center justify-between px-3.5 py-1.5 text-[10px] font-mono tracking-[1px] uppercase">
        <span className={state.playerTurn ? 'text-accent font-bold' : 'text-muted'}>
          {state.turnLabel}
        </span>
        <span className={`${evolveColor}`}>
          Tahta {state.turnsUntilEvolve} hamlede değişir
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

        <Rack
          tiles={state.playerRack}
          selectedTile={state.selectedTile}
          onSelect={(i) => dispatch({ type: 'SELECT_TILE', index: i })}
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
            className="flex-1 py-2.5 px-1.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1.2px] bg-accent text-[#060A0D] active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
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

      {state.evolveToast && (
        <div className="fixed top-[60px] left-1/2 -translate-x-1/2 z-[200] bg-gold text-[#060A0D] font-mono text-[11px] font-bold tracking-[1px] px-[18px] py-2 rounded-full uppercase pointer-events-none">
          ⚡ Tahta Değişiyor!
        </div>
      )}

      <GameOver
        show={state.isGameOver}
        playerScore={state.playerScore}
        aiScore={state.aiScore}
        turnCount={state.turnCount}
        onRestart={() => dispatch({ type: 'INIT' })}
      />
    </div>
  );
}
