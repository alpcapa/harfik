// Iskalanan dokunuşu kurtarma — taslak hamle sürerken oynanmış bir taşa
// dokunulduğunda, komşusundaki TASLAK taşını hedef sayar.
//
// NEDEN VAR (24 Ağustos 2026, kullanıcı önce mobil uygulamada bildirdi,
// sonra webe de istedi: *"Bir çok insan mobil browser kullanıyor, mouse
// değil"*): tahta hücresi ~24 px ve parmağın bildirdiği temas MERKEZİ nişan
// alınan noktanın altında kalıyor, yani taslak taşını geri almak için
// dokunan kullanıcı sık sık komşu (oynanmış) taşa isabet ediyor. Hücreyi
// büyütmek mümkün değil — ızgara ölçüsü oyunun kuralı. Ama taslak sürerken
// oynanmış taşlar ZATEN ölü (anlam penceresi o sırada açılmıyor), yani
// alanlarını taslak taşına devretmek bedava.
//
// ⚠ YALNIZCA OYNANMIŞ hücrelerden çağrılır; BOŞ hücrelere hiç dokunulmaz —
// yoksa kelimeyi dizerken bir sonraki harfi yan hücreye koymak zorlaşırdı.
//
// ⚠ BELİRSİZLİKTE TAHMİN ETMEZ. Bir oynanmış taşın İKİ yanında birden
// taslak olabilir (mevcut bir taşın hem üstüne hem altına harf koymak —
// kullanıcının "iki kelimenin birleştiği yer" tarifi). O zaman dokunuş
// noktasına en yakın olan seçilir; mesafeler eşitse ya da ölçüm yoksa
// `null` döner. Yanlış taşı geri almak, hiç tepki vermemekten DAHA kötü.
//
// Flutter portundaki eşi: `game_screen.dart` → `_nearbyDraftCell`
// (aynı aday sırası, aynı "en yakın merkez", aynı eşitlik kuralı).
export interface CellRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

export function nearbyDraftCell(
  size: number,
  r: number,
  c: number,
  hasDraftAt: (r: number, c: number) => boolean,
  point: { x: number; y: number } | null,
  rectOf: (r: number, c: number) => CellRect | null,
): [number, number] | null {
  const cands: [number, number][] = [];
  const add = (rr: number, cc: number) => {
    if (rr < 0 || rr >= size || cc < 0 || cc >= size) return;
    if (hasDraftAt(rr, cc)) cands.push([rr, cc]);
  };
  add(r - 1, c);
  add(r + 1, c);
  add(r, c - 1);
  add(r, c + 1);

  if (cands.length === 0) return null;
  if (cands.length === 1) return cands[0];
  if (!point) return null;

  const dist2 = ([rr, cc]: [number, number]) => {
    const rect = rectOf(rr, cc);
    if (!rect) return Number.POSITIVE_INFINITY;
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    return (point.x - cx) ** 2 + (point.y - cy) ** 2;
  };

  const sorted = [...cands].sort((a, b) => dist2(a) - dist2(b));
  if (!Number.isFinite(dist2(sorted[0]))) return null;
  // ⚠ PAY ŞART, çıplak `<` DEĞİL — portta CI yakaladı (24 Ağustos 2026):
  // hücrenin TAM ORTASINA dokunulduğunda iki mesafe matematiksel olarak
  // eşit ama kayan noktada ~1e-13 farkla biri "daha yakın" çıkıyor ve
  // "belirsizlikte tahmin etme" kuralı sessizce deliniyordu. 0.8 (kare
  // mesafede) ≈ 1.5 px'lik gerçek bir kayma demek: ölçüm gürültüsü altta
  // kalır, kasıtlı bir kayma rahatça geçer.
  return dist2(sorted[0]) < dist2(sorted[1]) * 0.8 ? sorted[0] : null;
}
