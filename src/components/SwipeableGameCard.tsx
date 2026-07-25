// Kelimeki — sola kaydırınca sağda aksiyon butonları (favori/gör) açılan kart sarmalayıcısı
import { useEffect, useRef, useState } from 'react';

/** Açılınca sağda görünen aksiyon şeridinin genişliği (px) — iki eşit buton. */
export const SWIPE_ACTIONS_WIDTH = 104;

interface SwipeableGameCardProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  actions: React.ReactNode;
  children: React.ReactNode;
}

export function SwipeableGameCard({ open, onOpenChange, actions, children }: SwipeableGameCardProps) {
  const dragging = useRef(false);
  const moved = useRef(false);
  const startX = useRef(0);
  const startOffset = useRef(0);
  // `offset` state render'ı tetikler; `offsetRef` aynı değeri anlık (senkron)
  // tutar — hem pointer hem wheel (trackpad) olayları setState'in gecikmeli
  // uygulanmasını beklemeden en güncel konumu okuyabilsin diye (ör. bırakma
  // anında hangi tarafa "snap" edileceğine karar verirken).
  const offsetRef = useRef(open ? -SWIPE_ACTIONS_WIDTH : 0);
  const [offset, setOffset] = useState(offsetRef.current);
  const wheelTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  const setPos = (next: number) => {
    const clamped = Math.min(0, Math.max(-SWIPE_ACTIONS_WIDTH, next));
    offsetRef.current = clamped;
    setOffset(clamped);
  };

  // Başka bir kart açılıp bu kart dıştan kapatıldığında (ya da tersi) — sürükleme
  // sırasında değilsek anlık pozisyonu prop'a senkronize et.
  useEffect(() => {
    if (dragging.current) return;
    setPos(open ? -SWIPE_ACTIONS_WIDTH : 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    return () => {
      if (wheelTimeout.current) clearTimeout(wheelTimeout.current);
    };
  }, []);

  const commit = () => {
    const shouldOpen = offsetRef.current < -SWIPE_ACTIONS_WIDTH / 2;
    setPos(shouldOpen ? -SWIPE_ACTIONS_WIDTH : 0);
    if (shouldOpen !== open) onOpenChange(shouldOpen);
  };

  // Fare/dokunmatik kalem/parmak — hepsi PointerEvent üzerinden aynı akışla.
  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    dragging.current = true;
    moved.current = false;
    startX.current = e.clientX;
    startOffset.current = offsetRef.current;
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // Bazı tarayıcılarda pointer capture başarısız olabilir — sürükleme yine de çalışır.
    }
  };

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!dragging.current) return;
    const dx = e.clientX - startX.current;
    if (Math.abs(dx) > 4) moved.current = true;
    setPos(startOffset.current + dx);
  };

  const endDrag = () => {
    if (!dragging.current) return;
    dragging.current = false;
    commit();
  };

  // Trackpad'in iki parmakla yatay kaydırması (Mac'te yaygın) pointer olayı
  // DEĞİL, yatay deltaX'li bir wheel olayı üretir — bu yüzden ayrıca ele
  // alınması gerekiyor. Dikey scroll'a (liste kaydırma) dokunmuyoruz.
  const onWheel = (e: React.WheelEvent<HTMLDivElement>) => {
    if (Math.abs(e.deltaX) <= Math.abs(e.deltaY)) return;
    e.preventDefault();
    dragging.current = true;
    setPos(offsetRef.current - e.deltaX);
    if (wheelTimeout.current) clearTimeout(wheelTimeout.current);
    wheelTimeout.current = setTimeout(() => {
      dragging.current = false;
      commit();
    }, 120);
  };

  // Sürüklemeden sonra gelen click'i yutar; gerçek bir tıklama (dokunma/fare)
  // ise kartın aç/kapa durumunu tersine çevirir — sürükleme kadar düz
  // tıklama/dokunma da swipe'ı tetikler (aksiyon butonları bu katmanın
  // dışında olduğundan burada yakalanmaz).
  const onClickCapture = (e: React.MouseEvent<HTMLDivElement>) => {
    e.stopPropagation();
    e.preventDefault();
    if (moved.current) return;
    onOpenChange(!open);
  };

  return (
    <div className="relative overflow-hidden rounded-md">
      <div
        className="absolute inset-y-0 right-0 flex items-stretch overflow-hidden rounded-md"
        style={{ width: SWIPE_ACTIONS_WIDTH }}
      >
        {actions}
      </div>
      <div
        className="relative cursor-grab active:cursor-grabbing"
        style={{
          transform: `translateX(${offset}px)`,
          transition: dragging.current ? 'none' : 'transform 0.2s ease',
          touchAction: 'pan-y',
          userSelect: 'none',
          WebkitUserSelect: 'none',
        }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onWheel={onWheel}
        onClickCapture={onClickCapture}
      >
        {children}
      </div>
    </div>
  );
}
