// Kelimeki — herkese açık davet sayfası: /davet/:token
// Girişsiz de erişilebilir (get_friend_invite_info RPC'si) — henüz üye
// olmayan biri de linke tıklayıp burada kayıt olabilir. Bkz. main.tsx'teki
// path kontrolü ve CLAUDE.md "Arkadaşlık Sistemi" notu.
import { useEffect, useState } from 'react';
import { LoadingNote } from './LoadingNote';
import { useAuth } from '../hooks/useAuth';
import { acceptFriendInvite, fetchFriendInviteInfo } from '../lib/api';
import { storePendingInviteToken, takePendingInviteToken } from '../utils/friendInvite';
import { LogoMark } from './LogoMark';
import { AuthModal } from './AuthModal';

interface FriendInvitePageProps {
  token: string;
}

type Status = 'loading' | 'invalid' | 'ready' | 'accepting' | 'accepted' | 'error';

export function FriendInvitePage({ token }: FriendInvitePageProps) {
  const { user, loading: authLoading } = useAuth();
  const [inviterName, setInviterName] = useState<string | null>(null);
  const [status, setStatus] = useState<Status>('loading');
  const [authMode, setAuthMode] = useState<'login' | 'signup' | null>(null);

  // Sayfaya her düşüşte token'ı sakla — e-posta doğrulaması açıkken bir
  // kayıt, doğrulama linkine tıklanana kadar burada oturum açmaz ve o link
  // genelde uygulamanın köküne döner; App.tsx bu kuyruğu oradan da işleyebilir.
  useEffect(() => {
    storePendingInviteToken(token);
  }, [token]);

  useEffect(() => {
    let cancelled = false;
    void fetchFriendInviteInfo(token).then((name) => {
      if (cancelled) return;
      if (!name) {
        setStatus('invalid');
      } else {
        setInviterName(name);
        setStatus('ready');
      }
    });
    return () => {
      cancelled = true;
    };
  }, [token]);

  // Kullanıcı bu sayfadayken girişli hale gelirse (zaten girişliyse ya da
  // AuthModal ile giriş/kayıt tamamlarsa) daveti hemen işle.
  useEffect(() => {
    if (authLoading || !user || status !== 'ready') return;
    setStatus('accepting');
    acceptFriendInvite(token)
      .then(() => {
        takePendingInviteToken(); // App.tsx bunu bir daha işlemeye çalışmasın
        setStatus('accepted');
      })
      .catch(() => setStatus('error'));
  }, [authLoading, user, status, token]);

  return (
    <div className="min-h-screen bg-panel flex flex-col items-center px-4 py-8 gap-6">
      <a href="/" aria-label="Kelimeki anasayfa">
        <LogoMark height={44} />
      </a>

      <div className="w-full max-w-[360px] flex flex-col items-center gap-4 text-center">
        {status === 'loading' && <LoadingNote py="py-0" />}

        {status === 'invalid' && (
          <p className="text-muted text-xs font-mono max-w-[320px]">
            Bu davet linki geçersiz ya da artık kullanılamıyor.
          </p>
        )}

        {(status === 'ready' || status === 'accepting') && (
          <>
            <p className="text-sm text-text font-mono">
              <span className="font-bold text-accent">{inviterName}</span> seni Kelimeki'de arkadaş
              eklemek istiyor.
            </p>
            {user ? (
              <p className="text-xs text-muted font-mono">İşleniyor…</p>
            ) : (
              <div className="flex gap-2">
                <button
                  onClick={() => setAuthMode('login')}
                  className="px-5 py-3 rounded-md bg-panel border border-border text-text font-mono font-bold text-sm tracking-[0.5px] shadow-raised active:scale-95 transition-transform"
                >
                  Giriş Yap
                </button>
                <button
                  onClick={() => setAuthMode('signup')}
                  className="px-5 py-3 rounded-md bg-accent text-white font-mono font-bold text-sm tracking-[0.5px] shadow-raised active:scale-95 transition-transform"
                >
                  Kayıt Ol
                </button>
              </div>
            )}
          </>
        )}

        {status === 'accepted' && (
          <>
            <p className="text-sm text-text font-mono">
              <span className="font-bold text-accent">{inviterName}</span> ile artık arkadaşsınız!
            </p>
            <a
              href="/"
              className="px-6 py-3 rounded-md bg-accent text-white font-mono font-bold text-sm tracking-[0.5px] shadow-raised active:scale-95 transition-transform"
            >
              Kelimeki'ye Git
            </a>
          </>
        )}

        {status === 'error' && (
          <p className="text-red text-xs font-mono">
            Davet kabul edilirken bir hata oluştu, lütfen tekrar dene.
          </p>
        )}
      </div>

      {authMode && <AuthModal initialMode={authMode} onClose={() => setAuthMode(null)} />}
    </div>
  );
}
