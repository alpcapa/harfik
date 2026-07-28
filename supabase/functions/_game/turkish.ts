// Kelimeki — Türkçe'ye duyarlı büyük/küçük harf dönüşümü
//
// src/utils/turkish.ts'in KOPYASI — bkz. types.ts'teki not.

/** Türkçe küçük harfe çevirir (İ→i, I→ı). Sözlük normalleştirmesiyle aynı. */
export function trLower(s: string): string {
  return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

/** Türkçe büyük harfe çevirir (i→İ, ı→I). Tahta/taş harflerini üretir. */
export function trUpper(s: string): string {
  return s.replace(/i/g, 'İ').replace(/ı/g, 'I').toUpperCase();
}
