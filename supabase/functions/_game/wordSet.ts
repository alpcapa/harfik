// Kelimeki — kelime listesini `public.words` tablosundan çeker.
//
// Tarayıcıdaki src/data/words.ts (~880KB statik dosya, ~63k kelime) burada
// BÜNDLE EDİLMİYOR — bunun yerine, sunucu tarafı doğrulamanın (is_valid_word
// RPC) zaten kullandığı AYNI kaynak olan `public.words` tablosu (65k+ satır)
// service role ile (RLS'i bypass ederek — `words` tablosunda hiç policy
// olmadığından anon/authenticated için zaten tamamen kapalı) bir kez
// sorgulanıp modül seviyesinde önbelleğe alınır — böylece hem gereksiz bir
// ~63k kelimelik ikinci kopya bakımı gerekmez hem de Edge Function paketi
// küçük kalır. `loadWordSet` her isolate'te (soğuk başlangıç) bir kez
// çağrılmalı (bkz. index.ts), sonrasında senkron `getWordSet()` kullanılabilir
// — ai.ts/validator.ts'in tarayıcı sürümüyle aynı senkron imzayı koruması için.
import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';

let cached: ReadonlySet<string> | undefined;

// PostgREST tek bir `select()`i, `range()` verilmese bile projenin
// `db-max-rows` ayarına (varsayılan 1000) sessizce kırpar — 63.890 satırlık
// `words` tablosunda bu, kelime havuzunun ~%98'inin hiç yüklenmediği anlamına
// geliyordu (bulundu: YZ ilk hamlesinde art arda iki kez, aslında geçerli
// köşe-değen kelimeler mevcutken taş değiştirmeye zorlanmıştı — rastgele
// 1000 kelimelik bir alt kümede 7 harften bir eşleşme bulma ihtimali çok
// düşük). Düzeltme: son sayfa PAGE_SIZE'tan az satır dönene kadar `range()`
// ile sayfalı çekiyoruz — sayfa boyutunu bilinen/güvenli varsayılanın
// altında tutmak, sunucunun gerçek üst sınırından bağımsız çalışmayı sağlıyor.
const PAGE_SIZE = 1000;

export async function loadWordSet(serviceClient: SupabaseClient): Promise<ReadonlySet<string>> {
  if (cached) return cached;
  const words = new Set<string>();
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await serviceClient
      .from('words')
      .select('word')
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(`Kelime listesi okunamadı: ${error.message}`);
    for (const r of data ?? []) words.add((r as { word: string }).word);
    if (!data || data.length < PAGE_SIZE) break;
  }
  cached = words;
  return cached;
}

export function getWordSet(): ReadonlySet<string> {
  if (!cached) {
    throw new Error('Kelime listesi henüz yüklenmedi — önce loadWordSet() çağrılmalı.');
  }
  return cached;
}
