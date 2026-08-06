// Kelimeki core — bitmiş bir oyunun tahtasının kompakt anlık görüntüsü
// (`games.board_snapshot`), src/utils/boardSnapshot.ts portu.
//
// Yalnızca DOLU hücreler yazılır; bonus/köşe düzeni sabitlerden türetildiği
// için saklanmaz. Alan adları web ile birebir (`r`,`c`,`l`,`o`, joker ise
// `w:true`) — aynı satırı web istemcisi de okuyor, biçim SÖZLEŞME.
//
// Kanonik codec ile aynı disiplin: opsiyonel alan yalnızca doluyken yazılır
// (`w` yalnız joker taşta).
import '../model/game_state.dart' show Board;
import '../model/tile.dart';

/// Tek bir dolu hücrenin kompakt gösterimi.
class BoardSnapshotTile {
  final int r;
  final int c;

  /// Görünen harf — joker taşta seçilen harf (`wildLetter`), aksi halde
  /// taşın kendi harfi.
  final String l;

  /// Taşı koyan oyuncunun koltuk indeksi (web `owner ?? 0`).
  final int o;

  /// Yalnızca joker taşlarda true (web'de alan hiç yazılmaz).
  final bool w;

  const BoardSnapshotTile({
    required this.r,
    required this.c,
    required this.l,
    required this.o,
    this.w = false,
  });

  Map<String, Object?> toJson() => {
        'r': r,
        'c': c,
        'l': l,
        'o': o,
        if (w) 'w': true,
      };

  factory BoardSnapshotTile.fromJson(Map<String, Object?> j) =>
      BoardSnapshotTile(
        r: j['r'] as int,
        c: j['c'] as int,
        l: j['l'] as String,
        o: j['o'] as int,
        w: j['w'] == true,
      );
}

/// Tahtanın dolu hücrelerini satır-satır (r artan, içinde c artan) tarar —
/// sıra web'in çift döngüsüyle birebir aynıdır (JSON dizisinin sırası da
/// sözleşmenin parçası: web bu diziyi olduğu gibi render ediyor).
List<BoardSnapshotTile> serializeBoardSnapshot(Board board) {
  final tiles = <BoardSnapshotTile>[];
  for (var r = 0; r < board.length; r++) {
    for (var c = 0; c < board[r].length; c++) {
      final Tile? tile = board[r][c];
      if (tile == null) continue;
      final wild = tile.wild;
      tiles.add(BoardSnapshotTile(
        r: r,
        c: c,
        l: wild ? (tile.wildLetter ?? tile.letter) : tile.letter,
        o: tile.owner ?? 0,
        w: wild,
      ));
    }
  }
  return tiles;
}
