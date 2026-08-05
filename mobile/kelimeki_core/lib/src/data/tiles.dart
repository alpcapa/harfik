// Kelimeki core — Türkçe harf dağılımı ve puanları (src/data/tiles.ts portu).
// Toplam 100 taş. '?' jokerdir: 0 puan, oynanırken bir harfe dönüşür.
// SIRA ÖNEMLİDİR: buildBag torbayı bu ekleme sırasıyla kurar; golden vector
// replay'inin TS ile aynı desteden çekmesi bu sıraya bağlıdır.

class TileInfo {
  final int pts;
  final int cnt;
  const TileInfo({required this.pts, required this.cnt});
}

const Map<String, TileInfo> tileData = {
  '?': TileInfo(pts: 0, cnt: 2),
  'A': TileInfo(pts: 1, cnt: 12),
  'B': TileInfo(pts: 3, cnt: 2),
  'C': TileInfo(pts: 4, cnt: 2),
  'Ç': TileInfo(pts: 3, cnt: 2),
  'D': TileInfo(pts: 3, cnt: 2),
  'E': TileInfo(pts: 1, cnt: 8),
  'F': TileInfo(pts: 7, cnt: 1),
  'G': TileInfo(pts: 5, cnt: 1),
  'Ğ': TileInfo(pts: 8, cnt: 1),
  'H': TileInfo(pts: 5, cnt: 1),
  'I': TileInfo(pts: 2, cnt: 4),
  'İ': TileInfo(pts: 1, cnt: 7),
  'J': TileInfo(pts: 10, cnt: 1),
  'K': TileInfo(pts: 1, cnt: 7),
  'L': TileInfo(pts: 1, cnt: 7),
  'M': TileInfo(pts: 2, cnt: 4),
  'N': TileInfo(pts: 1, cnt: 5),
  'O': TileInfo(pts: 2, cnt: 3),
  'Ö': TileInfo(pts: 7, cnt: 1),
  'P': TileInfo(pts: 5, cnt: 1),
  'R': TileInfo(pts: 1, cnt: 6),
  'S': TileInfo(pts: 2, cnt: 3),
  'Ş': TileInfo(pts: 4, cnt: 2),
  'T': TileInfo(pts: 1, cnt: 5),
  'U': TileInfo(pts: 2, cnt: 3),
  'Ü': TileInfo(pts: 3, cnt: 2),
  'V': TileInfo(pts: 7, cnt: 1),
  'Y': TileInfo(pts: 3, cnt: 2),
  'Z': TileInfo(pts: 4, cnt: 2),
};

/// Bir harfin puanı (joker ya da bilinmeyen harf için 0).
int letterPoints(String letter) => tileData[letter]?.pts ?? 0;
