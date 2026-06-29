// Harfik — hesap ayarları: profil fotoğrafı, kullanıcı adı, e-posta, şifre
import { useRef, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import {
  updateProfile,
  updateEmail,
  updatePassword,
  uploadAvatar,
} from '../lib/api';
import { useAuth } from '../hooks/useAuth';

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
  const [password, setPassword] = useState('');

  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const name = nickname || firstName || user?.email || 'Oyuncu';

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
      setError(err instanceof Error ? err.message : 'Yükleme başarısız.');
    } finally {
      setUploading(false);
    }
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setBusy(true);
    const notes: string[] = [];
    try {
      // Profil değiştiyse güncelle.
      const profilePatch: {
        first_name?: string;
        last_name?: string;
        display_name?: string | null;
      } = {};
      if (firstName.trim() !== (profile?.first_name ?? ''))
        profilePatch.first_name = firstName.trim();
      if (lastName.trim() !== (profile?.last_name ?? ''))
        profilePatch.last_name = lastName.trim();
      if (nickname.trim() !== (profile?.display_name ?? ''))
        profilePatch.display_name = nickname.trim() || null;
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

      // Şifre girildiyse güncelle.
      if (password) {
        if (password.length < 6) throw new Error('Şifre en az 6 karakter olmalı.');
        const { error } = await updatePassword(password);
        if (error) throw error;
        setPassword('');
        notes.push('Şifre güncellendi.');
      }

      setInfo(notes.length ? notes.join(' ') : 'Değişiklik yok.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Bir hata oluştu.');
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
        <Avatar url={profile?.photo_url} name={name} size={56} />
        <div>
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
            className="bg-panel border border-border text-text rounded-md px-3 py-1.5 text-[10px] font-mono uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
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
            />
          </div>
        </div>

        <div>
          <label className={labelCls}>Takma isim</label>
          <input
            className={inputCls}
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            placeholder="Girilmezse oyunda sadece adın görünür"
            autoComplete="nickname"
          />
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
          <label className={labelCls}>Yeni şifre</label>
          <input
            className={inputCls}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Değiştirmek için doldur"
            minLength={6}
            autoComplete="new-password"
          />
        </div>

        {error && <p className="text-red text-xs font-mono">{error}</p>}
        {info && <p className="text-green text-xs font-mono">{info}</p>}

        <button
          type="submit"
          disabled={busy}
          className="bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
        >
          {busy ? '...' : 'Kaydet'}
        </button>
      </form>
    </Modal>
  );
}
