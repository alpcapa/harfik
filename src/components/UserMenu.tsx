// Kelimeki — sağ üst köşedeki hesap menüsü.
// Oturum yoksa "Giriş / Kayıt" düğmesi; oturum varsa profil küçük resmi ve
// açılır menü (Hesap Ayarları, Skor Kartı, Çıkış) gösterir.
// Yalnızca Supabase yapılandırıldığında görünür.
import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { signOut, fetchMyLeaderboardRank, fetchIncomingFriendRequests } from '../lib/api';
import type { MyLeaderboardRank } from '../lib/database.types';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { ScoreCard } from './ScoreCard';
import { AccountSettingsModal } from './AccountSettingsModal';
import { HelpModal } from './HelpModal';
import { Leaderboard } from './Leaderboard';
import { AdminDashboard } from './AdminDashboard';
import { FriendsModal } from './FriendsModal';

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
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!user) return;
    fetchMyLeaderboardRank(user.id).then(setMyRank);
  }, [user]);

  useEffect(() => {
    if (!user) return;
    fetchIncomingFriendRequests().then((r) => setIncomingRequestCount(r.length));
  }, [user, modal]);

  // Dışarı tıklayınca / Esc ile menüyü kapat.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node))
        setOpen(false);
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
          aria-label="Hesap menüsü"
          aria-expanded={open}
          className="rounded-full active:scale-95 transition-transform ring-offset-2 focus:outline-none"
        >
          {identityLoading ? (
            <span className="w-8 h-8 rounded-full bg-panel border border-border flex items-center justify-center text-muted text-[10px] font-mono">
              …
            </span>
          ) : (
            <Avatar url={profile?.avatar_url} name={name} size={32} dot={incomingRequestCount > 0} />
          )}
        </button>

        {open && (
          <div className="absolute right-0 top-full mt-2 w-56 bg-panel border border-[#B8C2D1] rounded-xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] overflow-hidden z-[160]">
            <div className="flex items-center gap-2.5 px-3 py-3 border-b border-border">
              <Avatar url={profile?.avatar_url} name={name} size={36} />
              <div className="min-w-0">
                <div className="text-sm font-bold text-text truncate">{name}</div>
                <button
                  type="button"
                  onClick={() => {
                    setModal('league');
                    setOpen(false);
                  }}
                  className="flex items-center gap-1 text-[10px] font-mono text-left truncate active:opacity-70 transition-opacity"
                >
                  <span className="text-muted truncate">
                    {myRank
                      ? `#${myRank.rank} · ${myRank.total_score.toLocaleString('tr-TR')} puan`
                      : 'Sanal Lig'}
                  </span>
                  <span className="w-3 h-3 rounded-full border border-accent text-accent flex items-center justify-center text-[8px] leading-none font-bold shrink-0">
                    ?
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
                <span className="ml-auto min-w-[16px] h-4 px-1 rounded-full bg-red text-white text-[9px] font-bold flex items-center justify-center leading-none">
                  {incomingRequestCount}
                </span>
              )}
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

            {profile?.is_admin && (
              <button
                className={`${item} border-t border-border`}
                onClick={() => {
                  setModal('admin');
                  setOpen(false);
                }}
              >
                <span aria-hidden>🛡️</span> Admin Paneli
              </button>
            )}

            <button
              className={`${item} border-t border-border hover:text-red`}
              onClick={async () => {
                setOpen(false);
                await signOut();
              }}
            >
              <span aria-hidden>↩</span> Çıkış Yap
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
      {modal === 'admin' && <AdminDashboard onClose={() => setModal(null)} />}
      {modal === 'friends' && <FriendsModal onClose={() => setModal(null)} />}
    </>
  );
}
