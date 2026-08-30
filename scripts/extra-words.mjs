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
  // ⚠ `banu` ile `banü` BİRBİRİNİN YAZIM VARYANTI DEĞİL — iki AYRI madde,
  // her biri kendi anlam listesiyle (28 Ağustos 2026, kullanıcı ayrıştırdı).
  // Bu yüzden ikisi de burada; biri ötekine `extra-meanings` üzerinden
  // eklenmedi. Komşuları ölçüldü: `bani` GTS'te VAR ve FARKLI bir kelime —
  // "ıs"/"is" vakasıyla (bkz. aşağıdaki not) aynı sınıf, benzer yazılışı
  // "aynıdır" saymak bu projede bir kez hataya yol açtı.
  banu: {
    pos: 'a.',
    meanings: [
      'Hanımefendi, soylu kadın.',
      'Gelin.',
      'Bağ, bahçe.',
    ],
  },
  banü: {
    pos: 'a.',
    meanings: [
      'Kadın, hanım.',
      'Hanımefendi, soylu kadın.',
    ],
  },
  // `pilav` GTS'te ZATEN VAR ve anlamlarına DOKUNULMADI; bu ayrı bir
  // madde (İran mutfağının kendi adı), onun yazım varyantı değil.
  çilav: {
    pos: 'a.',
    meanings: ['İran usulü pirinç pilavı.'],
  },
  evsel: {
    pos: 'sf.',
    meanings: ['Evle ilgili.'],
  },
  // Türediği `kolza` GTS'te ZATEN VAR ve anlamlarına DOKUNULMADI —
  // `kanola` o bitkinin ıslah edilmiş biçiminin adı, ayrı bir madde.
  kanola: {
    pos: 'a.',
    meanings: [
      'Turpgiller familyasından, sarı çiçekli kolza bitkisinin zararlı asitlerden arındırılarak ıslah edilmesiyle elde edilen yağ bitkisi.',
    ],
  },
  // `lapislazuli` (bitişik, tek madde) GTS'te ZATEN VAR ve anlamlarına
  // DOKUNULMADI; bu madde onun ilk sözcüğü olan Latince `lapis` ("taş").
  lapis: {
    pos: 'a.',
    meanings: [
      'Lapis lazuli olarak bilinen koyu mavi değerli taş; dilimizde daha çok tam hâliyle ya da laciverttaşı, lacivert taşı olarak anılır.',
    ],
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
  // Sınıf `a.` — kardeş maddelerle AYNI: bu sözlükte hayvan sesleri ad
  // sayılıyor (`miyav` → "Kedinin çıkardığı ses, kedi sesi", `hav` →
  // "Köpeğin çıkardığı ses"; ikisi de `a.`, ölçüldü). Kullanıcı önce
  // "(ünlem)" demişti, ölçüm gösterilince kardeşlere uydurulmasını istedi.
  // Tanım da aynı kalıpta: "sesi anlatan söz" ünlem dilidir (`hey`, `of`),
  // ad olan bir madde sesin KENDİSİNİ tanımlar.
  mö: {
    pos: 'a.',
    meanings: ['İneğin çıkardığı ses, inek sesi.'],
  },
  nil: {
    pos: null,
    meanings: [
      "Afrika'nın kuzeydoğusundan geçerek Akdeniz'e dökülen, dünyanın en uzun nehirlerinden biri.",
    ],
  },
  refil: {
    pos: 'a.',
    meanings: [
      'Biten bir ürünün yerine takılan yedek dolum veya yedek parça.',
      'Bir kabı yeniden doldurma, tekrar doldurma.',
    ],
  },
  // ⚠ `su` (u ile) ile KARIŞTIRMA — o GTS'te zaten var, bambaşka bir
  // kelime ve anlamlarına dokunulmadı. Türkçede u/ü ayrımı iki ayrı
  // sözcük demektir; bu proje aynı sınıf bir hatayı bir kez "ıs"/"is"
  // maddesinde yaşadı (bkz. aşağıdaki not ve docs/decisions/dictionary.md).
  sü: {
    pos: 'a.',
    meanings: ['Eski Türkçede asker, ordu, askerî birlik.'],
  },
  tarot: {
    pos: 'a.',
    meanings: [
      'Geleceği öğrenmek veya rehberlik almak amacıyla kullanılan 78 kartlık özel deste.',
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
