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
