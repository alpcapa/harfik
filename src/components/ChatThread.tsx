// Kelimeki — Oyun İçi Mesajlaşma (Faz 1): paylaşılan, salt-görsel mesaj
// listesi. Hem Canlı oyundaki devam eden sohbeti (`ChatModal`, `mine`
// gönderenin çağıran kullanıcı olup olmadığına göre hesaplanır) hem de
// bitmiş bir oyunun dondurulmuş arşivini (`GameChatHistoryModal`, "kimin
// ekranı" kavramı geçmişte anlamsız olduğundan tüm mesajlar `mine=false`
// geçilir) render etmek için kullanılır.
import { PLAYER_COLORS } from '../game/constants';
import { Avatar } from './Avatar';

export interface ChatThreadMessage {
  key: string;
  name: string;
  colorIndex: number;
  /** Yalnızca canlı sohbette (`ChatModal`) dolu — arşivde isimden initials üretilir. */
  avatarUrl?: string | null;
  message: string;
  createdAt: string;
  /** true ise mesaj sağa, kendi rengiyle hizalanır. */
  mine: boolean;
  /**
   * Gönderenin user_id'si — yalnızca canlı sohbette dolu (Oyun İçi
   * Mesajlaşma Faz 2, sessize alma/rapor rozetleri için). Arşivde
   * (`GameChatMessage`) bilerek yok — donmuş bir isim kimliğe geri
   * bağlanmıyor, ayrıca bitmiş bir oyunda mute/rapor durumu zaten anlamsız.
   */
  senderId?: string;
}

function formatMessageTime(iso: string): string {
  const d = new Date(iso);
  const date = d.toLocaleDateString('tr-TR');
  const time = d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
  return `${date} · ${time}`;
}

interface ChatThreadProps {
  messages: ChatThreadMessage[];
  emptyText: string;
  /**
   * Oyun İçi Mesajlaşma — Faz 2: çağıranın (viewer'ın) sessize aldığı/aktif
   * rapor açtığı kullanıcı id'leri — doluysa ilgili gönderenin ismi
   * yanında küçük bir rozet (🚫/🚩) gösterilir. İkisi de verilmezse
   * (arşiv görünümü, `GameChatHistoryModal`) hiç rozet render edilmez.
   */
  mutedUserIds?: Set<string>;
  reportedUserIds?: Set<string>;
  /** Rozete tıklanınca çağrılır — o kişinin ayarlar detayını açmak için. */
  onBadgeClick?: (userId: string) => void;
}

export function ChatThread({ messages, emptyText, mutedUserIds, reportedUserIds, onBadgeClick }: ChatThreadProps) {
  if (messages.length === 0) {
    return <p className="text-muted text-[10px] font-mono text-center py-4">{emptyText}</p>;
  }
  return (
    <div className="flex flex-col gap-2.5">
      {messages.map((m) => {
        const col = PLAYER_COLORS[m.colorIndex] ?? PLAYER_COLORS[0];
        const reported = !!m.senderId && !!reportedUserIds?.has(m.senderId);
        const muted = !reported && !!m.senderId && !!mutedUserIds?.has(m.senderId);
        const badge = reported ? '🚩' : muted ? '🚫' : null;
        return (
          <div key={m.key} className={`flex items-end gap-1.5 ${m.mine ? 'flex-row-reverse' : ''}`}>
            <Avatar url={m.avatarUrl} name={m.name} size={22} className="shrink-0" />
            <div className={`flex flex-col gap-0.5 max-w-[75%] min-w-0 ${m.mine ? 'items-end' : 'items-start'}`}>
              <span className="flex items-center gap-1">
                <span
                  className="text-[9px] font-mono font-bold uppercase tracking-[0.5px]"
                  style={{ color: col.base }}
                >
                  {m.name}
                </span>
                {badge &&
                  (onBadgeClick ? (
                    <button
                      type="button"
                      onClick={() => onBadgeClick(m.senderId!)}
                      aria-label={reported ? 'Rapor edildi — ayarları aç' : 'Sessize alındı — ayarları aç'}
                      className="text-[9px] leading-none active:opacity-70 transition-opacity"
                    >
                      {badge}
                    </button>
                  ) : (
                    <span className="text-[9px] leading-none" aria-hidden>
                      {badge}
                    </span>
                  ))}
              </span>
              <div
                className="rounded-xl px-2.5 py-1.5 text-[12px] font-sans text-text leading-snug break-words"
                style={{ background: col.tint, border: `1px solid ${col.base}` }}
              >
                {m.message}
              </div>
              <span className="text-[8px] font-mono text-muted">{formatMessageTime(m.createdAt)}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
