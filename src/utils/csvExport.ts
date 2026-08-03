// Kelimeki — admin paneli tabloları için basit CSV export yardımcısı

/** CSV alanını gerektiğinde tırnak içine alır (virgül/tırnak/satır sonu içeriyorsa). */
function escapeCsvField(value: string | number | null | undefined): string {
  const s = value == null ? '' : String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/**
 * Başlık + satırları CSV'ye çevirip tarayıcıda indirir. Başına UTF-8 BOM
 * (﻿) eklenir — yoksa Excel Türkçe karakterleri (ı/ğ/ş/ç/ö/ü) bozuk açar.
 */
// Kod incelemesinde "büyük veri setinde senkron map/join ana thread'i
// bloklayabilir" bulgusu değerlendirildi: admin panelindeki mevcut veri
// hacimleri (üyeler/geri bildirim/büyüme serileri) yüzlerce-birkaç bin
// satırı geçmiyor, bu ölçekte map/join zaten milisaniyeler sürüyor — bir
// Web Worker'a/parçalı işlemeye taşımak bu aşamada gereksiz karmaşıklık
// olurdu. Hacim gerçekten büyürse (on binlerce satır) tekrar değerlendirilebilir.
export function downloadCsv(
  filename: string,
  headers: string[],
  rows: (string | number | null | undefined)[][],
): void {
  const lines = [headers, ...rows].map((row) => row.map(escapeCsvField).join(','));
  const csv = '﻿' + lines.join('\r\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
