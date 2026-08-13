// Form alanlarının TEK kaynağı — web'de de tek bir sınıf dizisi var:
//   w-full bg-bg border border-border rounded-md px-3 py-2 text-sm
//   text-text outline-none focus:border-accent transition-colors
// ve bu dize dokuz bileşende BİREBİR aynı. Port ise onu sekiz dosyaya
// kopyalamıştı ve kopyalar sessizce ayrışmıştı (dolgu 8 ya da 10, punto 16
// ya da tema varsayılanı, dolgu rengi beyaz ya da `_bg`) — Parça 54'teki
// renk sürüklenmesiyle AYNI sınıf risk.
//
// ÖLÇÜLEN web değerleri (derlenmiş CSS + Chromium, gerçek fontlarla):
//   yükseklik 38 · punto 16 · satır 20 · dolgu 8/12 · çerçeve 1px #DCE2EA
//   (odakta #2563EB) · yarıçap 6 · zemin #FFFFFF · metin #1B2430
//
// **Punto 16, `text-sm`in 14'ü DEĞİL:** `index.css`teki iOS zoom kuralı
// (`input, textarea, select { font-size: 16px !important }`) sınıfı eziyor,
// yani web'de GÖRÜNEN değer 16. Parça 56 bu maddeyi "web py-2=8, port 10"
// diye not ederken puntoyu 14 varsaymıştı — ölçüm bunu düzeltti.
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Web'in ölçülen giriş yüksekliği: 20 (satır) + 8 + 8 (dolgu) + 2 (çerçeve).
const double kInputHeight = 38;

const double _fontSize = 16;
const double _lineHeight = 20;

/// Giriş metni — punto/satır yüksekliği web ile birebir.
const kInputTextStyle = TextStyle(
  fontFamily: 'SpaceGrotesk',
  fontSize: _fontSize,
  height: _lineHeight / _fontSize,
  letterSpacing: 0,
  color: kText,
);

/// Placeholder. **Web'de placeholder'a HİÇ renk yazılmıyor** (tarayıcının
/// kendi grisi); port `tile-pts` token'ını kullanıyor — bilinçli, bkz.
/// Parça 61'in aynı notu.
const kInputHintStyle = TextStyle(
  fontFamily: 'SpaceGrotesk',
  fontSize: _fontSize,
  height: _lineHeight / _fontSize,
  letterSpacing: 0,
  color: kTilePts,
);

/// Web'deki tek sınıf dizisinin Flutter karşılığı.
///
/// [counterText] varsayılan olarak `''` — web'de karakter sayacı yok; sayan
/// ekranlar (sohbet, şikayet gerekçesi) kendi metnini AYRI bir satırda
/// gösteriyor.
InputDecoration kInputDecoration({
  String? hint,
  Widget? suffix,
  String? counterText = '',
  bool enabled = true,
}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: kBg, // web bg-bg (beyaz)
    hintText: hint,
    hintStyle: kInputHintStyle,
    counterText: counterText,
    suffixIcon: suffix,
    // web px-3 py-2 (8/12) + 1px çerçeve payı.
    //
    // CSS'te yükseklik = satır (20) + dolgu (8+8) + çerçeve (1+1) = 38 ve
    // çerçeve kutunun DIŞINA eklenir; Flutter'da `OutlineInputBorder`
    // çerçeveyi kutunun İÇİNE boyar, yani aynı dolguyla dış ölçü 36 kalır.
    // Dikeyde 1px çerçeve payı eklenince dış kutu 38, çerçevenin İÇİNDEKİ
    // boşluk da web'deki gibi 8 oluyor (ölçüldü).
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    enabledBorder: border(kBorder),
    focusedBorder: border(kAccent),
    disabledBorder: border(kBorder),
  );
}
