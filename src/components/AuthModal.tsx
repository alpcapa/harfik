// Harfik — giriş / kayıt ekranı
import { useState } from 'react';
import { Modal } from './Modal';
import { signIn, signUp } from '../lib/api';
import { useAuth } from '../hooks/useAuth';

interface AuthModalProps {
  onClose: () => void;
}

type Mode = 'login' | 'signup';

export function AuthModal({ onClose }: AuthModalProps) {
  const { refreshProfile } = useAuth();
  const [mode, setMode] = useState<Mode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

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
      } else {
        const { data, error } = await signUp(email, password, username || undefined);
        if (error) throw error;
        if (data.session) {
          await refreshProfile();
          onClose();
        } else {
          // E-posta doğrulaması açıksa oturum hemen oluşmaz.
          setInfo('Hesap oluşturuldu. E-postanı doğrulayıp giriş yap.');
          setMode('login');
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Bir hata oluştu.');
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';

  return (
    <Modal title={mode === 'login' ? 'Giriş' : 'Kayıt'} onClose={onClose}>
      <form onSubmit={submit} className="flex flex-col gap-3">
        {mode === 'signup' && (
          <input
            className={inputCls}
            placeholder="Kullanıcı adı"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
          />
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

        {error && <p className="text-red text-xs font-mono">{error}</p>}
        {info && <p className="text-gold text-xs font-mono">{info}</p>}

        <button
          type="submit"
          disabled={busy}
          className="bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
        >
          {busy ? '...' : mode === 'login' ? 'Giriş Yap' : 'Kayıt Ol'}
        </button>
      </form>

      <button
        onClick={() => {
          setMode(mode === 'login' ? 'signup' : 'login');
          setError(null);
          setInfo(null);
        }}
        className="mt-3 w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
      >
        {mode === 'login'
          ? 'Hesabın yok mu? Kayıt ol'
          : 'Zaten hesabın var mı? Giriş yap'}
      </button>
    </Modal>
  );
}
