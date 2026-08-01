// Kelimeki — Canlı sekmesi: davet bekleyen/rakip bekleyen/aktif Canlı
// oyunların listesi, gelen davetlerde kiminle oynayacağını gösterme +
// Kabul/Reddet + "+ Yeni Canlı Oyun" ile kurulum formuna geçiş (bkz.
// src/App.tsx'teki mainView tab'ı, src/components/LiveGameCreateForm.tsx).
import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import {
  checkInviteExpiry,
  checkOnlineGameTurnTimeout,
  fetchOnlineGameDeadlines,
  fetchOnlineGameTurns,
  listMyOnlineGames,
  respondToGameInvite,
  subscribeMyOnlineGames,
} from '../lib/api';
import { ABANDON_TIMEOUT_MS } from '../utils/gameStorage';
import type { OnlineGame, OnlineGameSlot } from '../lib/database.types';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { FriendSuggestModal } from './FriendSuggestModal';
import { LiveGameCreateForm } from './LiveGameCreateForm';
import { RecentGamesSection } from './RecentGamesSection';

type HumanSlot = Extract<OnlineGameSlot, { type: 'human' }>;

/** `game.slots`teki, çağıranın kendi koltuğunun indeksi (`relation==='self'`). */
function mySlotIndex(game: OnlineGame): number {
  return game.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
}

function statusLabel(game: OnlineGame, isMyTurn?: boolean): string {
  if (game.status === 'active') return isMyTurn ? 'Senin Hamlen Bekleniyor' : 'Rakibin hamlesi bekleniyor';
  if (game.status === 'pending') return 'Rakip bekleniyor';
  if (game.status === 'finished') return 'Bitti';
  return 'Terk edildi';
}

// Sırası gelen oyuncunun 48 saatlik zaman aşımına kalan süresi — Setup'taki
// "Devam Eden Oyun" satırının remainingDays'iyle aynı ilke (kalan süre
// düşükse kırmızı, kalın değil), burada saat cinsinden çünkü pencere gün
// değil saat mertebesinde (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6"). Kırmızı
// (kalın değil) kalan süre 24 saatin altına inince devreye giriyor.
function remainingTimeLabel(deadline: string | null | undefined): { text: string; urgent: boolean } | null {
  if (!deadline) return null;
  const ms = new Date(deadline).getTime() - Date.now();
  if (ms <= 0) return { text: 'Süresi doldu - teslim oldu', urgent: true };
  const totalMinutes = Math.ceil(ms / (60 * 1000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  const text =
    hours > 0
      ? `${hours} saat ${minutes} dakika sonra teslim sayılacak`
      : `${minutes} dakika sonra teslim sayılacak`;
  return { text, urgent: totalMinutes < 24 * 60 };
}

// Bekleyen bir davetin/oyunun 7 günlük iptal süresine kalan süre — Setup'taki
// "Devam Eden Oyun" satırının remainingTime'ıyla aynı ilke ve aynı süre
// (ABANDON_TIMEOUT_MS), oluşturulma anından itibaren. "N gün M saat kaldı"
// biçiminde (24 saatin altına düşünce dakika hassasiyetinde saate geçer,
// aynı zamanda kırmızı/kalın olur — remainingTimeLabel'daki aynı mantık).
function remainingInviteDays(createdAt: string): { text: string; urgent: boolean } {
  const ms = Date.parse(createdAt) + ABANDON_TIMEOUT_MS - Date.now();
  if (ms <= 0) return { text: 'Bugün iptal edilir', urgent: true };
  const totalMinutes = Math.ceil(ms / (60 * 1000));
  const totalHours = Math.floor(totalMinutes / 60);
  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;
  const minutes = totalMinutes % 60;
  const text =
    days > 0 ? `${days} gün ${hours} saat kaldı` : `${hours} saat ${minutes} dakika kaldı`;
  return { text, urgent: days < 1 };
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
  const remaining = remainingInviteDays(game.created_at);

  return (
    <div className="shadow-raised flex flex-col gap-2.5 rounded-md px-2.5 py-2.5 border border-border bg-panel">
      <div className="flex items-start gap-2">
        <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text leading-snug">{title}</span>
        <span
          className={`shrink-0 text-[9px] font-mono uppercase tracking-[0.5px] whitespace-nowrap ${
            remaining.urgent ? 'text-red font-bold' : 'text-muted'
          }`}
        >
          {remaining.text}
        </span>
      </div>
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
  /** `status==='active'` oyunlarda: sırası gelen oyuncunun zaman aşımı son tarihi. */
  deadline?: string | null;
}

function GameRow({ game, onRespond, busy, onOpen, isMyTurn, deadline }: GameRowProps) {
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

  const remaining = remainingTimeLabel(deadline);
  const Wrapper = onOpen ? 'button' : 'div';
  const creatorName = game.slots.find(
    (s): s is HumanSlot => s.type === 'human' && s.user_id === game.created_by,
  )?.name;
  return (
    <Wrapper
      type={onOpen ? 'button' : undefined}
      onClick={onOpen}
      className={`shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left ${
        onOpen ? 'active:scale-[0.99] transition-transform' : ''
      }`}
    >
      <span className="flex-1 min-w-0 flex flex-col gap-0.5">
        <span className="font-sans text-[12px] font-bold text-text truncate">
          {game.player_count} Kişilik Oyun
        </span>
        <span className="text-[9px] font-mono text-muted truncate">
          {creatorName ?? 'Bir arkadaşın'} açtı
        </span>
      </span>
      <span className="flex flex-col items-end gap-0.5 shrink-0">
        <span
          className={`text-[11px] font-mono uppercase tracking-[1px] ${
            game.status === 'active'
              ? isMyTurn
                ? 'text-green font-bold'
                : 'text-red font-bold'
              : 'text-muted'
          }`}
        >
          {statusLabel(game, isMyTurn)}
        </span>
        {remaining && (
          <span
            className={`text-[8px] font-mono uppercase tracking-[0.5px] ${
              remaining.urgent ? 'text-red' : 'text-muted'
            }`}
          >
            {remaining.text}
          </span>
        )}
      </span>
    </Wrapper>
  );
}

function Section({
  title,
  games,
  onOpenGame,
  turns,
  deadlines,
}: {
  title: string;
  games: OnlineGame[];
  onOpenGame?: (game: OnlineGame) => void;
  turns?: Record<string, number>;
  deadlines?: Record<string, string | null>;
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
            deadline={deadlines ? deadlines[g.id] : undefined}
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
          <PendingGameCard key={g.id} game={g} title={`${g.player_count} Kişilik Oyun`} />
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
  // gameId -> sırası gelen oyuncunun zaman aşımı son tarihi ("kalan süre" için).
  const [deadlines, setDeadlines] = useState<Record<string, string | null>>({});
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [creating, setCreating] = useState(false);
  const [busyInviteId, setBusyInviteId] = useState<string | null>(null);
  // Bir daveti kabul ettikten sonra, o oyundaki henüz arkadaş olunmayan
  // katılımcılara toplu istek gönderme önerisi (bkz. FriendSuggestModal).
  const [suggestCandidates, setSuggestCandidates] = useState<HumanSlot[] | null>(null);

  // Listeyi çeker, aktif oyunların sırasını/son tarihini yükler; süresi
  // ZATEN dolmuş bir sıra varsa `check_turn_timeout`'u (no-op değilse
  // otomatik teslim uygulanır), 7 gündür yanıtlanmamış bir davet/oyun varsa
  // `check_invite_expiry`'yi (no-op değilse oyun iptal edilir) tetikleyip
  // listeyi bir kez daha tazeler — böylece asılı kalmış bir Canlı oyun,
  // kullanıcı bu sekmeyi her açtığında kendiliğinden çözülür (bkz. CLAUDE.md
  // "Canlı Oyun — Faz 3.6").
  const loadGames = async (cancelledRef?: { current: boolean }) => {
    const rows = await listMyOnlineGames();
    if (cancelledRef?.current) return;
    setGames(rows);

    const expiredInviteIds = rows
      .filter((g) => g.status === 'pending' && Date.parse(g.created_at) + ABANDON_TIMEOUT_MS <= Date.now())
      .map((g) => g.id);
    const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
    if (activeIds.length === 0 && expiredInviteIds.length === 0) {
      setTurns({});
      setDeadlines({});
      return;
    }

    const [turnMap, deadlineMap] =
      activeIds.length > 0
        ? await Promise.all([fetchOnlineGameTurns(activeIds), fetchOnlineGameDeadlines(activeIds)])
        : [{}, {}];
    if (cancelledRef?.current) return;
    setTurns(turnMap);
    setDeadlines(deadlineMap);

    const expiredTurns = activeIds.filter((id) => {
      const d = deadlineMap[id];
      return d && new Date(d).getTime() <= Date.now();
    });
    if (expiredTurns.length === 0 && expiredInviteIds.length === 0) return;
    await Promise.all([
      ...expiredTurns.map((id) => checkOnlineGameTurnTimeout(id)),
      ...expiredInviteIds.map((id) => checkInviteExpiry(id)),
    ]);
    if (cancelledRef?.current) return;
    const rows2 = await listMyOnlineGames();
    if (cancelledRef?.current) return;
    setGames(rows2);
    const activeIds2 = rows2.filter((g) => g.status === 'active').map((g) => g.id);
    if (activeIds2.length === 0) {
      setTurns({});
      setDeadlines({});
      return;
    }
    const [turnMap2, deadlineMap2] = await Promise.all([
      fetchOnlineGameTurns(activeIds2),
      fetchOnlineGameDeadlines(activeIds2),
    ]);
    if (cancelledRef?.current) return;
    setTurns(turnMap2);
    setDeadlines(deadlineMap2);
  };

  const reload = () => {
    void loadGames();
  };

  // Bir daveti gönderilen/kabul edilen/reddedilen taraf bu sekmeyi zaten
  // açık tutuyorsa (ör. davet gönderilirken alıcı "Arkadaşınla" sekmesinde
  // bekliyorsa), önceden bunu görmenin tek yolu sekmeden çıkıp geri dönmek
  // (yeniden mount) ya da uygulamayı aç/kapa etmekti — online_games/
  // game_invites hiçbir Realtime olayı yayınlamıyordu. Artık ikisi de
  // supabase_realtime publication'ında (bkz. ilgili migration); burada
  // herhangi bir değişiklikte listeyi yeniden çekiyoruz. Art arda gelen
  // birden fazla olayı (ör. bir davet kabul edilince hem game_invites hem
  // online_games değişir) tek bir reload'a indirmek için kısa bir debounce.
  const reloadTimeoutRef = useRef<number | null>(null);
  const scheduleReload = () => {
    if (reloadTimeoutRef.current != null) window.clearTimeout(reloadTimeoutRef.current);
    reloadTimeoutRef.current = window.setTimeout(() => {
      reloadTimeoutRef.current = null;
      reload();
    }, 300);
  };

  useEffect(() => {
    if (!user) {
      setGames(null);
      return;
    }
    const cancelledRef = { current: false };
    void loadGames(cancelledRef);
    const unsubscribe = subscribeMyOnlineGames(scheduleReload);
    // Mobil tarayıcılar (özellikle iOS Safari) arka plana alınan bir
    // sekmenin Realtime websocket'ini askıya alabiliyor — o sırada gelen
    // bir davet/kabul olayı kaçırılabilir (bkz. OnlineGameScreen'deki aynı
    // gerekçe). Ön plana/çevrimiçi'ye dönüşte emniyet için elle de tazele.
    const onForeground = () => {
      if (document.visibilityState === 'visible') reload();
    };
    document.addEventListener('visibilitychange', onForeground);
    window.addEventListener('focus', onForeground);
    window.addEventListener('online', onForeground);
    return () => {
      cancelledRef.current = true;
      unsubscribe();
      document.removeEventListener('visibilitychange', onForeground);
      window.removeEventListener('focus', onForeground);
      window.removeEventListener('online', onForeground);
      if (reloadTimeoutRef.current != null) window.clearTimeout(reloadTimeoutRef.current);
    };
  }, [user]);

  if (authLoading) return null;

  if (creating) {
    return (
      <div className="w-full flex flex-col gap-5">
        <LiveGameCreateForm
          onCancel={() => setCreating(false)}
          onCreated={() => {
            setCreating(false);
            reload();
          }}
        />
        <RecentGamesSection onlineOnly />
      </div>
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
          <Section title="Devam Eden Oyunlar" games={active} onOpenGame={onOpenGame} turns={turns} deadlines={deadlines} />
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
          <PendingSection title="Kabul Ettin — Diğerleri Bekleniyor" games={acceptedWaiting} />
          <PendingSection title="Bekleyen Oyunlar" games={waiting} />
        </>
      )}

      <RecentGamesSection onlineOnly />
    </div>
  );
}
