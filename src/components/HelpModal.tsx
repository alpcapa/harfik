// Harfik — nasıl oynanır / kurallar sayfası
import { Modal } from './Modal';

interface HelpModalProps {
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

const Pill = ({
  label,
  color,
  desc,
}: {
  label: string;
  color: string;
  desc: string;
}) => (
  <div className="flex items-center gap-2">
    <span
      className="shrink-0 w-8 h-6 rounded text-[10px] font-bold font-mono flex items-center justify-center text-white"
      style={{ background: color }}
    >
      {label}
    </span>
    <span className="text-xs font-sans text-text">{desc}</span>
  </div>
);

const TileRow = ({
  pts,
  tiles,
}: {
  pts: number | string;
  tiles: string;
}) => (
  <div className="flex items-start gap-2">
    <span className="shrink-0 w-8 text-right font-mono text-xs font-bold text-accent">
      {pts}
    </span>
    <span className="font-mono text-xs text-text leading-relaxed">{tiles}</span>
  </div>
);

export function HelpModal({ onClose }: HelpModalProps) {
  return (
    <Modal title="Nasıl Oynanır?" onClose={onClose}>
      <div className="flex flex-col gap-5">

        <Section title="Oyun Nedir?">
          <P>
            Harfik, 13×13'lük özel bir oyun tahtasında oynanan Türkçe kelime oyunudur. 2 veya 4
            oyuncu ile oynanır; oyuncular kendi köşelerinden başlayıp tahtanın ortasına doğru
            ilerlerken puan toplar.
          </P>
        </Section>

        <Section title="Temel Kurallar">
          <P>
            <strong>Başlangıç:</strong> Her oyuncu tahtanın bir köşesindeki 5×5'lik bölgeye
            sahiptir. Bu alanlar o kişinin özel koruma alanıdır ve bu alanın dışına temas etmeden
            diğer oyuncular buraya ekleme yapamaz. 2 kişilik oyunda çapraz köşeler (sol-üst ↔
            sağ-alt), 4 kişilik oyunda dört köşe kullanılır.
          </P>
          <P>
            <strong>İlk hamle:</strong> İlk kelimende en az bir harf kendi köşe bölgene
            düşmelidir. Koyduğun kelime bölgenin dışındaki alana taşarsa veya sınıra değerse
            hemen bir oyuncu buraya ekleme yapıp %50 daha fazla puan alabilir. O nedenle, mümkün
            oldukça ilk başlarda bölgenin sınırlarına yaklaşma. Böylece, her oyuncu kendi
            bölgesinde elindeki taşlarla maksimum puanı alıp sonra dışarıya doğru açılmalıdır.
          </P>
          <P>
            <strong>Bağlantı:</strong> Her hamle, oyun tahtasındaki mevcut harflere yatay ya da
            dikey olarak bağlanmalıdır. Harfler aynı satır veya aynı sütun üzerinde olmalıdır.
            Bölge sınırına değen taşlara diğer oyuncular bağlantı yapabilir, onun dışında
            rakibinin bölgesinde bağlantı yapılamaz.
          </P>
        </Section>

        <Section title="Köşe Bölgeleri">
          <P>
            Kendi köşen senin kalen gibidir. Sahibi olan kişi 5×5 alanın kenarına değen bir hamle
            yapana kadar kimse o bölgenin içinde bağlantı yapamaz. Rakip köşesine girebilmek için
            önce o köşenin sahibinin sınır çizgili alana değen bir hamle yapmış olması gerekir.
            Buna <em>sınır ihlali</em> denir.
          </P>
          <P>
            Sınır ihlal edilmeden diğer oyuncular orada oynayamaz. İhlal gerçekleştiği anda
            sınıra değen kelime üzerine istediğin gibi bağlantı yapabilirsin. Sınıra değen bir
            kelime olduğu sürece bölgenin içine doğru da hamle yapılabilir.
          </P>
          <P>
            <strong>Köşe bonusu:</strong> Rakip köşesine giren bir kelime için %50 ek puan
            kazanırsın.
          </P>
        </Section>

        <Section title="Bonus Kareler">
          <div className="flex flex-col gap-1.5 mt-0.5">
            <Pill label="3K" color="#DC2626" desc="Üç kat kelime puanı" />
            <Pill label="2K" color="#D97706" desc="İki kat kelime puanı" />
            <Pill label="3H" color="#2563EB" desc="Üç kat harf puanı" />
            <Pill label="2H" color="#16A34A" desc="İki kat harf puanı" />
          </div>
          <P>Bonuslar yalnızca o tura yeni konan taşa uygulanır.</P>
        </Section>

        <Section title="Hamle Seçenekleri">
          <P>
            <strong>Oyna:</strong> Harf kutusundan seçtiğin harfi oyun tahtasına koy, ardından
            "Oyna" düğmesine bas. Kelimenin geçerli olması gerekir.
          </P>
          <P>
            <strong>Değiştir:</strong> Harf kutusundan istediğin taşları torbaya geri at, yerine
            yeni taş çek. Sıran geçer. Torba boşken kullanılamaz.
          </P>
          <P>
            <strong>Pas Geç:</strong> Sıranı kullanmadan geç. Tüm oyuncular arka arkaya 2 tur
            pas geçerse oyun sona erer.
          </P>
          <P>
            <strong>Karıştır:</strong> Harf kutusundaki taşların sırasını karıştırır (puan
            değişmez).
          </P>
          <P>
            <strong>Geri Al:</strong> Bu turda oyun tahtasına koyduğun taşları harf kutusuna geri
            alır.
          </P>
          <P>
            <strong>Torba:</strong> Torbada kalan taş sayısını ve dışarıda kalan taşların
            dağılımını gösterir.
          </P>
        </Section>

        <Section title="Bingo Bonusu">
          <P>
            Harf kutusundaki 7 taşın tamamını tek hamlede kullanırsan{' '}
            <strong>+50 puan</strong> bonus kazanırsın.
          </P>
        </Section>

        <Section title="Joker (Yıldız) Taşı">
          <P>
            Torbada 4 adet joker vardır. Joker taşı, oynandığında istediğin herhangi bir Türkçe
            harfe dönüşebilir. Puan değeri <strong>0</strong>'dır; bonus kareler de jokere
            uygulanmaz.
          </P>
        </Section>

        <Section title="Sözlük">
          <P>
            Yalnızca Türkçe kelimeler geçerlidir. Her hamledeki tüm yeni kelimeler (ana kelime +
            yan oluşumlar) sözlükte bulunmalıdır.
          </P>
        </Section>

        <Section title="Oyunun Sonu">
          <P>
            Bir oyuncunun harf kutusu boşaldığında ve torbada taş kalmadığında oyun biter. Harf
            kutusunda taş kalan oyuncuların puanından o taşların toplam değeri düşülür.
          </P>
          <P>
            Tüm oyuncular arka arkaya 2 tur boyunca pas geçerse de oyun sona erer. En yüksek
            puana sahip oyuncu kazanır.
          </P>
        </Section>

        <Section title="Puan Tablosu">
          <P>Torbada toplam 186 taş bulunur.</P>
          <div className="flex flex-col gap-1 mt-0.5">
            <TileRow pts="1" tiles="A (×20)  E (×14)  İ (×13)  K (×13)  L (×13)  R (×11)  N (×9)  T (×9)" />
            <TileRow pts="2" tiles="I (×7)  M (×7)  O (×6)  S (×6)  U (×6)" />
            <TileRow pts="3" tiles="B (×4)  Ç (×4)  D (×4)  Ü (×4)  Y (×4)" />
            <TileRow pts="4" tiles="C (×4)  Ş (×4)  Z (×4)" />
            <TileRow pts="5" tiles="G (×2)  H (×2)  P (×2)" />
            <TileRow pts="7" tiles="F (×2)  Ö (×2)  V (×2)" />
            <TileRow pts="8" tiles="Ğ (×2)" />
            <TileRow pts="10" tiles="J (×2)" />
            <TileRow pts="0" tiles="? Joker (×4)" />
          </div>
        </Section>

      </div>
    </Modal>
  );
}
