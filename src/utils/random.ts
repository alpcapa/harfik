// Kelimeki — rastgelelik yardımcıları

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

/** Fisher–Yates karıştırma. Diziyi yerinde karıştırır ve döndürür. */
export function shuffle<T>(a: T[]): T[] {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(randomSource() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
