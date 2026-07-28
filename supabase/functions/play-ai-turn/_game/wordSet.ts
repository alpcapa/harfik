// Kelimeki — kelime listesini senkron döner.
//
// Tarayıcıdaki src/data/wordSetLoader.ts, WORD_SET'i ayrı bir chunk'a
// bölüp gecikmeli/lazy yükler (bkz. o dosyadaki yorum) — Edge Function'da
// chunk-splitting'e gerek yok, fonksiyon her çağrıldığında zaten tüm
// modülü senkron olarak import ediyor. `getWordSet()` imzası ai.ts/
// validator.ts'in beklediğiyle aynı kalsın diye burada da aynı isimle var.
import { WORD_SET } from './words.ts';

export function getWordSet(): ReadonlySet<string> {
  return WORD_SET;
}
