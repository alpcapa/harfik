// Kart altı PUAN SATIRININ GEOMETRİSİ — "Devam Eden" (Canlı + YZ) ve "Son
// Oynananlar" kartlarında her puan KENDİ AVATARININ TAM ALTINDA durur
// (6 Eylül 2026, kullanıcı isteği: *"avatarların altına kişilerin o anki
// puanlarını yazalım … Böylece oyuna girmeden puan durumunu görebilsinler"*).
//
// ⚠ İLK HÂLİ TEK BİR DİZEYDİ (`45 - 38`) ve kullanıcı aynı gün bildirdi:
// *"Puanlar avatarların tam altına gelmiyor. Özellikle 4 kişilik oyunda."*
// Sebep yapısal: avatarlar ÜST ÜSTE BİNİYOR (26 px çap, 6 px binişme →
// adım 20 px), akan bir metin ise kendi harf genişliğine göre ilerler; iki
// ritim 4 koltukta tamamen ayrışır. Çözüm sayıları avatar adımına oturtmak,
// ve o zaman ayırıcı tireye de gerek kalmıyor — ayrımı HİZA yapıyor
// (kullanıcı kararı: "C hizalı").
//
// Sıra AVATAR SIRASIDIR (koltuk / snapshot sırası), sıralama (rank) DEĞİL:
// üstteki `PlayerAvatarRow` aynı diziyi çiziyor, yani N'inci puan N'inci
// yüzün altına düşer. Port ikizi: `mobile/app/lib/src/util/score_line.dart`.

/**
 * Bir puan hücresinin eni = avatar ADIMI. Bindirme yüzünden bu, avatar
 * çapından küçüktür (26 → 20): i'inci avatarın sol kenarı `i*adım`.
 */
export function scoreCellWidth(avatarSize: number, overlap: number): number {
  return avatarSize - overlap;
}

/**
 * Satırın sola kaydırması. i'inci avatarın MERKEZİ `i*adım + çap/2`, i'inci
 * hücrenin merkezi ise `offset + i*adım + adım/2` — ikisi eşitlenince
 * `offset = (çap - adım)/2 = binişme/2` çıkar (26/6 için 3 px).
 */
export function scoreRowOffset(overlap: number): number {
  return overlap / 2;
}
