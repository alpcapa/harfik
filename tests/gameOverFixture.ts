// Kelimeki — bitirme modalına ULAŞAN ortak kurulum + kutu ölçüm yardımcıları.
// İki spec dosyası paylaşıyor (`text-scale*.spec.ts`): `launchOptions`
// Playwright'ta DOSYA düzeyinde olmak zorunda (describe içinde kullanılamaz,
// yeni worker gerektiriyor), yani "asgari yazı boyutu açık/kapalı" iki ayrı
// dosya demek — yardımcıların kopyalanmaması için burada.
// `.spec.ts` DEĞİL: `testMatch` bu dosyayı toplamaz.
import { expect, type Page } from '@playwright/test';

/** Oyun bitmesine TEK pas kalmış bir kayıt — üretim reducer'ıyla kuruluyor
 *  (elle yazılmış fikstür şemadan sessizce kopar; `jokerliKayit`in dersi).
 *  2 oyuncu × MAX_PASS_ROUNDS(2) = 4 ardışık pas oyunu bitirir, yani 3'ten
 *  başlayıp bir kez "Pas Geç" demek yetiyor. */
async function bitmekUzereKayit(): Promise<string> {
  const { gameReducer, createInitialState } = await import('../src/game/gameReducer');
  const { TILE_DATA } = await import('../src/data/tiles');
  let s = gameReducer(createInitialState(), {
    type: 'START',
    players: [
      { name: 'Abdurrahman Çelebioğlu', isAI: false },
      { name: 'Yapay Zeka 2', isAI: true },
    ],
  });
  const raf = (harfler: string[]) => harfler.map((l) => ({ letter: l, pts: TILE_DATA[l].pts }));
  s = {
    ...s,
    current: 0,
    // Bir pas daha = oyun sonu.
    consecutivePasses: 3,
    players: s.players.map((p, i) =>
      i === 0
        ? { ...p, score: 271, rack: raf(['J', 'V']) } // kalan -18
        : { ...p, score: 189, rack: raf(['Z', 'F']) }, // kalan -11
    ),
  };
  return JSON.stringify({ version: 1, state: s, savedAt: Date.now() });
}

/** Kayıttan devam edip TEK pasla bitirme modalını açar. */
export async function bitirmeModali(page: Page): Promise<void> {
  await page.addInitScript(
    (payload) => {
      localStorage.setItem('kelimeki:game-state', payload as string);
      // Karşılama katmanı ve tanıtım araya girmesin.
      localStorage.setItem('kelimeki:seen-intro', '1');
    },
    await bitmekUzereKayit(),
  );
  await page.goto('/');
  await page.getByRole('button', { name: /SIRA SENDE/i }).click();
  const hizli = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await hizli.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }
  await page.getByRole('button', { name: 'Pas Geç' }).click();
  // Onay penceresindeki ikinci "Pas Geç".
  await page.getByRole('button', { name: 'Pas Geç' }).last().click();
  await expect(page.getByText('Oyun Bitti')).toBeVisible();
}

export interface KutuOlcumu {
  ad: string;
  /** Metnin dağıldığı satır kutusu sayısı — >1 ise SARMA (sınıf 3). */
  satir: number;
  /** Mürekkep genişliği (px) — kutudan büyükse TAŞMA (sınıf 1). */
  murekkep: number;
  kutu: number;
  metin: string;
}

/** Kutuların ölçüsü. Satır sayısı için `Range` kullanılıyor: element flex/grid
 *  öğesi olduğundan blok gibi davranıyor ve kendi `getClientRects()`i
 *  sarmadan bağımsız her zaman 1 dönüyor. */
export async function kutuOlcumleri(page: Page): Promise<KutuOlcumu[]> {
  return page.evaluate(() => {
    const kutular = document.querySelectorAll<HTMLElement>('[data-metin-kutusu]');
    return [...kutular].map((el) => {
      const r = document.createRange();
      r.selectNodeContents(el);
      const rects = [...r.getClientRects()];
      return {
        ad: el.dataset.metinKutusu!,
        satir: rects.length,
        murekkep: Math.max(0, ...rects.map((x) => x.width)),
        kutu: el.getBoundingClientRect().width,
        metin: (el.textContent ?? '').trim(),
      };
    });
  });
}
