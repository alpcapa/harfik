// Kelimeki — profil alanları için paylaşılan sabit ve yardımcılar (AuthModal'ın
// kayıt formu, AccountSettingsModal, Leaderboard/PlayerScoreCard/
// GameHistoryModal arasında ortak).
import type { Gender } from '../lib/database.types';

export const GENDER_OPTIONS: { value: Gender; label: string }[] = [
  { value: 'female', label: 'Kadın' },
  { value: 'male', label: 'Erkek' },
];

/**
 * Herkese açık yerlerde (Leaderboard, GameHistoryModal beğenenler listesi,
 * PlayerScoreCard) kullanılan kısa kimlik kuralı — nickname varsa o, yoksa
 * yalnızca ad; soyad hiçbir zaman gösterilmez. Önceden `rowName`/`likerName`/
 * `memberDisplayName` olarak üç ayrı dosyada birebir kopyalanmıştı (kod
 * incelemesi, dead-code/tekrar bulgusu).
 */
export function shortDisplayName(
  entity: { display_name?: string | null; first_name?: string | null } | null | undefined,
  fallback: string,
): string {
  return entity?.display_name || entity?.first_name || fallback;
}

/**
 * `birth_date` (ISO yyyy-mm-dd) sütununu "gg/aa/yyyy" gösterim biçimine
 * çevirir — tek bir metin alanında düzenlenir. Native `<input type="date">`
 * kullanılmıyor çünkü iOS Safari'de boş bir tarih alanına dokunup seçim
 * yapmadan bırakmak, tekerleğin o anki konumunu (bugünün tarihi) sessizce
 * değere yazıyordu, üstelik cihazın kendi yerel biçiminde gösteriyordu.
 */
export function isoToTrDate(iso: string | null | undefined): string {
  if (!iso) return '';
  const [y, m, d] = iso.split('-');
  return `${d}/${m}/${y}`;
}

/**
 * Doğum tarihi metin alanına yazarken "/" ayırıcılarını otomatik ekler
 * (ör. "01011990" yazılırken "01/01/1990" görünür) — kullanıcı sadece
 * rakam girer, ayırıcıları kendisi yazmak zorunda kalmaz.
 */
export function formatTrDateInput(value: string): string {
  const digits = value.replace(/\D/g, '').slice(0, 8);
  if (digits.length > 4) return `${digits.slice(0, 2)}/${digits.slice(2, 4)}/${digits.slice(4)}`;
  if (digits.length > 2) return `${digits.slice(0, 2)}/${digits.slice(2)}`;
  return digits;
}

/** "gg/aa/yyyy" kullanıcı girdisini `date` sütununa uygun ISO dizgeye çevirir. */
export function trDateToIso(input: string): string | null {
  const s = input.trim();
  if (!s) return null;
  const m = /^(\d{1,2})[./](\d{1,2})[./](\d{4})$/.exec(s);
  if (!m) throw new Error('Doğum tarihini GG/AA/YYYY biçiminde gir.');
  const d = Number(m[1]);
  const mo = Number(m[2]);
  const y = Number(m[3]);
  if (y < 1900 || y > new Date().getFullYear()) throw new Error('Doğum yılı geçersiz.');
  if (mo < 1 || mo > 12) throw new Error('Doğum ayı geçersiz.');
  const date = new Date(y, mo - 1, d);
  if (date.getFullYear() !== y || date.getMonth() !== mo - 1 || date.getDate() !== d) {
    throw new Error('Geçersiz doğum tarihi.');
  }
  return `${String(y).padStart(4, '0')}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/**
 * Doğum tarihinden TAMAMLANMIŞ yıl sayısını (yaş) hesaplar — doğum günü bu
 * yıl henüz geçmediyse bir eksik.
 *
 * ⚠ Bu tanım sunucudaki `get_profile_age_gender` RPC'sinin
 * `age(current_date, birth_date)` hesabıyla AYNI olmak zorunda: aynı satır
 * (`Y:59/C:E`) kendi kartında buradan, BAŞKASININ kartında RPC'den besleniyor
 * — ikisi ayrışırsa aynı oyuncu iki kartta farklı yaşta görünür.
 */
export function calculateAge(birthDate: string): number {
  const today = new Date();
  const born = new Date(birthDate);
  let age = today.getFullYear() - born.getFullYear();
  const monthDiff = today.getMonth() - born.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < born.getDate())) {
    age--;
  }
  return age;
}

/**
 * "Yaş: 59" yerine "Y:59/C:E" — yaş (Y) ve cinsiyet (C, Erkek/Kadın) tek
 * satırda, yalnızca girilmiş olanlar gösterilir; ikisi de yoksa boş dizge.
 * `ScoreCard` (kendi kartı) ve `PlayerScoreCard` (başkasının kartı) ortak
 * kullanır — satır iki kartta da aynı görünmeli.
 */
export function formatAgeGender(
  age: number | null,
  gender: Gender | null | undefined,
): string {
  const genderLetter = gender === 'male' ? 'E' : gender === 'female' ? 'K' : null;
  const parts: string[] = [];
  if (age !== null) parts.push(`Y:${age}`);
  if (genderLetter) parts.push(`C:${genderLetter}`);
  return parts.join('/');
}
