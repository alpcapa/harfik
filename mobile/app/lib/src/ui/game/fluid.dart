// Web'in CSS `clamp(min, calc(a + b·vw), max)` (ve tek terimli `clamp(min,
// b·vw, max)`, a=0) akıcı boyutlandırma deseninin ortak Flutter karşılığı —
// vw = ekran genişliği / 100. `game_header.dart`'ta yalnızca kendi
// kullanımı için yazılmıştı (`_fluid`); `tile_widget.dart`'ın board harf/
// puan puntosu için de AYNI formül gerektiğinden (bkz. `Tile.tsx`'in
// `clamp(14px,3.8vw,24px)`/`clamp(6px,1.6vw,10px)`'i) tek kaynağa çıkarıldı
// — iki widget'ın formülü sessizce ayrışmasın diye.
double fluidSize(double screenWidth, double min, double a, double b, double max) {
  final v = a + b * (screenWidth / 100);
  return v.clamp(min, max);
}
