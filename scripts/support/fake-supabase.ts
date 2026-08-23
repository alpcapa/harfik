// `src/lib/supabase` yerine geçen sahte istemci — YALNIZCA doğrulama
// betiklerinde kullanılır (esbuild `--alias` ile takılır, üretim paketine
// hiç girmez).
//
// Zincirlenebilir sorgu kurucusu (`from().select().eq().order().range()`)
// gerçek postgrest-js'in çağrı şeklini taklit ediyor; en sondaki `await`
// `{ data, error }` döndürüyor — postgrest-js fetch reddini de tam olarak
// böyle bir `error` nesnesine çeviriyor (kaynaktan doğrulandı), yani
// çevrimdışı davranışı bu sahteyle temsil edilebiliyor.

/** PostgREST hatası: `code` de taşınabiliyor (ör. 42501 = yetki yok). */
type Err = { message: string; code?: string };

export interface FakeSpec {
  /**
   * Çevrimdışı: AĞA GİDEN her şey düşer. Bu bayrak KRİTİK — sahte uç gerçek
   * ucun hata yollarını taklit etmezse, o yol hakkındaki testler sessizce
   * anlamsız kalır (bu betiğin ilk sürümünde tam olarak bu oldu: `getUser()`
   * yereldenmiş gibi cevaplanıyordu, dolayısıyla negatif eş kullanıcının
   * bildirdiği hatayı ÜRETEMİYORDU).
   *
   * Neyin ağa gittiği auth-js/postgrest-js kaynağından doğrulandı:
   *  - `getUser()`  → HER ZAMAN `GET /auth/v1/user` (ağ) → çevrimdışı null
   *  - `getSession()` → yerel depo (ağ YOK) → çevrimdışı da oturumu döner
   *  - `from().select()` / `rpc()` → ağ; postgrest-js fetch reddini
   *    `{data:null, error}`a çeviriyor (fırlatMIYOR)
   */
  offline?: boolean;
  /** null: oturum yok. Verilirse `getSession()` bunu döndürür (yerel okuma). */
  session?: { user: { id: string } } | null;
  /** `getSession()` hatası — süresi geçmiş token çevrimdışı tazelenemiyor. */
  sessionError?: Err;
  /** `from('games').select(...)` sonucu (çevrimiçi). */
  rows?: Record<string, unknown>[];
  /** RPC adı → veri (çevrimiçi). */
  rpcData?: Record<string, unknown[]>;
  /** Çevrimiçiyken belirli bir RPC'nin düşmesi (ör. yalnız rozet RPC'si). */
  rpcError?: Record<string, Err>;
  /** true: `supabase` null (anahtarlar yapılandırılmamış). */
  noClient?: boolean;
  /**
   * Kaçıncı AĞ çağrılarının düşeceği (1'den başlayarak, `from`+`rpc` ortak
   * sayaç). Yeniden deneme mantığını ölçmek için: `[1]` = ilk deneme düşer,
   * ikincisi başarılı olmalı. `offline` her çağrıyı düşürür; bu ise
   * "geçici" düşmeyi (ağ değişiminde iptal edilen fetch) temsil ediyor.
   */
  failCalls?: number[];
}

const NET: Err = { message: 'TypeError: Failed to fetch' };

let spec: FakeSpec = {};
let netCalls = 0;

/**
 * O ana kadar yapılan ağ çağrısı sayısı (`from` + `rpc`). Yeniden denemenin
 * GERÇEKTEN olup olmadığını ölçmek için — "sonuç doğru geldi" tek başına
 * retry'ın çalıştığını kanıtlamaz.
 */
export function __netCalls(): number {
  return netCalls;
}

/** Bu çağrı düşecek mi? Sayacı da ilerletir. */
function shouldFail(): boolean {
  netCalls += 1;
  if (spec.offline) return true;
  return (spec.failCalls ?? []).includes(netCalls);
}

export function __setFake(next: FakeSpec): void {
  spec = next;
  netCalls = 0;
  // `api.ts` `if (!supabase)` diye bakıyor; bir Proxy her zaman truthy
  // olduğundan o dal ancak GERÇEKTEN null atayarak test edilebilir.
  // ESM canlı bağlaması sayesinde yeniden atama import edene de yansıyor.
  supabase = next.noClient ? null : (client as unknown as Record<string, unknown>);
}

function builder() {
  const result = () =>
    shouldFail() ? { data: null, error: NET } : { data: spec.rows ?? [], error: null };
  const chain: Record<string, unknown> = {};
  for (const m of ['select', 'eq', 'is', 'not', 'order', 'range', 'in', 'limit']) {
    chain[m] = () => chain;
  }
  // Zincirin sonundaki `await` — thenable.
  chain.then = (resolve: (v: unknown) => unknown) => Promise.resolve(result()).then(resolve);
  return chain;
}

const client = {
  auth: {
    getSession: async () => ({
      data: { session: spec.session ?? null },
      error: spec.sessionError ?? null,
    }),
    // Gerçek `getUser()` ağa gidiyor → çevrimdışıyken kullanıcı YOK.
    // Eski kodun kırıldığı yer tam burasıydı.
    getUser: async () =>
      spec.offline
        ? { data: { user: null }, error: NET }
        : { data: { user: spec.session?.user ?? null }, error: null },
  },
  from: () => builder(),
  rpc: async (name: string) => {
    if (shouldFail()) return { data: null, error: NET };
    const err = spec.rpcError?.[name];
    if (err) return { data: null, error: err };
    return { data: spec.rpcData?.[name] ?? [], error: null };
  },
};

export const isSupabaseConfigured = true;
// eslint-disable-next-line prefer-const -- `__setFake` yeniden atıyor (canlı bağlama).
export let supabase: Record<string, unknown> | null =
  client as unknown as Record<string, unknown>;
