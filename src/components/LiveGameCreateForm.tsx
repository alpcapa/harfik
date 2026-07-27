// Kelimeki — Canlı oyun kurulumu: arkadaş seçip davet gönderme (Faz 2, 4. adım).
// Kural (bkz. CLAUDE.md / online_game_ai_slot_rule migration'ı): 2 kişilikte
// Yapay Zeka'ya hiç izin yok (iki koltuk da insan); 4 kişilikte yalnızca
// 4. koltuk Yapay Zeka olabilir, en az 2 arkadaş seçilmesi zorunlu. 2 arkadaş
// seçiliyken "Davet Gönder"e basınca önce bir onay sorulur ("4. koltuk Yapay
// Zeka ile doldurulacak, tamam mı?") — Hayır denirse Yapay Zeka bir kez daha
// sorulmasın diye normal bir liste satırı olarak kalıcı hâle gelir.
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { useAuth } from '../hooks/useAuth';
import { useModalA11y } from '../hooks/useModalA11y';
import { createOnlineGame, fetchFriends } from '../lib/api';
import type { FriendRow, OnlineGameSlot } from '../lib/database.types';
import { Avatar } from './Avatar';
import { FriendsModal } from './FriendsModal';

interface LiveGameCreateFormProps {
  onCancel: () => void;
  onCreated: () => void;
}

const toggleBtnCls = (active: boolean) =>
  [
    'flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97]',
    active
      ? 'btn-raised bg-accent text-white border-accent'
      : 'btn-raised-neutral bg-panel text-text border-border',
  ].join(' ');

function CheckMark({ checked }: { checked: boolean }) {
  return (
    <span
      className={[
        'w-4 h-4 rounded border shrink-0 flex items-center justify-center text-[10px] leading-none',
        checked ? 'bg-accent border-accent text-white' : 'border-border text-transparent',
      ].join(' ')}
    >
      ✓
    </span>
  );
}

export function LiveGameCreateForm({ onCancel, onCreated }: LiveGameCreateFormProps) {
  const { user } = useAuth();
  const [playerCount, setPlayerCount] = useState<2 | 4>(2);
  const [friends, setFriends] = useState<FriendRow[] | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [showAiRow, setShowAiRow] = useState(false);
  const [aiSelected, setAiSelected] = useState(false);
  const [showAiConfirm, setShowAiConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showFriendsModal, setShowFriendsModal] = useState(false);

  const aiConfirmRef = useModalA11y(showAiConfirm, () => setShowAiConfirm(false));

  const reloadFriends = () => {
    fetchFriends().then(setFriends);
  };

  useEffect(() => {
    reloadFriends();
  }, []);

  // 2↔4 arası kural tamamen farklı (YZ izni yok / var) — sekme değişince
  // seçimleri sıfırlıyoruz ki eski bir seçim yeni kuralda geçersiz kalmasın.
  useEffect(() => {
    setSelected([]);
    setShowAiRow(false);
    setAiSelected(false);
  }, [playerCount]);

  const toggleFriend = (friendId: string) => {
    if (playerCount === 2) {
      setSelected((s) => (s.includes(friendId) ? [] : [friendId]));
      return;
    }
    setSelected((s) => {
      if (s.includes(friendId)) return s.filter((id) => id !== friendId);
      const cap = aiSelected ? 2 : 3; // YZ koltuğu ayrılmışsa insan için yalnızca 2 yer kalır
      if (s.length >= cap) return s;
      return [...s, friendId];
    });
  };

  const canSubmit = playerCount === 2 ? selected.length === 1 : selected.length >= 2;

  const submit = async (withAiLastSlot: boolean) => {
    if (!user) return;
    setBusy(true);
    setError(null);
    try {
      const slots: OnlineGameSlot[] = [
        { type: 'human', user_id: user.id },
        ...selected.map((id) => ({ type: 'human' as const, user_id: id })),
        ...(withAiLastSlot ? [{ type: 'ai' as const }] : []),
      ];
      await createOnlineGame(playerCount, slots);
      onCreated();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Davet gönderilemedi.');
    } finally {
      setBusy(false);
    }
  };

  const handleSubmit = () => {
    if (playerCount === 2 || selected.length === 3) {
      void submit(false);
      return;
    }
    // playerCount === 4 && selected.length === 2
    if (aiSelected) {
      void submit(true);
      return;
    }
    setShowAiConfirm(true);
  };

  return (
    <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
      {showFriendsModal && (
        <FriendsModal
          initialTab="search"
          onClose={() => {
            setShowFriendsModal(false);
            reloadFriends();
          }}
        />
      )}
      <button
        onClick={onCancel}
        className="self-start text-xs font-mono text-muted hover:text-text active:opacity-70 transition-opacity"
      >
        ← Geri
      </button>

      <div className="flex flex-col gap-2">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Oyuncu Sayısı
        </div>
        <div className="flex gap-2">
          {([2, 4] as const).map((n) => (
            <button key={n} onClick={() => setPlayerCount(n)} className={toggleBtnCls(playerCount === n)}>
              {n} Oyunculu
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-2">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          {playerCount === 2 ? 'Arkadaşını Seç' : `Arkadaşlarını Seç (${selected.length}/3)`}
        </div>
        <div className="flex flex-col gap-1.5">
          {friends === null ? (
            <p className="text-muted text-xs font-mono py-4 text-center">Yükleniyor…</p>
          ) : friends.length === 0 ? (
            <div className="flex flex-col items-center gap-2.5 py-4">
              <p className="text-muted text-xs font-mono text-center">Henüz arkadaşın yok.</p>
              <button
                type="button"
                onClick={() => setShowFriendsModal(true)}
                className="btn-raised bg-accent text-white rounded-md py-2 px-4 text-[11px] font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Arkadaşlar'ı Aç
              </button>
            </div>
          ) : (
            friends.map((f) => {
              const isSelected = selected.includes(f.friend_id);
              return (
                <button
                  key={f.friend_id}
                  type="button"
                  onClick={() => toggleFriend(f.friend_id)}
                  className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel text-left transition-transform active:scale-[0.99]"
                >
                  <Avatar url={f.avatar_url} name={f.name} size={28} />
                  <span className="flex-1 min-w-0 text-sm font-bold text-text truncate">{f.name}</span>
                  <CheckMark checked={isSelected} />
                </button>
              );
            })
          )}
          {playerCount === 4 && showAiRow && (
            <button
              type="button"
              onClick={() => setAiSelected((v) => !v)}
              className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel text-left transition-transform active:scale-[0.99]"
            >
              <span className="w-7 h-7 rounded-full bg-void border border-border flex items-center justify-center text-sm shrink-0" aria-hidden>
                🤖
              </span>
              <span className="flex-1 min-w-0 text-sm font-bold text-text truncate">Yapay Zeka</span>
              <CheckMark checked={aiSelected} />
            </button>
          )}
        </div>
        {playerCount === 4 && (
          <p className="text-[10px] text-muted font-mono">
            En az 2 arkadaş gerekir — 3'ten azsa kalan koltuk Yapay Zeka ile dolar.
          </p>
        )}
      </div>

      {error && <p className="text-xs text-red font-mono text-center">{error}</p>}

      <button
        onClick={handleSubmit}
        disabled={!canSubmit || busy}
        className="btn-raised py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
      >
        {busy ? 'Gönderiliyor…' : 'Davet Gönder'}
      </button>

      {showAiConfirm &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={aiConfirmRef}
              role="dialog"
              aria-modal="true"
              aria-label="Yapay Zeka onayı"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
            >
              <p className="text-sm text-text font-sans leading-relaxed">
                4. koltuk Yapay Zeka ile doldurulacak, tamam mı?
              </p>
              <div className="flex gap-2 mt-1">
                <button
                  onClick={() => {
                    setShowAiConfirm(false);
                    void submit(true);
                  }}
                  className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
                >
                  Evet
                </button>
                <button
                  onClick={() => {
                    setShowAiConfirm(false);
                    setShowAiRow(true);
                  }}
                  className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
                >
                  Hayır
                </button>
              </div>
            </div>
          </div>,
          document.body,
        )}
    </div>
  );
}
