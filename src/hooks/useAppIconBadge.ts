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
// yalnızca uygulama açıkken/arka plan sekmesindeyken tazelenir.
import { useEffect, useRef } from 'react';
import { fetchIncomingFriendRequests, fetchOnlineGameTurns, listMyOnlineGames, subscribeMyOnlineGames } from '../lib/api';

export function useAppIconBadge(userId: string | undefined, localSaveCount: number): void {
  const friendCountRef = useRef(0);
  const liveCountRef = useRef(0);

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
      listMyOnlineGames().then((rows) => {
        if (cancelled) return;
        const inviteCount = rows.filter(
          (g) => g.my_role === 'invitee' && g.my_invite_status === 'pending'
        ).length;
        const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
        if (activeIds.length === 0) {
          liveCountRef.current = inviteCount;
          applyBadge();
          return;
        }
        fetchOnlineGameTurns(activeIds).then((turns) => {
          if (cancelled) return;
          const myTurnCount = rows.filter((g) => {
            if (g.status !== 'active') return false;
            const idx = g.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
            return turns[g.id] === idx;
          }).length;
          liveCountRef.current = inviteCount + myTurnCount;
          applyBadge();
        });
      });
    };

    const refreshAll = () => {
      refreshFriends();
      refreshLive();
    };

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
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);
}
