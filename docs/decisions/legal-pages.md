# Hukuki Statik Sayfalar — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). /gizlilik/, /kullanim-kosullari/, /hesap-silme/.

## Hukuki Statik Sayfalar — `/gizlilik/`, `/kullanim-kosullari/`, `/hesap-silme/` (23 Ağustos 2026)

**NEDEN VAR:** Play'in **Data safety formu kapalı test kanalındaki uygulamalar
için de zorunlu** ve o formu tamamlamak **doğrudan açılan bir gizlilik
politikası URL'i** istiyor (ölçüldü, Play dokümanı). Bugüne kadar politika
YALNIZCA SPA içindeki bir penceredeydi (`?gizlilik=1`) — yani inceleyenin JS
render'ına güvenmesi gerekiyordu. Aynı gerekçe hesap silme için de geçerli:
hesap açtıran uygulamalarda Play hem uygulama içi bir yol hem de bir **web
silme talep adresi** istiyor; `/hesap-silme/` ikincisini karşılıyor.

### Metin KOPYALANMAZ — `src/legal/LegalContent.tsx`

`PrivacyModal`/`TermsModal` artık ince sarmalayıcı; gövde tek kaynakta ve
statik sayfalar da AYNI bileşeni tüketiyor. Kopyalansaydı portun
`legal_modals.dart`'ıyla birlikte **üç kopya** olurdu ve `legal_text_test.dart`
yalnızca "Son güncelleme" TARİHLERİNİ karşılaştırıyor, metnin kendisini
DEĞİL — ayrışma sessiz kalırdı. İki tüketici arasındaki tek fark iletişim
bağlantısı (`contact` prop'u): pencerede `FeedbackModal`'ı açan bir `<button>`,
sayfada `/?contact=1`'e giden bir `<a>`.

**Çıkarma işlemi ÖLÇÜLEREK yapıldı:** eski gövde JSX'i, `git show HEAD:`ten
okunup yeni dosyada **bayt bayt** aranarak doğrulandı — metin değişmedi, yani
portun senkronu ve `legal_text_test.dart` etkilenmedi.

**`SILME_SURESI_GUN` sabiti:** silme süresi ÜÇ yerde geçiyor (politikanın 5. ve
8. bölümü + `/hesap-silme/`). Sabit yazılırken **8. bölümdekinin hâlâ elle
yazılmış olduğu smoke testi tarafından yakalandı** — o da sabite bağlandı.

### Eklenti, derleme sonrası betik DEĞİL

`scripts/legal-plugin.js`, `landing-plugin.js` ile aynı gerekçe: duman testleri
`npm run dev` üzerinde koşuyor, yalnızca `dist`e yazan bir çözümde sayfalar dev
sunucusunda HİÇ var olmaz ve tamamen bozukken bile testler yeşil kalır. Dev'de
middleware ile servis ediliyor, derlemede `generateBundle` + `emitFile` ile
`dist/<yol>/index.html` olarak bırakılıyor. Derleme+import **tek sıraya
dizilmiş** (landing eklentisindeki yarış dersi).

**Dev'de stil `/src/index.css?direct`ten geliyor** — `?direct` olmadan Vite JS
sarmalayıcı döndürür ve sayfa stilsiz kalır.

### ⚠ ÖLÇÜLEN İKİ TUZAK

1. **Service worker sayfaları SPA kabuğuna çeviriyordu.** `navigateFallback`
   (`createHandlerBoundToURL("index.html")`) yüzünden. Gerçek tarayıcıda
   ölçüldü: eğik çizgili `/gizlilik/` precache rotasına takılıp DOĞRU geliyordu
   ama **eğik çizgisiz `/gizlilik` uygulama kabuğunu döndürüyordu.** Çözüm
   `workbox.navigateFallbackDenylist` (üç yol için). `navigateFallback`'in
   kendisine ve `registerType:'prompt'`e DOKUNULMADI.
2. **Eğik çizgisiz adres sunucuya bağlı.** `vercel.json`'a üç `redirects`
   girdisi eklendi (`/gizlilik` → `/gizlilik/`); mevcut `rewrites` bloğuna
   dokunulmadı. **Bu ortamdan Vercel davranışı test EDİLEMİYOR** — bu yüzden
   yayınlanan HER adres (Play formu, sitemap, canonical, footer) eğik çizgili
   hâli kullanıyor; ölçülmüş ve çalıştığı bilinen hâl o. Eğik çizgisiz hâl bir
   kolaylık, bağımlılık değil.

### Regresyon

`tests/smoke.spec.ts` 22 → **27 test**: üç sayfa da statik açılıyor
(`#root` YOK — SPA'ya düşmediğinin kanıtı), sayfa ile pencerenin bölüm
başlıkları BİREBİR aynı, `/hesap-silme/` talep bağlantısını ve süreyi
gösteriyor. **Negatif eş ikisi de ölçüldü:** eklenti kaldırılınca sayfalar ne
derlemede üretiliyor ne dev'de servis ediliyor (dev `/gizlilik/` → SPA kabuğu);
sayfaya pencerede olmayan bir bölüm eklenince parite testi GERÇEKTEN düşüyor.

**Yeni bir hukuki sayfa eklenirken:** `LEGAL_PAGES`e ekle → `sitemap.xml`,
`navigateFallbackDenylist` ve `vercel.json` redirect'i de güncelle. Üçü elle
senkron; biri atlanırsa sayfa ya indekslenmez ya da SW tarafından yutulur.

