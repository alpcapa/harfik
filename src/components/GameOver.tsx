// Harfik — oyun sonu ekranı
interface GameOverProps {
  show: boolean;
  playerScore: number;
  aiScore: number;
  turnCount: number;
  onRestart: () => void;
}

export function GameOver({
  show,
  playerScore,
  aiScore,
  turnCount,
  onRestart,
}: GameOverProps) {
  if (!show) return null;

  const result =
    playerScore > aiScore ? 'win' : playerScore < aiScore ? 'lose' : 'tie';
  const title =
    result === 'win' ? 'KAZANDIN' : result === 'lose' ? 'YZ KAZANDI' : 'BERABERE';
  const titleColor =
    result === 'win'
      ? 'text-player'
      : result === 'lose'
        ? 'text-ai'
        : 'text-gold';

  return (
    <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-[18px] p-6 bg-[rgba(6,10,13,0.93)]">
      <div
        className={`font-mono text-[32px] font-bold tracking-[3px] text-center ${titleColor}`}
      >
        {title}
      </div>
      <div className="bg-panel border border-border rounded-[10px] px-9 py-5 text-center flex flex-col gap-2.5 min-w-[220px]">
        <div className="flex justify-between gap-8 text-[15px]">
          <span>Senin puanın</span>
          <span className="font-mono text-[22px] font-bold text-player">
            {playerScore}
          </span>
        </div>
        <div className="flex justify-between gap-8 text-[15px]">
          <span>YZ puanı</span>
          <span className="font-mono text-[22px] font-bold text-ai">
            {aiScore}
          </span>
        </div>
        <div className="flex justify-between gap-8 text-[15px]">
          <span>Toplam hamle</span>
          <span className="font-mono text-[22px] font-bold text-muted">
            {turnCount}
          </span>
        </div>
      </div>
      <button
        onClick={onRestart}
        className="bg-accent text-[#060A0D] rounded-lg px-9 py-3.5 text-[13px] font-bold tracking-[2px] uppercase font-sans active:scale-95 transition-transform"
      >
        Tekrar Oyna
      </button>
    </div>
  );
}
