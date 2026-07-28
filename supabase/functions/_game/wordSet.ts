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

export async function loadWordSet(serviceClient: SupabaseClient): Promise<ReadonlySet<string>> {
  if (cached) return cached;
  const { data, error } = await serviceClient.from('words').select('word');
  if (error) throw new Error(`Kelime listesi okunamadı: ${error.message}`);
  cached = new Set((data ?? []).map((r: { word: string }) => r.word));
  return cached;
}

export function getWordSet(): ReadonlySet<string> {
  if (!cached) {
    throw new Error('Kelime listesi henüz yüklenmedi — önce loadWordSet() çağrılmalı.');
  }
  return cached;
}
