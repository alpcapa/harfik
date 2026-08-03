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
