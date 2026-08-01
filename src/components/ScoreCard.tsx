// Kelimeki — skor kartı: oyuncu istatistikleri ve sıralamaya geçiş
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { GameHistoryModal } from './GameHistoryModal';
import { Leaderboard } from './Leaderboard';
import { KLigMark } from './KLigMark';
import { fetchPlayerStats, fetchMyLeaderboardRank } from '../lib/api';
import type { PlayerStats, MyLeaderboardRank, Gender } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';

interface ScoreCardProps {
  onClose: () => void;
}

type TabKey = 'all' | 2 | 4;
const TABS: { key: TabKey; label: string }[] = [
  { key: 'all', label: 'Genel' },
  { key: 2, label: '2 Oyunculu' },
  { key: 4, label: '4 Oyunculu' },
];

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

// "Yaş: 59" yerine "Y:59/C:E" — yaş (Y) ve cinsiyet (C, Erkek/Kadın) tek
// satırda, yalnızca girilmiş olanlar gösterilir; ikisi de yoksa boş.
function formatAgeGender(age: number | null, gender: Gender | null | undefined): string {
  const genderLetter = gender === 'male' ? 'E' : gender === 'female' ? 'K' : null;
  const parts: string[] = [];
  if (age !== null) parts.push(`Y:${age}`);
  if (genderLetter) parts.push(`C:${genderLetter}`);
  return parts.join('/');
}

export function ScoreCard({ onClose }: ScoreCardProps) {
  const { user, profile } = useAuth();
  const [statsByTab, setStatsByTab] = useState<
    Record<TabKey, PlayerStats | null | undefined>
  >({ all: undefined, 2: undefined, 4: undefined });
  const [tab, setTab] = useState<TabKey>('all');
  const [showAllGames, setShowAllGames] = useState(false);
  const [showLeague, setShowLeague] = useState(false);
  const [myRank, setMyRank] = useState<MyLeaderboardRank | null>(null);

  useEffect(() => {
    for (const { key } of TABS) {
      fetchPlayerStats(key).then((s) =>
        setStatsByTab((cur) => ({ ...cur, [key]: s })),
      );
    }
  }, []);

  useEffect(() => {
    if (!user) return;
    fetchMyLeaderboardRank(user.id).then(setMyRank);
  }, [user]);

  // Skor kartı herkese açık olabildiğinden (k-lig üzerinden başkaları da
  // görebilir) tam ad/soyad değil, oyun içindeki aynı kısa kimlik gösterilir
  // (bkz. Setup/App.tsx'teki accountName) — nickname yoksa sadece isim.
  const name =
    profile?.display_name ||
    profile?.first_name ||
    user?.email ||
    'Oyuncu';

  const age = profile?.birth_date ? calculateAge(profile.birth_date) : null;
  const ageGenderLabel = formatAgeGender(age, profile?.gender);

  const stats = statsByTab[tab];

  const totalScore = statsByTab.all?.total_score ?? 0;

  const pct = (n: number) =>
    stats && stats.games_played > 0 ? `%${Math.round((n / stats.games_played) * 100)}` : '%0';

  // 2 kişilikte 2. olmak lig puanı getirmez (kaybetmekle aynı şey) ama
  // "İkincilik" kutusu yine de bilgi amaçlı tüm sekmelerde gösteriliyor —
  // kullanıcı isteği: üç sekme de aynı kutu setine sahip olsun.
  const secondCellValue = stats?.second_places ?? 0;

  type Cell = { label: string; value: number | string; rate?: string; cls?: string; span2?: boolean };

  // Oyuncu istatistikleri (davranış/sonuç sayıları) üstte, oyun istatistikleri
  // (tek oyun/hamle/kelime rekorları) altta — kullanıcı isteği. Oyun
  // istatistikleri artık tab'dan bağımsız (İkincilik hariç hiçbiri
  // player_count'a göre değişmiyordu zaten).
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
      label: 'Ortalama Hamle Puanı',
      value: Number(stats?.avg_move_score ?? 0).toFixed(2),
      cls: 'text-accent',
    },
    { label: 'En Uzun Kelime', value: stats?.longest_word ?? '—', cls: 'text-text', span2: true },
  ];

  return (
    <Modal title="Skor Kartı" onClose={onClose}>
      <div className="mb-4 flex items-center gap-3">
        <Avatar url={profile?.avatar_url} name={name} size={44} />
        <div className="min-w-0 flex-1">
          <div className="text-base font-bold text-text truncate">{name}</div>
          {ageGenderLabel && (
            <div className="text-xs font-mono text-muted">{ageGenderLabel}</div>
          )}
        </div>
        <button
          type="button"
          onClick={() => setShowLeague(true)}
          aria-label="k-lig sıralamasını göster"
          className="text-right shrink-0 active:opacity-70 transition-opacity"
        >
          <div className="flex items-center justify-end gap-1 text-xs uppercase tracking-[1px] text-muted font-mono">
            <KLigMark height={16} className="inline-block" />
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
        {TABS.map(({ key, label }) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
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

      {stats === undefined ? (
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : (
        <>
          {!stats && (
            <p className="text-muted text-[10px] font-mono text-center pb-2">
              {tab === 'all' ? 'Henüz hiç oyun kaydın yok.' : `Henüz ${tab} oyunculu oyun kaydın yok.`}
            </p>
          )}
          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mb-1.5">
            Oyuncu İstatistikleri
          </div>
          <div className="grid grid-cols-3 gap-2">
            {playerCells.map((c) => (
              <div
                key={c.label}
                className={`btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center ${c.span2 ? 'col-span-2' : ''}`}
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

          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mt-4 mb-1.5">
            Oyun İstatistikleri
          </div>
          <div className="grid grid-cols-3 gap-2">
            {gameCells.map((c) => (
              <div
                key={c.label}
                className={`btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center ${c.span2 ? 'col-span-2' : ''}`}
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

      <div className="text-center mt-1.5">
        <button
          onClick={() => setShowAllGames(true)}
          className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-accent active:opacity-70 transition-opacity"
        >
          Tüm Geçmiş Oyunlar
        </button>
      </div>

      {showAllGames && (
        <GameHistoryModal playerCount={tab === 'all' ? null : tab} onClose={() => setShowAllGames(false)} />
      )}
      {showLeague && <Leaderboard onClose={() => setShowLeague(false)} />}
    </Modal>
  );
}
