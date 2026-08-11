/**
 * Kelimeki — arkadaşlık ilişkisi ikonları (11 Ağustos 2026).
 *
 * `FriendsModal`'ın iki sekmesindeki ("Ara & Ekle", "Arkadaşlarım") metin
 * butonları (Ekle / İstek Gönderildi / Kabul Et / Arkadaşsınız / Çıkar) ve
 * `PlayerScoreCard`'daki simge, tek bir ikon diline indirildi. Kural: **ikon,
 * DOKUNUŞUN NE YAPACAĞINI söyler, ilişkinin adını değil.** Bu yüzden
 * "arkadaşsınız" durumu yeşil onay değil kırmızı `person_remove` — dokununca
 * yaptığı şey çıkarmak. (Yeşil `check_circle` 9 Ağustos'ta eklenmişti;
 * durumu anlatıyordu ama eylemi anlatmadığından keşfedilebilirlik zayıftı.)
 *
 * | İlişki | İkon | Renk |
 * |---|---|---|
 * | arkadaş değil | person_add | accent |
 * | istek gönderdim | hourglass_top | muted |
 * | bana istek geldi | how_to_reg | accent |
 * | arkadaşız | person_remove | red |
 *
 * **`PlayerScoreCard` bu tablonun son satırında BİLİNÇLİ bir istisna** (kullanıcı
 * kararı, 11 Ağustos 2026): orada arkadaş durumu yeşil `how_to_reg` çizilir,
 * kırmızı `person_remove` değil. Gerekçe: listelerde ikon bir AKSİYON
 * sütununda durur; skor kartında ise ismin hemen yanında durur ve kimliğin
 * parçası gibi okunur — "adam-" orada bir uyarı gibi görünüyordu. Dokunuş
 * yine de çıkarma onayını açar, yani kural (dokunuş ne yapıyorsa onu sor)
 * onay diyaloğuyla korunuyor. Aynı glyph iki yerde iki farklı şey anlatıyor
 * — listede "gelen isteği kabul et" (mavi), kartta "arkadaşsınız" (yeşil);
 * renk ayrımı bu yüzden zorunlu, ikisini aynı renge çekme.
 *
 * **Hiçbir ikon dokunulduğu an iş yapmaz** — dördü de önce bir onay
 * diyaloğu açar (`FriendsModal`'ın ConfirmDialog'ları / `PlayerScoreCard`'ın
 * `friendDialogCopy`si). Etiketsiz bir ikona kazara dokunmak metin butonuna
 * göre çok daha kolay; yeni bir ilişki ikonu eklerken bu sözleşmeyi koru.
 *
 * **Path verisi elle çizilmedi**, Flutter SDK'sının `MaterialIcons-Regular.otf`
 * dosyasından fontTools ile çıkarılıp 24'lük viewBox'a dönüştürüldü
 * (unitsPerEm 512 → ölçek 24/512, y ekseni ters). Flutter portu aynı
 * glyph'leri `Icons.*` ile doğrudan çiziyor (font gömülü), yani iki platform
 * BENZER değil AYNI vektörü kullanıyor.
 *
 * **Codepoint'leri hafızadan yazma** — 11 Ağustos'ta tam bunu deneyip yanlış
 * glyph'ler (saat yerine hamburger, person_remove yerine `<>`) çizdirdim.
 * `cmap`'te "o kodda bir glyph var" demek aradığın ikon olduğu anlamına
 * gelmiyor. Tek doğru kaynak Flutter'ın kendi
 * `packages/flutter/lib/src/material/icons.dart` dosyası.
 *
 * Yeni bir ilişki ikonu gerekirse buraya ekle; `FriendsModal`/
 * `PlayerScoreCard` path'i kendi içine KOPYALAMASIN.
 */

interface RelationIconProps {
  /** Kenar uzunluğu (px). Varsayılan 20 — satır içi kullanım. */
  size?: number;
}

/** Material `Icons.person_add_alt_1` (U+E494). */
export function PersonAddIcon({ size = 20 }: RelationIconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12.984375 8.015625C12.984375 5.8125 11.203125 3.984375 9.0 3.984375C6.796875 3.984375 5.015625 5.8125 5.015625 8.015625C5.015625 10.21875 6.796875 12.0 9.0 12.0C11.203125 12.0 12.984375 10.21875 12.984375 8.015625ZM15.0 9.984375V12.0H18.0V15.0H20.015625V12.0H23.015625V9.984375H20.015625V6.984375H18.0V9.984375H15.0ZM0.984375 18.0V20.015625H17.015625V18.0C17.015625 15.328125 11.671875 14.015625 9.0 14.015625C6.328125 14.015625 0.984375 15.328125 0.984375 18.0Z" />
    </svg>
  );
}

/** Material `Icons.hourglass_top` (U+E327). */
export function HourglassIcon({ size = 20 }: RelationIconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M6.0 2.015625V8.015625L9.984375 12.0L6.0 16.03125V21.984375H18.0V15.984375L14.015625 12.0L18.0 8.015625V2.015625H6.0ZM15.984375 16.5V20.015625H8.015625V16.5L12.0 12.515625L15.984375 16.5Z" />
    </svg>
  );
}

/** Material `Icons.how_to_reg` (U+E32B). */
export function HowToRegIcon({ size = 20 }: RelationIconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M9.0 17.015625 12.0 14.0625C11.625 14.015625 11.296875 14.015625 11.015625 14.015625C8.34375 14.015625 3.0 15.328125 3.0 18.0V20.015625H12.0L9.0 17.015625ZM11.015625 12.0C13.21875 12.0 15.0 10.21875 15.0 8.015625C15.0 5.8125 13.21875 3.984375 11.015625 3.984375C8.8125 3.984375 6.984375 5.8125 6.984375 8.015625C6.984375 10.21875 8.8125 12.0 11.015625 12.0ZM15.46875 20.484375 12.0 17.015625 13.40625 15.609375 15.46875 17.671875 20.578125 12.515625 21.984375 13.921875 15.46875 20.484375Z" />
    </svg>
  );
}

/** Material `Icons.person_remove` (U+E49A). */
export function PersonRemoveIcon({ size = 20 }: RelationIconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M14.015625 8.015625C14.015625 5.8125 12.1875 3.984375 9.984375 3.984375C7.78125 3.984375 6.0 5.8125 6.0 8.015625C6.0 10.21875 7.78125 12.0 9.984375 12.0C12.1875 12.0 14.015625 10.21875 14.015625 8.015625ZM17.015625 9.984375V12.0H23.015625V9.984375H17.015625ZM2.015625 18.0V20.015625H18.0V18.0C18.0 15.328125 12.65625 14.015625 9.984375 14.015625C7.3125 14.015625 2.015625 15.328125 2.015625 18.0Z" />
    </svg>
  );
}
