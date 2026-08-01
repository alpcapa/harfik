// Kelimeki — başlık: skorlar ve hesap menüsü
import { PLAYER_COLORS } from '../game/constants';
import type { GameState } from '../game/types';
import { LogoMark } from './LogoMark';
import { UserMenu } from './UserMenu';

// Skor kutuları akıcı/duyarlı: dar ekranlarda küçülüp genişte tam boya
// çıkar, böylece 4 oyunculu + Giriş butonu neredeyse hiçbir zaman
// kaydırmaya ihtiyaç duymaz (eskiden sabit 84/56px'ti — bkz. git geçmişi).
// Her `clamp(min, calc(A + Bvw), max)` 375px'te (kullanıcıya onaylatılan
// örnek görselin baz alındığı genişlik) min'e, 465px'te max'e ulaşacak
// şekilde hesaplanmıştır. 465 kasıtlı olarak geniş tutuldu: ilk denemede
// 430 kullanılmıştı ama ölçünce içeriğin büyüme hızının (vw başına),
// header'da gerçekten açılan boş alanın büyüme hızından daha yüksek
// olduğu görüldü — yani 375-430 arasında açık kapanıp sonra tekrar
// açılıyordu. 465 bu eğimi gerçek açılan alanın eğiminin altında tutuyor,
// açık bir daha açılmıyor (375px ve üstünde ölçülüp doğrulandı). 375px'in
// altında (nadir/çok küçük telefonlar) clamp() min'in altına inmez, orada
// bir miktar kaydırma gerekebilir (kabul edildi, bkz. git geçmişi).
// Tailwind class'ı değil inline style kullanılıyor çünkü clamp()/calc()
// içindeki virgüller Tailwind'in arbitrary-value söz dizimiyle iyi
// geçinmiyor.
const PLAYER_BOX_WIDTH = 'clamp(51px, calc(-44.83px + 25.56vw), 74px)';
const YZ_BOX_WIDTH = 'clamp(33px, calc(-29.5px + 16.67vw), 48px)';
const LABEL_FONT_SIZE = 'clamp(6px, calc(-2.33px + 2.22vw), 8px)';
const SCORE_FONT_SIZE = 'clamp(13px, calc(-7.83px + 5.56vw), 18px)';
// 31 Temmuz 2026 — hem kutu genişliği hem yatay dolgu daraltıldı (kullanıcı
// geri bildirimi: isim/puan kenarlara çok uzak duruyordu). Aynı 375/465 uç
// noktalı sistemin içinde kalınarak eskisinin (6-8px) yaklaşık yarısına
// indirildi, sonra ikinci bir geri bildirimle bir kez daha (1.5-3.5px'e)
// daraltıldı.
const BOX_PADDING_X = 'clamp(1.5px, calc(-6.83px + 2.22vw), 3.5px)';
const BOX_GAP = 'clamp(6px, calc(-2.33px + 2.22vw), 8px)';
// Sabit py-0.5 (2px) kullanıldığında kutu, Giriş butonundan (UserMenu.tsx —
// kendi 1px kenarlığı + akıcı GIRIS_PADDING_Y'si var) 375px'te ~1.4px,
// 465px'te ~3px daha kısa kalıyordu (24 Temmuz 2026'da kullanıcı fotoğrafıyla
// fark edildi). Etiket satırının (leading-none OLMAYAN, puan satırının
// aksine) satır yüksekliği font boyutunun 1.5 katı olduğundan fark viewport
// büyüdükçe açılıyor. Bu akıcı dolgu, 375px ve 465px'te Giriş'in tam
// yüksekliğini (2px kenarlık + kendi dolgusu + yazı boyutu) verecek şekilde
// geri hesaplandı — aynı iki uç noktayı (375/465) kullanan diğer clamp'lerle
// tutarlı.
const BOX_PADDING_Y = 'clamp(2.7px, calc(-0.63px + 0.89vw), 3.5px)';
// Logo eskiden sabit 28px'ti — skor kutuları/Giriş 465px'te 37px'e kadar
// büyürken o hep aynı kaldığından geniş ekranlarda orantısı bozulup küçük
// kalıyordu (24 Temmuz 2026'da fark edildi). Aynı 375/465 uç noktalarını
// kullanan bir clamp'e bağlandı; LogoMark artık string bir height alınca
// (bkz. LogoMark.tsx/generate-logo-paths.mjs) SVG width/height attribute'u
// yerine CSS height + aspect-ratio kullanıyor.
const LOGO_HEIGHT = 'clamp(28px, calc(-5.33px + 8.89vw), 36px)';

interface GameHeaderProps {
  state: GameState;
  onLogoClick?: () => void;
  /** true iken çıkış devre dışı — ör. teslim olup YZ'leri izlerken oyundan
   *  çıkılamaz, oyunun bitmesi beklenmek zorunda. */
  exitDisabled?: boolean;
}

export function GameHeader({ state, onLogoClick, exitDisabled }: GameHeaderProps) {
  const { players, current } = state;
  return (
    <header className="w-full max-w-[680px] flex items-center justify-between gap-2 px-3 py-2.5 border-b border-border">
      <button
        onClick={onLogoClick}
        disabled={exitDisabled}
        className="shrink-0 flex flex-col items-center leading-none active:opacity-70 transition-opacity disabled:opacity-40 disabled:cursor-not-allowed disabled:active:opacity-40"
        aria-label="Oyundan çık">
        <LogoMark height={LOGO_HEIGHT} />
      </button>

      {/* Akıcı boyutlandırma 375px'te (bkz. yukarı) neredeyse tam sığdırsa
          da (logo/header dolgusu küçülmediğinden birkaç px'lik açık
          kalabiliyor) ve 375px altındaki nadir/çok küçük telefonlarda
          clamp() taban değerin altına inmediğinden orada kaydırma hâlâ
          gerekebilir (kabul edildi). Bu uç durum için
          min-w-0 + overflow-x-auto + no-scrollbar hâlâ güvenlik ağı
          olarak duruyor: sığmazsa header 2. satıra taşıp kutuları
          bozmak yerine şerit görünmez biçimde yatay kaydırılır.
          justify-end KULLANMA: taşan bir flex konteynerde justify-content:
          flex-end, taşan içeriği scrollWidth'e hiç yansımayan, kaydırarak
          bile ulaşılamayan bir şekilde kırpıyor (test edilip doğrulandı).
          justify-start (varsayılan) ile taşma her zaman erişilebilir kalır
          ve en önemli kutu (0. oyuncu/hesap sahibi) her zaman görünür.
          UserMenu bu kabın DIŞINDA (bkz. aşağı): overflow-x-auto,
          overflow-y'yi (CSS'in "visible" olmayan bir eksene sahip
          konteynerlerde diğer ekseni de 'auto' sayma kuralı yüzünden)
          fiilen 'auto' kılıp içindeki her şeyi dikeyde de kırpıyor —
          hesap menüsü dropdown'ı (top-full ile aşağı taşan, absolute
          konumlu) bu kabın içindeyken tamamen görünmez kırpılıyordu
          (tıklanınca açılıyordu ama hiç görünmüyordu, bkz. proje geçmişi). */}
      <div className="flex items-center min-w-0 gap-2">
        <div
          className="flex items-center min-w-0 overflow-x-auto no-scrollbar"
          style={{ gap: BOX_GAP }}
        >
          {players.map((p, i) => {
            const col = PLAYER_COLORS[p.colorIndex];
            const active = i === current;
            const label = p.isAI ? `YZ ${i + 1}` : p.name;
            return (
              <div
                key={i}
                className="shrink-0 text-center rounded-md transition-all"
                style={{
                  width: p.isAI ? YZ_BOX_WIDTH : PLAYER_BOX_WIDTH,
                  paddingLeft: BOX_PADDING_X,
                  paddingRight: BOX_PADDING_X,
                  paddingTop: BOX_PADDING_Y,
                  paddingBottom: BOX_PADDING_Y,
                  // Board'daki bölge renklendirmesiyle birebir aynı eşleme:
                  // iç dolgu = zone.tint, sınır çizgisi = base (bkz. Board.tsx
                  // territory hücre dolgusu ve buildOutline çağrısı). Sıra
                  // kimdeyse onu ayırt etmek için tek fark çerçeve kalınlığı —
                  // renk her oyuncuda aynı mantıkla (kendi base'i) belirleniyor.
                  // 31 Temmuz 2026 — nömorfik `boxShadow` (shadow-raised +
                  // sırası gelen kutunun parıltısı) kullanıcı geri bildirimiyle
                  // ("çamur gibi duruyor") tamamen kaldırıldı; kutular artık
                  // yalnızca çerçeve kalınlığıyla (2px aktif / 0.5px pasif)
                  // ayrışıyor.
                  background: col.tint,
                  border: `${active ? 2 : 0.5}px solid ${col.base}`,
                  opacity: p.surrendered ? 0.45 : 1,
                }}
              >
                <div
                  className="uppercase tracking-[1px] font-mono font-bold truncate"
                  style={{ fontSize: LABEL_FONT_SIZE, color: col.base }}
                >
                  {label}
                </div>
                <div
                  className={
                    p.surrendered
                      ? 'font-mono font-bold uppercase tracking-[1px] leading-none truncate'
                      : 'font-mono font-bold leading-none truncate'
                  }
                  style={{
                    fontSize: p.surrendered ? LABEL_FONT_SIZE : SCORE_FONT_SIZE,
                    color: col.base,
                  }}
                >
                  {p.surrendered ? 'Teslim' : p.score}
                </div>
              </div>
            );
          })}
        </div>

        <UserMenu />
      </div>
    </header>
  );
}
