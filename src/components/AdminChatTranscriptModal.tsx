// Kelimeki — Admin panosu > Geri Bildirim > Şikayetler: bitmiş bir Canlı
// oyunun tam sohbet dökümü. GameChatHistoryModal'ın admin karşılığı — aynı
// ChatThread'i, farklı bir veri kaynağıyla (admin_get_finished_game_chat
// RPC'si, oyunun kendi katılımcısı olmayan admin için de erişilebilir).
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { ChatThread, type ChatThreadMessage } from './ChatThread';
import { fetchAdminFinishedGameChat } from '../lib/api';
import type { GameChatMessage } from '../lib/database.types';

interface AdminChatTranscriptModalProps {
  onlineGameId: string;
  onClose: () => void;
}

export function AdminChatTranscriptModal({ onlineGameId, onClose }: AdminChatTranscriptModalProps) {
  const [messages, setMessages] = useState<GameChatMessage[] | null>(null);

  useEffect(() => {
    let cancelled = false;
    void fetchAdminFinishedGameChat(onlineGameId).then((rows) => {
      if (!cancelled) setMessages(rows);
    });
    return () => {
      cancelled = true;
    };
  }, [onlineGameId]);

  const threadMessages: ChatThreadMessage[] = (messages ?? []).map((m, i) => ({
    key: `${m.created_at}-${i}`,
    name: m.name,
    colorIndex: m.colorIndex,
    message: m.message,
    createdAt: m.created_at,
    mine: false,
  }));

  return (
    <Modal title="Sohbet Dökümü" onClose={onClose}>
      {messages === null ? (
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : (
        <div className="max-h-72 overflow-y-auto pr-1">
          <ChatThread messages={threadMessages} emptyText="Bu oyunda hiç mesaj gönderilmemiş." />
        </div>
      )}
    </Modal>
  );
}
