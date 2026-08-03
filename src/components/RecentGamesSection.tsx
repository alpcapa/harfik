// Kelimeki — "Son Oynadıklarım": hem "Yapay Zeka ile" hem "Arkadaşınla"
// sekmelerinde, o sekmenin türüne uygun (yerel/Canlı) son 5 biten oyunu
// gösteren kompakt liste. Bir satıra tıklamak Tüm Oyunlarım'ı
// (`GameHistoryModal`) doğrudan o oyunun tahta önizlemesi açık hâlde açar —
// ayrı bir mini tahta/sohbet gösterimi yazmak yerine mevcut modalın tüm
// davranışını (paylaş/beğen/sohbet geçmişi) olduğu gibi devralır.
import { useEffect, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { fetchMyGames } from '../lib/api';
import type { GameHistoryEntry } from '../lib/database.types';
import { leaguePoints, formatLeaguePoints } from '../utils/leaguePoints';
import { GameHistoryModal } from './GameHistoryModal';
import { PlayerAvatarRow } from './PlayerAvatarRow';

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('tr-TR');
}

// Eski (rank hiç yazılmamış) kayıtlarda bile en azından 1./2. tahmini için
// puan karşılaştırmasına düşülür — GameHistoryModal'daki fallbackPlayers'ın
// aynı ilkesi.
function rankFor(entry: GameHistoryEntry): number {
  return entry.rank ?? (entry.player_score >= entry.ai_score ? 1 : 2);
}

// 2 kişilik bir oyunda rakibin adını (varsa donmuş `players` anlık
// görüntüsünden) gösterir. Canlı 4 kişilik bir oyunda rakiplerin hepsi
// gerçek kişiler olabildiğinden (kimle oynadığını görmek anlamlı) hepsi
// yan yana virgülle yazılır; yerel (Yapay Zeka) 4 kişilik oyunlarda
// rakipler zaten hep YZ olduğundan bu bilgi eklemez, jenerik "N Kişilik
// Oyun" başlığına düşülür.
function titleFor(entry: GameHistoryEntry): string {
  if (!entry.players || entry.players.length < 2) return `${entry.player_count} Kişilik Oyun`;
  const meIdx = rankFor(entry) - 1;
  const others = entry.players.filter((_, i) => i !== meIdx);
  if (entry.player_count === 2 && others.length === 1) {
    return others[0].is_ai ? 'Yapay Zeka' : others[0].name;
  }
  if (entry.online_game_id && others.length > 0) {
    return others.map((p) => (p.is_ai ? 'Yapay Zeka' : p.name)).join(', ');
  }
  return `${entry.player_count} Kişilik Oyun`;
}

interface RecentGamesSectionProps {
  /** true: yalnızca Canlı (Arkadaşınla) oyunlar, false: yalnızca Yapay Zeka. */
  onlineOnly: boolean;
  /**
   * Verilirse, hiç bitmiş oyun yokken (ya da henüz yüklenmemişken) sessizce
   * `null` dönmek yerine bu metni gösterir — `LiveGamesTab`'daki "Son
   * Oynanan" sekmesi gibi, bileşenin TEK içerik olduğu bir sekme/alan boş
   * kaldığında kullanıcıya hâlâ bir şeyin orada olması gerektiğini
   * hatırlatmak için. Verilmezse eski davranış (boşsa hiçbir şey
   * render etmeme) aynen korunur — ör. "Yapay Zeka ile" sekmesinde ya da
   * Canlı oyun kurulum formunun altında, zaten başka içerik olduğundan
   * boş bir mesaj gösterilmesine gerek yok.
   */
  emptyMessage?: string;
}

export function RecentGamesSection({ onlineOnly, emptyMessage }: RecentGamesSectionProps) {
  const { user } = useAuth();
  const [games, setGames] = useState<GameHistoryEntry[] | null>(null);
  const [focusedId, setFocusedId] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);

  useEffect(() => {
    if (!user) {
      setGames(null);
      return;
    }
    let cancelled = false;
    fetchMyGames(null, 0, 5, undefined, false, onlineOnly).then(({ games: rows }) => {
      if (!cancelled) setGames(rows);
    });
    return () => {
      cancelled = true;
    };
  }, [user, onlineOnly]);

  // Girişsiz kullanıcı için oyun geçmişi hiç yok; henüz yüklenmediyse ya da
  // hiç bitmiş oyun yoksa da bilerek sessizce gizleniyor — boş bir bölüm
  // başlığı göstermenin bir değeri yok. `emptyMessage` verilmişse (bileşen
  // kendi başına bir sekmenin tek içeriğiyse) bunun yerine o metin gösterilir.
  if (!user) return null;
  if (!games) return emptyMessage ? <p className="text-center text-xs text-muted font-mono py-8">Yükleniyor…</p> : null;
  if (games.length === 0) return emptyMessage ? <p className="text-center text-xs text-muted font-mono py-8">{emptyMessage}</p> : null;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Son Oynadıklarım
        </div>
        <button
          onClick={() => setShowAll(true)}
          className="text-[10px] font-mono font-bold uppercase tracking-[0.5px] text-accent active:opacity-70 transition-opacity"
        >
          Tüm Oyunlarım
        </button>
      </div>
      <div className="flex flex-col gap-2">
        {games.map((g) => {
          const points = leaguePoints(rankFor(g), g.player_count, g.surrendered);
          return (
            <button
              key={g.id}
              onClick={() => setFocusedId(g.id)}
              className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left active:scale-[0.99] transition-transform"
            >
              <span className="flex-1 min-w-0 flex flex-col gap-0.5">
                {/* Rakip isimlerinin yerine katılımcı avatarları. Dondurulmuş
                    `players` anlık görüntüsü avatar_url TAŞIMIYOR (bilerek —
                    o snapshot girişli herkese açık, bkz. GamePlayerSnapshot),
                    bu yüzden burada her zaman baş harfler görünür; fotoğraflar
                    yalnızca Canlı kartlarında çıkar. Snapshot'ı hiç olmayan
                    eski kayıtlarda ise eski metin başlığına düşülüyor. */}
                {g.players && g.players.length > 0 ? (
                  <PlayerAvatarRow players={g.players.map((p) => ({ name: p.name }))} />
                ) : (
                  <span className="font-sans text-[12px] font-bold text-text truncate">{titleFor(g)}</span>
                )}
                <span className="text-[9px] font-mono text-muted truncate">{formatDate(g.created_at)}</span>
              </span>
              <span className="flex items-center gap-2 shrink-0">
                <span className="font-mono text-[11px] font-bold text-text">{g.player_score}</span>
                <span
                  className={`font-mono text-[11px] font-bold ${
                    points > 0 ? 'text-green' : points < 0 ? 'text-red' : 'text-muted'
                  }`}
                >
                  {formatLeaguePoints(points)}
                </span>
              </span>
            </button>
          );
        })}
      </div>

      {(focusedId || showAll) && (
        <GameHistoryModal
          playerCount={null}
          onClose={() => {
            setFocusedId(null);
            setShowAll(false);
          }}
          initialExpandedId={focusedId ?? undefined}
        />
      )}
    </div>
  );
}
