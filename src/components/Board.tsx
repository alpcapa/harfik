// Kelimeki — 13x13 oyun tahtası (çok oyunculu, renkli bölgeler)
import { useMemo } from 'react';
import {
  BONUS_LABELS,
  BONUS_ZONE,
  CORNER,
  PLAYER_COLORS,
  SIZE,
  cornerCell,
  inBonusZone,
  type PlayerColor,
} from '../game/constants';
import type { GameState, MoveStatus } from '../game/types';
import { key } from '../utils/board';
import { buildRoundedOutlinePath } from '../utils/outline';
import { computeAllTerritories } from '../utils/validator';
import { useOnlineStatus } from '../hooks/useOnlineStatus';
import { Tile } from './Tile';

// Dış hat köşe yarıçapı (ızgara birimi) — köşe bloğundaki dışbükey köşelerle
// aynı hissi versin diye, ama artık içbükey (genişleyen kolların dönüşleri)
// köşeler de aynı yarıçapla yuvarlanıyor.
const OUTLINE_RADIUS = 0.16;
const OUTLINE_STROKE = 2.5;

interface BoardProps {
  state: GameState;
  onCellClick: (r: number, c: number) => void;
  /** Oyna'ya basmadan önceki anlık geçerlilik/puan çerçevesi; taş yoksa null. */
  moveStatus: MoveStatus | null;
  /** "Oyun Geçmişi" linkine tıklanınca çağrılır. */
  onOpenHistory: () => void;
  /** Şu an sürüklenmekte olan, bu tur yerleştirilmiş taşın hücre anahtarı — o hücre boşmuş gibi çizilir. */
  dragHiddenKey?: string | null;
  /** Sürükleme sırasında işaretçinin üzerinde olduğu hücre (bırakma hedefi vurgusu). */
  dragOverKey?: string | null;
  /** `dragOverKey` hücresine bırakmak geçerli mi? */
  dragOverValid?: boolean;
  /** Bu tur yerleştirilmiş bir taşın sürüklenmesini başlatır. */
  onTilePointerDown?: (r: number, c: number, e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerMove?: (e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerUp?: (e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerCancel?: (e: React.PointerEvent<HTMLDivElement>) => void;
  /** Alt bilgi şeridini (Oyun Geçmişi linki + X2/X3 açıklaması) gizler — salt-okunur önizlemelerde (bkz. `GameBoardPreview`). */
  hideFooter?: boolean;
}

// Merkezdeki x2 bonus bölgesi altın rengi — nömorfik, diğer köşe tonlarıyla
// karışmasın diye sıcak/altın. Tam ortadaki tek X3 hücresi turuncu bir zeminle
// öne çıkar.
const GOLD_ZONE_STYLE: React.CSSProperties = {
  background: 'linear-gradient(135deg, #FDE68A, #FBBF24)',
  boxShadow: 'inset 2px 2px 5px rgba(180,130,10,0.3), inset -1px -1px 3px rgba(255,255,255,0.7), 0 2px 4px rgba(180,130,10,0.2)',
};
const CENTER_ZONE_STYLE: React.CSSProperties = {
  background: 'linear-gradient(135deg, #FDBA74, #F97316)',
  boxShadow: 'inset 2px 2px 5px rgba(180,80,10,0.35), inset -1px -1px 3px rgba(255,255,255,0.7), 0 2px 4px rgba(180,80,10,0.25)',
};
const CENTER_TEXT = 'text-[#7C2D12]';

// Tahtanın hemen altında gösterilen bonus açıklaması.
const LEGEND = [
  { label: 'X2', desc: '- kelime X2', bg: 'linear-gradient(135deg, #FDE68A, #FBBF24)', border: 'none' },
  { label: 'X3', desc: '- kelime X3', bg: 'linear-gradient(135deg, #FDBA74, #F97316)', border: 'none' },
];

/** Bir oyuncunun ilk hamlesinde mutlaka değmesi gereken köşe hücresindeki ev işareti. */
function HomeMark({ color }: { color: PlayerColor }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="w-[55%] h-[55%]"
      style={{ opacity: 0.85 }}
      fill={color.base}
    >
      <path d="M12 2.5 1.5 11h3V21h6v-6h3v6h6V11h3L12 2.5Z" />
    </svg>
  );
}

export function Board({
  state,
  onCellClick,
  moveStatus,
  onOpenHistory,
  dragHiddenKey = null,
  dragOverKey = null,
  dragOverValid = false,
  onTilePointerDown,
  onTilePointerMove,
  onTilePointerUp,
  onTilePointerCancel,
  hideFooter = false,
}: BoardProps) {
  const online = useOnlineStatus();
  const { board, placed, bonuses, players, current } = state;

  // Köşe bölgesi -> o köşenin sahibinin rengi (boş kareleri renklendirmek için).
  const cornerColor: (PlayerColor | undefined)[] = [
    undefined,
    undefined,
    undefined,
    undefined,
  ];
  for (const p of players) {
    for (const corner of p.corners) cornerColor[corner] = PLAYER_COLORS[p.colorIndex];
  }

  // Köşe bölgesi -> o köşedeki oyuncunun numarası (1, 2, …) — soluk filigran.
  const cornerNumber: (number | undefined)[] = [
    undefined,
    undefined,
    undefined,
    undefined,
  ];
  players.forEach((p, i) => {
    for (const corner of p.corners) cornerNumber[corner] = i + 1;
  });

  // Köşe bölgesinin tahtaya oranı (kenar uzunluğu).
  const cornerFrac = `${(CORNER / SIZE) * 100}%`;

  // Merkezdeki x2 bonus bölgesinin tahtaya oranı ve konumu — köşe numarası
  // filigranıyla aynı mantıkla, tek büyük bir "X2" o bölgenin arkasına yazılır.
  const zoneSize = BONUS_ZONE.r1 - BONUS_ZONE.r0 + 1;
  const zoneFrac = `${(zoneSize / SIZE) * 100}%`;
  const zoneTop = `${(BONUS_ZONE.r0 / SIZE) * 100}%`;
  const zoneLeft = `${(BONUS_ZONE.c0 / SIZE) * 100}%`;

  // Köşenin tam ucundaki tek başlangıç hücresi -> o köşenin sahibinin rengi.
  // İlk hamle bu hücreye değmek zorunda olduğundan burada bir "ev" işareti
  // gösterilir.
  const homeCellColor = new Map<string, PlayerColor>();
  players.forEach((p) => {
    for (const corner of p.corners) {
      const [hr, hc] = cornerCell(corner);
      homeCellColor.set(key(hr, hc), PLAYER_COLORS[p.colorIndex]);
    }
  });

  const colorOf = (owner: number | undefined): PlayerColor | undefined =>
    owner === undefined ? undefined : PLAYER_COLORS[players[owner]?.colorIndex ?? 0];

  // En son oynanan hamlenin taşlarını, bir çerçeve yerine hafifçe koyulaştırılmış
  // tonuyla ayırt eder — çerçeve, bölge genişledikçe bölge dış hattıyla çakışıp
  // kafa karıştırıcı kalıntılar bırakıyordu.
  const darken = (hex: string, amount: number): string => {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.round(((num >> 16) & 255) * (1 - amount));
    const g = Math.round(((num >> 8) & 255) * (1 - amount));
    const b = Math.round((num & 255) * (1 - amount));
    return `#${[r, g, b].map((v) => Math.max(0, Math.min(255, v)).toString(16).padStart(2, '0')).join('')}`;
  };

  const currentColor = PLAYER_COLORS[players[current]?.colorIndex ?? 0];

  // En son oynanan hamlenin hücreleri — taş rengi koyulaştırılarak vurgulanır.
  const lastMoveSet = new Set(state.lastMoveCells.map(([r, c]) => key(r, c)));

  // Her oyuncunun bölgesi: kendi köşesi + oradan kendi taşlarıyla genişleyen
  // alan. Sabit 4×4 köşenin aksine hamle oynandıkça büyür. `board`/`players`
  // yalnızca bir hamle oynanınca değiştiğinden `useMemo` ile önbelleklenir —
  // aksi halde bir taş sürüklenirken (her `pointermove`'da `Board` yeniden
  // render olur, ama `board`/`players` aynı kalır) bu flood-fill her seferinde
  // gereksiz yere tekrarlanıyordu.
  const territories = useMemo(
    () => computeAllTerritories(board, players),
    [board, players],
  );
  const territoryOwnerAt = (r: number, c: number): number => {
    const k = key(r, c);
    for (let i = 0; i < territories.length; i++) {
      if (territories[i].has(k)) return i;
    }
    return -1;
  };

  const cells = [];

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const k = key(r, c);
      const boardTile = board[r][c];
      const rawPlacedTile = placed[k];
      // Sürüklenmekte olan taş, alındığı hücrede boşmuş gibi çizilir (görsel olarak).
      const placedTile = k === dragHiddenKey ? undefined : rawPlacedTile;
      const bonus = bonuses[k];
      const inZone = inBonusZone(r, c);
      const territoryOwner = territoryOwnerAt(r, c);
      const zone = territoryOwner >= 0 ? PLAYER_COLORS[players[territoryOwner]?.colorIndex ?? 0] : undefined;
      const homeColor = homeCellColor.get(k);

      let content: React.ReactNode = null;
      let style: React.CSSProperties | undefined;
      const classes = [
        'min-w-0 min-h-0 rounded-[5px] flex items-center justify-center',
        'font-mono font-bold text-[clamp(5px,1.4vw,8px)] select-none',
        'transition-[background,box-shadow,opacity] duration-300',
      ];

      if (boardTile) {
        // Tahtadaki her taş tıklanabilir — hangi hamlede oynandığına
        // bakılmaksızın o hücreden geçen kelime(ler)in anlamı gösterilir.
        // `relative z-[5]`: köşe/bonus filigranları (z-index:auto) taşın
        // ÜZERİNDE boyanmasın diye — taş her zaman kendi solid renginde görünmeli.
        classes.push('relative z-[5] bg-transparent cursor-pointer');
        const tileColor = colorOf(boardTile.owner);
        const isLastMove = lastMoveSet.has(k);
        content = (
          <Tile
            tile={boardTile}
            variant="board"
            color={
              isLastMove && tileColor
                ? { ...tileColor, tint: darken(tileColor.tint, 0.14), base: darken(tileColor.base, 0.12) }
                : tileColor
            }
          />
        );
      } else if (placedTile) {
        classes.push('relative z-[5] bg-transparent');
        content = <Tile tile={placedTile} variant="placed" color={currentColor} />;
      } else if (inZone) {
        // Merkezdeki x2 bonus bölgesi — altın zemin, büyük "X2" filigranı
        // bölgenin tamamının arkasına yazılır (aşağıda). Tam ortadaki tek
        // hücre bunun dışında, turuncu zemin + kendi X3 etiketiyle öne çıkar.
        classes.push('cursor-pointer');
        style = bonus ? { ...CENTER_ZONE_STYLE } : { ...GOLD_ZONE_STYLE };
        if (bonus) {
          classes.push(CENTER_TEXT, 'text-[clamp(7px,1.9vw,12px)]');
          content = BONUS_LABELS[bonus];
        }
      } else if (zone) {
        // Bir oyuncunun köşesindeki boş kare: nömorfik içe gömülü + oyuncu tonu.
        classes.push('cursor-pointer');
        style = {
          background: zone.tint,
          boxShadow: `inset 2px 2px 5px ${zone.base}22, inset -1px -1px 3px rgba(255,255,255,0.6)`,
        };
      } else {
        // Merkez (tarafsız) boş kare: nömorfik içe gömülü.
        classes.push('bg-[#DDE4EE] cursor-pointer');
        style = { boxShadow: 'inset 3px 3px 6px rgba(163,177,198,0.6), inset -2px -2px 5px rgba(255,255,255,0.8)' };
      }

      if (homeColor && !boardTile && !placedTile) {
        // Oyuncunun mutlaka değmesi gereken başlangıç köşesi: ev işareti.
        content = <HomeMark color={homeColor} />;
      }

      // Bu turda yerleştirilmiş (henüz oynanmamış) bir taş, tıklama yerine
      // sürükleme jestiyle (basılı tut → hareket ettir → bırak) yönetilir.
      const hasPending = !!rawPlacedTile;

      if (dragOverKey === k) {
        style = {
          ...style,
          outline: `2px dashed ${dragOverValid ? '#1FA05C' : '#E0483A'}`,
          outlineOffset: '-2px',
        };
      }

      cells.push(
        <div
          key={k}
          className={classes.join(' ')}
          style={{
            ...style,
            gridRow: `${r + 1} / ${r + 2}`,
            gridColumn: `${c + 1} / ${c + 2}`,
            ...(hasPending ? { touchAction: 'none' } : null),
          }}
          data-cell={`${r},${c}`}
          onClick={hasPending ? undefined : () => onCellClick(r, c)}
          onPointerDown={hasPending ? (e) => onTilePointerDown?.(r, c, e) : undefined}
          onPointerMove={hasPending ? onTilePointerMove : undefined}
          onPointerUp={hasPending ? onTilePointerUp : undefined}
          onPointerCancel={hasPending ? onTilePointerCancel : undefined}
        >
          {content}
        </div>,
      );
    }
  }

  // Verilen hücre kümesinin TEK, tamamen yuvarlatılmış (dışbükey VE
  // içbükey köşeler dahil) dış hat SVG path'ini üretir — `buildRoundedOutlinePath`
  // ızgara birimi cinsinden çalışır, burada sadece rengi/kalınlığı ekleyip
  // bir <path> elemanına sarıyoruz. `extraOpen`, kümenin dışına bakan bir
  // kenarı da "kapalı" (çizgisiz) sayabilmek için — bonus bölgesi/merkez
  // çerçevesi, bir oyuncunun bölgesinin İÇİNDEN geçen kendi kenarını bu
  // şekilde bastırır, böylece oyuncunun genişleyen bölgesi içinde gereksiz
  // bir amber çizgi kalmaz.
  const buildOutline = (
    cellsList: [number, number][],
    color: string,
    keyPrefix: string,
    extraOpen?: (r: number, c: number, nr: number, nc: number) => boolean,
  ): React.ReactNode => {
    const uniqueCells = [...new Map(cellsList.map(([r, c]) => [key(r, c), [r, c] as [number, number]])).values()];
    if (uniqueCells.length === 0) return null;
    const d = buildRoundedOutlinePath(uniqueCells, OUTLINE_RADIUS, extraOpen);
    if (!d) return null;
    return (
      <path
        key={keyPrefix}
        d={d}
        fill="none"
        stroke={color}
        strokeWidth={OUTLINE_STROKE}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
      />
    );
  };

  // Bir hücre kümesinin en üst-soldaki hücresine puan rozeti konur
  // (tahtaya konan taşın kendi puan üst simgesiyle çakışmaması için sağ üst
  // yerine sol üst köşede).
  const buildBadge = (cellsList: [number, number][], score: number, color: string): React.ReactNode => {
    let badge: [number, number] | null = null;
    for (const [r, c] of cellsList) {
      if (!badge || r < badge[0] || (r === badge[0] && c < badge[1])) badge = [r, c];
    }
    if (!badge) return null;
    const [r, c] = badge;
    return (
      <div
        className="pointer-events-none absolute z-20 flex items-center justify-center rounded-full font-mono font-bold text-white leading-none whitespace-nowrap"
        style={{
          top: `${(r / SIZE) * 100}%`,
          left: `${(c / SIZE) * 100}%`,
          transform: 'translate(-35%, -35%)',
          background: color,
          fontSize: 'clamp(8px,2vw,11px)',
          padding: '3px 6px',
          boxShadow: '0 2px 5px rgba(0,0,0,0.25)',
        }}
      >
        +{score}
      </div>
    );
  };

  // Her oyuncunun bölgesinin dış hattı — köşeden taşlarla genişledikçe sınır
  // da ona göre büyür. Kenar izleme + yuvarlatma (`buildRoundedOutlinePath`)
  // pahalı olduğundan `territories` değişmediği sürece (bir taş sürüklenirken
  // olduğu gibi) tekrar hesaplanmaz.
  const territoryOutlines = useMemo(
    () =>
      players.map((p, i) => {
        const territoryCells = [...territories[i]].map(
          (k) => k.split(',').map(Number) as [number, number],
        );
        return buildOutline(territoryCells, PLAYER_COLORS[p.colorIndex].base, `territory-${i}`);
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [territories, players],
  );

  // Oyna'ya basmadan önce anlık geçerlilik çerçevesi (yeşil/kırmızı) + puan —
  // aynı sebeple `moveStatus` değişmediği sürece yeniden hesaplanmaz.
  const moveColor = moveStatus ? (moveStatus.valid ? '#1FA05C' : '#E0483A') : undefined;
  const moveOutline = useMemo(
    () => (moveStatus ? buildOutline(moveStatus.cells, moveColor!, 'move') : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [moveStatus],
  );
  const moveBadge = useMemo(
    () => (moveStatus ? buildBadge(moveStatus.cells, moveStatus.score, moveColor!) : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [moveStatus],
  );

  return (
    <div className="w-full max-w-[680px] mx-auto px-3 pt-2 pb-3 flex flex-col items-center">
      <div
        className="relative w-full bg-[#DDE4EE] rounded-[18px]"
        style={{
          boxShadow: '8px 8px 20px rgba(163,177,198,0.7), -4px -4px 14px rgba(255,255,255,0.9), 0 20px 60px rgba(163,177,198,0.5)',
        }}
      >
      <div
        className="relative grid gap-[3px] p-[10px] w-full aspect-square"
        style={{
          gridTemplateColumns: `repeat(${SIZE}, 1fr)`,
          gridTemplateRows: `repeat(${SIZE}, 1fr)`,
        }}
      >
        {cells}

        {/* Tüm bölge/bonus/hamle dış hatları tek bir SVG katmanında — ızgaranın
            tam hücre alanını kaplayacak şekilde tek bir grid öğesi olarak
            (satır/sütun 1'den sona) yerleştirilir, böylece her yolun köşeleri
            (dışbükey VE içbükey) aynı yarıçapla pürüzsüz yuvarlanır. Puan
            rozeti de aynı kutu içinde, aynı yüzde koordinatlarıyla hizalanır. */}
        <div className="pointer-events-none z-10" style={{ gridRow: '1 / -1', gridColumn: '1 / -1', position: 'relative' }}>
          <svg
            className="block w-full h-full"
            style={{ overflow: 'visible' }}
            viewBox={`0 0 ${SIZE} ${SIZE}`}
            preserveAspectRatio="none"
          >
            {/* Her oyuncunun genişleyen bölgesinin dış hattı — bonus bölgesi
                çerçevesinin üzerinde çizilir, böylece bir oyuncunun bölgesi
                bonus alanına ilerlediğinde sınır kendi renginde kalır. */}
            {territoryOutlines}

            {/* Oyna'ya basmadan önce anlık geçerlilik çerçevesi (yeşil/kırmızı):
                tüm kelimelerin hücrelerini kapsayan tek dış hat, iç kesişimde çizgi yok. */}
            {moveOutline}
          </svg>

          {/* Anlık geçerlilik çerçevesinin puan rozeti. */}
          {moveBadge}
        </div>

        {/* Her oyuncunun 4×4 köşesine soluk numara filigranı. `inset` burada
            ebeveyn grid'in kendi `p-[10px]` dolgusuyla BİREBİR eşleşmeli —
            absolute konumlanan bir grid öğesinin containing block'u
            padding box'tır (içerik kutusu değil), yani `inset-1` (4px) ile
            gerçek hücre alanının başladığı 10px arasındaki fark, üst
            köşelerde filigranı hücre alanının üstüne, alt köşelerde
            altına kaydırıyordu (ölçüldü: üstte -3.3px, altta +2.9px —
            toplam ~6px, tam da 10-4 farkı). */}
        <div className="pointer-events-none absolute inset-[10px]">
          {[0, 1, 2, 3].map((i) => {
            const col = cornerColor[i];
            const num = cornerNumber[i];
            if (!col || !num) return null;
            const top = i === 0 || i === 1;
            const left = i === 0 || i === 2;
            return (
              <div
                key={i}
                className="absolute flex items-center justify-center font-mono font-bold leading-none"
                style={{
                  width: cornerFrac,
                  height: cornerFrac,
                  top: top ? 0 : 'auto',
                  bottom: top ? 'auto' : 0,
                  left: left ? 0 : 'auto',
                  right: left ? 'auto' : 0,
                  color: col.base,
                  opacity: 0.20,
                  fontSize: 'clamp(80px, 32vw, 220px)',
                }}
              >
                {num}
              </div>
            );
          })}
        </div>

        {/* Merkezdeki x2 bonus bölgesinin arkasına yazılan büyük "X2" filigranı.
            inset-[10px]: yukarıdaki köşe filigranı notuyla aynı sebep — grid'in
            kendi p-[10px] dolgusuyla eşleşmesi gerekiyor. */}
        <div className="pointer-events-none absolute inset-[10px]">
          <div
            className="absolute flex items-center justify-center font-mono font-bold leading-none"
            style={{
              width: zoneFrac,
              height: zoneFrac,
              top: zoneTop,
              left: zoneLeft,
              color: '#92660A',
              opacity: 0.28,
              fontSize: 'clamp(60px, 24vw, 165px)',
            }}
          >
            X2
          </div>
        </div>
      </div>

      {/* Alt bilgi şeridi (Oyun Geçmişi / X2-X3 açıklaması) — kartın kendi
          zemini ve gölgesiyle bütünleşik bir alt bölüm; ayrı, asılı kalan
          bir beyaz şerit değil. */}
      {!hideFooter && (
        <div className="relative z-10 flex items-center justify-between gap-2 shrink-0 px-[10px] pb-[10px] pt-1 w-full">
          <button
            onClick={onOpenHistory}
            className="text-[13px] font-mono font-bold tracking-[0.5px] text-accent shrink-0"
          >
            Oyun Geçmişi
          </button>
          <div className="flex gap-2 justify-end flex-wrap">
            {!online && (
              <div className="text-[8px] font-mono font-bold text-red flex items-center">
                Çevrimdışı
              </div>
            )}
            {LEGEND.map((item) => (
              <div
                key={item.label}
                className="text-[8px] font-mono flex items-center gap-[3px] text-muted"
              >
                <span
                  className="w-2 h-2 rounded-[1px]"
                  style={{ background: item.bg, border: item.border }}
                />
                <span className="font-bold">{item.label}</span>
                <span className="text-muted/70">{item.desc}</span>
              </div>
            ))}
          </div>
        </div>
      )}
      </div>
    </div>
  );
}
