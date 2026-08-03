// Kelimeki — giriş / kayıt ekranı
import { useState } from 'react';
import { Modal } from './Modal';
import { TermsModal } from './TermsModal';
import { PrivacyModal } from './PrivacyModal';
import { signIn, signUp, sendPasswordReset } from '../lib/api';
import { useAuth } from '../hooks/useAuth';
import { useNicknameAvailability } from '../hooks/useNicknameAvailability';
import { GENDER_OPTIONS, formatTrDateInput, trDateToIso } from '../utils/profileFields';
import type { Gender } from '../lib/database.types';

interface AuthModalProps {
  onClose: () => void;
  initialMode?: Mode;
  initialEmail?: string;
  /** Bu kaydın hangi kanaldan geldiği (admin panelinde gösterilir). */
  signupChannel?: 'direct' | 'form';
}

type Mode = 'login' | 'signup' | 'forgot';

function EyeIcon({ open }: { open: boolean }) {
  return open ? (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  ) : (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
      <line x1="1" y1="1" x2="23" y2="23" />
    </svg>
  );
}

export function AuthModal({
  onClose,
  initialMode = 'login',
  initialEmail = '',
  signupChannel = 'direct',
}: AuthModalProps) {
  const { refreshProfile } = useAuth();
  const [mode, setMode] = useState<Mode>(initialMode);
  const [email, setEmail] = useState(initialEmail);
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [nickname, setNickname] = useState('');
  const [gender, setGender] = useState<Gender | ''>('');
  const [birthDate, setBirthDate] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [infoTone, setInfoTone] = useState<'gold' | 'red'>('gold');
  const [termsAccepted, setTermsAccepted] = useState(false);
  const [marketingConsent, setMarketingConsent] = useState(false);
  const [showTerms, setShowTerms] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);

  const nicknameStatus = useNicknameAvailability(nickname, mode === 'signup');

  const switchMode = (next: Mode) => {
    setMode(next);
    setError(null);
    setInfo(null);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setBusy(true);
    try {
      if (mode === 'login') {
        const { error } = await signIn(email, password);
        if (error) throw error;
        await refreshProfile();
        onClose();
      } else if (mode === 'forgot') {
        const { error } = await sendPasswordReset(email);
        if (error) throw error;
        setInfoTone('gold');
        setInfo('Şifre sıfırlama bağlantısı e-postana gönderildi.');
      } else {
        if (!firstName.trim()) throw new Error('Ad zorunludur.');
        if (!lastName.trim()) throw new Error('Soyad zorunludur.');
        if (!nickname.trim()) throw new Error('Takma isim zorunludur.');
        if (nicknameStatus === 'checking') throw new Error('Takma isim kontrol ediliyor, birazdan tekrar dene.');
        if (nicknameStatus === 'taken') throw new Error('Bu takma isim zaten kullanılıyor.');
        if (!termsAccepted) throw new Error('Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmelisiniz.');
        const birthDateIso = trDateToIso(birthDate);
        const { data, error } = await signUp(
          email,
          password,
          firstName.trim(),
          lastName.trim(),
          nickname.trim(),
          termsAccepted,
          signupChannel,
          gender || null,
          birthDateIso,
          marketingConsent,
        );
        if (error) throw error;
        if (data.session) {
          await refreshProfile();
          onClose();
        } else {
          switchMode('login');
          setInfoTone('red');
          setInfo('Hesap oluşturuldu. E-postanı doğrulayıp giriş yap.');
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : (err as { message?: string })?.message;
      setError(msg || 'Bir hata oluştu.');
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';
  const labelCls = 'text-[9px] uppercase tracking-[1.5px] text-muted font-mono mb-1 block';
  const required = <span className="text-red">*</span>;

  const title = mode === 'login' ? 'Giriş' : mode === 'signup' ? 'Kayıt' : 'Şifremi Unuttum';

  return (
    <>
    <Modal title={title} onClose={onClose}>
      <form onSubmit={submit} className="flex flex-col gap-3">
        {mode === 'signup' && (
          <>
            <div className="flex gap-2">
              <div className="flex-1">
                <label className={labelCls}>Ad {required}</label>
                <input
                  className={inputCls}
                  placeholder="Adın"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  autoComplete="given-name"
                  required
                />
              </div>
              <div className="flex-1">
                <label className={labelCls}>Soyad {required}</label>
                <input
                  className={inputCls}
                  placeholder="Soyadın"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  autoComplete="family-name"
                  required
                />
              </div>
            </div>

            <div>
              <label className={labelCls}>Takma isim {required}</label>
              {/* Boşluk kabul edilmiyor (tek kelime, özel karakterler serbest) —
                  aksi halde biri buraya gerçek adını yazarsa (ör. "İsim Soyad")
                  skor kartlarında nickname değil tam ad gibi görünüyordu.
                  Benzersiz olmak zorunda (profiles_display_name_tr_lower_key,
                  Türkçe'ye duyarlı büyük/küçük harf duyarsız) — iki kişinin
                  aynı görünen isimle ayrı hesap açması (ör. iki "deniz")
                  arkadaş aramasında/skor kartlarında ayırt edilemez oluyordu. */}
              <input
                className={inputCls}
                placeholder="Herkese görünen ismin"
                value={nickname}
                onChange={(e) => setNickname(e.target.value.replace(/\s+/g, ''))}
                autoComplete="nickname"
                required
              />
              {nicknameStatus === 'checking' && (
                <p className="text-[10px] text-muted font-mono mt-1">Kontrol ediliyor…</p>
              )}
              {nicknameStatus === 'available' && (
                <p className="text-[10px] text-green font-mono mt-1">✓ Kullanılabilir</p>
              )}
              {nicknameStatus === 'taken' && (
                <p className="text-[10px] text-red font-mono mt-1">Bu takma isim kullanımda.</p>
              )}
              {nicknameStatus === 'error' && (
                // Kontrol başarısız olsa bile kayıt engellenmiyor — DB'deki
                // unique kısıt gerçek doğruluk kaynağı, çakışma olursa
                // friendlyNicknameError dostane bir hataya çeviriyor.
                <p className="text-[10px] text-muted font-mono mt-1">Kullanılabilirlik kontrol edilemedi, kayıt sırasında tekrar denenecek.</p>
              )}
            </div>
          </>
        )}

        <div>
          {mode === 'signup' && <label className={labelCls}>E-posta {required}</label>}
          <input
            className={inputCls}
            type="email"
            placeholder={mode === 'signup' ? 'Doğrulama linki gönderilir' : 'E-posta'}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
          />
        </div>

        {mode === 'signup' && (
          <>
            <div>
              <label className={labelCls}>Cinsiyet</label>
              <select
                className={inputCls}
                value={gender}
                onChange={(e) => setGender(e.target.value as Gender | '')}
              >
                <option value="">Belirtilmedi</option>
                {GENDER_OPTIONS.map((g) => (
                  <option key={g.value} value={g.value}>
                    {g.label}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className={labelCls}>Doğum Tarihi (GG/AA/YYYY)</label>
              <input
                className={inputCls}
                type="text"
                inputMode="numeric"
                value={birthDate}
                onChange={(e) => setBirthDate(formatTrDateInput(e.target.value))}
                placeholder="GG/AA/YYYY"
                autoComplete="bday"
                maxLength={10}
              />
            </div>
          </>
        )}

        {mode !== 'forgot' && (
          <div>
            {mode === 'signup' && <label className={labelCls}>Şifre {required}</label>}
            <div className="relative">
              <input
                className={`${inputCls} pr-9`}
                type={showPassword ? 'text' : 'password'}
                placeholder="Şifre"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
                autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={showPassword ? 'Şifreyi gizle' : 'Şifreyi göster'}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-muted hover:text-text transition-colors"
              >
                <EyeIcon open={showPassword} />
              </button>
            </div>
          </div>
        )}

        {mode === 'forgot' && (
          <p className="text-xs text-muted font-mono">
            E-posta adresini gir, sıfırlama bağlantısı gönderelim.
          </p>
        )}

        {mode === 'signup' && (
          <label className="flex items-start gap-2 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={termsAccepted}
              onChange={(e) => setTermsAccepted(e.target.checked)}
              className="mt-0.5 shrink-0 accent-accent"
            />
            <span className="text-xs font-sans text-muted leading-relaxed">
              <button
                type="button"
                onClick={() => setShowTerms(true)}
                className="text-accent hover:underline"
              >
                Kullanım Koşulları
              </button>
              {' '}ve{' '}
              <button
                type="button"
                onClick={() => setShowPrivacy(true)}
                className="text-accent hover:underline"
              >
                Gizlilik Politikası
              </button>
              'nı okudum ve kabul ediyorum.
            </span>
          </label>
        )}

        {mode === 'signup' && (
          <label className="flex items-start gap-2 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={marketingConsent}
              onChange={(e) => setMarketingConsent(e.target.checked)}
              className="mt-0.5 shrink-0 accent-accent"
            />
            <span className="text-xs font-sans text-muted leading-relaxed">
              Pazarlama iletişimi almayı kabul ediyorum.
            </span>
          </label>
        )}

        {mode === 'signup' && (
          <p className="text-[9px] text-muted font-mono">{required} Zorunlu alan</p>
        )}

        {error && <p className="text-red text-xs font-mono">{error}</p>}
        {info && (
          <p className={`${infoTone === 'red' ? 'text-red' : 'text-gold'} text-xs font-mono`}>
            {info}
          </p>
        )}

        <button
          type="submit"
          disabled={
            busy || (mode === 'signup' && (nicknameStatus === 'checking' || nicknameStatus === 'taken'))
          }
          className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
        >
          {busy
            ? '...'
            : mode === 'login'
              ? 'Giriş Yap'
              : mode === 'signup'
                ? 'Kayıt Ol'
                : 'Bağlantı Gönder'}
        </button>
      </form>

      <div className="mt-3 flex flex-col gap-1.5">
        {mode === 'login' && (
          <>
            <button
              onClick={() => switchMode('forgot')}
              className="w-full text-center text-xs text-muted font-mono underline hover:text-accent transition-colors"
            >
              Şifremi unuttum
            </button>
            <button
              onClick={() => switchMode('signup')}
              className="w-full text-center text-xs text-muted font-mono transition-colors"
            >
              Hesabın yok mu? <span className="text-accent underline">Kayıt ol</span>
            </button>
          </>
        )}
        {mode === 'signup' && (
          <button
            onClick={() => switchMode('login')}
            className="w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
          >
            Zaten hesabın var mı? <span className="text-accent underline">Giriş yap</span>
          </button>
        )}
        {mode === 'forgot' && (
          <button
            onClick={() => switchMode('login')}
            className="w-full text-center text-xs text-muted font-mono hover:text-accent transition-colors"
          >
            Giriş ekranına dön
          </button>
        )}
      </div>
    </Modal>
    {showTerms && <TermsModal onClose={() => setShowTerms(false)} />}
    {showPrivacy && <PrivacyModal onClose={() => setShowPrivacy(false)} />}
    </>
  );
}
