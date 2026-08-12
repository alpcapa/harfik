// Kelimeki — rütbe bilgi popup'ı: Skor Kartı/PlayerScoreCard başlığındaki
// mühre dokununca açılır (12 Ağustos 2026, kullanıcı isteği — "basınca bilgi
// versin, ekranda çıkan popup açılabilir tekrar"). RewardBanner'ın kart
// düzenini ve `reward-*` animasyon sınıflarını (index.css) paylaşır — mühür
// her açılışta yeniden "damgalanır". Kutlamadan farkı: `seen_at`'e hiç
// dokunmaz (salt bilgi), konfeti yok, içerikte güncel puan + ödül payı +
// sıradaki rütbe hedefi var. "Toplam puana +N oyun ödülü dahildir" bilgisi
// de artık ScoreStatsSection'daki dipnot yerine burada yaşıyor.
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { useModalA11y } from '../hooks/useModalA11y';
import { RankSeal } from './RankSeal';
import { RANK_TIERS, type RankTier } from '../utils/leagueRank';

interface RankInfoModalProps {
  tier: RankTier;
  totalScore: number;
  /** total_score'a dahil edilen oyun ödülü puanı (player_stats_overall.bonus_points). */
  bonusPoints: number;
  onClose: () => void;
}

export function RankInfoModal({ tier, totalScore, bonusPoints, onClose }: RankInfoModalProps) {
  const ref = useModalA11y(true, onClose);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const raf = requestAnimationFrame(() => setVisible(true));
    return () => cancelAnimationFrame(raf);
  }, []);

  const nextTier = RANK_TIERS.find((t) => t.threshold > tier.threshold) ?? null;

  // Modal.tsx'in portal'ı z-[150] olduğundan bunun da portal + daha yüksek
  // z-index ile açılması gerekiyor — aksi halde Skor Kartı'nın altında kalırdı.
  return createPortal(
    <div
      className={`fixed inset-0 z-[200] flex items-center justify-center px-6 transition-colors duration-300 ${
        visible ? 'bg-black/40' : 'bg-transparent'
      }`}
      onClick={onClose}
    >
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label="Rütbe bilgisi"
        className={`relative w-[280px] max-w-full bg-bg border border-border rounded-2xl px-6 pt-6 pb-5 text-center shadow-raised ${
          visible ? 'reward-play' : ''
        }`}
        style={{ opacity: visible ? undefined : 0 }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="reward-card-anim">
          <div className="reward-seal-anim mx-auto mb-2.5 w-[88px] h-[88px] rounded-full bg-panel shadow-raised flex items-center justify-center">
            <RankSeal tier={tier} size={76} />
          </div>
          <h2 className="text-base font-bold" style={{ color: tier.color }}>
            {tier.name}
          </h2>
          <p className="font-mono text-sm font-bold text-text mt-1.5">
            {totalScore} k-lig puanı
          </p>
          {bonusPoints > 0 && (
            <p className="reward-line-anim font-mono text-[11px] font-bold text-green mt-1">
              +{bonusPoints} oyun ödülü dahil
            </p>
          )}
          <p className="text-[11px] font-mono text-muted mt-2">
            {nextTier
              ? `Sıradaki rütbe: ${nextTier.name} · ${nextTier.threshold} puan`
              : 'En yüksek rütbedesin!'}
          </p>
          <button
            type="button"
            onClick={onClose}
            className="btn-raised bg-accent text-white border border-accent rounded-md font-sans text-sm font-bold uppercase tracking-[1px] px-8 py-2 mt-4 active:scale-[0.97] transition-transform"
          >
            Kapat
          </button>
        </div>
      </div>
    </div>,
    document.body,
  );
}
