// Kelimeki core — tahta sabitleri (src/game/constants.ts portu).
// Oyuncu RENKLERİNİN kendisi (PLAYER_COLORS hex değerleri) bilinçli olarak
// core'da DEĞİL — UI katmanına ait; motor yalnızca `colorIndex` üretir.
import 'model/types.dart';

/// Tahta 13x13. (TS: SIZE)
const int boardSize = 13;

/// Köşe bölgelerinin kenar uzunluğu (4x4). (TS: CORNER)
const int cornerSize = 4;

/// Tüm oyuncular üst üste bu kadar tur pas geçtiğinde oyun biter.
/// (TS: MAX_PASS_ROUNDS)
const int maxPassRounds = 2;

/// Tüm rafı kullanan hamleye verilen bonus puan. (TS: BINGO_BONUS)
const int bingoBonus = 25;

/// Rafta tutulan taş sayısı. (TS: RACK_SIZE)
const int rackSize = 7;

/// Renk paleti uzunluğu (TS: PLAYER_COLORS.length) — startGame'deki
/// `colorIndex: i % PLAYER_COLORS.length` hesabının core'daki karşılığı.
const int playerColorCount = 4;

/// Misafir oyuncu adı. (TS: GUEST_PLAYER_NAME — yazan/okuyan senkron sabiti)
const String guestPlayerName = 'Misafir';

/// Oyunu bitiren tamamı-joker hamlenin bonusu: 1 joker +25, 2 joker +50.
int jokerFinishBonus(int jokerCount) {
  if (jokerCount >= 2) return 50;
  if (jokerCount == 1) return 25;
  return 0;
}

typedef CornerBoundsRec = ({int r0, int r1, int c0, int c1});

/// Köşe indeksinin satır/sütun aralığı. 0=sol-üst, 1=sağ-üst, 2=sol-alt,
/// 3=sağ-alt.
CornerBoundsRec cornerBounds(int corner) {
  final top = corner == 0 || corner == 1;
  final left = corner == 0 || corner == 2;
  return (
    r0: top ? 0 : boardSize - cornerSize,
    r1: top ? cornerSize - 1 : boardSize - 1,
    c0: left ? 0 : boardSize - cornerSize,
    c1: left ? cornerSize - 1 : boardSize - 1,
  );
}

/// Bir köşe bölgesinin en uç (tek) hücresi — ilk hamlenin değmesi zorunlu
/// başlangıç noktası.
Cell cornerCell(int corner) {
  final b = cornerBounds(corner);
  final top = corner == 0 || corner == 1;
  final left = corner == 0 || corner == 2;
  return (top ? b.r0 : b.r1, left ? b.c0 : b.c1);
}

/// Oyuncu sayısına göre köşe ataması: 2 oyuncuda [0]/[3], 4 oyuncuda
/// [0]/[1]/[2]/[3].
List<List<int>> cornersFor(int playerCount) => playerCount == 2
    ? [
        [0],
        [3],
      ]
    : [
        [0],
        [1],
        [2],
        [3],
      ];

/// Merkez x2 bonus bölgesi (5×5). (TS: BONUS_ZONE)
const int bonusZoneR0 = cornerSize;
const int bonusZoneR1 = boardSize - cornerSize - 1;
const int bonusZoneC0 = cornerSize;
const int bonusZoneC1 = boardSize - cornerSize - 1;

bool inBonusZone(int r, int c) =>
    r >= bonusZoneR0 && r <= bonusZoneR1 && c >= bonusZoneC0 && c <= bonusZoneC1;

/// Tahtanın tam merkezi — bonus bölgesinin tek X3 hücresi.
const Cell boardCenter = (boardSize ~/ 2, boardSize ~/ 2);

/// Başlangıç bonus yerleşimi: yalnızca merkez hücre X3 ('tw').
Map<String, BonusType> buildInitialBonuses() =>
    {'${boardCenter.$1},${boardCenter.$2}': BonusType.tw};
