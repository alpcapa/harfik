import { useState } from 'react';
import { Modal } from './Modal';
import { FeedbackModal } from './FeedbackModal';

interface TermsModalProps {
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

export function TermsModal({ onClose }: TermsModalProps) {
  const [showFeedback, setShowFeedback] = useState(false);

  return (
    <>
    <Modal title="Kullanım Koşulları" onClose={onClose}>
      <div className="flex flex-col gap-5">
        <P>
          Kelimeki'ye kaydolarak aşağıdaki koşulları okuduğunuzu ve kabul ettiğinizi beyan edersiniz.
          Son güncelleme: 31 Temmuz 2026.
        </P>

        <Section title="1. Hizmet Sağlayıcı ve Kapsam">
          <P>
            Kelimeki, herhangi bir şirket ya da tüzel kişilik bulunmaksızın, bağımsız bir geliştirici
            tarafından bireysel olarak geliştirilmekte ve işletilmektedir; faaliyet merkezi
            Sarıyer, İstanbul'dur. Hizmet, Türkçe kelimelerle oynanan çevrimiçi bir kelime
            oyunudur ve oyun tahtası, lider tablosu, arkadaşlık ve kullanıcı hesabı özelliklerini
            kapsar. Hizmet ücretsizdir ve herhangi bir bildirimde bulunmaksızın değiştirilebilir
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
            <button
              type="button"
              onClick={() => setShowFeedback(true)}
              className="text-accent font-mono hover:underline"
            >
              Görüş Bildir formu
            </button>
          </P>
        </Section>
      </div>
    </Modal>
    {showFeedback && <FeedbackModal onClose={() => setShowFeedback(false)} source="general" />}
    </>
  );
}
