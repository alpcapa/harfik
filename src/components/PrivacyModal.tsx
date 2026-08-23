import { useState } from 'react';
import { Modal } from './Modal';
import { FeedbackModal } from './FeedbackModal';
import { PrivacyBody } from '../legal/LegalContent';

interface PrivacyModalProps {
  onClose: () => void;
}

// Metin burada DEĞİL — tek kaynak `src/legal/LegalContent.tsx` (aynı metni
// `/gizlilik/` statik sayfası da tüketiyor). Buradaki tek fark, iletişim
// bağlantısının `FeedbackModal`'ı açan bir buton olması.
export function PrivacyModal({ onClose }: PrivacyModalProps) {
  const [showFeedback, setShowFeedback] = useState(false);

  return (
    <>
      <Modal title="Gizlilik Politikası" onClose={onClose}>
        <PrivacyBody
          contact={
            <button
              type="button"
              onClick={() => setShowFeedback(true)}
              className="text-accent font-mono hover:underline"
            >
              Görüş Bildir formu
            </button>
          }
        />
      </Modal>
      {showFeedback && <FeedbackModal onClose={() => setShowFeedback(false)} source="general" />}
    </>
  );
}
