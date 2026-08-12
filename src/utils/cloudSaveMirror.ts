// Kelimeki — girişli kullanıcının devam eden YZ oyunları için yerel dayanıklılık
// katmanı (12 Ağustos 2026).
//
// SORUN: `App.tsx`'in autosave'i girişli kullanıcıda `clearGameState()` çağırıp
// YALNIZCA `local_game_saves`e yazıyordu; `upsertLocalGameSave` ağ hatasında
// `false` dönüp state'i DÜŞÜRÜYORDU — ne kuyruk ne yerel yedek vardı. Yani
// çevrimdışıyken oynanan her hamle sessizce kayboluyor, bağlantı dönünce oyun
// sunucudaki son senkron hâline geri düşüyordu. "Tarayıcı zaten offline
// çalışmaz" diye savunulamaz: uygulama kurulabilir bir PWA ve service worker
// asset'leri precache ettiğinden ana ekrana ekleyen biri offline'da oynayabiliyor.
//
// ÇÖZÜM, Flutter portunda kanıtlanmış write-behind ayna deseninin birebir
// karşılığı (bkz. `mobile/CLAUDE.md` Parça 38/43/46 ve `cloud_save_repo.dart`):
// önce yerele yaz, sonra sunucuyu dene, başarıda yereli sil. Normal (online)
// akışta bu depolar hep boş kalır — maliyeti yalnızca bir localStorage yazması.
//
// ÜÇ AYRI DEPO, üç ayrı soru:
//   1. mirror  — sunucuya YAZILAMAMIŞ state (kaynak kayıt; kaybolursa gerçek
//                veri kaybı).
//   2. cache   — sunucuda ZATEN duran satırların salt gösterim kopyası
//                (bozulursa en fazla offline liste eksik görünür).
//   3. deletes — sunucuda SİLİNEMEMİŞ satırların id'leri.
// Bu ayrım mobilde bilinçliydi ve burada da korunuyor: ikisini tek bir yapıya
// koymak, gösterim kopyasının bozulmasını gerçek veri kaybıyla aynı kefeye
// sokardı.
//
// ANAHTARLAR `kelimeki:game-state`ten AYRI olmak ZORUNDA: o anahtarı girişli
// kullanıcıda `clearGameState()` bilerek siliyor, çünkü aynı oyun hem
// localStorage hem `local_game_saves` üzerinden iki kez terk-edilmiş sayılıp
// MÜKERRER -2 cezası üretebilirdi. Ayna o silmeden etkilenmemeli.
import type { GameState } from '../game/types';

const MIRROR_KEY = 'kelimeki:cloud-save-mirror';
const CACHE_KEY = 'kelimeki:cloud-save-cache';
const DELETE_KEY = 'kelimeki:cloud-save-deletes';

/** Sunucuya yazılamamış bir oyun — `savedAt` yazma denemesinin anı (epoch ms). */
export interface MirroredSave {
  id: string;
  userId: string;
  state: GameState;
  savedAt: number;
}

/** Son başarılı listeden bir satır — offline'da listeyi çizebilmek için. */
export interface CachedSave {
  id: string;
  state: GameState;
  /** Sunucudaki `updated_at` (epoch ms) — ayna bindirmesinde karşılaştırılır. */
  updatedAt: number;
}

// ── Düşük seviye: localStorage'ı asla fırlatmadan oku/yaz ───────────────────
//
// localStorage kapalı (gizli sekme/kota dolu) olabilir. `gameStorage.ts` ile
// aynı ilke: okuma hatası "boş" sayılır, yazma hatası `false` döner — çağıran
// buna göre "ne sunucuya ne aynaya yazabildim" ayrımını yapabilsin.

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    const parsed = JSON.parse(raw) as T;
    // Bozuk/eski biçim: sessizce boş say. SİLMİYORUZ — teşhis için dursun,
    // bir sonraki başarılı yazma zaten üzerine yazacak.
    return parsed ?? fallback;
  } catch {
    return fallback;
  }
}

function writeJson(key: string, value: unknown): boolean {
  try {
    localStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

// ── 1. Ayna: sunucuya yazılamamış state ────────────────────────────────────

type MirrorMap = Record<string, MirroredSave>;

/**
 * Bir oyunu aynaya yazar (sunucu denemesinden ÖNCE çağrılır).
 * Dönüş `false` ise yerel yazma da başarısız — çağıran bunu "hiçbir yerde yok"
 * olarak loglamalı, sessizce yutmamalı.
 */
export function putMirroredSave(id: string, userId: string, state: GameState): boolean {
  const all = readJson<MirrorMap>(MIRROR_KEY, {});
  all[id] = { id, userId, state, savedAt: Date.now() };
  return writeJson(MIRROR_KEY, all);
}

/** Sunucuya başarıyla yazılan (ya da terk edilip silinen) bir oyunu aynadan düşürür. */
export function removeMirroredSave(id: string): void {
  const all = readJson<MirrorMap>(MIRROR_KEY, {});
  if (!(id in all)) return;
  delete all[id];
  writeJson(MIRROR_KEY, all);
}

/** Bu hesaba ait, sunucuya itilmeyi bekleyen aynalar. */
export function pendingMirroredSaves(userId: string): MirroredSave[] {
  const all = readJson<MirrorMap>(MIRROR_KEY, {});
  return Object.values(all).filter((m) => m && m.userId === userId && m.state && m.id);
}

// ── 2. Önbellek: son BAŞARILI listenin kopyası ─────────────────────────────

type CacheMap = Record<string, CachedSave[]>;

/**
 * Son başarılı listeyi saklar. Sunucu satırlarını değil BİRLEŞTİRİLMİŞ sonucu
 * yazıyoruz — "en son bilinen doğru liste" tam olarak bu; ayna bindirmesi
 * zaten uygulanmış oluyor.
 */
export function writeCloudSaveCache(userId: string, saves: CachedSave[]): void {
  const all = readJson<CacheMap>(CACHE_KEY, {});
  all[userId] = saves;
  writeJson(CACHE_KEY, all);
}

export function readCloudSaveCache(userId: string): CachedSave[] {
  const all = readJson<CacheMap>(CACHE_KEY, {});
  const rows = all[userId];
  return Array.isArray(rows) ? rows.filter((r) => r && r.id && r.state) : [];
}

// ── 3. Silme kuyruğu: sunucuda silinemeyen satırlar ────────────────────────
//
// Oyun bitince `deleteLocalGameSave` çağrılıyor; ağ yoksa bu düşüyor ve "bu
// satır silinmeli" bilgisi hiçbir yerde kalmıyordu. Sunucudaki BİTMEMİŞ eski
// kopya duruyor, bir sonraki liste onu "devam eden oyun" olarak geri getiriyor
// — üstelik listenin bitmiş satırları temizleyen dalı da devreye giremiyor,
// çünkü sunucudaki state hiç bitmiş hâle gelmemiş oluyor (mobil Parça 46).
//
// Kuyruk HESABA GÖRE kapsanmalı: başka bir hesap açıkken onun adına silme
// denemek RLS'te sessiz no-op olur ve kuyruk hiç boşalmazdı.

type DeleteMap = Record<string, string[]>;

export function queueCloudSaveDelete(id: string, userId: string): void {
  const all = readJson<DeleteMap>(DELETE_KEY, {});
  const ids = Array.isArray(all[userId]) ? all[userId] : [];
  if (ids.includes(id)) return;
  all[userId] = [...ids, id];
  writeJson(DELETE_KEY, all);
}

export function pendingCloudSaveDeletes(userId: string): string[] {
  const all = readJson<DeleteMap>(DELETE_KEY, {});
  return Array.isArray(all[userId]) ? all[userId].filter((x) => typeof x === 'string') : [];
}

export function unqueueCloudSaveDelete(id: string, userId: string): void {
  const all = readJson<DeleteMap>(DELETE_KEY, {});
  const ids = Array.isArray(all[userId]) ? all[userId] : [];
  if (!ids.includes(id)) return;
  all[userId] = ids.filter((x) => x !== id);
  writeJson(DELETE_KEY, all);
}

// ── Sınıflandırma: hangi kayıt aktif, hangisi süresi dolmuş? ───────────────
//
// Bu iki fonksiyon BİLEREK saf: ağ/localStorage/React yok, yalnızca girdi →
// karar. Bu özelliğin riski tam olarak burada — mobilde açılıp aynı gün
// kapatılan üç gedik (bkz. dosya başı) hep bu kurallardaydı. Saf olduklarından
// bir betikle doğrudan sınanabiliyorlar (`scripts/verify-cloud-save-mirror.ts`).

export interface ServerRowLike {
  id: string;
  state: GameState;
  /** Sunucudaki `updated_at`, epoch ms. */
  updatedAt: number;
}

export interface CloudSaveClassification {
  /** Listede gösterilecek satırlar (ayna bindirmesi UYGULANMIŞ), yeniden eskiye. */
  active: ServerRowLike[];
  /** Sunucuda süresi dolmuş — `claimAbandonedLocalGameSave` ile iddia edilmeli. */
  expired: ServerRowLike[];
  /** Sunucuda duran ama bitmiş/oynanmayan satırlar — fırsatçı silinmeli. */
  finished: string[];
  /** Yalnızca aynada olup süresi dolmuş oyunlar — doğrudan cezaya çevrilir. */
  orphanExpired: MirroredSave[];
  /** Yalnızca aynada olup artık oynanmayan (bitmiş) oyunlar — sessizce silinir. */
  orphanFinished: string[];
}

function isLive(state: GameState): boolean {
  return state.phase === 'play' && !state.isGameOver;
}

/**
 * Sunucu satırları + bekleyen aynalar → ne yapılacağının kararı.
 *
 * **Ayna bindirmesi terk-edilme kararından ÖNCE uygulanır** — aksi halde dün
 * offline oynanmış bir oyun, sunucudaki satırı 7 günden eski diye haksız yere
 * -2 cezasıyla süpürülürdü (mobilde bu gedik açılıp aynı gün kapatılmıştı).
 *
 * Sunucunun HİÇ görmediği (tamamen offline açılmış) oyunlar da 7 gün kuralına
 * tabi: sunucu satırı olmadığından iddia edilecek bir şey yok, ama ayna zaten
 * CİHAZA ÖZEL olduğundan yarış da yok — doğrudan cezaya çevrilirler.
 */
export function classifyCloudSaves(
  rows: ServerRowLike[],
  mirrors: MirroredSave[],
  cutoffMs: number,
): CloudSaveClassification {
  const pending = new Map(mirrors.map((m) => [m.id, m]));
  const out: CloudSaveClassification = {
    active: [],
    expired: [],
    finished: [],
    orphanExpired: [],
    orphanFinished: [],
  };
  for (const row of rows) {
    if (!isLive(row.state)) {
      out.finished.push(row.id);
      pending.delete(row.id);
      continue;
    }
    const mine = pending.get(row.id);
    pending.delete(row.id);
    const effective =
      mine && mine.savedAt > row.updatedAt
        ? { id: row.id, state: mine.state, updatedAt: mine.savedAt }
        : row;
    if (effective.updatedAt > cutoffMs) out.active.push(effective);
    else out.expired.push(effective);
  }
  for (const m of pending.values()) {
    if (!isLive(m.state)) out.orphanFinished.push(m.id);
    else if (m.savedAt > cutoffMs) out.active.push({ id: m.id, state: m.state, updatedAt: m.savedAt });
    else out.orphanExpired.push(m);
  }
  out.active.sort((a, b) => b.updatedAt - a.updatedAt);
  return out;
}

/**
 * Sunucuya ulaşılamadığında gösterilecek liste: son başarılı önbellek + ayna.
 * Hiçbiri yoksa `null` — çağıran "liste alınamadı"yı koruyabilsin diye
 * (UI yanlışlıkla "hiç oyunun yok" göstermesin).
 *
 * **Bu dalda ceza HİÇ uygulanmaz** ve süresi geçmiş satır listeye ALINMAZ:
 * bir satırın gerçekten terk edilip edilmediği sunucuyla doğrulanmadan
 * bilinemez (başka bir cihaz oynamış olabilir) ve claim'in yarış koruması
 * offline çalışamaz.
 */
export function mergeOfflineCloudSaves(
  cached: CachedSave[],
  mirrors: MirroredSave[],
  cutoffMs: number,
): ServerRowLike[] | null {
  if (cached.length === 0 && mirrors.length === 0) return null;
  const byId = new Map<string, ServerRowLike>();
  for (const c of cached) byId.set(c.id, { id: c.id, state: c.state, updatedAt: c.updatedAt });
  // Ayna KOŞULSUZ kazanır — sunucu satırına karşı kullanılan "daha yeniyse"
  // koruması burada YANLIŞ olur: orada ayna BAŞKA bir cihazın yazdığı satırdan
  // eski olabilir, burada ise karşı taraf BU cihazın kendi önbelleği. Bekleyen
  // bir ayna, tanımı gereği son başarılı yazmadan sonra yapılmış ve sunucuya
  // ulaşmamış bir değişikliktir; damgalar eşit olsa bile (aynı tick) ayna
  // doğrudur. (Mobilde ilk sürüm `>` kullanıp eşit damgalarda offline
  // hamleleri GİZLEMİŞTİ.)
  for (const m of mirrors) byId.set(m.id, { id: m.id, state: m.state, updatedAt: m.savedAt });
  const rows = [...byId.values()].filter((r) => isLive(r.state) && r.updatedAt > cutoffMs);
  rows.sort((a, b) => b.updatedAt - a.updatedAt);
  return rows;
}
