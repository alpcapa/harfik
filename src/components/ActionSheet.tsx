// Kelimeki — iOS tarzı alttan açılan aksiyon menüsü
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { useModalA11y } from '../hooks/useModalA11y';

export interface ActionSheetAction {
  label: string;
  onSelect: () => void;
  destructive?: boolean;
}

interface ActionSheetProps {
  actions: ActionSheetAction[];
  onClose: () => void;
}

export function ActionSheet({ actions, onClose }: ActionSheetProps) {
  const containerRef = useModalA11y(true, onClose);
  // Modal.tsx'in aksine ActionSheet ekranın ALT ucuna açılıyor — kullanıcı
  // genelde ekranın ortasındaki bir öğeye dokunduğundan (ör. tahta
  // önizlemesi), gözü zaten oradayken alt uçta sessizce beliren, arka
  // planı hiç koyulaştırmayan bir menü kolayca gözden kaçıyordu (kullanıcı
  // bildirdi: "en altında çıkıyor ve farkedilmiyor bile"). Bir karartma
  // katmanı + kayarak beliren geçiş, yeni bir katmanın açıldığını
  // belirginleştiriyor. `visible` bir sonraki frame'de true olup CSS
  // transition'ı tetikliyor (mount anında doğrudan son durumda render
  // edilirse tarayıcı geçişi atlar).
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true));
    return () => cancelAnimationFrame(id);
  }, []);
  return createPortal(
    <div
      className={`fixed inset-0 z-[160] flex items-end justify-center p-3 bg-black/0 transition-colors duration-200 ${visible ? 'bg-black/40' : ''}`}
      onClick={onClose}
    >
      <div
        ref={containerRef}
        role="dialog"
        aria-modal="true"
        tabIndex={-1}
        className={`w-full max-w-[360px] flex flex-col gap-2 outline-none transition-all duration-200 ${
          visible ? 'translate-y-0 opacity-100' : 'translate-y-4 opacity-0'
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="bg-panel rounded-xl overflow-hidden shadow-[0_20px_45px_rgba(15,23,42,0.5)] divide-y divide-border">
          {actions.map((action) => (
            <button
              key={action.label}
              onClick={() => {
                onClose();
                action.onSelect();
              }}
              className={`w-full py-3.5 text-[15px] font-mono font-bold text-center active:bg-border/40 ${
                action.destructive ? 'text-red' : 'text-accent'
              }`}
            >
              {action.label}
            </button>
          ))}
        </div>
        <button
          onClick={onClose}
          className="w-full py-3.5 text-[15px] font-mono font-bold text-center text-text bg-panel rounded-xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] active:bg-border/40"
        >
          Vazgeç
        </button>
      </div>
    </div>,
    document.body,
  );
}
