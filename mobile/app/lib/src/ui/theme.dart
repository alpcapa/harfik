// Uygulamanın TEK teması — `app.dart` ve testler AYNI fonksiyonu kullanır.
//
// Testlerin kendi `ThemeData`larını kurması bir sapma kaynağıydı: tema
// üründe değişse bile testler eski temayla render edip "geçmeye" devam
// ediyordu (Parça 71'in dersinin tema hâli — gerçek ekranı ölç, taklidini
// değil). Bu yüzden tek giriş noktası burası.
import 'package:flutter/material.dart';

/// Material 3'ün varsayılan harf aralığını (tracking) SIFIRLAR.
///
/// 13 Ağustos 2026 (Parça 78). `useMaterial3: true` iken `TextTheme`in
/// gövde/etiket stilleri 0.25-0.5 arası `letterSpacing` taşıyor ve
/// `letterSpacing` YAZMAYAN her `Text` bunu miras alıyor (widget kendi
/// style'ında o alanı `null` bıraktığında `Text` DefaultTextStyle ile
/// MERGE ediyor). Web'de karşılığı YOK: tailwind hiçbir yere kendiliğinden
/// letter-spacing koymuyor, tracking yalnızca AÇIKÇA yazıldığı yerlerde
/// var (`tracking-[1px]` gibi) ve port o yerlerde zaten kendi değerini
/// veriyor.
///
/// Bu, iki kez ÜRÜNDE görünen bir farka yol açtı: Parça 61'de bir satır
/// karta sığmayıp ikiye bölündü, Parça 77'de Setup'ın paragrafı 4 yerine
/// 5 satır oldu. İkisi de tek tek yamanmıştı; bu fonksiyon kaynağı kapatıyor.
///
/// **Yalnızca `letterSpacing` sıfırlanır** — punto/kalınlık/renk gibi her
/// şey Material'ın kendi değerinde kalır (onlar zaten ekran ekran açıkça
/// veriliyor).
TextTheme zeroTrackingTextTheme(TextTheme t) => TextTheme(
      displayLarge: t.displayLarge?.copyWith(letterSpacing: 0),
      displayMedium: t.displayMedium?.copyWith(letterSpacing: 0),
      displaySmall: t.displaySmall?.copyWith(letterSpacing: 0),
      headlineLarge: t.headlineLarge?.copyWith(letterSpacing: 0),
      headlineMedium: t.headlineMedium?.copyWith(letterSpacing: 0),
      headlineSmall: t.headlineSmall?.copyWith(letterSpacing: 0),
      titleLarge: t.titleLarge?.copyWith(letterSpacing: 0),
      titleMedium: t.titleMedium?.copyWith(letterSpacing: 0),
      titleSmall: t.titleSmall?.copyWith(letterSpacing: 0),
      bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0),
      bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: t.bodySmall?.copyWith(letterSpacing: 0),
      labelLarge: t.labelLarge?.copyWith(letterSpacing: 0),
      labelMedium: t.labelMedium?.copyWith(letterSpacing: 0),
      labelSmall: t.labelSmall?.copyWith(letterSpacing: 0),
    );

/// Web tailwind paletiyle hizalı uygulama teması.
///
/// `fontFamily`: web `fontFamily.sans` = Space Grotesk.
/// `scaffoldBackgroundColor`: web'de sayfa zemini BEYAZ (colors.bg) — soluk
/// gri değil; nömorfik gölge dengesi buna bağlı (kullanıcı karşılaştırması,
/// 6 Ağustos 2026).
ThemeData kelimekiTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0891B2)),
    useMaterial3: true,
    fontFamily: 'SpaceGrotesk',
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: zeroTrackingTextTheme(base.textTheme),
    primaryTextTheme: zeroTrackingTextTheme(base.primaryTextTheme),
  );
}
