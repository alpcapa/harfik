// Kelimeki — sağ üst köşedeki hesap menüsü.
// Oturum yoksa "Giriş / Kayıt" düğmesi; oturum varsa profil küçük resmi ve
// açılır menü (Hesap Ayarları, Skor Kartı, Çıkış) gösterir.
// Yalnızca Supabase yapılandırıldığında görünür.
import { lazy, Suspense, useEffect, useRef, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import {
  signOut,
  fetchMyLeaderboardRank,
  fetchIncomingFriendRequests,
  fetchAdminPendingCount,
} from '../lib/api';
import type { MyLeaderboardRank } from '../lib/database.types';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { swallowNextClick } from '../utils/ghostClick';
import { CountBadge } from './CountBadge';
import { ScoreCard } from './ScoreCard';
import { AccountSettingsModal } from './AccountSettingsModal';
import { HelpModal } from './HelpModal';
import { Leaderboard } from './Leaderboard';
const AdminDashboard = lazy(() => import('./AdminDashboard').then((m) => ({ default: m.AdminDashboard })));
import { KLigMark } from './KLigMark';
import { FriendsModal } from './FriendsModal';
import { RankSeal } from './RankSeal';
import { tierFor } from '../utils/leagueRank';

type ActiveModal = 'auth' | 'account' | 'score' | 'help' | 'league' | 'admin' | 'friends' | null;

// GameHeader'daki skor kutularıyla aynı akıcı ölçek (bkz. GameHeader.tsx'teki
// PLAYER_BOX_WIDTH vb. yorumu, 465'in neden 430 değil seçildiğine dair
// not dahil) — Giriş butonu header'da onlarla aynı satırda olduğundan
// aynı 375px→465px geçişiyle küçülüp büyümesi gerekiyor. Bu bileşen
// Setup ekranında da tek başına kullanıldığından (App.tsx) oradaki
// görünümü de hafifçe etkiler — orada kalabalık olmadığından zararsız.
const GIRIS_FONT_SIZE = 'clamp(8px, calc(-4.5px + 3.33vw), 11px)';
const GIRIS_PADDING_X = 'clamp(6px, calc(-2.33px + 2.22vw), 8px)';
const GIRIS_PADDING_Y = 'clamp(8.7px, calc(-5.05px + 3.67vw), 12px)';

export function UserMenu() {
  const { user, profile, configured, loading, profileLoading } = useAuth();
  const [open, setOpen] = useState(false);
  const [modal, setModal] = useState<ActiveModal>(null);
  const [myRank, setMyRank] = useState<MyLeaderboardRank | null>(null);
  const [incomingRequestCount, setIncomingRequestCount] = useState(0);
  const [adminPendingCount, setAdminPendingCount] = useState(0);
  const wrapRef = useRef<HTMLDivElement>(null);
  const isAdmin = !!profile?.is_admin;

  // Hızlı hesap değişiminde (ör. çıkış yapıp başka bir hesapla giriş) eski
  // kullanıcının isteği geç dönüp yeni kullanıcının verisini ezebilirdi —
  // useAppIconBadge'deki aynı "bu hâlâ güncel istek mi" kilidini kullanıyor.
  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    fetchMyLeaderboardRank(user.id).then((r) => {
      if (!cancelled) setMyRank(r);
    });
    return () => {
      cancelled = true;
    };
  }, [user]);

  const refreshIncomingRequestCount = () => {
    if (!user) return;
    fetchIncomingFriendRequests().then((r) => setIncomingRequestCount(r.length));
  };

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    fetchIncomingFriendRequests().then((r) => {
      if (!cancelled) setIncomingRequestCount(r.length);
    });
    return () => {
      cancelled = true;
    };
    // Yalnızca kullanıcı değişince tazelenir — arkadaşlıkla ilgisi olmayan
    // her modal açılış/kapanışında (`modal` değişimi) yeniden çekmek
    // gereksizdi. FriendsModal kapanınca (isteğe yanıt verilmiş olabilir)
    // `refreshIncomingRequestCount` ayrıca çağrılıyor (aşağıda).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user]);

  // Admin'i bekleyen okunmamış geri bildirim + şikayet sayısı — "Admin
  // Paneli" satırının yanındaki kırmızı rozet için. Arkadaşlık isteği
  // sayacıyla aynı desen: yalnızca kullanıcı/rol değişince çekilir (ne
  // `feedback` ne `online_game_chat_reports` Realtime publication'ında,
  // ayrı bir abonelik bilinçli olarak eklenmedi), panel kapanınca ayrıca
  // tazelenir — admin içeride okundu işaretlemiş olabilir.
  const refreshAdminPendingCount = () => {
    if (!isAdmin) return;
    fetchAdminPendingCount().then(setAdminPendingCount);
  };

  useEffect(() => {
    // Admin olmayan için çağrılmamalı — bkz. fetchAdminPendingCount'un
    // dokümantasyonundaki uyarı (şikayet RLS'i kişinin kendi şikayetlerini
    // de görmesine izin veriyor).
    if (!isAdmin) {
      setAdminPendingCount(0);
      return;
    }
    let cancelled = false;
    fetchAdminPendingCount().then((n) => {
      if (!cancelled) setAdminPendingCount(n);
    });
    return () => {
      cancelled = true;
    };
  }, [user, isAdmin]);

  // Dışarı tıklayınca / Esc ile menüyü kapat.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
        // Menüyü kapatan dokunuş YALNIZCA kapatmalı — aynı jestin click'i
        // altındaki öğeye de düşüyor ve oyun ekranında bu, menüyü kapatmak
        // için tahtaya dokunan kullanıcıya istemediği bir taş yerleştirmesi
        // olarak dönüyordu (bkz. `src/utils/ghostClick.ts`).
        swallowNextClick();
      }
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (!configured) return null;

  // Profil henüz (ilk kez) çekilmediyse e-postaya düşmüyoruz — aksi halde
  // profil gelene kadar bir anlık e-posta bazlı baş harflere (ör. "AC")
  // düşüp hemen gerçek takma adın baş harfleriyle (ör. "AL") değişiyordu.
  const name =
    profile?.display_name ||
    profile?.username ||
    [profile?.first_name, profile?.last_name].filter(Boolean).join(' ').trim() ||
    (user?.email && !profileLoading ? user.email : null) ||
    'Hesabım';
  const identityLoading = loading || (!!user && profileLoading);

  // ── Oturum yok: Giriş / Kayıt düğmesi ──────────────────────────────────────
  if (!loading && !user) {
    return (
      <>
        <button
          onClick={() => setModal('auth')}
          className="shrink-0 btn-raised font-mono uppercase tracking-[0.5px] rounded-md border bg-accent border-accent text-white font-bold leading-none active:scale-[0.97] transition-transform"
          style={{
            fontSize: GIRIS_FONT_SIZE,
            paddingLeft: GIRIS_PADDING_X,
            paddingRight: GIRIS_PADDING_X,
            paddingTop: GIRIS_PADDING_Y,
            paddingBottom: GIRIS_PADDING_Y,
          }}
        >
          Giriş
        </button>
        {modal === 'auth' && <AuthModal onClose={() => setModal(null)} />}
      </>
    );
  }

  const item =
    'w-full flex items-center gap-2.5 px-3 py-2.5 text-left text-xs font-mono text-text hover:bg-bg transition-colors';

  return (
    <>
      <div className="relative shrink-0" ref={wrapRef}>
        <button
          onClick={() => setOpen((v) => !v)}
          disabled={identityLoading}
          // `aria-label` DURUYOR (ekran okuyucu için gerekli); hover/uzun
          // basma ipucu veren `title` ise kullanıcı isteğiyle kaldırıldı
          // (9 Ağustos 2026) — mobil porttaki `tooltip` de aynı anda.
          aria-label="Hesap menüsü"
          aria-expanded={open}
          // `flex` ŞART, kozmetik değil: `<button>` varsayılan olarak
          // inline-block ve fotoğraflı avatar bir `<img>` (inline-level) —
          // araya bir satır kutusu girip ALTINA taban çizgisi boşluğu
          // ekliyor, yani buton 32px değil 39px oluyor ve resim o kutunun
          // ÜSTÜNE yaslanıyor. Kabı `items-center` ile ortalayan header
          // 39px'lik kutuyu ortaladığından fotoğraf skor kutularının
          // merkezinden 3.5px YUKARIDA kalıyordu (ölçüldü: derlenmiş CSS +
          // Chromium, 17 Ağustos 2026 — kullanıcı cihazda bildirdi, mobil
          // portta hiç yaşanmıyor). `flex` satır kutusunu tamamen kaldırıyor.
          // ÖLÇÜM, "hangi avatar" sorusunun cevabını da verdi: yalnızca
          // profil FOTOĞRAFI olan hesaplarda görünüyor. Baş harf yedeği
          // (`display:flex`, blok seviyesi) ve rozetli sarmalayıcı
          // (`inline-flex`, taban çizgisi metnin kendi taban çizgisi) 32px
          // kalıyor — `<img>`in taban çizgisi ise ALT KENARI olduğundan
          // strut'ın tüm iniş payı (7px) altına ekleniyor.
          // `tap-expand`: avatar 32px çizilir, DOKUNMA kutusu Material
          // asgarisi olan 48'e bir `::after` sözde-elemanla çıkar — düzen
          // (header yüksekliği, `gap-2` aralığı) hiç etkilenmez. Kullanıcı
          // bu hedefi mobil uygulamada istemişti (*"Avatar'da tıklamada
          // sorun var, yine üstüne tıklaman lazım biraz"*, 24 Ağustos
          // 2026); portta sözde-eleman olmadığından orada bedeli header'ın
          // uzaması (bkz. `account_button.dart` → `TapTarget`).

          className="tap-expand rounded-full flex items-center justify-center active:scale-95 transition-transform ring-offset-2 focus:outline-none disabled:cursor-not-allowed"
        >
          {identityLoading ? (
            <span className="w-8 h-8 rounded-full bg-panel border border-border flex items-center justify-center text-muted text-[10px] font-mono">
              …
            </span>
          ) : (
            /* Menü kapalıyken de fark edilsin diye avatardaki rozet, menü
               içindeki rozetlerin TOPLAMIDIR — arkadaşlık isteği + (admin
               ise) bekleyen geri bildirim/şikayet. Bu, `CountBadge`'in
               "kapsayanın rozeti kapsananların toplamıdır" kuralının aynen
               uygulanması; 16 Ağustos 2026'ya kadar sayısız bir noktaydı ve
               kullanıcılar fark etmiyordu. */
            <Avatar
              url={profile?.avatar_url}
              name={name}
              size={32}
              badgeCount={incomingRequestCount + adminPendingCount}
            />
          )}
        </button>

        {open && (
          <div className="absolute right-0 top-full mt-2 w-56 bg-panel border border-[#B8C2D1] rounded-xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] overflow-hidden z-[160]">
            <div className="flex items-center gap-2.5 px-3 py-3 border-b border-border">
              <Avatar url={profile?.avatar_url} name={name} size={36} />
              <div className="min-w-0">
                {/* Rütbe mührü — k-lig satırındaki `myRank.total_score`in
                    ta kendisinden türetiliyor, ek bir sorgu YOK. Bu boyda
                    `RankSeal` kompakt çizer (halkasız, büyük harf); ölçü
                    k-lig listesindeki 18px ile aynı. */}
                <div className="flex items-center gap-1 min-w-0">
                  <span className="text-sm font-bold text-text truncate">{name}</span>
                  {myRank && (
                    <RankSeal tier={tierFor(myRank.total_score)} size={18} className="shrink-0" />
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setModal('league');
                    setOpen(false);
                  }}
                  className="flex items-center gap-2 text-[10px] font-mono text-left truncate active:opacity-70 transition-opacity"
                >
                  <KLigMark height={13} className="inline-block relative top-[1px] shrink-0" />
                  <span className="text-xs font-bold text-accent truncate">
                    {myRank && (
                      <>
                        #{myRank.rank}
                        <span className="mx-0.5">·</span>
                        {myRank.total_score.toLocaleString('tr-TR')}
                        <span className="font-normal text-muted"> puan</span>
                      </>
                    )}
                  </span>
                </button>
              </div>
            </div>

            <button
              className={item}
              onClick={() => {
                setModal('friends');
                setOpen(false);
              }}
            >
              <span aria-hidden>👥</span> Arkadaşlar
              {incomingRequestCount > 0 && (
                <CountBadge count={incomingRequestCount} className="ml-auto" />
              )}
            </button>
            <button
              className={item}
              onClick={() => {
                setModal('score');
                setOpen(false);
              }}
            >
              <span aria-hidden>📊</span> Skor Kartı
            </button>
            <button
              className={item}
              onClick={() => {
                setModal('help');
                setOpen(false);
              }}
            >
              <span aria-hidden>❓</span> Nasıl Oynanır?
            </button>
            <button
              className={item}
              onClick={() => {
                setModal('account');
                setOpen(false);
              }}
            >
              <span aria-hidden>⚙️</span> Hesap Ayarları
            </button>

            {isAdmin && (
              <button
                className={`${item} border-t border-border`}
                onClick={() => {
                  setModal('admin');
                  setOpen(false);
                }}
              >
                <span aria-hidden>🛡️</span> Admin Paneli
                {adminPendingCount > 0 && (
                  <CountBadge count={adminPendingCount} className="ml-auto" />
                )}
              </button>
            )}

            <button
              className={`${item} border-t border-border hover:text-red`}
              onClick={async () => {
                setOpen(false);
                await signOut();
              }}
            >
              <span aria-hidden>🚪</span> Çıkış Yap
            </button>
          </div>
        )}
      </div>

      {modal === 'account' && (
        <AccountSettingsModal onClose={() => setModal(null)} />
      )}
      {modal === 'score' && <ScoreCard onClose={() => setModal(null)} />}
      {modal === 'league' && <Leaderboard onClose={() => setModal(null)} />}
      {modal === 'help' && (
        <HelpModal onClose={() => setModal(null)} />
      )}
      {modal === 'admin' && (
        <Suspense fallback={null}>
        <AdminDashboard
          onClose={() => {
            setModal(null);
            // İçeride mesaj/şikayet okundu işaretlenmiş olabilir —
            // FriendsModal kapanışındaki aynı desen.
            refreshAdminPendingCount();
          }}
        />
        </Suspense>
      )}
      {modal === 'friends' && (
        <FriendsModal
          onClose={() => {
            setModal(null);
            refreshIncomingRequestCount();
          }}
        />
      )}
    </>
  );
}
