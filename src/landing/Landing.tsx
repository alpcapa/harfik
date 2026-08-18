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
//   • olay handler'ı YOK — iki butonun davranışı `main.tsx`'te, id ile
//     bağlanıyor (`karsilama-oyna` / `karsilama-giris`).
// Hedef: karşılama katmanı için 0 KB çalışma zamanı React/Supabase JS'i.
// (Ölçüldü: `@supabase/supabase-js` 54 KB + `react`+`react-dom/client` 45 KB
// gzip; bugünkü tam uygulama 410 KB. Ziyaretçi tanım gereği girişsiz
// olduğundan `UserMenu`'nün avatar/menü dalı hiç gerekmiyor.)
import { LogoMark } from '../components/LogoMark';

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

export function Landing() {
  return (
    // `#karsilama`nın kaydırma/flex kuralları `index.css`'te (`#root`'un
    // birebir karşılığı) — bkz. oradaki not: belge kaydırılmıyor, kaydırma
    // kabı olmadan `sticky` başlık da çalışmaz.
    <div id="karsilama">
      <div className="min-h-[100dvh] w-full flex flex-col items-center">
        {/* ── Kilitli başlık (üç yuva) ─────────────────────────────────────
            Taban: `App.tsx`'in kurulum başlığı satırı (`w-full max-w-[460px]
            flex items-center justify-end px-3.5 pt-3`) — burada `justify-end`
            yerine üç yuva var ve şerit `sticky`. Kullanıcı isteği (18 Ağustos
            2026): "header'ı kilitle, sayfa altına girsin … kaydırdıkça
            içerikler aksın".

            Sticky sarmalayıcı TAM GENİŞLİK, iç şerit `max-w-[460px]` — ikisini
            tek elemanda birleştirmek şeridi ekranın soluna yapıştırırdı. */}
        <div className="sticky top-0 z-20 w-full flex justify-center bg-bg">
          <div className="w-full max-w-[460px] flex items-center gap-2 px-3.5 pt-3">
            <button
              id="karsilama-oyna"
              type="button"
              className={`${BUTON_TABAN} btn-raised bg-accent border-accent text-white`}
              style={BUTON_OLCU}
            >
              Oyna
            </button>

            {/* ORTA YUVA — BİLEREK BOŞ VE REZERVE.
                Bölüm 3'te logo, kaydırılıp görünmez olduğu anda buraya
                küçülerek "park edecek" (kullanıcının istediği efekt). O efekt
                kaydırılacak GERÇEK içerik olmadan test edilemeyeceğinden bu
                bölümde YALNIZCA yapısı kuruluyor.

                ⚠ Ölçüldü: başlık ALTI ile logo ÜSTÜ arası TAM 0.00 px (390 ve
                834 genişlikte ayrı ayrı) — yani efekt kaydırmanın İLK
                pikselinde başlar. Bölüm 3'te sabit bir kaydırma eşiği ("120px
                sonra") yanlış olur; tetikleyici logonun görünürlüğü olmalı
                (`IntersectionObserver`), `rootMargin` da çalışma zamanında
                şeridin `offsetHeight`'inden okunmalı — başlık yüksekliği
                akışkan olduğundan sabit yazılamaz. */}
            <div
              id="karsilama-logo-yuvasi"
              className="flex-1 min-w-0 flex items-center justify-center"
              aria-hidden="true"
            />

            <button
              id="karsilama-giris"
              type="button"
              className={`${BUTON_TABAN} btn-raised-neutral bg-panel border-border text-text`}
              style={BUTON_OLCU}
            >
              Giriş
            </button>
          </div>
        </div>

        <main className="w-full flex flex-col items-center">
          <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
            {/* `-mt-6` (−24px) kaptaki `py-6`nın üst yarısını yiyerek başlık
                satırı ile logo arasını 0'a indirir — `Setup.tsx`'teki AYNI
                kalıp (orada da logo GİRİŞ satırının hemen altına oturuyor). */}
            <div className="text-center flex flex-col items-center gap-1 -mt-6">
              <h1 className="flex flex-col items-center gap-1" style={{ margin: 0 }}>
                <LogoMark height={52} />
                <span className="sr-only">
                  Kelimeki — Ücretsiz Online Türkçe Stratejik Kelime Bulmaca Oyunu
                </span>
              </h1>
            </div>

            {/* ── YER TUTUCU İÇERİK ────────────────────────────────────────
                Bölüm 2'nin amacı boruyu kurmak; gerçek tanıtım/hikâye metni ve
                SEO içeriği Bölüm 3'ün işi. Buradaki metin yalnızca (a) ham
                HTML'de gerçek bir metin sinyali olduğunu, (b) kilitli başlığın
                altından akacak kadar uzun olduğunu göstermek için. */}
            <section className="flex flex-col gap-4 text-sm font-mono text-text leading-relaxed">
              <p>
                Kelimeki, 13×13'lük bir tahtada köşelerden başlayarak oynanan,
                TDK sözlüğüne dayalı ücretsiz bir Türkçe kelime oyunudur. 2 ya da
                4 kişiyle, yapay zekaya ya da arkadaşlarına karşı oynanır.
              </p>
              <p>
                Her oyuncu kendi köşesinden başlar ve kurduğu kelimelerle
                bölgesini genişletir. Rakibin bölgesine girmek serbesttir — ama
                kazandığın puanın bir kısmı o bölgenin sahibine geçer. Oyun bu
                yüzden yalnızca kelime bilgisiyle değil, nereye oynadığınla da
                kazanılır.
              </p>
              <p>
                Tahtanın ortasındaki 5×5'lik bölge kelime puanını ikiye, tam
                merkezdeki tek kare üçe katlar. Yedi taşın hepsini tek hamlede
                kullanmak 25 puan bonus getirir.
              </p>
              <p>
                Arkadaşınla oynadığın canlı oyunlarda sıra sende olmasa da
                tahtada deneme yapabilir, mesajlaşabilir ve oyunu istediğin
                zaman bırakıp kaldığın yerden devam edebilirsin.
              </p>
              <p>
                Hesap açmadan da oynayabilirsin. Üye olursan oyun geçmişin, k-lig
                puanın ve arkadaş listen cihazlar arasında seninle taşınır.
              </p>
              <p>
                Sıra sende değilken oyun seni beklemez: canlı oyunlarda her
                oyuncunun hamlesi için 48 saati vardır. Süre dolarsa oyuncu
                teslim olmuş sayılır ve k-lig puanından düşülür.
              </p>
              <p>
                Yapay zekaya karşı açtığın oyunlar cihazına kaydedilir; üyeysen
                sunucuda da tutulur ve başka bir cihazdan devam edebilirsin.
                İnternet olmadan da oynayabilir, bağlantı gelince kaldığın
                yerden senkronlanabilirsin.
              </p>
              <p>
                Kazandığın puanlar k-lig sıralamasında birikir; belirli
                eşiklerde rütbe atlar ve tek seferlik ödül puanları kazanırsın.
                Çaylak'tan Tanrı'ya dokuz kademe var.
              </p>
            </section>
          </div>
        </main>
      </div>
    </div>
  );
}
