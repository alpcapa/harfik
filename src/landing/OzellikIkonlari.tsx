/**
 * Kelimeki — karşılama katmanı "Neler var" bölümündeki altı özellik ikonu
 * (18 Ağustos 2026, kullanıcı isteği: "6 kutuya uygun ikonlar koyalım.
 * Başlığın hemen yanına minik, yazı kadar.").
 *
 * ⚠ BU DOSYA `RelationIcons.tsx` DEĞİL — ve bu bilinçli. Oradaki ikonlar
 * Flutter'ın `MaterialIcons-Regular.otf`'undan çıkarılmış Material glyph'leri;
 * gerekçesi portun AYNI vektörü `Icons.*` ile çizmesi, yani parite. Buradaki
 * altı ikon ise Material DEĞİL, ilkel şekillerden kurulu.
 *
 * ⚠ 19 Ağustos 2026'dan beri PORTTA KARŞILIĞI VAR ve İKİSİ ELLE SENKRON:
 * `mobile/app/lib/src/ui/intro/ozellik_ikonlari.dart` aynı şekilleri
 * `CustomPainter` ile çiziyor (yine `Icons.*` DEĞİL — o, iki platformda
 * FARKLI vektör demek olurdu). Bu dosya bir dönem "portta karşılığı YOK ve
 * olamaz" diyordu; kullanıcı portun tanıtım ekranını "webin aynısı (6 kutu)"
 * isteyince o karar geçersizleşti. Biri değişirse öteki de değişmeli — bunu
 * zorlayan bir test YOK. Material path'lerini hafızadan yazmak ise bu kod tabanında bir
 * kez denenip yanlış glyph üretmişti (bkz. `RelationIcons.tsx` başlığı) ve bu
 * ortamda çıkarılacak bir font dosyası yok — o yüzden ikonlar ezberden path
 * değil, DOĞRULANABİLİR ilkel şekillerden (daire/dikdörtgen/çizgi/yay)
 * kuruldu ve gerçek Chromium render'ıyla gözle denetlendi.
 *
 * Ortak kurallar:
 *   • 24'lük viewBox, `stroke="currentColor"`, dolgu YOK — renk çağırandan
 *     miras alınır (bugün `text-accent`).
 *   • Varsayılan boy 13px: yanındaki başlık `text-[12px]`, yani "yazı kadar".
 *     Çizgi kalınlığı 2 → 13px'te ~1.1 CSS px, retinada net.
 *   • `aria-hidden`: ikonun anlattığı her şeyi yanındaki başlık zaten yazıyor;
 *     ekran okuyucuya ikinci kez okutmak gürültü olur.
 *
 * ⚠ SAYFA BÜTÇESİ: bu ikonlar `dist/index.html`'in İÇİNE gömülüyor (katman
 * sunucuda statik HTML'e render ediliyor). Altısının toplam maliyeti ölçüldü:
 * ham +2.6 KB / gzip +0.4 KB. Yeni bir ikon eklenirse ilkel şekillerde kal —
 * uzun bir `<path>` verisi bu bütçeyi hızla büyütür.
 */

import type { ReactNode } from 'react';

interface OzellikIkonProps {
  /** Kenar uzunluğu (px). Varsayılan 13 — başlık puntosuyla aynı. */
  size?: number;
}

function Ikon({ size = 13, children }: OzellikIkonProps & { children: ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

/** Robot kafası — "Yapay zekaya karşı oyna". */
export function RobotIkon(props: OzellikIkonProps) {
  return (
    <Ikon {...props}>
      <path d="M12 2.5V6" />
      <rect x="3.5" y="6" width="17" height="13" rx="3.5" />
      <circle cx="9" cy="12.5" r="0.6" fill="currentColor" strokeWidth="1.6" />
      <circle cx="15" cy="12.5" r="0.6" fill="currentColor" strokeWidth="1.6" />
    </Ikon>
  );
}

/** İki oyuncu — "Arkadaşınla canlı oyna". */
export function IkiKisiIkon(props: OzellikIkonProps) {
  return (
    <Ikon {...props}>
      <circle cx="8.5" cy="8" r="3.2" />
      <path d="M2.5 20c0-3.1 2.7-5.2 6-5.2s6 2.1 6 5.2" />
      <path d="M17 5.2a3 3 0 0 1 0 5.9" />
      <path d="M17.5 15.2c2.4.5 4 2.3 4 4.8" />
    </Ikon>
  );
}

/** Konuşma balonu — "Oyun içi sohbet". */
export function SohbetIkon(props: OzellikIkonProps) {
  return (
    <Ikon {...props}>
      <rect x="3" y="4" width="18" height="13" rx="3.5" />
      <path d="M8.5 17v4l4.5-4" />
    </Ikon>
  );
}

/** Üstü çizili wifi — "Çevrimdışı da oynar". */
export function CevrimdisiIkon(props: OzellikIkonProps) {
  return (
    <Ikon {...props}>
      <path d="M2 14.4a11 11 0 0 1 20 0" />
      <path d="M6.1 16.3a6.5 6.5 0 0 1 11.8 0" />
      <circle cx="12" cy="19.5" r="0.6" fill="currentColor" strokeWidth="1.6" />
      <path d="M3.5 3.5 20.5 20.5" />
    </Ikon>
  );
}

/** Tahta + konmuş taş — "Kelime denemesi". */
export function TahtaIkon(props: OzellikIkonProps) {
  return (
    <Ikon {...props}>
      <rect x="3" y="3" width="18" height="18" rx="3" />
      <path d="M12 3v18M3 12h18" />
      <rect x="13.6" y="13.6" width="5.8" height="5.8" rx="1" fill="currentColor" />
    </Ikon>
  );
}

/** Kurdeleli madalya — "k-lig ve rütbeler". */
export function MadalyaIkon(props: OzellikIkonProps) {
  return (
    <Ikon {...props}>
      <circle cx="12" cy="8.5" r="5.5" />
      <path d="M8.4 12.7 6.5 21l5.5-2.8L17.5 21l-1.9-8.3" />
    </Ikon>
  );
}
