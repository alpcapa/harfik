// Kelimeki — hesap ayarları: profil fotoğrafı, kullanıcı adı, e-posta, cinsiyet, doğum tarihi
import { useRef, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { updateProfile, updateEmail, uploadAvatar } from '../lib/api';
import { useAuth } from '../hooks/useAuth';
import { useNicknameAvailability } from '../hooks/useNicknameAvailability';
import type { Gender } from '../lib/database.types';
import { GENDER_OPTIONS, formatTrDateInput, isoToTrDate, trDateToIso } from '../utils/profileFields';

interface AccountSettingsModalProps {
  onClose: () => void;
}

export function AccountSettingsModal({ onClose }: AccountSettingsModalProps) {
  const { user, profile, refreshProfile } = useAuth();
  const fileRef = useRef<HTMLInputElement>(null);

  const [firstName, setFirstName] = useState(profile?.first_name ?? '');
  const [lastName, setLastName] = useState(profile?.last_name ?? '');
  const [nickname, setNickname] = useState(profile?.display_name ?? '');
  const [email, setEmail] = useState(user?.email ?? '');
  const [gender, setGender] = useState<Gender | ''>(profile?.gender ?? '');
  const [birthDate, setBirthDate] = useState(isoToTrDate(profile?.birth_date));
  const [marketingConsent, setMarketingConsent] = useState(profile?.marketing_consent ?? false);
  const [emailNotifications, setEmailNotifications] = useState(profile?.email_notifications_enabled ?? true);

  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const name = nickname || firstName || user?.email || 'Oyuncu';
  const nicknameStatus = useNicknameAvailability(nickname, true, profile?.display_name ?? undefined);

  const onPickFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // aynı dosya tekrar seçilebilsin
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setError('Lütfen bir görsel dosyası seç.');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setError('Görsel 2 MB’den küçük olmalı.');
      return;
    }
    setError(null);
    setInfo(null);
    setUploading(true);
    try {
      await uploadAvatar(file);
      await refreshProfile();
      setInfo('Profil fotoğrafı güncellendi.');
    } catch (err) {
      const msg = err instanceof Error ? err.message : (err as { message?: string })?.message;
      setError(msg || 'Yükleme başarısız.');
    } finally {
      setUploading(false);
    }
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);
    if (!firstName.trim()) {
      setError('Ad zorunludur.');
      return;
    }
    if (!lastName.trim()) {
      setError('Soyad zorunludur.');
      return;
    }
    if (!nickname.trim()) {
      setError('Takma isim zorunludur.');
      return;
    }
    if (nickname.trim() !== (profile?.display_name ?? '')) {
      if (nicknameStatus === 'checking') {
        setError('Takma isim kontrol ediliyor, birazdan tekrar dene.');
        return;
      }
      if (nicknameStatus === 'taken') {
        setError('Bu takma isim zaten kullanılıyor.');
        return;
      }
    }
    let birthDateIso: string | null;
    try {
      birthDateIso = trDateToIso(birthDate);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Doğum tarihi geçersiz.');
      return;
    }
    setBusy(true);
    const notes: string[] = [];
    try {
      // Profil değiştiyse güncelle.
      const profilePatch: {
        first_name?: string;
        last_name?: string;
        display_name?: string | null;
        gender?: Gender | null;
        birth_date?: string | null;
        marketing_consent?: boolean;
        email_notifications_enabled?: boolean;
      } = {};
      if (firstName.trim() !== (profile?.first_name ?? ''))
        profilePatch.first_name = firstName.trim();
      if (lastName.trim() !== (profile?.last_name ?? ''))
        profilePatch.last_name = lastName.trim();
      if (nickname.trim() !== (profile?.display_name ?? ''))
        profilePatch.display_name = nickname.trim();
      if (gender !== (profile?.gender ?? ''))
        profilePatch.gender = gender || null;
      if (birthDateIso !== (profile?.birth_date ?? null))
        profilePatch.birth_date = birthDateIso;
      if (marketingConsent !== (profile?.marketing_consent ?? false))
        profilePatch.marketing_consent = marketingConsent;
      if (emailNotifications !== (profile?.email_notifications_enabled ?? true))
        profilePatch.email_notifications_enabled = emailNotifications;
      if (Object.keys(profilePatch).length > 0) {
        await updateProfile(profilePatch);
        await refreshProfile();
        notes.push('Profil güncellendi.');
      }

      // E-posta değiştiyse güncelle (doğrulama gerektirebilir).
      if (email.trim() && email.trim() !== (user?.email ?? '')) {
        const { error } = await updateEmail(email.trim());
        if (error) throw error;
        notes.push('E-posta değişikliği için onay bağlantısı gönderildi.');
      }

      setInfo(notes.length ? notes.join(' ') : 'Değişiklik yok.');
    } catch (err) {
      const msg = err instanceof Error ? err.message : (err as { message?: string })?.message;
      setError(msg || 'Bir hata oluştu.');
    } finally {
      setBusy(false);
    }
  };

  const inputCls =
    'w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors';
  const labelCls =
    'text-[9px] uppercase tracking-[1.5px] text-muted font-mono mb-1 block';

  return (
    <Modal title="Hesap Ayarları" onClose={onClose}>
      {/* Profil fotoğrafı */}
      <div className="flex items-center gap-3 mb-4">
        <Avatar url={profile?.avatar_url} name={name} size={56} />
        <div>
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
            className="btn-raised-neutral bg-panel border border-border text-text rounded-md px-3 py-1.5 text-[10px] font-mono uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            {uploading ? 'Yükleniyor…' : 'Fotoğraf Değiştir'}
          </button>
          <p className="text-[9px] text-muted font-mono mt-1">JPG/PNG, en fazla 2 MB</p>
        </div>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={onPickFile}
        />
      </div>

      <form onSubmit={save} className="flex flex-col gap-3">
        <div className="flex gap-2">
          <div className="flex-1">
            <label className={labelCls}>Ad</label>
            <input
              className={inputCls}
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              placeholder="Adın"
              autoComplete="given-name"
              required
            />
          </div>
          <div className="flex-1">
            <label className={labelCls}>Soyad</label>
            <input
              className={inputCls}
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              placeholder="Soyadın"
              autoComplete="family-name"
              required
            />
          </div>
        </div>

        <div>
          <label className={labelCls}>Takma isim</label>
          {/* Boşluk kabul edilmiyor (tek kelime, özel karakterler serbest) —
              aksi halde biri buraya gerçek adını yazarsa (ör. "İsim Soyad")
              skor kartlarında nickname değil tam ad gibi görünüyordu.
              Benzersiz olmak zorunda (bkz. AuthModal'daki aynı not). */}
          <input
            className={inputCls}
            value={nickname}
            onChange={(e) => setNickname(e.target.value.replace(/\s+/g, ''))}
            placeholder="Herkese görünen ismin (boşluksuz)"
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
        </div>

        <div>
          <label className={labelCls}>E-posta</label>
          <input
            className={inputCls}
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
          />
        </div>

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

        <label className="flex items-start gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={marketingConsent}
            onChange={(e) => setMarketingConsent(e.target.checked)}
            className="mt-0.5 shrink-0 accent-accent"
          />
          <span className="text-xs font-sans text-muted leading-relaxed">
            Pazarlama iletişimi almayı kabul ediyorum.
            {profile?.marketing_consent && profile.marketing_consent_at && (
              <span className="block text-[9px] font-mono text-muted mt-0.5">
                Kabul tarihi: {new Date(profile.marketing_consent_at).toLocaleDateString('tr-TR')}{' '}
                {new Date(profile.marketing_consent_at).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}
              </span>
            )}
          </span>
        </label>

        <label className="flex items-start gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={emailNotifications}
            onChange={(e) => setEmailNotifications(e.target.checked)}
            className="mt-0.5 shrink-0 accent-accent"
          />
          <span className="text-xs font-sans text-muted leading-relaxed">
            Arkadaşlık isteği, oyun daveti ve süre uyarısı gibi e-posta bildirimlerini almak istiyorum.
            <span className="block text-[9px] font-mono text-muted mt-0.5">
              Bunu kapatsan da hesap güvenliğiyle ilgili mailleri (şifre sıfırlama, hesap durumu vb.) almaya devam edersin.
            </span>
          </span>
        </label>

        {error && <p className="text-red text-xs font-mono">{error}</p>}
        {info && <p className="text-green text-xs font-mono">{info}</p>}

        <button
          type="submit"
          disabled={busy || nicknameStatus === 'checking' || nicknameStatus === 'taken'}
          className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
        >
          {busy ? '...' : 'Kaydet'}
        </button>
      </form>
    </Modal>
  );
}
