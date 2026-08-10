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
  // Yetki, içerikten AYRI taşınıyor: "hiç mesaj yok" ile "görme yetkin yok"
  // farklı iki durum (bkz. `game_chat_archive` RPC'si, 10 Ağustos 2026).
  const [allowed, setAllowed] = useState(true);
  // Renk indeksi bazlı — dondurulmuş mesajlar kimlik taşımadığından
  // (bkz. GameChatMessage) eşleme sunucuda yapılıp buraya yalnızca
  // "hangi renk işaretli" bilgisi geliyor.
  const [flags, setFlags] = useState<{ muted: Set<number>; reported: Set<number> }>({
    muted: new Set(),
    reported: new Set(),
  });

  useEffect(() => {
    let cancelled = false;
    void fetchGameMessages(gameId).then((res) => {
      if (cancelled) return;
      setAllowed(res.allowed);
      setMessages(res.messages);
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

  // `games.messages` eskiden-yeniye (kronolojik artan) dondurulmuş durumda
  // geliyor (bkz. _finish_online_game_records) — ChatThread kendi tarafında
  // hiçbir sıralama yapmıyor, verilen diziyi yukarıdan aşağı basıyor.
  // Aşağıdaki `.reverse()` en yeni mesajı en ÜSTE alıyor.
  //
  // **Kural: mesajlar HER YERDE en yeniden eskiye (9 Ağustos 2026, kullanıcı
  // isteği).** Bu istek daha önce üç kez iletildi ama her seferinde yalnızca
  // `ChatModal`'a (canlı sohbet) uygulandı; arşiv görünümleri "yazışma kutusu
  // değil döküm" gerekçesiyle bilerek dışarıda bırakılmıştı — o gerekçe
  // kullanıcıdan gelmiyordu. Artık ÜÇ ekran da (ChatModal,
  // GameChatHistoryModal, AdminChatTranscriptModal) aynı yönde; birine
  // dokunan diğer ikisini de kontrol etmeli. Buradaki liste (Modal içindeki
  // `max-h-72 overflow-y-auto`) otomatik kaydırma YAPMIYOR, en üstte açılıyor
  // — yani sıralamayı çevirmek ChatModal'daki gibi bir kaydırma eşleşmesi
  // gerektirmiyor (orada `scrollTop = 0` ile birlikte değişmek zorundaydı).
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
      })).reverse()
    : [];

  return (
    <Modal title="Sohbet Geçmişi" onClose={onClose}>
      {messages === null ? (
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : !allowed ? (
        // Rozet (message_count) da 10 Ağustos 2026'dan beri katılımcı kapılı
        // (`game_like_stats` 0 döner), yani bu dal pratikte yalnızca yarışta
        // görünür: liste çekildikten SONRA katılımcılıktan çıkılması gibi.
        // Yine de duruyor — "hiç mesaj yok" ile karıştırılmamalı.
        <p className="text-muted text-xs font-mono text-center py-4">
          Yazışmaları görmeye yetkiniz yok.
        </p>
      ) : (
        <div className="max-h-72 overflow-y-auto pr-1">
          <ChatThread messages={threadMessages} emptyText="Bu oyunda hiç mesaj gönderilmemiş." />
        </div>
      )}
    </Modal>
  );
}
