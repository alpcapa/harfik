// Kelimeki — TDK GTS dökümünde bulunmayan, elle eklenen oynanabilir maddeler.
// =====================================================================
// proper-nouns.mjs'ten FARKI kapsam: orası yalnızca coğrafi/özel adları
// (ülke, başkent, şehir, dil) tamamlar ve başlığı bunu söyler; sıradan
// sözcükleri oraya koymak o dosyayı kendi başlığı hakkında yalancı yapardı.
// Bu liste, GTS'te hiç geçmeyen ama oynanabilir sayılan sözcükler içindir.
//
// protected-words.mjs'ten FARKI ise amaç: orası upstream GTS'in SONRADAN
// kaldırdığı maddeleri geri koyar (yani bir zamanlar TDK verisiydi); burada
// ise hiç var olmamış maddeler elle eklenir.
//
// Biçim protected-words.mjs ile aynı: { kelime: { pos, meanings: [...] } }
// `pos` TDK kısaltmasıdır (a. = ad, sf. = sıfat); emin olunmayan maddelerde
// UYDURULMAZ, `null` bırakılır — anlam metni zaten açıklıyor.
//
// KURAL — "zaten varsa dokunma": build-dictionary.mjs ve
// augment-dictionary.mjs bu listeden yalnızca sözlükte HENÜZ OLMAYAN
// maddeleri ekler. Var olan bir kelimeye ek ANLAM kazandırmak istiyorsanız
// doğru yer burası değil, extra-meanings.mjs'tir.
//
// Bir madde eklendikten sonra `node scripts/augment-dictionary.mjs`
// çalıştırılmalı; gerisi (words.ts, meanings.json, migration) üretilir.
export const EXTRA_WORDS = {
  evsel: {
    pos: 'sf.',
    meanings: ['Evle ilgili.'],
  },
  lila: {
    pos: 'sf.',
    meanings: ['Açık eflatun veya leylak rengi.'],
  },
  ma: {
    // Bir sözcük değil bağlayıcı bir kök olduğundan TDK kısaltması yok.
    pos: null,
    meanings: [
      "Arapçada cansız nesnelere işaret eden veya \"o şey ki\" anlamına gelen bağlayıcı kök (örnek: mâ-ba'd — sondaki).",
      'Eski dilde su.',
    ],
  },
  nil: {
    pos: null,
    meanings: [
      "Afrika'nın kuzeydoğusundan geçerek Akdeniz'e dökülen, dünyanın en uzun nehirlerinden biri.",
    ],
  },
  tikli: {
    pos: 'sf.',
    meanings: [
      'İstem dışı kas hareketi veya alışkanlık hâline gelmiş garip bir davranışı (tiki) olan kimse.',
    ],
  },
  // "is" (i ile, kurum/kara leke) ile KARIŞTIRMA — o GTS'te zaten var ve
  // anlamlarına dokunulmadı. Bu madde ı ile başlar; "ıssız" (= sahipsiz)
  // sözcüğü de bu kökten türer.
  ıs: {
    pos: 'a.',
    meanings: ['Eski Türkçede ve halk ağzında sahip, iye, malik.'],
  },
};
