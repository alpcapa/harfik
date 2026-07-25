// Kelimeki — skor kartı: oyuncu istatistikleri ve sıralamaya geçiş
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { GameHistoryModal } from './GameHistoryModal';
import { Leaderboard } from './Leaderboard';
import { fetchPlayerStats, fetchMyLeaderboardRank } from '../lib/api';
import type { PlayerStats, MyLeaderboardRank } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';

interface ScoreCardProps {
  onClose: () => void;
}

const TABS = [2, 4] as const;

function calculateAge(birthDate: string): number {
  const today = new Date();
  const born = new Date(birthDate);
  let age = today.getFullYear() - born.getFullYear();
  const monthDiff = today.getMonth() - born.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < born.getDate())) {
    age--;
  }
  return age;
}

export function ScoreCard({ onClose }: ScoreCardProps) {
  const { user, profile } = useAuth();
  const [statsByCount, setStatsByCount] = useState<
    Record<number, PlayerStats | null | undefined>
  >({ 2: undefined, 4: undefined });
  const [tab, setTab] = useState<(typeof TABS)[number]>(2);
  const [showAllGames, setShowAllGames] = useState(false);
  const [showLeague, setShowLeague] = useState(false);
  const [myRank, setMyRank] = useState<MyLeaderboardRank | null>(null);

  useEffect(() => {
    for (const count of TABS) {
      fetchPlayerStats(count).then((s) =>
        setStatsByCount((cur) => ({ ...cur, [count]: s })),
      );
    }
  }, []);

  useEffect(() => {
    if (!user) return;
    fetchMyLeaderboardRank(user.id).then(setMyRank);
  }, [user]);

  // Skor kartı herkese açık olabildiğinden (Sanal Lig üzerinden başkaları da
  // görebilir) tam ad/soyad değil, oyun içindeki aynı kısa kimlik gösterilir
  // (bkz. Setup/App.tsx'teki accountName) — nickname yoksa sadece isim.
  const name =
    profile?.display_name ||
    profile?.first_name ||
    user?.email ||
    'Oyuncu';

  const age = profile?.birth_date ? calculateAge(profile.birth_date) : null;

  const stats = statsByCount[tab];

  const totalScore = TABS.reduce((sum, count) => sum + (statsByCount[count]?.total_score ?? 0), 0);

  const pct = (n: number) =>
    stats && stats.games_played > 0 ? `%${Math.round((n / stats.games_played) * 100)}` : '%0';

  // 4 kişilikte ikincilik hâlâ +1 puan getirdiğinden ödüllü bir stat olarak
  // gösterilir; 2 kişilikte 2. olmak = kaybetmek olduğundan (artık lig puanı
  // getirmiyor) bu stat hiç gösterilmez.
  const secondCellValue = stats?.second_places ?? 0;

  const cells: {
    label: string;
    value: number | string;
    rate?: string;
    cls?: string;
    wide?: boolean;
    span2?: boolean;
    place?: string;
  }[] = [
    { label: 'Toplam Oyun', value: stats?.games_played ?? 0 },
    {
      label: 'Ortalama Hamle Puanı',
      value: Number(stats?.avg_move_score ?? 0).toFixed(2),
      cls: 'text-accent',
      place: 'row-start-2 col-start-1',
    },
    {
      label: 'Birincilik',
      value: stats?.first_places ?? 0,
      rate: pct(stats?.first_places ?? 0),
      cls: 'text-gold',
    },
    ...(tab === 4
      ? [
          {
            label: 'İkincilik',
            value: secondCellValue,
            rate: pct(secondCellValue),
            cls: 'text-accent',
          },
          { label: 'En Yüksek Oyun Puanı', value: stats?.best_score ?? 0, cls: 'text-gold' },
          {
            label: 'Teslim Olma',
            value: stats?.surrendered_count ?? 0,
            rate: pct(stats?.surrendered_count ?? 0),
            cls: 'text-red',
          },
        ]
      : [
          {
            label: 'Teslim Olma',
            value: stats?.surrendered_count ?? 0,
            rate: pct(stats?.surrendered_count ?? 0),
            cls: 'text-red',
          },
          { label: 'En Yüksek Oyun Puanı', value: stats?.best_score ?? 0, cls: 'text-gold' },
        ]),
    { label: 'En İyi Hamle Puanı', value: stats?.best_move_score ?? 0, cls: 'text-accent' },
    {
      label: 'En Uzun Kelime',
      value: stats?.longest_word ?? '—',
      cls: 'text-text',
      wide: tab !== 4,
      span2: tab === 4,
    },
  ];

  return (
    <Modal title="Skor Kartı" onClose={onClose}>
      <div className="mb-4 flex items-center gap-3">
        <Avatar url={profile?.avatar_url} name={name} size={44} />
        <div className="min-w-0 flex-1">
          <div className="text-base font-bold text-text truncate">{name}</div>
          {age !== null && (
            <div className="text-xs font-mono text-muted mt-0.5">Yaş: {age}</div>
          )}
        </div>
        <button
          type="button"
          onClick={() => setShowLeague(true)}
          aria-label="Sanal Lig sıralamasını göster"
          className="text-right shrink-0 active:opacity-70 transition-opacity"
        >
          <div className="flex items-center justify-end gap-1 text-xs uppercase tracking-[1px] text-muted font-mono">
            <span className="font-bold">Sanal Lig</span>
            <span className="w-3.5 h-3.5 rounded-full border border-muted text-muted flex items-center justify-center text-[9px] leading-none font-bold">
              ?
            </span>
          </div>
          <div className="font-mono text-xl font-bold text-gold">
            {myRank && (
              <span className="text-sm font-normal text-muted">
                #{myRank.rank}
                <span className="mx-0.5">·</span>
              </span>
            )}
            {totalScore}
            <span className="text-xs font-normal text-muted"> puan</span>
          </div>
        </button>
      </div>

      <div className="mb-3 flex gap-2">
        {TABS.map((count) => (
          <button
            key={count}
            type="button"
            onClick={() => setTab(count)}
            className={[
              'flex-1 py-2 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97] flex flex-col items-center',
              tab === count
                ? 'btn-raised bg-accent text-white border-accent'
                : 'btn-raised-neutral bg-panel text-text border-border',
            ].join(' ')}
          >
            <span className="leading-none">{count} Oyunculu</span>
            <span className="text-[10px] font-normal normal-case leading-none mt-0.5">
              ({statsByCount[count]?.total_score ?? 0} puan)
            </span>
          </button>
        ))}
      </div>

      {stats === undefined ? (
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : (
        <>
          {!stats && (
            <p className="text-muted text-[10px] font-mono text-center pb-2">
              Henüz {tab} oyunculu oyun kaydın yok.
            </p>
          )}
          <div className="grid grid-cols-3 gap-2">
            {cells.map((c) => (
              <div
                key={c.label}
                className={`btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center ${c.wide ? 'col-span-3' : c.span2 ? 'col-span-2' : ''} ${c.place ?? ''}`}
              >
                <div className={`font-mono text-xl font-bold ${c.cls ?? 'text-text'}`}>
                  {c.value}
                </div>
                {c.rate && (
                  <div className="font-mono text-xs text-muted mt-0.5">({c.rate})</div>
                )}
                <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                  {c.label}
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      <div className="text-center mt-4">
        <button
          onClick={() => setShowAllGames(true)}
          className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity"
        >
          Tüm Oyunları Gör
        </button>
      </div>

      {showAllGames && (
        <GameHistoryModal playerCount={tab} onClose={() => setShowAllGames(false)} />
      )}
      {showLeague && <Leaderboard onClose={() => setShowLeague(false)} />}
    </Modal>
  );
}
