// Kelimeki — Oyun İçi Mesajlaşma, Faz 2: sessize alma / raporlama ayarları.
// ChatModal'ın dişli ikonundan açılır, ChatModal'ın ÜZERİNE (nested modal)
// biner. Liste görünümü ↔ kişi detay görünümü ↔ rapor akışı aynı Modal
// içinde, inline state ile değişir — üçüncü bir nested modal katmanı
// (ayrı bir useModalA11y/focus-trap örneği) gerektirmeden, HelpModal'ın
// Hızlı Başlangıç ↔ Detaylı Kurallar geçişiyle aynı desen.
//
// Rozet mantığı: bayrak (🚩) yalnızca AKTİF (geri çekilmemiş) bir raporum
// varsa gösterilir; yoksa ve kişiyi sessize almışsam yasak işareti (🚫)
// gösterilir; ikisi de yoksa hiçbir işaret yok. Bu rozetler yalnızca
// işlemi yapan kişiye (bana) görünür — karşı taraf hiçbir zaman göremez
// (bkz. CLAUDE.md "karşı tarafa yansımıyor" ilkesi).
import { useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import type { ChatParticipant } from './ChatModal';
import { setChatMute, reportChatParticipant, withdrawChatReports } from '../lib/api';

interface ChatSettingsModalProps {
  gameId: string;
  /** Zaten myUserId hariç filtrelenmiş gelir. */
  participants: ChatParticipant[];
  mutedUserIds: Set<string>;
  reportedUserIds: Set<string>;
  onMuteChange: (targetUserId: string, muted: boolean) => void;
  onReported: (targetUserId: string) => void;
  onWithdrawn: (targetUserId: string) => void;
  onClose: () => void;
  /** Doluysa modal doğrudan bu kişinin detay görünümüyle açılır — sohbetteki
   * bir rozete (🚫/🚩) tıklanınca kullanılır, listeyi atlayıp direkt
   * hatırlatma/aksiyon ekranına gider. */
  initialParticipantId?: string | null;
}

type View =
  | { kind: 'list' }
  | { kind: 'detail'; participant: ChatParticipant }
  | { kind: 'mute-confirm'; participant: ChatParticipant; nextMuted: boolean }
  | { kind: 'report-reason'; participant: ChatParticipant }
  | { kind: 'report-confirm'; participant: ChatParticipant; reason: string }
  | { kind: 'withdraw-confirm'; participant: ChatParticipant };

const REASON_MAX = 500;

export function ChatSettingsModal({
  gameId,
  participants,
  mutedUserIds,
  reportedUserIds,
  onMuteChange,
  onReported,
  onWithdrawn,
  onClose,
  initialParticipantId,
}: ChatSettingsModalProps) {
  const [view, setView] = useState<View>(() => {
    const initial = initialParticipantId ? participants.find((p) => p.userId === initialParticipantId) : null;
    return initial ? { kind: 'detail', participant: initial } : { kind: 'list' };
  });
  const [reasonDraft, setReasonDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleToggleMute = async (participant: ChatParticipant) => {
    const nextMuted = !mutedUserIds.has(participant.userId);
    setBusy(true);
    setError(null);
    try {
      await setChatMute(gameId, participant.userId, nextMuted);
      onMuteChange(participant.userId, nextMuted);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'İşlem başarısız oldu.');
    } finally {
      setBusy(false);
    }
  };

  const handleWithdraw = async (participant: ChatParticipant) => {
    setBusy(true);
    setError(null);
    try {
      await withdrawChatReports(gameId, participant.userId);
      onWithdrawn(participant.userId);
      setView({ kind: 'list' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'İşlem başarısız oldu.');
    } finally {
      setBusy(false);
    }
  };

  const handleSubmitReport = async (participant: ChatParticipant, reason: string) => {
    setBusy(true);
    setError(null);
    try {
      await reportChatParticipant(gameId, participant.userId, reason);
      onReported(participant.userId);
      setView({ kind: 'list' });
      setReasonDraft('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Rapor gönderilemedi.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title="Sohbet Ayarları" onClose={onClose}>
      {view.kind === 'list' && (
        <div className="flex flex-col gap-3">
          <p className="text-xs text-muted leading-relaxed">
            Buradan kişileri sessize alabilir ve/veya uygunsuz paylaşımları rapor edebilirsiniz.
          </p>
          <div className="flex flex-col gap-1.5">
            {participants.map((p) => {
              const reported = reportedUserIds.has(p.userId);
              const muted = mutedUserIds.has(p.userId);
              return (
                <button
                  key={p.userId}
                  type="button"
                  onClick={() => {
                    setError(null);
                    setView({ kind: 'detail', participant: p });
                  }}
                  className="flex items-center gap-2 bg-bg border border-border rounded-lg px-2.5 py-2 text-left hover:border-accent transition-colors"
                >
                  <Avatar url={p.avatarUrl} name={p.name} size={24} />
                  <span className="text-xs text-text flex-1 min-w-0 truncate">{p.name}</span>
                  {reported ? (
                    <span aria-label="Rapor edildi" title="Rapor edildi" className="text-sm shrink-0">
                      🚩
                    </span>
                  ) : muted ? (
                    <span aria-label="Sessize alındı" title="Sessize alındı" className="text-sm shrink-0">
                      🚫
                    </span>
                  ) : null}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {view.kind === 'detail' && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center gap-2">
            <Avatar url={view.participant.avatarUrl} name={view.participant.name} size={28} />
            <p className="text-sm font-bold text-text">{view.participant.name}</p>
          </div>

          <button
            type="button"
            disabled={busy}
            onClick={() => {
              setError(null);
              setView({
                kind: 'mute-confirm',
                participant: view.participant,
                nextMuted: !mutedUserIds.has(view.participant.userId),
              });
            }}
            className="flex items-center gap-2.5 bg-bg border border-border rounded-lg px-2.5 py-2 text-left disabled:opacity-50"
          >
            <span
              className={[
                'w-4 h-4 rounded border-2 shrink-0 flex items-center justify-center text-[10px] leading-none',
                mutedUserIds.has(view.participant.userId)
                  ? 'bg-accent border-accent text-white'
                  : 'bg-bg border-muted text-transparent',
              ].join(' ')}
            >
              ✓
            </span>
            <span className="text-sm text-text">Kişiyi Sessize Al</span>
          </button>

          {reportedUserIds.has(view.participant.userId) ? (
            <div className="flex flex-col gap-1.5">
              <p className="text-xs text-muted">Bu kişiyi rapor ettiniz.</p>
              <button
                type="button"
                disabled={busy}
                onClick={() => {
                  setError(null);
                  setView({ kind: 'withdraw-confirm', participant: view.participant });
                }}
                className="btn-raised-neutral rounded-md py-2 text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform disabled:opacity-50"
              >
                Raporu Geri Çek
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => {
                setReasonDraft('');
                setError(null);
                setView({ kind: 'report-reason', participant: view.participant });
              }}
              className="btn-raised rounded-md py-2 text-xs font-bold uppercase tracking-[1px] bg-red text-white active:scale-[0.97] transition-transform"
            >
              Kişiyi Rapor Et
            </button>
          )}

          {error && <p className="text-red text-[10px] font-mono">{error}</p>}

          <button
            type="button"
            onClick={() => setView({ kind: 'list' })}
            className="text-[11px] font-mono text-muted hover:text-text text-center"
          >
            ← Geri
          </button>
        </div>
      )}

      {view.kind === 'mute-confirm' && (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-text font-bold">Emin misiniz?</p>
          <p className="text-sm text-text leading-relaxed">
            {view.nextMuted ? (
              <>
                <span className="font-bold">{view.participant.name}</span> kişisini sessize almak istediğinize emin
                misiniz? Mesajları sohbette görünmeye devam eder, yalnızca bu kişiden gelen yeni mesaj bildirimleri
                sizin için kapanır.
              </>
            ) : (
              <>
                <span className="font-bold">{view.participant.name}</span> kişisini sessizden çıkarmak istediğinize
                emin misiniz? Bu kişiden gelen yeni mesajlar için tekrar bildirim almaya başlarsınız.
              </>
            )}
          </p>
          {error && <p className="text-red text-[10px] font-mono">{error}</p>}
          <div className="flex gap-2">
            <button
              type="button"
              disabled={busy}
              onClick={async () => {
                await handleToggleMute(view.participant);
                setView({ kind: 'detail', participant: view.participant });
              }}
              className="flex-1 btn-raised rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              {busy ? '...' : view.nextMuted ? 'Sessize Al' : 'Sessizden Çıkar'}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => setView({ kind: 'detail', participant: view.participant })}
              className="flex-1 btn-raised-neutral rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              Vazgeç
            </button>
          </div>
        </div>
      )}

      {view.kind === 'withdraw-confirm' && (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-text font-bold">Emin misiniz?</p>
          <p className="text-sm text-text leading-relaxed">
            <span className="font-bold">{view.participant.name}</span> için gönderdiğiniz raporu geri çekmek
            istediğinize emin misiniz?
          </p>
          {error && <p className="text-red text-[10px] font-mono">{error}</p>}
          <div className="flex gap-2">
            <button
              type="button"
              disabled={busy}
              onClick={() => void handleWithdraw(view.participant)}
              className="flex-1 btn-raised rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              {busy ? '...' : 'Raporu Geri Çek'}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => setView({ kind: 'detail', participant: view.participant })}
              className="flex-1 btn-raised-neutral rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              Vazgeç
            </button>
          </div>
        </div>
      )}

      {view.kind === 'report-reason' && (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-text">
            <span className="font-bold">{view.participant.name}</span> kullanıcısını neden rapor ediyorsunuz?
          </p>
          <textarea
            className="w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors resize-none"
            rows={3}
            maxLength={REASON_MAX}
            placeholder="Kısaca açıklayın (zorunlu)…"
            value={reasonDraft}
            onChange={(e) => setReasonDraft(e.target.value)}
            autoFocus
          />
          <span className="text-[10px] text-muted font-mono self-end">
            {reasonDraft.length}/{REASON_MAX}
          </span>
          <div className="flex gap-2">
            <button
              type="button"
              disabled={reasonDraft.trim().length === 0}
              onClick={() => setView({ kind: 'report-confirm', participant: view.participant, reason: reasonDraft.trim() })}
              className="flex-1 btn-raised rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-red text-white active:scale-[0.97] transition-transform disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Devam Et
            </button>
            <button
              type="button"
              onClick={() => setView({ kind: 'detail', participant: view.participant })}
              className="flex-1 btn-raised-neutral rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform"
            >
              Vazgeç
            </button>
          </div>
        </div>
      )}

      {view.kind === 'report-confirm' && (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-text font-bold">Emin misiniz?</p>
          <p className="text-sm text-text leading-relaxed">
            <span className="font-bold">{view.participant.name}</span> kullanıcısı, yazdığınız nedenle admine rapor
            edilecek. Bu işlem geri alınamaz (ama daha sonra raporu geri çekebilirsiniz).
          </p>
          <div className="bg-bg border border-border rounded-md p-2">
            <p className="text-xs text-muted whitespace-pre-wrap">{view.reason}</p>
          </div>
          {error && <p className="text-red text-[10px] font-mono">{error}</p>}
          <div className="flex gap-2">
            <button
              type="button"
              disabled={busy}
              onClick={() => void handleSubmitReport(view.participant, view.reason)}
              className="flex-1 btn-raised rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-red text-white active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              {busy ? '...' : 'Rapor Et'}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => setView({ kind: 'report-reason', participant: view.participant })}
              className="flex-1 btn-raised-neutral rounded-md py-2.5 text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform disabled:opacity-50"
            >
              Vazgeç
            </button>
          </div>
        </div>
      )}
    </Modal>
  );
}
