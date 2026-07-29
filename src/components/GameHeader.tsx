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
const PLAYER_BOX_WIDTH = 'clamp(61px, calc(-34.83px + 25.56vw), 84px)';
const YZ_BOX_WIDTH = 'clamp(41px, calc(-21.5px + 16.67vw), 56px)';
const LABEL_FONT_SIZE = 'clamp(6px, calc(-2.33px + 2.22vw), 8px)';
const SCORE_FONT_SIZE = 'clamp(13px, calc(-7.83px + 5.56vw), 18px)';
const BOX_PADDING_X = 'clamp(6px, calc(-2.33px + 2.22vw), 8px)';
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
                className="shrink-0 shadow-raised text-center rounded-md transition-all"
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
                  // Sırası olmayanların çevresi bilinçli olarak İNCE tutuluyor
                  // (28 Temmuz 2026'da 1.5px'ten önce 0.75px'e düşürüldü, sonra
                  // gerçek bir `border`a çevrildi) — `boxShadow: inset` alt
                  // piksel (0.75px gibi) kalınlıklarda kenarlar arasında
                  // asimetrik render ediyordu (sol/üst kenarlar sağ/alttan
                  // kalın görünüyordu, kullanıcı gerçek cihazda fark etti) —
                  // `ScoreBoxRow`taki (GameHistoryModal.tsx) aynı inset
                  // box-shadow güvenilmezliği dersiyle tutarlı, oradaki gibi
                  // gerçek bir CSS `border`a geçildi, bu piksel ızgarasına
                  // tutarlı hizalanıyor.
                  background: col.tint,
                  border: `${active ? 2 : 0.5}px solid ${col.base}`,
                  opacity: p.surrendered ? 0.45 : 1,
                  // Çerçeve kalınlığı tek başına yeterince ayrışmadığından
                  // (28 Temmuz 2026, kullanıcı geri bildirimi) sırası gelen
                  // kutu ayrıca kendi rengiyle uyumlu bir parıltı kazanıyor.
                  // İlk denemede `transform: scale` + `filter: drop-shadow`
                  // kullanılmıştı ama bu kutuyu üst şeridin (`overflow-x-auto`
                  // — CSS'in "bir eksen auto ise diğerini de auto say" kuralı
                  // yüzünden dikeyde de kırpıyor, bkz. UserMenu ile ilgili
                  // yukarıdaki not) sınırlarının dışına taşırıp KESİYORDU, ve
                  // drop-shadow'un yayılımı komşu kutuya kadar uzanıyordu.
                  // Düzeltme: `transform`/`filter` tamamen kaldırıldı; bunun
                  // yerine `shadow-raised` class'ının katmanları BURADA aynen
                  // tekrarlanıp (inline `boxShadow` class'ınkini komple ezdiği
                  // için) üzerine dar bir (4px bulanıklık, hiç yayılım yok)
                  // parıltı katmanı EKLENİYOR — BOX_GAP'in (min 6px) altında
                  // kalacak kadar dar tutulduğundan komşu kutuya değmiyor.
                  boxShadow: active
                    ? `2px 2px 6px rgba(163, 177, 198, 0.5), -2px -2px 5px rgba(255, 255, 255, 0.85), 0 0 4px 0px ${col.base}80`
                    : undefined,
                }}
              >
                <div
                  className="uppercase tracking-[1px] font-mono font-bold truncate"
                  style={{
                    fontSize: LABEL_FONT_SIZE,
                    color: col.base,
                    textDecoration: p.surrendered ? 'line-through' : 'none',
                  }}
                >
                  {p.surrendered ? 'Teslim' : label}
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
