// Harfik — skor, sıra ve torba göstergesi
interface GameHeaderProps {
  playerScore: number;
  aiScore: number;
  bagCount: number;
}

export function GameHeader({ playerScore, aiScore, bagCount }: GameHeaderProps) {
  return (
    <header className="w-full max-w-[460px] flex items-center justify-between px-3.5 py-2.5 border-b border-border">
      <div className="font-mono text-lg font-bold text-accent tracking-[2px]">
        HAR<span className="text-ai">FİK</span>
      </div>
      <div className="flex gap-3.5 items-center">
        <div className="text-center">
          <div className="text-[8px] uppercase tracking-[1.5px] text-muted font-mono">
            Sen
          </div>
          <div className="font-mono text-xl font-bold leading-none text-player">
            {playerScore}
          </div>
        </div>
        <div className="w-px h-8 bg-border" />
        <div className="text-center">
          <div className="text-[8px] uppercase tracking-[1.5px] text-muted font-mono">
            YZ
          </div>
          <div className="font-mono text-xl font-bold leading-none text-ai">
            {aiScore}
          </div>
        </div>
        <div className="w-px h-8 bg-border" />
        <div className="text-center">
          <div className="text-[8px] uppercase tracking-[1.5px] text-muted font-mono">
            Torba
          </div>
          <div className="font-mono text-base font-bold leading-none text-muted">
            {bagCount}
          </div>
        </div>
      </div>
    </header>
  );
}
