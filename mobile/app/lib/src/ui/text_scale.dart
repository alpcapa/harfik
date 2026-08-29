// Sistem yazı boyutu (textScaler) karşısında düzenin kuralları.
//
// NEDEN VAR (28 Ağustos 2026, kullanıcı cihazda bildirdi: *"Görmediği için
// telefon fontlarını büyütenlerde ciddi sorunlar çıkıyor. Mesela, arkadaşlık
// davetinde davetin kimden geldiği görünmüyor. Bunun dışında başka yerler de
// patlıyor."*): Android/iOS yazı boyutunu %200'e kadar büyütebiliyor ve bu
// YALNIZCA metni büyütüyor — kutu, ikon, dolgu sabit kalıyor.
//
// İKİ AYRI HATA SINIFI var ve tek bir çözüm ikisini birden kapatmıyor:
//
//   1. TAŞMA — satır kabına sığmıyor, Flutter sarı-siyah şeridi çiziyor.
//      Çözümü [kMaxTextScale]: tavan koymak. ÖLÇÜLDÜ (tüm takım, ölçek
//      enjekte edilerek): 1,0 → 0 taşma · 1,3 → 10 · 1,6 → 27 · 2,0 → 73.
//
//   2. SIFIRA SIKIŞMA — taşma YOK, ama satırdaki tek esnek öğe (genelde
//      isim) sabit genişlikli komşuları büyüdükçe eziliyor. Hiçbir hata
//      basılmaz; kullanıcı sadece bilginin kaybolduğunu görür. Tavan bunu
//      ÇÖZMEZ, yalnızca geciktirir — 360 px ekranda arkadaşlık isteği
//      satırındaki isim ölçek 1,0'da 77,6 px, 1,3'te 53,2 px, 2,0'da
//      0,0 px (ölçüldü). Çözümü [buyukOlcek]: eşik aşılınca satırı İKİYE
//      BÖLMEK (üstte isim, altta butonlar) — web'in `CARD_HEADER`
//      düzeltmesiyle (23 Ağustos 2026) aynı ilke: kırpılacak EN SON şey
//      kimden geldiğidir.
//
// ⚠ Web'de karşılığı YOK ve bu bir port eksiği değil: tarayıcı `text-sm`
// gibi px değerlerini sistem yazı boyutuyla ölçeklemez, kullanıcı tüm
// SAYFAYI zoom'lar — yani kutular da birlikte büyür ve sınıf 2 hiç doğmaz.
// Bu yüzden burada web'den kopyalanacak bir yapı yok, yalnızca ilkesi var.
library;

import 'package:flutter/widgets.dart';

/// Uygulamanın kabul ettiği en yüksek sistem yazı ölçeği.
/// `KelimekiApp`in `MaterialApp.builder`ında TEK yerden uygulanır
/// (`MediaQuery.withClampedTextScaling`).
const double kMaxTextScale = 1.3;

/// Düzenin "artık tek satıra sığmaz" saydığı eşik.
///
/// [kMaxTextScale]'in ALTINDA olmalı — tavana eşit olsaydı kural hiçbir
/// zaman tetiklenmezdi (kısıt ölçeği asla eşiğin üstüne çıkarmaz).
const double kWideLayoutScale = 1.15;

/// Bu bağlamda metin, düzeni bozacak kadar büyümüş mü?
/// Kullanımı: `if (buyukOlcek(context)) ...` → satırı ikiye böl.
bool buyukOlcek(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) / 100 >= kWideLayoutScale;
