// Kelimeki — liderlik tablosu
import { useCallback, useEffect, useRef, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { fetchLeaderboard, fetchMyLeaderboardRank } from '../lib/api';
import type { LeaderboardRow, MyLeaderboardRank } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';
import { PlayerScoreCard, type PlayerSummary } from './PlayerScoreCard';
import { KLigMark } from './KLigMark';
import { RankSeal } from './RankSeal';
import { tierFor } from '../utils/leagueRank';
import { shortDisplayName } from '../utils/profileFields';

interface LeaderboardProps {
  onClose: () => void;
}

// İlk açılışta gösterilen sıra sayısı (istenen "ilk 10"); kaydırdıkça
// sonraki sayfalar bundan daha büyük bir adımla (PAGE_SIZE) lazy-load edilir.
const INITIAL_PAGE_SIZE = 10;
const PAGE_SIZE = 20;

// Herkese açık bir sıralama olduğundan tam ad/soyad değil, nickname yoksa
// sadece isim gösterilir (oyun içindeki aynı kısa kimlik kuralı).
function rowName(r: LeaderboardRow): string {
  return shortDisplayName(r, 'Anonim');
}

function rowToPlayerSummary(r: LeaderboardRow): PlayerSummary {
  return {
    id: r.user_id,
    username: r.username,
    first_name: r.first_name,
    last_name: r.last_name,
    display_name: r.display_name,
    avatar_url: r.avatar_url,
  };
}

export function Leaderboard({ onClose }: LeaderboardProps) {
  const { user, profile } = useAuth();
  const [rows, setRows] = useState<LeaderboardRow[] | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [myRank, setMyRank] = useState<MyLeaderboardRank | null>(null);
  const [selected, setSelected] = useState<PlayerSummary | null>(null);
  const scrollRef = useRef<HTMLOListElement | null>(null);
  const sentinelRef = useRef<HTMLLIElement | null>(null);

  useEffect(() => {
    fetchLeaderboard(INITIAL_PAGE_SIZE, 0).then((r) => {
      setRows(r);
      setHasMore(r.length === INITIAL_PAGE_SIZE);
    });
  }, []);

  useEffect(() => {
    if (!user) return;
    fetchMyLeaderboardRank(user.id).then(setMyRank);
  }, [user]);

  // rows'un en güncel uzunluğunu bir ref'te tutmak loadMore'u (dolayısıyla
  // aşağıdaki IntersectionObserver effect'ini) rows'tan bağımsız/stabil
  // kılıyor — önceden loadMore [rows]'a bağlı olduğundan, her yeni sayfa
  // yüklendiğinde (rows referansı değiştiğinde) observer gereksiz yere
  // disconnect edilip yeniden kuruluyordu.
  const rowsRef = useRef(rows);
  rowsRef.current = rows;
  const loadMore = useCallback(() => {
    if (rowsRef.current === null) return;
    setLoadingMore((already) => {
      if (already) return already;
      void fetchLeaderboard(PAGE_SIZE, rowsRef.current!.length).then((page) => {
        setRows((cur) => [...(cur ?? []), ...page]);
        setHasMore(page.length === PAGE_SIZE);
        setLoadingMore(false);
      });
      return true;
    });
  }, []);

  const rowsLoaded = rows !== null;
  useEffect(() => {
    if (!hasMore || !rowsLoaded) return;
    const sentinel = sentinelRef.current;
    const root = scrollRef.current;
    if (!sentinel || !root) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) loadMore();
      },
      { root, rootMargin: '80px' },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [hasMore, rowsLoaded, loadMore]);

  // Giriş yapmış kullanıcı şu ana kadar yüklenen satırlarda mı?
  const meInList = user && rows ? rows.some((r) => r.user_id === user.id) : false;

  return (
    <Modal
      title={
        <span className="inline-flex items-center gap-1.5">
          🏆 <KLigMark height={36} className="inline-block relative top-[1px]" />
        </span>
      }
      onClose={onClose}
    >
      <p className="text-[11px] text-muted font-mono text-center mb-3 leading-relaxed">
        k-lig, senin gibi kayıtlı kullanıcıların aldığı puanlara göre oluşan bir yarışmadır.
      </p>
      {rows === null ? (
        <p className="text-muted text-xs font-mono text-center py-6">Yükleniyor…</p>
      ) : (
        <div className="flex flex-col gap-2">
          <div className="flex items-center text-[9px] uppercase tracking-[1px] text-muted font-mono px-2 pb-1 gap-1">
            <span className="w-6">Sıra</span>
            <span className="flex-1">Oyuncu</span>
            <span className="w-12 text-right">Puan</span>
          </div>
          {rows.length === 0 ? (
            <p className="text-muted text-xs font-mono text-center py-4">
              Henüz skor yok. İlk sen ol!
            </p>
          ) : (
            <ol ref={scrollRef} className="flex flex-col gap-1 max-h-[50vh] overflow-y-auto pr-1">
              {rows.map((r, i) => {
                const me = user && r.user_id === user.id;
                const name = rowName(r);
                return (
                  <li key={r.user_id}>
                    <button
                      type="button"
                      onClick={() => setSelected(rowToPlayerSummary(r))}
                      className={[
                        'w-full flex items-center gap-1 text-sm font-mono rounded-md px-2 py-1.5 text-left active:opacity-70 transition-opacity',
                        me ? 'bg-accent/10 border border-accent' : 'bg-bg',
                      ].join(' ')}
                    >
                      <span
                        className={[
                          'w-6 font-bold shrink-0',
                          i === 0 ? 'text-gold' : i < 3 ? 'text-accent' : 'text-muted',
                        ].join(' ')}
                      >
                        {i + 1}
                      </span>
                      <Avatar
                        url={r.avatar_url}
                        name={name}
                        size={22}
                        className="mr-1 shrink-0"
                      />
                      <span className="flex-1 truncate text-text">{name}</span>
                      {/* Rütbe mührü — ulaşılan en yüksek kademe (düşmez),
                          bkz. leagueRank.ts / league_rewards.rank_up. */}
                      <RankSeal tier={tierFor(r.rank_tier)} size={17} className="shrink-0 mr-0.5" />
                      <span className="w-12 text-right font-bold text-accent shrink-0">
                        {r.total_score?.toLocaleString('tr-TR') ?? '—'}
                      </span>
                    </button>
                  </li>
                );
              })}
              {hasMore && (
                <li ref={sentinelRef} className="py-2 text-center">
                  <span className="text-muted text-[10px] font-mono">
                    {loadingMore ? 'Yükleniyor…' : ''}
                  </span>
                </li>
              )}
            </ol>
          )}

          {user && !meInList && myRank && (
            <>
              <div className="flex items-center gap-2 px-2">
                <div className="flex-1 border-t border-dashed border-border" />
                <span className="text-[9px] text-muted font-mono uppercase tracking-[1px]">senin sıran</span>
                <div className="flex-1 border-t border-dashed border-border" />
              </div>
              <button
                type="button"
                onClick={() =>
                  user &&
                  setSelected({
                    id: user.id,
                    username: profile?.username ?? null,
                    first_name: profile?.first_name ?? null,
                    last_name: profile?.last_name ?? null,
                    display_name: profile?.display_name ?? null,
                    avatar_url: profile?.avatar_url ?? null,
                  })
                }
                className="w-full flex items-center gap-1 text-sm font-mono rounded-md px-2 py-1.5 text-left bg-accent/10 border border-accent active:opacity-70 transition-opacity"
              >
                <span className="w-6 font-bold text-muted shrink-0">{myRank.rank}</span>
                <span className="flex-1 text-text">Sen</span>
                <span className="w-12 text-right font-bold text-accent shrink-0">
                  {myRank.total_score.toLocaleString('tr-TR')}
                </span>
              </button>
            </>
          )}
        </div>
      )}

      {selected && (
        <PlayerScoreCard member={selected} onClose={() => setSelected(null)} />
      )}
    </Modal>
  );
}
