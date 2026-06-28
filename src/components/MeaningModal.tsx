// Harfik — oynanan kelimenin sözlük anlamı açılır penceresi
import { Modal } from './Modal';
import type { WordMeaning } from '../lib/database.types';

interface MeaningModalProps {
  /** Görüntülenen kelime (büyük harf gösterilir). */
  word: string;
  /** Yüklenen anlam verisi (yoksa null). */
  data: WordMeaning | null;
  loading: boolean;
  onClose: () => void;
}

export function MeaningModal({ word, data, loading, onClose }: MeaningModalProps) {
  const title = word.toLocaleUpperCase('tr');
  return (
    <Modal title={title} onClose={onClose}>
      {loading ? (
        <p className="font-mono text-xs text-muted">Anlam yükleniyor…</p>
      ) : data && data.meanings.length > 0 ? (
        <div className="flex flex-col gap-3">
          {data.pos && (
            <span className="font-mono text-[10px] tracking-[1px] uppercase text-gold">
              {data.pos}
            </span>
          )}
          <ol className="flex flex-col gap-2 list-none">
            {data.meanings.map((m, i) => (
              <li key={i} className="flex gap-2 text-[13px] leading-snug text-text">
                <span className="font-mono text-muted shrink-0">{i + 1}.</span>
                <span>{m}</span>
              </li>
            ))}
          </ol>
        </div>
      ) : (
        <p className="font-mono text-xs text-muted">
          Bu kelimenin anlamı bulunamadı.
        </p>
      )}
    </Modal>
  );
}
