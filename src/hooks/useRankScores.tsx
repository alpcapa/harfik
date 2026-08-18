// Kelimeki — isimlerin yanındaki k-lig rütbe mührünün (RankSeal) puan
// kaynağı. Kural: mühür HER ZAMAN GÜNCEL puandan türetilir (düşmeli sürüm,
// bkz. `leagueRank.ts`) — sunucudaki `rank_tier` kolonu yalnızca "bu eşik
// kutlandı mı" kaydıdır, gösterimi sürmez.
//
// İki kullanım biçimi var, ikisi de AYNI çekimi paylaşır:
//  1. `useRankScores(ids)` — mührü çizen bileşen id'lere zaten sahipse
//     (Setup, FriendsModal, LiveGameCreateForm).
//  2. `RankTierProvider` + `useRankTier(id)` — satırı çizen bileşen listeyi
//     tutan bileşenden UZAKSA (LiveGamesTab → GameRow/PendingSection →
//     PendingGameCard → ParticipantRow: dört kat prop drilling yerine tek
//     bir context).
//
// "Henüz bilinmiyor" ile "0 puan" AYRI durumlar: yükleme bitene (ya da hata
// alınana) kadar `null` dönülür ve çağıran mührü HİÇ çizmez — aksi halde
// liste bir an herkesi Çaylak gösterirdi. Yükleme bitince listede olmayan
// bir id (hiç oyun bitirmemiş kullanıcı) 0 sayılır, yani gerçekten Çaylak.
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { fetchRankScores } from '../lib/api';
import { tierFor, type RankTier } from '../utils/leagueRank';

export type RankTierLookup = (userId: string | null | undefined) => RankTier | null;

function useScores(userIds: (string | null | undefined)[]): RankTierLookup {
  // Bağımlılık dizisi için KARARLI bir anahtar: id dizisi her render'da yeni
  // bir referans olduğundan doğrudan bağımlılığa konamaz (sonsuz döngü).
  const key = Array.from(new Set(userIds.filter((v): v is string => !!v)))
    .sort()
    .join(',');
  const [scores, setScores] = useState<Map<string, number> | null>(null);

  useEffect(() => {
    if (!key) {
      // Gösterilecek kimse yok — "bilinmiyor"da bırakmak yerine boş haritaya
      // geç, aksi halde liste dolduğunda ilk render'da gereksiz bir bekleme
      // durumu kalır.
      setScores((prev) => prev ?? new Map());
      return;
    }
    let cancelled = false;
    void fetchRankScores(key.split(',')).then((m) => {
      // Hata (null) durumunda BİLİNEN puanlar korunur, yenileri eklenmez —
      // mühürler kaybolmasın diye.
      if (cancelled || !m) return;
      setScores((prev) => {
        const next = new Map(prev ?? []);
        m.forEach((v, k) => next.set(k, v));
        return next;
      });
    });
    return () => {
      cancelled = true;
    };
  }, [key]);

  return (userId) => (scores && userId ? tierFor(scores.get(userId) ?? 0) : null);
}

export const useRankScores = useScores;

const RankTierContext = createContext<RankTierLookup>(() => null);

export function RankTierProvider({
  userIds,
  children,
}: {
  userIds: (string | null | undefined)[];
  children: ReactNode;
}) {
  const lookup = useScores(userIds);
  return <RankTierContext.Provider value={lookup}>{children}</RankTierContext.Provider>;
}

export function useRankTier(userId: string | null | undefined): RankTier | null {
  return useContext(RankTierContext)(userId);
}
