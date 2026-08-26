# İki gönderen: `noreply@` ↔ `destek@` ve "Zoho" rozeti (25 Ağustos 2026)

Kök `CLAUDE.md`'deki kısa kural bu dosyaya işaret ediyor. Burada kararın
gerekçesi, ölçümler, kurulum adımları ve bilerek yapılmayanlar var.

## Karar

Kullanıcı, 25 Ağustos 2026'da üç maddede karar verdi:

1. **`noreply@` yalnızca transactional mesajlarda kullanılacak ve GERÇEKTEN
   noreply olacak.** Gerekçesi kendi cümlesi: *"noreply demek cevaplanamaz
   demek. Noreply'a hiçbir uygulama cevap kabul etmez. Biz de etmemeliyiz."*
2. **Görüş bildirim yanıtları `destek@kelimeki.com`'dan gidecek**; kullanıcı
   cevap yazarsa Zoho kutusuna düşecek, **admin'e "mesaj var" uyarısı
   gelecek**.
3. **Admin'in Üyeler tablosundan yazdığı mesajlar** için de aynısı.

## Buraya nasıl gelindi (üç turluk soru-cevap)

Karar, doğrudan verilmedi — önce üç yanlış varsayım elendi. Kayda geçiyor,
çünkü üçü de tekrar sorulacak cinsten:

- **"Görüş formunu destek@'e bağlarsak mesajlar Zoho'ya mı gider?"** Hayır.
  `submitFeedback` (`src/lib/api.ts`) doğrudan `feedback` tablosuna INSERT
  ediyor — o yolda hiç e-posta yok. "destek@'e geçmek" yalnızca GİDEN mailin
  gönderenini değiştirir; form akışı hiç etkilenmez.
- **"Cevap aynı thread'e gelir mi?"** Hayır — ve sebebi incelikli: giden mail
  Brevo API'siyle gidiyor, yani Zoho'nun `Sent` klasöründe kopyası YOK. Gelen
  cevap kutuda bağlamsız tek bir `Re: …` olarak görünür. Mail istemcisi
  tarafında (kullanıcıda) thread doğru görünür, bizde görünmez.
- **"Bugün noreply'a yazılan cevap kayboluyor mu?"** O tarihte hayır: Zoho'da
  `noreply@` tek üyesi `destek@` olan bir GRUPtu, yani cevaplar kutuya
  düşüyordu. Madde 1 tam olarak bunu bitiriyor — grup silinince mail geri
  döner (bounce).

## Uygulama

### Gönderen ayrımı

`supabase/functions/_shared/email.ts`:

| Sabit | Adres | Kullanan |
|---|---|---|
| `KELIMEKI_SENDER` | `noreply@kelimeki.com` | 10 `notify-*`/`sweep-*` fonksiyonu + Dashboard'daki Auth şablonları |
| `KELIMEKI_SUPPORT_SENDER` | `destek@kelimeki.com` | `feedback-reply`, `admin-send-message` |

`sendBrevoEmail`'in `sender` parametresi **verilmezse noreply@ kullanılır** —
sender seçimi "unutulursa" transactional tarafa düşer, ki güvenli olan yön
budur: bir bildirimi yanlışlıkla destek@'ten göndermek, insanların cevap
yazacağı bir adresi robot trafiğiyle doldururdu. `replyTo` ayrıca geçiliyor,
çünkü bazı istemciler "Yanıtla"da `From` yerine `Reply-To`'ya bakar.

İki not metni:
- `buildNoReplyNoticeHtml()` — "Bu otomatik bir bildirimdir; bu adrese
  gönderilen yanıtlar okunmaz. Bize ulaşmak için destek@kelimeki.com."
  **Bu not olmadan madde 1 kullanıcıya düşman bir davranış olurdu**: cevap
  yazan kişi bir bounce alır ve nereye yazacağını bilmez.
- `buildSupportReplyNoticeHtml(threadId?)` — "Bu e-postayı doğrudan
  yanıtlayabilirsin… dilersen siteden de yazabilirsin." Eski hâli ("cevap
  vermek için tıklayın") artık yanlıştı: adres gerçek bir kutu.

⚠ **İki yolun VARDIĞI YER FARKLI ve bu bilinçli.** Doğrudan yanıt → Zoho
(panelde okunmaz, yalnızca rozeti artırır). Sitedeki `?contact=1&re=<id>`
linki → doğrudan `feedback` tablosu, panelde "↳ Cevaben" rozetiyle görünür.

### "Zoho" rozeti

Kullanıcının istediği biçim aynen: *"bildirim tablarını (gelen kutusu ve
şikayetler) biraz daraltıp küçük bir zoho tabı yapalım, üzerine bizim kırmızı
sayılı uyarı yuvarlağını koyalım. Ona tıklanırsa zoho inbox'a gitsin."*

`AdminDashboard.tsx` → Geri Bildirim sekmesinin alt sekme satırı. **Zoho bir
sekme DEĞİL, dışarı çıkan bir link**: `tabBtn` kullanmıyor (aktif hâli yok) ve
`flex-1` almıyor, yani yanındaki iki gerçek sekme daralıyor ama bu küçük
kalıyor. Hedef `https://mail.zoho.eu/zm/#mail/folder/inbox` — **`.eu`
bilerek**, kutu Avrupa veri merkezinde açıldı.

Rozet burada da projenin genel `CountBadge` dilini koruyor ("bekleyen İŞ"):
`destek@`'e admin'in haberi olmadığı bir cevap düşmüş demek.

**ZİNCİRİN ÜST HALKASI DA SAYAR (26 Ağustos 2026'da eklendi — ilk sürümde
ATLANMIŞTI).** `fetchAdminPendingCount`, yani `UserMenu`'deki "Admin Paneli"
satırının rozeti, artık üç kaynağı topluyor: okunmamış geri bildirim +
okunmamış şikayet + **haber verilmemiş destek cevabı**. Atlandığında ortaya
çıkan durum bu projede adı konmuş bir hata sınıfıdır (bkz.
`docs/decisions/components.md` → `CountBadge`, "rozet zinciri yukarı takip
edilmedi"): paneldeki "Zoho" rozeti sayarken dışarıdaki rozet saymıyordu,
yani admin **paneli açmayı akıl edene kadar** gelen cevaptan habersiz
kalıyordu — oysa bu rozetin var olma sebebi tam olarak buydu.

Kural: bir sayaç eklerken onu KAPSAYAN her seviye aynı PR'da güncellenir.

### Sayaç nereden geliyor

**Panel, Zoho'nun okunmamış sayısını kendiliğinden bilemez.** Bu yüzden:

```
kullanıcı "Yanıtla" → destek@kelimeki.com (Zoho — mailin ASIL yeri)
  → Zoho kuralı bir KOPYASINI mail.kelimeki.com'daki Brevo Inbound adresine yollar
    → Brevo Inbound Parsing `inbound-email` Edge Function'ına POST eder
      → `support_inbox`'a bir satır → rozet
```

`support_inbox` bir posta kutusu değil, bir **haber kaydı**: yalnızca
kimden/konu/tarih. **Gövde bilerek saklanmıyor** — kullanıcının mail metni tek
bir yerde (Zoho) kalsın diye. Panelde okuma istenirse şema genişletilir, ama o
zaman spam/ek dosya/boyut soruları da açılır.

`seen_at` = "admin'e HABER VERİLDİ", "Zoho'da OKUNDU" değil — gerçek
okunmuşluğu Zoho biliyor, biz bilemeyiz. Rozetin işi bir kez dürtmek.

### Güvenlik

`inbound-email` `verify_jwt:false` (Brevo JWT taşımaz), yani uç herkese açık.
Korumalar:
- Tek kapı `?key=` sorgu parametresindeki `INBOUND_EMAIL_SECRET`.
- **Sır tanımlı değilse fonksiyon 503 ile KAPALI** — yapılandırılmamış bir uç,
  panele sahte "cevap geldi" satırı POST edilebilen açık bir uçtan iyidir.
- `support_inbox`'ta **INSERT politikası yok**: satırları yalnızca service-role
  (RLS'i atlayarak) yazabilir; anon/authenticated rolü hiçbir şey ekleyemez.
- Kendi adreslerimizden gelen kopyalar ve otomatik yanıtlar (`Auto-Submitted`,
  `X-Autoreply`, `Precedence: bulk`) elenir — tatil mesajı "bekleyen iş" değil.

Hata kodları bilerek asimetrik: ayrıştırılamayan gövdeye **200** (4xx/5xx
dönersek Brevo aynı bozuk isteği sonsuza dek yeniden dener), DB yazma hatasına
**500** (yeniden denemesini İSTİYORUZ).

## Kurulum — panel adımları (koddan YAPILAMAZ)

Kod canlıda, ama zincirin şu halkaları Brevo/Zoho/GoDaddy panellerinden
yapılmalı. **Hiçbiri yapılmadan da uygulama bozulmaz**; yalnızca rozet hep 0
kalır ve destek maili göndermeye çalışan admin net bir hata mesajı görür.

1. ~~**Brevo → Settings → Senders**: `destek@kelimeki.com`'u gönderen olarak
   ekle ve doğrula.~~ **GEREKMEDİ — 26 Ağustos 2026'da ölçüldü** (aşağıdaki
   "İlk gerçek kullanım"). Brevo'nun `kelimeki.com` DOMAIN doğrulaması
   (25 Ağustos'ta DKIM kayıtlarıyla yapılmıştı) `destek@` için de yetiyor;
   adresi ayrıca Senders'a eklemeye gerek kalmadı. `brevoErrorMessage`'in
   yazdığı özel hata (*"destek@… Brevo'da doğrulanmış gönderen değil"*) yine
   dursun — başka bir domainde ya da doğrulama bozulursa tek yol gösteren o.
   **Ders: bu adımı yapmadan ÖNCE bir yanıt göndermeyi dene** — panelde altı
   adım atmadan hangisinin gerçekten gerektiğini bir dakikada öğrenirsin.
2. **Zoho → `noreply@` GRUBUNU SİL.** Madde 1'in fiilen uygulanması bu.
   Silinene kadar noreply'a yazılan cevaplar hâlâ `destek@`'e düşmeye devam
   eder, yani "gerçekten noreply" olmaz.
3. **Supabase → Edge Functions → Secrets**: `INBOUND_EMAIL_SECRET` ekle
   (32+ karakter rastgele). Bu eklenene kadar `inbound-email` 503 döner.
4. **GoDaddy DNS**: `mail.kelimeki.com` için Brevo'nun verdiği MX kaydı.
   ⚠ Kök `kelimeki.com`'un MX'ine DOKUNMA — o Zoho'ya bakıyor, gelen postanın
   tamamı oradan geçiyor. Subdomain kullanılmasının tek sebebi bu.
5. **Brevo → Inbound Parsing**: webhook URL'i
   `https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/inbound-email?key=<3. adımdaki sır>`
6. **Zoho → Filters**: `destek@`'e gelen mailin bir KOPYASINI 5. adımdaki
   inbound adresine yönlendir. ⚠ **Kopya** — kutuda da kalmalı, mailin asıl
   yeri orası.

Sıra önemli: 4→5→6 zinciri tamamlanmadan rozet beslenmez.

## İlk gerçek kullanım — GİDEN yarısı uçtan uca doğrulandı (26 Ağustos 2026)

Kullanıcı canlıda koştu, sonuçlar veritabanından teyit edildi:

| Adım | Sonuç |
|---|---|
| Ironman "Görüş Bildir" ile yazdı | `feedback` satırı (`origin: user`) panele düştü ✓ |
| Admin "Yanıtla" dedi | Mail **gitti**, `replied_at` damgalandı ✓ |
| Kullanıcı o maile "Yanıtla" dedi | Cevap **Zoho gelen kutusuna** düştü ✓ |
| Admin, Üyeler tablosundan Ironman'e mesaj yazdı | Mail gitti + `feedback` satırı (`origin: admin`, `handled: true`) ✓ |

Yani `destek@` gönderen ayrımının İKİ fonksiyonu da (`feedback-reply`,
`admin-send-message`) çalışıyor ve ikisi de kendi denetim satırını yazıyor.
`origin: admin` satırının DURUYOR olması ayrıca mailin gerçekten gittiğinin
kanıtı: Brevo çağrısı düşseydi fonksiyon o satırı geri silecekti.

**Rozet o turda ARTMADI ve bu doğru davranış** — `support_inbox` 0 satırdı,
çünkü GELEN zinciri (4→5→3→6) henüz kurulmamıştı. Zoho'ya düşen cevabın
Supabase'e ulaşacağı bir yol yoktu. Rozetin gerçek bir mailde sınanması
(ve `fetchAdminPendingCount`'un üçüncü kaynağının ilk kez doğrulanması) o
zincir kurulduğunda yapılacak.

## Ölçülemeyenler (dürüstlük notu)

- `inbound-email` ucu bu oturumdan **POST edilerek denenemedi**: bu ortamın
  `curl`'ü proxy'den çıkamıyor (`CONNECT tunnel failed, 403`) ve `WebFetch`
  yalnızca GET yapıyor. Fonksiyonun sırsız hâlde 503 dönmesi kod okumasıyla
  garanti, ölçümle değil.
- Brevo'nun `destek@`'i doğrulanmış domain (`kelimeki.com` DKIM'li) üzerinden
  otomatik kabul edip etmediği denenmedi — 1. adım bu yüzden listede duruyor.

## Bilerek YAPILMAYAN: panelde thread

Kullanıcı önce "aynı thread üzerinde olmalı" dedi, sonra kapsamı kendi
daralttı: mail Zoho'da okunacak, panel yalnızca haber verecek. Bu yüzden
`feedback.email_message_id` / `thread_root` gibi bir eşleştirme şeması
KURULMADI — gelen mail hiçbir `feedback` satırına bağlanmıyor.

Bir gün panelde tam yazışma istenirse gereken parçalar: giden mailin Brevo
`messageId`'sini saklamak, gelen mailin `In-Reply-To`/`References` başlığıyla
eşleştirmek, gövdeyi saklamak ve `feedback`'i tek-satır-tek-mesaj modeline
geçirmek. Bugünkü `related_to` (tek seviyeli, yalnızca site formundan gelen
cevaplar için) bunun yerine geçmez.
