// Bekleme göstergesi — web `LoadingNote.tsx` ile BİREBİR aynı görsel.
//
// NEDEN VAR (24 Ağustos 2026): kullanıcı cihazda lider tablosunu ve skor
// kartını açınca *"önce 1-2 saniye bir popup görüyorum, sonra sıralama
// üstüne geliyor"* dedi — pencere BOŞ açılıyor sanılıyordu. Oysa yükleme
// durumu vardı: 12 punto, `kMuted` gri, küçük harf "Yükleniyor…". Yani
// eksik olan durum değil, OKUNURLUĞUYDU.
//
// Gecikmenin kendisi UI'ın çözebileceği bir şey DEĞİL (lider tablosu
// sorgusu sunucuda 4.3 ms; kalanı mesafe — veritabanı `ap-south-1`/
// Mumbai'de, bkz. `docs/decisions/product-backlog.md` bölge taşıma
// maddesi). Yapılabilecek şey bekleyişi GÖRÜNÜR kılmak.
//
// ANİMASYON YOK ve bu bilinçli: sonsuz tekrarlı bir spinner
// (`CircularProgressIndicator` dahil) `pumpAndSettle` ile ASLA
// dinginleşmez, yani bu durumu ekranda gören her widget testi zaman
// aşımına düşerdi (bu pakette 20'den fazla dosya `pumpAndSettle`
// kullanıyor). Okunurluk bunun yerine punto/ağırlık/renk/boşlukla
// sağlanıyor.
//
// METİN AYNI KALDI ("Yükleniyor…") — hem kullanıcı alışkanlığı hem de
// birkaç testin bu dizeyi araması yüzünden.
import 'package:flutter/material.dart';

import 'tokens.dart';

class KLoadingNote extends StatelessWidget {
  /// Dikey nefes payı — web'in `py-*` sınıfının karşılığı. Gömülü/dar
  /// yerlerde (bir kartın içindeki tahta önizlemesi gibi) küçültülür.
  final double vertical;

  const KLoadingNote({super.key, this.vertical = 24});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: const Center(
        child: Text(
          'Yükleniyor…',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: kAccent,
          ),
        ),
      ),
    );
  }
}
