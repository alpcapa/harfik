// Kelimeki — Canlı sekmesi: davet bekleyen/rakip bekleyen/aktif Canlı
// oyunların listesi, gelen davetlerde kiminle oynayacağını gösterme +
// Kabul/Reddet + "+ Yeni Canlı Oyun" ile kurulum formuna geçiş (bkz.
// src/App.tsx'teki mainView tab'ı, src/components/LiveGameCreateForm.tsx).
import { useEffect, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { fetchOnlineGameTurns, listMyOnlineGames, respondToGameInvite } from '../lib/api';
import type { OnlineGame, OnlineGameSlot } from '../lib/database.types';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { FriendSuggestModal } from './FriendSuggestModal';
import { LiveGameCreateForm } from './LiveGameCreateForm';

type HumanSlot = Extract<OnlineGameSlot, { type: 'human' }>;

/** `game.slots`teki, çağıranın kendi koltuğunun indeksi (`relation==='self'`). */
function mySlotIndex(game: OnlineGame): number {
  return game.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
}

function statusLabel(game: OnlineGame, isMyTurn?: boolean): string {
  if (game.status === 'active') return isMyTurn ? 'Sıra sende — girmek için dokun' : 'Rakibin sırası';
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

// Bir davetin (yanıt bekleyen) ya da henüz `pending` bir oyunun (kabul
// ettin/kurdun ama diğerleri henüz tamamlanmadı) "kiminle oynayacaksın"
// detayı — katılımcı listesi hem yanıt bekleyen davetlerde hem de
// aşağıdaki "Kabul Ettin — Diğerleri Bekleniyor"/"Rakip Bekleniyor"
// bölümlerinde aynı görünür, çünkü ikisinde de asıl soru aynı: bu oyunda
// kim var, kim ne durumda. Yalnızca `onRespond` verildiğinde Kabul/Reddet
// butonları eklenir.
function PendingGameCard({
  game,
  title,
  onRespond,
  busy,
}: {
  game: OnlineGame;
  title: string;
  onRespond?: (accept: boolean) => void;
  busy?: boolean;
}) {
  const humanSlots = game.slots.filter((s): s is HumanSlot => s.type === 'human');
  const hasAi = game.slots.some((s) => s.type === 'ai');

  return (
    <div className="shadow-raised flex flex-col gap-2.5 rounded-md px-2.5 py-2.5 border border-border bg-panel">
      <span className="font-sans text-sm font-bold text-text leading-snug">{title}</span>
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
      {onRespond && (
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
      )}
    </div>
  );
}

interface GameRowProps {
  game: OnlineGame;
  onRespond?: (accept: boolean) => void;
  busy?: boolean;
  /** Yalnızca `status==='active'` oyunlarda verilir — satıra tıklanınca gerçek oyun ekranını açar. */
  onOpen?: () => void;
  /** `status==='active'` oyunlarda: sıra şu an çağırandaysa `true`. */
  isMyTurn?: boolean;
}

function GameRow({ game, onRespond, busy, onOpen, isMyTurn }: GameRowProps) {
  const isPendingInvite = game.my_role === 'invitee' && game.my_invite_status === 'pending';

  if (isPendingInvite && onRespond) {
    const humanSlots = game.slots.filter((s): s is HumanSlot => s.type === 'human');
    const inviterName = humanSlots.find((s) => s.user_id === game.created_by)?.name;

    return (
      <PendingGameCard
        game={game}
        title={`${inviterName ?? 'Bir arkadaşın'} seni ${game.player_count} kişilik oyuna davet etti`}
        onRespond={onRespond}
        busy={busy}
      />
    );
  }

  const Wrapper = onOpen ? 'button' : 'div';
  return (
    <Wrapper
      type={onOpen ? 'button' : undefined}
      onClick={onOpen}
      className={`shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left ${
        onOpen ? 'active:scale-[0.99] transition-transform' : ''
      }`}
    >
      <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
        {game.player_count} Kişilik Canlı Oyun
      </span>
      <span
        className={`text-[9px] font-mono uppercase tracking-[1px] shrink-0 ${
          isMyTurn ? 'text-green font-bold' : 'text-muted'
        }`}
      >
        {statusLabel(game, isMyTurn)}
      </span>
    </Wrapper>
  );
}

function Section({
  title,
  games,
  onOpenGame,
  turns,
}: {
  title: string;
  games: OnlineGame[];
  onOpenGame?: (game: OnlineGame) => void;
  turns?: Record<string, number>;
}) {
  if (games.length === 0) return null;
  return (
    <div className="flex flex-col gap-2">
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">{title}</div>
      <div className="flex flex-col gap-2">
        {games.map((g) => (
          <GameRow
            key={g.id}
            game={g}
            onOpen={onOpenGame ? () => onOpenGame(g) : undefined}
            isMyTurn={turns ? turns[g.id] === mySlotIndex(g) : undefined}
          />
        ))}
      </div>
    </div>
  );
}

// "Kabul Ettin — Diğerleri Bekleniyor"/"Rakip Bekleniyor" için: her oyunu
// tek satırlık bir özet yerine tam "Kiminle Oynayacaksın" detay kartıyla
// gösterir — bu iki bölümde asıl merak edilen şey zaten "hangi arkadaşım
// henüz kabul etmedi", o yüzden `Section`'ın kompakt `GameRow`'u yerine
// doğrudan `PendingGameCard` kullanılır (bkz. yukarıdaki davet kartı).
function PendingSection({ title, games }: { title: string; games: OnlineGame[] }) {
  if (games.length === 0) return null;
  return (
    <div className="flex flex-col gap-2">
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">{title}</div>
      <div className="flex flex-col gap-2">
        {games.map((g) => (
          <PendingGameCard key={g.id} game={g} title={`${g.player_count} Kişilik Canlı Oyun`} />
        ))}
      </div>
    </div>
  );
}

interface LiveGamesTabProps {
  /** `status==='active'` bir oyuna tıklanınca gerçek oyun ekranını açmak için (Faz 3, 4. adım). */
  onOpenGame: (game: OnlineGame) => void;
}

export function LiveGamesTab({ onOpenGame }: LiveGamesTabProps) {
  const { user, loading: authLoading } = useAuth();
  // null = henüz çekilmedi (yükleniyor), [] = çekildi ama hiç oyun yok.
  const [games, setGames] = useState<OnlineGame[] | null>(null);
  // gameId -> sırası gelen koltuk indeksi ("Sıra sende" rozeti için).
  const [turns, setTurns] = useState<Record<string, number>>({});
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [creating, setCreating] = useState(false);
  const [busyInviteId, setBusyInviteId] = useState<string | null>(null);
  // Bir daveti kabul ettikten sonra, o oyundaki henüz arkadaş olunmayan
  // katılımcılara toplu istek gönderme önerisi (bkz. FriendSuggestModal).
  const [suggestCandidates, setSuggestCandidates] = useState<HumanSlot[] | null>(null);

  const reload = () => {
    listMyOnlineGames().then((rows) => {
      setGames(rows);
      const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
      if (activeIds.length > 0) fetchOnlineGameTurns(activeIds).then(setTurns);
    });
  };

  useEffect(() => {
    if (!user) {
      setGames(null);
      return;
    }
    let cancelled = false;
    listMyOnlineGames().then((rows) => {
      if (cancelled) return;
      setGames(rows);
      const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
      if (activeIds.length > 0) {
        fetchOnlineGameTurns(activeIds).then((map) => {
          if (!cancelled) setTurns(map);
        });
      }
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
        <div className="w-full flex flex-col items-center gap-4 text-center py-4">
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
  // Daveti kabul ettin ama oyun (4 kişilikte diğer davetliler henüz
  // kabul etmediğinden) hâlâ 'pending' — `invites`/`active`/`waiting`
  // hiçbirine düşmediğinden bir kategori eksikti, oyun listede hiç
  // görünmüyordu (kabul ettikten sonra "kayboluyor" gibi görünüyordu).
  const acceptedWaiting = (games ?? []).filter(
    (g) => g.my_role === 'invitee' && g.my_invite_status === 'accepted' && g.status === 'pending',
  );

  return (
    <div className="w-full flex flex-col gap-5">
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
          <Section title="Aktif Oyunlar" games={active} onOpenGame={onOpenGame} turns={turns} />
          <PendingSection title="Kabul Ettin — Diğerleri Bekleniyor" games={acceptedWaiting} />
          <PendingSection title="Rakip Bekleniyor" games={waiting} />
        </>
      )}
    </div>
  );
}
