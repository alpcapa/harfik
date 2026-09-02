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

  // (1) IZGARANIN SÖZLEŞMESİ, ortamdan bağımsız — iki parça:
  //   a. bir sütundaki BÜTÜN hücreler aynı genişlikte (satırlar hizalı),
  //   b. o genişlik hiçbir hücrenin mürekkebinden dar değil (kırpma yok).
  //
  // ⚠ Bu iddia "sabit px'e geri dönüldü" hâlini YAKALAMAZ ve bu ölçüldü:
  // `min-w-*` tabanları yerinde olduğu için normal ölçekte ızgara ile sabit
  // genişlik BİREBİR aynı render ediyor (29,00/37,00/20,00) — ayırt edilecek
  // bir fark yok. O regresyonu yakalayan `text-scale.spec.ts`in TAŞMA
  // iddiası (kutuya `w-[29px]` konunca 50,4 px metin 29 px kutuda kalıyor).
  // Buradaki iş bölümü bilinçli: bu dosya "eski görünüm bozulmadı"yı, öteki
  // "büyüyünce patlamıyor"u tutuyor.
  for (const [sutun, hucreler] of [
    ['Kalan', ['kalan-baslik', 'kalan-skor']],
    ['Toplam', ['toplam-baslik', 'toplam-skor']],
    ['k-lig', ['klig-baslik', 'klig-skor']],
  ] as const) {
    const ait = kutular.filter((k) => hucreler.includes(k.ad as never));
    const en = ait[0].kutu;
    for (const k of ait) {
      expect(k.kutu, `${sutun}: ${k.ad} kutusu sütunla aynı olmalı`).toBeCloseTo(en, 1);
      expect(
        k.kutu,
        `${sutun}: ${k.ad} mürekkebi (${k.murekkep.toFixed(1)}) kutusundan geniş`,
      ).toBeGreaterThanOrEqual(k.murekkep - 0.5);
    }
  }

  // (2) Elle yazılmış eski px değerleri — ±1,5 px BANT olarak.
  // ⚠ Nokta atışı iddia KIRILGAN ve bu ölçüldü: aynı test yerelde 37,0 px
  // görürken CI runner'ında 36,36 px gördü (koşu 33593831957). Kutu
  // genişliği font METRİKLERİNDEN türüyor, onlar da ortama göre kıl payı
  // oynuyor. Bant, gerçek bir kaymayı (bir sütunun bir öncekinin yerine
  // geçmesi ~8 px) yine de yakalar.
  const bant = (ad: string, beklenen: number) =>
    expect(
      Math.abs(bul(ad).kutu - beklenen),
      `${ad} kutusu ${beklenen}±1,5 px olmalı, ölçülen ${bul(ad).kutu.toFixed(1)}`,
    ).toBeLessThanOrEqual(1.5);
  bant('kalan-baslik', 29);
  bant('toplam-baslik', 37);
  bant('klig-baslik', 20);

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
