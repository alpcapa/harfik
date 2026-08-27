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
import { RANK_TIERS, rewardAlreadyClaimed, type RankTier } from '../utils/leagueRank';

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
  // Sıradaki rütbeye ilerleme — mevcut kademenin eşiğinden sonrakine oran
  // (Meraklı 50 → Oyuncu 100 arasında 83 puan = %66). Puan negatifse
  // (yalnızca -2 cezalarıyla mümkün, kademe zaten Çaylak) 0'a kırpılır.
  const progress = nextTier
    ? Math.min(
        1,
        Math.max(0, (totalScore - tier.threshold) / (nextTier.threshold - tier.threshold)),
      )
    : 1;

  // Modal.tsx'in portal'ı z-[150] olduğundan bunun da portal + daha yüksek
  // z-index ile açılması gerekiyor — aksi halde Skor Kartı'nın altında kalırdı.
  return createPortal(
    <div
      className={`fixed inset-0 z-[200] flex items-center justify-center px-6 transition-colors duration-300 ${
        visible ? 'bg-black/40' : 'bg-transparent'
      }`}
      onClick={onClose}
    >
      {/* Gölge `shadow-raised` DEĞİL, `Modal.tsx`'in düz düşen gölgesi (12
          Ağustos 2026, kullanıcı bildirdi). `shadow-raised`in sol-üst beyaz
          parıltısı (-2 -2 5 rgba(255,255,255,.85)) nömorfik YÜZEYLER için
          tasarlandı; karartılmış zeminin (bg-black/40) üstünde yüzen bir
          kartta çirkin bir hale olarak okunuyordu. RewardBanner'ın kartı da
          aynı gün aynı gölgeye çekildi — ikisi aynı kart. */}
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label="Rütbe bilgisi"
        className={`relative w-[280px] max-w-full bg-bg border border-border rounded-2xl px-6 pt-6 pb-5 text-center shadow-[0_20px_45px_rgba(15,23,42,0.5)] ${
          visible ? 'reward-play' : ''
        }`}
        style={{ opacity: visible ? undefined : 0 }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Kapatma: kocaman bir "KAPAT" butonu yerine sağ üstte ✕ (12
            Ağustos 2026, kullanıcı isteği) — projedeki tüm modallerin
            (Modal.tsx) kapatma deseni bu; stil oradan birebir alındı. */}
        <button
          type="button"
          onClick={onClose}
          aria-label="Kapat"
          className="absolute top-2 right-2 text-muted hover:text-text text-lg leading-none tap-expand w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform focus:outline-none"
        >
          ✕
        </button>
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
              +{bonusPoints} eşik ödülü dahil
            </p>
          )}
          <p className="text-[11px] font-mono text-muted mt-2">
            {nextTier
              ? `Sıradaki rütbe: ${nextTier.name} · ${nextTier.threshold} puan`
              : 'En yüksek rütbedesin!'}
          </p>
          {nextTier && (
            <div className="mt-1.5">
              {/* İlerleme çubuğu — dolgu, kart görünür olduktan sonra 0'dan
                  gerçek orana animasyonla akar (width transition; visible
                  zaten bir rAF sonrası true olduğundan geçiş atlanmaz).
                  Renk SIRADAKİ kademenin rengi — hedefe doğru dolduğu için. */}
              <div
                className="h-2 rounded-full bg-panel border border-border overflow-hidden"
                role="progressbar"
                aria-valuemin={tier.threshold}
                aria-valuemax={nextTier.threshold}
                aria-valuenow={Math.min(totalScore, nextTier.threshold)}
                aria-label={`${nextTier.name} rütbesine ilerleme`}
              >
                <div
                  className="h-full rounded-full transition-[width] duration-700 ease-out"
                  style={{
                    width: visible ? `${Math.round(progress * 100)}%` : '0%',
                    background: nextTier.color,
                  }}
                />
              </div>
              {/* Eşik etiketlerinin altında o eşiğin tek seferlik ödülü.
                  Renk kuralı (12 Ağustos 2026, kullanıcı kararı): YEŞİL + ✓
                  yalnızca ALINMIŞ ödülde (kişi sonradan eşiğin altına düşse
                  bile yeşil ✓ kalır — ödül geri alınmıyor); henüz alınmamış
                  hedef ödülü GRİ. */}
              <div className="flex justify-between text-[9px] font-mono text-muted mt-0.5">
                <span className="flex flex-col items-start leading-tight">
                  <span>{tier.threshold}</span>
                  {tier.reward > 0 &&
                    (rewardAlreadyClaimed(tier, bonusPoints) ? (
                      <span className="text-green font-bold">(+{tier.reward})<span className="text-[13px] leading-none align-middle">✓</span></span>
                    ) : (
                      <span className="font-bold">(+{tier.reward})</span>
                    ))}
                </span>
                <span className="font-bold text-text">{totalScore}</span>
                <span className="flex flex-col items-end leading-tight">
                  {/* Hedef eşik: YALNIZCA SAYI (12 Ağustos 2026, kullanıcı
                      kararı). İlk sürüm "N puan" yazıyordu; "puan" kelimesi
                      hemen üstteki "Sıradaki rütbe: … · N puan" satırında
                      zaten geçtiğinden alt alta tekrar oluyordu — sayı
                      kalır, kelime kalkar. */}
                  <span>{nextTier.threshold}</span>
                  {nextTier.reward > 0 &&
                    (rewardAlreadyClaimed(nextTier, bonusPoints) ? (
                      <span className="text-green font-bold">(+{nextTier.reward})<span className="text-[13px] leading-none align-middle">✓</span></span>
                    ) : (
                      <span className="font-bold">(+{nextTier.reward})</span>
                    ))}
                </span>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>,
    document.body,
  );
}
