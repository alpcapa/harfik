// Kelimeki — paylaşılan modal kabuğu
import { useId, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useModalA11y } from '../hooks/useModalA11y';

interface ModalProps {
  title: ReactNode;
  onClose: () => void;
  children: ReactNode;
  // Başlığın hemen üstünde gösterilen küçük bir gezinme linki (ör. HelpModal'ın
  // Hızlı Başlangıç ↔ Detaylı Kurallar geçişi).
  headerLink?: ReactNode;
  // Başlığın YANINDA, kapat butonunun solunda gösterilen küçük bir aksiyon
  // ikonu (ör. ChatModal'ın Ayarlar/dişli ikonu, Oyun İçi Mesajlaşma — Faz 2).
  // headerLink'in aksine aynı satırda, başlıkla ✕ arasında render edilir.
  headerAction?: ReactNode;
  // Başlık ile ✕ arasındaki BOŞLUĞUN ortasında gösterilen öğe (ör. Skor
  // Kartı'nın rütbe mührü). headerAction'dan farkı hizalama: o ✕'e bitişik
  // sağda durur, bu ikisinin arasında ortalanır. Verilmezse hiçbir şey
  // değişmez (justify-between eski davranışı korur).
  headerCenter?: ReactNode;
}

export function Modal({ title, onClose, children, headerLink, headerAction, headerCenter }: ModalProps) {
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
        {/* headerLink varken üst dolgu 20 → 3 ve aradaki gap YOK: link
            artık 48px'lik bir dokunma hedefi (`min-h-[48px]`) ve metni o
            kutunun ORTASINDA duruyor, yani 3 + 24 = 27 → metnin üst
            kenarı yine 20'de. Telafi olmasa başlık 34px aşağı kayardı;
            böyle yalnızca 9px uzuyor. Flutter portu (`modal_shell.dart`)
            aynı telafiyi taşıyor. */}
        <div className={`shrink-0 flex flex-col px-5 pb-4 border-b border-border ${headerLink ? 'pt-[3px]' : 'gap-2 pt-5'}`}>
          {headerLink}
          <div className="flex items-center justify-between">
            <h2 id={titleId} className="font-mono text-sm font-bold tracking-[1.5px] uppercase text-accent shrink-0">
              {title}
            </h2>
            {headerCenter && (
              <div className="flex-1 flex items-center justify-center min-w-0">{headerCenter}</div>
            )}
            <div className="flex items-center gap-1 shrink-0">
              {headerAction}
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
        </div>
        <div className="overflow-y-auto px-5 pt-4 pb-5">{children}</div>
      </div>
    </div>,
    document.body,
  );
}
