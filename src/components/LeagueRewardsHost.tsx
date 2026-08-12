// Kelimeki — k-lig ödül/rütbe kutlama banner'ının sürücüsü. Görülmemiş
// `league_rewards` satırlarını çekip TEK birleşik RewardBanner gösterir,
// "Devam"da hepsini `mark_league_rewards_seen` RPC'siyle işaretler (sunucu
// tarafı `seen_at`, cihazdan bağımsız "bir kez göster" garantisi).
//
// App.tsx'in Setup ve oyun dallarında + OnlineGameScreen'de mount edilir —
// App erken return'lerle dallandığından tek üst-seviye mount YOK; dallar
// birbirini dışladığından aynı anda hep en fazla bir host yaşar, modül
// seviyesindeki `requestCheck` kaydı bu yüzden güvenli (mount set eder,
// unmount temizler; React yeni dalı eskisinin cleanup'ından sonra kurar).
//
// `suppress`: oyun ortasında (phase='play' ve bitmemişken) banner'ın odak
// çalmasını önler — bayrak düşünce (oyun bitince/Setup'a dönünce) otomatik
// bir kontrol tetiklenir, bekleyen kutlama o anda gösterilir.
import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { fetchUnseenLeagueRewards, markLeagueRewardsSeen } from '../lib/api';
import type { LeagueReward } from '../lib/database.types';
import { RewardBanner, type RewardSummary } from './RewardBanner';
import { tierFor } from '../utils/leagueRank';

let requestCheck: (() => void) | null = null;

/**
 * Bir `games` kaydının sunucuya GERÇEKTEN düştüğü an çağrılır (App.tsx'in
 * oyun-bitti kaydı, OnlineGameScreen'in bitiş senkronu) — trigger ödülü aynı
 * transaction'da açtığından hemen ardından çekmek güvenli. Host mount değilse
 * sessiz no-op; bir sonraki mount/focus kontrolü zaten yakalar.
 */
export function requestLeagueRewardCheck() {
  requestCheck?.();
}

function buildSummary(rows: LeagueReward[]): RewardSummary {
  let rewardPoints = 0;
  let rewardGamesThreshold: number | undefined;
  let rankUpThreshold: number | undefined;
  let milestone: number | undefined;
  for (const r of rows) {
    if (r.kind === 'games_reward') {
      rewardPoints += r.points;
      if (!rewardGamesThreshold || r.threshold > rewardGamesThreshold) {
        rewardGamesThreshold = r.threshold;
      }
    } else if (r.kind === 'rank_up') {
      if (!rankUpThreshold || r.threshold > rankUpThreshold) rankUpThreshold = r.threshold;
    } else if (r.kind === 'points_milestone') {
      if (!milestone || r.threshold > milestone) milestone = r.threshold;
    }
  }
  return {
    rankUpTier: rankUpThreshold ? tierFor(rankUpThreshold) : undefined,
    milestone,
    rewardPoints,
    rewardGamesThreshold,
  };
}

export function LeagueRewardsHost({ suppress = false }: { suppress?: boolean }) {
  const { user } = useAuth();
  const userId = user?.id ?? null;
  const [summary, setSummary] = useState<RewardSummary | null>(null);
  const inFlightRef = useRef(false);
  const suppressRef = useRef(suppress);
  suppressRef.current = suppress;
  const showingRef = useRef(false);
  showingRef.current = summary !== null;

  const check = useCallback(() => {
    if (!userId || suppressRef.current || inFlightRef.current || showingRef.current) return;
    inFlightRef.current = true;
    void fetchUnseenLeagueRewards(userId)
      .then((rows) => {
        if (rows.length > 0 && !suppressRef.current && !showingRef.current) {
          setSummary(buildSummary(rows));
        }
      })
      .finally(() => {
        inFlightRef.current = false;
      });
  }, [userId]);

  // Mount / kullanıcı değişimi / suppress'in düşmesi → kontrol.
  useEffect(() => {
    if (!suppress) check();
  }, [suppress, check]);

  // Oyun kaydı düşünce anında kontrol (modül seviyesi köprü).
  useEffect(() => {
    requestCheck = check;
    return () => {
      requestCheck = null;
    };
  }, [check]);

  // Öne dönüşte kontrol — projedeki standart üçlü + 300ms debounce
  // (masaüstünde sekmeye dönüş üç olayı neredeyse aynı anda tetikliyor).
  useEffect(() => {
    let timer: number | undefined;
    const onWake = () => {
      window.clearTimeout(timer);
      timer = window.setTimeout(check, 300);
    };
    const onVisibility = () => {
      if (document.visibilityState === 'visible') onWake();
    };
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('focus', onWake);
    window.addEventListener('online', onWake);
    return () => {
      window.clearTimeout(timer);
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('focus', onWake);
      window.removeEventListener('online', onWake);
    };
  }, [check]);

  // Hesap değişiminde açık banner'ı düşür (başka hesabın kutlaması kalmasın).
  useEffect(() => {
    setSummary(null);
  }, [userId]);

  if (!summary) return null;
  return (
    <RewardBanner
      summary={summary}
      onClose={() => {
        // İşaretleme "Devam"da — sayfa banner görünürken kapanırsa satırlar
        // görülmemiş kalır ve bir sonraki girişte tekrar gösterilir.
        void markLeagueRewardsSeen();
        setSummary(null);
      }}
    />
  );
}
