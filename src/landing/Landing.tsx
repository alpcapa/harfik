// Kelimeki — karşılama (landing) katmanı.
//
// NEDEN VAR: uygulama tamamen istemci tarafında render ediliyor, yani ham
// HTML'de `<head>`'deki meta/title dışında gerçek bir metin YOK. 17 Ağustos
// 2026'da bunun somut bedeli ölçüldü — Google'ın AI Mode'u Kelimeki'yi
// "kelime bulucu ve sözlük platformu" diye tamamen uydurdu (organik sonuç ve
// AI Overview doğru anlatırken). Bu katman, ilk kez gelen ziyaretçiye
// gösterilen ve ham HTML'de GERÇEK metin taşıyan bir giriş sayfası.
//
// ⚠ BU BİLEŞEN SUNUCUDA (Node) RENDER EDİLİR — derleme/servis zamanında
// `renderToStaticMarkup` ile statik HTML'e çevrilip `index.html`'in gövdesine
// gömülür (bkz. `src/landing/render.tsx` ve `scripts/landing-plugin.js`).
// Dolayısıyla:
//   • tarayıcı globali (`window`/`document`/`localStorage`/`navigator`) YOK,
//   • hook (`useState`/`useEffect`) YOK,
//   • olay handler'ı YOK — butonların davranışı `main.tsx`'te bağlanıyor.
// Hedef: karşılama katmanı için 0 KB çalışma zamanı React/Supabase JS'i.
// (Ölçüldü: `@supabase/supabase-js` 54 KB + `react`+`react-dom/client` 45 KB
// gzip; bugünkü tam uygulama 410 KB. Ziyaretçi tanım gereği girişsiz
// olduğundan `UserMenu`'nün avatar/menü dalı hiç gerekmiyor.)
//
// ⚠ BUTON BAĞLAMA SÖZLEŞMESİ: sayfada birden fazla "Oyna"/"Giriş" düğmesi var.
// `main.tsx` bunları `[data-kelimeki-oyna]` / `[data-kelimeki-giris]`
// SEÇİCİSİYLE topluca bağlıyor — yeni bir düğme eklerken id değil BU
// ÖZNİTELİK verilmeli, aksi halde düğme sessizce ölü kalır. Başlıktaki iki
// düğme ayrıca id taşımaya devam ediyor (`tests/smoke.spec.ts` onları id ile
// buluyor).
import { LandingLogo, LandingLogoDefs } from './LandingLogo';
import { GameBoardPreview } from '../components/GameBoardPreview';
import { RankSeal } from '../components/RankSeal';
import { RANK_TIERS } from '../utils/leagueRank';
import { PLAYER_COLORS } from '../game/constants';
import { DEMO_TILES } from './demoBoard';

// `UserMenu.tsx:33-35`'ten BİREBİR kopyalandı — kodu import etmiyoruz
// (bu katman `UserMenu`'yü, dolayısıyla Supabase SDK'sını yüklememeli),
// yalnızca DEĞERLERİ. Başlık yüksekliğini bunlar belirliyor (390px'te
// 41.0 px, 375→465 arası akışkan); sabit piksele ÇEVİRME.
const GIRIS_FONT_SIZE = 'clamp(8px, calc(-4.5px + 3.33vw), 11px)';
const GIRIS_PADDING_X = 'clamp(6px, calc(-2.33px + 2.22vw), 8px)';
const GIRIS_PADDING_Y = 'clamp(8.7px, calc(-5.05px + 3.67vw), 12px)';

// İki buton da AYNI akışkan ölçüyü kullanıyor — aksi halde şeridin yüksekliği
// hangisinin daha uzun olduğuna göre değişir ve aşağıdaki "başlık altı → logo
// üstü = 0.00" değişmezi bozulur.
const BUTON_OLCU = {
  fontSize: GIRIS_FONT_SIZE,
  paddingLeft: GIRIS_PADDING_X,
  paddingRight: GIRIS_PADDING_X,
  paddingTop: GIRIS_PADDING_Y,
  paddingBottom: GIRIS_PADDING_Y,
};

const BUTON_TABAN =
  'shrink-0 font-mono uppercase tracking-[0.5px] rounded-md border font-bold leading-none active:scale-[0.97] transition-transform';

// Başlıktaki İKİ düğme de AYNI görünür — `UserMenu.tsx:145`'teki uygulama içi
// GİRİŞ düğmesi de accent/mavi olduğundan bu aynı zamanda katmanı uygulamayla
// hizalıyor. (18 Ağustos 2026: GİRİŞ bir süre nötr çizilmişti; kullanıcı
// "Oyna butonu giriş butonu ile aynı yükseklikte olmalı" diye bildirdi.
// ÖLÇÜLDÜ — kutular 360/390/834 genişliklerinde zaten BİREBİR aynıydı
// (27.38 / 28.98 / 37.00 px, ikisi de `top: 12`); gözle görünen fark
// `btn-raised`ın ağır gölgesi ile `btn-raised-neutral`ın hafif gölgesi
// arasındaydı. Yani düzeltilen şey yükseklik değil GÖLGE AĞIRLIĞIydı.)
const BASLIK_BUTON = `${BUTON_TABAN} btn-raised bg-accent border-accent text-white`;

// Park eden logonun yüksekliği — düğmelerin (27–37 px) belirgin şekilde
// altında kalmalı ki şeridin yüksekliğini DEĞİŞTİRMESİN (yükseklik
// düğmelerden gelmeye devam ediyor).
const PARK_LOGO_HEIGHT = 'clamp(13px, 3.6vw, 17px)';

// `src/data/words.ts` bugün 63.896 madde taşıyor; yuvarlanmış hâli hem burada
// hem SSS'te kullanılıyor. Liste büyürse İKİSİ de tek yerden değişsin diye
// sabit. (README'deki rakamla aynı disiplin — bkz. CLAUDE.md "Belgeleri
// Güncel Tutma".)
const KELIME_SAYISI = '63.000';

/* ────────────────────────────────────────────────────────────────────────── */

function Oyna({ etiket, id }: { etiket: string; id?: string }) {
  return (
    <button
      id={id}
      type="button"
      data-kelimeki-oyna=""
      className="w-full btn-raised bg-accent border border-accent text-white font-mono font-bold uppercase tracking-[1px] rounded-xl px-5 py-3.5 text-[13px] leading-none active:scale-[0.97] transition-transform"
    >
      {etiket}
    </button>
  );
}

function Giris({ etiket }: { etiket: string }) {
  return (
    <button
      type="button"
      data-kelimeki-giris=""
      className="w-full btn-raised-neutral bg-panel border border-border text-text font-mono font-bold uppercase tracking-[1px] rounded-xl px-5 py-3.5 text-[13px] leading-none active:scale-[0.97] transition-transform"
    >
      {etiket}
    </button>
  );
}

function Bolum({
  baslik,
  ustBaslik,
  id,
  children,
}: {
  baslik: string;
  ustBaslik?: string;
  id?: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className="w-full flex flex-col gap-3">
      <div className="flex flex-col gap-0.5">
        {ustBaslik ? (
          <span className="font-mono text-[9px] uppercase tracking-[1.5px] text-accent">
            {ustBaslik}
          </span>
        ) : null}
        <h2 className="text-[17px] font-bold leading-tight" style={{ margin: 0 }}>
          {baslik}
        </h2>
      </div>
      {children}
    </section>
  );
}

/**
 * Küçük şematik ızgara — "Nasıl oynanır" adımlarının yanındaki çizimler.
 * Renkler `PLAYER_COLORS`tan ve `Board.tsx`'in altın X2 zemininden OKUNUYOR,
 * kopyalanmıyor: paletin iki yerde sessizce ayrışması bu kod tabanının en sık
 * tekrarlayan hata sınıfı.
 *
 * Harf sözlüğü — her satır 5 karakter:
 *   `.` boş · `~` 1. oyuncunun bölgesi (taşsız) · `#` altın X2 zemini
 *   `*` merkezdeki X3 karesi · `A` 1. oyuncunun taşı · `B` 2. oyuncunun taşı
 */
function MiniIzgara({ satirlar }: { satirlar: string[] }) {
  const zemin: Record<string, string> = {
    '.': '#DDE4EE',
    '~': PLAYER_COLORS[0].zone,
    '#': '#FDE68A',
    '*': '#F97316',
    A: PLAYER_COLORS[0].base,
    B: PLAYER_COLORS[1].base,
  };
  return (
    <div
      aria-hidden="true"
      className="shrink-0 grid gap-[2px] p-[3px] rounded-lg bg-[#DDE4EE] shadow-raised"
      style={{ gridTemplateColumns: 'repeat(5, 10px)' }}
    >
      {satirlar.flatMap((satir, r) =>
        Array.from(satir).map((h, c) => (
          <span
            key={`${r}-${c}`}
            className="block w-[10px] h-[10px] rounded-[2px]"
            style={{ background: zemin[h] ?? zemin['.'] }}
          />
        )),
      )}
    </div>
  );
}

function Adim({
  no,
  baslik,
  metin,
  izgara,
}: {
  no: number;
  baslik: string;
  metin: string;
  izgara: string[];
}) {
  return (
    <li className="flex items-start gap-3 bg-panel border border-border rounded-xl p-3 shadow-raised">
      <MiniIzgara satirlar={izgara} />
      <div className="min-w-0 flex flex-col gap-1">
        <h3 className="text-[13px] font-bold leading-tight" style={{ margin: 0 }}>
          <span className="font-mono text-accent">{no}.</span> {baslik}
        </h3>
        <p className="text-[12px] leading-relaxed text-muted" style={{ margin: 0 }}>
          {metin}
        </p>
      </div>
    </li>
  );
}

function Ozellik({ baslik, metin }: { baslik: string; metin: string }) {
  return (
    <li className="bg-panel border border-border rounded-xl p-3 shadow-raised flex flex-col gap-1">
      <h3 className="text-[12px] font-bold leading-tight" style={{ margin: 0 }}>
        {baslik}
      </h3>
      <p className="text-[11px] leading-relaxed text-muted" style={{ margin: 0 }}>
        {metin}
      </p>
    </li>
  );
}

function Kutu({ sayi, etiket }: { sayi: string; etiket: string }) {
  return (
    <div className="flex-1 min-w-0 bg-panel border border-border rounded-xl px-1 py-2.5 shadow-raised text-center">
      <div className="font-mono text-[14px] font-bold leading-none text-accent">{sayi}</div>
      <div className="font-mono text-[8px] uppercase tracking-[0.5px] text-muted mt-1">
        {etiket}
      </div>
    </div>
  );
}

function Rozet({ renk, metin }: { renk: string; metin: string }) {
  return (
    <li className="flex items-center gap-2 text-[11px] leading-tight">
      <span
        aria-hidden="true"
        className="shrink-0 w-3.5 h-3.5 rounded-[3px] border border-border"
        style={{ background: renk }}
      />
      <span className="text-muted">{metin}</span>
    </li>
  );
}

function Soru({ soru, cevap }: { soru: string; cevap: string }) {
  // Native `<details>` — açılır/kapanır davranış için 0 bayt JS. Karşılama
  // katmanı statik HTML olduğundan uygulamadaki React state kalıbı burada
  // KULLANILAMAZ; tarayıcının kendi öğesi tam olarak bu iş için var.
  return (
    <details className="bg-panel border border-border rounded-xl px-3 py-2.5 shadow-raised">
      <summary className="text-[12px] font-bold leading-snug cursor-pointer marker:text-accent">
        {soru}
      </summary>
      <p className="text-[12px] leading-relaxed text-muted" style={{ margin: '8px 0 0' }}>
        {cevap}
      </p>
    </details>
  );
}

/* ────────────────────────────────────────────────────────────────────────── */

export function Landing() {
  return (
    // `#karsilama`nın kaydırma/flex kuralları `index.css`'te (`#root`'un
    // birebir karşılığı) — bkz. oradaki not: belge kaydırılmıyor, kaydırma
    // kabı olmadan `sticky` başlık da çalışmaz.
    <div id="karsilama">
      <LandingLogoDefs />
      <div className="min-h-[100dvh] w-full flex flex-col items-center">
        {/* ── Kilitli başlık (üç yuva) ─────────────────────────────────────
            Taban: `App.tsx`'in kurulum başlığı satırı (`w-full max-w-[460px]
            flex items-center justify-end px-3.5 pt-3`) — burada `justify-end`
            yerine üç yuva var ve şerit `sticky`. Kullanıcı isteği (18 Ağustos
            2026): "header'ı kilitle, sayfa altına girsin … kaydırdıkça
            içerikler aksın".

            Sticky sarmalayıcı TAM GENİŞLİK, iç şerit `max-w-[460px]` — ikisini
            tek elemanda birleştirmek şeridi ekranın soluna yapıştırırdı. */}
        <div id="karsilama-serit" className="sticky top-0 z-20 w-full flex justify-center bg-bg">
          <div className="w-full max-w-[460px] flex items-center gap-2 px-3.5 pt-3">
            <button
              id="karsilama-oyna"
              type="button"
              data-kelimeki-oyna=""
              className={BASLIK_BUTON}
              style={BUTON_OLCU}
            >
              Oyna
            </button>

            {/* ORTA YUVA — logonun "park ettiği" yer. Kullanıcı isteği (18
                Ağustos 2026): "Kelimeki logosu … kaybolduğu anda oyna ve
                giriş butonun arasına küçülmüş olarak yerleşsin."

                Logo BURADA HER ZAMAN VAR (statik HTML); yalnızca görünürlüğü
                CSS'te (`index.css` → `.logo-parkli`). `main.tsx`'teki
                `IntersectionObserver`, kahraman logo şeridin altına girdiği an
                sınıfı ekliyor. Sabit bir kaydırma eşiği ("120 px sonra")
                YANLIŞ olurdu: ölçüldü, şeridin ALTI ile kahraman logonun ÜSTÜ
                arası TAM 0.00 px ve şerit yüksekliği akışkan — eşik ekran
                genişliğine göre değişir. `rootMargin` da bu yüzden çalışma
                zamanında şeridin `offsetHeight`'inden okunuyor. */}
            <div
              id="karsilama-logo-yuvasi"
              className="flex-1 min-w-0 flex items-center justify-center"
              aria-hidden="true"
            >
              <LandingLogo height={PARK_LOGO_HEIGHT} className="block" />
            </div>

            <button
              id="karsilama-giris"
              type="button"
              data-kelimeki-giris=""
              className={BASLIK_BUTON}
              style={BUTON_OLCU}
            >
              Giriş
            </button>
          </div>
        </div>

        <main className="w-full flex flex-col items-center">
          <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-9">
            {/* ── Kahraman ─────────────────────────────────────────────────
                `-mt-6` (−24px) kaptaki `py-6`nın üst yarısını yiyerek başlık
                satırı ile logo arasını 0'a indirir — `Setup.tsx`'teki AYNI
                kalıp (orada da logo GİRİŞ satırının hemen altına oturuyor). */}
            <div className="flex flex-col items-center gap-4 text-center -mt-6">
              <h1 id="karsilama-logo" className="flex flex-col items-center gap-1" style={{ margin: 0 }}>
                <LandingLogo height={52} className="block" />
                <span className="sr-only">
                  Kelimeki — Ücretsiz Online Türkçe Stratejik Kelime Bulmaca Oyunu
                </span>
              </h1>

              <p className="text-[19px] font-bold leading-snug" style={{ margin: 0 }}>
                Kelime kur, bölgeni büyüt, tahtayı ele geçir.
              </p>

              <p className="text-[13px] leading-relaxed text-muted" style={{ margin: 0 }}>
                Kelimeki, 13×13'lük bir tahtada köşelerden başlayan özgün bir
                mekanikle oynanan Türkçe kelime oyunudur. {KELIME_SAYISI}'den fazla
                kelimelik TDK sözlüğüyle, yapay zekaya ya da arkadaşlarına karşı.
              </p>

              <div className="w-full flex flex-col gap-2 pt-1">
                <Oyna etiket="Hemen Oyna" />
                <span className="font-mono text-[10px] text-muted">
                  Ücretsiz · Kurulum yok · Üyeliksiz başlar
                </span>
              </div>
            </div>

            {/* ── Rakamlar ─────────────────────────────────────────────── */}
            <div className="flex gap-2">
              <Kutu sayi={`${KELIME_SAYISI}+`} etiket="Kelime" />
              <Kutu sayi="13×13" etiket="Tahta" />
              <Kutu sayi="2–4" etiket="Oyuncu" />
              <Kutu sayi="Ücretsiz" etiket="Fiyat" />
            </div>

            {/* ── Tahta ────────────────────────────────────────────────────
                Bu bir ekran görüntüsü DEĞİL: üretimdeki `Board.tsx`'in
                sunucuda render edilmiş hâli (taşlar `demoBoard.ts`'te).
                Yani ziyaretçinin gördüğü tahta, oyuna girdiğinde göreceğiyle
                birebir aynı bileşendir — köşe tonlaması, bölge dış hattı,
                ev işareti, X2/X3 hepsi tek kaynaktan. */}
            <Bolum ustBaslik="Tahtaya bir bak" baslik="Oyun tam olarak böyle görünüyor">
              <p className="text-[12px] leading-relaxed text-muted" style={{ margin: 0 }}>
                İki oyuncu karşılıklı köşelerden başladı; ikisi de ortadaki bonus
                bölgesine uzandı. Renkli alanlar kimin nereyi ele geçirdiğini
                gösteriyor — bundan sonrası bölge kapma yarışı.
              </p>
              <GameBoardPreview
                snapshot={DEMO_TILES}
                playerCount={2}
                players={[
                  { name: 'Sen', score: 0, is_ai: false, colorIndex: 0 },
                  { name: 'Rakip', score: 0, is_ai: false, colorIndex: 1 },
                ]}
              />
              <ul className="grid grid-cols-2 gap-x-3 gap-y-1.5 list-none p-0 m-0">
                <Rozet renk={PLAYER_COLORS[0].base} metin="1. oyuncunun taşları" />
                <Rozet renk={PLAYER_COLORS[1].base} metin="2. oyuncunun taşları" />
                <Rozet renk={PLAYER_COLORS[0].zone} metin="Ele geçirilmiş bölge" />
                <Rozet renk="#DDE4EE" metin="Henüz kimsenin değil" />
                <Rozet renk="#FDE68A" metin="X2 — kelime puanı iki katı" />
                <Rozet renk="#F97316" metin="X3 — tam merkezdeki kare" />
              </ul>
            </Bolum>

            {/* ── Nasıl oynanır ────────────────────────────────────────── */}
            <Bolum id="nasil-oynanir" ustBaslik="Üç adımda" baslik="Nasıl oynanır?">
              <ol className="list-none p-0 m-0 flex flex-col gap-2.5">
                <Adim
                  no={1}
                  baslik="Köşenden başla"
                  metin="İlk kelimen köşendeki ev karesine değmek zorunda. Herkes kendi köşesinden açılır."
                  izgara={['AAA~.', '~~~~.', '~~~~.', '~~~~.', '.....']}
                />
                <Adim
                  no={2}
                  baslik="Bölgeni büyüt"
                  metin="Köşenden kesintisiz zincirlenen her taş bölgeni büyütür. Bölge sabit değil; oynadıkça yayılır."
                  izgara={['AAAA.', '~~~A.', '~~~A.', '~~~A.', '...A.']}
                />
                <Adim
                  no={3}
                  baslik="Merkezi ve rakibi zorla"
                  metin="Ortadaki 5×5 bölge kelime puanını ikiye, tam merkez üçe katlar. Rakibin bölgesine oynamak serbesttir — ama puanın bir kısmı ona geçer."
                  izgara={['..A..', '.###.', '.#*#.', '.###.', '..B..']}
                />
              </ol>
            </Bolum>

            {/* ── Özellikler ───────────────────────────────────────────── */}
            <Bolum ustBaslik="Neler var" baslik="Kelimeki'de neler yapabilirsin?">
              <ul className="grid grid-cols-2 gap-2 list-none p-0 m-0">
                <Ozellik
                  baslik="Yapay zekaya karşı"
                  metin="Rafından kurabildiği en yüksek puanlı kelimeyi arayan bir rakip. 2 ya da 4 kişilik."
                />
                <Ozellik
                  baslik="Arkadaşınla canlı"
                  metin="Davet gönder, sıra sana geçince oyna. Aynı anda çevrimiçi olmanız gerekmez."
                />
                <Ozellik
                  baslik="Oyun içi sohbet"
                  metin="Canlı oyunlarda masadan ayrılmadan yazışın; rahatsız eden olursa sessize al ya da bildir."
                />
                <Ozellik
                  baslik="Çevrimdışı da oynar"
                  metin="Yapay zeka oyunu internetsiz sürer; bağlantı gelince kaldığın yerden senkronlanır."
                />
                <Ozellik
                  baslik="Kelime anlamları"
                  metin="Tahtadaki bir kelimeye dokun, sözlükteki anlamını orada gör."
                />
                <Ozellik
                  baslik="k-lig ve rütbeler"
                  metin="Kazandıkça puan toplarsın; eşikleri geçtikçe rütben yükselir."
                />
              </ul>
            </Bolum>

            {/* ── k-lig ────────────────────────────────────────────────────
                Kademe listesi `RANK_TIERS`ten OKUNUYOR (elle yazılmıyor):
                eşik/ad/renk değişirse bu sayfa kendiliğinden takip eder —
                `HelpModal`'ın "Rütbeler ve Ödüller" bölümüyle aynı ilke.
                Mühürler de gerçek `RankSeal` bileşeni, ayrı bir çizim değil. */}
            <Bolum ustBaslik="k-lig" baslik="Çaylak'tan Tanrı'ya dokuz rütbe">
              <p className="text-[12px] leading-relaxed text-muted" style={{ margin: 0 }}>
                Kazandığın her oyun k-lig puanı getirir. Eşiği geçtiğin an rütben
                yükselir ve o eşiğe özel, bir kereye mahsus bir ödül puanı
                kazanırsın.
              </p>
              <ul className="grid grid-cols-3 gap-2 list-none p-0 m-0">
                {RANK_TIERS.map((tier) => (
                  <li
                    key={tier.name}
                    className="bg-panel border border-border rounded-xl py-2.5 shadow-raised flex flex-col items-center gap-1"
                  >
                    <RankSeal tier={tier} size={30} />
                    <span className="text-[10px] font-bold leading-none">{tier.name}</span>
                    <span className="font-mono text-[9px] leading-none text-muted">{tier.threshold}</span>
                  </li>
                ))}
              </ul>
            </Bolum>

            {/* ── SSS ──────────────────────────────────────────────────── */}
            <Bolum ustBaslik="Sık sorulanlar" baslik="Merak edilenler">
              <div className="flex flex-col gap-2">
                <Soru
                  soru="Ücretli mi?"
                  cevap="Hayır. Kelimeki tamamen ücretsiz; reklam ya da oyun içi satın alma yok."
                />
                <Soru
                  soru="Üye olmadan oynayabilir miyim?"
                  cevap="Evet. Yapay zekaya karşı oynamak için hesap gerekmiyor. Üye olursan oyun geçmişin, k-lig puanın ve arkadaş listen cihazlar arasında taşınır; arkadaşınla canlı oyun ise üyelik ister."
                />
                <Soru
                  soru="Hangi kelimeler geçerli?"
                  cevap={`TDK Güncel Türkçe Sözlük kaynaklı ${KELIME_SAYISI}'den fazla madde. Özel isimler ve çok sözcüklü maddeler listede yok. Tahtadaki bir kelimeye dokunarak anlamını da görebilirsin.`}
                />
                <Soru
                  soru="Klasik kelime oyunlarından farkı ne?"
                  cevap="Tahtanın köşeleri oyunculara ait ve herkes kendi köşesinden başlayıp bölgesini büyütüyor. Rakibin bölgesine oynamak serbest, ama kazandığın puanın bir kısmı o bölgenin sahibine geçiyor — yani nereye oynadığın en az ne oynadığın kadar önemli."
                />
                <Soru
                  soru="Uygulama indirmem gerekiyor mu?"
                  cevap="Hayır, tarayıcıda çalışıyor. İstersen telefonundaki 'Ana Ekrana Ekle' seçeneğiyle uygulama gibi de kurabilirsin."
                />
                <Soru
                  soru="Arkadaşımla aynı anda çevrimiçi olmamız gerekiyor mu?"
                  cevap="Hayır. Canlı oyunlar sırayla oynanır ve her hamle için 48 saat süre vardır; sıra sana geçtiğinde e-posta ile haber verilir."
                />
              </div>
            </Bolum>

            {/* ── Son çağrı ────────────────────────────────────────────── */}
            <section className="w-full flex flex-col items-center gap-3 text-center border-t border-border pt-7">
              <LandingLogo height={34} className="block" />
              <p className="text-[13px] leading-relaxed text-muted" style={{ margin: 0 }}>
                Bir tahta seni bekliyor. İlk kelimeni köşenden kur.
              </p>
              <div className="w-full flex flex-col gap-2 pt-1">
                <Oyna etiket="Oyuna Başla" />
                <Giris etiket="Giriş Yap" />
              </div>
            </section>
          </div>
        </main>
      </div>
    </div>
  );
}
