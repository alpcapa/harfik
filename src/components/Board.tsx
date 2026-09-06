// Kelimeki — 13x13 oyun tahtası (çok oyunculu, renkli bölgeler)
import { useMemo } from 'react';
import type { MouseEvent as ReactMouseEvent } from 'react';
import {
  BONUS_LABELS,
  BONUS_ZONE,
  CORNER,
  PLAYER_COLORS,
  SIZE,
  cornerCell,
  inBonusZone,
  type PlayerColor,
} from '../game/constants';
import type { AiLevel, GameState, MoveStatus } from '../game/types';
import { key } from '../utils/board';
import { buildRoundedOutlinePath } from '../utils/outline';
import {
  ZOOM_ANIM_MS,
  ZOOM_OFF,
  zoomTransform,
  type ZoomState,
} from '../utils/boardZoom';
import { computeAllTerritories } from '../utils/validator';
import { useOnlineStatus } from '../hooks/useOnlineStatus';
import { AiLevelBadge } from './AiLevelBadge';
import { CountBadge } from './CountBadge';
import { Tile } from './Tile';

// Dış hat köşe yarıçapı (ızgara birimi) — köşe bloğundaki dışbükey köşelerle
// aynı hissi versin diye, ama artık içbükey (genişleyen kolların dönüşleri)
// köşeler de aynı yarıçapla yuvarlanıyor.
const OUTLINE_RADIUS = 0.16;
const OUTLINE_STROKE = 2.5;

interface BoardProps {
  state: GameState;
  // Tıklama olayı da veriliyor: taslak sürerken ıskalanan dokunuş, en
  // yakın taslak hücresine yönlendirilirken noktayı kullanıyor
  // (`src/utils/draftRescue.ts`).
  onCellClick: (r: number, c: number, e: ReactMouseEvent) => void;
  /** Oyna'ya basmadan önceki anlık geçerlilik/puan çerçevesi; taş yoksa null. */
  moveStatus: MoveStatus | null;
  /** "Hamleler" linkine tıklanınca çağrılır. */
  onOpenHistory: () => void;
  /**
   * Alt şeritte "Hamleler"in yanındaki zorluk rozeti (6 Eylül 2026, kullanıcı
   * isteği: rozet "Mesajlaşma"nın olduğu yerde de dursun). Yalnızca YZ oyunu
   * geçirir (App.tsx, her seviyede); Canlı ekran geçirmez → rozet yok.
   * Tıklanamaz, 48px asgarisini TAŞIMAZ — şeridin "beş öğe" sayımına girmez.
   */
  aiLevel?: AiLevel | null;
  /**
   * "Mesajlaşma" butonuna tıklanınca çağrılır — yalnızca Canlı (online
   * multiplayer) oyun ekranı (`OnlineGameScreen.tsx`) geçirir; verilmezse
   * (yerel/YZ oyun ekranı) buton hiç render edilmez (Oyun İçi Mesajlaşma —
   * Faz 1, YZ'ye karşı yerel oyunlarda kapsam dışı).
   */
  onOpenMessaging?: () => void;
  /**
   * `onOpenMessaging` butonunun sağ üstünde okunmamış mesaj SAYISINI
   * gösterir (`CountBadge`). 16 Ağustos 2026'ya kadar sayısız bir kırmızı
   * noktaydı; kullanıcı "insanlar fark etmiyor" diye bildirince projedeki
   * öteki rozetlerle aynı görsele çekildi (bkz. kök CLAUDE.md, `CountBadge`).
   */
  unreadMessageCount?: number;
  /**
   * Alt şeridin SAĞ ucundaki "Yardım" linki (14 Ağustos 2026,
   * kullanıcı isteği) — buraya kadar X2/X3 açıklaması duruyordu. Kurallar
   * her zaman erişilebilir olmalı; bonus renkleri zaten tahtada filigranla
   * yazılı olduğundan legend'ın taşıdığı bilgi kaybolmuyor. Verilmezse
   * (salt-okunur önizlemeler) link hiç çizilmez.
   */
  onOpenHelp?: () => void;
  /** Şu an sürüklenmekte olan, bu tur yerleştirilmiş taşın hücre anahtarı — o hücre boşmuş gibi çizilir. */
  dragHiddenKey?: string | null;
  /** Sürükleme sırasında işaretçinin üzerinde olduğu hücre (bırakma hedefi vurgusu). */
  dragOverKey?: string | null;
  /** `dragOverKey` hücresine bırakmak geçerli mi? */
  dragOverValid?: boolean;
  /** Raftan/tahtadan bir taş HAVADA mı (sürükleme sürüyor) — "Buradan başla"
      balonu bu anda kaybolur: oyuncu taşı KALDIRDIYSA ipucu görevini
      bitirmiştir ve balon bırakma hedefinin yanında dikkat dağıtır. */
  tileLifted?: boolean;
  /** Bu tur yerleştirilmiş bir taşın sürüklenmesini başlatır. */
  onTilePointerDown?: (r: number, c: number, e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerMove?: (e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerUp?: (e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerCancel?: (e: React.PointerEvent<HTMLDivElement>) => void;
  /** Alt bilgi şeridini (Hamleler linki + Mesajlaşma butonu + "Yardım" linki) gizler — salt-okunur önizlemelerde (bkz. `GameBoardPreview`). */
  hideFooter?: boolean;
  /** Taşları küçük/puan göstermeden çizer — salt-okunur önizlemelerde (bkz. `GameBoardPreview`). */
  compact?: boolean;
  /** Tahta yakınlaştırması (1 Eylül 2026 — port ile AYNI davranış, bkz.
      `src/utils/boardZoom.ts`). VERİLMEZSE ağaç eskisiyle birebir aynı
      çizilir: transform `none`, kırpma yok — salt-okunur önizlemeler ve
      karşılama katmanı bu yoldan geçiyor. */
  zoom?: ZoomState;
  /** Görünür kare (kırpma kutusu) — hook'un ölçüm/odak referansı. */
  viewportRef?: React.RefObject<HTMLDivElement>;
  /** Zoom tanıtım balonu (1 Eylül 2026) — merkez kareyi işaret eden tek
      seferlik ipucu. Gösterilip gösterilmeyeceğine `useBoardZoom` karar
      verir (`utils/onboarding.ts`); burada yalnızca çizim var. */
  zoomHint?: boolean;
  onBoardPointerDown?: (e: React.PointerEvent) => void;
  onBoardPointerMove?: (e: React.PointerEvent) => void;
  onBoardPointerUp?: () => void;
  onBoardPointerCancel?: () => void;
}

// Merkezdeki x2 bonus bölgesi altın rengi — nömorfik, diğer köşe tonlarıyla
// karışmasın diye sıcak/altın. Tam ortadaki tek X3 hücresi turuncu bir zeminle
// öne çıkar.
//
// 25 Ağustos 2026 — İKİSİ DE `export`: `FriendInvitePage`'in tanıtım tahtasının
// altındaki X2/X3 açıklama rozetleri bu zeminleri BİREBİR kullanıyor (tahta
// orada `compact`, yani hücrelerin üstünde "X2"/"X3" etiketi çizilmiyor —
// rengi açıklayan tek şey o rozetler). Renk kodunu oraya elle yazmak bu kod
// tabanının en sık tekrarlayan hata sınıfının (iki kopyanın sessizce
// ayrışması) bir örneği daha olurdu.
export const GOLD_ZONE_STYLE: React.CSSProperties = {
  background: 'linear-gradient(135deg, #FDE68A, #FBBF24)',
  boxShadow: 'inset 2px 2px 5px rgba(180,130,10,0.3), inset -1px -1px 3px rgba(255,255,255,0.7), 0 2px 4px rgba(180,130,10,0.2)',
};
export const CENTER_ZONE_STYLE: React.CSSProperties = {
  background: 'linear-gradient(135deg, #FDBA74, #F97316)',
  boxShadow: 'inset 2px 2px 5px rgba(180,80,10,0.35), inset -1px -1px 3px rgba(255,255,255,0.7), 0 2px 4px rgba(180,80,10,0.25)',
};
const CENTER_TEXT = 'text-[#7C2D12]';

/** Bir oyuncunun ilk hamlesinde mutlaka değmesi gereken köşe hücresindeki ev işareti. */
function HomeMark({ color }: { color: PlayerColor }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="w-[55%] h-[55%]"
      style={{ opacity: 0.85 }}
      fill={color.base}
    >
      <path d="M12 2.5 1.5 11h3V21h6v-6h3v6h6V11h3L12 2.5Z" />
    </svg>
  );
}

/** "Hamleler" linkinin başındaki küçük döküman ikonu. */
function DocumentIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
      <path d="M9 13h6M9 17h6" />
    </svg>
  );
}

/** "Mesajlaşma" butonunun başındaki küçük konuşma balonu ikonu. */
function ChatBubbleIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    </svg>
  );
}

/** Alt şeritteki "Yardım" linkinin başındaki soru işareti ikonu. */
function HelpIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <circle cx="12" cy="12" r="10" />
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
      <path d="M12 17h.01" />
    </svg>
  );
}

export function Board({
  state,
  onCellClick,
  moveStatus,
  onOpenHistory,
  aiLevel,
  onOpenHelp,
  onOpenMessaging,
  unreadMessageCount = 0,
  dragHiddenKey = null,
  dragOverKey = null,
  dragOverValid = false,
  tileLifted = false,
  onTilePointerDown,
  onTilePointerMove,
  onTilePointerUp,
  onTilePointerCancel,
  hideFooter = false,
  compact = false,
  zoom = ZOOM_OFF,
  viewportRef,
  zoomHint = false,
  onBoardPointerDown,
  onBoardPointerMove,
  onBoardPointerUp,
  onBoardPointerCancel,
}: BoardProps) {
  const online = useOnlineStatus();
  const { board, placed, bonuses, players, current } = state;

  // Köşe bölgesi -> o köşenin sahibinin rengi (boş kareleri renklendirmek için).
  const cornerColor: (PlayerColor | undefined)[] = [
    undefined,
    undefined,
    undefined,
    undefined,
  ];
  for (const p of players) {
    for (const corner of p.corners) cornerColor[corner] = PLAYER_COLORS[p.colorIndex];
  }

  // Köşe bölgesi -> o köşedeki oyuncunun numarası (1, 2, …) — soluk filigran.
  const cornerNumber: (number | undefined)[] = [
    undefined,
    undefined,
    undefined,
    undefined,
  ];
  players.forEach((p, i) => {
    for (const corner of p.corners) cornerNumber[corner] = i + 1;
  });

  // Izgaranın boşluğu (`gap-[3px]`) ve ondan türeyen GERÇEK hücre genişliği.
  // Yüzde tabanlı katmanlar (köşe filigranı, X2) bu farkı görmezden gelebiliyor
  // çünkü onlar 4×4/5×5 blokları kabaca kaplıyor; tek bir hücreye HİZALANAN
  // bir şey (aşağıdaki "Buradan başla" balonu) için ise kayma görünür oluyor.
  const GRID_GAP = 3;
  const CELL_W = `((100% - ${(SIZE - 1) * GRID_GAP}px) / ${SIZE})`;

  // Köşe bölgesinin tahtaya oranı (kenar uzunluğu).
  const cornerFrac = `${(CORNER / SIZE) * 100}%`;

  // "Buradan başla" balonu — tahta TAMAMEN boşken, sırası gelen İNSAN
  // oyuncunun ev karesinin yanında (kullanıcı isteği, 26 Ağustos 2026).
  //
  // NEDEN VAR: kapalı testte insanların kuralı değil, İLK HAMLEYİ nereye
  // yapacaklarını bulamadıkları görüldü. Ev işareti (`HomeMark`) zaten
  // duruyor ama ne olduğunu söyleyen bir şey yok — tanıtımda okunan bir
  // cümle, tahtaya bakarken hatırlanmıyor.
  //
  // GÖRÜNME KOŞULU üç parça ve üçü de bilinçli:
  //   1. tahtada TEK taş yok (ilk hamle henüz oynanmadı),
  //   2. bu turda konmuş taslak taş da yok — oyuncu oynamaya başladıysa
  //      ipucu görevini bitirmiştir, balon taslağın üstünü kapatmasın,
  //      (`board` boş ama `placed` doluysa balon hâlâ gösterilseydi taşın
  //      üzerine binerdi — 4 kişilik oyunda ev kareleri kenarda ve
  //      balon yanlarına doğru uzuyor)
  //   3. sıra bir İNSANDA — YZ düşünürken "buradan başla" demek anlamsız.
  // Kalıcı bir "görüldü" bayrağı YOK: koşul kendi kendini sınırlıyor
  // (ilk taş konunca kayboluyor) ve her yeni oyunda yeniden görünmesi
  // zararsız; localStorage'a bir bayrak daha eklemek, cihaz değiştiren ya
  // da uzun aradan sonra dönen oyuncuyu ipuçsuz bırakırdı.
  const startHint = useMemo(() => {
    if (compact) return null;
    // Taş HAVADA (sürükleniyor) ya da rafta SEÇİLİ: oyuncu taşı KALDIRDIĞI
    // anda ipucu görevini bitirmiştir — balon bırakma hedefinin yanında
    // dikkat dağıtır (kullanıcı isteği, 26 Ağustos 2026: "taşı kaldırdığı
    // anda yok olsun"; ilk sürüm yalnızca taş KONUNCA gizliyordu).
    // İKİ sinyal de gerekiyor: `tileLifted` sürüklemeyi, `selectedTile`
    // dokunup seçmeyi kapsıyor — sürükleme `selectedTile`ı SET ETMİYOR
    // (App.tsx `endDrag` yalnızca `!moved` dalında seçiyor).
    if (tileLifted || state.selectedTile !== null) return null;
    if (Object.keys(placed).length > 0) return null;
    if (board.some((row) => row.some((c) => c !== null))) return null;
    const p = players[current];
    if (!p || p.isAI || p.surrendered) return null;
    const corner = p.corners[0];
    if (corner === undefined) return null;
    const [hr, hc] = cornerCell(corner);
    const col = PLAYER_COLORS[p.colorIndex];
    // Balon ev karesinin YANINDA, aynı satırda, tahtanın içine doğru uzar —
    // böylece hangi köşede olursa olsun tahtadan taşmaz. Kuyruk ev karesine
    // bakar. (Aynı sütunda yukarı/aşağı uzatmak 13 satırın en uçlarında
    // dışarı taşardı.)
    const toRight = hc < SIZE / 2;
    return { hr, hc, col, toRight };
  }, [compact, placed, board, players, current, tileLifted, state.selectedTile]);

  // Merkezdeki x2 bonus bölgesinin tahtaya oranı ve konumu — köşe numarası
  // filigranıyla aynı mantıkla, tek büyük bir "X2" o bölgenin arkasına yazılır.
  const zoneSize = BONUS_ZONE.r1 - BONUS_ZONE.r0 + 1;
  const zoneFrac = `${(zoneSize / SIZE) * 100}%`;
  const zoneTop = `${(BONUS_ZONE.r0 / SIZE) * 100}%`;
  const zoneLeft = `${(BONUS_ZONE.c0 / SIZE) * 100}%`;

  // Köşenin tam ucundaki tek başlangıç hücresi -> o köşenin sahibinin rengi.
  // İlk hamle bu hücreye değmek zorunda olduğundan burada bir "ev" işareti
  // gösterilir.
  const homeCellColor = new Map<string, PlayerColor>();
  players.forEach((p) => {
    for (const corner of p.corners) {
      const [hr, hc] = cornerCell(corner);
      homeCellColor.set(key(hr, hc), PLAYER_COLORS[p.colorIndex]);
    }
  });

  const colorOf = (owner: number | undefined): PlayerColor | undefined =>
    owner === undefined ? undefined : PLAYER_COLORS[players[owner]?.colorIndex ?? 0];

  // En son oynanan hamlenin taşlarını, bir çerçeve yerine hafifçe koyulaştırılmış
  // tonuyla ayırt eder — çerçeve, bölge genişledikçe bölge dış hattıyla çakışıp
  // kafa karıştırıcı kalıntılar bırakıyordu.
  const darken = (hex: string, amount: number): string => {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.round(((num >> 16) & 255) * (1 - amount));
    const g = Math.round(((num >> 8) & 255) * (1 - amount));
    const b = Math.round((num & 255) * (1 - amount));
    return `#${[r, g, b].map((v) => Math.max(0, Math.min(255, v)).toString(16).padStart(2, '0')).join('')}`;
  };

  const currentColor = PLAYER_COLORS[players[current]?.colorIndex ?? 0];

  // En son oynanan hamlenin hücreleri — taş rengi koyulaştırılarak vurgulanır.
  const lastMoveSet = new Set(state.lastMoveCells.map(([r, c]) => key(r, c)));

  // Her oyuncunun bölgesi: kendi köşesi + oradan kendi taşlarıyla genişleyen
  // alan. Sabit 4×4 köşenin aksine hamle oynandıkça büyür. `board`/`players`
  // yalnızca bir hamle oynanınca değiştiğinden `useMemo` ile önbelleklenir —
  // aksi halde bir taş sürüklenirken (her `pointermove`'da `Board` yeniden
  // render olur, ama `board`/`players` aynı kalır) bu flood-fill her seferinde
  // gereksiz yere tekrarlanıyordu.
  const territories = useMemo(
    () => computeAllTerritories(board, players),
    [board, players],
  );
  // territories[i]'yi hücre başına tek tek taramak yerine, aynı useMemo
  // içinde tek bir hücre→sahip Map'ine çevriliyor — 169 hücrenin her biri
  // için O(oyuncu sayısı) yerine O(1) arama.
  const territoryOwnerMap = useMemo(() => {
    const m = new Map<string, number>();
    territories.forEach((cellSet, i) => {
      cellSet.forEach((k) => m.set(k, i));
    });
    return m;
  }, [territories]);
  const territoryOwnerAt = (r: number, c: number): number => territoryOwnerMap.get(key(r, c)) ?? -1;

  const cells = [];

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const k = key(r, c);
      const boardTile = board[r][c];
      const rawPlacedTile = placed[k];
      // Sürüklenmekte olan taş, alındığı hücrede boşmuş gibi çizilir (görsel olarak).
      const placedTile = k === dragHiddenKey ? undefined : rawPlacedTile;
      const bonus = bonuses[k];
      const inZone = inBonusZone(r, c);
      const territoryOwner = territoryOwnerAt(r, c);
      const zone = territoryOwner >= 0 ? PLAYER_COLORS[players[territoryOwner]?.colorIndex ?? 0] : undefined;
      const homeColor = homeCellColor.get(k);

      let content: React.ReactNode = null;
      let style: React.CSSProperties | undefined;
      const classes = [
        'min-w-0 min-h-0 rounded-[5px] flex items-center justify-center',
        'font-mono font-bold text-[clamp(5px,1.4vw,8px)] select-none',
        'transition-[background,box-shadow,opacity] duration-300',
      ];

      if (boardTile) {
        // Tahtadaki her taş tıklanabilir — hangi hamlede oynandığına
        // bakılmaksızın o hücreden geçen kelime(ler)in anlamı gösterilir.
        // AMA taslak hamle sürerken DEĞİL (bkz. App.tsx handleCellClick):
        // o sırada dokunuş sessizce yutulduğundan imleç de "tıklanır"
        // demesin — yoksa çalışmayan bir kontrol gibi görünür.
        // `relative z-[5]`: köşe/bonus filigranları (z-index:auto) taşın
        // ÜZERİNDE boyanmasın diye — taş her zaman kendi solid renginde görünmeli.
        classes.push('relative z-[5] bg-transparent');
        if (Object.keys(placed).length === 0) classes.push('cursor-pointer');
        const tileColor = colorOf(boardTile.owner);
        const isLastMove = lastMoveSet.has(k);
        content = (
          <Tile
            tile={boardTile}
            variant="board"
            compact={compact}
            color={
              isLastMove && tileColor
                ? { ...tileColor, tint: darken(tileColor.tint, 0.14), base: darken(tileColor.base, 0.12) }
                : tileColor
            }
          />
        );
      } else if (placedTile) {
        classes.push('relative z-[5] bg-transparent');
        content = <Tile tile={placedTile} variant="placed" color={colorOf(placedTile.owner) ?? currentColor} />;
      } else if (inZone) {
        // Merkezdeki x2 bonus bölgesi — altın zemin, büyük "X2" filigranı
        // bölgenin tamamının arkasına yazılır (aşağıda). Tam ortadaki tek
        // hücre bunun dışında, turuncu zemin + kendi X3 etiketiyle öne çıkar.
        classes.push('cursor-pointer');
        style = bonus ? { ...CENTER_ZONE_STYLE } : { ...GOLD_ZONE_STYLE };
        if (bonus && !compact) {
          // 28 Ağustos 2026, kullanıcı isteği ("en ortadaki X3 yazısını biraz
          // büyütelim"): 7/1.9vw/12 → 9/2.6vw/16. Port ikizi
          // `board_widget.dart` (`fluidSize(screenWidth, 9, 0, 2.6, 16)`) —
          // İKİSİ BİRLİKTE DEĞİŞİR, punto ikisinde de hücreye değil EKRAN
          // genişliğine bağlı.
          classes.push(CENTER_TEXT, 'text-[clamp(9px,2.6vw,16px)]');
          content = BONUS_LABELS[bonus];
        }
      } else if (zone) {
        // Bir oyuncunun köşesindeki boş kare: nömorfik içe gömülü + oyuncu tonu.
        classes.push('cursor-pointer');
        style = {
          background: zone.tint,
          boxShadow: `inset 2px 2px 5px ${zone.base}22, inset -1px -1px 3px rgba(255,255,255,0.6)`,
        };
      } else {
        // Merkez (tarafsız) boş kare: nömorfik içe gömülü.
        classes.push('bg-[#DDE4EE] cursor-pointer');
        style = { boxShadow: 'inset 3px 3px 6px rgba(163,177,198,0.6), inset -2px -2px 5px rgba(255,255,255,0.8)' };
      }

      if (homeColor && !boardTile && !placedTile) {
        // Oyuncunun mutlaka değmesi gereken başlangıç köşesi: ev işareti.
        content = <HomeMark color={homeColor} />;
      }

      // Bu turda yerleştirilmiş (henüz oynanmamış) bir taş, tıklama yerine
      // sürükleme jestiyle (basılı tut → hareket ettir → bırak) yönetilir.
      const hasPending = !!rawPlacedTile;

      if (dragOverKey === k) {
        style = {
          ...style,
          outline: `2px dashed ${dragOverValid ? '#1FA05C' : '#E0483A'}`,
          outlineOffset: '-2px',
        };
      }

      cells.push(
        <div
          key={k}
          className={classes.join(' ')}
          style={{
            ...style,
            gridRow: `${r + 1} / ${r + 2}`,
            gridColumn: `${c + 1} / ${c + 2}`,
            ...(hasPending ? { touchAction: 'none' } : null),
          }}
          data-cell={`${r},${c}`}
          onClick={hasPending ? undefined : (e) => onCellClick(r, c, e)}
          onPointerDown={hasPending ? (e) => onTilePointerDown?.(r, c, e) : undefined}
          onPointerMove={hasPending ? onTilePointerMove : undefined}
          onPointerUp={hasPending ? onTilePointerUp : undefined}
          onPointerCancel={hasPending ? onTilePointerCancel : undefined}
        >
          {content}
        </div>,
      );
    }
  }

  // Verilen hücre kümesinin TEK, tamamen yuvarlatılmış (dışbükey VE
  // içbükey köşeler dahil) dış hat SVG path'ini üretir — `buildRoundedOutlinePath`
  // ızgara birimi cinsinden çalışır, burada sadece rengi/kalınlığı ekleyip
  // bir <path> elemanına sarıyoruz. `extraOpen`, kümenin dışına bakan bir
  // kenarı da "kapalı" (çizgisiz) sayabilmek için — bonus bölgesi/merkez
  // çerçevesi, bir oyuncunun bölgesinin İÇİNDEN geçen kendi kenarını bu
  // şekilde bastırır, böylece oyuncunun genişleyen bölgesi içinde gereksiz
  // bir amber çizgi kalmaz.
  const buildOutline = (
    cellsList: [number, number][],
    color: string,
    keyPrefix: string,
    extraOpen?: (r: number, c: number, nr: number, nc: number) => boolean,
  ): React.ReactNode => {
    const uniqueCells = [...new Map(cellsList.map(([r, c]) => [key(r, c), [r, c] as [number, number]])).values()];
    if (uniqueCells.length === 0) return null;
    const d = buildRoundedOutlinePath(uniqueCells, OUTLINE_RADIUS, extraOpen);
    if (!d) return null;
    return (
      <path
        key={keyPrefix}
        d={d}
        fill="none"
        stroke={color}
        strokeWidth={OUTLINE_STROKE}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
      />
    );
  };

  // Bir hücre kümesinin en üst-soldaki hücresine puan rozeti konur
  // (tahtaya konan taşın kendi puan üst simgesiyle çakışmaması için sağ üst
  // yerine sol üst köşede).
  const buildBadge = (cellsList: [number, number][], score: number, color: string): React.ReactNode => {
    let badge: [number, number] | null = null;
    for (const [r, c] of cellsList) {
      if (!badge || r < badge[0] || (r === badge[0] && c < badge[1])) badge = [r, c];
    }
    if (!badge) return null;
    const [r, c] = badge;
    return (
      <div
        data-move-badge=""
        className="pointer-events-none absolute z-20 flex items-center justify-center rounded-full font-sans font-bold text-white leading-none whitespace-nowrap"
        style={{
          top: `${(r / SIZE) * 100}%`,
          left: `${(c / SIZE) * 100}%`,
          transform: 'translate(-35%, -35%)',
          background: color,
          // Punto SABİT 11 + `font-sans` (29 Ağustos 2026, kullanıcı kararı:
          // "web'i porta getir"). Önceden `clamp(8px,2vw,11px)` + `font-mono`
          // idi ve port sabit 11 + tema sans'ı çizdiğinden iki taraf dar
          // telefonda ayrışıyordu (port %19 geniş) — şikayetin asıl kaynağı
          // buydu. Ayrışma PORTU küçülterek değil WEBİ sabitleyerek kapandı:
          // hamle puanı "Oyna"dan önce bakılan tek sayı, küçültmek istenmedi
          // (aynı gerekçeyle bir tur önce portun puntosuna da dokunulmamıştı).
          // ÖLÇÜLDÜ (gerçek oyun + Chromium, taslak taş konup rozetin metni
          // değiştirilerek; "hücre" = tahta genişliği / 13):
          //   384px (yaygın telefon, hücre 27.7px)
          //     "+35"  ÖNCE 20.7px (clamp 8px'e kırpılıyor) = 0.75 hücre
          //            SONRA 26.1px = 0.94 hücre
          //   320px (EN DAR gerçek yüzey, hücre 22.8px)
          //     "+35"  ÖNCE 20.7px = 0.91 → SONRA 26.1px = 1.15 hücre
          // Yani 320px'te iki haneli bir puan tek hücreyi AŞIYOR. Bilerek
          // kabul edildi: port zaten sabit 11 çizdiğinden 320px'lik bir
          // telefonda AYNI taşmayı yaşıyor — bu değişiklik web'i portun
          // davranışına getiriyor, yeni bir sorun üretmiyor. Taşma bir gün
          // şikayet konusu olursa çözüm İKİ tarafta birden uygulanmalı.
          // clamp `2vw`si her telefonda 8px'e kırpıldığından (11px'e ancak
          // 550px'te ulaşıyordu) ayrışma pratikte sabit %19'du.
          // Dolgu 3/6 → 1.5/3 düzeltmesi bir tur önce geldi (portta 384px'te
          // 30.7px = 1.22 hücre → 24.7px = 0.98 hücre).
          // Port ikizi: mobile/.../board_widget.dart `_moveBadge` — biri
          // değişirse öteki de AYNI PR'da.
          fontSize: '11px',
          padding: '1.5px 3px',
          boxShadow: '0 2px 5px rgba(0,0,0,0.25)',
        }}
      >
        +{score}
      </div>
    );
  };

  // Her oyuncunun bölgesinin dış hattı — köşeden taşlarla genişledikçe sınır
  // da ona göre büyür. Kenar izleme + yuvarlatma (`buildRoundedOutlinePath`)
  // pahalı olduğundan `territories` değişmediği sürece (bir taş sürüklenirken
  // olduğu gibi) tekrar hesaplanmaz.
  const territoryOutlines = useMemo(
    () =>
      players.map((p, i) => {
        const territoryCells = [...territories[i]].map(
          (k) => k.split(',').map(Number) as [number, number],
        );
        return buildOutline(territoryCells, PLAYER_COLORS[p.colorIndex].base, `territory-${i}`);
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [territories, players],
  );

  // Oyna'ya basmadan önce anlık geçerlilik çerçevesi (yeşil/kırmızı) + puan —
  // aynı sebeple `moveStatus` değişmediği sürece yeniden hesaplanmaz.
  const moveColor = moveStatus ? (moveStatus.valid ? '#1FA05C' : '#E0483A') : undefined;
  const moveOutline = useMemo(
    () => (moveStatus ? buildOutline(moveStatus.cells, moveColor!, 'move') : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [moveStatus],
  );
  const moveBadge = useMemo(
    () => (moveStatus ? buildBadge(moveStatus.cells, moveStatus.score, moveColor!) : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [moveStatus],
  );

  return (
    <div className="w-full max-w-[680px] mx-auto px-3 pt-1.5 pb-3 flex flex-col items-center">
      <div
        className="relative w-full bg-[#DDE4EE] rounded-[18px]"
        style={{
          boxShadow: '8px 8px 20px rgba(163,177,198,0.7), -4px -4px 14px rgba(255,255,255,0.9), 0 20px 60px rgba(163,177,198,0.5)',
        }}
      >
      {/* ── Yakınlaştırma katmanları (1 Eylül 2026) ────────────────────
          GÖRÜNÜR KARE (`viewportRef`) ızgarayı kırpar, ızgaranın kendisi
          `transform` ile ölçeklenir/kaydırılır. Kırpma YALNIZCA zoom
          açıkken kurulur — kapalıyken `clipPath: none`, yani eski render
          BİREBİR korunur (kırpmanın kendisi bir tur önce portta rozeti ve
          bölge çizgisini kesmişti; web'de o riski hiç doğurmuyoruz).
          Kırpma KARE DEĞİL, kartın üst köşelerinin yuvarlağını taşır —
          gerekçe aşağıdaki `clipPath` yorumunda.
          ⚠ `elementFromPoint` transform'u kendisi tersine çevirdiğinden
          hücre bulma/bırakma kodunun HİÇBİRİ değişmedi (portta bu iş için
          ayrı bir "görünür kare kapısı" yazmak gerekmişti). */}
      <div className="relative w-full aspect-square">
      <div
        ref={viewportRef}
        data-board-viewport=""
        className="absolute inset-0"
        style={{
          // ⚠ KARE DEĞİL, KARTIN ŞEKLİ. Önce `inset(-4px)` idi: kırpma
          // kartın dışına 4 px taşıyor ve KARE olduğu için kartın 18 px'lik
          // yuvarlak ÜST köşelerini de dolduruyordu — kullanıcı zoom'da
          // "tahtanın üstünde ve sağında taşma" olarak gördü. ÖLÇÜLDÜ
          // (fark ölçümü, zoom öncesi ↔ sonrası): kartın üstündeki bantta
          // 462 → 527 taş renkli piksel, yani zoom 65 px² fazladan boyuyor.
          // Yalnızca ÜST iki köşe yuvarlanıyor: alt iki köşe kartın
          // ortasında (altında alt şerit var), onları yuvarlamak tahtanın
          // alt köşelerini keserdi.
          // Pay neden 0: zoom'da dış hat ızgaranın 10 px dolgusunun
          // içinde, yani 2×'te kenardan ≥20 px içeride — kırpma sınırına
          // hiç yaklaşmıyor; bu yüzden pay 0 ve eski `BOARD_CLIP_SLACK`
          // sabiti kaldırıldı (rozetin KENDİ payı ayrı ve duruyor).
          clipPath: zoom.zoomed ? 'inset(0 round 18px 18px 0 0)' : undefined,
          // Zoom'luyken parmak tahtayı kaydırır; tarayıcının kendi kaydırma
          // jesti devreye girerse pan hiç başlamaz.
          touchAction: zoom.zoomed ? 'none' : undefined,
        }}
        onPointerDown={onBoardPointerDown}
        onPointerMove={onBoardPointerMove}
        onPointerUp={onBoardPointerUp}
        onPointerCancel={onBoardPointerCancel}
      >
      <div
        data-board-grid=""
        className="relative grid gap-[3px] p-[10px] w-full h-full"
        style={{
          gridTemplateColumns: `repeat(${SIZE}, 1fr)`,
          gridTemplateRows: `repeat(${SIZE}, 1fr)`,
          transform: zoomTransform(zoom),
          transformOrigin: '0 0',
          transition: zoom.animate ? `transform ${ZOOM_ANIM_MS}ms cubic-bezier(0.22,1,0.36,1)` : undefined,
        }}
      >
        {cells}

        {/* Tüm bölge/bonus/hamle dış hatları tek bir SVG katmanında — ızgaranın
            tam hücre alanını kaplayacak şekilde tek bir grid öğesi olarak
            (satır/sütun 1'den sona) yerleştirilir, böylece her yolun köşeleri
            (dışbükey VE içbükey) aynı yarıçapla pürüzsüz yuvarlanır. Puan
            rozeti de aynı kutu içinde, aynı yüzde koordinatlarıyla hizalanır. */}
        <div className="pointer-events-none z-10" style={{ gridRow: '1 / -1', gridColumn: '1 / -1', position: 'relative' }}>
          <svg
            className="block w-full h-full"
            style={{ overflow: 'visible' }}
            viewBox={`0 0 ${SIZE} ${SIZE}`}
            preserveAspectRatio="none"
          >
            {/* Her oyuncunun genişleyen bölgesinin dış hattı — bonus bölgesi
                çerçevesinin üzerinde çizilir, böylece bir oyuncunun bölgesi
                bonus alanına ilerlediğinde sınır kendi renginde kalır. */}
            {territoryOutlines}

            {/* Oyna'ya basmadan önce anlık geçerlilik çerçevesi (yeşil/kırmızı):
                tüm kelimelerin hücrelerini kapsayan tek dış hat, iç kesişimde çizgi yok. */}
            {moveOutline}
          </svg>

        </div>

        {/* Zoom tanıtım balonu — MERKEZ karenin üstünde, kuyruğu aşağı
            (kareye) bakan çok satırlı kutu. `inset-[10px]`: aşağıdaki
            "Buradan başla" ile aynı gerekçe (grid'in kendi dolgusuyla
            eşleşmezse yüzde koordinatları hücre alanından kayar).
            Sürükleme başlayınca kaybolur — `tileLifted`, "Buradan başla"nın
            aynı davranışı. Port ikizi: `board_widget.dart`
            `_zoomHintBubble`; METİN İKİSİNDE DE BİREBİR aynı olmalı. */}
        {zoomHint && !tileLifted && (
          <div className="pointer-events-none absolute inset-[10px] z-20">
            <div
              data-zoom-hint=""
              className="absolute left-0 right-0 flex flex-col items-center"
              style={{
                // Merkez karenin ÜST kenarı; kutu kendi yüksekliği kadar
                // yukarı çekiliyor (punto akışkan, yükseklik bilinmiyor).
                top: `calc(${CELL_W} * ${Math.floor(SIZE / 2)} + ${Math.floor(SIZE / 2) * GRID_GAP}px)`,
                transform: 'translateY(-100%)',
              }}
            >
              <div
                className="font-bold leading-snug text-center rounded-[9px] text-white"
                style={{
                  maxWidth: '78%',
                  background: '#2563EB',
                  fontSize: 'clamp(9px, 2.4vw, 13px)',
                  padding: '7px 10px',
                  boxShadow: '0 2px 6px rgba(15,23,42,0.28)',
                }}
              >
                Boş kareye veya çerçevesine çift tıklama tahtayı büyütür. Hemen dene!
              </div>
              {/* Kuyruk: merkez kareye bakan küçük üçgen. */}
              <span
                style={{
                  width: 0,
                  height: 0,
                  borderLeft: '5px solid transparent',
                  borderRight: '5px solid transparent',
                  borderTop: '6px solid #2563EB',
                }}
              />
            </div>
          </div>
        )}

        {/* "Buradan başla" balonu. `inset-[10px]`: köşe filigranındaki aynı
            gerekçe — absolute konumlanan bir grid öğesinin containing block'u
            padding box olduğundan, grid'in kendi p-[10px] dolgusuyla birebir
            eşleşmezse yüzde koordinatları hücre alanından kayar. */}
        {startHint && (
          <div className="pointer-events-none absolute inset-[10px] z-20">
            <div
              data-start-hint=""
              className="absolute flex items-center"
              style={{
                // Hücre geometrisi YÜZDEYLE ifade EDİLEMEZ: ızgarada 12 adet
                // 3px'lik boşluk var, yani bir hücre `100%/13` değil
                // `(100% - 36px)/13`. Yüzde yaklaşımı ölçüldüğünde balonu
                // dikeyde ~9px aşağı kaydırıyordu (Chromium, 656px ızgara).
                top: `calc(${CELL_W} * ${startHint.hr + 0.5} + ${startHint.hr * GRID_GAP}px)`,
                left: startHint.toRight
                  ? `calc(${CELL_W} * ${startHint.hc + 1} + ${(startHint.hc + 1) * GRID_GAP}px)`
                  : undefined,
                right: startHint.toRight
                  ? undefined
                  : `calc(100% - (${CELL_W} * ${startHint.hc} + ${startHint.hc * GRID_GAP}px))`,
                transform: 'translateY(-50%)',
                flexDirection: startHint.toRight ? 'row' : 'row-reverse',
              }}
            >
              {/* Kuyruk: ev karesine bakan küçük üçgen. */}
              <span
                style={{
                  width: 0,
                  height: 0,
                  borderTop: '5px solid transparent',
                  borderBottom: '5px solid transparent',
                  [startHint.toRight ? 'borderRight' : 'borderLeft']: `6px solid ${startHint.col.base}`,
                }}
              />
              <span
                className="font-bold leading-none whitespace-nowrap rounded-[7px]"
                style={{
                  background: startHint.col.base,
                  color: '#FFFFFF',
                  fontSize: 'clamp(9px, 2.4vw, 13px)',
                  padding: '5px 8px',
                  boxShadow: '0 2px 6px rgba(15,23,42,0.28)',
                }}
              >
                Buradan başla
              </span>
            </div>
          </div>
        )}

        {/* Her oyuncunun 4×4 köşesine soluk numara filigranı. `inset` burada
            ebeveyn grid'in kendi `p-[10px]` dolgusuyla BİREBİR eşleşmeli —
            absolute konumlanan bir grid öğesinin containing block'u
            padding box'tır (içerik kutusu değil), yani `inset-1` (4px) ile
            gerçek hücre alanının başladığı 10px arasındaki fark, üst
            köşelerde filigranı hücre alanının üstüne, alt köşelerde
            altına kaydırıyordu (ölçüldü: üstte -3.3px, altta +2.9px —
            toplam ~6px, tam da 10-4 farkı). */}
        {!compact && (
          <div className="pointer-events-none absolute inset-[10px]">
            {[0, 1, 2, 3].map((i) => {
              const col = cornerColor[i];
              const num = cornerNumber[i];
              if (!col || !num) return null;
              const top = i === 0 || i === 1;
              const left = i === 0 || i === 2;
              return (
                <div
                  key={i}
                  className="absolute flex items-center justify-center font-mono font-bold leading-none"
                  style={{
                    width: cornerFrac,
                    height: cornerFrac,
                    top: top ? 0 : 'auto',
                    bottom: top ? 'auto' : 0,
                    left: left ? 0 : 'auto',
                    right: left ? 'auto' : 0,
                    color: col.base,
                    opacity: 0.20,
                    fontSize: 'clamp(80px, 32vw, 220px)',
                  }}
                >
                  {num}
                </div>
              );
            })}
          </div>
        )}

        {/* Merkezdeki x2 bonus bölgesinin arkasına yazılan büyük "X2" filigranı.
            inset-[10px]: yukarıdaki köşe filigranı notuyla aynı sebep — grid'in
            kendi p-[10px] dolgusuyla eşleşmesi gerekiyor. Compact (önizleme)
            varyantında köşe numaralarıyla birlikte hiç gösterilmez. */}
        {!compact && (
          <div className="pointer-events-none absolute inset-[10px]">
            <div
              className="absolute flex items-center justify-center font-mono font-bold leading-none"
              style={{
                width: zoneFrac,
                height: zoneFrac,
                top: zoneTop,
                left: zoneLeft,
                color: '#92660A',
                opacity: 0.28,
                fontSize: 'clamp(60px, 24vw, 165px)',
              }}
            >
              X2
            </div>
          </div>
        )}
      </div>
      </div>

      {/* ROZET, KIRPMANIN DIŞINDA — ızgarayla AYNI transform'u alır ama
          görünür karenin içinde DEĞİLDİR. Sebebi ölçüldü (1 Eylül 2026,
          portta bir kullanıcı cihazda yakaladı: *"kenarda kalan deneme
          sayıları kesiliyor"*): rozet `translate(-35%,-35%)` ile hücre
          kutusunun dışına, tahtanın 10px'lik dolgusuna taşıyor; kırpılan
          katmanda kalsaydı kenardaki rozetin bir yanı düz kesilirdi.
          Kırpma payını rozeti kapsayacak kadar büyütmek YANLIŞ çözüm olurdu
          — aynı pay kadar zoom'lu ızgara da taşardı.
          `inset-0 p-[10px]`: transform ızgarayla AYNI kutuda uygulanmalı,
          rozetin yüzde koordinatları ise hücre alanına göre (dolgunun
          içinde) — ikisi ancak böyle birebir hizalı kalır.
          Port ikizi: `board_widget.dart` → `_zoomWrap(unclipped:)`. */}
      {moveBadge && (
        /* ⚠ KLİP AYRI, TRANSFORM'SUZ BİR SARMALAYICIDA — aynı elemana
           koymak İŞE YARAMAZ ve bu ölçülerek öğrenildi (2 Eylül 2026).
           CSS `clip-path`i elemanın KENDİ transform'undan ÖNCE uygular,
           yani klip de rozetle birlikte kayar; kullanıcı hatayı düzeltme
           "yapıldıktan" sonra da gördü. Izgara zaten bu doğru yapıyı
           kullanıyordu: klip kırpılmayan GÖRÜNÜR KAREDE, transform içteki
           katmanda. Rozet katmanı da artık öyle.
           Flutter'da sıra TERS (`ClipRect` çocuğunu ebeveyn uzayında
           kırpar), bu yüzden portta aynı hata hiç doğmadı — kullanıcı
           "bu app'de olmuyordu" derken haklıydı.
           Pay ölçüldü: rozet 2× zoom'da 39,9 × 28 px, `-35%` taşması ≈14.
           Klip HER ZAMAN açık; dinlenmede güvenli çünkü tahtanın 10 px
           dolgusu rozetin 1×'teki ≈7 px taşmasından büyük. */
        <div
          className="pointer-events-none absolute inset-0 z-20"
          /* PAY YOK ve kırpma KARTIN ŞEKLİ — ızgarayla BİREBİR aynı.
             Önce 14 px pay vardı, gerekçesi "kenardaki rozet kesilmesin"di;
             ama o pay tam olarak kullanıcının gördüğü taşmaydı: *"deneme
             rozeti hâlâ dışarı taşıyormuş, her kenardan denedim, onun
             içeride kalması lazım; header ve kenar sınırlarının altına
             giriyor"*. ÖLÇÜLDÜ: 14 px payla rozet kartın dışına 126 piksel
             boyuyordu. Kullanıcı kararı: rozet kartın İÇİNDE kalsın,
             gerekirse kesilsin — taşların kenarda kesilmesiyle aynı
             davranış. Dinlenme hâlinde zaten kesilmiyor: ızgaranın 10 px
             dolgusu rozetin 1×'teki ≈7 px taşmasından büyük. */
          style={{ clipPath: 'inset(0 round 18px 18px 0 0)' }}
        >
          <div
            data-board-badge-layer=""
            className="absolute inset-0 p-[10px]"
            style={{
              transform: zoomTransform(zoom),
              transformOrigin: '0 0',
              transition: zoom.animate
                ? `transform ${ZOOM_ANIM_MS}ms cubic-bezier(0.22,1,0.36,1)`
                : undefined,
            }}
          >
            <div className="relative w-full h-full">{moveBadge}</div>
          </div>
        </div>
      )}
      </div>

      {/* PUNTO 12 → 11 (2 Eylül 2026): portun ikizinde kullanıcı cihazda
          şeridin sistem yazı ölçeğiyle çok büyüdüğünü bildirdi. Web'de
          sistem ölçeği böyle uygulanmıyor, yani buradaki değişikliğin tek
          sebebi PARİTE — BEŞ kardeş de portla aynı puntoda kalmalı
          (`board_widget.dart`, TESTING.md "aynı puntoda olmalı" maddesi).
          ⚠ Bu satır bu turda "dört kardeş" diyordu ve SAYIM HATASIYDI:
          şeritte beş öğe var (Hamleler · ayraç · Mesajlaşma · Çevrimdışı ·
          Yardım). Yanlış sayı zararsız bir yazım hatası değildi — 12 → 11
          turu bu yorumun sayısına güvenip satır ARALIĞIYLA düzenlendi ve
          beşinci (Yardım) aralığın dışında kalıp 12'de unutuldu; kullanıcı
          cihazda fark etti. Bir "hepsi aynı olmalı" kuralı yazarken KAÇ
          tane olduğunu da yaz ve tek tek say. */}
      {/* Alt bilgi şeridi (Hamleler / Mesajlaşma / Yardım) — kartın
          kendi zemini ve gölgesiyle bütünleşik bir alt bölüm; ayrı, asılı
          kalan bir beyaz şerit değil. */}
      {/* Şeridin DİKEY ölçüsü KABIN değil her ÖĞENİN üzerinde ve asgari
          48px (Material `kMinInteractiveDimension`). 22 Ağustos 2026'da
          dolgu (`pt-1 pb-[10px]`) öğelere taşınmıştı ama YETMEDİ: gerçek
          kutu 31px kaldı ve kullanıcı 24 Ağustos'ta aynı şikayeti
          tekrarladı — *"biraz üstüne basınca çalışıyor"*. Ders sayının
          kendisinde: bir dolgu "biraz büyüttük" diye değil, ÖLÇÜLEN kutu
          asgariyi geçtiği için yeterlidir (portta
          `mobile/app/test/tap_target_test.dart` bunu iddia ediyor).
          **BEŞ öğenin de taşıması ŞART** — yalnızca dokunulabilirler
          büyürse ayraç ve "Çevrimdışı" 48px'lik satırda ortalanmaz.
          Flutter portu (`board_widget.dart` → `TapTarget`) aynı asgariyi
          taşıyor; biri değişirse öteki de değişmeli. */}
      {!hideFooter && (
        <div className="relative z-10 flex items-center justify-between gap-2 shrink-0 px-[10px] w-full">
          <div className="flex items-center gap-1.5 shrink-0">
            <button
              onClick={onOpenHistory}
              className="flex items-center gap-1 min-h-[48px] text-[11px] font-mono font-bold tracking-[0.5px] text-accent shrink-0"
            >
              <DocumentIcon />
              Hamleler
            </button>
            {/* Zorluk rozeti — YZ oyununda (App.tsx) "Hamleler"in sağında, Canlı'daki
                "· Mesajlaşma"nın yerinde; ayraç aynı görünümde. Rozet ve ayracı
                DOKUNULAMAZ, bu yüzden 48px asgarisi taşımazlar (şeridin "beş öğe"
                sayımı `layout_parity_test`te kilitli); satır yüksekliğini
                "Hamleler" veriyor, `items-center` ortalıyor. */}
            {aiLevel && (
              <>
                <span className="text-muted text-[11px] leading-none shrink-0">·</span>
                <AiLevelBadge level={aiLevel} size="sm" />
              </>
            )}
            {onOpenMessaging && (
              <>
                <span className="text-muted text-[11px] flex items-center min-h-[48px] shrink-0">·</span>
                <button
                  onClick={onOpenMessaging}
                  className="flex items-center min-h-[48px] text-[11px] font-mono font-bold tracking-[0.5px] text-accent shrink-0"
                >
                  {/* `relative` iç span'de: rozet Flutter'daki gibi METİN
                      kutusuna çapalı kalsın diye (orada da Stack, TapTarget'ın
                      İÇİNDE). 48px'lik <button>'a çapalansaydı rozet
                      satırın üst kenarına, metinden kopuk kalırdı. */}
                  <span className="relative flex items-center gap-1">
                    <ChatBubbleIcon />
                    Mesajlaşma
                    {/* Konum ÖLÇÜLEREK seçildi, tercihle değil: rozet mutlak
                        konumlu olmak ZORUNDA (satır içi olsaydı 20px eklerdi
                        ve 360px'lik bir telefonda "Nasıl Oynanır?" ile çakışan
                        şerit zaten yalnızca 7.8px boşluk taşıyor — ⚠ bu ölçüm
                        ESKİ etiketle yapıldı; etiket 2 Eylül 2026'da "Yardım"
                        olunca boşluk arttı, yani gerekçe hâlâ geçerli ama 7.8
                        rakamı artık DEĞİL, yeniden ölçmeden alıntılama). Aynı
                        sebeple sağa taşma 4px'ten (`-right-1`) fazla olamaz.
                        `ring-2 ring-panel`: rozet, altındaki mavi etiketten
                        ayrışsın diye — halkasız hâli ölçüm turunda okunaksız
                        çıktı. Etiketin son iki harfini kapatması bilinen ve
                        kabul edilen bedel. */}
                    {unreadMessageCount > 0 && (
                      <CountBadge
                        count={unreadMessageCount}
                        className="absolute -top-1 -right-1 ring-2 ring-panel"
                      />
                    )}
                  </span>
                </button>
              </>
            )}
          </div>
          <div className="flex items-center gap-2 justify-end flex-wrap">
            {/* Punto/aralık, alt şeritteki KARDEŞ kontrollerle (Hamleler ·
                Mesajlaşma · Yardım) birebir aynı — yalnızca rengi
                farklı. Önceden 8px'ti ve kullanıcı cihazda "belli olmuyor"
                diye bildirdi (14 Ağustos 2026): tam da çevrimdışıyken
                okunması gereken tek gösterge, şeridin en küçük yazısıydı. */}
            {!online && (
              <div className="text-[11px] font-mono font-bold tracking-[0.5px] text-red flex items-center min-h-[48px] shrink-0">
                Çevrimdışı
              </div>
            )}
            {onOpenHelp && (
              <button
                onClick={onOpenHelp}
                /* ⚠ 11px — BEŞ kardeşin hepsi aynı puntoda olmak zorunda.
                   2 Eylül 2026: puntolar 12 → 11 indirilirken BU SATIR
                   atlanmıştı (aralığın dışında kaldı) ve tek başına 12'de
                   kaldı; kullanıcı cihazda fark etti (*"Nasıl Oynanır hâlâ
                   12px sanki"*) ama o an geçiştirildi. */
                className="flex items-center gap-1 min-h-[48px] text-[11px] font-mono font-bold tracking-[0.5px] text-accent shrink-0"
              >
                <HelpIcon />
                Yardım
              </button>
            )}
          </div>
        </div>
      )}
      </div>
    </div>
  );
}
