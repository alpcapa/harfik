// Kelimeki — devam eden oyunu (phase==='play') localStorage'a otomatik kaydeder.
// Tarayıcı/uygulama kapatılıp yeniden açıldığında kaldığı yerden devam
// edilebilsin diye: aksi halde biri kaybetmek üzereyken sekmeyi kapatıp
// "teslim ol"un -2 cezasından kaçabilirdi (bkz. proje notları). 7 gün boyunca
// hiç dönülmezse oyun burada terk edilmiş sayılıp silinir — App.tsx bu
// durumda da (oyun gerçekten başlamışsa) aynı -2 cezasını uygular, yani
// kapat-aç-hiç-dönme de bir kaçış yolu değildir.
import type { GameState } from '../game/types';

const STORAGE_KEY = 'kelimeki:game-state';
// Kaydedilen state'in şekli değişirse (yeni zorunlu alan vb.) eski
// kayıtları sessizce geçersiz saymak için.
const STORAGE_VERSION = 1;

// Bir oyun bu kadar süre hiç kaydedilmeden (yani hiç hamle yapılmadan)
// localStorage'da beklerse terk edilmiş sayılır: bir sonraki açılışta
// silinir ve admin panelinin Büyüme > Oyun grafiğine "terk edilen" olarak
// düşer. Süre son KAYIT anından itibaren sayılır (oyunun başladığı andan
// değil) — yoksa gerçekten günler süren çok-oturumlu bir oyunu da hatalı
// biçimde terk edilmiş sayardık.
// Setup'taki "Devam Eden Oyun" satırında kalan gün sayısını göstermek için
// (bkz. App.tsx/Setup.tsx) dışa da açık.
export const ABANDON_TIMEOUT_MS = 7 * 24 * 60 * 60 * 1000;

const PENDING_ABANDON_KEY = 'kelimeki:pending-abandoned-game';

interface StoredPayload {
  version: number;
  state: GameState;
  /** Bu kaydın en son yazıldığı an (epoch ms) — terk edilme süresini ölçmek için. */
  savedAt?: number;
}

export interface PendingAbandonedGame {
  playerCount: number;
  durationSeconds: number;
  multiSession: boolean;
  /**
   * Terk edilip silinen tam GameState — App.tsx bunu, oyun gerçekten
   * başlamışsa (`turnCount>=2`, mevcut "Çık" akışındaki `gameStarted` ile
   * aynı eşik) hesap sahibi için bir teslim kaydı (-2 Sanal Lig cezası)
   * oluşturmak için kullanır. `saveGameState` her zaman bunu doldurur —
   * yalnızca çok eski (bu alan eklenmeden önceki) bir kayıt hâlâ
   * localStorage'da bekliyorsa teorik olarak eksik olabilir.
   */
  state?: GameState;
}

export interface SavedGame {
  state: GameState;
  /** Bu kaydın en son yazıldığı an (epoch ms) — kalan gün sayısını göstermek için. */
  savedAt: number;
}

/** Devam eden oyunu kaydeder. localStorage kapalı/dolu olabilir — sessizce yok sayılır. */
export function saveGameState(state: GameState): void {
  try {
    const payload: StoredPayload = { version: STORAGE_VERSION, state, savedAt: Date.now() };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  } catch {
    // yoksay
  }
}

export function clearGameState(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // yoksay
  }
}

/** Bitmemiş bir oyun varsa geri yükler; yoksa, bittiyse ya da bozuksa null döner. */
export function loadGameState(): SavedGame | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as StoredPayload;
    if (parsed.version !== STORAGE_VERSION) return null;
    const state = parsed.state;
    if (
      !state ||
      state.phase !== 'play' ||
      state.isGameOver ||
      !Array.isArray(state.players) ||
      state.players.length === 0
    ) {
      return null;
    }
    // Bu alanlar eklenmeden önce kaydedilmiş bir state'te olmayabilir.
    state.players = state.players.map((p) => ({ ...p, surrendered: p.surrendered ?? false }));
    state.startedAt = state.startedAt || new Date().toISOString();

    // savedAt eklenmeden önceki kayıtlarda bu alan yoktur — "az önce
    // kaydedildi" varsayılır ki mevcut bir oyuncu deploy sonrası ilk açılışta
    // hatalı biçimde terk edilmiş sayılmasın.
    const savedAt = parsed.savedAt ?? Date.now();
    if (Date.now() - savedAt > ABANDON_TIMEOUT_MS) {
      queuePendingAbandonedGame({
        playerCount: state.players.length,
        durationSeconds: Math.max(0, Math.round((savedAt - Date.parse(state.startedAt)) / 1000)),
        multiSession: state.multiSession,
        state,
      });
      clearGameState();
      return null;
    }

    // Buraya ulaşmak, uygulamanın (bu oyun bitmeden) yeniden başlatılıp
    // localStorage'dan kaldığı yerden devam ettiği anlamına gelir — bu oyun
    // artık "çok oturumlu" sayılır, geri dönüşü yoktur.
    state.multiSession = true;
    return { state, savedAt };
  } catch {
    return null;
  }
}

function queuePendingAbandonedGame(record: PendingAbandonedGame): void {
  try {
    localStorage.setItem(PENDING_ABANDON_KEY, JSON.stringify(record));
  } catch {
    // yoksay
  }
}

/**
 * Bir önceki `loadGameState()` çağrısı 7 gün hareketsizlik yüzünden bir
 * oyunu terk edilmiş sayıp sildiyse, o oyunun kaydı burada tek seferlik
 * okunup temizlenir — çağıran (App.tsx) bunu `logGameFinish(..., completed:
 * false)` ile sunucuya bildirir, ve oyun gerçekten başlamışsa (bkz.
 * `PendingAbandonedGame.state`) hesap sahibi için bir teslim kaydı (-2 Sanal
 * Lig cezası, `buildGameRecord`/`saveGameDurable`) oluşturur — tıpkı oyun
 * içindeki "Çık" ile teslim olmak gibi, yalnızca gecikmeli/örtük. Kuyruk
 * boşsa null döner.
 */
export function takePendingAbandonedGame(): PendingAbandonedGame | null {
  try {
    const raw = localStorage.getItem(PENDING_ABANDON_KEY);
    if (!raw) return null;
    localStorage.removeItem(PENDING_ABANDON_KEY);
    return JSON.parse(raw) as PendingAbandonedGame;
  } catch {
    return null;
  }
}
