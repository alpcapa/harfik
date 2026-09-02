// Kelimeki — SINIF 3 (SARMA) web tarafı.
//
// Mobil portta 1 Eylül 2026'da bulunan hata sınıfının web eşleniği:
// sabit genişlikli sütun kutularının (`w-[29px]` gibi) içindeki metin
// büyüyünce kutuya sığmayıp SARIYOR — kullanıcının bildirdiği biçimiyle
// "bitirme modalı puanları bölüyor" (`241` → `24` / `1`).
//
// Web'de yazı ölçeğinin karşılığı tarayıcı zoom'u DEĞİL (o kutuları da
// büyütür, yani hatayı üretmez); karşılığı **asgari yazı boyutu** ayarı:
// yalnızca eşiğin altındaki metinleri büyütür, kutular px'te kalır. Bu
// yüzden bu dosya kendi tarayıcı bayrağıyla koşuyor.
import { test, expect } from '@playwright/test';
import { bitirmeModali, kutuOlcumleri } from './gameOverFixture';

test.use({
  viewport: { width: 390, height: 844 },
  launchOptions: {
    // Config'deki değeri EZDİĞİMİZ için burada yeniden vermek ZORUNDAYIZ —
    // `launchOptions` sığ birleşiyor, atlanınca "Executable doesn't exist".
    executablePath: process.env.CI ? undefined : '/opt/pw-browsers/chromium',
    args: ['--blink-settings=minimumFontSize=16'],
  },
});

test('Asgari yazı boyutu 16px iken bitirme modalındaki sayılar BÖLÜNMEZ', async ({ page }) => {
  await bitirmeModali(page);

  // Kurulum kontrolü: bayrak gerçekten etkili mi? Etkili değilse test
  // hatayı göremez — sessizce geçmesindense düşsün.
  const punto = await page.evaluate(() => {
    // Başlık satırı `text-[9px]` — asgari boyut etkiliyse 16'ya çıkmalı.
    const el = document.querySelector<HTMLElement>('[data-metin-kutusu="kalan-baslik"]')!;
    return parseFloat(getComputedStyle(el).fontSize);
  });
  expect(punto, 'asgari yazı boyutu bayrağı etkisiz — --blink-settings uygulanmadı').toBe(16);

  const kutular = await kutuOlcumleri(page);
  expect(kutular.length, 'ölçülecek kutu bulunamadı (data-metin-kutusu)').toBeGreaterThan(0);

  // Ölçüm kayda geçsin: bu dosyanın işi hata yakalamak kadar, bir sonraki
  // turda "ne kadar dardı" sorusunu tahmin ettirmemek de.
  for (const k of kutular) {
    console.log(
      `  ${k.ad.padEnd(14)} "${k.metin}" metin=${k.murekkep.toFixed(1)} kutu=${k.kutu.toFixed(1)} satır=${k.satir}`,
    );
  }

  // SINIF 3 — SARMA: sayı iki satıra bölünüyor ("241" → "24"/"1").
  const bolunen = kutular.filter((k) => k.satir > 1);
  expect(
    bolunen.map((b) => `${b.ad}="${b.metin}"`),
    'bu kutulardaki metin SARIYOR',
  ).toEqual([]);

  // SINIF 1 — TAŞMA: sarmıyor ama kutusundan geniş, yani komşusunun üstüne
  // biniyor. Sarmayı `nowrap` ile kapatıp taşmayı bırakmak DÜZELTME DEĞİL,
  // sınıf değiştirmektir; iddia bu yüzden ikisini birden tutuyor.
  const tasan = kutular.filter((k) => k.murekkep > k.kutu + 0.5);
  expect(
    tasan.map((t) => `${t.ad}="${t.metin}" (${t.murekkep.toFixed(1)}px metin, ${t.kutu.toFixed(1)}px kutu)`),
    'bu kutulardaki metin TAŞIYOR',
  ).toEqual([]);
});
