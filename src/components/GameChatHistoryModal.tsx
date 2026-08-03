// Kelimeki — Oyun İçi Mesajlaşma (Faz 1): bitmiş bir Canlı oyunun
// dondurulmuş sohbet kaydını gösteren salt-okunur modal. `GameHistoryModal`
// (Tüm Oyunlarım) listesindeki sohbet rozetinden açılır — ileride uygunsuz
// paylaşım kontrolü için bu kayıt kalıcı olarak erişilebilir kalıyor.
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { ChatThread, type ChatThreadMessage } from './ChatThread';
import { fetchGameMessages, fetchFinishedGameChatFlags } from '../lib/api';
import type { GameChatMessage } from '../lib/database.types';

interface GameChatHistoryModalProps {
  gameId: string;
  /**
   * Bu kaydın geldiği Canlı oyun (`games.online_game_id`) — sessize
   * alma/rapor rozetlerini çözmek için. Yerel/YZ oyunlarında null olur
   * (zaten sohbet de olmaz), o durumda hiç rozet sorgusu yapılmaz.
   */
  onlineGameId?: string | null;
  onClose: () => void;
}

export function GameChatHistoryModal({ gameId, onlineGameId, onClose }: GameChatHistoryModalProps) {
  const [messages, setMessages] = useState<GameChatMessage[] | null>(null);
  // Renk indeksi bazlı — dondurulmuş mesajlar kimlik taşımadığından
  // (bkz. GameChatMessage) eşleme sunucuda yapılıp buraya yalnızca
  // "hangi renk işaretli" bilgisi geliyor.
  const [flags, setFlags] = useState<{ muted: Set<number>; reported: Set<number> }>({
    muted: new Set(),
    reported: new Set(),
  });

  useEffect(() => {
    let cancelled = false;
    void fetchGameMessages(gameId).then((rows) => {
      if (!cancelled) setMessages(rows);
    });
    return () => {
      cancelled = true;
    };
  }, [gameId]);

  useEffect(() => {
    if (!onlineGameId) return;
    let cancelled = false;
    void fetchFinishedGameChatFlags(onlineGameId).then((f) => {
      if (!cancelled) setFlags(f);
    });
    return () => {
      cancelled = true;
    };
  }, [onlineGameId]);

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
        // Salt-görsel: `senderId` verilmediğinden (arşiv kimlik taşımaz)
        // ChatThread bu rozetleri tıklanabilir yapmaz. Durum kişi bazlı ve
        // güncel olduğundan (bkz. person_scoped_chat_moderation) rozet, o
        // oyundaki değil BUGÜNKÜ sessize alma/rapor durumunu gösterir.
        badge: flags.reported.has(m.colorIndex)
          ? ('reported' as const)
          : flags.muted.has(m.colorIndex)
            ? ('muted' as const)
            : undefined,
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
