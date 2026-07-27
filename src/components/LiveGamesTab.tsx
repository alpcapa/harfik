// Kelimeki — Canlı sekmesi: davet bekleyen/rakip bekleyen/aktif Canlı
// oyunların listesi, gelen davetlerde kiminle oynayacağını gösterme +
// Kabul/Reddet + "+ Yeni Canlı Oyun" ile kurulum formuna geçiş (bkz.
// src/App.tsx'teki mainView tab'ı, src/components/LiveGameCreateForm.tsx).
import { useEffect, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { listMyOnlineGames, respondToGameInvite } from '../lib/api';
import type { OnlineGame, OnlineGameSlot } from '../lib/database.types';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { FriendSuggestModal } from './FriendSuggestModal';
import { LiveGameCreateForm } from './LiveGameCreateForm';

type HumanSlot = Extract<OnlineGameSlot, { type: 'human' }>;

function statusLabel(game: OnlineGame): string {
  if (game.status === 'active') return 'Aktif — oynanış yakında';
  if (game.status === 'pending') return 'Rakip bekleniyor';
  if (game.status === 'finished') return 'Bitti';
  return 'Terk edildi';
}

// Bir davet satırındaki tek katılımcının, o oyundaki rolüne göre etiketi —
// "kim arkadaşım" değil "kim ne durumda" sorusuna cevap verir (relation
// tabanlı +/✓ göstergesi kafa karıştırdığı için kaldırıldı). Çağıranın
// kendi koltuğu da özel bir "Sen" etiketi almıyor — o da diğer davetliler
// gibi kendi gerçek adıyla ve invite_status'una göre gösterilir (bu
// listede zaten her zaman 'pending'dir, yani "Bekliyor" çıkar).
function participantLabel(slot: HumanSlot, game: OnlineGame): string {
  if (slot.user_id === game.created_by) return 'Davet gönderen';
  if (slot.invite_status === 'accepted') return 'Kabul etti';
  if (slot.invite_status === 'declined') return 'Reddetti';
  return 'Bekliyor';
}

function ParticipantRow({ slot, game }: { slot: HumanSlot; game: OnlineGame }) {
  return (
    <div className="flex items-center gap-2">
      <Avatar url={slot.avatar_url} name={slot.name} size={22} />
      <span className="flex-1 min-w-0 text-xs text-text truncate">{slot.name ?? 'Oyuncu'}</span>
      <span className="text-[9px] font-mono uppercase tracking-[0.5px] text-muted shrink-0">
        {participantLabel(slot, game)}
      </span>
    </div>
  );
}

interface GameRowProps {
  game: OnlineGame;
  onRespond?: (accept: boolean) => void;
  busy?: boolean;
}

function GameRow({ game, onRespond, busy }: GameRowProps) {
  const isPendingInvite = game.my_role === 'invitee' && game.my_invite_status === 'pending';

  if (isPendingInvite && onRespond) {
    const humanSlots = game.slots.filter((s): s is HumanSlot => s.type === 'human');
    const hasAi = game.slots.some((s) => s.type === 'ai');
    const inviterName = humanSlots.find((s) => s.user_id === game.created_by)?.name;

    return (
      <div className="shadow-raised flex flex-col gap-2.5 rounded-md px-2.5 py-2.5 border border-border bg-panel">
        <span className="font-sans text-sm font-bold text-text leading-snug">
          {inviterName ?? 'Bir arkadaşın'} seni {game.player_count} kişilik oyuna davet etti
        </span>
        <div className="flex flex-col gap-1.5">
          <div className="text-[9px] uppercase tracking-[1px] text-muted font-mono">Kiminle Oynayacaksın</div>
          {humanSlots.map((slot) => (
            <ParticipantRow key={slot.user_id} slot={slot} game={game} />
          ))}
          {hasAi && (
            <div className="flex items-center gap-2">
              <span
                className="w-[22px] h-[22px] rounded-full bg-void border border-border flex items-center justify-center text-xs shrink-0"
                aria-hidden
              >
                🤖
              </span>
              <span className="flex-1 min-w-0 text-xs text-text truncate">Yapay Zeka</span>
            </div>
          )}
        </div>
        <div className="flex gap-1.5">
          <button
            onClick={() => onRespond(true)}
            disabled={busy}
            className="flex-1 btn-raised bg-accent text-white rounded-md py-1.5 text-[10px] font-bold uppercase tracking-[0.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            Kabul Et
          </button>
          <button
            onClick={() => onRespond(false)}
            disabled={busy}
            className="flex-1 btn-raised-neutral bg-panel border border-border text-muted rounded-md py-1.5 text-[10px] font-bold uppercase tracking-[0.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            Reddet
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel">
      <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
        {game.player_count} Kişilik Canlı Oyun
      </span>
      <span className="text-[9px] font-mono uppercase tracking-[1px] text-muted shrink-0">
        {statusLabel(game)}
      </span>
    </div>
  );
}

function Section({ title, games }: { title: string; games: OnlineGame[] }) {
  if (games.length === 0) return null;
  return (
    <div className="flex flex-col gap-2">
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">{title}</div>
      <div className="flex flex-col gap-2">
        {games.map((g) => (
          <GameRow key={g.id} game={g} />
        ))}
      </div>
    </div>
  );
}

export function LiveGamesTab() {
  const { user, loading: authLoading } = useAuth();
  // null = henüz çekilmedi (yükleniyor), [] = çekildi ama hiç oyun yok.
  const [games, setGames] = useState<OnlineGame[] | null>(null);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [creating, setCreating] = useState(false);
  const [busyInviteId, setBusyInviteId] = useState<string | null>(null);
  // Bir daveti kabul ettikten sonra, o oyundaki henüz arkadaş olunmayan
  // katılımcılara toplu istek gönderme önerisi (bkz. FriendSuggestModal).
  const [suggestCandidates, setSuggestCandidates] = useState<HumanSlot[] | null>(null);

  const reload = () => {
    listMyOnlineGames().then(setGames);
  };

  useEffect(() => {
    if (!user) {
      setGames(null);
      return;
    }
    let cancelled = false;
    listMyOnlineGames().then((rows) => {
      if (!cancelled) setGames(rows);
    });
    return () => {
      cancelled = true;
    };
  }, [user]);

  if (authLoading) return null;

  if (creating) {
    return (
      <LiveGameCreateForm
        onCancel={() => setCreating(false)}
        onCreated={() => {
          setCreating(false);
          reload();
        }}
      />
    );
  }

  if (!user) {
    return (
      <>
        {showAuthModal && <AuthModal onClose={() => setShowAuthModal(false)} />}
        <div className="w-full max-w-[460px] px-4 py-10 flex flex-col items-center gap-4 text-center">
          <p className="text-sm text-muted font-sans">
            Canlı oyun oynamak için giriş yapmalısın.
          </p>
          <button
            onClick={() => setShowAuthModal(true)}
            className="btn-raised py-2.5 px-6 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
          >
            Giriş Yap
          </button>
        </div>
      </>
    );
  }

  const handleRespond = async (game: OnlineGame, accept: boolean) => {
    if (!game.my_invite_id) return;
    setBusyInviteId(game.my_invite_id);
    try {
      await respondToGameInvite(game.my_invite_id, accept);
      if (accept) {
        const candidates = game.slots.filter(
          (s): s is HumanSlot => s.type === 'human' && s.relation !== 'self' && s.relation !== 'accepted',
        );
        if (candidates.length > 0) setSuggestCandidates(candidates);
      }
      reload();
    } catch (err) {
      console.error('[Kelimeki] respondToGameInvite hatası:', err);
    } finally {
      setBusyInviteId(null);
    }
  };

  const invites = (games ?? []).filter((g) => g.my_role === 'invitee' && g.my_invite_status === 'pending');
  const active = (games ?? []).filter((g) => g.status === 'active');
  const waiting = (games ?? []).filter((g) => g.my_role === 'creator' && g.status === 'pending');

  return (
    <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
      {suggestCandidates && (
        <FriendSuggestModal candidates={suggestCandidates} onDone={() => setSuggestCandidates(null)} />
      )}

      <button
        onClick={() => setCreating(true)}
        className="btn-raised py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform"
      >
        + Yeni Canlı Oyun
      </button>

      {games === null ? (
        <p className="text-center text-xs text-muted font-mono py-8">Yükleniyor…</p>
      ) : games.length === 0 ? (
        <p className="text-center text-xs text-muted font-mono py-8">
          Henüz bir Canlı oyunun yok.
        </p>
      ) : (
        <>
          {invites.length > 0 && (
            <div className="flex flex-col gap-2">
              <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                Davet Bekliyor
              </div>
              <div className="flex flex-col gap-2">
                {invites.map((g) => (
                  <GameRow
                    key={g.id}
                    game={g}
                    onRespond={(accept) => handleRespond(g, accept)}
                    busy={busyInviteId === g.my_invite_id}
                  />
                ))}
              </div>
            </div>
          )}
          <Section title="Aktif" games={active} />
          <Section title="Rakip Bekleniyor" games={waiting} />
        </>
      )}
    </div>
  );
}
