// Harfik — oyun kurulum ekranı: oyuncu sayısı (2/4) ve isimler
import { useState } from 'react';
import { PLAYER_COLORS, cornersFor } from '../game/constants';

interface SetupProps {
  onStart: (names: string[]) => void;
}

const CORNER_LABEL = ['Sol üst', 'Sağ üst', 'Sol alt', 'Sağ alt'];

export function Setup({ onStart }: SetupProps) {
  const [count, setCount] = useState<2 | 4>(2);
  const [names, setNames] = useState<string[]>(['', '', '', '']);

  const corners = cornersFor(count);

  const setName = (i: number, v: string) =>
    setNames((cur) => cur.map((n, idx) => (idx === i ? v : n)));

  const handleStart = () => {
    const list = Array.from({ length: count }, (_, i) =>
      names[i].trim() ? names[i].trim() : `Oyuncu ${i + 1}`,
    );
    onStart(list);
  };

  return (
    <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
      <div className="text-center">
        <div className="font-mono text-2xl font-bold text-accent tracking-[3px]">
          HARFİK
        </div>
        <p className="text-muted text-xs font-mono mt-1">
          Her oyuncu kendi köşesinden başlar. 5×5 köşenden çıkmadan
          diğerlerine ulaşamazsın.
        </p>
      </div>

      <div className="flex flex-col gap-2">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Oyuncu sayısı
        </div>
        <div className="flex gap-2">
          {([2, 4] as const).map((n) => (
            <button
              key={n}
              onClick={() => setCount(n)}
              className={[
                'flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97]',
                count === n
                  ? 'bg-accent text-white border-accent'
                  : 'bg-panel text-text border-border',
              ].join(' ')}
            >
              {n} Kişi
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-2.5">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Oyuncular
        </div>
        {Array.from({ length: count }, (_, i) => {
          const col = PLAYER_COLORS[i];
          return (
            <div
              key={i}
              className="flex items-center gap-2.5 rounded-md px-2.5 py-2 border"
              style={{ background: col.zone, borderColor: `${col.base}55` }}
            >
              <span
                className="w-4 h-4 rounded-sm shrink-0"
                style={{ background: col.base }}
              />
              <input
                value={names[i]}
                onChange={(e) => setName(i, e.target.value)}
                placeholder={`Oyuncu ${i + 1}`}
                maxLength={14}
                className="flex-1 bg-transparent outline-none font-sans text-sm text-text placeholder:text-muted"
              />
              <span
                className="text-[9px] uppercase tracking-[1px] font-mono shrink-0"
                style={{ color: col.base }}
              >
                {CORNER_LABEL[corners[i]]}
              </span>
            </div>
          );
        })}
      </div>

      <button
        onClick={handleStart}
        className="py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform"
      >
        Oyunu Başlat
      </button>
    </div>
  );
}
