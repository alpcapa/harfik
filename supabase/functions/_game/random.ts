// Kelimeki — rastgelelik yardımcıları
//
// src/utils/random.ts'in KOPYASI — bkz. types.ts'teki not. `play-ai-turn`
// yalnızca Normal oynatır (rastgele değer hiç tüketilmez); kopya burada
// çünkü `_game/ai.ts` `nextRandom`u import ediyor ve Faz 2'den sonra üç
// kopyanın DAVRANIŞI eşit olmalı (`verify-edge-engine-parity` Kolay'ı da
// tohumlayarak karşılaştırır).

let randomSource: () => number = Math.random;

/**
 * Rastgelelik kaynağını değiştirir (parametresiz çağrı Math.random'a döner).
 * ÜRETİM KODU BUNU HİÇ ÇAĞIRMAZ — tek kullanıcı, Flutter portunun golden
 * vector üreticisi (`scripts/generate-golden-vectors.ts`): tohumlu bir PRNG
 * takıp aynı oyunların Dart motorunda (mobile/kelimeki_core) bit-eş yeniden
 * oynatılabilmesini sağlar. Bkz. mobile/CLAUDE.md, "Golden vector" bölümü.
 */
export function setRandomSource(f?: () => number): void {
  randomSource = f ?? Math.random;
}

/**
 * Enjekte edilmiş kaynaktan [0, 1) aralığında bir sayı. Torba karıştırması
 * dışında tek tüketicisi YZ'nin Kolay seviyesi (`pickTopMove`, ai.ts) —
 * golden vector replay'i bu akışın SIRASINA dayanır, yeni bir tüketici
 * eklerken bunu bil (bkz. mobile/CLAUDE.md, "Golden Vector İş Akışı").
 */
export function nextRandom(): number {
  return randomSource();
}

/** Fisher–Yates karıştırma. Diziyi yerinde karıştırır ve döndürür. */
export function shuffle<T>(a: T[]): T[] {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(randomSource() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
