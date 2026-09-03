// `util/recent_game_avatars.dart` — "Son Oynananlar" avatar çözümü.
//
// Vakalar web ikizinin doğrulama betiğiyle BİREBİR aynı
// (`scripts/verify-recent-game-avatars.ts`, `npm run verify-recent-game-avatars`);
// iki taraf aynı kuralı okumak zorunda, biri değişirse öteki de.
//
// NEDEN ÖNEMLİ: burada yanlış yapmanın bedeli "avatar çıkmaz" değil,
// BAŞKASININ YÜZÜNÜ göstermek. Takma adlar değiştirilebiliyor, yani isimle
// GLOBAL bir arama adı sonradan devralan başka bir kullanıcıyı eşleştirirdi.
// Kural eşlemeyi OYUNUN KENDİ koltuklarıyla sınırlıyor; aşağıdaki
// "başka oyundaki aynı isim sızmaz" iddiası tam olarak o sınırın negatif eşi.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/recent_game_avatars.dart';

void main() {
  final index = buildOnlineAvatarIndex([
    (
      id: 'g1',
      slots: const [
        AvatarSlot(name: 'Ironman', avatarUrl: 'https://x/ironman.png'),
        AvatarSlot(name: 'Bobola', avatarUrl: null), // fotoğrafı yok
        AvatarSlot(name: null, avatarUrl: null), // YZ koltuğu
      ],
    ),
    (
      id: 'g2',
      slots: const [
        AvatarSlot(name: 'Esiner', avatarUrl: 'https://x/esiner.png')
      ],
    ),
  ]);

  String? cozum(String name, String? onlineGameId, {String? own}) =>
      avatarForRecentPlayer(
        isAi: false,
        isGuest: false,
        name: name,
        onlineGameId: onlineGameId,
        onlineIndex: index,
        ownAvatarUrl: own,
      );

  group('çevrimiçi oyun — kendi koltuklarından eşleme', () {
    test('oyundaki oyuncunun avatarı gelir', () {
      expect(cozum('Ironman', 'g1'), 'https://x/ironman.png');
    });
    test('fotoğrafı olmayan oyuncu null (baş harfe düşer)', () {
      expect(cozum('Bobola', 'g1'), isNull);
    });
    test('BAŞKA oyundaki aynı isim BU oyuna SIZMAZ', () {
      expect(cozum('Esiner', 'g1'), isNull,
          reason: 'global isim araması yanlış yüz gösterirdi');
    });
    test('bilinmeyen oyun id → null', () {
      expect(cozum('Ironman', 'yok'), isNull);
    });
    test('oyundan sonra adını değiştiren oyuncu → null (zarif geri düşüş)', () {
      expect(cozum('IronmanYeni', 'g1'), isNull);
    });
  });

  group('yerel (YZ) oyun — ada BAKMADAN hesabın kendi avatarı', () {
    test('yerel kayıtta hesabın avatarı verilir', () {
      // Ad donmuş olabilir (kullanıcı sonradan değiştirmiş); yerel oyunda
      // tek insan koltuk HER ZAMAN satırın sahibi olduğundan ada bakılmıyor.
      expect(cozum('HerhangiBirAd', null, own: 'https://x/ben.png'),
          'https://x/ben.png');
    });
    test('hesabın avatarı yoksa null', () {
      expect(cozum('X', null), isNull);
    });
  });

  group('YZ ve misafir koltukları HER ZAMAN null', () {
    test('YZ koltuğuna kendi avatarım SIZMAZ', () {
      expect(
          avatarForRecentPlayer(
            isAi: true,
            isGuest: false,
            name: 'Yapay Zeka 2',
            onlineGameId: null,
            onlineIndex: index,
            ownAvatarUrl: 'https://x/ben.png',
          ),
          isNull);
    });
    test('misafir koltuğuna kendi avatarım SIZMAZ', () {
      expect(
          avatarForRecentPlayer(
            isAi: false,
            isGuest: true,
            name: 'Misafir',
            onlineGameId: null,
            onlineIndex: index,
            ownAvatarUrl: 'https://x/ben.png',
          ),
          isNull);
    });
  });

  group('sözlük kurulumu', () {
    test('yalnızca adı VE avatarı olan koltuklar girer', () {
      expect(index['g1']!.length, 1);
    });
    test('hiç avatarı olmayan oyun sözlüğe HİÇ girmez', () {
      final bos = buildOnlineAvatarIndex([
        (id: 'g3', slots: const [AvatarSlot(name: 'Kimse', avatarUrl: null)]),
      ]);
      expect(bos.containsKey('g3'), isFalse);
    });
  });
}
