// Harfik — giriş / kayıt ekranı
import { useState } from 'react';
import { Modal } from './Modal';
import { signIn, signUp, sendPasswordReset } from '../lib/api';
import { useAuth } from '../hooks/useAuth';

interface AuthModalProps {
  onClose: () => void;
}

type Mode = 'login' | 'signup' | 'forgot';

export function AuthModal({ onClose }: AuthModalProps) {
  const { refreshProfile } = useAuth();
  const [mode, setMode] = useState<Mode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [nickname, setNickname] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const switchMode = (next: Mode) => {
    setMode(next);
    setError(null);
    setInfo(null);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setBusy(true);
    try {
      if (mode === 'login') {
        const { error } = await signIn(email, password);
        if (error) throw error;
        await refreshProfile();
        onClose();
      } else if (mode === 'forgot') {
        const { error } = await sendPasswordReset(email);
        if (error) throw error;
        setInfo('Şifre sıfırlama bağlantısı e-postana gönderildi.');
      } else {
        if (!firstName.trim()) throw new Error('Ad zorunludur.');
        if (!lastName.trim()) throw new Error('Soyad zorunludur.');
        const { data, error } = await signUp(
          email,
          password,
          firstName.trim(),
          lastName.trim(),
          nickname.trim() || undefined,
        );
        if (error) throw error;
        if (data.session) {
          await refreshProfile();
          onClose();
        } else {
          setInfo('Hesap oluşturuldu. E-postanı doğrulayıp giriş yap.');
          switchMode('login');
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : (err as { message?: string })?.message;
      setError(msg || 'Bir hata oluştu.');
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';

  const title = mode === 'login' ? 'Giriş' : mode === 'signup' ? 'Kayıt' : 'Şifremi Unuttum';

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={submit} className="flex flex-col gap-3">
        {mode === 'signup' && (
          <>
            <div className="flex gap-2">
              <input
                className={inputCls}
                placeholder="Ad"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                autoComplete="given-name"
                required
              />
              <input
                className={inputCls}
                placeholder="Soyad"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                autoComplete="family-name"
                required
              />
            </div>
            <input
              className={inputCls}
              placeholder="Takma isim (isteğe bağlı)"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              autoComplete="nickname"
            />
          </>
        )}

        <input
          className={inputCls}
          type="email"
          placeholder="E-posta"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
        />

        {mode !== 'forgot' && (
          <input
            className={inputCls}
            type="password"
            placeholder="Şifre"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={6}
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
          />
        )}

        {mode === 'forgot' && (
          <p className="text-xs text-muted font-mono">
            E-posta adresini gir, sıfırlama bağlantısı gönderelim.
          </p>
        )}

        {error && <p className="text-red text-xs font-mono">{error}</p>}
        {info && <p className="text-gold text-xs font-mono">{info}</p>}

        <button
          type="submit"
          disabled={busy}
          className="bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
        >
          {busy
            ? '...'
            : mode === 'login'
              ? 'Giriş Yap'
              : mode === 'signup'
                ? 'Kayıt Ol'
                : 'Bağlantı Gönder'}
        </button>
      </form>

      <div className="mt-3 flex flex-col gap-1.5">
        {mode === 'login' && (
          <>
            <button
              onClick={() => switchMode('forgot')}
              className="w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
            >
              Şifremi unuttum
            </button>
            <button
              onClick={() => switchMode('signup')}
              className="w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
            >
              Hesabın yok mu? Kayıt ol
            </button>
          </>
        )}
        {mode === 'signup' && (
          <button
            onClick={() => switchMode('login')}
            className="w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
          >
            Zaten hesabın var mı? Giriş yap
          </button>
        )}
        {mode === 'forgot' && (
          <button
            onClick={() => switchMode('login')}
            className="w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
          >
            Giriş ekranına dön
          </button>
        )}
      </div>
    </Modal>
  );
}
