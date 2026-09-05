// Kelimeki — `subscribeMyOnlineGames` PAYLAŞILAN kanal değişmezi.
//
// NEDEN VAR (5 Eylül 2026, incelemenin 3. geçişi — performans): bu
// fonksiyonun üç çağıranı var (`Setup`, `LiveGamesTab`, `useAppIconBadge`)
// ve üçü aynı anda canlı olabiliyor. Öncesinde her çağrı kendi kanalını
// açıyordu, yani tek kullanıcı için 3 kanal × 3 tablo = 9 Realtime
// aboneliği. Sunucuda WAL'daki her satır değişikliği HER abonelik için
// ayrı ayrı RLS'ten geçiyor (`realtime.apply_rls`) ve o tek başına
// veritabanı yürütme süresinin %75,8'iydi (`pg_stat_statements`, 69 günlük
// pencere: 3,38 M çağrı / 18.327 s).
//
// Kanal paylaşımı DERLEYİCİNİN GÖREMEYECEĞİ bir şey: dördüncü bir çağıran
// eklenince ya da referans sayımı yanlış kurulunca hiçbir test düşmez —
// uygulama çalışmaya devam eder, yalnızca sunucu maliyeti sessizce üçe
// katlanır. Duman testi de göremez: bu kod yolu oturum açmış bir kullanıcı
// istiyor, dev sunucusunda Supabase yapılandırılmamış.
//
// Ölçülen ÜRETİM `subscribeMyOnlineGames`inin kendisi; yalnızca Supabase
// istemcisi sahte (`scripts/support/fake-supabase.ts`).
import { subscribeMyOnlineGames } from '../src/lib/api';
import {
  __allChannels,
  __emit,
  __emitSubscribed,
  __liveChannels,
  __resetChannels,
} from './support/fake-supabase';

let failed = false;

function check(label: string, actual: unknown, expected: unknown): void {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok) failed = true;
  console.log(`${ok ? '✓' : '✗'} ${label} — beklenen ${JSON.stringify(expected)}, gelen ${JSON.stringify(actual)}`);
}

// ── 1. Üç dinleyici → TEK kanal ───────────────────────────────────────────
__resetChannels();
let a = 0;
let b = 0;
let c = 0;
const offA = subscribeMyOnlineGames(() => { a += 1; });
const offB = subscribeMyOnlineGames(() => { b += 1; });
const offC = subscribeMyOnlineGames(() => { c += 1; });

check('üç dinleyici tek kanal açar', __allChannels().length, 1);
check('kanal üç tabloya bağlanır', __liveChannels()[0].bindings.map((x) => x.table), [
  'online_games',
  'game_invites',
  'online_game_states',
]);

// ── 2. Tek olay → HER dinleyici bir kez ───────────────────────────────────
__emit('online_game_states');
check('bir hamle olayı üç dinleyiciye de gider', [a, b, c], [1, 1, 1]);

__emit('game_invites');
check('davet olayı da üçüne birden gider', [a, b, c], [2, 2, 2]);

// ── 3. Bir dinleyici çıkarsa kanal AYAKTA kalır, ötekiler çalışır ─────────
offB();
check('bir dinleyici çıkınca kanal kapanmaz', __liveChannels().length, 1);
__emit('online_games');
check('çıkan dinleyici artık çağrılmaz, ötekiler çağrılır', [a, b, c], [3, 2, 3]);

// ── 4. onResubscribe: İLK bağlanma sinyal DEĞİL, sonrakiler sinyal ────────
//
// İlk `SUBSCRIBED` mount'taki ilk yüklemenin hemen ardından gelir; onu
// "tazele" saymak aynı isteği ikinci kez attırırdı (21 Ağustos 2026 kaydı).
__resetChannels();
offA();
offC();
check('son dinleyici de çıkınca kanal kaldırılır', __liveChannels().length, 0);

let resubA = 0;
let resubB = 0;
const off1 = subscribeMyOnlineGames(() => {}, () => { resubA += 1; });
check('ilk SUBSCRIBED tazeleme sinyali DEĞİL', resubA, 0);

// Kanal zaten bağlıyken katılan ikinci dinleyici de sinyal almamalı —
// o da kendi ilk yüklemesini mount'ta zaten yaptı.
const off2 = subscribeMyOnlineGames(() => {}, () => { resubB += 1; });
check('sonradan katılan dinleyici de sinyal almaz', [resubA, resubB], [0, 0]);

// Soket gerçekten kopup döndü: O ANDAKİ tüm dinleyiciler haber almalı.
__emitSubscribed();
check('yeniden bağlanmada TÜM dinleyiciler haber alır', [resubA, resubB], [1, 1]);

// ── 5. Kanal kapanıp yeniden açılırsa sayaç sıfırlanır ────────────────────
off1();
off2();
check('kanal kapandı', __liveChannels().length, 0);
let resubC = 0;
const off3 = subscribeMyOnlineGames(() => {}, () => { resubC += 1; });
check('yeni kanalın ilk SUBSCRIBED\'ı yine sinyal değil', resubC, 0);
off3();

if (failed) {
  console.error('\n✗ Paylaşılan Realtime kanalı değişmezi KIRILDI.');
  process.exit(1);
}
console.log('\n✓ Paylaşılan Realtime kanalı: çok dinleyici → tek abonelik.');
