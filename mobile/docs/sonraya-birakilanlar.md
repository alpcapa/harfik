# Sonraya Bırakılan İşler (mobil)

Karar verilmiş ama henüz yapılmamış mobil işler. Kök `CLAUDE.md`'nin "Web'de
Yapılacak İşler" listesinin mobil karşılığı; kökte aynı sınıf
`docs/decisions/product-backlog.md`'de duruyor.

**31 Ağustos 2026'da `mobile/CLAUDE.md`'den buraya taşındı.** Gerekçe doküman
boyutu bütçesi (kök `CLAUDE.md` → "Doküman Boyutu Bütçesi"): o dosya `auto`
sınıfında, yani HER TURDA bağlama yükleniyor ve orada yalnızca her yerde
geçerli kural/değişmez kalmalı. Bir backlog tanımı gereği o değil — bir
madde ancak üzerinde çalışılırken okunur.

Kök `CLAUDE.md`'nin "Web'de Yapılacak İşler" listesinin mobil karşılığı —
kararı verilmiş ama henüz yapılmamış işler. Bir madde uygulanınca buradan
silinip kendi tarihli parça notuna taşınır.

- ~~Sistem fontu büyütülünce düzen patlıyor~~ — **YAPILDI** (28 Ağustos
  2026, Parça 161): yazı ölçeği `kMaxTextScale`=1,3 ile sınırlandı
  (`ui/text_scale.dart` + `MaterialApp.builder`), tahtanın alt şeridi
  `Row`→`Wrap` oldu, arkadaşlık isteği satırı büyük ölçekte ikiye bölünüyor.
  Ölçüldü: ölçek 1,3'te taşma **10 → 0**; istek satırındaki isim 1,3'te
  53,2 → 121,4 px, 2,0'da 0,0 → 187,0 px. Kural ve tuzaklar aşağıda
  ("Sistem Yazı Boyutu"), envanter Parça 161'de.

- **KGP uyarısı — ileride derlemeyi KIRACAK (23 Ağustos 2026'da `.aab`
  log'unda ölçüldü, bugün yalnızca uyarı):** `image_picker_android`,
  `share_plus` ve `shared_preferences_android` Kotlin Gradle Plugin'i
  kendileri uyguluyor; Flutter'ın uyarısı birebir *"Future versions of
  Flutter will fail to build if your app uses plugins that apply KGP"*.
  Bugün acil DEĞİL (derleme geçiyor) ve bu eklentiler bizim değil —
  çözümü kendi sürümlerini Built-in Kotlin'e geçmiş sürümlere yükseltmek.
  Flutter yükseltmesi yapılırken ÖNCE bunların changelog'una bak;
  aksi halde yükseltme günü derleme sebebi anlaşılmayan bir şekilde kırılır.
  - ⚠ **28 Ağustos 2026'da liste ÜÇTEN BEŞE çıktı** (PR #360, Parça 158 —
    CI log'unda okundu): push/Analytics ile gelen **`firebase_core`** ve
    **`firebase_analytics`** de KGP uyguluyor. Derleme yine geçti (`.aab`
    üretildi ve imzası doğrulandı), ama borç büyüdü — Flutter yükseltmesi
    artık üç değil BEŞ eklentinin changelog'una bakmayı gerektiriyor.
  - ✅ **30 Ağustos 2026'da `in_app_update` eklendi (Parça 171) ve liste
    BEŞTE KALDI** — CI log'undan okundu (PR #371, `bundleRelease`):
    *"…apply Kotlin Gradle Plugin (KGP): firebase_analytics, firebase_core,
    image_picker_android, share_plus, shared_preferences_android"*.
    Yani `in_app_update` KGP uygulamıyor, borç büyümedi. Yeni bir eklenti
    eklerken bu kontrolü tekrarla: cevap yalnızca Android işinin log'unda.
- ~~Bağlantı durumu göstergesi (`useOnlineStatus` portu)~~ — **YAPILDI**
  (14 Ağustos 2026): karar mantığı Parça 96'da (`util/online_status.dart` +
  `connectivity_plus`), Board alt şeridindeki görsel "Çevrimdışı" rozeti
  Parça 97'de.
- ~~Kayıt onayı maili kaydın GELDİĞİ kanala dönmeli~~ — **YAPILDI**
  (28 Ağustos 2026, Parça 158): `AuthService.signUp` artık
  `emailRedirectTo: authRedirectUri` geçiyor (`config/env.dart`), web
  istemcisi DEĞİŞMEDİ. Değer bilerek **`https://kelimeki.com/auth`** — custom
  şema (`kelimeki://auth`) ile başlandı ve aynı gün https'e çevrildi:
  uygulamanın kurulu OLMADIĞI bir tarayıcıda (insanlar postalarını sıklıkla
  masaüstünden okur) custom şema `ERR_UNKNOWN_URL_SCHEME` çıkmazı veriyordu,
  yani onay linki BOZUK görünüyordu. Gerekçenin tamamı `env.dart`'ın
  başlığında.
  - **Dashboard el işi:** Redirect URLs listesinde `https://kelimeki.com/**`
    ZATEN var (davet linkleri için), yani ek bir kayıt gerekmedi —
    `kelimeki://reset`in aksine.
  - **Doğrulama sınırı DEĞİŞMEDİ, yalnızca yer değiştirdi:** App Links
    doğrulaması YALNIZCA Play imzalı derlemede geçer, CI'nın debug-imzalı
    `.apk`'sında geçmez. Yani `.apk`da görülecek olan güvenli yedek yoldur
    (link tarayıcıda açılır, kullanıcı elle giriş yapar = bugünkü davranış);
    "uygulama açılıyor + doğrudan girişli kalıyor" yarısı ancak kapalı test
    kanalından kurulan derlemede doğrulanabilir (`mobile/TESTING.md` 9.16).
  - **`signup_channel` ile KARIŞTIRMA:** o alan 'direct'/'form' ayrımını
    (hangi FORMDAN gelindiği) tutuyor; buradaki "kanal" platform.
  - **Eski davranış bir HATA değildi, kayda geçsin:** T3'ün onay linki
    sunucuda gerçekten işliyordu (`email_confirmed_at` linke basılan an) ve
    tarayıcıdaki başka bir oturuma DOKUNMUYORDU — link kimseyi giriş
    yaptırmıyor, yalnızca o origin'de zaten duran oturum görünüyordu.
    PKCE'nin verifier'ı öteki origin'de olduğundan takas yapılamıyor; bu aynı
    zamanda güvenlik açısından doğru taraf (aksi halde bir kullanıcının onay
    linki başka bir hesabın açık oturumunu sessizce ezerdi).
