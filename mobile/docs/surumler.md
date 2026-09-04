# Sürüm Kütüğü — Play'e yüklenen her paket

**Bu dosya KANONİK kaydıdır:** hangi sürüm, hangi `versionCode`, hangi
commit'ten, ne zaman yüklendi ve şu an ne durumda. "Yayında olan paket
hangisi?" sorusunun tek cevap yeri burasıdır.

**Neden ayrı bir dosya (4 Eylül 2026, kullanıcı isteği):** kütük daha önce
`build-and-distribution-log.md`in içinde, "Play Store İmzalama" bölümünün
altında bir alt başlıktı — yani adı imzalamayı anlatan 25 KB'lık bir karar
kaydının içinde gömülüydü ve bulunması için önce o dosyayı bilmek
gerekiyordu. Kullanıcı *"bir tane App version dosyası yap, bugüne kadar
çıkan tüm sürümleri güncel tut"* dedi. İçerik taşındı, **kopyalanmadı**;
eski yerinde yalnızca buraya bir işaret var.

⚠ Bu dosyanın kendisi bir bölünme dersinin ürünü: 2 Eylül 2026'ya kadar
kütük diye bir şey YOKTU, "hangi `versionCode` yayında" bilgisi
`ROADMAP.md`'nin sürüm turu bölümüyle karar kaydı arasında ikiye bölünmüştü
ve biri kapanırken öteki kapanmamıştı. **İş bölümü:** burası hangi PAKETİN
yayında olduğunu tutar; `ROADMAP.md` sürüm TURUNU (ne girdi, hangi kapı
açıldı) anlatır; `docs/decisions/roadmap-arsiv.md` kapanmış turları saklar.

---

## `versionCode` nereden geliyor

`.github/workflows/mobile-build.yml`:

```
flutter build appbundle --release "--build-number=${{ github.run_number }}"
```

Yani **`versionCode` = GitHub Actions koşu numarası.** `pubspec.yaml`'daki
`+1` Play'e HİÇ gitmez — orada hep `+1` yazması bir hata değil, CI onu
eziyor. (Play aynı `versionCode`'u iki kez kabul etmediğinden `pubspec`'in
sabit değeri ikinci yüklemede reddedilirdi; kural bu yüzden var.)

Pratik sonuç: **`versionCode` bir koşu numarasıdır**, o koşunun sayfasından
hangi commit'ten derlendiği okunabilir. `sha` sütununu doldurmanın en kolay
yolu budur.

---

## Kütük

| Sürüm | versionCode | sha | pubspec'te sürüm | Play'e yükleme | Durum | İçerik |
|---|---|---|---|---|---|---|
| 0.1.0 | — | `28b93ac` | 19 Ağu 2026 | **yüklenmedi** | — | Play öncesi; mağaza hazırlığı başlamamıştı |
| 1.0.0 | — | `48f01a1` | 28 Ağu 2026 | Console'dan doğrulanmadı | — | Derin bağlantı kanalı + push bildirimleri. In-App Update mekanizması YOKTU (bkz. `build-and-distribution-log.md` → "Güncelleme modeli") |
| 1.0.1 | — | `7dd56ad` | 29 Ağu 2026 | Console'dan doğrulanmadı | — | Zorunlu güncelleme kullanılabilir hâle getirildi |
| 1.0.2 | **435** | `d3d4702` | 30 Ağu 2026 | **30 Ağu, 12:07** (Submission 8) | yayınlandı → pasif | Faz 1 paketi + Play In-App Update. İnceleme **10 dk** (15:29 → Published 15:39, Console saatleri) |
| 1.0.3 | **449** | — | 31 Ağu 2026 (`c1c0437`) | **31 Ağu, 08:00** | yayınlandı → pasif | — |
| 1.0.4 | **467** | — | 31 Ağu 2026 (`72278c3`) | **1 Eyl, 10:25** | yayınlandı → pasif | Faz 6'nın istemci yarısı + Faz 7'nin iki çökmesi + hata hız sınırı |
| 1.0.5 | **501** | `4a0a29b` | 1 Eyl 2026 (`f28b3da`) | **2 Eyl, 14:22** (paket) · sürüm 17:58'de güncellendi | ✅ **kapalı testte YAYINDA** (Alpha, tam dağıtım) | Tahta zoom'u + zoom tanıtım balonu + yazı ölçeği + mesaj kutusu etiketi + cihaz turu düzeltmeleri (rozet kırpması · alt şerit · çevrimdışı şerit · zoom çerçevesi · filigranlar). `.aab` 63.146.275 bayt, SHA-256 `200e82b9…451d4`. İnceleme ≈23 dk. Yayın sonrası cihazda doğrulandı (kullanıcı: *"1.0.5 turu testi tamam."*) |
| **1.0.6** | **525** | `711eaaa` | 3 Eyl 2026 (`a33fdaa`) | ⏳ **hazır, gönderilmedi** | — | Aşağı bkz. |

⚠ **"Console'dan doğrulanmadı" uydurma değil, eksik demek:** 4 Eylül'de
kütük derlenirken Console'un paket listesi 435'e kadar okunabildi, altındaki
satırlar ekranda kalmadı. 1.0.0/1.0.1 için Play'e yükleme yapılıp
yapılmadığı bu depodan çıkarılamıyor. **Console'un "Latest app bundles"
listesini aşağı kaydırıp bakan biri bu iki satırı doldurmalı.**

⚠ 1.0.3 ve 1.0.4'ün `sha`sı boş: `versionCode` koşu numarası olduğundan
Actions'ta 449 ve 467 numaralı koşuların `head_sha`sına bakılarak
doldurulabilir. Doldurulmadı çünkü ölçülmedi.

---

## 1.0.6 (525) — gönderilmeye hazır

**Paket:** `mobile-latest` prerelease'indeki `kelimeki.aab`, koşu 525,
`711eaaa`'dan derlenmiş, release anahtarıyla imzalı (4 Eyl 10:36).

| | |
|---|---|
| İndirme | `https://github.com/alpcapa/kelimeki/releases/download/mobile-latest/kelimeki.aab` |
| Boyut | 63.210.820 bayt |
| SHA-256 | `96f176e64d79a622a2c33cb8e49588c9ce9f15ad13e6bb55060b0f99b4769aca` |
| Yüklendiği an | 4 Eyl 2026, 10:36:00 UTC (release varlığı) |

⚠ Bu SHA-256 **4 Eylül 10:36'daki** pakete ait. `mobile-latest` her mobil
derlemede üzerine yazıldığından, gönderimden önce indirdiğin dosyanın
özetini bununla KARŞILAŞTIR — tutmuyorsa arada yeni bir derleme olmuş
demektir ve gönderdiğin paket bu satırın anlattığı paket değildir.

**Sürüm adı (Console):** `1.0.6 (525)`

**Sürüm notları (`tr-TR`, 491/500 karakter):**

```
Yenilikler
• Oyun geçmişinde "Tekrar Oyna": biten bir Canlı oyunun aynı kadrosuyla rövanş daveti gönder.
• Skor kartında kafa kafaya oran çubuğu — bir rakibe karşı galibiyet/beraberlik/mağlubiyet dağılımın.
• Biten Canlı oyunlarda "Yeni" rozeti: sonucunu görmediklerin işaretli.
• Listelerde süresi bitmeye en yakın oyun en üstte.

Düzeltmeler
• iPad'de paylaşım penceresinin asılı kalması.
• Kafa kafaya oranında teslimlerin beraberlik sayılması.
• Terk edilen oyunun yanlış güne yazılması.
```

**Notlara giren commit'ler:** `c9f03fd` · `76a7151` · `a966dec` ·
`a33fdaa` · `d07c06d` · `711eaaa`.

⚠ **Bilerek dışarıda bırakılan iki değişiklik:** kafa kafaya avatarlarının
büyütülmesi (#426) ve "Yeni Canlı Oyun" çökmesi (#427). İkisi de
`mobile/app/lib` altında **sıfır** dosya değiştirdi — web-only. Mobil sürüm
notuna yazmak, kullanıcıya onun paketinde olmayan bir değişikliği duyurmak
olurdu.

**Cihaz doğrulaması:** APK (`711eaaa`) 4 Eylül'de cihazda koşuldu; §0-§4'ün
koşulabilir maddeleri geçti (ayrıntı: `cihaz-testi-log.md` → "FAZ B — İLK
GERÇEK CİHAZ TURU"). Kullanıcı kuralı sağlandı: *"apk ile test edip
sorunsuz olduğundan emin olmadan aab yapılmayacak."*

---

## Bir sürüm yüklendiğinde ne yapılır

1. **Kütüğe satır ekle** — sürüm, `versionCode`, `sha`, yükleme tarihi.
   `versionCode` ile `sha`yı BİRLİKTE yaz: sahadaki bir ekran
   görüntüsündeki `Derleme <sha>` satırını Console'daki kayda bağlamanın en
   kısa yolu bu.
2. **`.aab`nin SHA-256'sını yaz** — indirdiğin anda. `mobile-latest` her
   mobil derlemede ÜZERİNE yazıldığından "şu an orada duran paket" ile
   "Play'e yüklediğin paket" birkaç saat sonra aynı şey olmayabilir.
3. **Bir önceki sürümün durumunu güncelle** (yayında → pasif).
4. **Sürüm turunu `ROADMAP.md`'de kapat**, kapanınca arşive taşı — bu dosya
   turu değil PAKETİ tutar.

## İnceleme süresi — iki ölçüm, aralık geniş

- `1.0.2 (435)`: **10 dakika** (15:29 → 15:39, Console saatleri)
- `1.0.5 (501)`: **≈23 dakika** (~14:40 → ~15:03)

⚠ İkinci ölçüm Console'dan değil kullanıcının bildirdiği anlardan geliyor,
yani gerçek süre daha kısa olabilir — **üst sınır** sayılmalı. Çıkarım: "10
dakika" bir kural değil **alt sınır**; 20-30 dakikayı normal say ve
"yayınlanmadı herhâlde" teşhisini yarım saatten önce kurma.

⚠ **Published ≠ testçinin telefonunda.** Kapalı testte paket yayınlansa bile
testçiye ulaşması için ayrı koşullar var; ayrıntı ve çare (opt-in linkine
tekrar girme) `build-and-distribution-log.md` → "Kapalı test" bölümünde.
