// Harfik — oynanan kelime(ler)in sözlük anlamı açılır penceresi
import { Modal } from './Modal';
import type { WordMeaning } from '../lib/database.types';
import { trUpper } from '../utils/turkish';

interface MeaningEntry {
  /** Görüntülenen kelime. */
  word: string;
  /** Yüklenen anlam verisi (yoksa null). */
  data: WordMeaning | null;
  loading: boolean;
}

interface MeaningModalProps {
  /** Gösterilecek kelimeler; ilki başlık olur, diğerleri alt başlıkla listelenir. */
  entries: MeaningEntry[];
  onClose: () => void;
}

function Meanings({ entry }: { entry: MeaningEntry }) {
  if (entry.loading) {
    return <p className="font-mono text-xs text-muted">Anlam yükleniyor…</p>;
  }
  if (entry.data && entry.data.meanings.length > 0) {
    return (
      <ol className="flex flex-col gap-2 list-none">
        {entry.data.meanings.map((m, i) => (
          <li key={i} className="flex gap-2 text-[13px] leading-snug text-text">
            <span className="font-mono text-muted shrink-0">{i + 1}.</span>
            <span>{m}</span>
          </li>
        ))}
      </ol>
    );
  }
  return (
    <p className="font-mono text-xs text-muted">
      Bu kelimenin anlamı bulunamadı.
    </p>
  );
}

export function MeaningModal({ entries, onClose }: MeaningModalProps) {
  const title = entries[0] ? trUpper(entries[0].word) : '';
  return (
    <Modal title={title} onClose={onClose}>
      <div className="flex flex-col gap-4">
        {entries.map((entry, idx) => (
          <div key={entry.word} className="flex flex-col gap-3">
            {idx > 0 && (
              <h3 className="font-mono text-xs font-bold tracking-[1.5px] uppercase text-accent border-t border-border pt-4">
                {trUpper(entry.word)}
              </h3>
            )}
            <Meanings entry={entry} />
          </div>
        ))}
      </div>
    </Modal>
  );
}
