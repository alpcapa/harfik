// Kelimeki — şifre sıfırlama bağlantısı tıklanınca açılan "yeni şifre belirle" ekranı
import { useState } from 'react';
import { Modal } from './Modal';
import { setNewPassword, friendlyAuthMessage } from '../lib/api';

interface ResetPasswordModalProps {
  onDone: () => void;
}

export function ResetPasswordModal({ onDone }: ResetPasswordModalProps) {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password.length < 6) {
      setError('Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (password !== confirm) {
      setError('Şifreler eşleşmiyor.');
      return;
    }
    setBusy(true);
    try {
      const { error } = await setNewPassword(password);
      if (error) throw error;
      setDone(true);
    } catch (err) {
      const msg = friendlyAuthMessage(err) ?? (err instanceof Error ? err.message : (err as { message?: string })?.message);
      setError(msg || 'Bir hata oluştu.');
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';

  // Sıfırlama bağlantısı tıklandığında zaten bir recovery oturumu (useAuth'taki
  // `user`) açılmış oluyor — burada ayrıca bir "giriş yap" adımı yok, "Kapat"a
  // basılınca onDone() recovery ekranını kapatır ve uygulama o mevcut oturumla
  // (giriş yapılmış olarak) render edilir.
  if (done) {
    return (
      <Modal title="Yeni Şifre Belirle" onClose={onDone}>
        <div className="flex flex-col gap-3">
          <p className="text-green text-sm font-mono">Şifren başarıyla değiştirildi.</p>
          <button
            type="button"
            onClick={onDone}
            className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform"
          >
            Kapat
          </button>
        </div>
      </Modal>
    );
  }

  return (
    <Modal title="Yeni Şifre Belirle" onClose={onDone}>
      <form onSubmit={submit} className="flex flex-col gap-3">
        <p className="text-xs text-muted font-mono">
          Hesabın için yeni bir şifre belirle.
        </p>
        <input
          className={inputCls}
          type="password"
          placeholder="Yeni şifre"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={6}
          autoComplete="new-password"
          autoFocus
        />
        <input
          className={inputCls}
          type="password"
          placeholder="Yeni şifre (tekrar)"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          required
          autoComplete="new-password"
        />

        {error && <p className="text-red text-xs font-mono">{error}</p>}

        <button
          type="submit"
          disabled={busy}
          className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
        >
          {busy ? '...' : 'Şifreyi Kaydet'}
        </button>
      </form>
    </Modal>
  );
}
