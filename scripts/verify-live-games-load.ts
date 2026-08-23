// Kelimeki — Canlı oyun listesinin "geçici ağ hatası ↔ gerçekten boş" ayrımını
// ve sessiz yeniden denemeyi ÜRETİM kodunu import ederek doğrular.
//
// NEDEN AYRI BİR BETİK: web tarafında birim test çatısı yok (`npm run test`
// Playwright duman testleri) ve bu kod yolu OTURUM AÇMIŞ bir kullanıcı ister —
// dev sunucusunda Supabase yapılandırılmadığından `LiveGamesTab` tarayıcıda
// "giriş yapmalısın" dalına düşüyor, yani duman testiyle ulaşılamıyor.
// `verify-fetch-my-games` ile BİREBİR aynı desen: `src/lib/supabase` esbuild
// takma adıyla sahteyle değiştiriliyor, ölçülen şey yine üretim fonksiyonları.
//
// NEDEN VAR (21 Ağustos 2026, gerçek vaka): Bir kullanıcı sırası KENDİSİNDEYKEN
// uygulamayı açtı ve "Devam eden bir Canlı oyunun yok." gördü; oyun ancak
// dakikalar sonra belirdi. Sunucu logları tertemizdi (16 istek, 16'sı 200 ve
// hepsi oyunu içeriyordu) — yani düşen istek sunucuya HİÇ ULAŞMAMIŞTI:
// telefon oturum ortasında ağ değiştirmişti (WiFi ↔ hücresel) ve geçiş
// uçuştaki fetch'i iptal etmişti. `listMyOnlineGames` o hatayı yutup `[]`
// döndüğünden ekran "hiç oyunun yok" diyordu, üstelik bir daha denemiyordu.
//
// Koşum: npm run verify-live-games-load
import { fetchOnlineGameTurns, listMyOnlineGames } from '../src/lib/api';
import {
  decideInitialMainView,
  fetchPendingLiveGameCounts,
} from '../src/utils/pendingLiveGames';
import { __netCalls, __setFake, type FakeSpec } from './support/fake-supabase';
import {
  __resetErrorReportingForTests,
  __setClientErrorSinkForTests,
} from '../src/utils/errorReporting';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

/** Sıradaki koltuk 1 ve o "ben"im → sıra bende. */
const GAME = {
  id: 'g1',
  status: 'active',
  player_count: 2,
  created_at: '2026-08-21T08:00:00Z',
  created_by: 'u2',
  my_role: 'invitee',
  my_invite_status: 'accepted',
  my_invite_id: null,
  slots: [
    { type: 'human', user_id: 'u2', relation: 'accepted' },
    { type: 'human', user_id: 'u1', relation: 'self' },
  ],
};
const STATE_ROW = { online_game_id: 'g1', current: 1, turn_deadline: '2026-08-23T08:00:00Z' };

/** Oyunu döndüren, sıra bilgisi de dolu "sağlıklı sunucu". */
function healthy(extra: Partial<FakeSpec> = {}): FakeSpec {
  return { rpcData: { list_my_online_games: [GAME] }, rows: [STATE_ROW], ...extra };
}

async function main() {
  console.log('Canlı oyun listesi — geçici ağ hatası ↔ boş liste, ve yeniden deneme\n');

  // ── 1) Hatanın kendisi: ağ düşmesi "oyunun yok" DEĞİL "bilmiyorum" olmalı
  __setFake({ offline: true });
  check('ağ hatası → null (boş dizi DEĞİL)', (await listMyOnlineGames()) === null);
  check(
    'ağ hatası → 1 deneme + 2 yeniden deneme = 3 çağrı',
    __netCalls() === 3,
    `çağrı sayısı ${__netCalls()}`,
  );

  // ── 2) Sunucu gerçekten boş dediyse bu bir hata DEĞİL — ve tekrar denenmez
  __setFake({ rpcData: { list_my_online_games: [] } });
  const bos = await listMyOnlineGames();
  check('sunucu boş dedi → [] (null değil)', Array.isArray(bos) && bos.length === 0);
  check('boş liste yeniden DENENMEZ (tek çağrı)', __netCalls() === 1, `${__netCalls()} çağrı`);

  // ── 3) ASIL VAKA: ilk deneme düşer, ikincisi tutar → kullanıcı hiçbir şey
  //      görmez. Düzeltmeden önce bu senaryo "hiç oyunun yok" veriyordu.
  __setFake(healthy({ failCalls: [1] }));
  const kurtarilan = await listMyOnlineGames();
  check(
    'ilk deneme düşer, ikincisi tutar → oyun GELİR',
    Array.isArray(kurtarilan) && kurtarilan.length === 1,
    `gelen ${JSON.stringify(kurtarilan)}`,
  );
  check('kurtarma tam 2 çağrı sürer', __netCalls() === 2, `${__netCalls()} çağrı`);

  // ── 4) İki deneme de düşse üçüncü kurtarır (merdivenin son basamağı)
  __setFake(healthy({ failCalls: [1, 2] }));
  const kurtarilan2 = await listMyOnlineGames();
  check(
    'iki deneme düşer, üçüncüsü tutar → oyun GELİR',
    Array.isArray(kurtarilan2) && kurtarilan2.length === 1,
  );

  // ── 5) Sunucunun KENDİ reddi asla tekrarlanmaz — o bir karar, hata değil
  __setFake({ rpcError: { list_my_online_games: { message: 'permission denied for table' } } });
  check('sunucu reddi → null', (await listMyOnlineGames()) === null);
  check('sunucu reddi YENİDEN DENENMEZ (tek çağrı)', __netCalls() === 1, `${__netCalls()} çağrı`);

  // ── 6) Yapılandırılmamış istemci bir hata DEĞİL (misafir/offline hâli)
  __setFake({ noClient: true });
  const yapilandirilmamis = await listMyOnlineGames();
  check(
    'supabase yapılandırılmamış → [] (null değil)',
    Array.isArray(yapilandirilmamis) && yapilandirilmamis.length === 0,
  );

  // ── 7) "Sıra kimde" — boş harita, "sıra rakipte" YALANINI üretiyordu
  __setFake({ offline: true });
  check('turns ağ hatası → null (boş harita değil)', (await fetchOnlineGameTurns(['g1'])) === null);

  // ── 8) Teşhisin dayandığı değişmez: boş id listesinde HİÇ istek atılmaz.
  //      Sunucu loglarında `list_my_online_games`in ardından gelen
  //      `online_game_states?...in.(<id>)` isteği tam bu yüzden "liste doluydu"
  //      kanıtı sayıldı — bu değişmez kırılırsa o çıkarım da geçersiz olur.
  __setFake(healthy());
  const bosId = await fetchOnlineGameTurns([]);
  check('boş id listesi → {} ve HİÇ ağ çağrısı yok', __netCalls() === 0 && !!bosId);

  // ── 9) Rozet/giriş kararı: sayılar bilinmiyorsa `0` DEĞİL `null` dönmeli.
  //      `0` dönmek rozeti silmenin yanında `applyLoginDefaultOnce`ı da
  //      tüketiyordu — tek bir düşen istek "girişte Canlı sekmesini aç"
  //      kararını o oturum için kalıcı olarak yakıyordu.
  __setFake({ offline: true });
  check('sayılar: liste düşerse null', (await fetchPendingLiveGameCounts()) === null);

  // Liste gelir ama sıra sorgusu düşer (2. çağrı ve onun iki denemesi).
  __setFake(healthy({ failCalls: [2, 3, 4] }));
  check('sayılar: sıra sorgusu düşerse null', (await fetchPendingLiveGameCounts()) === null);

  __setFake(healthy());
  const sayilar = await fetchPendingLiveGameCounts();
  check(
    'sağlıklı sunucu → sıra bende sayılır (myTurnCount=1)',
    sayilar !== null && sayilar.myTurnCount === 1 && sayilar.inviteCount === 0,
    `gelen ${JSON.stringify(sayilar)}`,
  );

  // ── 10) Giriş varsayılanı: HANGİ sekmeyle karşılanıyoruz?
  //      Kullanıcı 21 Ağustos 2026'da bildirdi: hesabında 0 YZ oyunu ve 6
  //      aktif Canlı oyun varken (hiçbirinde sıra kendisinde değil) uygulama
  //      her açılışta BOŞ "Yapay Zeka ile" sekmesiyle karşılıyordu.
  const say = (
    inviteCount: number,
    myTurnCount: number,
    activeCount: number,
  ) => ({ inviteCount, myTurnCount, activeCount });

  check(
    'karar: sıra bendeyse → live',
    decideInitialMainView(say(0, 1, 3), []) === 'live',
  );
  check(
    'karar: bekleyen davet → live (YZ oyunu OLSA bile)',
    decideInitialMainView(say(1, 0, 0), [{}, {}]) === 'live',
  );
  check(
    'karar: YZ boş + Canlı oyun var → live (sıra bende OLMASA bile)',
    decideInitialMainView(say(0, 0, 6), []) === 'live',
    'kullanıcının bildirdiği vaka',
  );
  check(
    'karar: YZ oyunu VAR + Canlı sakin → local (sekme kaçırılmaz)',
    decideInitialMainView(say(0, 0, 6), [{}]) === 'local',
  );
  check(
    'karar: her ikisi de boş → local',
    decideInitialMainView(say(0, 0, 0), []) === 'local',
  );
  // Üçüncü durum: eksik veriyle KARAR VERİLMEZ. `local` dönmek tek seferlik
  // kararı yakıp kullanıcıyı kalıcı olarak yanlış sekmede bırakırdı.
  check(
    'karar: Canlı sayıları bilinmiyorsa null (karar ertelenir)',
    decideInitialMainView(null, []) === null,
  );
  // ⚠ Kural (1) YZ listesini BEKLEMEZ. Beklemek gerçek bir regresyon
  // üretti (21 Ağustos 2026, CI iki mevcut port testiyle yakaladı): YZ
  // listesi hiç yüklenmeyen bir hesapta kullanıcı bekleyen işine rağmen
  // YZ sekmesinde kalıyordu.
  check(
    'karar: bekleyen iş varsa YZ listesi BİLİNMESE de live',
    decideInitialMainView(say(0, 1, 3), null) === 'live',
  );
  check(
    'karar: bekleyen davet varsa YZ listesi BİLİNMESE de live',
    decideInitialMainView(say(2, 0, 0), null) === 'live',
  );
  check(
    'karar: YZ listesi henüz çekilmediyse null (karar ertelenir)',
    decideInitialMainView(say(0, 0, 6), null) === null,
    'bayat/eksik veriyle tüketilen tek-seferlik karar hatası',
  );

  // ── Oturum düşmüşken gelen "permission denied" TELEMETRİYE DÜŞMEZ
  //
  // 23 Ağustos 2026, panelin ilk gerçek verisi: `[list_my_online_games]
  // permission denied for function list_my_online_games`. Grant DOĞRU
  // (`authenticated`'e verili), yani rol `anon` kalmış — oturum düşmüş.
  // Bu beklenen bir durum, bug değil. AMA aynı mesaj gerçek bir grant
  // hatasının da yüzü; ayıran tek şey OTURUMUN VARLIĞI.
  const raporlar: Record<string, unknown>[] = [];
  const raporlariIzle = () => {
    raporlar.length = 0;
    __resetErrorReportingForTests();
    __setClientErrorSinkForTests(async (r) => {
      raporlar.push(r);
    });
  };
  /** Rapor fire-and-forget + `getSession()` async — mikrogörevleri bekle. */
  const bekle = () => new Promise((r) => setTimeout(r, 0));
  const yetkiHatasi = {
    list_my_online_games: {
      code: '42501',
      message: 'permission denied for function list_my_online_games',
    },
  };

  {
    raporlariIzle();
    __setFake({ rpcError: yetkiHatasi, session: null });
    check('oturumsuz yetki hatası → null (davranış değişmedi)', (await listMyOnlineGames()) === null);
    await bekle();
    check('oturumsuz "permission denied" RAPORLANMAZ', raporlar.length === 0, `rapor=${raporlar.length}`);
  }
  {
    raporlariIzle();
    __setFake({ rpcError: yetkiHatasi, session: { user: { id: 'u1' } } });
    await listMyOnlineGames();
    await bekle();
    check(
      'oturum VARKEN "permission denied" RAPORLANIR (grant hatası gizlenmez)',
      raporlar.length === 1,
      `rapor=${raporlar.length}`,
    );
  }
  {
    raporlariIzle();
    __setFake({
      rpcError: { list_my_online_games: { code: 'P0001', message: 'beklenmedik sunucu hatası' } },
      session: null,
    });
    await listMyOnlineGames();
    await bekle();
    check(
      'yetkiyle İLGİSİZ hata oturumsuz da RAPORLANIR',
      raporlar.length === 1,
      `rapor=${raporlar.length}`,
    );
  }
  __setClientErrorSinkForTests(null);

  console.log(failures === 0 ? '\nTümü geçti.' : `\n${failures} kontrol düştü.`);
  process.exit(failures === 0 ? 0 : 1);
}

void main();
