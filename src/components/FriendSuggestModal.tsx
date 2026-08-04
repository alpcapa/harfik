// Kelimeki — Bir Canlı oyun davetini kabul ettikten sonra, o oyundaki henüz
// arkadaş olunmayan diğer katılımcılara toplu arkadaşlık isteği gönderme
// önerisi. Karşılıklı istekler mevcut `handle_friend_request_insert`
// trigger'ı (friends_system migration'ı) sayesinde otomatik kabul olur.
import { useState } from 'react';
import { createPortal } from 'react-dom';
import { useModalA11y } from '../hooks/useModalA11y';
import { sendFriendRequest } from '../lib/api';
import { trCompare } from '../utils/turkish';
import { Avatar } from './Avatar';

interface Candidate {
  user_id: string;
  name?: string;
  avatar_url?: string | null;
}

interface FriendSuggestModalProps {
  candidates: Candidate[];
  onDone: () => void;
}

function CheckMark({ checked }: { checked: boolean }) {
  return (
    <span
      className={[
        'w-4 h-4 rounded border-2 shrink-0 flex items-center justify-center text-[10px] leading-none',
        checked ? 'bg-accent border-accent text-white' : 'bg-bg border-muted text-transparent',
      ].join(' ')}
    >
      ✓
    </span>
  );
}

export function FriendSuggestModal({ candidates, onDone }: FriendSuggestModalProps) {
  const sortedCandidates = [...candidates].sort((a, b) => trCompare(a.name ?? '', b.name ?? ''));
  const [selected, setSelected] = useState<Set<string>>(new Set(candidates.map((c) => c.user_id)));
  const [stage, setStage] = useState<'select' | 'done'>('select');
  const [busy, setBusy] = useState(false);
  const ref = useModalA11y(true, onDone);

  const toggle = (id: string) => {
    setSelected((s) => {
      const next = new Set(s);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleContinue = async () => {
    if (selected.size === 0) {
      onDone();
      return;
    }
    setBusy(true);
    await Promise.all(
      Array.from(selected).map((id) =>
        sendFriendRequest(id).catch((err) => {
          // Zaten bekleyen bir istek varsa (unique violation) sessizce yoksay.
          console.error('[Kelimeki] arkadaşlık isteği hatası:', err);
        }),
      ),
    );
    setBusy(false);
    setStage('done');
  };

  return createPortal(
    <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label="Arkadaş ekle"
        tabIndex={-1}
        className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
      >
        {stage === 'select' ? (
          <>
            <p className="text-sm text-text font-sans leading-relaxed">
              Bu kişileri arkadaşın olarak eklemek ister misin?
            </p>
            <div className="flex flex-col gap-1.5">
              {sortedCandidates.map((c) => (
                <button
                  key={c.user_id}
                  type="button"
                  onClick={() => toggle(c.user_id)}
                  className="flex items-center gap-2.5 bg-bg rounded-md px-2.5 py-2 text-left"
                >
                  <Avatar url={c.avatar_url} name={c.name} size={28} />
                  <span className="flex-1 min-w-0 text-sm font-bold text-text truncate">
                    {c.name ?? 'Oyuncu'}
                  </span>
                  <CheckMark checked={selected.has(c.user_id)} />
                </button>
              ))}
            </div>
            <button
              onClick={handleContinue}
              disabled={busy}
              className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              {busy ? '…' : 'Devam'}
            </button>
          </>
        ) : (
          <>
            <p className="text-sm text-text font-sans leading-relaxed">Arkadaşlık davetiniz iletilmiştir.</p>
            <button
              onClick={onDone}
              className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Tamam
            </button>
          </>
        )}
      </div>
    </div>,
    document.body,
  );
}
