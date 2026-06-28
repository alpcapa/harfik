// Harfik — rastgelelik yardımcıları

/** Fisher–Yates karıştırma. Diziyi yerinde karıştırır ve döndürür. */
export function shuffle<T>(a: T[]): T[] {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Diziden rastgele bir eleman seçer. */
export function pick<T>(a: T[]): T {
  return a[Math.floor(Math.random() * a.length)];
}
