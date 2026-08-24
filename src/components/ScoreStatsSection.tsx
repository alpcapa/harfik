// Kelimeki — ScoreCard ve PlayerScoreCard arasında paylaşılan sekme çubuğu +
// istatistik hücreleri. Öncesinde ikisi de (CLAUDE.md'nin kendi notuyla:
// "ikisi de aynı tab/cells mantığını kopyalayarak taşıdığından tutarlılık
// için birlikte güncellendi") ~150 satırlık neredeyse birebir aynı kodu
// (TABS/pct/Cell hesabı + sekme çubuğu + iki hücre ızgarası JSX'i) ayrı ayrı
// taşıyordu — kod incelemesiyle (Orta bulgu) tek kaynağa çıkarıldı.
import type { PlayerStats } from '../lib/database.types';
import { LoadingNote } from './LoadingNote';

export type TabKey = 'all' | 2 | 4;

export const SCORE_TABS: { key: TabKey; label: string }[] = [
  { key: 'all', label: 'Genel' },
  { key: 2, label: '2 Oyunculu' },
  { key: 4, label: '4 Oyunculu' },
];

interface Cell {
  label: string;
  value: number | string;
  rate?: string;
  cls?: string;
  span2?: boolean;
}

/**
 * `stats`'tan Oyuncu/Oyun istatistik kutularının içeriğini hesaplar — hem
 * ScoreCard hem PlayerScoreCard'ın önceden ayrı ayrı taşıdığı BİREBİR AYNI
 * mantık (2 kişilikte "İkincilik" lig puanı getirmese de bilgi amaçlı
 * gösterilir, bkz. dosyaların eski git geçmişi).
 */
export function buildScoreCells(
  stats: PlayerStats | null | undefined,
): { playerCells: Cell[]; gameCells: Cell[] } {
  const pct = (n: number) =>
    stats && stats.games_played > 0 ? `%${Math.round((n / stats.games_played) * 100)}` : '%0';
  const secondCellValue = stats?.second_places ?? 0;

  const playerCells: Cell[] = [
    { label: 'Toplam Oyun', value: stats?.games_played ?? 0 },
    {
      label: 'Yapay Zeka ile',
      value: stats?.local_games_played ?? 0,
      rate: pct(stats?.local_games_played ?? 0),
    },
    {
      label: 'Arkadaşınla',
      value: stats?.online_games_played ?? 0,
      rate: pct(stats?.online_games_played ?? 0),
    },
    {
      label: 'Birincilik',
      value: stats?.first_places ?? 0,
      rate: pct(stats?.first_places ?? 0),
      cls: 'text-gold',
    },
    {
      label: 'İkincilik',
      value: secondCellValue,
      rate: pct(secondCellValue),
      cls: 'text-accent',
    },
    {
      label: 'Teslim Olma',
      value: stats?.surrendered_count ?? 0,
      rate: pct(stats?.surrendered_count ?? 0),
      cls: 'text-red',
    },
  ];

  const gameCells: Cell[] = [
    { label: 'En Yüksek Oyun Puanı', value: stats?.best_score ?? 0, cls: 'text-gold' },
    { label: 'En İyi Hamle Puanı', value: stats?.best_move_score ?? 0, cls: 'text-accent' },
    { label: 'En Yüksek Puanlı Kelime', value: stats?.best_word_score ?? 0, cls: 'text-gold' },
    {
      // "(OHP)" — k-lig listesindeki OHP sütunuyla AYNI sayı olduğunu
      // söyleyen tek ipucu bu; iki ekran arasındaki bağı kuran etiket
      // (kullanıcı isteği, 20 Ağustos 2026).
      label: 'Ortalama Hamle Puanı (OHP)',
      value: Number(stats?.avg_move_score ?? 0).toFixed(2),
      cls: 'text-accent',
    },
    { label: 'En Uzun Kelime', value: stats?.longest_word ?? '—', cls: 'text-text', span2: true },
  ];

  return { playerCells, gameCells };
}

export function ScoreTabsBar({
  tab,
  onChange,
  statsByTab,
}: {
  tab: TabKey;
  onChange: (t: TabKey) => void;
  statsByTab: Record<TabKey, PlayerStats | null | undefined>;
}) {
  return (
    <div className="mb-3 flex gap-2">
      {SCORE_TABS.map(({ key, label }) => (
        <button
          key={key}
          type="button"
          onClick={() => onChange(key)}
          className={[
            'flex-1 py-2 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97] flex flex-col items-center',
            tab === key
              ? 'btn-raised bg-accent text-white border-accent'
              : 'btn-raised-neutral bg-panel text-text border-border',
          ].join(' ')}
        >
          <span className="leading-none">{label}</span>
          <span className="text-[10px] font-normal normal-case leading-none mt-0.5">
            ({statsByTab[key]?.total_score ?? 0} puan)
          </span>
        </button>
      ))}
    </div>
  );
}

function CellsGrid({ cells }: { cells: Cell[] }) {
  return (
    <div className="grid grid-cols-3 gap-2">
      {cells.map((c) => (
        <div
          key={c.label}
          className={`btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center ${c.span2 ? 'col-span-2' : ''}`}
        >
          <div className={`font-mono text-xl font-bold ${c.cls ?? 'text-text'}`}>{c.value}</div>
          {c.rate && <div className="font-mono text-xs text-muted mt-0.5">({c.rate})</div>}
          <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
            {c.label}
          </div>
        </div>
      ))}
    </div>
  );
}

/** Yükleniyor/boş durumu + iki istatistik ızgarası — `emptyText` çağırana bırakılır (ScoreCard/PlayerScoreCard'da metin farklı). */
export function ScoreStatsSection({
  stats,
  emptyText,
}: {
  stats: PlayerStats | null | undefined;
  emptyText: string;
}) {
  if (stats === undefined) {
    // Yüklenirken de TAM ızgara çizilir, değerler "—". Pencere yüksekliğini
    // içeriğinden aldığından tek satırlık bir yükleme metni onu önce küçük
    // açıp veri gelince büyütüyordu — kullanıcı bunu mobil portta bildirdi
    // (24 Ağustos 2026): "önce 1-2 saniye bir popup görüyorum, sonra
    // sıralama üstüne geliyor... tek pencere açılmalı ve datanın olduğu
    // kısımda yükleniyor yazmalı". Aynı kusur webde de vardı.
    const { playerCells, gameCells } = buildScoreCells(null);
    const dash = (cells: Cell[]): Cell[] => cells.map((c) => ({ ...c, value: '—', cls: 'text-muted' }));
    return (
      <>
        <LoadingNote py="py-1" />
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mb-1.5">
          Oyuncu İstatistikleri
        </div>
        <CellsGrid cells={dash(playerCells)} />
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mt-4 mb-1.5">
          Oyun İstatistikleri
        </div>
        <CellsGrid cells={dash(gameCells)} />
      </>
    );
  }
  const { playerCells, gameCells } = buildScoreCells(stats);
  return (
    <>
      {!stats && <p className="text-muted text-[10px] font-mono text-center pb-2">{emptyText}</p>}
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mb-1.5">
        Oyuncu İstatistikleri
      </div>
      <CellsGrid cells={playerCells} />

      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mt-4 mb-1.5">
        Oyun İstatistikleri
      </div>
      <CellsGrid cells={gameCells} />
    </>
  );
}
