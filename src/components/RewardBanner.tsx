// Kelimeki — k-lig kutlama banner'ı ("Mühür" konsepti animasyonu): kart
// alttan yaylanarak gelir, mühür 2× boyuttan küçülerek damgalanır, konfeti
// patlar, ödül satırı belirir. Görülmemiş `league_rewards` satırlarından
// LeagueRewardsHost'un ürettiği TEK birleşik özeti gösterir (satır başına
// ayrı popup yok — geçmişe dönük backfill'de bile tek banner).
//
// ActionSheet dersi (CLAUDE.md): alt/kenar yerine EKRAN ORTASINDA açılır ve
// arka planı karartır + animasyon `visible` state'inin bir rAF sonrası true
// olmasıyla tetiklenir (mount anında son durumda render edilirse tarayıcı
// CSS geçişini atlar).
import { useEffect, useState } from 'react';
import { useModalA11y } from '../hooks/useModalA11y';
import { RankSeal } from './RankSeal';
import { tierFor, type RankTier } from '../utils/leagueRank';

/** LeagueRewardsHost'un görülmemiş satırlardan damıttığı birleşik özet. */
export interface RewardSummary {
  /** Yeni ulaşılan en yüksek rütbe (varsa) — banner'ın ana konusu olur. */
  rankUpTier?: RankTier;
  /** Ulaşılan en yüksek puan kilometre taşı (100/200/300…, varsa). */
  milestone?: number;
  /** Kazanılan toplam eşik ödülü puanı (0 = yok). */
  rewardPoints: number;
  /** Ödülü tetikleyen en yüksek PUAN eşiği (50/100/200/500/1000 — 12 Ağustos
   * 2026'dan beri ödüller oyun sayısına değil puan eşiğine bağlı). */
  rewardThreshold?: number;
  /**
   * Rütbe düşüş bildirimi — YALNIZCA hiçbir olumlu olay yokken doldurulur
   * (LeagueRewardsHost öncelik kuralı: olumlu varsa üzgün banner bastırılır).
   * `fromThreshold` altına inilen eşik, `newTier` yeni (alt) kademe,
   * `currentPoints` banner anındaki güncel toplam (host ayrıca çeker) —
   * ilerleme çubuğunun dolgusu için; çekilemezse çubuk gizlenir.
   */
  rankDown?: { fromThreshold: number; newTier: RankTier; currentPoints?: number };
}

// Konfeti parçacıkları — merkezden dışa savrulan 8 nokta (CSS değişkenleriyle
// yön, index.css'teki `reward-burst` keyframe'i).
const CONFETTI: { dx: number; dy: number; color: string }[] = [
  { dx: -90, dy: -70, color: '#2563EB' },
  { dx: 80, dy: -90, color: '#B7791F' },
  { dx: -110, dy: 10, color: '#16A34A' },
  { dx: 110, dy: -10, color: '#F2650F' },
  { dx: -60, dy: -110, color: '#DC2626' },
  { dx: 55, dy: -120, color: '#2563EB' },
  { dx: -95, dy: -30, color: '#F2650F' },
  { dx: 95, dy: 40, color: '#16A34A' },
];

interface RewardBannerProps {
  summary: RewardSummary;
  onClose: () => void;
}

export function RewardBanner({ summary, onClose }: RewardBannerProps) {
  const ref = useModalA11y(true, onClose);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const raf = requestAnimationFrame(() => setVisible(true));
    return () => cancelAnimationFrame(raf);
  }, []);

  const { rankUpTier, milestone, rewardPoints, rewardThreshold, rankDown } = summary;

  // Öncelik: rütbe atlama > kilometre taşı > yalnızca eşik ödülü.
  // rankDown yalnızca hiçbir olumlu olay yokken dolu gelir (host garantisi) —
  // üzgün varyant: konfeti yok, yeni (alt) kademenin mührü + nazik metin.
  const tier = rankDown
    ? rankDown.newTier
    : (rankUpTier ?? tierFor(milestone ?? rewardThreshold ?? 0));
  const glyph = rankDown
    ? rankDown.newTier.letter
    : rankUpTier
      ? rankUpTier.letter
      : milestone
        ? String(milestone)
        : `+${rewardPoints}`;
  const title = rankDown
    ? 'Rütben geriledi'
    : rankUpTier
      ? `Yeni rütben: ${rankUpTier.name}!`
      : milestone
        ? `${milestone} k-lig puanına ulaştın!`
        : 'Eşik ödülü kazandın!';
  // "X k-lig puanına ulaştın" alt satırı — ulaşılan en yüksek eşik (rütbe/
  // kilometre taşı/ödül hangisi büyükse). Başlık zaten aynı bilgiyi veren
  // milestone-only durumda tekrarlanmaz.
  const reachedPoints = Math.max(rankUpTier?.threshold ?? 0, milestone ?? 0, rewardThreshold ?? 0);

  return (
    <div
      className={`fixed inset-0 z-50 flex items-center justify-center px-6 transition-colors duration-300 ${
        visible ? 'bg-black/40' : 'bg-transparent'
      }`}
    >
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label="k-lig ödülü"
        className={`relative w-[280px] max-w-full bg-bg border border-border rounded-2xl px-6 pt-6 pb-5 text-center shadow-raised ${
          visible ? 'reward-play' : ''
        }`}
        style={{ opacity: visible ? undefined : 0 }}
      >
        <div className="reward-card-anim">
          <div className="reward-seal-anim mx-auto mb-2.5 w-[88px] h-[88px] rounded-full bg-panel shadow-raised flex items-center justify-center">
            <RankSeal tier={tier} glyph={glyph} size={76} />
          </div>
          <h2 className="text-base font-bold text-text">{title}</h2>
          {rankDown ? (
            <>
              {/* Sayıya iyelik eki YOK ("50'nin/100'ün" ünlü uyumu isme göre
                  değişirdi) — "X eşiğinin altına" kalıbı her eşikte çalışır,
                  bkz. CLAUDE.md "Sıra: {isim}" dersi. */}
              <p className="text-[11px] font-mono text-muted mt-1">
                Üzgünüz — puanın {rankDown.fromThreshold} eşiğinin altına indi.
                Yeni rütben: <b style={{ color: rankDown.newTier.color }}>{rankDown.newTier.name}</b>
              </p>
              <p className="reward-line-anim font-mono text-[11px] font-bold text-accent mt-1.5">
                Kazandıkça geri yükselirsin!
              </p>
              {rankDown.currentPoints !== undefined && (
                <div className="mt-2 text-left">
                  {/* Kaybedilen eşiğe geri dönüş çubuğu — RankInfoModal'daki
                      aynı desen. Hedef etiketin altında BİLEREK "(0)": bu
                      eşiğin ödülü zaten alındı, yeniden aşmak ikinci kez
                      ödül VERMEZ (kullanıcı isteği — yanlış beklenti
                      oluşmasın). */}
                  <div
                    className="h-2 rounded-full bg-panel border border-border overflow-hidden"
                    role="progressbar"
                    aria-valuemin={rankDown.newTier.threshold}
                    aria-valuemax={rankDown.fromThreshold}
                    aria-valuenow={Math.min(rankDown.currentPoints, rankDown.fromThreshold)}
                    aria-label="Kaybedilen rütbeye geri dönüş ilerlemesi"
                  >
                    <div
                      className="h-full rounded-full transition-[width] duration-700 ease-out"
                      style={{
                        width: visible
                          ? `${Math.round(
                              Math.min(
                                1,
                                Math.max(
                                  0,
                                  (rankDown.currentPoints - rankDown.newTier.threshold) /
                                    (rankDown.fromThreshold - rankDown.newTier.threshold),
                                ),
                              ) * 100,
                            )}%`
                          : '0%',
                        background: tierFor(rankDown.fromThreshold).color,
                      }}
                    />
                  </div>
                  <div className="flex justify-between text-[9px] font-mono text-muted mt-0.5">
                    <span>{rankDown.newTier.threshold}</span>
                    <span className="font-bold text-text">{rankDown.currentPoints}</span>
                    <span className="flex flex-col items-end leading-tight">
                      <span>{rankDown.fromThreshold}</span>
                      <span className="font-bold">(0)</span>
                    </span>
                  </div>
                </div>
              )}
            </>
          ) : (
            <>
              {(rankUpTier || (!milestone && rewardThreshold)) && reachedPoints > 0 ? (
                <p className="text-[11px] font-mono text-muted mt-1">
                  {reachedPoints} k-lig puanına ulaştın
                </p>
              ) : null}
              {rewardPoints > 0 && (
                <p className="reward-line-anim font-mono text-sm font-bold text-green mt-1.5">
                  +{rewardPoints} ödül puanı eklendi
                </p>
              )}
            </>
          )}
          <button
            type="button"
            onClick={onClose}
            className="btn-raised bg-accent text-white border border-accent rounded-md font-sans text-sm font-bold uppercase tracking-[1px] px-8 py-2 mt-4 active:scale-[0.97] transition-transform"
          >
            Devam
          </button>
        </div>
        {rankDown ? null : (
        <div className="absolute inset-0 pointer-events-none overflow-visible" aria-hidden="true">
          {CONFETTI.map((c, i) => (
            <span
              key={i}
              className="reward-confetti absolute left-1/2 top-[38%] w-[7px] h-[7px] rounded-[2px]"
              style={
                {
                  background: c.color,
                  '--dx': `${c.dx}px`,
                  '--dy': `${c.dy}px`,
                } as React.CSSProperties
              }
            />
          ))}
        </div>
        )}
      </div>
    </div>
  );
}
