// Kelimeki — herkese açık davet sayfası: /davet/:token
// Girişsiz de erişilebilir (get_friend_invite_info RPC'si) — henüz üye
// olmayan biri de linke tıklayıp burada kayıt olabilir. Bkz. boot.tsx'teki
// path kontrolü ve docs/decisions/friends.md.
//
// 25 Ağustos 2026 — SAYFA ZENGİNLEŞTİRİLDİ (kullanıcı isteği: "bu ekranı
// biraz daha zenginleştirelim"). Öncesinde sayfa logo + tek cümle + iki
// düğmeden ibaretti: telefonda ekranın alt üçte ikisi boştu ve linke tıklayan
// kişi (tanım gereği Kelimeki'yi HİÇ bilmeyen biri) "Kayıt Ol"a basmadan önce
// neye kayıt olduğunu gösteren tek bir şey göremiyordu. Eklenenler:
//   • Davet edenin baş harf avatarı (`Avatar`) — profil fotoğrafı YOK, çünkü
//     `get_friend_invite_info` yalnızca ADI dönüyor; fotoğrafı da döndürmek
//     bir migration + herkese açık bir uçtan foto sızdırma kararı demekti,
//     bu tur kapsam dışı bırakıldı (baş harf yedeği zaten `Avatar`'ın kendi
//     davranışı, ayrıca bir şey gerektirmiyor).
//   • Oyunun ne olduğunu ANLATAN bölüm: gerçek tanıtım tahtası + dört özellik.
//
// ⚠ TEK DÜĞME, TEK ETİKET (kullanıcı isteği, aynı gün ikinci tur: "Tek buton
// 'Daveti kabul et' olsun. Alttaki buton da aynı."). Öncesinde kartta yan yana
// "Giriş Yap"/"Kayıt Ol" ve altlarında iki blok açıklama vardı (bir ipucu
// cümlesi + "kabul edince ne olur" üç maddesi); hepsi kaldırıldı. Ziyaretçiye
// sorulan soru artık hesabının olup olmadığı DEĞİL, daveti kabul edip
// etmediği — hesap ayrımı zaten `AuthModal`'ın kendi işi ve orada iki yönlü
// geçiş linki var ("Zaten hesabın var mı? Giriş yap"), yani üye olan biri de
// tek düğmeden ilerleyebiliyor. Sayfanın altındaki CTA da AYNI etiketi
// taşıyor: iki düğme aynı şeyi yapıyorsa iki farklı ad taşımamalı.
//
// ⚠ TANITIM İÇERİĞİ KARŞILAMA KATMANIYLA TEK KAYNAK: tahta `landing/demoBoard.ts`
// (her kelimesi `npm run verify-demo-board` ile sözlüğe karşı doğrulanıyor),
// ikonlar `landing/OzellikIkonlari.tsx`. İkisi de saf/veri modülü — tarayıcı
// globali ya da hook taşımıyorlar, yani katmanın "sunucuda render edilir"
// kısıtını uygulama paketine taşımıyorlar. Buraya İKİNCİ bir tanıtım tahtası
// çizmek ya da ikonları kopyalamak bu kod tabanının en sık tekrarlayan hata
// sınıfı olurdu (bkz. CLAUDE.md). ÖLÇÜLDÜ (bu bölümün tamamının maliyeti,
// yalnız tahta/ikonlar değil): `dist/assets/boot-*.js` 800.94 → 808.77 KB ham,
// 228.50 → 230.98 KB gzip. Uygulama paketi zaten tek parça (bkz. boot.tsx),
// yani karşılama katmanını gören ziyaretçi bunu hiç indirmiyor.
//
// ⚠ KELİME SAYISI GİBİ RAKAMLAR BİLEREK YOK: `KELIME_SAYISI` sabiti
// `Landing.tsx`in içinde ve o dosyayı buraya import etmek TÜM karşılama
// katmanını (RankSeal, SSS, tüm bölümler) uygulama paketine sokardı. Rakamı
// elle yazmak ise üçüncü bir kopya demekti (ikincisi
// `scripts/sponsored-post/`). Bu yüzden metin sayı vermiyor.
import { useEffect, useState } from 'react';
import { LoadingNote } from './LoadingNote';
import { useAuth } from '../hooks/useAuth';
import { acceptFriendInvite, fetchFriendInviteInfo } from '../lib/api';
import { storePendingInviteToken, takePendingInviteToken } from '../utils/friendInvite';
import { LogoMark } from './LogoMark';
import { AuthModal } from './AuthModal';
import { Avatar } from './Avatar';
import { TermsModal } from './TermsModal';
import { PrivacyModal } from './PrivacyModal';
import { GameBoardPreview } from './GameBoardPreview';
import { CENTER_ZONE_STYLE, GOLD_ZONE_STYLE } from './Board';
import { DEMO_TILES_2 } from '../landing/demoBoard';
import { IkiKisiIkon, MadalyaIkon, RobotIkon, SohbetIkon } from '../landing/OzellikIkonlari';

interface FriendInvitePageProps {
  token: string;
}

type Status = 'loading' | 'invalid' | 'ready' | 'accepting' | 'accepted' | 'error';

const primaryBtn =
  'px-5 py-3 rounded-md bg-accent text-white font-mono font-bold text-sm tracking-[0.5px] shadow-raised active:scale-95 transition-transform';
const cardCls =
  'w-full bg-bg border border-border rounded-xl shadow-raised px-4 py-5 flex flex-col items-center gap-3 text-center';

/**
 * Tahtanın altındaki X2/X3 açıklaması — zeminler `Board.tsx`'ten BİREBİR
 * geliyor (bkz. oradaki not). Gerekli, çünkü tahta burada `compact`: hücrenin
 * üstünde "X2"/"X3" etiketi çizilmiyor, sarı/turuncu kareyi açıklayan başka
 * bir şey yok.
 */
function Rozet({ stil, metin }: { stil: React.CSSProperties; metin: string }) {
  return (
    <li className="flex shrink-0 items-center gap-1.5 text-[11px] leading-tight text-muted">
      <span aria-hidden="true" className="shrink-0 w-3.5 h-3.5 rounded-[3px]" style={stil} />
      <span>{metin}</span>
    </li>
  );
}

/** `Landing.tsx`'in "Neler var" kutusuyla aynı düzen — ikonlar da aynı kaynaktan. */
function Ozellik({
  ikon,
  baslik,
  metin,
}: {
  ikon: React.ReactNode;
  baslik: string;
  metin: string;
}) {
  return (
    <li className="bg-panel border border-border rounded-lg p-2.5 flex flex-col gap-1 text-left">
      <h3 className="text-[12px] font-bold leading-tight flex items-start gap-1.5 m-0">
        <span className="shrink-0 mt-[1px] text-accent">{ikon}</span>
        <span className="min-w-0">{baslik}</span>
      </h3>
      <p className="text-[11px] leading-relaxed text-muted m-0">{metin}</p>
    </li>
  );
}

export function FriendInvitePage({ token }: FriendInvitePageProps) {
  const { user, loading: authLoading } = useAuth();
  const [inviterName, setInviterName] = useState<string | null>(null);
  const [status, setStatus] = useState<Status>('loading');
  const [authMode, setAuthMode] = useState<'login' | 'signup' | null>(null);
  const [showTerms, setShowTerms] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);

  // Sayfaya her düşüşte token'ı sakla — e-posta doğrulaması açıkken bir
  // kayıt, doğrulama linkine tıklanana kadar burada oturum açmaz ve o link
  // genelde uygulamanın köküne döner; App.tsx bu kuyruğu oradan da işleyebilir.
  useEffect(() => {
    storePendingInviteToken(token);
  }, [token]);

  useEffect(() => {
    let cancelled = false;
    void fetchFriendInviteInfo(token).then((name) => {
      if (cancelled) return;
      if (!name) {
        setStatus('invalid');
      } else {
        setInviterName(name);
        setStatus('ready');
      }
    });
    return () => {
      cancelled = true;
    };
  }, [token]);

  // Kullanıcı bu sayfadayken girişli hale gelirse (zaten girişliyse ya da
  // AuthModal ile giriş/kayıt tamamlarsa) daveti hemen işle.
  useEffect(() => {
    if (authLoading || !user || status !== 'ready') return;
    setStatus('accepting');
    acceptFriendInvite(token)
      .then(() => {
        takePendingInviteToken(); // App.tsx bunu bir daha işlemeye çalışmasın
        setStatus('accepted');
      })
      .catch(() => setStatus('error'));
  }, [authLoading, user, status, token]);

  // Tanıtım bölümü yalnızca GİRİŞSİZ ziyaretçiye gösteriliyor: girişli biri
  // zaten üye, ona oyunu anlatmak gürültü olur (ve o kişi için sayfa bir
  // saniyelik bir ara duraktan ibaret — davet otomatik işleniyor).
  const showPitch = !user;

  return (
    <div className="min-h-screen bg-panel flex flex-col items-center px-4 py-8 gap-6">
      <a href="/" aria-label="Kelimeki anasayfa">
        <LogoMark height={44} />
      </a>

      <div className="w-full max-w-[380px] flex flex-col items-center gap-4">
        {/* ── Davet kartı ────────────────────────────────────────────── */}
        <section className={cardCls}>
          {status === 'loading' && <LoadingNote py="py-0" />}

          {status === 'invalid' && (
            <>
              <p className="text-muted text-xs font-mono leading-relaxed m-0">
                Bu davet linki geçersiz ya da artık kullanılamıyor.
              </p>
              <p className="text-muted text-[11px] leading-relaxed m-0">
                Seni davet eden kişiden yeni bir link isteyebilir ya da Kelimeki'ye doğrudan göz
                atabilirsin.
              </p>
              <a href="/" className={`${primaryBtn} inline-block`}>
                Kelimeki'ye Git
              </a>
            </>
          )}

          {(status === 'ready' || status === 'accepting') && (
            <>
              <p className="font-mono text-[10px] uppercase tracking-[1.5px] text-muted m-0">
                Arkadaşlık Daveti
              </p>
              <Avatar name={inviterName} size={56} />
              <h1 className="text-sm text-text font-mono font-normal leading-relaxed m-0">
                <span className="font-bold text-accent">{inviterName}</span> seni Kelimeki'de
                arkadaş eklemek istiyor.
              </h1>
              {user ? (
                <p className="text-xs text-muted font-mono m-0">İşleniyor…</p>
              ) : (
                <button onClick={() => setAuthMode('signup')} className={`${primaryBtn} w-full`}>
                  Daveti Kabul Et
                </button>
              )}
            </>
          )}

          {status === 'accepted' && (
            <>
              <Avatar name={inviterName} size={56} />
              <h1 className="text-sm text-text font-mono font-normal leading-relaxed m-0">
                <span className="font-bold text-accent">{inviterName}</span> ile artık arkadaşsınız!
              </h1>
              <p className="text-[11px] text-muted leading-relaxed m-0">
                Sıra oyunda: "Arkadaşınla" sekmesinden yeni bir oyun açıp ona davet gönderebilirsin.
              </p>
              <a href="/" className={`${primaryBtn} inline-block`}>
                Kelimeki'ye Git
              </a>
            </>
          )}

          {status === 'error' && (
            <>
              <p className="text-red text-xs font-mono leading-relaxed m-0">
                Davet kabul edilirken bir hata oluştu, lütfen tekrar dene.
              </p>
              {/* Önceden bu dal bir çıkmazdı: "tekrar dene" yazıyordu ama
                  tekrar denemenin tek yolu sayfayı yenilemekti. `ready`e
                  dönmek yukarıdaki effect'i yeniden tetikliyor. */}
              <button onClick={() => setStatus('ready')} className={primaryBtn}>
                Tekrar Dene
              </button>
            </>
          )}
        </section>

        {/* ── Kelimeki nedir ─────────────────────────────────────────── */}
        {showPitch && (
          <section className={`${cardCls} gap-4`}>
            <div className="flex flex-col gap-2">
              <h2 className="text-[13px] font-bold text-text m-0">Kelimeki nedir?</h2>
              <p className="text-[12px] leading-relaxed text-muted m-0">
                Türkçe bir kelime oyunu — ama tahtanın köşeleri oyunculara ait. Kendi köşenden
                başlar, oynadıkça bölgeni büyütürsün. Rakibin bölgesine oynamak serbesttir; ama
                kazandığın puanın bir kısmı bölge vergisi olarak ona geçer.
              </p>
            </div>

            {/* `role="img"` + `aria-label`: aksi halde 13×13 = 169 hücrenin
                her biri ekran okuyucuya tek tek harf çorbası olarak okunur —
                `Landing.tsx`'teki aynı sarmalayıcı deseni. `compact` (yani
                varsayılan) BİLEREK: burası dar bir kart, karşılama
                katmanındaki `compact={false}` tam-boy tahta bu genişlikte
                orantısız görünürdü (bkz. GameBoardPreview'ın notu). */}
            <div
              role="img"
              aria-label="Kelimeki tahtası örneği — köşelerden başlayıp merkeze uzanan, kelimelerle dolu 13×13 tahta"
              className="w-full"
            >
              <GameBoardPreview
                snapshot={DEMO_TILES_2}
                playerCount={2}
                players={[
                  { name: 'Sen', score: 0, is_ai: false, colorIndex: 0 },
                  { name: 'Rakip', score: 0, is_ai: false, colorIndex: 1 },
                ]}
              />
            </div>
            <ul className="flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5 list-none p-0 m-0">
              <Rozet stil={GOLD_ZONE_STYLE} metin="X2 — kelime puanının 2 katı" />
              <Rozet stil={CENTER_ZONE_STYLE} metin="X3 — 3 katı" />
            </ul>
            <p className="text-[11px] leading-relaxed text-muted m-0">
              Köşenden başla, bölgeni büyüt, ortadaki alana ulaşıp puanını ikiye hatta üçe katla.
            </p>

            <ul className="w-full grid grid-cols-2 gap-2 list-none p-0 m-0">
              <Ozellik
                ikon={<IkiKisiIkon />}
                baslik="Arkadaşınla oyna"
                metin="Oyun aç, davet gönder. Aynı anda çevrimiçi olmak şart değil."
              />
              <Ozellik
                ikon={<RobotIkon />}
                baslik="Yapay zekaya karşı"
                metin="Canlı rakip beklemeden, çevrimdışıyken bile oynayabilirsin."
              />
              <Ozellik
                ikon={<SohbetIkon />}
                baslik="Oyun içi sohbet"
                metin="Canlı oyunlarda masadan ayrılmadan yazışın."
              />
              <Ozellik
                ikon={<MadalyaIkon />}
                baslik="k-lig ve rütbeler"
                metin="Kazandıkça puan topla, eşikleri geçip rütbeni yükselt."
              />
            </ul>

            <p className="text-[11px] leading-relaxed text-muted m-0">
              Ücretsiz; reklam ya da oyun içi satın alma yok.
            </p>

            {status === 'ready' && (
              <button onClick={() => setAuthMode('signup')} className={`${primaryBtn} w-full`}>
                Daveti Kabul Et
              </button>
            )}
          </section>
        )}

        {/* ── Footer — Setup.tsx'in kendi footer'ıyla aynı iki katmanlı yapı
            (hukuki linkler + "© Kelimeki"). "Paylaş" BİLEREK yok: bu sayfaya
            gelen kişi henüz üye bile değil, davet edilen taraf. */}
        <div className="flex flex-col items-center gap-3 pt-1">
          <div className="flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-[10px] font-mono text-muted">
            <button
              onClick={() => setShowTerms(true)}
              className="flex items-center min-h-[48px] hover:underline active:opacity-70 transition-opacity"
            >
              Kullanım Koşulları
            </button>
            <span>·</span>
            <button
              onClick={() => setShowPrivacy(true)}
              className="flex items-center min-h-[48px] hover:underline active:opacity-70 transition-opacity"
            >
              Gizlilik Politikası
            </button>
          </div>
          <p className="font-mono text-[10px] text-muted m-0">© Kelimeki</p>
        </div>
      </div>

      {authMode && <AuthModal initialMode={authMode} onClose={() => setAuthMode(null)} />}
      {showTerms && <TermsModal onClose={() => setShowTerms(false)} />}
      {showPrivacy && <PrivacyModal onClose={() => setShowPrivacy(false)} />}
    </div>
  );
}
