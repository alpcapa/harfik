// Kelimeki — oturum açan kullanıcının geçmiş tüm oyunlarının listesi (lazy load)
import { useCallback, useEffect, useRef, useState } from 'react';
import { Modal } from './Modal';
import { fetchMyGames, fetchGameBoardSnapshot, toggleGameFavorite, markGameShared } from '../lib/api';
import type { BoardSnapshotTile, GameHistoryEntry, GamePlayerSnapshot } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';
import { PLAYER_COLORS } from '../game/constants';
import { PlayerBadge } from './PlayerBadge';
import { GameBoardPreview } from './GameBoardPreview';
import { SwipeableGameCard } from './SwipeableGameCard';
import { ActionSheet } from './ActionSheet';
import { captureNodeAsPng } from '../utils/shareBoardImage';

interface GameHistoryModalProps {
  playerCount: number;
  onClose: () => void;
  /** Verilirse (admin panelindeki oyuncu detayı) oturum sahibi yerine bu kullanıcının geçmişi gösterilir. */
  userId?: string;
  /** Verilirse varsayılan "Tüm Oyunlar · N Oyunculu" başlığının yerine geçer. */
  title?: string;
}

const PAGE_SIZE = 20;

function formatDateTime(iso: string): string {
  const d = new Date(iso);
  const date = d.toLocaleDateString('tr-TR');
  const time = d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
  return `${date} · ${time}`;
}

/**
 * Bir oyuncunun bu oyundan kazandığı Sanal Lig puanı — leaderboard/
 * player_stats view'larıyla aynı formül: teslim → -2, 1. → +2, 2. (yalnızca
 * 2 kişilik değilse) → +1, diğerleri 0.
 */
function leaguePoints(rank: number, playerCount: number, surrendered?: boolean): number {
  if (surrendered) return -2;
  if (rank === 1) return 2;
  if (rank === 2 && playerCount !== 2) return 1;
  return 0;
}

function formatLeaguePoints(points: number): string {
  return points > 0 ? `+${points}` : points < 0 ? `${points}` : '-';
}

/**
 * `players` zaten final sıralamasına göre (aktifler puana göre azalan,
 * teslim olanlar en sonda) diziliymiş durumda — burada yalnızca eşit
 * puanlı (ve aynı teslim durumundaki) bitişik oyunculara aynı sırayı
 * vererek gerçek "rank"i (dizideki ham pozisyon değil) çıkarıyoruz.
 * Aksi halde beraberlikte 2. sıradaki oyuncu, 1.yle aynı puanı almasına
 * rağmen SL sütununda 0 gösteriyordu.
 */
function computeRanks(players: GamePlayerSnapshot[]): number[] {
  let rank = 1;
  let prevScore: number | null = null;
  let prevSurrendered = false;
  return players.map((p, i) => {
    if (prevScore === null || p.score !== prevScore || !!p.surrendered !== prevSurrendered) {
      rank = i + 1;
    }
    prevScore = p.score;
    prevSurrendered = !!p.surrendered;
    return rank;
  });
}

/**
 * Eski kayıtlarda (players alanı eklenmeden önce oynanmış oyunlarda) yalnızca
 * kendi puanın ve en iyi rakibin puanı bilinir — diğer oyuncuların adı/puanı
 * saklanmamıştır. Bilinen iki satırı döner; kalan oyuncu sayısını ve kendi
 * satırının indeksini ayrıca verir.
 */
function fallbackPlayers(
  entry: GameHistoryEntry,
): { known: GamePlayerSnapshot[]; unknownCount: number; meIndex: number } {
  const me: GamePlayerSnapshot = { name: 'Sen', score: entry.player_score, is_ai: false };
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

/** Paylaş aksiyonunun sabit metni — skor/tarih artık görselin kendisinde (bkz. aşağı). */
const SHARE_MESSAGE = "Kelimeki'de oynadığım bu oyun çok iyidi.";

/** Herkese açık paylaşım sayfası — bkz. `SharedGamePage`/`main.tsx`'teki path kontrolü. */
function buildShareUrl(gameId: string): string {
  return `${window.location.origin}/game/${gameId}`;
}

function HeartIcon({ filled }: { filled: boolean }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill={filled ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
    </svg>
  );
}

function EyeIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

/**
 * Tahta önizlemesinin üstünde tek satır skor kutuları — `GameHeader`'daki
 * oyun içi skor kutularıyla aynı görsel dil (renk = zone.tint dolgu +
 * base çerçeve, üstte isim, altta puan), yalnızca burada dört kutu da
 * eşit genişlikte (flex-1) tek satıra sığacak şekilde küçültülmüş.
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
            className="flex-1 min-w-0 shadow-raised text-center rounded-md py-1 px-1"
            style={{ background: col.tint, boxShadow: `inset 0 0 0 1.5px ${col.base}` }}
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

export function GameHistoryModal({ playerCount, onClose, userId, title }: GameHistoryModalProps) {
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
  const fetchedIds = useRef<Set<string>>(new Set());

  // Sola kaydırılıp aksiyonları (favori/gör) açık olan tek kart — aynı anda
  // yalnızca biri açık olabilir.
  const [openSwipeId, setOpenSwipeId] = useState<string | null>(null);

  // Tahta önizlemesine tıklanınca açılan Kapat/Paylaş aksiyon menüsü.
  const [boardSheetId, setBoardSheetId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const copiedTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Aynı anda yalnızca bir oyunun tahtası genişletilmiş olabildiğinden
  // (expandedId tek bir id) paylaş için görseli buradan yakalıyoruz — tek ref yeterli.
  const boardCaptureRef = useRef<HTMLDivElement | null>(null);

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
      await navigator.clipboard.writeText(url ? `${text}\n${url}` : text);
      setCopiedId(entry.id);
      if (copiedTimeout.current) clearTimeout(copiedTimeout.current);
      copiedTimeout.current = setTimeout(() => setCopiedId(null), 1800);
    }
  }, []);

  const handleViewBoard = useCallback((gameId: string) => {
    setOpenSwipeId(null);
    setExpandedId((cur) => (cur === gameId ? null : gameId));
    if (fetchedIds.current.has(gameId)) return;
    fetchedIds.current.add(gameId);
    setSnapshotLoadingId(gameId);
    void fetchGameBoardSnapshot(gameId).then((snap) => {
      setSnapshots((c) => ({ ...c, [gameId]: snap }));
      setSnapshotLoadingId((id) => (id === gameId ? null : id));
    });
  }, []);

  const handleToggleFavorite = useCallback((gameId: string) => {
    setOpenSwipeId(null);
    setGames((cur) => cur.map((g) => (g.id === gameId ? { ...g, favorited: !g.favorited } : g)));
    void toggleGameFavorite(gameId).then((result) => {
      if (result === null) {
        // İstek başarısız oldu (ör. çevrimdışı) — iyimser güncellemeyi geri al.
        setGames((cur) => cur.map((g) => (g.id === gameId ? { ...g, favorited: !g.favorited } : g)));
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
    setOpenSwipeId(null);
    setBoardSheetId(null);
    fetchedIds.current.clear();
    void fetchMyGames(playerCount, 0, PAGE_SIZE, userId, favoritesOnly).then(({ games: page, hasMore: more }) => {
      if (cancelled) return;
      setGames(page);
      setHasMore(more);
      setLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [playerCount, userId, favoritesOnly]);

  const loadMore = useCallback(() => {
    setLoadingMore((already) => {
      if (already) return already;
      void fetchMyGames(playerCount, games.length, PAGE_SIZE, userId, favoritesOnly).then(({ games: page, hasMore: more }) => {
        setGames((cur) => [...cur, ...page]);
        setHasMore(more);
        setLoadingMore(false);
      });
      return true;
    });
  }, [playerCount, games.length, userId, favoritesOnly]);

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
    <Modal title={title ?? `Tüm Oyunlar · ${playerCount} Oyunculu`} onClose={onClose}>
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
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : games.length === 0 ? (
        <p className="text-muted text-[10px] font-mono text-center py-4">
          {favoritesOnly ? 'Henüz favori işaretlediğin bir oyun yok.' : 'Bu kategoride henüz kayıtlı oyun yok.'}
        </p>
      ) : (
        <div ref={scrollRef} className="flex flex-col gap-2 max-h-[65vh] overflow-y-auto pr-1">
          {games.map((entry) => {
            const hasSnapshot = !!entry.players && entry.players.length > 0;
            const fallback = hasSnapshot ? null : fallbackPlayers(entry);
            const players = hasSnapshot ? entry.players! : fallback!.known;
            const unknownCount = fallback?.unknownCount ?? 0;
            const meIndex = hasSnapshot ? findMeIndex(entry, players) : fallback!.meIndex;
            const ranks = computeRanks(players);
            const expanded = expandedId === entry.id;
            return (
              <div key={entry.id} className="flex flex-col gap-1.5">
                <SwipeableGameCard
                  open={openSwipeId === entry.id}
                  onOpenChange={(open) => setOpenSwipeId(open ? entry.id : null)}
                  actions={
                    <>
                      <button
                        onClick={() => handleToggleFavorite(entry.id)}
                        aria-label={entry.favorited ? 'Favoriden çıkar' : 'Favoriye ekle'}
                        className="flex-1 flex items-center justify-center bg-red text-white active:opacity-80"
                      >
                        <HeartIcon filled={entry.favorited} />
                      </button>
                      <button
                        onClick={() => handleViewBoard(entry.id)}
                        aria-label="Tahtayı gör"
                        className="flex-1 flex items-center justify-center bg-accent text-white active:opacity-80"
                      >
                        <EyeIcon />
                      </button>
                    </>
                  }
                >
                  <div className="shadow-raised bg-bg border border-border rounded-md py-2 px-2.5 flex flex-col gap-1.5">
                    <div className="flex items-center justify-between gap-2 text-[9px] font-mono text-muted uppercase tracking-[0.5px]">
                      <span className="flex items-center gap-1">
                        {entry.favorited && (
                          <span className="text-red">
                            <HeartIcon filled />
                          </span>
                        )}
                        {formatDateTime(entry.created_at)}
                      </span>
                      <span className="flex items-center gap-2 shrink-0">
                        <span className="w-9 text-right">Puan</span>
                        <span className="w-6 text-right">SL</span>
                      </span>
                    </div>
                    <div className="flex flex-col gap-0.5">
                      {players.map((p, i) => {
                        const points = leaguePoints(ranks[i], entry.player_count, p.surrendered);
                        return (
                          <div
                            key={i}
                            className="flex items-center justify-between gap-2 text-[12px] font-mono"
                          >
                            <span className="flex items-center gap-1.5 min-w-0">
                              <span className="w-3 text-right text-muted shrink-0">{ranks[i]}.</span>
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
                                className={`font-bold w-9 text-right ${i === meIndex ? 'text-gold' : 'text-muted'}`}
                              >
                                {p.score}
                              </span>
                              <span
                                className={`font-bold w-6 text-right ${points > 0 ? 'text-green' : points < 0 ? 'text-red' : 'text-muted'}`}
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
                </SwipeableGameCard>
                {expanded && (
                  <div>
                    {snapshotLoadingId === entry.id ? (
                      <p className="text-muted text-[10px] font-mono text-center py-3">Yükleniyor…</p>
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
                      </>
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
    </Modal>
  );
}
