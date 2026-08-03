// Kelimeki — "Ana Ekrana Ekle" ile kurulan PWA'nın kendi İKONU üzerinde
// (masaüstü/dock/görev çubuğu) tarayıcının Badge API'siyle
// (`navigator.setAppBadge`) kırmızı yuvarlak/beyaz sayı rozeti gösterir —
// uygulama hiç açılmadan da görünür. Setup ekranındaki "Arkadaşınla"/
// "Yapay Zeka ile" sekme rozetleriyle ve UserMenu'deki "Arkadaşlar"
// rozetiyle AYNI üç sinyalin toplamı: bekleyen arkadaşlık isteği + bekleyen
// Canlı davet/sırası gelen aktif Canlı oyun + devam eden Yapay Zeka oyunu
// sayısı. Sonuncusu App.tsx'in zaten sahip olduğu `localSaveCount`'tan
// parametre olarak alınır, burada yeniden hesaplanmaz (misafir/girişli
// ayrımı zaten orada çözülüyor).
//
// Badge API iOS'ta desteklenmiyor (Android/masaüstü Chrome/Edge'de
// çalışıyor) — `'setAppBadge' in navigator` ile feature-detect edilip
// yoksa sessizce hiçbir şey yapılmıyor. Uygulama kapalıyken (arka planda
// bile çalışmıyorken) bu rozeti canlı güncelleyecek bir mekanizma yok
// (bunun için Push API + Service Worker gerekir, kapsam dışı) — rozet
// yalnızca uygulama açıkken/arka plan sekmesindeyken (Realtime +
// focus/visibility/online olayları + Setup ekranına her dönüş + 10
// dakikalık periyodik tazeleme) güncelleniyor.
import { useEffect, useRef } from 'react';
import { fetchIncomingFriendRequests, subscribeMyOnlineGames } from '../lib/api';
import { fetchPendingLiveGameCounts } from '../utils/pendingLiveGames';

export function useAppIconBadge(
  userId: string | undefined,
  localSaveCount: number,
  isOnSetupScreen: boolean
): void {
  const friendCountRef = useRef(0);
  const liveCountRef = useRef(0);
  // Aşağıdaki [userId] effect'i içindeki refreshAll'a dışarıdan (Setup'a
  // dönüş effect'inden) erişebilmek için — `localSaveCount`'un App.tsx'teki
  // `refreshCloudSaves` aracılığıyla zaten yaptığı gibi, Canlı/arkadaşlık
  // kısmı da Setup ekranına her dönüşte tazelensin diye (tutarlılık).
  const refreshAllRef = useRef<() => void>(() => {});

  const applyBadge = () => {
    if (!('setAppBadge' in navigator)) return;
    const total = friendCountRef.current + liveCountRef.current + localSaveCount;
    try {
      if (total > 0) void navigator.setAppBadge(total);
      else void navigator.clearAppBadge();
    } catch {
      // Bazı tarayıcılarda/izin durumlarında reddedilebilir — yoksay.
    }
  };

  // localSaveCount değişince (parametre) de rozeti tazele.
  useEffect(() => {
    applyBadge();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [localSaveCount]);

  useEffect(() => {
    if (!userId) {
      friendCountRef.current = 0;
      liveCountRef.current = 0;
      refreshAllRef.current = () => {};
      applyBadge();
      return;
    }
    let cancelled = false;

    const refreshFriends = () => {
      fetchIncomingFriendRequests().then((rows) => {
        if (cancelled) return;
        friendCountRef.current = rows.length;
        applyBadge();
      });
    };

    const refreshLive = () => {
      fetchPendingLiveGameCounts().then(({ inviteCount, myTurnCount }) => {
        if (cancelled) return;
        liveCountRef.current = inviteCount + myTurnCount;
        applyBadge();
      });
    };

    const refreshAll = () => {
      refreshFriends();
      refreshLive();
    };
    refreshAllRef.current = refreshAll;

    refreshAll();
    const unsubscribe = subscribeMyOnlineGames(refreshAll);
    const onForeground = () => {
      if (document.visibilityState === 'visible') refreshAll();
    };
    document.addEventListener('visibilitychange', onForeground);
    window.addEventListener('focus', onForeground);
    window.addEventListener('online', onForeground);
    // Ekran açık kalıp hiçbir hamle/foreground/Realtime olayı gerçekleşmezse
    // (ör. sekme uzun süre öne alınmadan açık kalırsa) periyodik bir tazeleme.
    const intervalId = window.setInterval(refreshAll, 10 * 60 * 1000);
    return () => {
      cancelled = true;
      unsubscribe();
      document.removeEventListener('visibilitychange', onForeground);
      window.removeEventListener('focus', onForeground);
      window.removeEventListener('online', onForeground);
      window.clearInterval(intervalId);
      refreshAllRef.current = () => {};
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  // Setup ekranına her dönüşte (App.tsx zaten `cloudSaves`'i aynı geçişte
  // tazeliyor, dolayısıyla `localSaveCount` kendiliğinden güncel) Canlı
  // oyun/arkadaşlık kısmını da tazele — az önce oynanan bir hamle sırf
  // `online_game_states`'i değiştirdiğinden (yukarıdaki Realtime aboneliği
  // yalnızca `online_games`/`game_invites`'ı dinliyor) tek başına rozeti
  // güncellemiyordu; Setup'a dönüş artık ikisi için de ortak bir tazeleme
  // anı oluyor.
  useEffect(() => {
    if (isOnSetupScreen) refreshAllRef.current();
  }, [isOnSetupScreen]);
}
