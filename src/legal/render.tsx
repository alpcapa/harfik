// Hukuki sayfaların STATİK HTML üreticisi — Node'da koşar, tarayıcıya hiç
// gitmez (`src/landing/render.tsx` ile aynı desen: `renderToStaticMarkup`,
// esbuild ile paketlenip Vite eklentisinden import ediliyor).
//
// NEDEN VAR: Play'in Data safety formu doğrudan açılan bir gizlilik politikası
// URL'i istiyor ve o form kapalı test kanalındaki uygulamalar için de zorunlu.
// Bugüne kadar politika YALNIZCA SPA içindeki bir penceredeydi (`?gizlilik=1`)
// — yani inceleyenin JS render'ına güvenmesi gerekiyordu. Aynı gerekçe hesap
// silme için de geçerli: hesap açtıran uygulamalarda Play hem uygulama içi bir
// yol hem de bir WEB silme talep adresi istiyor.
//
// Sayfalar TAMAMEN JS'siz: uygulama paketini hiç yüklemiyorlar, yalnızca
// derlenmiş CSS'e bağlılar.
import { renderToStaticMarkup } from 'react-dom/server';
import { LogoMark } from '../components/LogoMark';
import { PrivacyBody, TermsBody, Section, P, SILME_SURESI_GUN } from './LegalContent';

const SITE = 'https://kelimeki.com';

/** Metin içindeki "Görüş Bildir formu" — pencerede buton, burada bağlantı. */
const iletisim = (
  <a href="/?contact=1" className="text-accent font-mono hover:underline">
    Görüş Bildir formu
  </a>
);

function HesapSilmeBody() {
  return (
    <div className="flex flex-col gap-5">
      <P>
        Kelimeki hesabınızı ve hesabınıza bağlı kişisel verilerinizi kalıcı olarak
        sildirebilirsiniz. Bu sayfa, silme talebinin nasıl iletileceğini ve neyin silinip
        neyin kaldığını açıklar.
      </P>

      <Section title="1. Uygulama İçinden Silme (en hızlı yol)">
        <P>
          Hesabınıza giriş yaptıktan sonra sağ üstteki hesap menüsünden{' '}
          <strong>Hesap Ayarları</strong> &rsaquo; <strong>Hesabımı Sil</strong> adımını
          izleyin. Açılan pencere, silinecek kayıtlarınızı tek tek sayarak gösterir; onayı
          yazdığınızda hesabınız ve verileriniz <strong>anında</strong> silinir. Bu yol hem
          web sitesinde (kelimeki.com) hem mobil uygulamada aynıdır.
        </P>
      </Section>

      <Section title="2. Giriş Yapamıyorsanız: Talep Yolu">
        <P>
          Şifrenizi hatırlamıyorsanız ya da hesabınıza herhangi bir nedenle erişemiyorsanız
          silme talebinizi {iletisim} üzerinden gönderin. Mesajınızda hesabınızın e-posta
          adresini ve hesabınızın silinmesini istediğinizi belirtmeniz yeterli. Talep, hesabın
          gerçekten size ait olduğunun doğrulanmasının ardından işleme alınır.
        </P>
      </Section>

      <Section title="3. Ne Zaman Silinir">
        <P>
          Uygulama içinden başlattığınız silme onayladığınız anda uygulanır. Talep yoluyla
          ilettiğiniz silme ise en geç {SILME_SURESI_GUN} gün içinde, ücretsiz olarak
          sonuçlandırılır. Hesabın geçici olarak devre dışı bırakılması ya da dondurulması
          silme sayılmaz — silme kalıcıdır ve geri alınamaz.
        </P>
      </Section>

      <Section title="4. Neler Silinir">
        <ul className="text-xs font-sans text-text leading-relaxed list-disc list-inside flex flex-col gap-1">
          <li>Hesabınız ve giriş bilgileriniz</li>
          <li>Ad, soyad, takma isim, e-posta, cinsiyet, doğum tarihi, profil fotoğrafı</li>
          <li>Oyun istatistikleriniz, k-lig puanınız ve oyun geçmişiniz</li>
          <li>Arkadaşlık bağlantılarınız ve gönderdiğiniz/aldığınız davetler</li>
          <li>Gönderdiğiniz oyun içi mesajlar ve geri bildirimler</li>
          <li>Devam eden oyun kayıtlarınız</li>
        </ul>
      </Section>

      <Section title="5. Neler Kalır">
        <P>
          Diğer oyuncuların bitmiş oyun kayıtları kendi verileridir ve silinmez. Bu kayıtlarda
          o oyundaki puanınız yer almaya devam eder, ancak adınız "Silinmiş oyuncu" olarak
          değiştirilir; bunun dışında hesabınıza ait hiçbir bilgi (e-posta, profil,
          istatistik) orada bulunmaz ve kayıt silinen hesabınızla eşleştirilemez.
        </P>
        <P>
          Kimliğinizle hiçbir şekilde ilişkilendirilmeyen anonim sayaçlar (ziyaret, oyun
          başlangıcı, hata kaydı) hesabınıza bağlı olmadıklarından bu kapsamın dışındadır —
          ayrıntı için <a href="/gizlilik/" className="text-accent font-mono hover:underline">Gizlilik Politikası</a>'nın
          6. bölümüne bakın.
        </P>
      </Section>
    </div>
  );
}

interface Sayfa {
  /** `dist` içindeki dosya yolu. */
  dosya: string;
  /** Sondaki eğik çizgiyle birlikte adres. */
  yol: string;
  baslik: string;
  aciklama: string;
  govde: () => React.ReactNode;
}

export const LEGAL_PAGES: Sayfa[] = [
  {
    dosya: 'gizlilik/index.html',
    yol: '/gizlilik/',
    baslik: 'Gizlilik Politikası',
    aciklama:
      'Kelimeki gizlilik politikası: hangi verileri topluyoruz, nasıl kullanıyoruz ve KVKK kapsamındaki haklarınız.',
    govde: () => <PrivacyBody contact={iletisim} />,
  },
  {
    dosya: 'kullanim-kosullari/index.html',
    yol: '/kullanim-kosullari/',
    baslik: 'Kullanım Koşulları',
    aciklama: 'Kelimeki kullanım koşulları: hizmetin kapsamı, hesap kuralları ve sorumluluk sınırları.',
    govde: () => <TermsBody contact={iletisim} />,
  },
  {
    dosya: 'hesap-silme/index.html',
    yol: '/hesap-silme/',
    baslik: 'Hesap ve Veri Silme',
    aciklama:
      'Kelimeki hesabınızın ve kişisel verilerinizin kalıcı olarak silinmesini nasıl talep edeceğinizi açıklar.',
    govde: () => <HesapSilmeBody />,
  },
];

function Kabuk({ sayfa }: { sayfa: Sayfa }) {
  return (
    <div className="min-h-full flex flex-col items-center px-4 py-6 gap-5">
      <a href="/" aria-label="Kelimeki ana sayfası" className="shrink-0">
        <LogoMark height={46} />
      </a>

      <main className="w-full max-w-[560px] bg-panel shadow-raised rounded-2xl px-4 py-5 flex flex-col gap-5">
        <h1 className="font-sans text-base font-bold text-text">{sayfa.baslik}</h1>
        {sayfa.govde()}
      </main>

      <footer className="flex flex-col items-center gap-3 pb-2">
        <nav className="flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-[10px] font-mono text-muted">
          {LEGAL_PAGES.filter((s) => s.yol !== sayfa.yol).map((s) => (
            <a key={s.yol} href={s.yol} className="hover:underline active:opacity-70">
              {s.baslik}
            </a>
          ))}
          <a href="/" className="hover:underline active:opacity-70">
            Kelimeki'ye dön
          </a>
        </nav>
        <span className="font-mono text-[10px] text-muted">© Kelimeki</span>
      </footer>
    </div>
  );
}

export function renderLegalPage(sayfa: Sayfa, cssHref: string): string {
  return `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${sayfa.baslik} — Kelimeki</title>
<meta name="description" content="${sayfa.aciklama}" />
<link rel="canonical" href="${SITE}${sayfa.yol}" />
<meta name="robots" content="index,follow" />
<link rel="icon" href="/favicon.svg" type="image/svg+xml" />
<link rel="stylesheet" href="${cssHref}" />
<style>html,body{height:auto;overflow:visible;position:static;background:#EEF1F5}</style>
</head>
<body>${renderToStaticMarkup(<Kabuk sayfa={sayfa} />)}</body>
</html>`;
}
