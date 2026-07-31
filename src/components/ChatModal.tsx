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
}

export function ChatModal({ messages, participants, myUserId, onSend, onClose }: ChatModalProps) {
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const threadRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const el = threadRef.current;
    if (el) el.scrollTop = el.scrollHeight;
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

  const threadMessages: ChatThreadMessage[] = messages.map((m) => {
    const p = participants.find((x) => x.userId === m.sender_user_id);
    return {
      key: m.id,
      name: p?.name ?? 'Oyuncu',
      colorIndex: p?.colorIndex ?? 0,
      avatarUrl: p?.avatarUrl ?? null,
      message: m.message,
      createdAt: m.created_at,
      mine: m.sender_user_id === myUserId,
    };
  });

  return (
    <Modal title="Mesajlaşma" onClose={onClose}>
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
        <div className="flex items-center justify-between gap-2">
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
        <ChatThread messages={threadMessages} emptyText="Henüz mesaj yok. İlk mesajı sen gönder!" />
      </div>
    </Modal>
  );
}
