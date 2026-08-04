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
   * Gönderenin user_id'si — yalnızca canlı sohbette dolu (`ChatModal`).
   * Arşivde (`GameChatMessage`) bilerek yok: donmuş snapshot girişli HERKESE
   * açık olduğundan (`games_select_authenticated`) kimliğe geri bağlanmıyor.
   * Rozete/mesaja tıklayıp ayarları açmak bu alana bağlı, dolayısıyla arşiv
   * rozetleri salt-görsel kalır.
   */
  senderId?: string;
  /**
   * Oyun İçi Mesajlaşma — Faz 2: bu gönderen için gösterilecek rozet.
   * Kararı ÇAĞIRAN veriyor, çünkü iki kullanım yeri kimliği farklı
   * anahtarlarla biliyor: canlı sohbet `senderId` setleriyle
   * (`mutedUserIds`/`reportedUserIds`), arşiv ise renk indeksiyle
   * (`chat_flags_for_finished_game` — bkz. `fetchFinishedGameChatFlags`).
   */
  badge?: 'muted' | 'reported';
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
   * Rozete/mesaja tıklanınca çağrılır — o kişinin ayarlar detayını açmak
   * için. Yalnızca canlı sohbette (`ChatModal`) verilir; arşivde
   * verilmediğinden rozetler salt-görsel kalır.
   */
  onBadgeClick?: (userId: string) => void;
}

export function ChatThread({ messages, emptyText, onBadgeClick }: ChatThreadProps) {
  if (messages.length === 0) {
    return <p className="text-muted text-[10px] font-mono text-center py-4">{emptyText}</p>;
  }
  return (
    <div className="flex flex-col gap-2.5">
      {messages.map((m) => {
        const col = PLAYER_COLORS[m.colorIndex] ?? PLAYER_COLORS[0];
        const reported = m.badge === 'reported';
        const badge = reported ? '🚩' : m.badge === 'muted' ? '🚫' : null;
        // Kendi mesajını sessize alamayacağın/rapor edemeyeceğin için
        // yalnızca başkasının mesajına tıklamak ayarlar panelini açar.
        const canOpenSettings = !m.mine && !!m.senderId && !!onBadgeClick;
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
                  (onBadgeClick && m.senderId ? (
                    <button
                      type="button"
                      onClick={() => onBadgeClick(m.senderId!)}
                      aria-label={reported ? 'Şikayet edildi — ayarları aç' : 'Sessize alındı — ayarları aç'}
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
              {canOpenSettings ? (
                <button
                  type="button"
                  onClick={() => onBadgeClick!(m.senderId!)}
                  aria-label={`${m.name} — sessize al/şikayet et`}
                  className="rounded-xl px-2.5 py-1.5 text-[12px] font-sans text-text leading-snug break-words text-left active:opacity-70 transition-opacity"
                  style={{ background: col.tint, border: `1px solid ${col.base}` }}
                >
                  {m.message}
                </button>
              ) : (
                <div
                  className="rounded-xl px-2.5 py-1.5 text-[12px] font-sans text-text leading-snug break-words"
                  style={{ background: col.tint, border: `1px solid ${col.base}` }}
                >
                  {m.message}
                </div>
              )}
              <span className="text-[8px] font-mono text-muted">{formatMessageTime(m.createdAt)}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
