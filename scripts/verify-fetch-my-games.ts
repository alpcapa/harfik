// Kelimeki — `fetchMyGames`in "ağ hatası mı, boş liste mi" ayrımını ÜRETİM
// kodunu import ederek doğrular.
//
// NEDEN AYRI BİR BETİK: web tarafında birim test çatısı yok (`npm run test`
// Playwright duman testleri). `verify-cloud-save-mirror` ile AYNI desen —
// esbuild ile bundle'layıp node'da koşuyoruz, yeni bağımlılık yok.
//
// NEDEN VAR (14 Ağustos 2026, cihaz testinde bulundu): `failed` bayrağı ilk
// sürümde İŞE YARAMIYORDU ve bunu yalnızca gerçek bir çevrimdışı denemesi
// gösterdi. `fetchMyGames` görüntüleyeni `supabase.auth.getUser()` ile
// çözüyordu; o her çağrıda `GET /auth/v1/user`'a gidiyor, yani ÇEVRİMDIŞIYKEN
// `viewer` null dönüyor. `ScoreCard` `userId` prop'u geçmediğinden `targetUid`
// undefined kalıyor ve akış "oturum yok, bu bir hata değil" erken dönüşüne
// düşüp `failed: false` diyordu — yani düzeltmenin kendisi atlanıyordu.
// `getSession()`e (yerel depo, ağ yok) geçilerek kapatıldı.
//
// Bu betik `verify-cloud-save-mirror`dan bir yönüyle AYRILIYOR: oradaki
// fonksiyonlar saf, buradaki değil. Bu yüzden `supabase` modülü esbuild
// takma adıyla (`--alias`) sahte bir istemciyle değiştiriliyor; ölçülen şey
// yine ÜRETİM `fetchMyGames`inin kendisi.
//
// Koşum: npm run verify-fetch-my-games
import { fetchMyGames } from '../src/lib/api';
import { __setFake, type FakeSpec } from './support/fake-supabase';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const NET_ERR = { message: 'TypeError: Failed to fetch' };
const ROW = {
  id: 'g1',
  created_at: '2026-08-14T10:00:00Z',
  player_count: 2,
  players: null,
  player_score: 100,
  ai_score: 90,
  rank: 1,
  surrendered: false,
  online_game_id: null,
  user_id: 'u1',
};

async function scenario(
  name: string,
  spec: FakeSpec,
  expectFailed: boolean,
  expectGames: number,
  favoritesOnly = false,
) {
  __setFake(spec);
  const res = await fetchMyGames(null, 0, 20, undefined, favoritesOnly);
  check(
    `${name} → failed=${expectFailed}`,
    res.failed === expectFailed,
    `beklenen failed=${expectFailed}, gelen ${res.failed}`,
  );
  check(
    `${name} → ${expectGames} oyun`,
    res.games.length === expectGames,
    `beklenen ${expectGames}, gelen ${res.games.length}`,
  );
}

async function main() {
  console.log('fetchMyGames — ağ hatası ↔ boş liste ayrımı\n');

  // ── Asıl vaka: cihaz testinde kullanıcının gördüğü hata ────────────────
  // Çevrimdışı + geçerli oturum. `getSession()` yerelden okuduğu için uid
  // ÇÖZÜLÜR, sorgu düşer → failed. Eski kod burada `getUser()` ağ isteğine
  // gidip null dönüyor, uid çözülemiyor ve "hiç oyunun yok" gösteriliyordu.
  await scenario(
    'çevrimdışı + geçerli oturum',
    { offline: true, session: { user: { id: 'u1' } } },
    true,
    0,
  );

  // Favoriler AYRI bir kod yolu (`list_liked_games` RPC'si) — kullanıcının
  // adım listesinde ayrıca kontrol edilmesinin sebebi bu.
  await scenario(
    'çevrimdışı + Favoriler sekmesi (rpc yolu)',
    { offline: true, session: { user: { id: 'u1' } } },
    true,
    0,
    true, // favoritesOnly — AYRI kod yolu, varsayılan çağrı buraya hiç girmez
  );

  // ── Negatif eş: bunlar failed ÜRETMEMELİ ──────────────────────────────
  await scenario(
    'çevrimiçi + gerçekten hiç oyun yok',
    { session: { user: { id: 'u1' } }, rows: [] },
    false,
    0,
  );
  await scenario(
    'çevrimiçi + oyun var',
    { session: { user: { id: 'u1' } }, rows: [ROW] },
    false,
    1,
  );
  // Misafir: `getSession()` HATASIZ `session: null` döner — gerçekten
  // oturum yok, bu bir hata değil.
  await scenario('misafir (oturum yok, hata yok)', { session: null }, false, 0);
  // Supabase hiç yapılandırılmamış (offline mod) — yine hata değil.
  await scenario('supabase yapılandırılmamış', { noClient: true }, false, 0);

  // ── Uç durum: süresi geçmiş token çevrimdışı tazelenemiyor ────────────
  // `getSession()` bu durumda HATA döner; uid çözülemese de bu gerçek bir
  // başarısızlık, "misafir" değil.
  await scenario(
    'çevrimdışı + tazelenemeyen token',
    { offline: true, session: null, sessionError: NET_ERR },
    true,
    0,
  );

  // ── Rozet RPC'sinin hatası listeyi DÜŞÜRMEMELİ ────────────────────────
  // Liste zaten elde; kartlar yalnızca rozetsiz çizilir (mobil portun aynı
  // kararı). Bunu `failed`a çevirmek, gerçekten gelmiş bir listeyi "yüklenemedi"
  // diye gizlerdi.
  await scenario(
    'liste geldi ama game_like_stats düştü',
    { session: { user: { id: 'u1' } }, rows: [ROW], rpcError: { game_like_stats: NET_ERR } },
    false,
    1,
  );

  console.log(failures === 0 ? '\nTümü geçti.' : `\n${failures} kontrol BAŞARISIZ.`);
  process.exit(failures === 0 ? 0 : 1);
}

void main();
