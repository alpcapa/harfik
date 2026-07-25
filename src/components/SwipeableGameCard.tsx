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
  const [offset, setOffset] = useState(open ? -SWIPE_ACTIONS_WIDTH : 0);

  // Başka bir kart açılıp bu kart dıştan kapatıldığında (ya da tersi) — sürükleme
  // sırasında değilsek anlık pozisyonu prop'a senkronize et.
  useEffect(() => {
    if (dragging.current) return;
    setOffset(open ? -SWIPE_ACTIONS_WIDTH : 0);
  }, [open]);

  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    dragging.current = true;
    moved.current = false;
    startX.current = e.clientX;
    startOffset.current = offset;
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
    setOffset(Math.min(0, Math.max(-SWIPE_ACTIONS_WIDTH, startOffset.current + dx)));
  };

  const endDrag = () => {
    if (!dragging.current) return;
    dragging.current = false;
    const shouldOpen = offset < -SWIPE_ACTIONS_WIDTH / 2;
    setOffset(shouldOpen ? -SWIPE_ACTIONS_WIDTH : 0);
    if (shouldOpen !== open) onOpenChange(shouldOpen);
  };

  // Sürüklemeden (gerçek bir tıklamadan) sonra gelen click'i yutar; kart açıkken
  // içeriğe düz tıklama kartı kapatır (aksiyon butonları bu katmanın dışında
  // olduğundan burada yakalanmaz).
  const onClickCapture = (e: React.MouseEvent<HTMLDivElement>) => {
    if (moved.current) {
      e.stopPropagation();
      e.preventDefault();
      return;
    }
    if (open) {
      e.stopPropagation();
      e.preventDefault();
      onOpenChange(false);
    }
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
        className="relative"
        style={{
          transform: `translateX(${offset}px)`,
          transition: dragging.current ? 'none' : 'transform 0.2s ease',
          touchAction: 'pan-y',
        }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onClickCapture={onClickCapture}
      >
        {children}
      </div>
    </div>
  );
}
