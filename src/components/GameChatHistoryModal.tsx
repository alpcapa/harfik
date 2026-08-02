// Kelimeki — Oyun İçi Mesajlaşma (Faz 1): bitmiş bir Canlı oyunun
// dondurulmuş sohbet kaydını gösteren salt-okunur modal. `GameHistoryModal`
// (Tüm Oyunlarım) listesindeki sohbet rozetinden açılır — ileride uygunsuz
// paylaşım kontrolü için bu kayıt kalıcı olarak erişilebilir kalıyor.
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { ChatThread, type ChatThreadMessage } from './ChatThread';
import { fetchGameMessages } from '../lib/api';
import type { GameChatMessage } from '../lib/database.types';

interface GameChatHistoryModalProps {
  gameId: string;
  onClose: () => void;
}

export function GameChatHistoryModal({ gameId, onClose }: GameChatHistoryModalProps) {
  const [messages, setMessages] = useState<GameChatMessage[] | null>(null);

  useEffect(() => {
    let cancelled = false;
    void fetchGameMessages(gameId).then((rows) => {
      if (!cancelled) setMessages(rows);
    });
    return () => {
      cancelled = true;
    };
  }, [gameId]);

  // `games.messages` zaten eskiden-yeniye (kronolojik artan) dondurulmuş
  // durumda geliyor (bkz. _finish_online_game_records) — ChatThread de
  // kendi tarafında hiçbir sıralama yapmıyor, mesajları olduğu gibi
  // yukarıdan aşağı basıyor. Buradaki `.reverse()` yanlışlıkla en yeni
  // mesajı en üste koyuyordu; aynı veriyi gösteren AdminChatTranscriptModal
  // reverse yapmadığından iki ekran farklı sırada görünüyordu (kod
  // incelemesiyle bulundu).
  const threadMessages: ChatThreadMessage[] = messages
    ? messages.map((m, i) => ({
        key: `${m.created_at}-${i}`,
        name: m.name,
        colorIndex: m.colorIndex,
        message: m.message,
        createdAt: m.created_at,
        mine: false,
      }))
    : [];

  return (
    <Modal title="Sohbet Geçmişi" onClose={onClose}>
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
