// Kelimeki — skor kartı: oyuncu istatistikleri ve sıralamaya geçiş
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { GameHistoryModal } from './GameHistoryModal';
import { Leaderboard } from './Leaderboard';
import { KLigMark } from './KLigMark';
import { RankSeal } from './RankSeal';
import { RankInfoModal } from './RankInfoModal';
import { tierFor } from '../utils/leagueRank';
import { fetchPlayerStats, fetchMyLeaderboardRank } from '../lib/api';
import type { PlayerStats, MyLeaderboardRank, Gender } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';
import { type TabKey, SCORE_TABS, ScoreTabsBar, ScoreStatsSection } from './ScoreStatsSection';

interface ScoreCardProps {
  onClose: () => void;
}

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
  const [showRankInfo, setShowRankInfo] = useState(false);
  const [myRank, setMyRank] = useState<MyLeaderboardRank | null>(null);

  useEffect(() => {
    for (const { key } of SCORE_TABS) {
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
  // Rütbe mührü — GÜNCEL puandan türetilir (düşmeli sürüm, bkz.
  // leagueRank.ts). Genel istatistik henüz yüklenmediyse gizli. Modal
  // BAŞLIĞININ sağında, yazısız/büyük durur (12 Ağustos 2026, kullanıcı
  // kararı — ilk sürüm ismin yanındaydı); dokununca RankInfoModal açılır.
  const rankTier = statsByTab.all !== undefined ? tierFor(statsByTab.all?.total_score) : null;

  return (
    <Modal
      title="Skor Kartı"
      onClose={onClose}
      headerAction={
        rankTier ? (
          <button
            type="button"
            onClick={() => setShowRankInfo(true)}
            aria-label={`Rütbe: ${rankTier.name} — bilgi için dokun`}
            className="shrink-0 leading-none active:scale-90 transition-transform mr-1"
          >
            <RankSeal tier={rankTier} size={34} />
          </button>
        ) : undefined
      }
    >
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
          <div className="font-mono text-sm font-bold text-accent">
            {myRank && (
              <>
                #{myRank.rank}
                <span className="mx-0.5">·</span>
              </>
            )}
            {totalScore}
            <span className="text-xs font-normal text-muted"> puan</span>
          </div>
        </button>
      </div>

      <ScoreTabsBar tab={tab} onChange={setTab} statsByTab={statsByTab} />

      <ScoreStatsSection
        stats={stats}
        emptyText={tab === 'all' ? 'Henüz hiç oyun kaydın yok.' : `Henüz ${tab} oyunculu oyun kaydın yok.`}
      />

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
      {showRankInfo && rankTier && (
        <RankInfoModal
          tier={rankTier}
          totalScore={totalScore}
          bonusPoints={statsByTab.all?.bonus_points ?? 0}
          onClose={() => setShowRankInfo(false)}
        />
      )}
    </Modal>
  );
}
