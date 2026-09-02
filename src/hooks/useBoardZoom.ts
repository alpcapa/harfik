// Kelimeki — tahta yakınlaştırmasının React kabuğu (iki oyun ekranı için).
//
// Port ikizi: iki ekranın `_zoom`/`_panRef`/`_boardTapDown` alanları
// (`game_screen.dart` ↔ `online_game_screen.dart`). Web'de aynı deseni İKİ
// dosyaya kopyalamak yerine tek hook'a çıkarıldı — App.tsx ile
// OnlineGameScreen.tsx'in sessizce ayrışması bu projenin kayıtlı hata
// sınıfı; hook o riski yapısal olarak kapatıyor.
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  BOARD_ZOOM_SCALE,
  DoubleTapDetector,
  PAN_SWALLOW_MS,
  panZoom,
  toggleZoom,
  ZOOM_OFF,
  type ZoomState,
} from '../utils/boardZoom';
import { swallowNextClick } from '../utils/ghostClick';
import {
  bumpZoomHintShown,
  markZoomTried,
  shouldShowZoomHint,
} from '../utils/onboarding';

export type BoardZoom = {
  zoom: ZoomState;
  viewportRef: React.RefObject<HTMLDivElement>;
  /** Tahtanın görünür karesine bağlanacak pointer kancaları. */
  onPointerDown: (e: React.PointerEvent) => void;
  onPointerMove: (e: React.PointerEvent) => void;
  onPointerUp: () => void;
  onPointerCancel: () => void;
  /**
   * Bir HÜCRE dokunuşunun BAŞINDA çağrılır. `true` → dokunuşun kendi işlemi
   * YUTULMALI (çiftin ikincisiydi ya da pan artığıydı).
   */
  registerCellTap: (x: number, y: number) => boolean;
  /** Boş kareye düşen dokunuş — sonraki dokunuş bununla çift oluşturabilir. */
  registerPairable: (x: number, y: number) => void;
  /** Taşa dokunuş / raf / gerçek sürükleme — çift zincirini kırar. */
  markUnpairable: () => void;
  /** Yeni oyun / rövanş. */
  reset: () => void;
  /** Pan sürerken sayfanın kaymaması için (dokunmatik). */
  panning: boolean;
  /** Tanıtım balonu bu açılışta gösterilsin mi (bkz. utils/onboarding). */
  hint: boolean;
};

/**
 * @param dragActive Taş sürüklemesi yaşıyor mu — DOLUYSA pan hiç başlamaz.
 *   (Portta bu ayrım hit-test sırasıyla oluyordu: çocuk taş Listener'ı
 *   `_dragRef`i ata Listener'dan ÖNCE dolduruyor. Web'de olay yine önce
 *   taşın kendi handler'ına gittiğinden aynı sıra geçerli, ama bayrağı
 *   AÇIKÇA sormak daha okunur.)
 */
/**
 * @param boardVisible Tahta ŞU AN ekranda mı — tanıtım balonunun gösterim
 *   sayacı yalnızca tahta görünürken artmalı. **Ölçüldü (1 Eylül 2026,
 *   kullanıcı preview'da fark etti: "misafirde çalışmıyor mu?"):** `App`
 *   bileşeni Setup ekranını da render ettiğinden hook Setup'ta da mount
 *   oluyordu ve sayaç tahta HİÇ GÖRÜNMEDEN 1 oluyordu; siteyi iki kez açıp
 *   oyun açmayan kullanıcıda tavan doluyor, balon bir daha hiç çıkmıyordu.
 *   Sorun misafir/girişli ayrımı DEĞİLDİ — herkeste vardı. Portta bu hata
 *   yok, çünkü `GameScreen` ayrı bir route ve karar `initState`'te veriliyor
 *   (tahta zaten görünür); web'de o "ekran sınırı" olmadığından açıkça
 *   sormak gerekiyor.
 */
export function useBoardZoom(
  dragActive: () => boolean,
  boardVisible = true,
): BoardZoom {
  const [zoom, setZoom] = useState<ZoomState>(ZOOM_OFF);
  // Tanıtım balonu (1 Eylül 2026, kullanıcı isteği) — karar EKRAN AÇILIRKEN
  // bir kez veriliyor ve o an sayaç artıyor: "gösterim" balonun ekrana
  // gelmesidir, nasıl kapandığı sayacı etkilemez. Port ikizi: iki oyun
  // ekranının `_zoomHintKarariVer`i.
  const [hint, setHint] = useState(false);
  // ⚠ MÜKERRER-ÇALIŞMA KİLİDİ: React StrictMode dev'de effect'i İKİ KEZ
  // çalıştırıyor ve sayaç bir açılışta 2 artıyordu — Playwright ölçtü
  // (beklenen 1, gelen 2), yani balon ilk oyunda tavana çarpıp ikinci
  // gösterimi kaybediyordu. Aynı kilit deseni App.tsx'te de var
  // (`migratingSavedGameRef`); sayaç artıran her effect buna muhtaç.
  const hintDecided = useRef(false);
  useEffect(() => {
    // Tahta görünene kadar KARAR VERİLMEZ: "gösterim" balonun ekrana
    // gelmesidir (yukarıdaki `boardVisible` notu — ölçülmüş hata).
    if (!boardVisible || hintDecided.current) return;
    hintDecided.current = true;
    if (!shouldShowZoomHint()) return;
    bumpZoomHintShown();
    setHint(true);
  }, [boardVisible]);
  const [panning, setPanning] = useState(false);
  const detector = useRef(new DoubleTapDetector());
  const panRef = useRef<{ x: number; y: number; moved: boolean } | null>(null);
  // Tahta dokunuş ADAYI: hücre kutusuna DÜŞMEYEN (boşluk/çerçeve) dokunuşlar
  // da çift dokunuş jestine sayılsın diye. Karar İNİŞ noktasına göre verilir
  // — hücreye inip boşlukta kalkan parmakta hücrenin kendi `onClick`i YİNE
  // ateşler; kalkışa bakmak aynı dokunuşu iki kez saydırırdı.
  const tapDown = useRef<{ x: number; y: number; onCell: boolean } | null>(null);
  const swallowUntil = useRef(0);

  const boxOf = useRef<HTMLDivElement>(null);

  const toggleAt = useCallback((clientX: number, clientY: number) => {
    const el = boxOf.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    setZoom((z) => {
      // Odak, ÖLÇEKSİZ yerel uzayda olmalı: zoom açıkken kutu zaten
      // ölçekli çizildiğinden ters çevrilir. (Kapatmada odak kullanılmaz.)
      const localX = z.zoomed
        ? (clientX - r.left - z.x) / BOARD_ZOOM_SCALE
        : clientX - r.left;
      const localY = z.zoomed
        ? (clientY - r.top - z.y) / BOARD_ZOOM_SCALE
        : clientY - r.top;
      detector.current.reset();
      return toggleZoom(z, localX, localY, r.width, r.height);
    });
    // Kullanıcı zoom'u DENEDİ: balon anında kapanır ve kalıcı olarak susar
    // (kullanıcı isteği: "Deneme gösterimi bitirir").
    setHint(false);
    markZoomTried();
  }, []);

  const registerCellTap = useCallback(
    (x: number, y: number) => {
      if (Date.now() < swallowUntil.current) return true;
      if (!detector.current.tryCompletePair(x, y)) return false;
      toggleAt(x, y);
      return true;
    },
    [toggleAt],
  );

  const onPointerDown = useCallback(
    (e: React.PointerEvent) => {
      if (dragActive()) return; // taş jesti sahiplendi
      const onCell = !!(e.target as Element | null)?.closest?.('[data-cell]');
      tapDown.current = { x: e.clientX, y: e.clientY, onCell };
      if (!zoom.zoomed || panRef.current) return;
      panRef.current = { x: e.clientX, y: e.clientY, moved: false };
      setPanning(true);
    },
    [dragActive, zoom.zoomed],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent) => {
      const d = tapDown.current;
      if (d && Math.hypot(e.clientX - d.x, e.clientY - d.y) >= 10) {
        tapDown.current = null; // hareket etti: dokunuş adayı düştü
      }
      const p = panRef.current;
      if (!p) return;
      if (!p.moved) {
        if (Math.hypot(e.clientX - p.x, e.clientY - p.y) < 10) return;
        p.moved = true;
      }
      const dx = e.clientX - p.x;
      const dy = e.clientY - p.y;
      p.x = e.clientX;
      p.y = e.clientY;
      const el = boxOf.current;
      if (!el) return;
      const r = el.getBoundingClientRect();
      // ⚠ BURADA `/ BOARD_ZOOM_SCALE` YOK ve OLMAMALI. İlk sürümde vardı,
      // gerekçesi "kutu zoom'lu ölçülüyor" diye yazılmıştı — YANLIŞTI:
      // `boxOf` GÖRÜNÜR KARE (`absolute inset-0`) ve ölçeklenen o değil
      // İÇİNDEKİ ızgara, yani bu dikdörtgen her zaman ölçeksiz. Bölme
      // izinli öteleme menzilini yarıya indiriyordu ve tahtanın alt/sağ
      // yarısına ASLA kaydırılamıyordu (bir kullanıcı gerçek oyunda
      // bildirdi: *"zoom yapınca alt kısım altta kalıyor ve görünmüyor"*).
      // ÖLÇÜLDÜ (390 px, kare 366 px): en uç öteleme −183 px'te
      // duruyordu, doğrusu −366. `toggleAt` doğru menzili kullandığından
      // odaklı açılış çalışıyor, sonra ilk pan onu geri ZIPLATIYORDU.
      // Port ikizinde böyle bir bölme hiç olmadı (`panBy(delta, gridSize)`).
      // Kapı: smoke.spec.ts → "zoom açıkken SONA kadar kaydırılabilir".
      setZoom((z) => panZoom(z, dx, dy, r.width, r.height));
    },
    [],
  );

  const endPan = useCallback(() => {
    const p = panRef.current;
    panRef.current = null;
    tapDown.current = null;
    if (!p) return;
    setPanning(false);
    if (p.moved) {
      // Pan'in artığı click'i yut (mevcut hayalet-click mekanizması) VE
      // zaman penceresiyle çifti kır — bayrak tek başına yetmez, aynı
      // jestten birden fazla artık olay gelebilir.
      swallowNextClick();
      swallowUntil.current = Date.now() + PAN_SWALLOW_MS;
      detector.current.markUnpairable();
    }
  }, []);

  const onPointerUp = useCallback(
    () => {
      const d = tapDown.current;
      endPan();
      if (!d) return;
      // Hücreye İNEN dokunuş hücrenin kendi `onClick`inin işi (orada
      // `registerCellTap` çağrılıyor); burada da saymak tek dokunuşu çift
      // gösterirdi. Boşluğa/çerçeveye inen ise TAHTA dokunuşudur.
      if (d.onCell) return;
      if (registerCellTap(d.x, d.y)) return;
      detector.current.registerPairableTap(d.x, d.y);
    },
    [endPan, registerCellTap],
  );

  const reset = useCallback(() => {
    detector.current.reset();
    panRef.current = null;
    tapDown.current = null;
    setPanning(false);
    setZoom(ZOOM_OFF);
  }, []);

  // Ekran değişimi/oyun sonu gibi durumlarda asılı kalan pan temizlensin.
  useEffect(() => () => {
    panRef.current = null;
  }, []);

  return {
    zoom,
    viewportRef: boxOf,
    onPointerDown,
    onPointerMove,
    onPointerUp,
    onPointerCancel: endPan,
    registerCellTap,
    registerPairable: (x, y) => detector.current.registerPairableTap(x, y),
    markUnpairable: () => detector.current.markUnpairable(),
    reset,
    panning,
    hint,
  };
}
