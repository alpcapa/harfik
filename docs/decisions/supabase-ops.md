# Supabase işletim kayıtları — e-posta, migration, Edge Function

Bu dosya, kök `CLAUDE.md`'nin `## Supabase` bölümünden **24-26 Ağustos 2026
doküman bütçesi bölünmesiyle** taşınan tarihli anlatılardır. Kök dosyada
kalan şey KURAL; burada duran şey o kuralın NEDEN böyle olduğu ve hangi
hatayla öğrenildiği.

**Ne zaman okunur:** bir mail gitmediğinde/branding bozuk göründüğünde, bir
migration'ın canlıyla repo arasında ayrıştığından şüphelenildiğinde, ya da
bir Edge Function deploy'undan sonra beklenmedik bir 401 alındığında.

⚠ Kural değişirse kök `CLAUDE.md` de güncellenmeli — burası arşiv, tek
kaynak değil.

---

## Genel

Env değişkenleri olmadan uygulama offline çalışır — `useAuth` içindeki `configured` flag'i `false` olur ve tüm hesap/lider tablosu özellikleri gizlenir. Lokal geliştirmede Supabase gerekmez.

### Auth e-postaları — Brevo SMTP (Supabase'in varsayılan mailer'ı DEĞİL)

Supabase Auth (kayıt onayı, şifre sıfırlama vb.) e-postaları artık **Brevo** üzerinden özel SMTP ile gönderiliyor — Supabase'in kendi varsayılan/paylaşımlı mail servisi çoktan terk edildi. Bir kullanıcı "e-posta gelmedi/spam'e düştü" derse **ilk şüpheli Supabase'in default mailer'ı OLMASIN** — o zaten devre dışı. Bunun yerine Brevo tarafına bak: gönderen domain'in SPF/DKIM/DMARC kaydı hâlâ geçerli mi, Brevo hesabında gönderim/kota limiti mi devrede, Brevo'nun kendi gönderim loglarında o adrese ne olmuş (kabul/ret/bounce). SMTP kimlik bilgileri koda değil doğrudan Supabase Dashboard'a (Authentication → Emails → SMTP Settings) girildiği için repoda hiçbir iz bırakmaz — bu yüzden bu not burada duruyor, koddan çıkarılamaz.

**E-posta şablonları (branding):** Brevo yalnızca taşıyıcıdır (SMTP relay) — mailin HTML içeriği/markası Supabase Dashboard → Authentication → Emails → Templates'te tanımlanır, bu da SMTP kimlik bilgileri gibi repoda hiçbir iz bırakmaz. Kelimeki markalı şablonların kaynağı `supabase/email-templates/*.html`'de tutulur (confirm-signup, reset-password, change-email) — ama bunlar Supabase Auth tarafından otomatik okunmaz, her değişiklikte Dashboard'daki ilgili template'e elle yapıştırılması gerekir. 20 Temmuz 2026'da bu şablonlar hiç kaydedilmemiş/kaybolmuş olduğu ortaya çıktı — kullanıcı gerçek bir onay maili aldığında hâlâ Supabase'in stok İngilizce varsayılan metni ("Confirm your email address" / "Follow the link below...") geliyordu, hiçbir Kelimeki markası yoktu. Bir kullanıcı "mailde branding yok" derse önce Dashboard'daki template'in bu repo dosyalarıyla eşleşip eşleşmediğini kontrol et.

20 Temmuz 2026'da bu yüzden yaşanan bir teslimat sorunu şu şekilde çözüldü: Brevo'daki **Sender** hâlâ rebrand öncesinden kalma `Harfik <kişisel-hotmail-adresi>` idi — DKIM "Default" (domain'e özel değil) ve DMARC uyarılıydı, Brevo'nun kendi paneli de "senders not compliant with Google/Yahoo/Microsoft's new requirements" diyordu. Brevo → Settings → Senders, domains, IPs → **Domains** sekmesinden `kelimeki.com` domain olarak eklenip verilen DNS kayıtları domain'in DNS'ine girildi, sonra sender `Kelimeki <noreply@kelimeki.com>` olarak yeniden eklendi. **DÜZELTME (25 Ağustos 2026, GoDaddy panelinden 14 kaydın tamamı okundu):** bu cümle uzun süre "SPF/DKIM/DMARC girildi" diyordu; gerçekte girilen **DKIM (`brevo1/2._domainkey`) + DMARC (`p=none`) + `brevo-code` doğrulaması**, ve **SPF kaydı HİÇ YOK** — kök `kelimeki.com` üzerinde `v=spf1` ile başlayan bir TXT bulunmuyor. Teslimat yine de sağlam, çünkü DMARC SPF **veya** DKIM'den biri hizalanırsa geçer ve Brevo'nun DKIM'i `kelimeki.com` adına imzalıyor; Brevo'nun zarf adresi (Return-Path) kendi domaininde olduğundan kök SPF'e zaten bakılmıyor (`mail`/`r.mail`/`img.mail` CNAME'lerinin `brevosend.com`'a gitmesinin sebebi bu). **Bu yanlış cümlenin bedeli ölçüldü:** 25 Ağustos'ta `destek@kelimeki.com` kurulumu planlanırken üç tur boyunca "mevcut SPF kaydını birleştir, ikinci TXT açma" uyarısı yazıldı — birleştirilecek kayıt hiç yoktu. Domaine ilk SPF kaydı yazılırken Brevo da `include:spf.brevo.com` ile içine alınmalı. **KURULDU (25 Ağustos 2026):** domaine ilk SPF kaydı `v=spf1 include:zohomail.eu include:spf.brevo.com ~all` olarak yazıldı ve **Brevo regresyonu ölçüldü — SPF/DKIM/DMARC üçü de PASS**, zincir bozulmadı. Aynı gün `destek@kelimeki.com` gerçek bir posta kutusu olarak açıldı (Zoho Mail, AVRUPA veri merkezi) ve MX artık Zoho'ya bakıyor; `noreply@kelimeki.com` bir GRUP olarak aynı kutuya düşüyor, yani kullanıcıların "Yanıtla" cevapları artık kaybolmuyor. **Bundan sonra "mail gelmedi" teşhisinde İKİ sistem var:** giden = Brevo (Auth SMTP + Transactional API), gelen = Zoho. Ayrıntı, as-built kayıtlar ve test sonuçları: `marketing/play-store/console-formlari.md` → "destek@kelimeki.com — kurulum". Sonuç: DKIM signature "kelimeki.com" ✓, DMARC "configured" ✓, uyumluluk uyarısı yeşile döndü. Yani gönderen adı/adresi **"Kelimeki" / `noreply@kelimeki.com`** olmalı — bir daha "Harfik" görülürse (sender listesinde ya da gönderen adında) bu geriye gitmiş demektir, DNS kaydı silinmiş/domain doğrulaması bozulmuş olabilir, Brevo → Senders, domains, IPs'ten kontrol et.

### Geri bildirim yanıtları — Brevo Transactional API (SMTP'den AYRI, ilk Edge Function)

Yukarıdaki "Auth e-postaları — Brevo SMTP" bölümü yalnızca Supabase Auth'un kendi ürettiği mailleri (kayıt onayı, şifre sıfırlama) kapsar — bu akış Supabase Dashboard'da yapılandırılır ve uygulama kodundan keyfi bir mail göndermek için **kullanılamaz**. Görüş bildirimlere admin panelinden yanıt gönderebilmek için 26 Temmuz 2026'da ayrı bir mekanizma kuruldu: Brevo'nun **HTTP Transactional Email API**'si (`POST https://api.brevo.com/v3/smtp/email`), SMTP kimlik bilgilerinden tamamen farklı bir **API key** ile çağrılıyor.

- Bu API key, Supabase Dashboard → Edge Functions → **Secrets** altına `BREVO_API_KEY` adıyla **custom secret** olarak elle girildi (kullanıcı tarafından) — SMTP şifresi gibi bu da repoda/koda hiç yazılmaz, yalnızca bu not burada duruyor.
- Bu, projedeki **ilk Supabase Edge Function**: `supabase/functions/feedback-reply/` — admin panelinden çağrılır (`sendFeedbackReply`, `src/lib/api.ts`), çağıranın kendi JWT'siyle bir Supabase client oluşturur (RLS/`is_admin()` doğal olarak uygulanır, ayrı bir yetki kontrolü kod tekrarı gerekmez), gönderen adresi olarak zaten SPF/DKIM/DMARC doğrulanmış `noreply@kelimeki.com`'u (bkz. yukarıdaki sender kurulumu) kullanır, e-postayı gönderdikten sonra `feedback.reply`/`replied_at`/`replied_by`'ı günceller. Deploy `supabase functions deploy` CLI'ı ile DEĞİL, migration'larla aynı gerekçeyle (CI/CLI erişimi yok) Supabase MCP'nin `deploy_edge_function`'ı ile production'a doğrudan yapılıyor — yeni bir Edge Function eklenirse/değiştirilirse aynı yolu izle.
- Yalnızca `feedback.email` dolu olan satırlar yanıtlanabilir; `feedback_rate_limit` gibi bu da bir güvenlik ağı değil sadece pratik bir sınır — anonim/e-postasız gönderimlere mail atılamaz.
- **26 Temmuz 2026'nın ikinci değişikliği — "hafif çözüm" (gerçek `destek@` gelen kutusu bilinçli olarak ERTELENDİ):** Kullanıcıya gerçek iki yönlü mail yazışması (Brevo Inbound Parsing + yeni bir subdomain/MX kaydı + `feedback_messages` gibi çok mesajlı bir şema) kurmak yerine, şimdilik daha ucuz bir ara çözüm seçildi — iş büyüyünce gerçek `destek@` kutusuna geçilebilir, o zamana kadar bu not burada bir hatırlatma. İki parça eklendi:
  1. `supabase/functions/admin-send-message/` — admin panelinin Üyeler tablosundaki her satıra eklenen "Mesaj Gönder" linkinden (`MemberMessageModal.tsx`) tetiklenir; admin serbest bir Konu + Mesaj yazar, aynı Brevo API'siyle gönderilir. İki fonksiyon da ortak `supabase/functions/_shared/email.ts`'i kullanıyor (Brevo çağrısı, HTML escape, sender sabiti) — Supabase her fonksiyonu bağımsız bir paket olarak deploy ettiğinden, `deploy_edge_function` her iki fonksiyon için de `_shared/email.ts`'i kendi `files` listesine ayrıca eklemek zorunda (tek bir yerde deploy edip diğerinin otomatik görmesi mümkün değil).
  2. Hem `feedback-reply` hem `admin-send-message`'ın gönderdiği e-postaların altına artık farklı stilde (küçük, gri, italik) bir not ekleniyor: "Bu e-posta noreply adresinden gönderilmiştir. Cevap için tıklayın" — `tıklayın` `kelimeki.com/?contact=1`'e giden altı çizili bir link. Bu link bir mail istemcisinde form açtıramayacağından (mail'ler JS/form çalıştırmaz) en yakın pratik çözüm seçildi: `App.tsx`'teki bir `useEffect` sayfa yüklenince `?contact=1` parametresini okuyup genel "Görüş Bildir" formunu (`FeedbackModal`, `source="general"`) otomatik açıyor, sonra `history.replaceState` ile parametreyi URL'den temizliyor (yenilemede tekrar açılmasın diye). Kullanıcı gerçekten mail'e "Yanıtla" derse o cevap hâlâ `noreply@kelimeki.com`'a gider ve kimse görmez — bu link sadece "buraya tıkla, formu doldur" alternatifini sunuyor, gerçek bir iki yönlü yazışma değil.
     **`fromEmailLink` — bu yoldan gelene üyelik teklifi gösterilmiyor (4 Ağustos 2026):** `FeedbackModal` gönderim sonrası misafire "{e-posta} ile üyeliğine devam etmek ister misin?" teklifi çıkarıyor. Ama `?contact=1`'den gelen kişiye zaten BİZ mail atmışız — e-postası bizde kayıtlı ve büyük olasılıkla hesabı da var. En uç örneği hesabı DONDURULMUŞ bir kullanıcının itiraz etmesi: giriş yapamadığından girişsiz görünüyor, itirazını gönderiyor ve sonunda "üye olmak ister misin?" teklifi alıyordu — zaten üyesi. Uygulama bunu tek başına anlayamaz (ziyaretçi girişsiz, elde yalnızca bir e-posta metni var) ve "bu e-posta kayıtlı mı" diye sormak hesap-varlığı sızdıran bir enumeration açığı olurdu; bu yüzden çözüm sorgu değil BAĞLAM: yeni `fromEmailLink` prop'u yalnızca App.tsx'teki İKİ `?contact=1` çağrı yerinde geçiliyor, teklif orada gizleniyor. Uygulama içindeki diğer giriş noktaları (oyun sonu formu, Terms/Privacy) dokunulmadı — orada gerçekten misafir olan biri form doldurabilir, teklif hâlâ anlamlı.

**26 Temmuz 2026'nın üçüncü değişikliği — görünürlük + kısmi bağlama (`feedback_origin_subject_related_to` migration'ı):** Yukarıdaki ikinci değişiklikten hemen sonra iki gerçek eksik fark edildi: (1) `admin-send-message` DB'ye hiçbir şey yazmadığından, admin gönderdiği mesajı bir daha hiçbir yerde göremiyordu — "kime ne yazdım" sorusunun cevabı yoktu; (2) `?contact=1` linkinden gelen her yeni "Genel" geri bildirim (hem bir `feedback-reply` yanıtına hem bir `admin-send-message` mesajına gelen cevaplar dahil) birbirinden ve orijinal mesajdan ayırt edilemeyen, tamamen bağımsız yeni bir satır olarak giriyordu.
- `admin-send-message` artık Brevo'ya göndermeden ÖNCE `feedback`'e `{origin: 'admin', subject, message, user_id: <alıcı>, handled: true}` olarak bir satır YAZIYOR (`.select('id').single()` ile id'yi geri alıyor) — Brevo gönderimi başarısız olursa bu satır geri silinir (`delete().eq('id', inserted.id)`), böylece "gönderilmedi ama kayıtta duruyor" tutarsız bir durum oluşmaz. Kayıt e-postadan önce oluşturuluyor çünkü mailin içine (aşağıya bkz.) bu satırın id'si gömülüyor.
- `_shared/email.ts`'teki sabit `NOREPLY_NOTICE_HTML` bir fonksiyona (`buildNoreplyNoticeHtml(threadId?: string)`) çevrildi — `threadId` verilirse link `?contact=1&re=<threadId>` olur. `feedback-reply` kendi `feedbackId`'sini, `admin-send-message` da az önce oluşturduğu satırın id'sini buraya veriyor.
- `App.tsx`'teki `?contact=1` effect'i artık `re` parametresini de okuyup `contactRelatedTo` state'inde tutuyor ve `FeedbackModal`'ın yeni `relatedTo` prop'una geçiyor; `FeedbackModal` → `submitFeedbackDurable`/`feedbackSync.ts` → `submitFeedback` bunu `feedback.related_to`'ya yazıyor (kendine referans veren nullable FK, `on delete set null`).
- Admin panelinde (`AdminDashboard.tsx`) `origin: 'admin'` satırları "Gönderilen" rozetiyle ve `→ {alıcı}` başlığıyla (normal satırlardaki "kimden geldi" etiketinin tersi) ayrışır, "Yanıtla" gösterilmez. `related_to` dolu satırlar "↳ Cevaben" rozetiyle işaretlenir; genişletilince üstte hangi mesaja cevaben geldiği kısa bir alıntıyla (`feedback?.find(x => x.id === f.related_to)` — liste zaten sayfalamasız tamamen client'ta) gösterilir.
- `feedback_insert_any` RLS politikası gevşetildi: `user_id is null or auth.uid() = user_id or is_admin()` — önceki hâli yalnızca kendi adına (ya da anonim) insert'e izin veriyordu, admin artık "Mesaj Gönder" ile BAŞKA bir kullanıcı adına da satır ekleyebiliyor.
- **Hâlâ çözülmeyen kısım:** Bu, `related_to` yalnızca kişi GERÇEKTEN linke tıklayıp SİTEDEKİ formdan yazarsa çalışır. Kişi mail programında doğrudan "Yanıtla"ya basarsa o cevap yine `noreply@kelimeki.com`'a gider, hiçbir yere düşmez, hiçbir şeye bağlanmaz — gerçek bir e-posta thread'i hâlâ yok, bunun için hâlâ gerçek bir `destek@` gelen kutusu + Brevo Inbound Parsing gerekir (bkz. yukarıdaki "hafif çözüm" notu).

### İki gönderen: `noreply@` (transactional) ↔ `destek@` (insan)

25 Ağustos 2026 kararı. Ayrıntı/kurulum adımları:
**`docs/decisions/support-email.md`**.

| Mail | Gönderen | Kullanıcı "Yanıtla" derse |
|---|---|---|
| Auth şablonları + 10 `notify-*`/`sweep-*` bildirimi | `noreply@kelimeki.com` | **Geri döner** (Zoho'da böyle bir kutu yok) |
| `feedback-reply`, `admin-send-message` | `destek@kelimeki.com` | **Zoho kutusuna düşer** |

`supabase/functions/_shared/email.ts`: `KELIMEKI_SENDER` ↔
`KELIMEKI_SUPPORT_SENDER`. **`sendBrevoEmail`'in `sender`ı verilmezse noreply@
kullanılır** — bir fonksiyon hiçbir şey yapmazsa transactional sayılır; insanın
yazdığı mail `sender`ı açıkça geçmek zorunda. ⚠ **Yeni bir mail gönderen Edge
Function yazarken bu ikisinden birini SEÇ**; varsayılan bilerek yok, üçüncü bir
adres uydurma.

Kullanıcının `destek@`'e yazdığı cevap **admin panelinde OKUNMAZ** (mailin
asıl yeri Zoho). Panel yalnızca haber verir: Geri Bildirim sekmesinin alt
sekme satırındaki küçük **Zoho** düğmesi + kırmızı `CountBadge`, tıklanınca
sayaç sıfırlanıp Zoho gelen kutusu açılır. Sayacın kaynağı `support_inbox`;
onu `inbound-email` (Brevo Inbound webhook'u, `verify_jwt:false` +
`INBOUND_EMAIL_SECRET`) besler. **Gövde saklanmaz** — kimden/konu/tarih.

### Migration'lar — CI yok, elle uygulama

Kullanıcı iPad üzerinden çalışıyor; bunu tetikleyip sonucunu takip edecek bir CLI/CI erişimi yok. Bu yüzden **her yeni migration'ı Claude'un kendisi, Supabase MCP (`apply_migration`/`execute_sql`) ile doğrudan production'a uygulaması gerekiyor** — migration dosyasını repoya eklemek tek başına yeterli değil. Akış:

1. Migration dosyasını normal şekilde `supabase/migrations/` altına yaz.
2. SQL'i kullanıcıya açıkça göster (ne çalıştırılacağını gizleme).
3. Supabase MCP ile aynı SQL'i doğrudan production'a uygula, sonra `execute_sql` ile canlıda doğrula (view/fonksiyon tanımını tekrar oku).
4. Uyguladığını kullanıcıya açıkça söyle ("canlıya uyguladım, doğruladım" gibi) — sessizce dosya eklemekle yetinme.
5. **Her migration'da zorunlu:** `list_migrations` çağırıp `apply_migration`'ın döndürdüğü gerçek versiyon numarasını dosya adındaki zaman damgasıyla karşılaştır — session'ın dosyayı yazdığı an ile sunucuda uygulandığı an birkaç saniye/dakika farklı olabiliyor. Eşleşmiyorsa dosyayı `git mv` ile gerçek versiyona yeniden adlandır ve bunu da commit'e dahil et. Bunu "genelde iyi fikir" değil, adım 1-4 kadar zorunlu bir adım say — 23 Temmuz 2026'da tam bu yüzden ayrı bir PR (#141) açmak gerekti çünkü ilk PR bu kontrol yapılmadan merge edilmişti.

**4 Ağustos 2026 — `.github/workflows/supabase-migrations.yml` tamamen kaldırıldı:** (O tarihte repoda başka workflow kalmamıştı; 6 Ağustos 2026'da mobil port için `mobile-build.yml` eklendi — Flutter analiz/test + Android APK + imzasız iOS + web test ortamı derler, Supabase'e ya da web uygulamasına HİÇ dokunmaz, bkz. `mobile/CLAUDE.md`.) Bu dosya (main'e push'ta `supabase link` + `supabase db push` çalıştırıyordu) yukarıdaki elle-uygulama akışıyla baştan beri çelişiyordu — migration'lar MCP ile zaten uygulanmış geldiğinden `db push` her seferinde "değişiklik yok" diyordu, yani hiçbir güvenlik ağı sağlamıyor, yalnızca bir kalıntı olarak duruyordu. Kullanıcı bir GitHub Actions hata maili alınca incelendi: son başarılı çalışma 3 Ağustos 11:16'ydı, ondan sonraki iki çalışmanın ikisi de `supabase link` adımında `Unexpected error retrieving remote project status: {"message":"Unauthorized"}` ile düşmüştü — yani `SUPABASE_ACCESS_TOKEN` GitHub secret'ı 3 Ağustos'ta 11:16-13:29 arasında geçersizleşmişti. **Hiçbir migration etkilenmedi** (workflow `db push`'a hiç gelemeden ölüyordu, o günün migration'ları zaten MCP ile uygulanıp doğrulanmıştı) ama her migration içeren merge bir hata maili üretiyordu — gerçek bir sorunmuş izlenimi veren, gerçekte hiçbir şey ifade etmeyen bir gürültü. Token'ı yenilemek yerine workflow kaldırıldı: `SUPABASE_ACCESS_TOKEN`/`SUPABASE_DB_PASSWORD` secret'ları repoda BAŞKA HİÇBİR YERDE kullanılmıyordu (uygulamanın kendisi Vercel'deki `VITE_SUPABASE_*` değişkenlerini kullanır, bunlarla ilgisi yok) ve Claude'un MCP erişimi de bu secret'tan tamamen bağımsız. Secret'lar GitHub'da duruyor olabilir, zararsız — ileride gerçekten CI'a geçilirse token'ın yenilenmesi gerekeceğini unutma.
**İleride gerçekten CI'a dönülürse iki şeye dikkat:** (1) migration geçmişi — elle uygulama sürdükçe `supabase_migrations.schema_migrations` ile repo arasındaki eşleşme `db push`'un beklediği durumdan sapabilir (bkz. hemen aşağıdaki 15 Temmuz notu, aynı sebeple yaşanmış bir kopukluk); (2) Edge Function'lar da MCP'nin `deploy_edge_function`'ıyla deploy ediliyor — `supabase functions deploy` CLI'ına geçilirse `verify_jwt: false` olması gereken üç fonksiyonun (`notify-deadline-warnings`, `notify-friend-request-reminders`, `notify-turn-timeout-surrender`) bu ayarı `config.toml`'a taşınmalı, aksi halde cron/Postgres kaynaklı çağrılar 401 almaya başlar (bkz. "Edge Function deploy'ları" bölümü).

**10 Ağustos 2026 — üçüncü workflow: `.github/workflows/branch-cleanup.yml` (elle tetiklenen dal temizliği).** Repoda 209 uzak dal birikmişti (19'u Haziran, 142'si Temmuz, 48'i Ağustos) ve açık PR yoktu — yani neredeyse hepsi işini bitirmiş, yalnızca duruyorlardı. Temizliği Claude oturumundan yapmak MÜMKÜN DEĞİL: bu ortamın git kimliği yalnızca **push** yetkisine sahip, `git push origin --delete` GitHub'dan **403** alıyor (denendi ve doğrulandı — hiçbir dal silinmedi, işlem temiz bir no-op oldu) ve GitHub MCP araçlarında dal silen bir uç yok (`create_branch` var, delete yok). Bu yüzden iş GitHub'ın kendi tarafına, workflow'un `GITHUB_TOKEN`'ına taşındı. **Varsayılan DRY RUN**; `dry_run: false` ile gerçekten siler. Dokunmadığı dört küme: varsayılan dal, `keep` listesi (varsayılanı `main` + aktif mobil port dalı), branch protection'lı dallar ve **AÇIK bir PR'ın head'i olan dallar** (merge edilmemiş iş silinmesin). Özet olarak silinen her dalın sha'sını yazar — geri yükleme hem oradan (`git push origin <sha>:refs/heads/<ad>`) hem PR sayfasındaki "Restore branch" düğmesinden mümkün. **Asıl kalıcı çözüm bu dosya DEĞİL:** Settings → General → Pull Requests → **"Automatically delete head branches"** açılırsa merge edilen her PR'ın dalı kendiliğinden silinir; bu workflow o zaman yalnızca PR'sız/artık dallar için elde kalır. `git`'in "merge edilmiş" saydığı yalnızca 42 daldı — kalan 161'i squash merge edildiğinden ataları eşleşmiyor; yani **dal temizliğinde güvenilecek sinyal `git branch --merged` DEĞİL, PR durumudur** (`git cherry`/`rev-list` sayıları da aynı sebeple yanıltıcı: örnek bir dal 859 "eşleşmeyen" commit gösterirken işi aylar önce PR #157 ile merge edilmişti).

**1 Eylül 2026 — kullanıcı sordu: *"Ben otomatik dal temizliği işaretlemiştim, neden temizlemem gerekiyor hâlâ?"* Ayar AÇIK ve çalışıyor; kapsamı dar.** O gün kalan altı dal tek tek ölçüldü (`list_pull_requests` + `list_branches`) ve iki ayrı sebep çıktı:

| Sebep | Kaç dal | Neden ayar yakalamıyor |
|---|---|---|
| **Hiç PR açılmamış** | 2 (`friend-tab-not-opening`, `image-asset-specs`) | Ayar "merge edilen PR'ın head dalını sil" diyor; PR yoksa tetiklenecek olay yok |
| **Son merge'den SONRA push edilmiş** | 4 (`bolge-sinir-ihlal-vergisi`, `mobile-device-testing`, `play-store-launch`, `version-b-start`) | GitHub dalı merge anında GERÇEKTEN sildi, sonraki push onu yeniden yarattı |

⚠ **İkincisinin kanıtı sha karşılaştırması:** dördünde de merge edilen head sha ile bugünkü dal ucu FARKLI (ör. `play-store-launch`: PR #328 `378e38b` ile merge edildi, dal ucu `4abd4a0`, son commit merge'den bir gün SONRA). Yani "ayar çalışmamış" değil, "çalıştı ve dal sonradan geri geldi".

**Bu, bu deponun iş akışının doğrudan sonucu:** bir oturum tek bir dalda çalışıp ondan arka arkaya birkaç PR açıyor (`mobile-device-testing` daldan **21 PR**), son PR merge olduktan sonra oturum bitmediği için push devam ediyor. Ayar bunu engelleyemez, engellememeli de.

**Sonuç: `branch-cleanup.yml` bir geçici çözüm değil, KALICI olarak gerekli.** Ayar merge anını kapatıyor; workflow yukarıdaki iki durumu. **Pratik kural: bir oturumu bitirirken, o dalın son PR'ı merge edildikten SONRA dala bir daha push etme** — aksi halde temizlik listesine bir satır daha eklenir.

15 Temmuz 2026'da bu yüzden repo ile production'ın migration geçmişi (`supabase_migrations.schema_migrations`) birbirinden kopmuştu: geçmiş migration'lar CI yerine elle (muhtemelen `apply_migration` ile, kendi otomatik zaman damgasıyla) uygulanmış, dosya adlarındaki timestamp'lerle hiç eşleşmiyordu, `supabase db push` bu yüzden sürekli "Remote migration versions not found" hatasıyla fail ediyordu. Tüm dosyaların içeriği tek tek production'da doğrulanıp (`games.players` jsonb için eksik olan tek dosya da eklendi) kayıt tablosu repodaki 26 dosyayla birebir eşleşecek şekilde yeniden yazıldı. Yeni migration eklerken bu senkronu bozmamak için 1-4 adımlarını takip et.

**19 Temmuz 2026'da farklı türde bir kopukluk daha yaşandı** (büyüme grafiği/admin paneli genişletmesi sırasında): bir oturum yukarıdaki 1-4 akışını doğru takip edip migration'ları production'a uyguladı, ama o oturum bitmeden önce kod/dosya değişiklikleri **commit edilmeden** kaldı — üstelik bu değişiklikler, konuyla tamamen alakasız bir başlığa sahip (ilk commit'inden kalma, sonradan hiç güncellenmemiş) **açık bir PR'a** gömülüydü. Sonraki bir oturum, admin panelinde veri gözükmediğini görünce bunu "kod hiç yazılmamış/kaybolmuş" sandı ve migration'ları introspection'dan (`pg_get_functiondef` vb.) sıfırdan yeniden inşa etti — bu da neredeyse iki paralel/çakışan implementasyona (iki ayrı PR, farklı migration timestamp'leri) yol açıyordu; şans eseri açık PR fark edilip onun üstüne inşa edilerek toparlandı. Dersler:
1. "X özelliği bozuk/veri gözükmüyor" tarzı bir sorunla karşılaşınca, koda dalmadan önce **açık PR'lara ve branch'lere bak** (`list_pull_requests`) — production'da migration'lar zaten uygulanmış ama karşılık gelen kod hiç merge edilmemiş olabilir.
2. Çok commit'li bir PR'ın başlığı yalnızca ilk commit'i yansıtabilir; gövdesine/commit listesine bakmadan başlığı "alakasız" diye atlama.
3. Bir migration dosyası yazılıp `apply_migration` ile uygulandıktan sonra dosya adı **mutlaka** `list_migrations`'ın döndürdüğü gerçek versiyon numarasıyla eşleştirilmeli — session'ın dosyayı yazdığı an ile `apply_migration`'ın sunucuda çalıştığı an birkaç saniye/dakika farklı olabiliyor, aksi halde 15 Temmuz'daki sorun tekrarlanır.

### Edge Function deploy'ları — `deploy_edge_function` MCP aracının iki tuzağı (2 Ağustos 2026, kod incelemesi sırasında bulundu/çözüldü)

Aylardır CLAUDE.md'nin çeşitli yerlerinde ayrı ayrı "kesin sebebi netleştirilmedi" notuyla kayıtlı duran `_shared/email.ts` import yolu tutarsızlığı (bazı fonksiyonlar `'../_shared/email.ts'`, bazıları `'./_shared/email.ts'`) bu incelemede kök sebebiyle birlikte çözüldü — ayrıca bu sırada **ikinci, daha tehlikeli bir tuzak** da bulundu. İkisi de `deploy_edge_function` MCP aracının kendi davranışıyla ilgili, kodun kendisiyle değil.

1. **Import yolu — kök sebep artık netleşti:** Araç, verdiğin `entrypoint_path`i olduğu gibi kullanmıyor, tüm dosyaları örtük bir `source/` klasörünün altına yerleştiriyor. Doğru/kararlı tarif: `entrypoint_path: "source/index.ts"` VER, entrypoint dosyasının adını da `"source/index.ts"` YAP (böylece gerçekte `source/source/index.ts`e iner) ve kardeş bağımlılık dosyalarını (`_shared/email.ts` gibi) **hiçbir `source/` öneki OLMADAN** adlandır (böylece `source/_shared/email.ts`e iner) — bu durumda `source/source/index.ts`'ten `source/_shared/email.ts`'e giden doğru göreli yol her zaman `'../_shared/email.ts'`dir. `'./_shared/email.ts'` kullanan 6 fonksiyonun (`notify-account-banned`, `notify-account-unbanned`, `notify-deadline-warnings`, `notify-friend-request-reminders`, `notify-local-game-abandoned`, `notify-turn-timeout-surrender`) bugüne kadar hiç patlamadan çalışmasının sebebi, o fonksiyonların ilk deploy'unda bu tarifin (muhtemelen) tutarlı uygulanmamış olması, yani dosyaların gerçekte BEKLENENDEN farklı bir iç içe klasör yapısına yerleşmiş olmasıydı — CLAUDE.md'de "CI/CLI deploy'a geçilirse 6 fonksiyon anında bozulur" diye zaten öngörülmüştü, bu doğru bir öngörüydü. **Düzeltme:** 6 fonksiyonun hepsi `'../_shared/email.ts'`e çevrilip yukarıdaki tarifle yeniden deploy edildi — artık 11 Edge Function'ın tamamı aynı, tek doğru importu kullanıyor.
2. **`verify_jwt` — aracın kendi varsayılanı `true`, parametre REQUIRED değilse bile geçilmezse önceki deploy'un değerini KORUMUYOR:** Bu araçla (CLI/`supabase functions deploy` değil) yapılan bir redeploy'da `verify_jwt` parametresi verilmezse, önceden `false` olan bir fonksiyon SESSİZCE `true`'ya döner — kod hiç değişmese bile. Bu, `notify-deadline-warnings`i (cron tarafından JWT'siz çağrılıyor, `verify_jwt:false` olması ŞART) bu incelemenin bir yan etkisi olarak neredeyse kırıyordu: fonksiyonun kodunu (CRON_SECRET kontrolü, satır başına try/catch) güncelleyip `verify_jwt` belirtmeden deploy edince araç onu `true`'ya çevirdi, `list_edge_functions`'la fark edilip aynı anda ikinci bir deploy'la (bu kez `verify_jwt: false` açıkça verilerek) geri alındı — production'a hiç sızmadı ama neredeyse pg_cron'un 15 dakikada bir 401 almaya başlamasına yol açıyordu. **Kural: `deploy_edge_function`'ı çağırmadan ÖNCE her zaman `list_edge_functions`/`get_edge_function` ile fonksiyonun MEVCUT `verify_jwt` değerini kontrol et ve deploy çağrısına AYNI değeri açıkça geçir — asla parametreyi atlayıp aracın varsayılanına (`true`) güvenme.** Projedeki `verify_jwt:false` olması gereken fonksiyonlar (**25 Ağustos 2026'da canlıdan sayıldı: ALTI tane** — bu liste uzun süre üç diyordu, sonradan eklenen üçü hiç işlenmemişti): `notify-deadline-warnings`, `notify-friend-request-reminders` (ikisi de pg_cron'dan JWT'siz çağrılıyor), `notify-turn-timeout-surrender` ve `notify-welcome` (Postgres'in kendisinden `net.http_post` ile JWT'siz çağrılıyor), `sweep-unconfirmed-accounts` (cron), `inbound-email` (Brevo webhook'u, kendi paylaşılan sırrıyla korunuyor) — geri kalanı `true`.

### Play Store öncesi güvenlik geçişi (5 Eylül 2026) — `anon` kimlik sızıntısı

Kullanıcı isteği: *"Play Store öncesi kapsamlı bir code review iyi olabilir.
Buglar, temizlik, güvenlik, performans."* İlk geçiş güvenlikti; bulguların
tamamı `ROADMAP.md` → "Güvenlik geçişi — açık kalan maddeler"de. Burada
yalnızca **kapatılan** madde ve ondan çıkan kalıcı kural var.

**Ne bulundu.** `profiles_select_own_or_admin` politikası bir kullanıcının
YALNIZCA kendi profilini okumasına izin veriyor — yani başkalarının adı
bilerek view'lara emanet edilmiş. Ama `leaderboard`, `player_stats`,
`player_stats_overall` ve `k_lig_siralama` hem `anon`'a açıktı hem de
`SECURITY DEFINER` olduğu için RLS'i atlıyordu. `set local role anon` ile
ölçüldü:

| Sorgu (`anon`) | Önce | Sonra |
|---|---|---|
| `profiles` / `games` | 0 satır ✅ | 0 satır |
| `leaderboard` | **30 satır** (user_id + ad + soyad DOLU) | `42501 permission denied` |
| `player_stats` | 46 satır | reddedildi |
| `player_stats_overall` / `k_lig_siralama` | 30 / 30 satır | reddedildi |
| `get_profile_age_gender(30 UUID)` | **19 kişide yaş + cinsiyet** | reddedildi |

Yani yayınlanmış anon anahtarıyla, oturum açmadan, tüm üye listesi + ad
soyad + 19 kişinin yaşı/cinsiyeti okunabiliyordu. Zincir iki halkalıydı:
view'dan UUID topla → RPC'ye ver.

**⚠ KURAL — advisor'ın önerdiği düzeltme özelliği KIRAR.** Supabase güvenlik
paneli bu üç view için "`security_invoker`a çevir" diyor. Uygulansaydı
`profiles` politikası devreye girer ve **girişli** kullanıcı da kendi
satırından başkasını göremez, k-lig listesi boşalırdı. Doğru düzeltme
grant'te: `anon` gider, `authenticated` aynen kalır. **Bir advisor önerisini
uygulamadan önce her zaman sor: bu view/politika hangi ÖZELLİĞİ besliyor?**

**⚠ İkinci kural — `security_invoker` aşağıdan yukarı miras KALMAZ.**
`k_lig_siralama` zaten `security_invoker=true` taşıyordu, yani birileri onu
"doğru" yapmıştı; ama `leaderboard`'dan (definer) select ettiği için o ayar
hiçbir işe yaramıyordu. Bir view zincirinde atlama en alttaki definer
view'dan gelir — dördü birlikte kapatılmalıydı, üçü değil.

**Kullanıcı etkisi: YOK, ölçüldü.** Bu view'ları okuyan her istemci yolu
oturum arkasında: web `Leaderboard` yalnızca `UserMenu`/`ScoreCard`/
`PlayerScoreCard`'dan mount ediliyor; `useRankScores` misafirde `key` boş
olduğu için isteği HİÇ göndermiyor; portun `RankScores.ensure`ı aynı şekilde
`id != null` filtresiyle çıkıyor. İki anon route (`/game/:id`,
`/davet/:token`) yalnızca `get_shared_game` ve `get_friend_invite_info`
çağırıyor — ikisi de `anon`'da BIRAKILDI, bilerek. Uygulama sonrası
`authenticated` rolüyle sondalandı: 30/30/46/30 satır, yani liste aynen
çalışıyor.

**⚠ Bu bir SUNUCU değişikliğiydi — kapalı testteki paketi de anında
etkiledi.** `main`'e merge beklemez; yanılma bedeli port tarafında yeni bir
sürüm turu olurdu. Bu yüzden portun kodu da uygulama ÖNCESİ okundu. Sunucu
tarafı bir güvenlik düzeltmesinde refleks bu olmalı: istemcinin mağazadaki
sürümü ne yapıyor?

**Geri alma** tek satır ve anında: `grant select on public.leaderboard to
anon;` (ve diğer üçü). Migration: `20260905050730_revoke_anon_identity_leak`.

**`my_leaderboard_rank` bilerek dokunulmadı:** `SECURITY INVOKER` ve
`k_lig_siralama`yı okuduğundan view revoke'u onu geçişli olarak zaten
kapatıyor. En dar değişiklik tercih edildi.

**Ek (aynı gün) — trigger fonksiyonlarının REST erişimi:** Sekiz
`SECURITY DEFINER` trigger fonksiyonunun dördü `anon`+`authenticated`e
`execute` iznine sahipti, yani `/rest/v1/rpc/<ad>` uçları açıktı; ötekiler
zaten yalnızca `service_role`'du. Tutarsızlık giderildi (migration
`20260905055111`). **Kalıcı kural: bir trigger fonksiyonu yazarken
kuruluştaki örtük grant'i temizlemeyi unutma** — `revoke execute ... from
public, anon, authenticated`. Trigger'ı bozmaz, çünkü **EXECUTE izni
`create trigger` anında kontrol edilir, ateşlenirken değil**; bu depoda
ölçüldü (`feedback_rate_limit_check` 22 Temmuz'da aynı şekilde kapatıldı ve
sonrasında 18 geri bildirim satırı o trigger'dan geçerek girdi).
