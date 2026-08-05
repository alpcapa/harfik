// Kelimeki core — Tile (src/game/types.ts portu).

/// Tek bir taş. TS tarafında opsiyonel alanlar (wild/wildLetter/owner) JSON'da
/// yalnızca doluyken görünür — `toJson` bu kanonik biçimi birebir üretir
/// (golden vector karşılaştırması buna dayanır, bkz. mobile/CLAUDE.md).
class Tile {
  /// Raftaki/torbadaki ham harf ('?' joker olabilir).
  final String letter;
  final int pts;

  /// Joker mi?
  final bool wild;

  /// Joker oynandığında seçilen harf.
  final String? wildLetter;

  /// Tahtaya konduğunda sahibi (oyuncu indeksi).
  final int? owner;

  const Tile({
    required this.letter,
    required this.pts,
    this.wild = false,
    this.wildLetter,
    this.owner,
  });

  static const Object _unset = Object();

  Tile copyWith({
    String? letter,
    int? pts,
    bool? wild,
    Object? wildLetter = _unset,
    Object? owner = _unset,
  }) =>
      Tile(
        letter: letter ?? this.letter,
        pts: pts ?? this.pts,
        wild: wild ?? this.wild,
        wildLetter:
            identical(wildLetter, _unset) ? this.wildLetter : wildLetter as String?,
        owner: identical(owner, _unset) ? this.owner : owner as int?,
      );

  Map<String, Object?> toJson() => {
        'letter': letter,
        'pts': pts,
        if (wild) 'wild': true,
        if (wildLetter != null) 'wildLetter': wildLetter,
        if (owner != null) 'owner': owner,
      };

  factory Tile.fromJson(Map<String, Object?> j) => Tile(
        letter: j['letter'] as String,
        pts: j['pts'] as int,
        wild: j['wild'] == true,
        wildLetter: j['wildLetter'] as String?,
        owner: j['owner'] as int?,
      );
}
