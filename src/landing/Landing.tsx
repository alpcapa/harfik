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
import { ShareIcon } from '../components/RelationIcons';
import { RANK_TIERS } from '../utils/leagueRank';
import { PLAYER_COLORS } from '../game/constants';
import { DEMO_TILES_2, DEMO_TILES_4 } from './demoBoard';
import {
  CevrimdisiIkon,
  IkiKisiIkon,
  MadalyaIkon,
  RobotIkon,
  SohbetIkon,
  TahtaIkon,
} from './OzellikIkonlari';

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

// Şeritteki GİRİŞ düğmesi `UserMenu.tsx:145`'teki uygulama içi GİRİŞ
// düğmesiyle BİREBİR aynı (accent/mavi + `btn-raised`) — katman uygulamayla
// hizalı kalsın diye.
const BASLIK_BUTON = `${BUTON_TABAN} btn-raised bg-accent border-accent text-white`;

// Park eden logo, GİRİŞ düğmesiyle TAM AYNI yükseklikte (kullanıcı isteği,
// 18 Ağustos 2026: "kelimeki logosunu giriş butonuna eşit yüksekliğe
// çekebiliriz"). Sabit bir piksel YAZILMIYOR — düğmenin kendi akışkan
// formülünden türetiliyor (2 × dikey dolgu + punto + 2 × 1 px çerçeve), yani
// `GIRIS_*` sabitleri değişirse logo kendiliğinden takip eder.
const PARK_LOGO_HEIGHT = `calc(2 * ${GIRIS_PADDING_Y} + ${GIRIS_FONT_SIZE} + 2px)`;

// `src/data/words.ts` bugün 63.896 madde taşıyor; yuvarlanmış hâli hem burada
// hem SSS'te kullanılıyor. Liste büyürse İKİSİ de tek yerden değişsin diye
// sabit. (README'deki rakamla aynı disiplin — bkz. CLAUDE.md "Belgeleri
// Güncel Tutma".)
const KELIME_SAYISI = '63.000';

/**
 * SSS metinleri — TEK KAYNAK. Hem ekrandaki `<details>` kutuları (aşağıda,
 * `.map`) hem `render.tsx`'in ürettiği `FAQPage` JSON-LD'si (18 Ağustos
 * 2026, SEO denetimi) bu diziyi tüketir. Metinleri schema için İKİNCİ KEZ
 * yazmak bu kod tabanının en sık tekrarlayan hata sınıfını (iki kopyanın
 * sessizce ayrışması — bkz. CLAUDE.md'deki renk paleti/rütbe tablosu/hukuki
 * metin örnekleri) yeniden üretirdi.
 */
export const SSS: { soru: string; cevap: string }[] = [
  {
    soru: 'Ücretli mi?',
    cevap:
      'Hayır. Kelimeki tamamen ücretsiz; reklam ya da oyun içi satın alma olmayan bir oyundur.',
  },
  {
    soru: 'Üye olmadan oynayabilir miyim?',
    cevap:
      'Evet. Yapay zekaya karşı oynamak için hesap gerekmiyor. Üye olursan oyun geçmişin, k-lig puanın ve arkadaş listen cihazlar arasında taşınır; arkadaşınla canlı oyun ise üyelik ister.',
  },
  {
    soru: 'Hangi kelimeler geçerli?',
    cevap: `TDK Güncel Türkçe Sözlük kaynaklı ${KELIME_SAYISI}'den fazla kelime. Özel isimler ve çok sözcüklü kelimeler listede yok. İstediğin zaman tahtadaki bir kelimeye dokunarak anlamını da görebilirsin.`,
  },
  {
    soru: 'Klasik kelime oyunlarından farkı ne?',
    cevap:
      'Tahtanın köşeleri oyunculara ait ve herkes kendi köşesinden başlayıp bölgesini büyütüyor. Rakibin bölgesine oynamak serbest, ama kazandığın puanın bir kısmı o bölgenin sahibine geçiyor — yani nereye oynadığın en az ne oynadığın kadar önemli.',
  },
  {
    soru: 'Uygulama indirmem gerekiyor mu?',
    cevap:
      "Hayır, tarayıcıda çalışıyor. İstersen telefonundaki 'Ana Ekrana Ekle' seçeneğiyle uygulama gibi de kurabilirsin.",
  },
  {
    soru: 'Kelimeki\'nin mobil uygulaması yok mu?',
    cevap:
      'Mobil uygulamalarımız hazır; şu anda App Store ve Google Play inceleme sürecinde, çok yakında mağazalarda olacaklar. O zamana kadar tarayıcıdan eksiksiz oynayabilirsin.',
  },
  {
    soru: 'Arkadaşımla aynı anda çevrimiçi olmamız gerekiyor mu?',
    cevap:
      'Hayır. Canlı oyunlar sırayla oynanır ve her hamle için 48 saat süre vardır. Tabii ki aynı anda bağlı iki oyuncu canlı da oynayabilir; bu gerçekten son derece keyiflidir.',
  },
];

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

function Bolum({
  baslik,
  ustBaslik,
  id,
  baslikClassName = '',
  children,
}: {
  baslik: string;
  ustBaslik?: string;
  id?: string;
  /**
   * Yalnızca BAŞLIK bloğunu daraltmak için (18 Ağustos 2026, kullanıcı
   * bildirdi: yatay tablette tahta bölümü "diğer bölümlerden büyük"
   * duruyordu). Tahta bölümü, taş harfleri gerçek oyunla birebir olsun
   * diye kendi `max-w-[680px]` kabında yaşıyor (bkz. o kabın yorumu) —
   * ama BAŞLIĞIN da o genişlikte olması gerekmiyordu ve 834px'te öteki
   * bölüm başlıklarından 114px sola taşıyordu. Ölçüldü: bu prop ile
   * 834/1194'te başlığın sol kenarı öteki başlıklarla BİREBİR aynı.
   * Verilmezse hiçbir bölüm etkilenmez.
   */
  baslikClassName?: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className="w-full flex flex-col gap-3">
      <div className={`flex flex-col gap-0.5${baslikClassName ? ` ${baslikClassName}` : ''}`}>
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
 *   `*` merkezdeki X3 karesi · `b` 2. oyuncunun bölgesi (taşsız)
 *   `A` 1. oyuncunun taşı · `B` 2. oyuncunun taşı
 */
function MiniIzgara({ satirlar }: { satirlar: string[] }) {
  const zemin: Record<string, string> = {
    '.': '#DDE4EE',
    '~': PLAYER_COLORS[0].zone,
    '#': '#FDE68A',
    '*': '#F97316',
    b: PLAYER_COLORS[1].zone,
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

/**
 * `ikon` başlığın HEMEN SOLUNDA, başlık puntosu kadar (13px) duruyor —
 * kullanıcı isteği (18 Ağustos 2026): "Başlığın hemen yanına minik, yazı
 * kadar." Hizalama `items-start` + 1px'lik bir nudge: başlık dar kartlarda
 * (390px'te iç genişlik ~151px) neredeyse her zaman iki satıra sarıyor,
 * `items-center` ikonu o iki satırın ortasına düşürüp ilk satırla ilişkisini
 * koparıyordu.
 */
function Ozellik({
  baslik,
  metin,
  ikon,
}: {
  baslik: string;
  metin: string;
  ikon: React.ReactNode;
}) {
  return (
    <li className="bg-panel border border-border rounded-xl p-3 shadow-raised flex flex-col gap-1">
      <h3
        className="text-[12px] font-bold leading-tight flex items-start gap-1.5"
        style={{ margin: 0 }}
      >
        <span className="shrink-0 mt-[1px] text-accent">{ikon}</span>
        <span className="min-w-0">{baslik}</span>
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
    <li className="flex shrink-0 items-center gap-2 text-[11px] leading-tight">
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
          <div className="relative w-full max-w-[460px] flex items-center px-3.5 py-3">
            {/* LOGO YUVASI — logonun "park ettiği" yer. Kullanıcı isteği (18
                Ağustos 2026): "Kelimeki logosu … kaybolduğu anda … küçülmüş
                olarak yerleşsin."

                Şeritte BİR TEK giriş düğmesi var: sayfanın tepesindeki büyük
                "HEMEN OYNA" dururken başlıkta ikinci bir OYNA gereksizdi
                (kullanıcı isteği, aynı gün) — kaldırıldı.

                ⚠ Yuva AKIŞTA DEĞİL, `absolute inset-0`: `flex-1` ile
                konulduğunda logo şeridin GİRİŞ'ten ARTA KALAN alanının
                ortasında duruyordu, yani sayfanın gerçek ortasının
                (GİRİŞ genişliği ÷ 2) kadar solunda — kullanıcı bunu "tam
                ortalı durmuyor" diye bildirdi. Mutlak konumla logo şeridin
                TAMAMINA göre ortalanıyor; şeridin yüksekliğini yine yalnızca
                düğme belirliyor (logo onunla aynı boyda) ve
                `pointer-events-none` dokunuşların altındaki alana geçmesini
                sağlıyor.

                Logo BURADA HER ZAMAN VAR (statik HTML); yalnızca görünürlüğü
                CSS'te (`index.css` → `.logo-parkli`). `main.tsx`'teki
                `IntersectionObserver`, kahraman logo şeridin altına girdiği an
                sınıfı ekliyor. Sabit bir kaydırma eşiği ("120 px sonra")
                YANLIŞ olurdu: şerit yüksekliği akışkan, yani eşik ekran
                genişliğine göre değişir — `rootMargin` bu yüzden çalışma
                zamanında şeridin `offsetHeight`'inden okunuyor. */}
            <div
              id="karsilama-logo-yuvasi"
              className="absolute inset-0 flex items-center justify-center pointer-events-none"
              aria-hidden="true"
            >
              <LandingLogo height={PARK_LOGO_HEIGHT} className="block" />
            </div>

            <button
              id="karsilama-giris"
              type="button"
              data-kelimeki-giris=""
              className={`${BASLIK_BUTON} ml-auto`}
              style={BUTON_OLCU}
            >
              Giriş
            </button>
          </div>
        </div>

        <main className="w-full flex flex-col items-center">
          <div className="w-full max-w-[460px] px-4 pt-6 flex flex-col gap-9">
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
                Kelime bul, bölgeni büyüt, tahtayı ele geçir.
              </p>

              <p className="text-[13px] leading-relaxed text-muted" style={{ margin: 0 }}>
                Kelimeki, 2 veya 4 kişi yapay zekaya veya arkadaşlarına karşı
                oynanabilen, strateji odaklı Türkçe kelime oyunudur.
              </p>

              <div className="w-full flex flex-col gap-2 pt-1">
                <Oyna etiket="Hemen Oyna" />
                <span className="font-mono text-[10px] text-muted">
                  Ücretsiz · Kurulum yok · Üyelik gerekmez
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
          </div>

          {/* ⚠ Tahta bölümü BİLEREK 460px'lik metin kolonunun DIŞINDA
              (18 Ağustos 2026, kullanıcı: "Bu sefer de küçük oldu. Normal
              oyundaki gibi olmalı"). Sebebi ölçüldü: taş harfi `vw` tabanlı
              bir `clamp` (`Tile.tsx`), hücre ise KABIN genişliğine bağlı.
              Tahta metin kolonunun içindeyken 390px viewport'ta 334px
              oluyordu (kolonun `px-4`ü + tahtanın kendi `px-3`ü), gerçek
              oyunda ise 366px — yani harf/hücre oranı tutmuyordu: compact
              varyant 0.36, normal varyant 0.58, gerçek oyun 0.53. İki tur
              boyunca yanlış yerde (font boyutunda) arandı; sorun tahtanın
              DAR olmasıydı. Bölüm kendi kabına alınınca içindeki
              `max-w-[680px] px-3` (GameBoardPreview -> Board, gerçek oyunun
              kullandığı AYNI kutu) devreye giriyor ve geometri her
              genişlikte gerçek oyunla birebir eşleşiyor.

              Negatif margin ile çözülemezdi: `-mx-4` yalnızca dolguyu
              yiyor, ebeveynin `max-w-[460px]`ini aşamıyor. */}
          <div className="w-full max-w-[680px] px-3 my-9 flex flex-col">

            {/* ── Tahta ────────────────────────────────────────────────────
                İKİ görsel, yan yana kaydırmalı (kullanıcı isteği, 18 Ağustos
                2026): 2 kişilik ve 4 kişilik tahta. Kaydırma tamamen CSS —
                `overflow-x-auto` + `snap-x snap-mandatory`, hiç JS yok.
                `main.tsx` yalnızca ALTTAKİ İKİ NOKTAYI güncelliyor (hangi
                görselde olduğun anlaşılsın diye); nokta güncellemesi düşse
                bile kaydırma çalışmaya devam eder.

                Tahtalar ekran görüntüsü DEĞİL: üretimdeki `Board.tsx`'in
                sunucuda render edilmiş hâli (taşlar `demoBoard.ts`'te, her
                kelimesi `npm run verify-demo-board` ile sözlüğe karşı
                doğrulanıyor). Köşe tonlaması, bölge dış hattı, ev işareti,
                X2/X3 hepsi tek kaynaktan.

                `py-2 -my-2`: kaydırma kabı dikeyde de kırpar (CSS'te bir eksen
                `auto` ise diğeri de `visible` kalamaz) — tahtanın gölgesi
                kesilmesin diye içeriden pay veriliyor, dış ölçü değişmiyor. */}
            <Bolum
              ustBaslik="Tahtaya bir bak"
              baslik="Oyun tam olarak böyle görünüyor"
              /* 428 = öteki bölümlerin metin genişliği (`max-w-[460px]`
                 eksi `px-4`). Tahtanın KENDİSİ geniş kalıyor — bu bilinçli
                 (gerçek oyunla aynı kutu = aynı harf oranı, bkz. yukarısı);
                 daraltılan yalnızca metin. */
              baslikClassName="w-full max-w-[428px] mx-auto"
            >
              <div
                id="karsilama-tahta-serit"
                /* `-mx-3`: metinler kabın `px-3`ünde hizalı kalsın ama ŞERİT
                   o dolgudan çıksın — böylece tahtanın KENDİ `max-w-[680px]
                   px-3` kutusu (gerçek oyunun kullandığı aynı kutu) devreye
                   girip geometri birebir eşleşiyor. Negatif margin burada
                   çalışıyor çünkü yalnızca DOLGUYU yiyor; ebeveynin
                   `max-w`ini aşmaya çalışmıyor. */
                className="flex gap-4 overflow-x-auto snap-x snap-mandatory no-scrollbar py-2 -my-2 -mx-3"
              >
                <div className="snap-center shrink-0 w-full flex flex-col gap-3">
                  {/* `role="img"` + `aria-label`: aksi halde 13×13 = 169
                      hücrenin her biri tek tek ekran okuyucuya (ve
                      crawler'ın taranabilir metnine "K E L İ M E A R A…"
                      diye harf çorbası olarak) okunur. `role="img"` çocuk
                      düğümlere inmeyi keser — `RankSeal`'daki 9 mühürde
                      kullanılan desenin aynısı. `Board.tsx`'e DOKUNULMADI:
                      öznitelik yalnızca bu katmanın kendi sarmalayıcısında —
                      gerçek oyunda tahta bir "resim" değil etkileşimli bir
                      yüzey. */}
                  <div role="img" aria-label="2 kişilik oyun tahtası örneği — KELİME, IRMAK, ZAMAN gibi kelimelerle dolu 13×13 tahta">
                    <GameBoardPreview
                      snapshot={DEMO_TILES_2}
                      playerCount={2}
                      compact={false}
                      players={[
                        { name: 'Sen', score: 0, is_ai: false, colorIndex: 0 },
                        { name: 'Rakip', score: 0, is_ai: false, colorIndex: 1 },
                      ]}
                    />
                  </div>
                  {/* 18 Ağustos 2026 — kullanıcı isteği ("resimlerin altındaki
                      yazılar sola yapışmış, ortala hepsini"): `grid-cols-2`
                      yerine ortalanmış bir flex satırı. ÖLÇÜLDÜ, seçim
                      buna dayanıyor: iki öğenin içeriği 166.1px, grid'in
                      sütunu 360px'te yalnızca 158px — yani metin sütunun
                      içinde SARIYORDU (yükseklik 27.5) ve orada
                      `justify-center` hiçbir şey değiştirmezdi. Flex+wrap ile
                      360'ta iki öğe alt alta ama her biri TEK satır ve
                      ortalı; 390 ve üstünde ikisi yan yana ve grup olarak
                      ortalı. */}
                  <ul className="w-full max-w-[428px] mx-auto flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5 list-none p-0 m-0">
                    <Rozet renk="#FDE68A" metin="X2 — Kelime puanının 2 katı" />
                    <Rozet renk="#F97316" metin="X3 — Kelime puanının 3 katı" />
                  </ul>
                  <p className="w-full max-w-[428px] mx-auto text-[12px] leading-relaxed text-muted text-center" style={{ marginTop: 0, marginBottom: 0 }}>
                    Köşenden başla, orta bölgedeki sarı alana ulaş, puanlarını
                    ikiye hatta üçe katla. Rakip bölgesine değen hamle yaparsan
                    kazandığının üçte birini ona vergi olarak ödersin.
                  </p>
                </div>

                <div className="snap-center shrink-0 w-full flex flex-col gap-3">
                  <div role="img" aria-label="4 kişilik oyun tahtası örneği — dört köşeden başlayıp merkeze uzanan, KELİME, BALKON, KUZEY, OYUN gibi kelimelerle dolu 13×13 tahta">
                    <GameBoardPreview
                      snapshot={DEMO_TILES_4}
                      playerCount={4}
                      compact={false}
                      players={[
                        { name: 'Sen', score: 0, is_ai: false, colorIndex: 0 },
                        { name: '2. oyuncu', score: 0, is_ai: false, colorIndex: 1 },
                        { name: '3. oyuncu', score: 0, is_ai: false, colorIndex: 2 },
                        { name: '4. oyuncu', score: 0, is_ai: false, colorIndex: 3 },
                      ]}
                    />
                  </div>
                  <p className="w-full max-w-[428px] mx-auto text-[12px] leading-relaxed text-muted text-center" style={{ marginTop: 0, marginBottom: 0 }}>
                    Dilersen 3 yapay zekaya veya 3 arkadaşına karşı oyna, gücünü
                    sına. 3 oyuncuyu yenmenin keyfi bir başka ama ikinci bile
                    olsan k-lig puanı kazanırsın.
                  </p>
                </div>
              </div>

              {/* Kaydığı anlaşılsın diye iki nokta. `aria-hidden` — bilgi
                  taşımıyor, kaydırma kabının kendisi zaten erişilebilir. */}
              <div
                id="karsilama-tahta-noktalar"
                aria-hidden="true"
                className="flex items-center justify-center gap-1.5"
              >
                <span className="block w-1.5 h-1.5 rounded-full bg-accent transition-colors" />
                <span className="block w-1.5 h-1.5 rounded-full bg-border transition-colors" />
              </div>
            </Bolum>
          </div>

          <div className="w-full max-w-[460px] px-4 pb-6 flex flex-col gap-9">

            {/* ── Nasıl oynanır ────────────────────────────────────────── */}
            <Bolum id="nasil-oynanir" ustBaslik="Dört adımda" baslik="Nasıl oynanır?">
              <ol className="list-none p-0 m-0 flex flex-col gap-2.5">
                <Adim
                  no={1}
                  baslik="Köşenden başla"
                  metin="İlk kelimen köşendeki ev karesine değmek zorunda. Herkes kendi köşesinden başlar."
                  izgara={['AAA~.', '~~~~.', '~~~~.', '~~~~.', '.....']}
                />
                <Adim
                  no={2}
                  baslik="Bölgeni büyüt"
                  metin="Köşenden kesintisiz bağlanan her taş bölgeni büyütür. Bölgen sabit bir alan değildir, sen oynadıkça büyür."
                  izgara={['AAAA.', '~~~A.', '~~~A.', '~~~A.', '...A.']}
                />
                <Adim
                  no={3}
                  baslik="Merkeze oyna"
                  metin="Ortadaki 5×5 bölge kelime puanını ikiye, tam merkezdeki tek kare ise üçe katlar. Oraya git!"
                  izgara={['..A..', '.###.', '.#*#.', '.###.', '.....']}
                />
                <Adim
                  no={4}
                  baslik="Bölge vergisine dikkat!"
                  metin="İlk hamleden sonra istediğin zaman rakibin bölgesine değen/giren hamle yapabilirsin; ama vergisini ödersin, unutma!"
                  izgara={['.....', '.bbb.', '.bAb.', '.bbb.', '.....']}
                />
              </ol>
              {/* ⚠ GERÇEK bir `<a href>` — bu satırın asıl işi tarayıcı
                  DEĞİL, TARAYICI ROBOTU. `/nasil-oynanir/` yalnızca
                  `sitemap.xml`de dursaydı öksüz bir sayfa olurdu; katmandan
                  verilen bu bağlantı onu keşfedilebilir kılıyor.
                  Footer'daki hukuki bağlantıların `<button>` olmasının
                  sebebi ayrı (SPA penceresi açıyorlar, bkz. aşağıdaki not) —
                  burası öyle değil, hedefi statik bir sayfa.

                  ⚠ `target="_blank"` BİLEREK (31 Ağustos 2026, kullanıcı
                  kararı: "ilk defa gelen kişiyi başka yere göndermek
                  yanlış"). İç bağlantılarda yeni sekme normalde kaçınılan
                  bir kalıp — geri tuşunu işlevsizleştiriyor — ama bu sayfa
                  KARŞILAMA katmanı, yani ilk ziyaretçinin dönüşüm sayfası:
                  onu buradan çıkarmanın bedeli sekme sürprizinden ağır.
                  Robot tarafı ETKİLENMİYOR: Googlebot `href`i `target`tan
                  bağımsız izliyor, yani öksüzlük çözümü aynen duruyor.
                  `aria-label` yeni sekmeyi duyuruyor (görünen metni de
                  içeriyor — WCAG "Label in Name"). */}
              <a
                href="/nasil-oynanir/"
                target="_blank"
                rel="noopener"
                aria-label="Kuralların tamamı (yeni sekmede açılır)"
                className="self-start mt-1 font-mono text-[11px] text-accent underline-offset-2 hover:underline"
              >
                Kuralların tamamı →
              </a>
            </Bolum>

            {/* ── Özellikler ───────────────────────────────────────────── */}
            <Bolum ustBaslik="Neler var" baslik="Kelimeki'de neler yapabilirsin?">
              <ul className="grid grid-cols-2 gap-2 list-none p-0 m-0">
                <Ozellik
                  ikon={<RobotIkon />}
                  baslik="Yapay zekaya karşı oyna"
                  metin="Kurabildiği en yüksek puanlı kelimeyi arayan amansız bir rakip. İster 1 rakip, ister 3 rakibe karşı oyna."
                />
                <Ozellik
                  ikon={<IkiKisiIkon />}
                  baslik="Arkadaşınla canlı oyna"
                  metin="Oyun aç, davet gönder, ister canlı, ister 48 saat içinde hamle yaparak rahatça oyna."
                />
                <Ozellik
                  ikon={<SohbetIkon />}
                  baslik="Oyun içi sohbet"
                  metin="Canlı oyunlarda masadan ayrılmadan yazışın; rahatsız eden olursa sessize al ya da bildir."
                />
                <Ozellik
                  ikon={<CevrimdisiIkon />}
                  baslik="Çevrimdışı da oynar"
                  metin="Yapay zekaya karşı internet bağlantısı olmadan da oynayabilirsin. Canlı oyun için İnternet gerekiyor."
                />
                <Ozellik
                  ikon={<TahtaIkon />}
                  baslik="Kelime denemesi"
                  metin="Sıra sendeyken veya rakipteyken tahtada her zaman kelime denemeleri yapabilirsin."
                />
                <Ozellik
                  ikon={<MadalyaIkon />}
                  baslik="k-lig ve rütbeler"
                  metin="Kazandıkça puan toplar; puan topladıkça eşikleri geçip rütbeni yükseltir, bonusları kaparsın."
                />
              </ul>
            </Bolum>

            {/* ── k-lig ────────────────────────────────────────────────────
                Kademe listesi `RANK_TIERS`ten OKUNUYOR (elle yazılmıyor):
                eşik/ad/renk değişirse bu sayfa kendiliğinden takip eder —
                `HelpModal`'ın "Rütbeler ve Ödüller" bölümüyle aynı ilke.
                Mühürler de gerçek `RankSeal` bileşeni, ayrı bir çizim değil. */}
            <Bolum ustBaslik="k-lig" baslik="Çaylak'tan Kozmik'e dokuz rütbe">
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
                {SSS.map((s) => (
                  <Soru key={s.soru} soru={s.soru} cevap={s.cevap} />
                ))}
              </div>
            </Bolum>

            {/* ── Son çağrı ────────────────────────────────────────────── */}
            <section className="w-full flex flex-col items-center gap-3 text-center border-t border-border pt-7">
              <LandingLogo height={34} className="block" />
              <p className="text-[13px] leading-relaxed text-muted" style={{ margin: 0 }}>
                Oyun seni bekliyor. Mücadeleye hazır mısın?
              </p>
              <div className="w-full flex flex-col gap-2 pt-1">
                <Oyna etiket="Oyuna Başla" />
              </div>

              {/* Hukuki alt satır — `Setup.tsx`'in kendi footer'ıyla AYNI üç
                  bağlantı (18 Ağustos 2026'ya kadar iki bağlantıydı, o gün
                  "Paylaş" eklendi — kullanıcı: "İki tarafa da ikonlu şekilde
                  koy"). Katmanda React state/olay handler'ı olmadığından
                  (bkz. dosya başlığı) hiçbiri kendi tıklamasını burada işleyemez:
                  Kullanım Koşulları/Gizlilik Politikası uygulamaya geçip ilgili
                  pencereyi açtırıyor (`?kosullar=1` / `?gizlilik=1`, `?giris=1`
                  ile birebir aynı kalıp — bkz. `main.tsx` → `gec`); "Paylaş" ise
                  uygulamaya HİÇ geçmiyor — `main.tsx`'teki `paylasiKur()` doğrudan
                  `shareKelimekiLink()`i (`src/utils/shareLink.ts`, Setup.tsx'in
                  KENDİ "Paylaş" linkiyle AYNI fonksiyon) çağırıp native paylaşım/
                  clipboard'ı burada, katman modunda iken açıyor. */}
              <div className="flex flex-wrap items-center justify-center gap-x-2 gap-y-1 pt-4 font-mono text-[10px] text-muted">
                <button type="button" data-kelimeki-kosullar="" className="underline-offset-2 hover:underline">
                  Kullanım Koşulları
                </button>
                <span aria-hidden="true">·</span>
                <button type="button" data-kelimeki-gizlilik="" className="underline-offset-2 hover:underline">
                  Gizlilik Politikası
                </button>
                <span aria-hidden="true">·</span>
                <button
                  type="button"
                  id="karsilama-paylas"
                  data-kelimeki-paylas=""
                  className="flex items-center gap-1 underline-offset-2 hover:underline"
                >
                  <ShareIcon size={12} />
                  {/* `main.tsx`'teki `paylasiKur()` yalnızca bu span'in metnini
                      2 saniyeliğine "Link kopyalandı!" yapıyor (Setup.tsx'in
                      `shareCopied` state'iyle AYNI geri bildirim) — düğmenin
                      TAMAMINA `textContent` yazmak yukarıdaki `ShareIcon`'u da
                      silerdi. */}
                  <span data-kelimeki-paylas-metin>Paylaş</span>
                </button>
              </div>
              <p className="font-mono text-[10px] text-muted" style={{ margin: 0 }}>
                © Kelimeki
              </p>
            </section>
          </div>
        </main>
      </div>
    </div>
  );
}
