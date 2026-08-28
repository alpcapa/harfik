// Push'un SAF kararları (izin sorma + platform eşlemesi) — Flutter/Firebase
// bağımlılığı YOK, Flutter/Firebase bağımlılığı YOK.
//
// **Neden ayrı ve saf (28 Ağustos 2026, ROADMAP madde 13):** bu karar bir
// widget'ın içine gömülürse test edilemez, ama yanlışı pahalı. Android 13+'ta
// `POST_NOTIFICATIONS` bir runtime izni ve **İKİNCİ redden sonra sistem
// diyaloğu bir daha HİÇ gösterilmiyor** — sonraki istekler UI açmadan döner
// ve tek çare kullanıcıyı sistem ayarlarına göndermek. Yani "bağlamsız sor"
// hatası geri alınamaz.
//
// Bu yüzden akış İKİ AŞAMALI ve sıra kritik:
//   1. Bizim kendi sayfamız ("Sıra sana geldiğinde haber verelim mi?")
//   2. YALNIZCA kullanıcı orada "Aç" derse sistem diyaloğu
// "Şimdi Değil" bir sistem denemesi HARCAMAZ — ara adımın tek varlık sebebi
// bu. Doğrudan sistem diyaloğunu açsaydık her "hayır" kalıcı hakkımızdan
// yerdi.
library;

/// Sorma sayfasının gösterilip gösterilmeyeceği.
///
/// [aktifOyunVar] — en az bir aktif Canlı oyun ya da bekleyen davet.
///   ⚠ Bu koşul konum değil DURUM: "bu kişiye bildirim gerçekten işe yarar
///   mı?" Oyunu olmayan birine, olmayan oyunlar için bildirim sormuyoruz.
///   Aynı kontrol hem Canlı sekmesi açılışında hem oyun kurma/kabul anında
///   çalışır (hangisi önce gelirse).
/// [izinZatenVerildi] — sistem izni verilmişse hiç sorma.
/// [kalıcıReddedildi] — sistem kalıcı reddetmişse sormanın anlamı yok:
///   diyalog artık açılmıyor. Kullanıcıya yapılacak tek şey Hesap
///   Ayarları'ndan sistem ayarlarına yönlendirmek.
/// [soruldu] — bizim sayfamızın kaç kez gösterildiği.
/// [sonSorulma] / [simdi] — son gösterimden bu yana geçen süre.
///
/// Kural: en fazla **üç** kez, aralarında en az **yedi gün**. Sonsuza kadar
/// rahatsız etmek de, bir kez sorup bırakmak da yanlış — ilk seferde "şimdi
/// değil" diyen biri iki hafta sonra oyunu ciddiye almış olabilir.
bool pushIzniSorulmali({
  required bool aktifOyunVar,
  required bool izinZatenVerildi,
  required bool kaliciReddedildi,
  required int soruldu,
  required DateTime? sonSorulma,
  required DateTime simdi,
}) {
  if (!aktifOyunVar) return false;
  if (izinZatenVerildi) return false;
  if (kaliciReddedildi) return false;
  if (soruldu >= kPushSormaAzamiSayi) return false;
  if (sonSorulma == null) return true;
  return simdi.difference(sonSorulma) >= kPushSormaAralik;
}

const int kPushSormaAzamiSayi = 3;
const Duration kPushSormaAralik = Duration(days: 7);

/// Bu cihazın `push_tokens.platform` değeri; token KAYDEDİLEMEZse `null`.
///
/// ⚠ `currentPlatform` ile AYNI ŞEY DEĞİL ve karıştırmak sessiz bir arıza
/// üretir: o fonksiyon telemetri için `'app-web'` de dönebiliyor, oysa
/// `push_tokens.platform` sütununun check kısıtı YALNIZCA `'android'|'ios'`
/// kabul ediyor. `'app-web'` yollamak insert'i düşürür — yani token hiç
/// kaydedilmez ve kullanıcı hiç bildirim almaz, üstelik kimse fark etmez.
///
/// Flutter WEB derlemesi bir TEST ORTAMI, ürün değil; FCM web push'u bu
/// projede kapsam dışı. Masaüstü hedefleri de yayınlanmıyor. İkisinde de
/// doğru davranış "uydurma bir değer yolla" değil, **hiç kaydetme**.
String? pushPlatform(String? platform) {
  if (platform == 'android' || platform == 'ios') return platform;
  return null;
}
