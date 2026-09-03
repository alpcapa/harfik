// Kelimeki — `src/utils/recentGameAvatars.ts`in saf kuralını ÜRETİM kodunu
// import ederek doğrular ("Son Oynananlar" listesindeki avatar çözümü).
//
// NEDEN AYRI BİR BETİK: web tarafında birim test çatısı yok (`npm run test`
// Playwright duman testleri). `verify-draft-rescue` ile AYNI desen.
//
// NEDEN ÖNEMLİ: burada yanlış yapmanın bedeli "avatar çıkmaz" değil,
// **BAŞKASININ YÜZÜNÜ GÖSTERMEK**. Takma adlar değiştirilebiliyor
// (`AccountSettingsModal`), yani isimle GLOBAL bir arama, adı sonradan
// devralan başka bir kullanıcıyı eşleştirebilirdi. Kural bu yüzden eşlemeyi
// OYUNUN KENDİ koltuklarıyla sınırlıyor ve aşağıdaki testler tam olarak o
// sınırın durduğunu kanıtlıyor.
//
// Flutter portundaki eşi `util/recent_game_avatars.dart`, vakaları
// `recent_game_avatars_test.dart`.
//
// Koşum: npm run verify-recent-game-avatars
import {
  buildOnlineAvatarIndex,
  avatarForRecentPlayer,
} from '../src/utils/recentGameAvatars';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const index = buildOnlineAvatarIndex([
  {
    id: 'g1',
    slots: [
      { name: 'Ironman', avatarUrl: 'https://x/ironman.png' },
      { name: 'Bobola', avatarUrl: null }, // fotoğrafı yok → baş harf
      { name: null, avatarUrl: null }, // YZ koltuğu
    ],
  },
  { id: 'g2', slots: [{ name: 'Esiner', avatarUrl: 'https://x/esiner.png' }] },
]);

const oyunda = (
  name: string,
  onlineGameId: string | null,
  own: string | null = null,
) =>
  avatarForRecentPlayer({
    isAi: false,
    isGuest: false,
    name,
    onlineGameId,
    onlineIndex: index,
    ownAvatarUrl: own,
  });

console.log('Çevrimiçi oyun — kendi koltuklarından eşleme');
check('oyundaki oyuncunun avatarı gelir', oyunda('Ironman', 'g1') === 'https://x/ironman.png');
check('fotoğrafı olmayan oyuncu null (baş harfe düşer)', oyunda('Bobola', 'g1') === null);
check(
  'BAŞKA oyundaki aynı isim BU oyuna sızmaz',
  oyunda('Esiner', 'g1') === null,
  'eşleme oyunla sınırlı olmalı — global isim araması YANLIŞ YÜZ gösterirdi',
);
check('bilinmeyen oyun id → null', oyunda('Ironman', 'yok') === null);
check(
  'oyundan sonra adını değiştiren oyuncu → null (zarif geri düşüş)',
  oyunda('IronmanYeni', 'g1') === null,
);

console.log('Yerel (YZ) oyun — ada BAKMADAN hesabın kendi avatarı');
check(
  'yerel kayıtta hesabın avatarı verilir',
  oyunda('HerhangiBirAd', null, 'https://x/ben.png') === 'https://x/ben.png',
  'yerel oyunda tek insan koltuk satırın sahibidir; ad donmuş olabilir',
);
check('hesabın avatarı yoksa null', oyunda('X', null, null) === null);

console.log('YZ ve misafir koltukları HER ZAMAN null');
for (const [ad, isAi, isGuest] of [
  ['Yapay Zeka 2', true, false],
  ['Misafir', false, true],
] as const) {
  check(
    `${ad} → null`,
    avatarForRecentPlayer({
      isAi,
      isGuest,
      name: ad,
      onlineGameId: null,
      onlineIndex: index,
      ownAvatarUrl: 'https://x/ben.png',
    }) === null,
    'kendi avatarı SIZMAMALI',
  );
}

console.log('Sözlük kurulumu');
check('yalnızca adı VE avatarı olan koltuklar girer', index.get('g1')?.size === 1);
check('hiç avatarı olmayan oyun sözlüğe hiç girmez', !buildOnlineAvatarIndex([
  { id: 'g3', slots: [{ name: 'Kimse', avatarUrl: null }] },
]).has('g3'));

console.log(failures === 0 ? '\nTÜMÜ GEÇTİ' : `\n${failures} KONTROL DÜŞTÜ`);
process.exit(failures === 0 ? 0 : 1);
