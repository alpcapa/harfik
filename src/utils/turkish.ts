// Harfik — Türkçe'ye duyarlı büyük/küçük harf dönüşümü
// =====================================================================
// Türk alfabesinde i/İ (noktalı) ile ı/I (noktasız) ayrı harflerdir.
// JavaScript'in varsayılan yerel ayarlı `toUpperCase()`/`toLowerCase()`
// dönüşümleri bunu bozar: "kilis".toUpperCase() => "KILIS" (yanlış,
// noktasız I) — oysa doğrusu "KİLİS"; "KİLİS".toLowerCase() => "ki̇lis"
// (İ, i + birleştiren nokta olur) ve sözlükteki "kilis" ile eşleşmez.
//
// Sözlük verisi (src/data/words.ts) küçük harfle ve aşağıdaki trLower
// kuralıyla üretilir; karşılaştırmaların tutması için çalışma anında da
// AYNI normalleştirme kullanılmalıdır.

/** Türkçe küçük harfe çevirir (İ→i, I→ı). Sözlük normalleştirmesiyle aynı. */
export function trLower(s: string): string {
  return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

/** Türkçe büyük harfe çevirir (i→İ, ı→I). Tahta/taş harflerini üretir. */
export function trUpper(s: string): string {
  return s.replace(/i/g, 'İ').replace(/ı/g, 'I').toUpperCase();
}
