// Kelimeki — oyun bitiminde gösterilen "Görüş Bildir" formu
import { useRef, useState } from 'react';
import { Modal } from './Modal';
import { AuthModal } from './AuthModal';
import { submitFeedbackDurable } from '../utils/feedbackSync';
import { useAuth } from '../hooks/useAuth';
import type { FeedbackSource } from '../lib/database.types';

interface FeedbackModalProps {
  onClose: () => void;
  source: FeedbackSource;
  // E-postadaki "cevap için tıklayın" linkine gömülü bir referans (?contact=1&re=<id>)
  // varsa, gönderilen yeni mesajı o önceki mesaja bağlamak için.
  relatedTo?: string | null;
  /**
   * Kullanıcı buraya BİZİM gönderdiğimiz bir e-postadaki linkten (?contact=1)
   * geldiyse `true` — gönderim sonrası "bu e-postayla üyeliğine devam etmek
   * ister misin?" teklifi gösterilmez, yalnızca teşekkür + "Kapat" çıkar.
   *
   * Gerekçe (kullanıcı isteği, 4 Ağustos 2026): o linke tıklayan kişiye zaten
   * biz mail atmışız, yani e-postası bizde kayıtlı ve büyük olasılıkla hesabı
   * da var. En uç örneği hesabı DONDURULMUŞ bir kullanıcının itiraz etmesi:
   * giriş yapamadığı için girişsiz görünüyor, itirazını gönderiyor ve
   * sonunda "üye olmak ister misin?" teklifi alıyordu — zaten üyesi.
   * Uygulama bunu tek başına anlayamaz (ziyaretçi girişsiz, elde yalnızca bir
   * e-posta metni var) ve "bu e-posta kayıtlı mı" diye sormak hesap-varlığı
   * sızdıran bir enumeration açığı olurdu; bu yüzden çözüm sorgu değil,
   * BAĞLAM: linkten gelindiği bilgisini prop olarak taşımak.
   */
  fromEmailLink?: boolean;
}

// Basit bot/spam koruması: sunucu tarafı doğrulaması olmadığı için (henüz
// CAPTCHA/edge function yok) burada sadece naif botları caydıracak ucuz
// önlemler var — hedefli bir saldırıyı durdurmaz, sadece maliyetsiz gürültüyü keser.
const FEEDBACK_HISTORY_KEY = 'kelimeki:feedback-submissions';
const FEEDBACK_WINDOW_MS = 10 * 60 * 1000;
const FEEDBACK_MAX_PER_WINDOW = 3;
const MIN_SUBMIT_MS = 1500;

function recentSubmissionTimestamps(): number[] {
  try {
    const raw = localStorage.getItem(FEEDBACK_HISTORY_KEY);
    const list = raw ? (JSON.parse(raw) as number[]) : [];
    const cutoff = Date.now() - FEEDBACK_WINDOW_MS;
    return list.filter((t) => typeof t === 'number' && t > cutoff);
  } catch {
    return [];
  }
}

function recordSubmission(): void {
  try {
    const list = recentSubmissionTimestamps();
    list.push(Date.now());
    localStorage.setItem(FEEDBACK_HISTORY_KEY, JSON.stringify(list));
  } catch {
    // yoksay
  }
}

export function FeedbackModal({ onClose, source, relatedTo, fromEmailLink = false }: FeedbackModalProps) {
  const { user } = useAuth();
  const [message, setMessage] = useState('');
  const [email, setEmail] = useState(user?.email ?? '');
  const [honeypot, setHoneypot] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [showSignup, setShowSignup] = useState(false);
  const openedAt = useRef(Date.now());

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!message.trim()) {
      setError('Mesaj boş olamaz.');
      return;
    }

    // Honeypot dolu ya da form saniyeler içinde gönderildiyse büyük ihtimalle
    // bot — hiçbir şey kaydetmeden "gönderildi" göster (botu bilgilendirme).
    if (honeypot || Date.now() - openedAt.current < MIN_SUBMIT_MS) {
      setSent(true);
      return;
    }

    if (recentSubmissionTimestamps().length >= FEEDBACK_MAX_PER_WINDOW) {
      setError('Çok fazla mesaj gönderdin, birkaç dakika sonra tekrar dene.');
      return;
    }

    setBusy(true);
    try {
      await submitFeedbackDurable(message, email, source, relatedTo);
      recordSubmission();
      setSent(true);
    } catch (err) {
      const msg = err instanceof Error ? err.message : (err as { message?: string })?.message;
      setError(msg || 'Bir hata oluştu.');
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';

  return (
    <>
    <Modal title="Görüşleriniz Bizim İçin Önemli" onClose={onClose}>
      {sent ? (
        <div className="flex flex-col items-center gap-3 py-4 text-center">
          <p className="text-sm text-text">Teşekkürler, mesajın bize ulaştı.</p>
          {!user && email.trim() && !fromEmailLink ? (
            <>
              <p className="text-xs text-muted font-mono">
                {email.trim()} ile üyeliğine devam etmek ister misin?
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setShowSignup(true)}
                  className="btn-raised bg-accent text-white rounded-md py-2.5 px-5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform"
                >
                  Evet
                </button>
                <button
                  onClick={onClose}
                  className="btn-raised-neutral bg-panel border border-border text-text rounded-md py-2.5 px-5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform"
                >
                  Hayır
                </button>
              </div>
            </>
          ) : (
            <button
              onClick={onClose}
              className="btn-raised bg-accent text-white rounded-md py-2.5 px-5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform"
            >
              Kapat
            </button>
          )}
        </div>
      ) : (
        <form onSubmit={submit} className="flex flex-col gap-3">
          {/* Honeypot: botlar bu alanı doldurur, insanlar görmez. */}
          <input
            type="text"
            name="website"
            value={honeypot}
            onChange={(e) => setHoneypot(e.target.value)}
            tabIndex={-1}
            autoComplete="off"
            aria-hidden="true"
            className="absolute -left-[9999px] w-px h-px opacity-0 pointer-events-none"
          />
          <p className="text-xs text-muted font-mono">
            Öneri, hata bildirimi ya da her türlü görüşünü bize iletebilirsin.
          </p>
          <textarea
            className={`${inputCls} resize-none`}
            rows={4}
            placeholder="Mesajın"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            maxLength={2000}
            required
            autoFocus
          />
          {user ? (
            <p className="text-[10px] text-muted font-mono">
              Yanıt e-postan: <span className="text-text">{user.email}</span>
            </p>
          ) : (
            <input
              className={inputCls}
              type="email"
              placeholder="E-posta (yanıt alabilmen için, isteğe bağlı)"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
            />
          )}

          {error && <p className="text-red text-xs font-mono">{error}</p>}

          <button
            type="submit"
            disabled={busy}
            className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            {busy ? '...' : 'Gönder'}
          </button>
        </form>
      )}
    </Modal>
    {showSignup && (
      <AuthModal
        initialMode="signup"
        initialEmail={email.trim()}
        signupChannel="form"
        onClose={onClose}
      />
    )}
    </>
  );
}
