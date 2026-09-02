// Kelimeki — bitirme modalı sütunları NORMAL yazı ölçeğinde.
// Kardeşi `text-scale.spec.ts` asgari-yazı-boyutu bayrağıyla koşuyor; o
// bayrak `launchOptions`ta ve Playwright onu dosya düzeyinde istiyor, bu
// yüzden iki dosya.
import { test, expect } from '@playwright/test';
import { bitirmeModali, kutuOlcumleri } from './gameOverFixture';

test.use({ viewport: { width: 390, height: 844 } });

// Izgaraya geçiş NORMAL ölçekte hiçbir şeyi değiştirmemeli: sütun
// genişlikleri ve aralarındaki BİLİNÇLİ asimetrik boşluklar (ml-1/ml-2/ml-1,
// 21 Ağustos 2026 kullanıcı isteği) korunuyor mu? `auto` sütunlar zaten
// "her kutu kendi en geniş içeriğine eşit" kuralını uyguladığından elle
// yazılmış 29/37/20 px ile aynı sayıları vermeli — bu test onu KANITLIYOR,
// yoksa düzeltme sessizce görünümü kaydırabilirdi.
test('Normal ölçekte sütun genişlikleri ve sağa yaslama DEĞİŞMEDİ', async ({ page }) => {
  await bitirmeModali(page);
  const kutular = await kutuOlcumleri(page);
  const bul = (ad: string) => kutular.find((k) => k.ad === ad)!;

  // Elle yazılmış eski px değerleri (mürekkep ölçüsüyle türetilmişti).
  expect(bul('kalan-baslik').kutu).toBeCloseTo(29, 0);
  expect(bul('toplam-baslik').kutu).toBeCloseTo(37, 0);
  expect(bul('klig-baslik').kutu).toBeCloseTo(20, 0);

  // Sağa yaslama: her sütunda metnin sağ kenarı kutunun sağ kenarıyla aynı.
  const yasli = await page.evaluate(() =>
    [...document.querySelectorAll<HTMLElement>('[data-metin-kutusu]')].every((el) => {
      const r = document.createRange();
      r.selectNodeContents(el);
      const m = r.getBoundingClientRect();
      const k = el.getBoundingClientRect();
      return m.width === 0 || Math.abs(m.right - k.right) < 0.5;
    }),
  );
  expect(yasli, 'sütunlar sağa yaslı olmalı').toBe(true);

  // Asimetrik boşluklar: Toplam'ın SOLU (8px) sağındakinden (4px) geniş.
  const bosluklar = await page.evaluate(() => {
    const g = (ad: string) =>
      document
        .querySelector<HTMLElement>(`[data-metin-kutusu="${ad}"]`)!
        .getBoundingClientRect();
    return {
      toplamSol: g('toplam-baslik').left - g('kalan-baslik').right,
      toplamSag: g('klig-baslik').left - g('toplam-baslik').right,
    };
  });
  expect(bosluklar.toplamSol).toBeCloseTo(8, 0);
  expect(bosluklar.toplamSag).toBeCloseTo(4, 0);
});
