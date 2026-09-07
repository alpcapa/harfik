// Kelimeki — oturum açan kullanıcının geçmiş tüm oyunlarının listesi (lazy load)
import { useCallback, useEffect, useRef, useState } from 'react';
import { LoadingNote } from './LoadingNote';
import { Modal } from './Modal';
import {
  fetchMyGames,
  fetchGameBoardSnapshot,
  fetchGameLikers,
  fetchGameMoves,
  toggleGameLike,
  markGameShared,
  fetchFinishedGameSlots,
  createOnlineGame,
} from '../lib/api';
import type { BoardSnapshotTile, GameHistoryEntry, GameLiker, GamePlayerSnapshot } from '../lib/database.types';
import type { HistoryEntry } from '../game/types';
import { buildSnapshotGameState } from '../utils/boardSnapshot';
import { MoveHistoryModal } from './MoveHistoryModal';
import { useAuth } from '../hooks/useAuth';
import { buildRematchSlots } from '../utils/rematchSlots';
import { PLAYER_COLORS } from '../game/constants';
import { PlayerBadge } from './PlayerBadge';
import { AiLevelBadge } from './AiLevelBadge';
import { aiLevelForBadge } from '../utils/aiLevel';
import { GameBoardPreview } from './GameBoardPreview';
import { ActionSheet } from './ActionSheet';
import { Avatar } from './Avatar';
import { PlayerScoreCard, type PlayerSummary } from './PlayerScoreCard';
import { GameChatHistoryModal } from './GameChatHistoryModal';
import { captureNodeAsPng } from '../utils/shareBoardImage';
import { leaguePoints, formatLeaguePoints, computeRanks } from '../utils/leaguePoints';
import { shortDisplayName } from '../utils/profileFields';

/** Beğenenler listesindeki bir satırı `PlayerScoreCard` açabilecek şekle çevirir. */
function likerToPlayerSummary(l: GameLiker): PlayerSummary {
  return {
    id: l.user_id,
    username: null,
    first_name: l.first_name,
    last_name: null,
    display_name: l.display_name,
    avatar_url: l.avatar_url,
  };
}

/** `Leaderboard`/`PlayerScoreCard`'daki aynı kısa kimlik kuralı: soyad hiç gösterilmez. */
function likerName(l: GameLiker): string {
  return shortDisplayName(l, 'Oyuncu');
}

interface GameHistoryModalProps {
  /** `null` — Skor Kartı'ndaki "Genel" sekmesi: oyuncu sayısından bağımsız tüm oyunlar. */
  playerCount: number | null;
  onClose: () => void;
  /** Verilirse (admin panelindeki oyuncu detayı) oturum sahibi yerine bu kullanıcının geçmişi gösterilir. */
  userId?: string;
  /**
   * `userId` doluyken hedef üyenin görünen adı — eski (players alanı
   * olmayan) kayıtlardaki "Sen" yer tutucusunun izleyenin kendisi değil bu
   * kullanıcı için gösterilmesi gerektiğinden (bkz. `fallbackPlayers`).
   */
  targetName?: string | null;
  /** Verilirse varsayılan "Tüm Oyunlar · N Oyunculu" başlığının yerine geçer. */
  title?: string;
  /**
   * Verilirse (ör. `RecentGamesSection`'daki "Son Oynadıklarım" satırlarından
   * biri tıklanınca) modal açılır açılmaz bu oyunun tahta önizlemesi
   * genişletilmiş hâlde gösterilir ve o karta kaydırılır — kullanıcı ayrıca
   * tıklamak zorunda kalmaz.
   */
  initialExpandedId?: string;
}

const PAGE_SIZE = 20;

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('tr-TR');
}

/**
 * Eski kayıtlarda (players alanı eklenmeden önce oynanmış oyunlarda) yalnızca
 * kendi puanın ve en iyi rakibin puanı bilinir — diğer oyuncuların adı/puanı
 * saklanmamıştır. Bilinen iki satırı döner; kalan oyuncu sayısını ve kendi
 * satırının indeksini ayrıca verir.
 *
 * `isMyRow` false iken (ör. admin panelinden ya da k-lig'den BAŞKA bir
 * üyenin eski bir kaydını görüntülerken) "Sen" etiketi izleyenin kendisi
 * değil, o eski kaydın gerçek sahibi olan hedef üye için kullanılır —
 * önceden bu ayrım yapılmadığından, başkasının geçmişinde her zaman
 * literal "Sen" yazısı görünüyordu (bkz. kod incelemesi).
 */
function fallbackPlayers(
  entry: GameHistoryEntry,
  isMyRow: boolean,
  targetName: string | null,
): { known: GamePlayerSnapshot[]; unknownCount: number; meIndex: number } {
  const me: GamePlayerSnapshot = {
    name: isMyRow ? 'Sen' : targetName || 'Oyuncu',
    score: entry.player_score,
    is_ai: false,
  };
  const opponent: GamePlayerSnapshot = { name: 'En iyi rakip', score: entry.ai_score, is_ai: false };
  const meFirst = entry.player_score >= entry.ai_score;
  const known = meFirst ? [me, opponent] : [opponent, me];
  return { known, unknownCount: Math.max(0, entry.player_count - 2), meIndex: meFirst ? 0 : 1 };
}

/**
 * Final sıralaması (players) içinde oturum açan kullanıcının (hesap
 * sahibinin) satırının indeksini bulur. `rank` alanı (1 = birinci) bu
 * sıralamadaki pozisyonu doğrudan verir; eski kayıtlarda rank bilinmiyorsa
 * puanı entry.player_score'a eşit olan ve YZ olmayan ilk satıra düşülür.
 */
function findMeIndex(entry: GameHistoryEntry, players: GamePlayerSnapshot[]): number {
  if (entry.rank !== null && entry.rank >= 1 && entry.rank <= players.length) {
    return entry.rank - 1;
  }
  const byScore = players.findIndex((p) => !p.is_ai && p.score === entry.player_score);
  return byScore >= 0 ? byScore : 0;
}

/**
 * Rozette gösterilecek renk/numara, final sıralamasındaki konumdan (rank)
 * BAĞIMSIZ, oyuncunun sabit koltuk kimliğidir — 1. oyuncu her zaman mavi,
 * her YZ her zaman aynı renk (Setup'taki gibi). `colorIndex` bu alan
 * eklenmeden önceki kayıtlarda yok; o durumda varsayılan isimden
 * ("Yapay Zeka N") tahmin edilir, insan oyuncu her zaman koltuk 0'dır.
 * Gerçek oyun anlık görüntüsü değilse (çok eski kayıtların "Sen"/"En iyi
 * rakip" yer tutucuları) tahmin güvenilir olmadığından listedeki konum
 * kullanılır.
 */
function seatIndexFor(p: GamePlayerSnapshot, positionIndex: number, isSnapshot: boolean): number {
  if (p.colorIndex !== undefined) return p.colorIndex;
  if (!isSnapshot) return positionIndex;
  if (!p.is_ai) return 0;
  const m = /Yapay Zeka (\d+)/.exec(p.name);
  return m ? Math.max(0, parseInt(m[1], 10) - 1) : positionIndex;
}

/**
 * Paylaş aksiyonunun sabit metni — skor/tarih artık görselin kendisinde
 * (bkz. aşağı). Bilerek birinci şahıstan ("oynadığım oyun") jenerik üçüncü
 * şahsa çevrildi: paylaşan kişi artık her zaman oyunun sahibi olmayabilir
 * (herkes herkesin oyununu paylaşabiliyor, bkz. `set_game_shared` RPC'si).
 */
const SHARE_MESSAGE = "Kelimeki'deki şu oyunu görmeni istedim.";

/** Herkese açık paylaşım sayfası — bkz. `SharedGamePage`/`main.tsx`'teki path kontrolü. */
function buildShareUrl(gameId: string): string {
  return `${window.location.origin}/game/${gameId}`;
}

function HeartIcon({ filled, size = 18 }: { filled: boolean; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={filled ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
    </svg>
  );
}

/** Oyun İçi Mesajlaşma — Faz 1: Canlı/Yapay Zeka rozetlerinin yanındaki sohbet rozeti. */
function ChatBubbleIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    </svg>
  );
}

/** Hamle geçmişi ikonu — sohbet rozetiyle AYNI boyda (kullanıcı isteği:
 *  "mesaj balonunun yanına aynı boyda bir file ikonu"). Path verisi
 *  `Board.tsx`'in alt şeridindeki "Hamleler" ikonuyla BİREBİR aynı: aynı
 *  şeyi açan iki kontrol aynı görünmeli (bkz. `RelationIcons` ilkesi) —
 *  biri değişirse öteki de değişmeli. */
function MovesIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
      <path d="M9 13h6M9 17h6" />
    </svg>
  );
}

/**
 * Tahta önizlemesinin üstünde tek satır skor kutuları — `GameHeader`'daki
 * oyun içi skor kutularıyla aynı görsel dil (renk = zone.tint dolgu +
 * base çerçeve, üstte isim, altta puan), yalnızca burada dört kutu da
 * eşit genişlikte (flex-1) tek satıra sığacak şekilde küçültülmüş.
 * Çerçeve `GameHeader`'daki gibi inset box-shadow DEĞİL, gerçek bir CSS
 * `border` — bu düğüm `captureNodeAsPng` ile PNG'ye yakalandığından
 * (paylaşım görseli), html-to-image inset box-shadow'u köşe yuvarlaklığıyla
 * güvenilir yakalamıyor (25 Temmuz 2026'da fark edildi: çerçeve neredeyse
 * hiç görünmüyor, kutunun sağında rastgele ince bir çizgi artığı kalıyordu).
 */
function ScoreBoxRow({
  players,
  hasSnapshot,
  meIndex,
  myCurrentName,
}: {
  players: GamePlayerSnapshot[];
  hasSnapshot: boolean;
  meIndex: number;
  myCurrentName: string | null;
}) {
  return (
    <div className="flex gap-1.5">
      {players.map((p, i) => {
        const col = PLAYER_COLORS[seatIndexFor(p, i, hasSnapshot)];
        const label = i === meIndex && myCurrentName ? myCurrentName : p.name;
        return (
          <div
            key={i}
            className="flex-1 min-w-0 text-center rounded-md py-1 px-1 border-[1.5px] border-solid"
            style={{ background: col.tint, borderColor: col.base }}
          >
            <div
              className="uppercase tracking-[0.5px] font-mono font-bold truncate text-[7px]"
              style={{ color: col.base }}
            >
              {label}
            </div>
            <div className="font-mono font-bold leading-none text-[13px]" style={{ color: col.base }}>
              {p.score}
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function GameHistoryModal({
  playerCount,
  onClose,
  userId,
  targetName,
  title,
  initialExpandedId,
}: GameHistoryModalProps) {
  const { user, profile, profileLoading } = useAuth();
  // Her oyunun `players` jsonb'si o oyun bittiği andaki ismi donmuş halde
  // tutar — takma adını sonradan değiştirsen eski kayıtlar güncellenmez.
  // Kendi satırını (meIndex) burada donmuş isim yerine her zaman GÜNCEL
  // takma adınla göstererek nickname'in geçmişte de tutarlı görünmesini
  // sağlıyoruz; diğer oyuncuların isimleri hâlâ o anki hallerini gösterir.
  // Admin başka bir oyuncunun geçmişine bakıyorsa (userId verilmiş) bu
  // geçersiz olur — admin'in kendi ismini o oyuncunun satırına koymamak için.
  const myCurrentName = userId
    ? null
    : profile?.display_name ||
      profile?.first_name ||
      (user?.email && !profileLoading ? user.email.split('@')[0] : null) ||
      'Sen';
  const [games, setGames] = useState<GameHistoryEntry[]>([]);
  const [loading, setLoading] = useState(true);
  // Son yükleme GERÇEKTEN hata verdi mi — boş listeden ayrı tutuluyor.
  // Çevrimdışı açan kullanıcıya "henüz kayıtlı oyun yok" demek, oyunlarının
  // silindiğini düşündürür (bkz. `fetchMyGames`'in `failed` alanı).
  const [loadFailed, setLoadFailed] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const scrollRef = useRef<HTMLDivElement | null>(null);

  // Tahta önizlemesi göz ikonuna tıklanınca lazy çekilir (liste sorgusuna dahil
  // değil, bkz. `fetchGameBoardSnapshot`) ve tekrar tıklanana kadar önbellekte
  // tutulur. `fetchedIds`, aynı oyunu aç/kapa yaparken tekrar ağa gitmemek için.
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [snapshots, setSnapshots] = useState<Record<string, BoardSnapshotTile[] | null>>({});
  const [snapshotLoadingId, setSnapshotLoadingId] = useState<string | null>(null);
  // Gerçek bir ağ/DB hatası ("kaydedilmemiş" değil, yüklenemedi) yaşayan
  // oyun id'leri — bu id'ler `fetchedIds`e EKLENMEZ ki "Tekrar Dene" gerçekten
  // yeniden ağa gitsin (bkz. `loadSnapshot`).
  const [snapshotErrorIds, setSnapshotErrorIds] = useState<Set<string>>(new Set());
  const fetchedIds = useRef<Set<string>>(new Set());

  const loadSnapshot = useCallback((gameId: string, afterLoad?: () => void) => {
    fetchedIds.current.add(gameId);
    setSnapshotErrorIds((cur) => {
      if (!cur.has(gameId)) return cur;
      const next = new Set(cur);
      next.delete(gameId);
      return next;
    });
    setSnapshotLoadingId(gameId);
    fetchGameBoardSnapshot(gameId)
      .then((snap) => {
        setSnapshots((c) => ({ ...c, [gameId]: snap }));
        setSnapshotLoadingId((id) => (id === gameId ? null : id));
        afterLoad?.();
      })
      .catch((err) => {
        console.error('[Kelimeki] tahta önizlemesi yüklenemedi:', err);
        fetchedIds.current.delete(gameId);
        setSnapshotLoadingId((id) => (id === gameId ? null : id));
        setSnapshotErrorIds((cur) => new Set(cur).add(gameId));
      });
  }, []);

  // Tahta önizlemesine tıklanınca açılan Kapat/Paylaş aksiyon menüsü.
  const [boardSheetId, setBoardSheetId] = useState<string | null>(null);
  /**
   * "Tekrar Oyna" (4 Eylül 2026, kullanıcı isteği: menüde yalnızca Paylaş ve
   * Kapat vardı). Oyun sonundaki rövanşın aynısı — kadro AYNEN taşınır ve
   * davet gider — ama YALNIZCA Canlı oyunlarda: YZ kayıtlarında yeni bir
   * yerel oyun başlatmak, o an kaydedilmiş devam eden oyunu ezme riski
   * taşıyor (bkz. `docs/decisions/local-game-persistence.md`) ve kapsam
   * bilerek dar tutuldu.
   *
   * Onay adımı KOZMETİK DEĞİL: iki mevcut "Tekrar Oyna" da onay soruyor,
   * çünkü buton davet gönderiyor (bkz. kök CLAUDE.md, "Tekrar Oyna").
   */
  const [rematch, setRematch] = useState<{
    gameId: string;
    playerCount: number;
    names: string[];
    withAi: boolean;
    phase: 'confirm' | 'busy' | 'sent' | 'error';
    message?: string;
  } | null>(null);
  // `handleRematch` useCallback'i state'e bağımlı olmasın diye (her tuşta
  // yeniden kurulmasın); okuduğu değer her zaman en güncel olan.
  const rematchRef = useRef<typeof rematch>(null);
  rematchRef.current = rematch;
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [shareErrorId, setShareErrorId] = useState<string | null>(null);
  const copiedTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Aynı anda yalnızca bir oyunun tahtası genişletilmiş olabildiğinden
  // (expandedId tek bir id) paylaş için görseli buradan yakalıyoruz — tek ref yeterli.
  const boardCaptureRef = useRef<HTMLDivElement | null>(null);

  // Beğeni sayısına dokununca açılan "Beğenenler" listesi. `likersByGame`
  // bir kez çekilen listeyi önbellekte tutar (snapshot'lardaki `fetchedIds`
  // deseniyle aynı mantık) — tekrar aç/kapa yapınca ağa tekrar gitmez.
  const [likersGameId, setLikersGameId] = useState<string | null>(null);
  const [likersByGame, setLikersByGame] = useState<Record<string, GameLiker[]>>({});
  const [likersLoading, setLikersLoading] = useState(false);
  const [selectedLiker, setSelectedLiker] = useState<PlayerSummary | null>(null);

  // Oyun İçi Mesajlaşma — Faz 1: bir oyun kartındaki sohbet rozetine
  // tıklanınca o oyunun tüm sohbet geçmişini gösteren modal.
  const [selectedChatGameId, setSelectedChatGameId] = useState<string | null>(null);
  // Hamle geçmişi — döküm lazy çekilip önbelleğe alınır (`board_snapshot`
  // ile aynı desen). `null` değeri "çekildi ama kaydedilmemiş" demek;
  // anahtarın hiç olmaması "henüz çekilmedi".
  const [selectedMovesGameId, setSelectedMovesGameId] = useState<string | null>(null);
  const [movesByGame, setMovesByGame] = useState<Record<string, HistoryEntry[] | null>>({});
  const [movesLoading, setMovesLoading] = useState(false);
  const [movesError, setMovesError] = useState(false);

  const handleShowLikers = useCallback((gameId: string) => {
    setLikersGameId(gameId);
    if (likersByGame[gameId]) return;
    setLikersLoading(true);
    void fetchGameLikers(gameId).then((rows) => {
      setLikersByGame((cur) => ({ ...cur, [gameId]: rows }));
      setLikersLoading(false);
    });
  }, [likersByGame]);

  /**
   * Rövanşı açar. Kadro geçmiş kaydından ÇIKMIYOR (`GamePlayerSnapshot`
   * `user_id` taşımaz), o yüzden biten oyunun `online_games.slots` satırı
   * ayrıca okunuyor; sıralama kuralı `buildRematchSlots`ta, oyun
   * ekranındakiyle TEK kaynaktan.
   */
  const handleRematch = useCallback(async () => {
    const st = rematchRef.current;
    if (!st || !user?.id) return;
    setRematch({ ...st, phase: 'busy' });
    try {
      const slots = await fetchFinishedGameSlots(st.gameId);
      if (!slots) {
        throw new Error('Bu oyunun kadrosuna ulaşılamadı, rövanş açılamıyor.');
      }
      await createOnlineGame(st.playerCount as 2 | 4, buildRematchSlots(slots, user.id));
      setRematch({ ...st, phase: 'sent' });
    } catch (err) {
      setRematch({
        ...st,
        phase: 'error',
        message: err instanceof Error ? err.message : 'Davet gönderilemedi.',
      });
    }
  }, [user?.id]);

  const handleShare = useCallback(async (entry: GameHistoryEntry) => {
    const text = SHARE_MESSAGE;
    const shared = await markGameShared(entry.id);
    const url = shared ? buildShareUrl(entry.id) : undefined;
    const node = boardCaptureRef.current;
    const blob = node ? await captureNodeAsPng(node) : null;
    const file = blob ? new File([blob], 'kelimeki.png', { type: 'image/png' }) : null;

    if (file && navigator.canShare?.({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: 'Kelimeki', text, url });
        return;
      } catch {
        // Kullanıcı paylaşım sayfasını iptal etti — sessizce geç.
        return;
      }
    }
    if (navigator.share) {
      try {
        await navigator.share({ title: 'Kelimeki', text, url });
      } catch {
        // Kullanıcı paylaşım sayfasını iptal etti — sessizce geç.
      }
      return;
    }
    if (navigator.clipboard) {
      try {
        await navigator.clipboard.writeText(url ? `${text}\n${url}` : text);
        setCopiedId(entry.id);
        setShareErrorId(null);
      } catch (err) {
        console.error('[Kelimeki] panoya kopyalama hatası:', err);
        setShareErrorId(entry.id);
        setCopiedId(null);
      }
      if (copiedTimeout.current) clearTimeout(copiedTimeout.current);
      copiedTimeout.current = setTimeout(() => {
        setCopiedId(null);
        setShareErrorId(null);
      }, 1800);
    }
  }, []);

  // "Son Oynadıklarım"dan `initialExpandedId` ile açılınca hedef kartı
  // listenin ORTASINA hizalar (kullanıcı isteği: "direkt görünsün").
  // `scrollIntoView({block:'start'})` burada güvenilir değildi — bu liste
  // Modal.tsx'in KENDİ `overflow-y-auto` gövdesinin İÇİNDE ikinci (iç
  // içe) bir kaydırma alanı; tarayıcılar iç içe kaydırma alanlarında
  // hizalamayı tutarsız uyguluyor, bu yüzden `getBoundingClientRect` ile
  // hedefin `scrollRef` konteynerine göre GERÇEK konumu elle hesaplanıp
  // `scrollTop` doğrudan ayarlanıyor — konteynerin kendisi taşımadığı
  // sürece (yani ana Modal gövdesi de kaymadığı sürece, ki normalde bu
  // liste `max-h-[65vh]` ile zaten kendi içinde taşıyor) sonuç garantili.
  const centerEntryInView = useCallback((id: string, behavior: ScrollBehavior = 'smooth') => {
    const container = scrollRef.current;
    const target = document.getElementById(`game-history-entry-${id}`);
    if (!container || !target) return;
    const containerRect = container.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();
    const offsetWithinContainer = targetRect.top - containerRect.top + container.scrollTop;
    const centered = offsetWithinContainer - container.clientHeight / 2 + target.clientHeight / 2;
    container.scrollTo({ top: Math.max(0, centered), behavior });
  }, []);

  // Karta (aksiyon menüsü/kalp dışındaki herhangi bir yerine) tıklanınca
  // tahta önizlemesini aç/kapa çevirir — tekrar tıklamak kapatır.
  const handleToggleBoard = useCallback((gameId: string) => {
    setExpandedId((cur) => (cur === gameId ? null : gameId));
    if (fetchedIds.current.has(gameId)) return;
    loadSnapshot(gameId);
  }, [loadSnapshot]);

  const flipLike = (g: GameHistoryEntry) => ({
    ...g,
    liked_by_me: !g.liked_by_me,
    like_count: g.like_count + (g.liked_by_me ? -1 : 1),
  });

  const handleToggleLike = useCallback((gameId: string) => {
    setGames((cur) => cur.map((g) => (g.id === gameId ? flipLike(g) : g)));
    // Beğenenler listesi önbellekte kalmışsa artık güncel değil — bir dahaki
    // açılışta yeniden çekilsin diye siliniyor.
    setLikersByGame((cur) => {
      if (!(gameId in cur)) return cur;
      const next = { ...cur };
      delete next[gameId];
      return next;
    });
    void toggleGameLike(gameId).then((result) => {
      if (result === null) {
        // İstek başarısız oldu (ör. çevrimdışı) — iyimser güncellemeyi geri al.
        setGames((cur) => cur.map((g) => (g.id === gameId ? flipLike(g) : g)));
      }
    });
  }, []);

  useEffect(() => {
    return () => {
      if (copiedTimeout.current) clearTimeout(copiedTimeout.current);
    };
  }, []);

  // Sekme (oyuncu sayısı) ya da "Tümü/Favoriler" filtresi değişince listeyi baştan yükle.
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setGames([]);
    setHasMore(true);
    setExpandedId(null);
    setSnapshots({});
    setBoardSheetId(null);
    setLikersGameId(null);
    fetchedIds.current.clear();
    void (async () => {
      // "Son Oynadıklarım" (RecentGamesSection) TÜR filtreli (onlineOnly)
      // bir sıralamadan geliyor — buradaki (Tüm Oyunlarım) liste ise
      // filtresiz/karma. Sonuç: "Son Oynadıklarım"da 3-5. sırada görünen
      // (ör. en son Canlı oyun) bir kayıt, arada çok sayıda yerel/YZ oyunu
      // varsa, karma sıralamada ilk PAGE_SIZE'ın çok gerisinde kalabiliyordu
      // — hedef kart hiç fetch edilmediğinden `scrollIntoView` sessizce
      // hiçbir şey yapmıyor, kart yalnızca kullanıcı kendisi sonsuz
      // kaydırmayla oraya ulaşınca (beklenmedik bir noktada) beliriyordu.
      // Düzeltme: initialExpandedId varsa, hedef sayfada bulunana ya da
      // liste tükenene kadar (makul bir üst sınıra kadar) sayfa sayfa
      // çekmeye devam ediyoruz.
      let offset = 0;
      let accumulated: GameHistoryEntry[] = [];
      let more = true;
      let found = false;
      let pages = 0;
      const MAX_PAGES = 25; // ~500 oyun — pratikte hiç ulaşılmaz, sonsuz döngüye karşı güvenlik ağı.
      do {
        const { games: page, hasMore: hm, failed } = await fetchMyGames(playerCount, offset, PAGE_SIZE, userId, favoritesOnly);
        if (cancelled) return;
        setLoadFailed(failed);
        accumulated = accumulated.concat(page);
        more = hm;
        offset += page.length;
        pages += 1;
        if (initialExpandedId && page.some((g) => g.id === initialExpandedId)) found = true;
      } while (initialExpandedId && !found && more && pages < MAX_PAGES);

      setGames(accumulated);
      setHasMore(more);
      setLoading(false);
      // "Son Oynadıklarım" satırından açıldıysa (initialExpandedId), o karta
      // hiç tıklamaya gerek kalmadan tahtayı hemen genişletip kaydır.
      if (initialExpandedId) {
        setExpandedId(initialExpandedId);
        if (!fetchedIds.current.has(initialExpandedId)) {
          // Tahta önizlemesi yüklenince kart boyu ciddi ölçüde büyüyor (bkz.
          // yukarıdaki centerEntryInView yorumu) — ilk hizalama o andaki
          // (henüz "Yükleniyor…" yer tutucusu kadar kısa) yüksekliğe göre
          // yapıldığından, gerçek tahta render olduktan sonra tekrar
          // ortalamak gerekiyor, yoksa kart yeniden ekranın altına kayabilir.
          loadSnapshot(initialExpandedId, () =>
            requestAnimationFrame(() => centerEntryInView(initialExpandedId)),
          );
        }
        requestAnimationFrame(() => centerEntryInView(initialExpandedId));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [playerCount, userId, favoritesOnly, initialExpandedId]);

  // games.length'i bir ref'te tutmak loadMore'u (dolayısıyla aşağıdaki
  // IntersectionObserver effect'ini) games'ten bağımsız kılıyor — önceden
  // loadMore [games.length]'e bağlı olduğundan, her yeni sayfa yüklendiğinde
  // observer gereksiz yere disconnect edilip yeniden kuruluyordu.
  const gamesLengthRef = useRef(games.length);
  gamesLengthRef.current = games.length;
  const loadMore = useCallback(() => {
    setLoadingMore((already) => {
      if (already) return already;
      void fetchMyGames(playerCount, gamesLengthRef.current, PAGE_SIZE, userId, favoritesOnly).then(({ games: page, hasMore: more, failed }) => {
        setGames((cur) => [...cur, ...page]);
        setHasMore(more);
        setLoadingMore(false);
        setLoadFailed(failed);
      });
      return true;
    });
  }, [playerCount, userId, favoritesOnly]);

  // Hamle geçmişi ikonuna basılınca dökümü lazy çeker (bir kez; sonra
  // önbellekten). Hata ile "kaydedilmemiş" AYRI durumlar: ilki yeniden
  // denenebilir, ikincisi kalıcı (kolon eklenmeden önce biten yerel oyunlar).
  useEffect(() => {
    const id = selectedMovesGameId;
    if (!id || id in movesByGame) return;
    let cancelled = false;
    setMovesLoading(true);
    setMovesError(false);
    fetchGameMoves(id)
      .then((rows) => {
        if (cancelled) return;
        setMovesByGame((prev) => ({ ...prev, [id]: rows }));
      })
      .catch(() => {
        if (!cancelled) setMovesError(true);
      })
      .finally(() => {
        if (!cancelled) setMovesLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [selectedMovesGameId, movesByGame]);

  // Liste kaydırılıp en alttaki sentinel göründüğünde bir sonraki sayfayı yükler.
  useEffect(() => {
    if (!hasMore || loading) return;
    const sentinel = sentinelRef.current;
    const root = scrollRef.current;
    if (!sentinel || !root) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) loadMore();
      },
      { root, rootMargin: '80px' },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [hasMore, loading, loadMore]);

  return (
    <Modal title={title ?? (playerCount === null ? 'Tüm Oyunlar' : `Tüm Oyunlar · ${playerCount} Oyunculu`)} onClose={onClose}>
      {/* Tümü / Favoriler filtresi */}
      <div className="flex gap-1.5 mb-3 shrink-0">
        {([
          { key: false, label: 'Tümü' },
          { key: true, label: 'Favoriler' },
        ] as const).map((tab) => (
          <button
            key={String(tab.key)}
            onClick={() => setFavoritesOnly(tab.key)}
            className={`flex-1 text-[11px] font-mono font-bold uppercase tracking-[0.5px] py-1.5 rounded-md transition-colors ${
              favoritesOnly === tab.key
                ? 'bg-accent text-white'
                : 'bg-panel text-muted border border-border'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {loading ? (
        <LoadingNote py="py-4" />
      ) : games.length === 0 ? (
        <p className="text-muted text-[10px] font-mono text-center py-4">
          {loadFailed
            ? 'Oyun geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.'
            : favoritesOnly
              ? userId
                ? 'Bu oyuncunun henüz favori işaretlediği bir oyun yok.'
                : 'Henüz favori işaretlediğin bir oyun yok.'
              : 'Bu kategoride henüz kayıtlı oyun yok.'}
        </p>
      ) : (
        <div ref={scrollRef} className="flex flex-col gap-2 max-h-[65vh] overflow-y-auto pr-1">
          {games.map((entry) => {
            const hasSnapshot = !!entry.players && entry.players.length > 0;
            // Favoriler listesinde bir satır, oturum açan kullanıcının SAHİP
            // OLMADIĞI bir oyuna (başkasının kartından beğenilmiş) ait olabilir
            // — bu durumda `entry.rank`/`entry.player_score` o satırın gerçek
            // sahibine ait olduğundan "meIndex" hesaplamak ve myCurrentName ile
            // ikame etmek yanlış oyuncuyu "ben" gibi gösterirdi (bkz. list_liked_games
            // notu, src/lib/api.ts). Yalnızca satır GERÇEKTEN bana aitse hesapla.
            const isMyRow = !!user && entry.user_id === user.id;
            const fallback = hasSnapshot ? null : fallbackPlayers(entry, isMyRow, targetName ?? null);
            const players = hasSnapshot ? entry.players! : fallback!.known;
            const unknownCount = fallback?.unknownCount ?? 0;
            const meIndex = isMyRow ? (hasSnapshot ? findMeIndex(entry, players) : fallback!.meIndex) : -1;
            const ranks = computeRanks(players);
            const expanded = expandedId === entry.id;
            const isOnline = !!entry.online_game_id;
            const isVsAi = !isOnline && hasSnapshot && players.some((p) => p.is_ai);
            return (
              <div key={entry.id} id={`game-history-entry-${entry.id}`} className="flex flex-col gap-1.5">
                <div
                  role="button"
                  tabIndex={0}
                  onClick={() => handleToggleBoard(entry.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      handleToggleBoard(entry.id);
                    }
                  }}
                  className={`shadow-raised ${entry.online_game_id ? 'bg-panel' : 'bg-bg'} border border-border rounded-md py-2 px-2.5 flex flex-col gap-1.5 cursor-pointer text-left`}
                >
                  <div className="flex items-center justify-between gap-x-2 gap-y-1 flex-wrap text-[9px] font-mono text-muted uppercase tracking-[0.5px]">
                    <span className="flex items-center gap-1.5 flex-wrap">
                      <span className="flex items-center gap-0.5 shrink-0">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleToggleLike(entry.id);
                          }}
                          aria-label={entry.liked_by_me ? 'Favoriden çıkar' : 'Favoriye ekle'}
                          className={`tap-expand-y shrink-0 ${entry.liked_by_me ? 'text-red' : 'text-muted'}`}
                        >
                          <HeartIcon filled={entry.liked_by_me} size={13} />
                        </button>
                        {entry.like_count > 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleShowLikers(entry.id);
                            }}
                            aria-label="Beğenenleri göster"
                            className="text-muted underline underline-offset-2 py-1 px-0.5 whitespace-nowrap shrink-0"
                          >
                            {entry.like_count}
                          </button>
                        )}
                      </span>
                      <span className="whitespace-nowrap shrink-0">{formatDate(entry.created_at)}</span>
                      {isOnline && (
                        <span className="text-green font-bold normal-case border border-green/40 bg-green/10 rounded px-[3px] py-0 text-[7px] leading-[10px] whitespace-nowrap shrink-0">
                          Canlı
                        </span>
                      )}
                      {isVsAi && (
                        <span className="text-accent font-bold normal-case border border-accent/40 bg-accent/10 rounded px-[3px] py-0 text-[7px] leading-[10px] whitespace-nowrap shrink-0">
                          Yapay Zeka
                        </span>
                      )}
                      {/* Zorluk rozeti (ROADMAP #23 Faz 3) — "Yapay Zeka"nın
                          hemen sağında, YZ oyununda her seviyede (Normal
                          turuncu); Canlı'da YOK. `ai_level` iki kaynaktan da
                          geliyor (`fetchMyGames` cols + `list_liked_games`),
                          eski satırlar null = Normal. */}
                      <AiLevelBadge level={aiLevelForBadge(entry.ai_level, !isOnline)} />
                      {entry.message_count > 0 && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedChatGameId(entry.id);
                          }}
                          aria-label="Sohbet geçmişini göster"
                          className="tap-expand-y flex items-center gap-0.5 text-muted shrink-0"
                        >
                          <ChatBubbleIcon />
                          {entry.message_count}
                        </button>
                      )}
                      {/* Hamle geçmişi — YALNIZCA dökümü olan kartta (12
                          Ağustos 2026, kullanıcı bildirdi: "YZ oyunlarda içi
                          boş geliyor"). İlk sürüm KOŞULSUZ çiziyordu ("her
                          bitmiş oyunun hamlesi var") — bu, `games.moves`
                          eklenmeden ÖNCE biten oyunları saymıyordu: yerel
                          oyunların dökümü geri doldurulamıyor (bitmiş bir
                          oyunun `moveHistory`'si hiçbir yerde saklanmıyor),
                          Canlı oyunlar ise migration'da dolduruldu. Koşul
                          tür bazlı DEĞİL veri bazlı: bundan sonra biten YZ
                          oyunlarında ikon normal şekilde çıkacak. Dökümün
                          kendisi hâlâ lazy (`fetchGameMoves`). */}
                      {entry.has_moves && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedMovesGameId(entry.id);
                          }}
                          aria-label="Hamle geçmişini göster"
                          /* px-1/py-px + eşit negatif margin: dokunma alanı
                             büyür ama ikonun GÖRSEL konumu ve yanındaki
                             sohbet rozetiyle arasındaki 6px boşluk aynı
                             kalır. Gerekçe/ölçüm mobil eşinde
                             (`game_history_modal.dart`): sohbet kontrolünün
                             kutusuna sayı ETİKETİ de dahil olduğundan
                             18.9x13.5 = 255px², etiketsiz hamle ikonu ise
                             12x12 = 144px² — tam yarısı; cihazda "tam
                             basamazsan kart açılıp kapanıyor" olarak
                             bildirildi. İkisi tek bir çift: biri
                             büyütülürse öteki de kontrol edilmeli. */
                          className="tap-expand-y flex items-center text-muted shrink-0 px-1 py-px -mx-1"
                        >
                          <MovesIcon />
                        </button>
                      )}
                    </span>
                    <span className="flex items-center gap-2 shrink-0 ml-auto">
                      {/* `w-*` DEĞİL `min-w-*` + `whitespace-nowrap` (2 Eylül
                          2026): tarayıcının asgari-yazı-boyutu ayarı puntoyu
                          büyütünce sabit px kutu metni sarıyor/taşırıyordu
                          (GameOver'da ölçüldü). Normal ölçekte etkisiz —
                          kutular zaten içerikten geniş. */}
                      <span className="min-w-9 whitespace-nowrap text-right">Puan</span>
                      {/* "SL" (Sanal Lig) yerine marka adı: küçük harf "k-lig"
                          — satır `uppercase` olduğundan `normal-case` şart
                          (yanındaki "Canlı" rozetiyle aynı gerekçe). Wordmark
                          (KLigMark) değil düz metin: 9px'te el yazısı okunmaz.
                          w-6→w-8: 5 karakter 9px mono + 0.5px tracking ile
                          24px'e sığmıyor (mobil portta da aynı genişlik). */}
                      <span className="min-w-8 whitespace-nowrap text-right normal-case">k-lig</span>
                    </span>
                  </div>
                  <div className="flex flex-col gap-0.5">
                    {players.map((p, i) => {
                      const points = leaguePoints(ranks[i], entry.player_count, p.surrendered, entry.ai_level);
                      return (
                        <div
                          key={i}
                          className="flex items-center justify-between gap-2 text-[12px] font-mono"
                        >
                          <span className="flex items-center gap-1.5 min-w-0">
                            <span className="min-w-3 whitespace-nowrap text-right text-muted shrink-0">{ranks[i]}.</span>
                            <PlayerBadge index={seatIndexFor(p, i, hasSnapshot)} size={14} />
                            <span className={`truncate ${i === meIndex ? 'text-text font-bold' : 'text-muted'}`}>
                              {i === meIndex && myCurrentName ? myCurrentName : p.name}
                            </span>
                            {p.surrendered && (
                              <span className="text-[8px] font-bold uppercase tracking-[0.5px] text-red border border-red/40 bg-red/10 rounded px-1 py-[1px] shrink-0">
                                Teslim Oldu
                              </span>
                            )}
                          </span>
                          <span className="flex items-center gap-2 shrink-0">
                            <span
                              className={`font-bold min-w-9 whitespace-nowrap text-right ${i === meIndex ? 'text-gold' : 'text-muted'}`}
                            >
                              {p.score}
                            </span>
                            <span
                              // Başlıkla (k-lig) aynı genişlik — ikisi de sağa
                              // hizalı, sağ kenarların çakışması için eşit
                              // olmak zorunda.
                              className={`font-bold min-w-8 whitespace-nowrap text-right ${points > 0 ? 'text-green' : points < 0 ? 'text-red' : 'text-muted'}`}
                            >
                              {formatLeaguePoints(points)}
                            </span>
                          </span>
                        </div>
                      );
                    })}
                    {unknownCount > 0 && (
                      <div className="text-[10px] font-mono text-muted italic pt-0.5">
                        +{unknownCount} diğer oyuncu (bu eski kayıtta bilinmiyor)
                      </div>
                    )}
                  </div>
                </div>
                {expanded && (
                  <div>
                    {snapshotLoadingId === entry.id ? (
                      <LoadingNote py="py-3" />
                    ) : snapshots[entry.id] ? (
                      <>
                        <div ref={boardCaptureRef} className="flex flex-col gap-1.5">
                          <ScoreBoxRow
                            players={players}
                            hasSnapshot={hasSnapshot}
                            meIndex={meIndex}
                            myCurrentName={myCurrentName}
                          />
                          <GameBoardPreview
                            snapshot={snapshots[entry.id]!}
                            playerCount={entry.player_count}
                            players={players}
                            onClick={() => setBoardSheetId(entry.id)}
                          />
                        </div>
                        {copiedId === entry.id && (
                          <p className="text-muted text-[10px] font-mono text-center pt-1.5">
                            Panoya kopyalandı
                          </p>
                        )}
                        {shareErrorId === entry.id && (
                          <p className="text-red text-[10px] font-mono text-center pt-1.5">
                            Panoya kopyalanamadı.
                          </p>
                        )}
                      </>
                    ) : snapshotErrorIds.has(entry.id) ? (
                      <div className="flex flex-col items-center gap-1.5 py-3">
                        <p className="text-red text-[10px] font-mono text-center">
                          Tahta önizlemesi yüklenemedi.
                        </p>
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            loadSnapshot(entry.id);
                          }}
                          className="text-accent text-[10px] font-mono font-bold uppercase tracking-[0.5px] hover:underline"
                        >
                          Tekrar Dene
                        </button>
                      </div>
                    ) : (
                      <p className="text-muted text-[10px] font-mono text-center py-3">
                        Bu oyun için tahta görüntüsü kaydedilmemiş.
                      </p>
                    )}
                  </div>
                )}
                {boardSheetId === entry.id && (
                  <ActionSheet
                    onClose={() => setBoardSheetId(null)}
                    actions={[
                      { label: 'Paylaş', onSelect: () => void handleShare(entry) },
                      // Rövanş yalnızca KENDİ geçmişinde ve yalnızca Canlı
                      // oyunlarda: `userId` doluysa admin başkasının
                      // geçmişine bakıyordur (o oyunun tarafı değil),
                      // `online_game_id` boşsa kayıt yerel bir YZ oyunudur.
                      ...(!userId && entry.online_game_id && user?.id
                        ? [
                            {
                              label: 'Tekrar Oyna',
                              onSelect: () =>
                                setRematch({
                                  gameId: entry.online_game_id!,
                                  playerCount: entry.player_count,
                                  names: players
                                    .filter((p, i) => !p.is_ai && i !== meIndex)
                                    .map((p) => p.name),
                                  withAi: players.some((p) => p.is_ai),
                                  phase: 'confirm',
                                }),
                            },
                          ]
                        : []),
                      { label: 'Kapat', onSelect: () => setExpandedId(null) },
                    ]}
                  />
                )}
              </div>
            );
          })}
          {hasMore && (
            <div ref={sentinelRef} className="py-2 text-center">
              <span className="text-muted text-[10px] font-mono">
                {loadingMore ? 'Yükleniyor…' : ''}
              </span>
            </div>
          )}
        </div>
      )}

      {likersGameId && (
        <Modal title="Beğenenler" onClose={() => setLikersGameId(null)}>
          {likersLoading ? (
            <LoadingNote py="py-4" />
          ) : (
            <ul className="flex flex-col gap-1">
              {(likersByGame[likersGameId] ?? []).map((liker) => {
                const name = likerName(liker);
                return (
                  <li key={liker.user_id}>
                    <button
                      type="button"
                      onClick={() => setSelectedLiker(likerToPlayerSummary(liker))}
                      className="w-full flex items-center gap-2 text-sm font-mono rounded-md px-2 py-1.5 text-left bg-bg active:opacity-70 transition-opacity"
                    >
                      <Avatar url={liker.avatar_url} name={name} size={22} className="shrink-0" />
                      <span className="flex-1 truncate text-text">{name}</span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </Modal>
      )}
      {selectedLiker && (
        <PlayerScoreCard member={selectedLiker} onClose={() => setSelectedLiker(null)} />
      )}
      {selectedChatGameId && (
        <GameChatHistoryModal
          gameId={selectedChatGameId}
          onlineGameId={games.find((g) => g.id === selectedChatGameId)?.online_game_id ?? null}
          onClose={() => setSelectedChatGameId(null)}
        />
      )}
      {selectedMovesGameId && (() => {
        const entry = games.find((g) => g.id === selectedMovesGameId);
        const rows = movesByGame[selectedMovesGameId];
        const close = () => setSelectedMovesGameId(null);
        if (movesLoading || !(selectedMovesGameId in movesByGame)) {
          return (
            <Modal title="Hamleler" onClose={close}>
              <LoadingNote py="py-4" />
            </Modal>
          );
        }
        if (movesError) {
          return (
            <Modal title="Hamleler" onClose={close}>
              <p className="text-muted text-xs font-mono text-center py-4">
                Hamleler yüklenemedi. Bağlantını kontrol edip tekrar dene.
              </p>
            </Modal>
          );
        }
        if (!rows || rows.length === 0) {
          // Kolon eklenmeden ÖNCE biten yerel oyunlar — veri hiç yazılmamış,
          // kurtarılamaz (tahta önizlemesindeki aynı durum).
          return (
            <Modal title="Hamleler" onClose={close}>
              <p className="text-muted text-xs font-mono text-center py-4">
                Bu oyun için hamle geçmişi kaydedilmemiş.
              </p>
            </Modal>
          );
        }
        // `MoveHistoryModal` yalnızca `moveHistory` ve `players`ı okuyor —
        // tahtaya hiç bakmadığından boş bir snapshot yeterli.
        const state = {
          ...buildSnapshotGameState([], entry?.player_count ?? 2, entry?.players ?? []),
          moveHistory: rows,
        };
        return <MoveHistoryModal state={state} onClose={close} />;
      })()}

      {/*
        Rövanş onayı — düzen/metin `OnlineGameScreen`deki ikiziyle BİREBİR
        (kullanıcı ikisini aynı iş sanıyor, çünkü öyleler). Biri değişirse
        öteki de. z-[200]: Modal 150, ActionSheet 160 — bunun ikisinin de
        üstünde kalması gerekiyor.
      */}
      {rematch && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none">
            <p className="text-base font-bold text-text font-sans">Tekrar Oyna</p>
            {rematch.phase === 'sent' ? (
              <>
                <p className="text-sm text-text font-sans leading-relaxed">Davetiniz gönderilmiştir.</p>
                <p className="text-xs text-muted font-mono leading-relaxed">
                  {rematch.names.join(', ')} yanıt verince oyun başlayacak.
                  {rematch.withAi && ' 4. koltuk Yapay Zeka.'}
                </p>
                <button
                  onClick={() => setRematch(null)}
                  className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
                >
                  Tamam
                </button>
              </>
            ) : rematch.phase === 'error' ? (
              <>
                <p className="text-sm text-red font-sans leading-relaxed">{rematch.message}</p>
                <button
                  onClick={() => setRematch(null)}
                  className="btn-raised-neutral py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
                >
                  Kapat
                </button>
              </>
            ) : (
              <>
                <p className="text-sm text-text font-sans leading-relaxed">
                  {rematch.names.join(', ')} ile aynı kadroda yeni bir oyun açılacak ve davet
                  gönderilecek.
                  {rematch.withAi && ' 4. koltuk yine Yapay Zeka olacak.'} Emin misin?
                </p>
                <div className="flex gap-2 mt-1">
                  <button
                    disabled={rematch.phase === 'busy'}
                    onClick={() => void handleRematch()}
                    className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-35"
                  >
                    {rematch.phase === 'busy' ? 'Gönderiliyor…' : 'Tekrar Oyna'}
                  </button>
                  <button
                    disabled={rematch.phase === 'busy'}
                    onClick={() => setRematch(null)}
                    className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-35"
                  >
                    Vazgeç
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </Modal>
  );
}
