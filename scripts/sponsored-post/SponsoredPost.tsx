// Kelimeki — 6 günlük sponsorlu carousel reklamının 5 kare görseli (1080×1080).
//
// NEDEN BURADA VE NEDEN BÖYLE:
//   • Görseller çizim/ekran görüntüsü DEĞİL — tahtalar üretimdeki
//     `GameBoardPreview` → `Board`, rütbeler gerçek `RankSeal`, logo
//     `LandingLogo` sprite'ı, renkler `PLAYER_COLORS`. Karşılama katmanının
//     (`src/landing/Landing.tsx`) kendi gerekçesiyle aynı: ikinci bir
//     "tanıtım çizimi" bu kod tabanının en sık tekrarlayan hata sınıfını
//     (sessiz ayrışma) büyütürdü. Palet/rütbe/tahta değişirse görseller
//     yeniden üretilince kendiliğinden takip eder.
//
//   • ⚠ TAILWIND SINIFI KULLANILMIYOR (yalnızca inline `style`). Sebep
//     ölçülmüş bir tuzak: `tailwind.config.js`in `content`i yalnızca
//     `./index.html` ve `./src/**/*.{ts,tsx}` — bu dosya `scripts/` altında
//     olduğundan buradaki bir `text-[52px]` DERLENMİŞ CSS'E HİÇ GİRMEZ ve
//     sessizce uygulanmaz. İçe aktarılan üretim bileşenlerinin (Board/Tile/
//     RankSeal) kendi sınıfları `src/` tarandığı için zaten `dist` CSS'inde.
//     Tek istisna `shadow-raised`: o sınıf `src/` içinde kullanıldığından
//     derlenmiş CSS'te var, burada güvenle kullanılabiliyor.
//
//   • ⚠ TAHTA BÜYÜTMEK İÇİN `transform: scale` KULLANILIYOR, kap genişliği
//     DEĞİL. `Board` `max-w-[680px]`, harf ise `vw` tabanlı bir `clamp`
//     (`Tile.tsx`) — kabı daraltmak/genişletmek harf/hücre oranını bozar
//     (18 Ağustos 2026'da karşılama katmanında tam bu yaşandı, iki tur
//     yanlış yerde arandı). `scale` ikisini birlikte ölçekler, oran korunur.
//
// Metinler karşılama sayfasından İLHAM ALIR ama BİREBİR KOPYA DEĞİL: reklam
// kopyası sayfa kopyasından kısadır. Yani bu dosya ile `Landing.tsx`
// arasında bir "senkron tutulmalı" yükümlülüğü YOK — tek kaynak zorunluluğu
// yalnızca VERİ için geçerli (rütbe tablosu, palet, tahta taşları).
import { LandingLogo, LandingLogoDefs } from '../../src/landing/LandingLogo';
import { GameBoardPreview } from '../../src/components/GameBoardPreview';
import { RankSeal } from '../../src/components/RankSeal';
import { RANK_TIERS } from '../../src/utils/leagueRank';
import { PLAYER_COLORS } from '../../src/game/constants';
import { DEMO_TILES_2, DEMO_TILES_4 } from '../../src/landing/demoBoard';
import { IkiKisiIkon, RobotIkon, SohbetIkon } from '../../src/landing/OzellikIkonlari';

const SLIDE = 1080;
const PAD_X = 64;
/** `Board`un kendi `max-w` değeri — ölçek hesabının paydası. */
const BOARD_BASE_W = 680;

const C = {
  bg: '#FFFFFF',
  panel: '#F5F7FA',
  border: '#DCE2EA',
  text: '#1B2430',
  muted: '#5A6673',
  accent: '#2563EB',
  gold: '#FDE68A',
  orange: '#F97316',
};

const SANS = '"Space Grotesk", sans-serif';
const MONO = '"Space Mono", monospace';

/* ────────────────────────────────────────────────────────────────────────── */

/** `duz` — marka adı gibi büyük harfe çevrilmemesi gereken üst başlıklar için
 *  ("k-lig" küçük harf yazılır; `uppercase` onu "K-LİG" yapıp markayı bozuyordu). */
function Kicker({ children, duz = false }: { children: React.ReactNode; duz?: boolean }) {
  return (
    <span
      style={{
        fontFamily: MONO,
        fontSize: 20,
        lineHeight: 1,
        textTransform: duz ? 'none' : 'uppercase',
        letterSpacing: 3,
        color: C.accent,
        fontWeight: 700,
      }}
    >
      {children}
    </span>
  );
}

function Baslik({ children, size = 52 }: { children: React.ReactNode; size?: number }) {
  return (
    <h2
      style={{
        margin: 0,
        fontSize: size,
        lineHeight: 1.14,
        fontWeight: 700,
        letterSpacing: -0.8,
        color: C.text,
      }}
    >
      {children}
    </h2>
  );
}

function Metin({ children, size = 26 }: { children: React.ReactNode; size?: number }) {
  return (
    <p style={{ margin: 0, fontSize: size, lineHeight: 1.55, color: C.muted }}>{children}</p>
  );
}

/** Alt şerit — HER karede `kelimeki.com` görünür (carousel'de URL kartı yalnızca
 *  son karede çıkabiliyor; hedef trafik olduğu için adres her karede duruyor). */
function Footer({ no }: { no: number }) {
  return (
    <div
      style={{
        marginTop: 'auto',
        paddingTop: 22,
        borderTop: `2px solid ${C.border}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
      }}
    >
      <span style={{ fontFamily: MONO, fontSize: 26, fontWeight: 700, color: C.accent }}>
        kelimeki.com
      </span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        {[1, 2, 3, 4, 5].map((i) => (
          <span
            key={i}
            style={{
              display: 'block',
              width: i === no ? 26 : 10,
              height: 10,
              borderRadius: 5,
              background: i === no ? C.accent : C.border,
            }}
          />
        ))}
      </div>
    </div>
  );
}

function Slide({ no, children }: { no: number; children: React.ReactNode }) {
  return (
    <div
      className="kelimeki-slide"
      data-slide={no}
      style={{
        width: SLIDE,
        height: SLIDE,
        boxSizing: 'border-box',
        padding: `64px ${PAD_X}px 52px`,
        background: C.bg,
        color: C.text,
        fontFamily: SANS,
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
      }}
    >
      {children}
      <Footer no={no} />
    </div>
  );
}

/** Tahtayı oranı bozmadan büyütür/küçültür (bkz. dosya başlığı). */
function Tahta({ scale, children }: { scale: number; children: React.ReactNode }) {
  return (
    <div
      style={{
        width: BOARD_BASE_W * scale,
        height: BOARD_BASE_W * scale,
        margin: '0 auto',
        overflow: 'hidden',
      }}
    >
      <div style={{ width: BOARD_BASE_W, transform: `scale(${scale})`, transformOrigin: 'top left' }}>
        {children}
      </div>
    </div>
  );
}

/** 10000 → "10.000". `toLocaleString` yerine elle: Node'un ICU'suna bağlı
 *  kalmadan her ortamda aynı çıktıyı üretsin. */
function binlik(n: number): string {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

function Kutu({ sayi, etiket }: { sayi: string; etiket: string }) {
  return (
    <div
      className="shadow-raised"
      style={{
        flex: 1,
        minWidth: 0,
        background: C.panel,
        border: `1px solid ${C.border}`,
        borderRadius: 22,
        padding: '24px 8px',
        textAlign: 'center',
      }}
    >
      <div style={{ fontFamily: MONO, fontSize: 34, fontWeight: 700, lineHeight: 1, color: C.accent }}>
        {sayi}
      </div>
      <div
        style={{
          fontFamily: MONO,
          fontSize: 16,
          letterSpacing: 1,
          textTransform: 'uppercase',
          color: C.muted,
          marginTop: 10,
        }}
      >
        {etiket}
      </div>
    </div>
  );
}

/**
 * "Nasıl oynanır" adımlarının yanındaki şematik ızgara. `Landing.tsx`teki
 * `MiniIzgara`nın poster ölçeğindeki karşılığı (oradaki hücre 10px sabit).
 * ⚠ RENKLER `PLAYER_COLORS`TAN OKUNUYOR, kopyalanmıyor — paletin iki yerde
 * ayrışması bu kod tabanının bilinen hata sınıfı; asıl korunması gereken
 * değişmez bu, geometri değil.
 *
 * Harf sözlüğü (her satır 5 karakter):
 *   `.` boş · `~` 1. oyuncunun bölgesi · `#` altın X2 zemini · `*` X3 karesi
 *   `b` 2. oyuncunun bölgesi · `A`/`B` oyuncu taşı
 */
function MiniIzgara({ satirlar, hucre = 20 }: { satirlar: string[]; hucre?: number }) {
  const zemin: Record<string, string> = {
    '.': '#DDE4EE',
    '~': PLAYER_COLORS[0].zone,
    '#': C.gold,
    '*': C.orange,
    b: PLAYER_COLORS[1].zone,
    A: PLAYER_COLORS[0].base,
    B: PLAYER_COLORS[1].base,
  };
  return (
    <div
      className="shadow-raised"
      style={{
        flexShrink: 0,
        display: 'grid',
        gap: 4,
        padding: 7,
        borderRadius: 16,
        background: '#DDE4EE',
        gridTemplateColumns: `repeat(5, ${hucre}px)`,
      }}
    >
      {satirlar.flatMap((satir, r) =>
        Array.from(satir).map((h, c) => (
          <span
            key={`${r}-${c}`}
            style={{
              display: 'block',
              width: hucre,
              height: hucre,
              borderRadius: 5,
              background: zemin[h] ?? zemin['.'],
            }}
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
    <li
      className="shadow-raised"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
        gap: 12,
        background: C.panel,
        border: `1px solid ${C.border}`,
        borderRadius: 24,
        padding: 24,
      }}
    >
      <MiniIzgara satirlar={izgara} />
      <h3 style={{ margin: 0, fontSize: 30, lineHeight: 1.15, fontWeight: 700 }}>
        <span style={{ fontFamily: MONO, color: C.accent }}>{no}.</span> {baslik}
      </h3>
      <p style={{ margin: 0, fontSize: 22, lineHeight: 1.45, color: C.muted }}>{metin}</p>
    </li>
  );
}

function Ozellik({
  ikon,
  baslik,
  metin,
  baslikBoyu = 26,
  metinBoyu = 20,
}: {
  ikon: React.ReactNode;
  baslik: string;
  metin: string;
  baslikBoyu?: number;
  metinBoyu?: number;
}) {
  return (
    <li
      className="shadow-raised"
      style={{
        listStyle: 'none',
        background: C.panel,
        border: `1px solid ${C.border}`,
        borderRadius: 22,
        padding: 22,
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
      }}
    >
      <h3
        style={{
          margin: 0,
          fontSize: baslikBoyu,
          lineHeight: 1.15,
          fontWeight: 700,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
        }}
      >
        <span style={{ flexShrink: 0, color: C.accent, display: 'block' }}>{ikon}</span>
        <span style={{ minWidth: 0 }}>{baslik}</span>
      </h3>
      <p style={{ margin: 0, fontSize: metinBoyu, lineHeight: 1.45, color: C.muted }}>{metin}</p>
    </li>
  );
}

function Rozet({ renk, metin }: { renk: string; metin: string }) {
  return (
    <li style={{ display: 'flex', alignItems: 'center', gap: 12, listStyle: 'none' }}>
      <span
        style={{
          flexShrink: 0,
          width: 26,
          height: 26,
          borderRadius: 7,
          border: `1px solid ${C.border}`,
          background: renk,
        }}
      />
      <span style={{ fontSize: 22, color: C.muted }}>{metin}</span>
    </li>
  );
}

/** Slide 5'teki ana çağrı — uygulamadaki "HEMEN OYNA" düğmesinin poster ölçeği. */
function CtaButon({ etiket }: { etiket: string }) {
  return (
    <div
      className="btn-raised"
      style={{
        background: C.accent,
        border: `1px solid ${C.accent}`,
        borderRadius: 26,
        color: '#FFFFFF',
        fontFamily: MONO,
        fontWeight: 700,
        fontSize: 34,
        letterSpacing: 2,
        textTransform: 'uppercase',
        textAlign: 'center',
        padding: '30px 24px',
      }}
    >
      {etiket}
    </div>
  );
}

/* ────────────────────────────────────────────────────────────────────────── */

export function SponsoredPost() {
  return (
    <div id="kelimeki-post">
      <LandingLogoDefs />

      {/* ── 1 · Kanca ──────────────────────────────────────────────────── */}
      <Slide no={1}>
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
            justifyContent: 'center',
            gap: 34,
          }}
        >
          <LandingLogo height={96} />
          <h1
            style={{
              margin: 0,
              fontSize: 76,
              lineHeight: 1.08,
              fontWeight: 700,
              letterSpacing: -2,
            }}
          >
            Kelime bul,
            <br />
            bölgeni büyüt,
            <br />
            <span style={{ color: C.accent }}>tahtayı ele geçir.</span>
          </h1>
          <Metin size={28}>
            2 veya 4 kişi; yapay zekaya ya da arkadaşlarına karşı oynanan,
            strateji odaklı Türkçe kelime oyunu.
          </Metin>
          <div style={{ display: 'flex', gap: 16, width: '100%' }}>
            <Kutu sayi="63.000+" etiket="Kelime" />
            <Kutu sayi="13×13" etiket="Tahta" />
            <Kutu sayi="2–4" etiket="Oyuncu" />
            <Kutu sayi="Ücretsiz" etiket="Fiyat" />
          </div>
          <span style={{ fontFamily: MONO, fontSize: 22, color: C.muted }}>
            Kurulum yok · Üyelik gerekmez · Tarayıcıda çalışır
          </span>
        </div>
      </Slide>

      {/* ── 2 · Ürünün kendisi ─────────────────────────────────────────── */}
      <Slide no={2}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 20 }}>
          <Kicker>Tahtaya bir bak</Kicker>
          <Baslik size={48}>Oyun tam olarak böyle görünüyor</Baslik>
        </div>

        <Tahta scale={1.06}>
          <GameBoardPreview
            snapshot={DEMO_TILES_2}
            playerCount={2}
            compact={false}
            players={[
              { name: 'Sen', score: 0, is_ai: false, colorIndex: 0 },
              { name: 'Rakip', score: 0, is_ai: false, colorIndex: 1 },
            ]}
          />
        </Tahta>

        <ul
          style={{
            listStyle: 'none',
            padding: 0,
            margin: '18px 0 0',
            display: 'flex',
            justifyContent: 'center',
            gap: 44,
          }}
        >
          <Rozet renk={C.gold} metin="X2 — Kelime puanının 2 katı" />
          <Rozet renk={C.orange} metin="X3 — Kelime puanının 3 katı" />
        </ul>
      </Slide>

      {/* ── 3 · Asıl fark ──────────────────────────────────────────────── */}
      <Slide no={3}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 26 }}>
          <Kicker>Dört adımda</Kicker>
          <Baslik size={46}>Ne oynadığın kadar nereye oynadığın da önemli</Baslik>
        </div>

        {/* `flex: 1` + dikey ortalama: kareler sabit yükseklikte olduğundan
            aksi halde altta ~200 px ölü boşluk kalıyordu. */}
        <ol
          style={{
            flex: 1,
            alignContent: 'center',
            listStyle: 'none',
            padding: 0,
            margin: 0,
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gridAutoRows: 'min-content',
            gap: 20,
          }}
        >
          <Adim
            no={1}
            baslik="Köşenden başla"
            metin="İlk kelimen köşendeki ev karesine değmek zorunda. Herkes kendi köşesinden başlar."
            izgara={['AAA~.', '~~~~.', '~~~~.', '~~~~.', '.....']}
          />
          <Adim
            no={2}
            baslik="Bölgeni büyüt"
            metin="Köşene kesintisiz bağlanan her taş bölgeni büyütür — bölgen sen oynadıkça büyür."
            izgara={['AAAA.', '~~~A.', '~~~A.', '~~~A.', '...A.']}
          />
          <Adim
            no={3}
            baslik="Merkeze oyna"
            metin="Ortadaki 5×5 alan kelime puanını ikiye, tam merkezdeki kare ise üçe katlar."
            izgara={['..A..', '.###.', '.#*#.', '.###.', '.....']}
          />
          <Adim
            no={4}
            baslik="Vergiyi göze al"
            metin="Rakibin bölgesine oynamak serbest; ama kazandığın puanın bir kısmı ona geçer."
            izgara={['.....', '.bbb.', '.bAb.', '.bbb.', '.....']}
          />
        </ol>
      </Slide>

      {/* ── 4 · Rakip seçimi ───────────────────────────────────────────── */}
      <Slide no={4}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 26 }}>
          <Kicker>Tek başına da, kalabalık da</Kicker>
          <Baslik size={44}>3 yapay zekaya ya da 3 arkadaşına karşı</Baslik>
        </div>

        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 22 }}>
          <Tahta scale={0.82}>
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
          </Tahta>

          <ul
            style={{
              listStyle: 'none',
              padding: 0,
              margin: 0,
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 16,
            }}
          >
            <Ozellik
              ikon={<RobotIkon size={22} />}
              baslik="Yapay zekaya karşı"
              baslikBoyu={22}
              metinBoyu={18}
              metin="En yüksek puanlı kelimeyi arayan amansız bir rakip. İster 1, ister 3 tanesiyle."
            />
            <Ozellik
              ikon={<IkiKisiIkon size={22} />}
              baslik="Arkadaşınla canlı"
              baslikBoyu={22}
              metinBoyu={18}
              metin="Oyun aç, davet gönder. Aynı anda çevrimiçi olmak şart değil: her hamle için 48 saat."
            />
            <Ozellik
              ikon={<SohbetIkon size={22} />}
              baslik="Oyun içi sohbet"
              baslikBoyu={22}
              metinBoyu={18}
              metin="Canlı oyunlarda masadan ayrılmadan yazışın; rahatsız eden olursa sessize al."
            />
          </ul>
        </div>
      </Slide>

      {/* ── 5 · k-lig + çağrı ──────────────────────────────────────────── */}
      <Slide no={5}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 22 }}>
          <Kicker duz>k-lig</Kicker>
          <Baslik size={48}>Çaylak'tan Kozmik'e dokuz rütbe</Baslik>
          <Metin size={23}>
            Kazandığın her oyun k-lig puanı getirir. Üye ol; puanın, oyun
            geçmişin ve arkadaş listen tüm cihazlarında seninle olsun.
          </Metin>
        </div>

        {/* ⚠ Liste `RANK_TIERS`ten OKUNUYOR, elle yazılmıyor — bir kademenin
            adı/rengi/eşiği değişirse görsel yeniden üretilince takip eder
            (19 Ağustos 2026'da Tanrı→Kozmik değişikliği tam bu sınıftandı). */}
        <ul
          style={{
            flex: 1,
            alignContent: 'space-evenly',
            listStyle: 'none',
            padding: 0,
            margin: 0,
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gridAutoRows: 'min-content',
            gap: 16,
          }}
        >
          {RANK_TIERS.map((tier) => (
            <li
              key={tier.name}
              className="shadow-raised"
              style={{
                background: C.panel,
                border: `1px solid ${C.border}`,
                borderRadius: 20,
                padding: '22px 10px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 12,
              }}
            >
              <RankSeal tier={tier} size={60} />
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                <span style={{ fontSize: 22, fontWeight: 700, lineHeight: 1 }}>{tier.name}</span>
                <span style={{ fontFamily: MONO, fontSize: 18, lineHeight: 1, color: C.muted }}>
                  {binlik(tier.threshold)} puan
                </span>
              </div>
            </li>
          ))}
        </ul>

        <div style={{ marginTop: 22, marginBottom: 10, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <CtaButon etiket="kelimeki.com — hemen oyna" />
          <span
            style={{
              fontFamily: MONO,
              fontSize: 21,
              color: C.muted,
              textAlign: 'center',
            }}
          >
            Ücretsiz · Kurulum yok · Reklam yok
          </span>
        </div>
      </Slide>
    </div>
  );
}
