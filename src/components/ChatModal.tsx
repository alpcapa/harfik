// Kelimeki — Oyun İçi Mesajlaşma (Faz 1): Canlı oyundaki gerçek sohbet
// penceresi. Board'un yeni "Mesajlaşma" butonuyla (`OnlineGameScreen.tsx`)
// açılır; yalnızca Canlı (online multiplayer) oyunlarda kullanılır.
import { useEffect, useRef, useState } from 'react';
import { Modal } from './Modal';
import { ChatThread, type ChatThreadMessage } from './ChatThread';
import type { OnlineGameMessageRow } from '../lib/database.types';

const MAX_LENGTH = 200;

export interface ChatParticipant {
  userId: string;
  name: string;
  avatarUrl: string | null;
  colorIndex: number;
}

interface ChatModalProps {
  messages: OnlineGameMessageRow[];
  participants: ChatParticipant[];
  myUserId: string;
  onSend: (text: string) => Promise<void>;
  onClose: () => void;
  /** Ayarlar/dişli ikonuna basınca çağrılır — Oyun İçi Mesajlaşma Faz 2
   * (sessize alma/raporlama) panelini açar (bkz. `ChatSettingsModal`). */
  onOpenSettings: () => void;
  /** Oyun İçi Mesajlaşma — Faz 2: çağıranın sessize aldığı/aktif rapor
   * açtığı kullanıcı id'leri — sohbetteki isimlerin yanında rozet (🚫/🚩)
   * göstermek için `ChatThread`'e iletilir. */
  mutedUserIds: Set<string>;
  reportedUserIds: Set<string>;
  /** Bir mesajdaki rozete tıklanınca çağrılır — o kişinin ayarlar detayını
   * doğrudan açar (bkz. `ChatSettingsModal`'ın `initialParticipantId`'i). */
  onOpenParticipantSettings: (userId: string) => void;
}

function GearIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  );
}

export function ChatModal({
  messages,
  participants,
  myUserId,
  onSend,
  onClose,
  onOpenSettings,
  mutedUserIds,
  reportedUserIds,
  onOpenParticipantSettings,
}: ChatModalProps) {
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const threadRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const el = threadRef.current;
    if (el) el.scrollTop = 0;
  }, [messages.length]);

  const handleSend = async () => {
    const trimmed = text.trim();
    if (trimmed.length === 0 || sending) return;
    setSending(true);
    setError(null);
    try {
      await onSend(trimmed);
      setText('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Mesaj gönderilemedi.');
    } finally {
      setSending(false);
    }
  };

  const threadMessages: ChatThreadMessage[] = messages
    .map((m) => {
      const p = participants.find((x) => x.userId === m.sender_user_id);
      return {
        key: m.id,
        name: p?.name ?? 'Oyuncu',
        colorIndex: p?.colorIndex ?? 0,
        avatarUrl: p?.avatarUrl ?? null,
        message: m.message,
        createdAt: m.created_at,
        mine: m.sender_user_id === myUserId,
        senderId: m.sender_user_id,
      };
    })
    .reverse();

  return (
    <Modal
      title="Mesajlaşma"
      onClose={onClose}
      headerAction={
        <button
          onClick={onOpenSettings}
          aria-label="Sohbet Ayarları"
          className="text-muted hover:text-text w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
        >
          <GearIcon />
        </button>
      }
    >
      <div className="flex flex-col gap-2 mb-3">
        <textarea
          className="w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors resize-none"
          rows={2}
          placeholder="Mesajınızı girin"
          value={text}
          onChange={(e) => setText(e.target.value.slice(0, MAX_LENGTH))}
          maxLength={MAX_LENGTH}
          disabled={sending}
        />
        <div className="flex items-center justify-between gap-2 -mt-1">
          <span className="text-[10px] text-muted font-mono">
            {text.length}/{MAX_LENGTH}
          </span>
          <button
            onClick={() => void handleSend()}
            disabled={sending || text.trim().length === 0}
            className="btn-raised bg-accent text-white rounded-md py-1.5 px-4 text-[11px] font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {sending ? 'Gönderiliyor…' : 'Gönder'}
          </button>
        </div>
        {error && <p className="text-[10px] font-mono text-red">{error}</p>}
      </div>

      <div ref={threadRef} className="max-h-72 overflow-y-auto pr-1">
        <ChatThread
          messages={threadMessages}
          emptyText="Henüz mesaj yok. İlk mesajı sen gönder!"
          mutedUserIds={mutedUserIds}
          reportedUserIds={reportedUserIds}
          onBadgeClick={onOpenParticipantSettings}
        />
      </div>
    </Modal>
  );
}
