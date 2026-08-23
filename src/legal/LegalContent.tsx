// Hukuki metinlerin TEK KAYNAĞI.
//
// NEDEN AYRI DOSYA (23 Ağustos 2026): bu metinler artık İKİ yerde
// gösteriliyor — uygulama içindeki pencereler (`PrivacyModal`/`TermsModal`)
// ve derleme zamanında üretilen statik sayfalar (`/gizlilik/`,
// `/kullanim-kosullari/`). Play'in Data safety formu doğrudan açılan bir
// URL istiyor ve o form kapalı test kanalı için de zorunlu.
//
// **Metin KOPYALANMAZ.** Kopyalansaydı, portun `legal_modals.dart`'ıyla
// birlikte ÜÇ kopya olurdu ve `legal_text_test.dart` yalnızca "Son
// güncelleme" TARİHLERİNİ karşılaştırıyor, metnin kendisini DEĞİL — yani
// ayrışma sessiz kalırdı.
//
// İki tüketici arasındaki TEK fark iletişim bağlantısı: pencere içinde
// `FeedbackModal`'ı açan bir `<button>`, statik sayfada `/?contact=1`'e
// giden bir `<a>`. Bu yüzden `contact` bir prop — metnin geri kalanı ortak.
import type { ReactNode } from 'react';

/**
 * Silme talebinin sonuçlandırılma süresi (gün).
 *
 * İKİ yerde geçiyor — Gizlilik Politikası'nın "Veri Saklama Süresi" bölümü ve
 * `/hesap-silme/` sayfası — bu yüzden sabit. Sayıyı iki yere ayrı ayrı yazmak,
 * biri güncellenince ötekinin sessizce yanlış kalması demekti; üstelik ikincisi
 * Play'in Data safety formuna verilen URL, yani yanlış kalması pahalı.
 */
export const SILME_SURESI_GUN = 30;

export const Section = ({ title, children }: { title: string; children: ReactNode }) => (
  <div className="flex flex-col gap-2">
    <h3 className="font-mono text-[11px] uppercase tracking-[1.5px] text-accent border-b border-border pb-1">
      {title}
    </h3>
    {children}
  </div>
);

export const P = ({ children }: { children: ReactNode }) => (
  <p className="text-xs font-sans text-text leading-relaxed">{children}</p>
);

export function PrivacyBody({ contact }: { contact: ReactNode }) {
  return (
      <div className="flex flex-col gap-5">
        <P>
          Kelimeki olarak gizliliğinize önem veriyoruz. Bu politika, hangi verileri topladığımızı,
          nasıl kullandığımızı ve haklarınızı açıklar. Son güncelleme: 21 Ağustos 2026</P>

        <Section title="1. Veri Sorumlusu">
          <P>
            Kelimeki, herhangi bir şirket ya da tüzel kişilik bulunmaksızın, bağımsız bir geliştirici
            tarafından bireysel olarak geliştirilmekte ve işletilmektedir; faaliyet merkezi
            Sarıyer, İstanbul'dur. 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") anlamında
            veri sorumlusu bu bireysel geliştiricidir ve işbu politikada "Kelimeki" bu kapsamda
            anılmaktadır. Talep ve başvurularınız için 8. bölümdeki iletişim kanalını
            kullanabilirsiniz.
          </P>
        </Section>

        <Section title="2. Toplanan Veriler">
          <P>Hesap oluştururken şu bilgileri topluyoruz:</P>
          <ul className="text-xs font-sans text-text leading-relaxed list-disc list-inside flex flex-col gap-1">
            <li>Ad ve soyad</li>
            <li>E-posta adresi</li>
            <li>Takma isim (zorunlu — oyunlarda ve k-lig'de herkese görünür)</li>
            <li>Cinsiyet (isteğe bağlı)</li>
            <li>Doğum tarihi (isteğe bağlı)</li>
            <li>Profil fotoğrafı (isteğe bağlı)</li>
            <li>Pazarlama iletişimi onayı ve onay tarihi (isteğe bağlı)</li>
            <li>
              Hoş geldiniz mesajı, arkadaşlık isteği, oyun daveti ve süre uyarısı gibi işlemsel
              e-posta bildirimlerini alma tercihi
            </li>
            <li>Oyun istatistikleri (oynanan oyunlar, kazanma/kaybetme, puan geçmişi)</li>
            <li>
              Arkadaşlık bağlantıları (kiminle arkadaş olduğunuz, gönderdiğiniz/aldığınız
              arkadaşlık istekleri, davet linkinizin kullanım verisi)
            </li>
            <li>Canlı oyunlarda gönderdiğiniz oyun içi sohbet mesajları</li>
            <li>
              "Görüş Bildir" formundan ilettiğiniz mesajlar ve size yanıt verebilmemiz için
              formda belirttiğiniz e-posta adresi — girişsiz (misafir) gönderdiğinizde de
              saklanır
            </li>
            <li>
              Bir Canlı oyunda kimleri sessize aldığınız ve gönderdiğiniz uygunsuz paylaşım
              şikayetleri (şikayetin nedeni dahil)
            </li>
            <li>
              Bir oyunu hangi istemciden oynadığınız (web sitesi ya da mobil uygulama) — yalnızca
              hangi platformun ne kadar kullanıldığını ölçmek için; cihaz kimliği, marka/model ya
              da işletim sistemi sürümü gibi hiçbir ek bilgi toplanmaz
            </li>
            <li>
              Siteye ilk gelişinizde kullandığınız tanıtım bağlantısının kaynak etiketi (ör.
              bir sosyal medya paylaşımı) — yalnızca hangi kanalın ne kadar üye getirdiğini
              ölçmek için, hesabınıza kayıt anında tek seferlik yazılır ve sonradan değişmez.
              Bağlantı yoksa "direkt" olarak kaydedilir. Bu etiket, aşağıda anlatılan anonim
              ziyaretçi sayacındaki kayıtlarla EŞLEŞTİRİLMEZ
            </li>
          </ul>
        </Section>

        <Section title="3. Verilerin Kullanım Amacı ve Hukuki Sebebi">
          <P>
            Verileriniz, hesap oluştururken verdiğiniz açık rızanıza (KVKK m.5/1) ve hizmetin
            sunulabilmesi için sözleşmenin kurulması/ifasına (KVKK m.5/2-c) dayanılarak, yalnızca
            şu amaçlarla işlenir:
          </P>
          <ul className="text-xs font-sans text-text leading-relaxed list-disc list-inside flex flex-col gap-1">
            <li>Hesap oluşturma ve kimlik doğrulama</li>
            <li>Lider tablosu ve skor kartı gösterimi</li>
            <li>Oyun deneyiminin kişiselleştirilmesi</li>
            <li>Hesap güvenliği ve destek hizmetleri</li>
            <li>
              Üyeliğiniz başladığında bir hoş geldiniz e-postası; bir arkadaşlık isteği ya da Canlı
              oyun daveti aldığınızda size e-posta ile bildirim gönderilmesi — bunlar hizmetin
              işleyişine dair işlemsel bildirimlerdir, pazarlama onayı gerektirmez ve pazarlama
              onayınızdan bağımsız olarak gönderilir
            </li>
            <li>Yalnızca ayrıca onay verdiyseniz: pazarlama/tanıtım amaçlı iletişim</li>
          </ul>
        </Section>

        <Section title="4. Veri Paylaşımı ve Aktarım">
          <P>
            Kişisel verileriniz üçüncü taraflara satış amacıyla kullanılmaz. Kayıt formundaki
            "Pazarlama iletişimi almayı kabul ediyorum" kutusunu işaretlerseniz, size pazarlama/
            tanıtım amaçlı iletişim gönderilebilir — bu kutu isteğe bağlıdır, işaretlemeseniz de
            hizmeti eksiksiz kullanabilirsiniz; bu onayı Hesap Ayarları'ndaki aynı onay kutusundan
            istediğiniz zaman verebilir ya da geri çekebilirsiniz. Hizmetin sunulabilmesi için üç
            altyapı sağlayıcısından yararlanılır: veritabanı, kimlik doğrulama ve dosya
            saklama için <strong>Supabase</strong>; e-posta bildirimlerinin (kayıt onayı, şifre
            sıfırlama, arkadaşlık/oyun daveti, süre uyarısı, destek yanıtı) gönderilmesi için
            <strong>Brevo</strong> — bu kapsamda yalnızca adınız/takma isminiz ve e-posta
            adresiniz iletilir; sitenin ve uygulamanın yayınlanması için <strong>Vercel</strong>.
            Bu sağlayıcıların sunucuları yurt dışında bulunabilir. Böyle bir
            durumda aktarım, KVKK m.9'da aranan (yeterli korumanın bulunduğu ülke veya uygun
            güvencelerin sağlanması gibi) şartlara uygun şekilde yapılır. Yasal zorunluluk halinde
            yetkili makamlarla paylaşım yapılabilir.
          </P>
          <P>
            Bunun yanında, adınız/takma isminiz, profil fotoğrafınız ve oyun istatistikleriniz
            k-lig (lider tablosu) ve arkadaşlık arama özelliği aracılığıyla diğer KAYITLI
            kullanıcılara görünür olur; e-posta adresiniz hiçbir zaman başka bir kullanıcıya
            gösterilmez. Bir oyunu paylaşmayı seçerseniz, o oyunun tahtası ve oyuncu
            isimleri/puanları giriş yapmamış ziyaretçiler dahil herkese açık bir bağlantı
            üzerinden görülebilir hale gelir; bu paylaşım geri alınamaz. Canlı oyunlarda
            gönderdiğiniz oyun içi sohbet mesajları o oyundaki diğer katılımcılara gerçek
            zamanlı olarak görünür ve oyun bittikten sonra da saklanır; bu yazışmalar
            YALNIZCA o oyunun katılımcılarına ve (şikayet incelemesi amacıyla) yönetici
            ekibine açıktır — oyunun skoru ve tahtası tüm kayıtlı kullanıcılara görünür
            olsa bile sohbet içeriği görünmez.
          </P>
          <P>
            Bir Canlı oyunda kimi sessize aldığınız yalnızca size görünür, diğer katılımcılar
            (sessize alınan kişi dahil) bunu hiçbir zaman göremez. Gönderdiğiniz uygunsuz
            paylaşım şikayetleri yalnızca inceleme amacıyla yönetici ekibiyle paylaşılır;
            şikayet edilen kullanıcıya şikayet edildiği, kimin şikayet ettiği ya da şikayetin içeriği
            hiçbir şekilde bildirilmez.
          </P>
        </Section>

        <Section title="5. Veri Saklama Süresi">
          <P>
            Verileriniz hesabınız aktif olduğu sürece saklanır. Uygulama içinde kendi kendine
            hesap silme özelliği bulunmuyor; hesabınızın ve kişisel verilerinizin
            silinmesini istiyorsanız 8. bölümdeki "Görüş Bildir" kanalından talep
            edebilirsiniz. Talebiniz üzerine tüm kişisel verileriniz en geç {SILME_SURESI_GUN} gün
            içinde kalıcı olarak silinir.
          </P>
        </Section>

        <Section title="6. Çerezler ve Yerel Depolama">
          <P>
            Kelimeki, HTTP çerezi (cookie) kullanmaz. Bunun yerine oturumunuzu açık tutmak, oyun
            ilerlemenizi kaydetmek ve tercihlerinizi hatırlamak için tarayıcınızın yerel depolama
            alanı (localStorage/sessionStorage) kullanılır; bu veriler cihazınızda tutulur ve
            sunucularımıza otomatik gönderilmez. İstisna: misafir (girişsiz) oynadığınız bir
            oyunun sonucu, bağlantı yoksa ya da henüz hesabınız yoksa geçici olarak bu yerel
            depoda bekletilir; aynı cihazda daha sonra giriş yapar ya da kayıt olursanız bu
            bekleyen sonuçlar otomatik olarak hesabınıza aktarılıp sunucuya gönderilir. Reklam
            veya pazarlama amaçlı herhangi bir çerez ya da izleme teknolojisi kullanılmamaktadır.
            Kaç benzersiz ziyaretçimiz olduğunu ve kaç kişinin oyuna başladığını anlayabilmek
            için cihazınızda rastgele, kimliğinizle hiçbir şekilde ilişkilendirilmeyen anonim bir
            kod üretilir. Bu kod iki durumda sunucuya iletilir: girişsiz (misafir) ziyaretlerde
            kaba cihaz tipiyle (mobil/masaüstü) birlikte, ve yapay zekaya karşı bir oyun
            başlattığınızda oyuncu sayısıyla birlikte — ikisinde de varsa bir paylaşım
            linkindeki kaynak etiketi eklenir. Üçüncü bir durum, uygulamada beklenmedik bir
            hata oluşmasıdır: hatayı bulup düzeltebilmemiz için hatanın teknik açıklaması,
            oluştuğu yerin teknik izi, kullandığınız sürüm ve platform (web/uygulama) aynı
            anonim kodla birlikte kaydedilir. Bu kayıtlar hesabınıza bağlanmaz ve yalnızca
            arıza gidermek için tutulur; bulunduğunuz sayfanın adresi kaydedilirken davet
            bağlantısı gibi kişiye özel kısımlar temizlenir. Teknik hata açıklamaları çok
            nadiren yazdığınız bir metin parçasını içerebilir. Oyun başlangıcı kaydı giriş
            yapmış olsanız da tutulur, ancak bu kayıtların hiçbirinde hesap kimliğiniz YER
            ALMAZ: bu veriler hiçbir üçüncü tarafla paylaşılmaz ve hesabınızla asla
            eşleştirilmez. Yazı tipleri de dahil tüm statik
            içerikler kendi sunucularımızdan sağlanır; üçüncü taraf (ör. Google Fonts) çağrısı
            yapılmaz.
          </P>
        </Section>

        <Section title="7. KVKK Kapsamındaki Haklarınız">
          <P>KVKK m.11 uyarınca aşağıdaki haklara sahipsiniz:</P>
          <ul className="text-xs font-sans text-text leading-relaxed list-disc list-inside flex flex-col gap-1">
            <li>Kişisel verilerinizin işlenip işlenmediğini öğrenme</li>
            <li>İşlenmişse buna ilişkin bilgi talep etme</li>
            <li>İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme</li>
            <li>Yurt içinde/yurt dışında aktarıldığı üçüncü kişileri bilme</li>
            <li>Eksik veya yanlış işlenmişse düzeltilmesini isteme</li>
            <li>Silinmesini veya yok edilmesini talep etme</li>
            <li>Düzeltme/silme işlemlerinin verilerin aktarıldığı üçüncü kişilere bildirilmesini isteme</li>
            <li>Otomatik sistemlerle analiz edilmesi sonucu aleyhinize çıkan bir sonuca itiraz etme</li>
            <li>Kanuna aykırı işleme nedeniyle uğradığınız zararın giderilmesini talep etme</li>
          </ul>
        </Section>

        <Section title="8. Başvuru Usulü ve Kurul'a Şikayet Hakkı">
          <P>
            Yukarıdaki haklarınızı kullanmak için{' '}
            {contact}{' '}
            üzerinden başvurabilirsiniz. Başvurunuz niteliğine göre en geç {SILME_SURESI_GUN} gün içinde ücretsiz
            olarak sonuçlandırılır. Başvurunuzun reddedilmesi, yetersiz bulunması veya süresinde
            cevap verilmemesi halinde Kişisel Verileri Koruma Kurulu'na şikayette bulunma
            hakkınız bulunmaktadır.
          </P>
        </Section>
      </div>
  );
}

export function TermsBody({ contact }: { contact: ReactNode }) {
  return (
      <div className="flex flex-col gap-5">
        <P>
          Kelimeki'ye kaydolarak aşağıdaki koşulları okuduğunuzu ve kabul ettiğinizi beyan edersiniz.
          Son güncelleme: 19 Ağustos 2026.
        </P>

        <Section title="1. Hizmet Sağlayıcı ve Kapsam">
          <P>
            Kelimeki, herhangi bir şirket ya da tüzel kişilik bulunmaksızın, bağımsız bir geliştirici
            tarafından bireysel olarak geliştirilmekte ve işletilmektedir; faaliyet merkezi
            Sarıyer, İstanbul'dur. Hizmet, Türkçe kelimelerle oynanan çevrimiçi bir kelime
            oyunudur ve oyun tahtası, Yapay Zeka'ya karşı ya da arkadaşlarınla gerçek zamanlı
            oynanan Canlı oyun, oyun içi mesajlaşma, lider tablosu (k-lig), arkadaşlık ve
            kullanıcı hesabı özelliklerini kapsar. Hizmet ücretsizdir ve herhangi bir bildirimde bulunmaksızın değiştirilebilir
            ya da sonlandırılabilir.
          </P>
        </Section>

        <Section title="2. Hesap Sorumluluğu">
          <P>
            Kayıt sırasında verdiğiniz bilgilerin doğru ve güncel olması zorunludur. Hesap
            güvenliğinizden yalnızca siz sorumlusunuz; şifrenizi kimseyle paylaşmayınız. Hesabınızı
            başkasına devredemezsiniz.
          </P>
        </Section>

        <Section title="3. Kabul Edilemez Kullanım">
          <P>
            Aşağıdaki eylemler kesinlikle yasaktır:
          </P>
          <ul className="text-xs font-sans text-text leading-relaxed list-disc list-inside flex flex-col gap-1">
            <li>Otomatik araçlar veya botlar aracılığıyla oyun oynamak</li>
            <li>Diğer kullanıcıları rahatsız edecek içerik paylaşmak</li>
            <li>Sistemi manipüle etmeye veya güvenlik açıklarını istismar etmeye çalışmak</li>
            <li>Başkasının hesabına yetkisiz erişim sağlamaya çalışmak</li>
            <li>Arkadaşlık isteklerini veya davet linkini spam, taciz ya da istenmeyen toplu davet amacıyla kullanmak</li>
            <li>Oyun içi mesajlaşmayı taciz, spam, hukuka aykırı ya da uygunsuz içerik paylaşmak amacıyla kullanmak</li>
          </ul>
        </Section>

        <Section title="4. Hesap Askıya Alma">
          <P>
            Yukarıdaki kurallara aykırı davranış tespit edilmesi durumunda hesabınız önceden
            bildirim yapılmaksızın askıya alınabilir veya silinebilir.
          </P>
        </Section>

        <Section title="5. Sorumluluk Sınırlaması">
          <P>
            Kelimeki, hizmet kesintileri, veri kayıpları veya üçüncü taraf hizmetlerinden
            kaynaklanan zararlardan sorumlu değildir. Hizmet "olduğu gibi" sunulmaktadır.
          </P>
          <P>
            Oyun içi mesajlaşma özelliğiyle gönderilen mesajlar önceden denetlenmez (moderasyona
            tabi değildir); kullanıcılar arasında gönderilen mesajların içeriğinden Kelimeki hiçbir
            şekilde sorumlu tutulamaz, sorumluluk tamamen mesajı gönderen kullanıcıya aittir.
            Uygunsuz bir mesajla karşılaşan kullanıcılar, sohbet ekranındaki ayarlar üzerinden
            ilgili kişiyi sessize alabilir ve/veya yönetici ekibine şikayet edebilir.
          </P>
        </Section>

        <Section title="6. Değişiklikler">
          <P>
            Bu koşullar zaman zaman güncellenebilir. Değişiklikler yayımlandıktan sonra hizmeti
            kullanmaya devam etmeniz, güncel koşulları kabul ettiğiniz anlamına gelir.
          </P>
        </Section>

        <Section title="7. İletişim">
          <P>
            Sorularınız için:{' '}
            {contact}
          </P>
        </Section>
      </div>
  );
}
