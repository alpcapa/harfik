// Kelimeki — admin panelinin Üyeler tablosundan bir üyeye elle yazılan
// mesajı gönderen küçük compose modalı (bkz. AdminDashboard.tsx).
import { useState } from 'react';
import { Modal } from './Modal';
import { sendMemberMessage } from '../lib/api';

interface MemberMessageModalProps {
  toUserId: string;
  toEmail: string;
  toName: string;
  onClose: () => void;
  onSent?: () => void;
}

export function MemberMessageModal({ toUserId, toEmail, toName, onClose, onSent }: MemberMessageModalProps) {
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!subject.trim() || !message.trim()) return;
    setError(null);
    setBusy(true);
    try {
      await sendMemberMessage(toUserId, toEmail, toName, subject.trim(), message.trim());
      setSent(true);
      onSent?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';

  return (
    <Modal title="Mesaj Gönder" onClose={onClose}>
      {sent ? (
        <div className="flex flex-col items-center gap-3 py-4 text-center">
          <p className="text-sm text-text">Mesaj {toEmail} adresine gönderildi.</p>
          <button
            onClick={onClose}
            className="btn-raised bg-accent text-white rounded-md py-2.5 px-5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform"
          >
            Kapat
          </button>
        </div>
      ) : (
        <form onSubmit={submit} className="flex flex-col gap-3">
          <p className="text-xs text-muted font-mono">
            Alıcı: <span className="text-text">{toName} · {toEmail}</span>
          </p>
          <input
            className={inputCls}
            type="text"
            placeholder="Konu"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            maxLength={200}
            required
            autoFocus
          />
          <textarea
            className={`${inputCls} resize-none`}
            rows={6}
            placeholder="Mesajın"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            maxLength={5000}
            required
          />
          <p className="text-[10px] text-muted font-mono">
            Altına otomatik olarak "Saygılarımızla, Kelimeki Müşteri Hizmetleri" imzası eklenir.
          </p>
          {error && <p className="text-red text-xs font-mono">{error}</p>}
          <button
            type="submit"
            disabled={busy}
            className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            {busy ? '...' : 'Gönder'}
          </button>
        </form>
      )}
    </Modal>
  );
}
