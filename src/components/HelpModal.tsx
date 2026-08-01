// Kelimeki — nasıl oynanır / kurallar sayfası. İki adım: kısa "Hızlı Başlangıç"
// (varsayılan) ve altındaki linkle açılan "Detaylı Kurallar".
import { useState } from 'react';
import { Modal } from './Modal';
import { BINGO_BONUS } from '../game/constants';

interface HelpModalProps {
  onClose: () => void;
  initialStep?: 'quick' | 'detailed';
}

type Step = 'quick' | 'detailed';

const Section = ({ title, children }: { title: React.ReactNode; children: React.ReactNode }) => (
  <div className="flex flex-col gap-2">
    <h3 className="flex items-center font-mono text-[11px] uppercase tracking-[1.5px] text-accent border-b border-border pb-1">
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
  note,
}: {
  pts: number | string;
  tiles: [string, number][];
  note?: string;
}) => (
  <div className="flex items-start gap-2">
    <span className="shrink-0 whitespace-nowrap text-left font-mono text-xs font-bold text-accent">
      {pts} puan:
    </span>
    <span className="font-mono text-xs text-text leading-relaxed">
      {tiles.map(([letter, count], i) => (
        <span key={letter}>
          <strong>
            {letter === '★' ? (
              <span className="text-base leading-none relative -top-[2px]">★</span>
            ) : (
              letter
            )}
          </strong>
          (×{count})
          {i < tiles.length - 1 ? '  ' : ''}
        </span>
      ))}
      {note}
    </span>
  </div>
);

const QuickItem = ({ icon, children }: { icon: string; children: React.ReactNode }) => (
  <div className="flex items-start gap-2.5">
    <span
      className="shrink-0 w-7 h-7 rounded-full bg-accent/10 flex items-center justify-center text-sm"
      aria-hidden
    >
      {icon}
    </span>
    <span className="text-xs font-sans text-text leading-relaxed pt-1.5">{children}</span>
  </div>
);

function QuickStart({ onDetailedClick }: { onDetailedClick: () => void }) {
  return (
    <div className="flex flex-col gap-2">
      <QuickItem icon="🎯">
        2 ya da 4 oyuncuyla, <strong>Yapay Zekâ</strong>'ya veya arkadaşlarına karşı oynanır.
      </QuickItem>
      <QuickItem icon="🏠">
        Kendi bölgenden başlar, tahtanın <strong>ortasına doğru</strong> bölgeni
        genişletirsin.
      </QuickItem>
      <QuickItem icon="🔗">
        Yeni kelimeler tahtadaki mevcut harflere (rakiplerinki dahil) bağlanmalıdır.
      </QuickItem>
      <QuickItem icon="💰">
        Rakip bölgesine değen/giren hamlede, <strong>bölge vergisi</strong> ödersin.
      </QuickItem>
      <QuickItem icon="✨">
        Ortadaki 5×5 bonus bölgesi puanlarını <strong>ikiye</strong>, <strong>üçe</strong>{' '}
        katlar.
      </QuickItem>
      <QuickItem icon="🎁">
        7 taşını tek hamlede koyarsan <strong>+{BINGO_BONUS} Bingo bonus</strong> kazanırsın.
      </QuickItem>
      <QuickItem icon="⭐">
        Joker (<span className="text-base leading-none align-middle">★</span>) istediğin
        harfe dönüşür, puan değeri 0'dır. Elindeki son taş(lar)
        jokerse ve onunla bitirirsen <strong>+25/+50 bonus</strong> kazanırsın.
      </QuickItem>
      <QuickItem icon="📖">
        Sadece <strong>TDK sözlüğündeki</strong> Türkçe kelimeler geçerlidir.
      </QuickItem>
      <QuickItem icon="🏁">
        Harf kutunu bitirir ve torbada başka taş kalmazsa oyun biter. Art arda 2 tur pas
        geçilince de oyun biter.
      </QuickItem>
      <button
        onClick={onDetailedClick}
        className="self-start mt-1 font-mono text-[10px] uppercase tracking-[1px] text-accent active:opacity-70 transition-opacity"
      >
        Detaylı Kurallar →
      </button>
    </div>
  );
}

function DetailedRules() {
  return (
    <div className="flex flex-col gap-5">
      <Section title="Nasıl Oynanır?">
        <P>
          Kelimeki, Yapay Zekâ'ya veya arkadaşlarına karşı oynanan strateji odaklı bir kelime
          oyunudur. Her oyuncu
          kendi köşesinden başlar; kurduğu her kelimeyle puan toplar, bölgesini büyütür ve
          tahtanın merkezine doğru ilerleyerek üstünlük kurmaya çalışır.
        </P>
        <P>
          İlk hamle bölgenin köşesinden başlar ama ondan sonraki hamleler tahtanın dilediğin
          herhangi bir yerine yapılabilir. Ancak önemli bir kural var: Eğer yaptığın hamle
          başka bir oyuncunun bölgesine temas ederse, kazandığın puanın üçte birini o
          oyuncuyla paylaşırsın. Bu nedenle en iyi strateji, mümkün olduğunca kendi bölgeni
          büyütürken rakiplerinin genişlemesini zorlaştıracak hamleler yapmaktır. Oyuncuların
          kontrol ettiği bölgeler kalın çizgilerle gösterilir. Hamlen herhangi bir oyuncunun
          bölgesine temas etmiyorsa puan paylaşımı olmaz ve kazandığın puanın tamamı sana
          kalır.
        </P>
      </Section>

      <Section title="Temel Kurallar">
        <P>
          <strong>Başlangıç:</strong> Her oyuncu tahtanın köşelerindeki 4×4'lük bölgelere
          sahiptir. 2 kişilik oyunda 1. oyuncu sol-üst, 2. oyuncu sağ-alt köşeyi kullanır; 4
          kişilik oyunda her oyuncu tek bir köşe kullanır. Köşelerdeki ev işaretli kare, o
          oyuncunun başlangıç noktasıdır.
        </P>
        <P>
          <strong>Bağlantı:</strong> Her hamle, oyun tahtasındaki mevcut harflere (rakipler de
          dahil) yatay ya da dikey olarak bağlanmalıdır.
        </P>
      </Section>

      <Section title="Bölge Vergisi">
        <P>
          Her oyuncu 4×4'lük kendi köşesinden başlar ve kelimeleri bağladıkça bölgesini
          büyütür. Tahta üzerinde güncel bölgeler her oyuncunun kendi renginde kalın çizgiyle
          belirlenmiştir.
        </P>
        <P>
          İlk hamleden sonra rakibin bölgesine de taş koyabilirsin; ancak yerleştirdiğin
          harflerden herhangi biri rakibin bölgesine temas eder ya da içine yerleşirse, o
          hamleden kazandığın puanın 1/3'ü bölge sahibine gider, 2/3'ü sende kalır. Aynı hamle
          iki farklı rakip bölgesiyle birden etkileşirse puanın yarısı sende kalır, diğer
          yarısı rakipler arasında eşit paylaştırılır. 3 farklı bölge temasında ise 1/3 sende
          kalır, 2/3 diğer 3 rakiple eşit paylaşılır.
        </P>
        <P>
          Rakip bölgesine temas eden ama senin bölgene bağlı olmayan kelimeler sana vergi
          kazandırmaz. Ancak ilerleyen hamlelerde bu kelimeyi kendi bölgene bağlarsan artık
          bölgene dahil olur ve bundan sonra o kelime üzerinden vergi kazanmaya başlayabilirsin.
        </P>
      </Section>

      <Section title="Bonus Bölgesi">
        <div className="flex flex-col gap-1.5 mt-0.5">
          <Pill label="X2" color="#FBBF24" desc="En ortadaki 5×5 sarı alanda yapılan kelime puanı ikiye katlanır" />
          <Pill label="X3" color="#F97316" desc="Tam merkezdeki tek karede yapılan kelime puanı üçe katlanır" />
        </div>
        <P>
          X2 ve X3 bonusları yalnızca o kare ilk kez kullanıldığında geçerlidir; daha önce
          kullanılmış karelere yapılan bağlantılar bonus kazandırmaz. X2 bölgesi içinde olmasına
          rağmen, X3 hücresi kullanıldığında ayrıca X2 eklenmez.
        </P>
      </Section>

      <Section title="Hamle Seçenekleri">
        <P>
          <strong>Oyna:</strong> Harf kutundan seçtiğin harfleri oyun tahtasına koy, kelimelerin
          geçerli olup olmadığını gör ve ardından "Oyna" düğmesine bas.
        </P>
        <P>
          <strong>Değiştir:</strong> Harf kutundan istediğin taşları torbaya geri at, yerine
          yeni taş çek. Sıran sonraki oyuncuya geçer. Torba boşken değiştirme pasif olur.
        </P>
        <P>
          <strong>Pas Geç:</strong> Sıranı kullanmadan pas geçmeni sağlar. Tüm oyuncular arka
          arkaya 2 tur pas geçerse oyun sona erer.
        </P>
        <P>
          <strong>Karıştır:</strong> Harf kutundaki taşların yerlerini değiştirerek kelime
          bulmanı kolaylaştırır.
        </P>
        <P>
          <strong>Geri Al:</strong> Oyun tahtasına koyup deneme yaptığın taşları kutuya geri
          alır.
        </P>
        <P>
          <strong>Torba:</strong> Torbada kalan taş sayısını ve dışarıda kalan taşların
          dağılımını gösterir.
        </P>
      </Section>

      <Section title="Bingo Bonusu">
        <P>
          Harf kutundaki 7 taşın tamamını tek hamlede kullanırsan{' '}
          <strong>+{BINGO_BONUS} puan</strong> bonus kazanırsın.
        </P>
      </Section>

      <Section
        title={
          <>
            Joker (
            <span className="relative top-[-2px] text-[16px] normal-case tracking-normal leading-none">★</span>
            ) Taşı
          </>
        }
      >
        <P>
          Torbada 2 adet joker bulunur. Joker taşı oynandığında istediğin herhangi bir Türkçe
          harfe dönüşebilir ve puan değeri <strong>0</strong>'dır.
        </P>
        <P>
          Oyun sonunda elinde kalan son taş joker ise ve onu yerleştirerek bitersen{' '}
          <strong>+25 yıldız bonus</strong> puan kazanırsın. 2 joker taş ile bitiş ise{' '}
          <strong>+50 puan</strong> kazandırır. Becerebilirsen jokerlerini en sona taşa bırak,
          bonusu kap.
        </P>
      </Section>

      <Section title="Sözlük">
        <P>
          Yalnızca Türkçe kelimeler geçerlidir ve sadece Türk Dil Kurumu (TDK) sözlüğünde yer
          alan kelimeler bulunur. TDK sözlüğünde olmayan ama bulmacalarda sık kullanılan bazı
          kelimeler eklenmiştir.
        </P>
      </Section>

      <Section title="Oyunun Sonu">
        <P>
          Bir oyuncu harf kutusundaki tüm harfleri yerleştirdiğinde ve torbada başka taş
          kalmadığında oyun biter. Oyun bittiğinde harf kutusunda taş kalan oyuncuların
          puanından o taşların toplam değeri düşülür. Ancak bu puanlar bitiren oyuncuya
          eklenmez.
        </P>
        <P>
          Tüm oyuncular arka arkaya 2 tur boyunca pas geçerse de oyun sona erer. Bu durumda da
          tüm oyuncuların puanından elinde kalan taşların değeri düşer. En yüksek puana sahip
          oyuncu kazanır.
        </P>
      </Section>

      <Section title="Skor Kartı ve Puanlama">
        <P>
          Oyun oynamak için giriş yapman gerekmez. Sadece oyun istatistikleri ve k-lig için
          giriş yapman gerekir. Giriş yapmış kullanıcıların oyun sonuçları Skor Kartı'na
          kaydedilir. Oyun içi puanının yanında, sıralamana göre bir k-lig puanı da
          kazanırsın. 4 kişilik oyunda birinci bitirirsen <strong>+2</strong>, ikinci
          bitirirsen <strong>+1</strong> puan alırsın; üçüncü ve dördüncü puan almaz. 2 kişilik
          oyunda ise sadece birinci <strong>+2</strong> puan alır; ikinci puan almaz.
          Beraberlikte aynı sırayı paylaşan oyuncuların hepsi o sıranın puanını alır.
        </P>
      </Section>

      <Section title="Puan Tablosu">
        <P>
          Torbada oyuncu sayısından bağımsız olarak sabit toplam 100 taş bulunur. Aşağıdaki
          döküm bu değere göredir.
        </P>
        <div className="flex flex-col gap-1 mt-0.5">
          <TileRow
            pts="1"
            tiles={[
              ['A', 12],
              ['E', 8],
              ['İ', 7],
              ['K', 7],
              ['L', 7],
              ['R', 6],
              ['N', 5],
              ['T', 5],
            ]}
          />
          <TileRow
            pts="2"
            tiles={[
              ['I', 4],
              ['M', 4],
              ['O', 3],
              ['S', 3],
              ['U', 3],
            ]}
          />
          <TileRow
            pts="3"
            tiles={[
              ['B', 2],
              ['Ç', 2],
              ['D', 2],
              ['Ü', 2],
              ['Y', 2],
            ]}
          />
          <TileRow
            pts="4"
            tiles={[
              ['C', 2],
              ['Ş', 2],
              ['Z', 2],
            ]}
          />
          <TileRow
            pts="5"
            tiles={[
              ['G', 1],
              ['H', 1],
              ['P', 1],
            ]}
          />
          <TileRow
            pts="7"
            tiles={[
              ['F', 1],
              ['Ö', 1],
              ['V', 1],
            ]}
          />
          <TileRow pts="8" tiles={[['Ğ', 1]]} />
          <TileRow pts="10" tiles={[['J', 1]]} />
          <TileRow pts="0" tiles={[['★', 2]]} note=" Joker" />
        </div>
      </Section>
    </div>
  );
}

export function HelpModal({ onClose, initialStep = 'quick' }: HelpModalProps) {
  const [step, setStep] = useState<Step>(initialStep);

  return (
    <Modal
      title={step === 'quick' ? 'Hızlı Başlangıç' : 'Detaylı Kurallar'}
      onClose={onClose}
      headerLink={
        <button
          onClick={() => setStep(step === 'quick' ? 'detailed' : 'quick')}
          className="self-start font-mono text-[10px] uppercase tracking-[1px] text-accent active:opacity-70 transition-opacity"
        >
          {step === 'quick' ? 'Detaylı Kurallar →' : 'Hızlı Başlangıç →'}
        </button>
      }
    >
      {step === 'quick' ? (
        <QuickStart onDetailedClick={() => setStep('detailed')} />
      ) : (
        <DetailedRules />
      )}
    </Modal>
  );
}
