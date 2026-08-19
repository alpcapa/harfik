# Kelimeki — Sıradaki İşler (19 Ağustos 2026)

**Bu dosya bir FİKİR LİSTESİ DEĞİL, sıralı bir yürütme planı.** Kök
`CLAUDE.md`'deki "Sonraya Bırakılan Ürün Fikirleri" bölümü *ne* yapılacağını
ve *neden* ertelendiğini anlatır; burası *hangi sırayla*, *hangi modelle* ve
*hangi tuzaklara dikkat ederek* yapılacağını anlatır.

Bir madde bitince buradan SİLİNİR ve kaydı ilgili bölümün kendi tarihli
notuna taşınır (projenin genel "değişiklik = tarihli not" disiplini).

**Durum (19 Ağustos 2026):** `main` yeşil, yarım kalan iş yok. FAZ A1 cihaz
turu Bölüm 6 (Paylaşma, iPad popover) hariç kapalı. Web + port paritesi
güncel.

---

## Modeller — hangi iş için hangisi

Ölçüt maliyet değil **hata bedeli** ve **ufuk uzunluğu**:

| Model | Ne zaman |
|---|---|
| **Fable 5** (`claude-fable-5`) | Geri dönüşü OLMAYAN ya da çok uzun ufuklu iş: veri silme kaskadı, çok platformlu yapılandırma zincirleri. En yetenekli model; pahalı, o yüzden yalnızca bu iki sınıf için. |
| **Opus 5** (`claude-opus-5`) | Varsayılan. Tasarım kararı gerektiren, çok dosyaya yayılan, ama geri alınabilir işler. |
| **Sonnet 5** (`claude-sonnet-5`) | Spesifikasyonu bu dosyada NET yazılmış, mekanik iş. Takılırsa Opus 5'e yükselt — inatla devam ettirme. |

**Efor:** uzun/agentic işlerde `high`–`xhigh`; mekanik işlerde `low`–`medium`.

---

## Bu projede bir oturumun gerçek maliyeti

19 Ağustos turunda ölçüldü — planlarken bunu hesaba kat:

- **`mobile/**` altına dokunan her PR** şu boru hattını tetikliyor: Analiz +
  testler (~3 dk) → Android APK (~5 dk) → iOS (~5 dk) → `main`'e merge
  sonrası Pages yayını. Tur başına **15-20 dk** ve birkaç mesaj.
- **Yalnızca web** (`src/**` vb.) → yalnız `web-ci.yml`, ~2 dk.
- **Yalnızca doküman** (`*.md`) → **hiç CI koşmaz.** Ücretsiz.
- **Taslak PR deseni işe yarıyor:** Flutter SDK bu ortamda YOK, yani Dart
  testleri yalnızca CI'da koşuyor. Emin olmadığın bir Dart değişikliğini
  önce `draft: true` PR ile CI'a sor, yeşilse merge et. 19 Ağustos'ta bu,
  iki bozuk testin `main`'e girmesini önledi.

---

## 1. `kelimeki://` deep link kanalı — **MAĞAZA BLOKERİ**

**Model: Fable 5, efor `xhigh`.** Üç platform yapılandırması + Supabase Auth
+ Flutter yönlendirme aynı anda; hiçbiri bu ortamdan uçtan uca test
edilemiyor, yani her adım "kör" yazılıp cihazda doğrulanacak.

**Neden ilk:** 17 Ağustos'ta cihazda bizzat gözlendi — kayıt onayı
e-postasındaki bağlantı uygulamayı değil `kelimeki.com`'u açtı, üstelik o
sekmede BAŞKA bir hesap açıktı. `mobile/CLAUDE.md` bunu *"mağazaya çıkışta
kabul edilemez"* diye kaydetmiş. Diğer iki bloker (2 ve 3) bundan daha az
acil.

**Kapsam — üç akış:** kayıt onayı, şifre sıfırlama, arkadaş daveti
(`/davet/:token`).

**Dokunulacaklar:**
- Supabase Dashboard → Auth → URL Configuration (redirect allow-list) ve üç
  e-posta şablonu (`supabase/email-templates/*.html` — bunlar Dashboard'a
  ELLE yapıştırılıyor, repo otomatik okunmuyor; bkz. kök `CLAUDE.md`).
- iOS: `Info.plist` URL scheme + Associated Domains.
- Android: intent filter + `assetlinks.json` (Pages'ta barındırılacak).
- Flutter: gelen linki karşılayan yönlendirme + `friendInvite` kuyruğuyla
  (web'deki `kelimeki:pending-invite` deseninin portu) birleştirme.

**Tuzaklar:**
- Universal Links yalnızca App Store'dan kurulan uygulamalarda çalışıyor —
  "Ana Ekrana Ekle" PWA'sı bu mekanizmaya HİÇ giremiyor (kök `CLAUDE.md`,
  `AddToHomeScreen` notu). Yani bu iş FAZ B'yi (gerçek imzalı derleme)
  fiilen zorunlu kılıyor.
- Auth şablonları değişirse `_shared/email.ts`'in marka sarmalayıcısıyla
  ayrışmasınlar (kök `CLAUDE.md`, "Marka şablonu").

**Ön koşul:** Apple Developer üyeliği + imzalama anahtarı. Bunlar yoksa iş
yarıda kalır — **başlamadan önce teyit et.**

---

## 2. Uygulama içinden hesap silme — **MAĞAZA BLOKERİ**

**Model: Fable 5, efor `xhigh`.** Bu listedeki tek GERİ DÖNÜŞSÜZ iş.

**Neden:** Apple 5.1.1(v) ve Google'ın veri silme şartı, hesap açtıran
uygulamalarda uygulama İÇİNDEN başlatılabilen bir silme yolu istiyor. Bugün
hiç yok. **Hukuken zorunlu değil** (KVKK m.7/m.11 ve GDPR m.17 hakkı verir,
buton şart koşmaz) — Gizlilik Politikası 19 Ağustos'ta bunu "Görüş
Bildir'den talep edin, 30 gün" olarak doğru anlatacak şekilde düzeltildi.
Yani bu madde **mağaza kapısı** için var; web'de gerekmez (kullanıcı kararı,
19 Ağustos).

**İşin ağırlığı UI'da değil kaskad zincirinde.** Silinecek/anonimleştirilecek
yerler en az: `auth.users`, `profiles`, `games`, `game_likes`,
`friend_requests`, `friend_invite_links`, `local_game_saves`,
`online_game_*` (state/secrets/moves/messages/mutes/reports/clients),
`feedback`, `league_rewards`, `admin_ban_log`, `avatars` storage kovası.
Bir kısmı cascade, bir kısmı değil.

**Kritik karar:** silinen kişi BAŞKALARININ bitmiş oyun kayıtlarında
(`games.players` snapshot'ı) isimle duruyor. O satırlar başka kullanıcıların
kendi verisi — silinemez, en fazla anonimleştirilebilir. Bu kararı
kullanıcıya sor.

**Yöntem:** service-role bir Edge Function (`delete-my-account`) +
çağıranın kendi JWT'si ile kimlik doğrulama. Önce **kuru çalıştırma**:
silinecek satır sayılarını döndüren bir rapor, kullanıcıya göster, sonra
uygula.

**Zorunlu ekler:** `PrivacyModal` + portun `legal_modals.dart`'ı (tarihler
`legal_text_test.dart` ile karşılaştırılıyor, biri bayat kalırsa mobil CI
düşer).

---

## 3. İstemci hata telemetrisi — **MAĞAZA ÖNCESİ**

**Model: Opus 5, efor `high`.** Sınırları net, ama "ne kaydedilMEZ" kararı
tasarım işi.

**Neden çıkıştan önce:** geriye dönük doldurulamaz (`games.platform` ile
aynı sınıf). Bugün istemcideki her çökme kullanıcının cihazında ölüyor —
web'de 81 `console.error`, portta 74 `debugPrint`, artı `ErrorBoundary` ve
`componentDidCatch`. Bu projede bedeli ölçülmüş: avatar yükleme 20
Temmuz'dan 13 Ağustos'a kadar 403 veriyordu ve kimse fotoğrafını
değiştirmediği için üç hafta görünmedi.

**Kapsam:** yakalanmamış istisna, `unhandledrejection`, `ErrorBoundary`, ve
BİLİNÇLİ "bu olmamalıydı" noktaları (ör. `cloud_save_repo`'nun "KAYIP"
logu).

**Kaydedilmeyecek:** çevrimdışılık, `isNetworkError`'a düşen her şey,
sunucunun KENDİ reddi (`'Sıra sende değil.'`). Girerse gürültü sinyali
boğar.

**Üç zorunluluk:** (1) fire-and-forget, asla `await` edilmez, asla fırlatmaz;
(2) tekrar bastırma + hız sınırı (çökme döngüsü binlerce satır yazar);
(3) derleme kimliği (`window.__KELIMEKI_BUILD__` / `buildSha`) her kayda
eklenir.

**Nerede saklanır:** kendi `client_errors` tablomuz (`guest_visits` deseni:
anonim, yalnız insert eden RLS, admin panelinde okunur) — Sentry gibi bir
üçüncü tarafa geçmek gizlilik metninde çok daha ağır bir değişiklik olur.

**Zorunlu ek:** `PrivacyModal` + `legal_modals.dart` (yeni kişisel veri).

---

## 4. Test hesaplarının silinmesi — **TEMİZLİK, GERİ DÖNÜŞSÜZ**

**Model: Opus 5, efor `high`.** Küçük ama geri alınamaz; Sonnet'e verme.

23 üyenin 5'i test hesabı ve tüm büyüme metriklerini kirletiyor:
`T1` (alp.capa@hotmail.com — **kullanıcının KENDİ kişisel e-postası**),
`T2`, `T3`, `T4`, `T5` (tek kullanımlık testinator adresleri).

**`Ironman` (alprcapa@gmail.com) HİÇBİR KOŞULDA SİLİNMEZ** — hesap
sahibinin gerçek ana/admin hesabı (kullanıcı kararı, 14 Ağustos).

**Sıra önemli:** madde 2 (hesap silme) BİTTİKTEN SONRA yap — o iş zaten
kaskad zincirini çıkarmış olur ve bu silme onun ilk gerçek kullanımı olur.
Öncesinde yapılırsa aynı analiz iki kez yapılır.

Silmeden önce kaskad zincirini çıkarıp kullanıcıya göster: geri dönüşü yok.

---

## 5. k-lig puan grafiği — **İSTEĞE BAĞLI**

**Model: Sonnet 5, efor `medium`.** Spesifikasyon kök `CLAUDE.md`'de eksiksiz
yazılı (seri nasıl kurulur, hangi oyunlar atlanır, hangi etiketler). Takılırsa
Opus 5'e yükselt.

**Ertelemenin maliyeti SIFIR** — `games.created_at` durduğu sürece seri her
zaman geriye dönük kurulabilir. Bugün 15 kullanıcının yalnızca 4'ünde dolu
bir grafik çıkıyor ve `league_rewards`'ta toplam 6 satır var, yani etiketler
neredeyse boş. Ironman 100 puanı geçtiğinde anlam kazanmaya başlar.

**Değişmez:** son nokta `player_stats_overall.total_score` ile BİREBİR
eşleşmeli (14 Ağustos'ta canlıda 15/15 kullanıcıda doğrulandı). Web + port
AYNI PR'da.

---

## 6. Taranabilir `/nasil-oynanir` sayfası — **İSTEĞE BAĞLI**

**Model: Opus 5, efor `high`.** Basit görünüyor ama üç gizli bağı var.

**Neden:** Google AI Mode Kelimeki'yi "kelime bulucu ve sözlük platformu"
diye tamamen uydurdu (17 Ağustos, üç ekran görüntüsüyle). Sitenin en zengin
açıklayıcı içeriği (`HelpModal`) yalnızca modal açılınca render oluyor,
taranabilir HTML'de hiç yok.

**Gizli bağlar — yapmadan ÖNCE oku:**
1. `mobile/app/test/help_text_parity_test.dart` **doğrudan
   `src/components/HelpModal.tsx`'i okuyor** ve `<Section title="…">` /
   `<QuickItem icon="…">` regex'leriyle tarıyor. İçeriği başka dosyaya
   çıkarmak o testi düşürür — üstelik web'e dokunduğun için bakmayacağın
   mobil tarafta.
2. İçerik TEK KAYNAKTA kalmalı; modal ve sayfa AYNI bileşeni tüketmeli.
   İki kopya bu projenin en sık tekrarlayan hata sınıfı.
3. Sayfanın KENDİ `title`/`description`'ı olmalı, yoksa SPA'nın genel
   meta'sını miras alır ve kazancın yarısı gider.

**Client-render YETMEZ:** Googlebot JS çalıştırıyor ama AI/LLM crawler'ları
çalıştırmıyor — sorunu doğuran şeyi tam olarak ıskalar. Derleme-zamanı
statik üretim gerekiyor (`generate-og-image` deseni →
`dist/nasil-oynanir/index.html`). Vercel'in statik dosyayı rewrite'tan ÖNCE
servis ettiği DOĞRULANMALI.

**Ayrıca:** `sitemap.xml` (şu an tek URL) ve PWA precache listesi.

---

## 7. Davet linkine `?ref=arkadas` — **KÜÇÜK**

**Model: Sonnet 5, efor `low`.** Tek satır, yalnız web, CI ~2 dk.

`buildInviteUrl` (`FriendsModal.tsx`) davet linkine `?ref=arkadas` eklerse
admin panelindeki Kaynak Hunisi'nin iki ucu aynı kanalı ölçmeye başlar.
Bugün ziyaretçi ucu yalnız Setup'ın paylaş butonunu, üye ucu ağırlıkla
`/davet/:token`'ı sayıyor — o path `?ref=` taşımıyor, dolayısıyla
`arkadas` satırının "%100 dönüşümü" bir ÖLÇÜM DEĞİL, tesadüf.

---

## 8. FAZ A1 Bölüm 6 (Paylaşma) — cihazda kapatılacak

Kod işi yok; iPad popover ankrajı (Parça 86) gerçek cihaz istiyor. FAZ B
turunda kapanır.

---

## Her iş için değişmeyen kurallar

1. **Önce etki analizi** (kök `CLAUDE.md` → "Çalışma İlkesi"): bu kodun
   ikinci okuyucusu/yazarı var mı? bir zincirin halkası mı? derleyicinin
   göremeyeceği hangi değişmeze dokunuyorum?
2. **Bitince `git status` oku** ve dokunduğun her alanın eşini güncelle —
   `CLAUDE.md`/`README.md`/`TESTING.md`/`mobile/*`.
3. **Migration varsa** MCP ile canlıya uygula, `list_migrations` ile dosya
   adını gerçek versiyonla eşleştir, ve **fonksiyonu GERÇEKTEN çağır** —
   "uygulandı" yetmez (bu projede geçerli SQL iki kez ilk çağrıda patladı).
4. **Ölçmeden "ölçüldü" yazma.** Flutter SDK bu ortamda yok; Dart tarafında
   bir sayıyı ancak CI ya da cihaz kanıtlar.
5. **Geometri ölçen bir teste `setUpAll(loadAppFonts)` şart** — yoksa
   Ahem'in düzenini ölçersin, ürünün değil (19 Ağustos'ta iki testi birden
   düşürdü).
6. **Düzen testinin boyu** ürünün göründüğü EN DAR/EN KISA yüzeyi temsil
   etmeli — etmiyorsa yeşil olması hiçbir şey garanti etmez.
