import { useState } from 'react';
import { Modal } from './Modal';
import { FeedbackModal } from './FeedbackModal';
import { TermsBody } from '../legal/LegalContent';

interface TermsModalProps {
  onClose: () => void;
}

// Metin burada DEĞİL — bkz. `PrivacyModal` başlığındaki not.
export function TermsModal({ onClose }: TermsModalProps) {
  const [showFeedback, setShowFeedback] = useState(false);

  return (
    <>
      <Modal title="Kullanım Koşulları" onClose={onClose}>
        <TermsBody
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
