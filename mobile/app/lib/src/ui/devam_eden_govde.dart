// "Devam eden oyun" kartının ORTAK gövdesi ve tipografisi — Setup'ın Yapay
// Zeka sekmesindeki yerel kayıt satırı (`setup_screen.dart`) ile
// Arkadaşınla sekmesindeki Canlı oyun satırı (`live/live_games_tab.dart`)
// aynı kaynaktan beslensin diye.
//
// NEDEN AYRI DOSYA (2 Eylül 2026): gövde 2 Eylül sabahı `setup_screen`in
// İÇİNDE `_DevamEdenGovde` olarak, yani PRIVATE doğdu; Canlı oyun kartı
// o turda dokunulmadan kaldı ve iki kart sessizce AYRIŞTI. Kullanıcı
// cihazda gördü (1.0.5, `Derleme 4a0a29b`): YZ'de kalan süre kendi alt
// satırındayken Canlı'da durum etiketiyle aynı sağ sütunda duruyor ve
// "X açtı" yazısına biniyordu. Yani ayrışmanın sebebi düzenin YANLIŞ
// olması değil, DOĞRUSUNUN ulaşılamaz bir yerde durmasıydı — bu depoda
// kayıtlı hata sınıfı (bkz. kök `CLAUDE.md` → "Çalışma İlkesi", soru 1:
// bu kodun ikinci bir okuyucusu var mı?).
//
// Tipografi de burada, çünkü ayrışan YALNIZCA düzen değildi: iki kart
// puntoyu/ağırlığı iki ayrı yerde tekrar ediyordu ve 30 Ağustos'taki
// 11 → 13 px değişikliği ikisine ELLE taşınmıştı. Tek kaynak, bir daha
// elle taşınmasın diye.
import 'package:flutter/material.dart';

/// Durum etiketinin ("SIRA SENDE" / "SIRA RAKİPTE") puntosu.
///
/// 11 → 13 (30 Ağustos 2026) → **15** (2 Eylül 2026, kullanıcı isteği:
/// *"Sıra Sende ve Sıra Rakipte fontu biraz daha büyüt"*).
///
/// ⚠ Bu sayı kartın sol sütunundan yer YER: durum etiketi `Expanded`
/// olmayan taraftadır, yani genişledikçe isim/avatar alanı daralır ve
/// yazı ölçeği tavanında (`kMaxTextScale`) daralma en sert hâline gelir.
/// `setup_screen_test.dart` → *"DEVAM EDEN OYUN: … isim alanı sıkışmaz"*
/// bunun oranını kilitliyor; bu sabiti büyütürken o testin ölçtüğü oran
/// CI'dan OKUNMALI (bu ortamda Flutter yok — kök `CLAUDE.md`, kural 4).
const double kDevamEdenDurumPunto = 15;

/// Durum etiketinin (yeşil "SIRA SENDE" / kırmızı "SIRA RAKİPTE") stili.
TextStyle devamEdenDurumStil(Color renk) => TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: kDevamEdenDurumPunto,
      height: 1, // ok/nokta satırı büyütmesin (bkz. turnTriangleSpan)
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
      color: renk,
    );

/// Alttaki kalan-süre satırının stili (web `text-[8px] tracking-[0.5px]`).
/// Avatarların altındaki PUAN SATIRI da bu stili kullanır (6 Eylül 2026,
/// kullanıcı: "font kalan süre ile aynı olsun") — üç kartta da
/// (`_SavedGameRow` · `_GameRow` · `_RecentRow`).
TextStyle devamEdenSureStil(Color renk) => TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: 8,
      letterSpacing: 0.5,
      color: renk,
    );

/// Testlerin SOL ALANI (isim/avatar tarafı) ölçebilmesi için.
///
/// Neden anahtar gerekti: sıkışmayı ölçen test sol sütunu
/// `find.ancestor(of: PlayerAvatarRow, matching: Column)` ile buluyordu ve
/// bu, Setup kartının sol tarafı "avatar şeridi + Sıra: X" iken çalışıyordu.
/// 2 Eylül 2026'da o alt satır kalkınca sol taraf TEK bir `PlayerAvatarRow`a
/// indi — kendi eni SABİT (36 px), yani bulucu DIŞ sütuna sıçrar ve testi
/// düşürmek yerine YANLIŞ ŞEYİ (kartın tamamını) ölçerdi. Sessiz yeşil,
/// düşen testten kötüdür.
const Key kDevamEdenSolKey = Key('devam-eden-sol');

/// Kartın gövdesi: üstte tek satır (sol oyuncular, sağ durum etiketi),
/// altta tam genişlik kalan-süre satırı.
///
/// **Süre neden ÜST SATIRDA DEĞİL** (2 Eylül 2026, ölçüldü — 320 px):
/// durum ve süre tek bir sağ sütunda toplandığında o sütunun enini
/// SÜRE belirliyor ("SIRA SENDE" 89,6 px, süre satırı **194,3 px**), yani
/// isim alanını daraltan etiket değil süredir — üstelik yazı ölçeği 1,0'da
/// bile. Süre alta, tam genişlik bir satıra indiğinde sağ sütunun eni
/// yalnızca etikete düşer; süre hâlâ sağ kenara yaslı olduğundan görsel
/// çapa değişmez.
class DevamEdenGovde extends StatelessWidget {
  /// Sol taraf: avatar şeridi + altında puan satırı (6 Eylül 2026'ya kadar
  /// Canlı kartında "X açtı" satırıydı; kurucu zaten `slots[0]`, kalktı).
  final Widget sol;

  /// Sağ üstteki durum etiketi.
  final Widget durum;

  /// Alt satırdaki kalan süre. **Null olabilir** — Canlı oyun kartı süreyi
  /// yalnızca sıra ÇAĞIRANDAYKEN gösteriyor (yanlış tarafa ait bir sürenin
  /// bir an görünmesindense hiç görünmemesi tercih edildi).
  final Widget? sure;

  const DevamEdenGovde(
      {super.key, required this.sol, required this.durum, this.sure});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          // `Align` bilerek: `Expanded`ın kendi render kutusu yok, sol
          // alanın enini ölçülebilir kılan bu (bkz. kDevamEdenSolKey).
          // Hizalama Row'un zaten yaptığını tekrar ediyor, düzen değişmiyor.
          Expanded(
            child: Align(
              key: kDevamEdenSolKey,
              alignment: Alignment.centerLeft,
              child: sol,
            ),
          ),
          durum,
        ]),
        if (sure != null) ...[
          // 8 px — web `gap-0.5` + `mt-1.5` (kullanıcı isteği): süre satırı
          // durum etiketine YAPIŞMASIN.
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: sure),
        ],
      ],
    );
  }
}
