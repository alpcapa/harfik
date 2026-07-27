// Kelimeki — paylaşılan modal kabuğu
import { useId, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useModalA11y } from '../hooks/useModalA11y';

interface ModalProps {
  title: string;
  onClose: () => void;
  children: ReactNode;
  // Başlığın hemen üstünde gösterilen küçük bir gezinme linki (ör. HelpModal'ın
  // Hızlı Başlangıç ↔ Detaylı Kurallar geçişi).
  headerLink?: ReactNode;
}

export function Modal({ title, onClose, children, headerLink }: ModalProps) {
  const containerRef = useModalA11y(true, onClose);
  const titleId = useId();
  return createPortal(
    <div
      className="fixed inset-0 z-[150] flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        ref={containerRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        className="w-full max-w-[360px] bg-panel border border-[#B8C2D1] rounded-xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] max-h-[85vh] flex flex-col overflow-hidden outline-none"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="shrink-0 flex flex-col gap-2 px-5 pt-5 pb-4 border-b border-border">
          {headerLink}
          <div className="flex items-center justify-between">
            <h2 id={titleId} className="font-mono text-sm font-bold tracking-[1.5px] uppercase text-accent">
              {title}
            </h2>
            {/* Çoğu modalda headerLink olmadığından bu, DOM'daki ilk odaklanabilir
                öğe oluyor — useModalA11y açılışta buraya otomatik odaklanıyor,
                bu yüzden tarayıcının varsayılan mavi focus halkası her modal
                açılışında görünür oluyordu. */}
            <button
              onClick={onClose}
              aria-label="Kapat"
              className="text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform focus:outline-none"
            >
              ✕
            </button>
          </div>
        </div>
        <div className="overflow-y-auto px-5 pt-4 pb-5">{children}</div>
      </div>
    </div>,
    document.body,
  );
}
