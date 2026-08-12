// Oyuncu renk paleti — src/game/constants.ts PLAYER_COLORS'un UI portu.
// Core bilinçli olarak yalnızca colorIndex taşır (renk UI kararıdır,
// kelimeki_core'a girmez); hex değerleri web ile BİREBİR aynı — camgöbeği
// text'inin #0A6076 düzeltmesi (algısal karanlık dersi) dahil.
import 'dart:ui';

class PlayerColor {
  /// Ana çizgi/çerçeve rengi.
  final Color base;

  /// Köşe bölgesi ve taş arka planı için açık ton.
  final Color tint;

  /// Bölge vurgusu için daha da soluk ton.
  final Color zone;

  /// Renk üzerinde okunan koyu metin.
  final Color text;

  const PlayerColor({
    required this.base,
    required this.tint,
    required this.zone,
    required this.text,
  });
}

const List<PlayerColor> playerColors = [
  PlayerColor(
    // camgöbeği
    base: Color(0xFF0891B2),
    tint: Color(0xFFA9E4EF),
    zone: Color(0xFFE7F6FA),
    text: Color(0xFF0A6076),
  ),
  PlayerColor(
    // kırmızı
    base: Color(0xFFDC2626),
    tint: Color(0xFFFBDADA),
    zone: Color(0xFFFDEFEF),
    text: Color(0xFF7A1414),
  ),
  PlayerColor(
    // yeşil
    base: Color(0xFF16A34A),
    tint: Color(0xFFD6F3E1),
    zone: Color(0xFFEDFAF1),
    text: Color(0xFF0B5128),
  ),
  PlayerColor(
    // mor
    base: Color(0xFF7C3AED),
    tint: Color(0xFFDCC8FC),
    zone: Color(0xFFF3ECFE),
    text: Color(0xFF4A1A90),
  ),
];

/// Web Board.tsx'teki darken() — son hamle taşlarının tonunu koyulaştırır
/// (çerçeve yerine; çerçeve bölge dış hattıyla çakışıyordu, aynı gerekçe).
Color darken(Color c, double amount) => Color.fromARGB(
      (c.a * 255).round(),
      ((c.r * 255) * (1 - amount)).round().clamp(0, 255),
      ((c.g * 255) * (1 - amount)).round().clamp(0, 255),
      ((c.b * 255) * (1 - amount)).round().clamp(0, 255),
    );
