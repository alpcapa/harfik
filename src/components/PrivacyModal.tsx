import { useState } from 'react';
import { Modal } from './Modal';
import { FeedbackModal } from './FeedbackModal';

interface PrivacyModalProps {
  onClose: () => void;
}

const Section = ({ title, children }: { title: string; children: React.ReactNode }) => (
  <div className="flex flex-col gap-2">
    <h3 className="font-mono text-[11px] uppercase tracking-[1.5px] text-accent border-b border-border pb-1">
      {title}
    </h3>
    {children}
  </div>
);

const P = ({ children }: { children: React.ReactNode }) => (
  <p className="text-xs font-sans text-text leading-relaxed">{children}</p>
);

export function PrivacyModal({ onClose }: PrivacyModalProps) {
  const [showFeedback, setShowFeedback] = useState(false);

  return (
    <>
    <Modal title="Gizlilik Politikası" onClose={onClose}>
      <div className="flex flex-col gap-5">
        <P>
          Kelimeki olarak gizliliğinize önem veriyoruz. Bu politika, hangi verileri topladığımızı,
          nasıl kullandığımızı ve haklarınızı açıklar. Son güncelleme: 2 Ağustos 2026.
        </P>

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
            <li>Takma isim (isteğe bağlı)</li>
            <li>Cinsiyet (isteğe bağlı)</li>
            <li>Doğum tarihi (isteğe bağlı)</li>
            <li>Profil fotoğrafı (isteğe bağlı)</li>
            <li>Pazarlama iletişimi onayı ve onay tarihi (isteğe bağlı)</li>
            <li>
              Arkadaşlık isteği, oyun daveti ve süre uyarısı gibi işlemsel e-posta
              bildirimlerini alma tercihi
            </li>
            <li>Oyun istatistikleri (oynanan oyunlar, kazanma/kaybetme, puan geçmişi)</li>
            <li>
              Arkadaşlık bağlantıları (kiminle arkadaş olduğunuz, gönderdiğiniz/aldığınız
              arkadaşlık istekleri, davet linkinizin kullanım verisi)
            </li>
            <li>Canlı oyunlarda gönderdiğiniz oyun içi sohbet mesajları</li>
            <li>
              Bir Canlı oyunda kimleri sessize aldığınız ve gönderdiğiniz uygunsuz paylaşım
              şikayetleri (şikayetin nedeni dahil)
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
              Bir arkadaşlık isteği ya da Canlı oyun daveti aldığınızda size e-posta ile bildirim
              gönderilmesi — bu, hizmetin işleyişine dair işlemsel bir bildirimdir, pazarlama onayı
              gerektirmez ve pazarlama onayınızdan bağımsız olarak gönderilir
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
            istediğiniz zaman verebilir ya da geri çekebilirsiniz. Altyapı hizmeti olarak Supabase
            kullanılmaktadır; bu kapsamda veriler
            Supabase'in sunucularında saklanır ve bu sunucular yurt dışında bulunabilir. Böyle bir
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
            zamanlı olarak görünür ve oyun bittikten sonra oyun kaydının bir parçası olarak
            (mevcut skor/tahta görünürlüğüyle aynı şekilde, tüm kayıtlı kullanıcılara açık)
            saklanır.
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
            Verileriniz hesabınız aktif olduğu sürece saklanır. Hesabınızı silmeniz durumunda
            tüm kişisel verileriniz 30 gün içinde kalıcı olarak silinir.
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
            Girişsiz (misafir) ziyaretlerde, kaç benzersiz ziyaretçimiz olduğunu anlayabilmek
            için cihazınızda rastgele, kimliğinizle hiçbir şekilde ilişkilendirilmeyen anonim bir
            kod üretilir; bu kodla birlikte yalnızca kaba cihaz tipi (mobil/masaüstü) ve varsa bir
            paylaşım linkindeki kaynak etiketi sunucuya iletilir — bu veri hiçbir üçüncü tarafla
            paylaşılmaz ve hesabınızla asla eşleştirilmez. Yazı tipleri de dahil tüm statik
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
            <button
              type="button"
              onClick={() => setShowFeedback(true)}
              className="text-accent font-mono hover:underline"
            >
              Görüş Bildir formu
            </button>{' '}
            üzerinden başvurabilirsiniz. Başvurunuz niteliğine göre en geç 30 gün içinde ücretsiz
            olarak sonuçlandırılır. Başvurunuzun reddedilmesi, yetersiz bulunması veya süresinde
            cevap verilmemesi halinde Kişisel Verileri Koruma Kurulu'na şikayette bulunma
            hakkınız bulunmaktadır.
          </P>
        </Section>
      </div>
    </Modal>
    {showFeedback && <FeedbackModal onClose={() => setShowFeedback(false)} source="general" />}
    </>
  );
}
