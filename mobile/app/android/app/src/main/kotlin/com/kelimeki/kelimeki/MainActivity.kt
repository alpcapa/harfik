package com.kelimeki.kelimeki

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * Bildirim panelini temizleyen kanal (ROADMAP #15, 31 Ağustos 2026).
     *
     * NEDEN VAR: bir kullanıcı uygulama simgesindeki rozetin 9'da takılı
     * kaldığını bildirdi. Rozet uygulamanın kendi sayacı DEĞİL — Samsung
     * One UI onu panelde HÂLÂ DURAN bildirimlerden türetiyor; bildirime
     * dokunmak yalnızca O bildirimi kapatıyor. Uygulama öne geldiğinde
     * Dart tarafı (`_HomeGate.didChangeAppLifecycleState`) burayı çağırıyor.
     *
     * ⚠ Kanal adı ve metot adı Dart tarafıyla (`data/notification_shade.dart`)
     * BİREBİR aynı olmak zorunda. Uyuşmazlık SESSİZ bir arıza: Dart
     * `MissingPluginException`ı yutuyor, yani rozet temizlenmez ve hiçbir
     * hata görünmez. `notification_shade_parity_test.dart` bunu zorluyor —
     * bildirim KANALI kimliğinde (`kelimeki_oyun`) öğrenilen dersin aynısı.
     *
     * `cancelAll()` yalnızca BU uygulamanın bildirimlerini kaldırır; başka
     * uygulamalara dokunamaz (Android izin vermez).
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kelimeki/bildirimler")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hepsiniTemizle" -> {
                        getSystemService(NotificationManager::class.java)?.cancelAll()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Oyun bildirimleri kanalı (Android 8 / API 26+).
     *
     * ⚠ NEDEN ELLE YARATILIYOR: sunucu (`_shared/push.ts`) yükte
     * `channel_id: "kelimeki_oyun"` gönderiyor. Android 8+'ta VAR OLMAYAN bir
     * kanala gelen bildirim GÖSTERİLMEZ ve hiçbir hata da vermez — tam olarak
     * bu projenin en sevmediği "sessiz arıza" sınıfı: sunucu 200 döner, kimse
     * bir şey görmez. Kanal burada yaratılmazsa kimlik zinciri, token, izin,
     * hepsi doğru olsa bile bildirim düşmez.
     *
     * Kimliği `_shared/push.ts`teki `channel_id` ile BİREBİR AYNI olmak
     * zorunda; biri değişirse öteki de değişmeli (derleyici bunu yakalamaz).
     *
     * `createNotificationChannel` tekrar çağrılmaya güvenli — var olan kanalı
     * yeniden yaratmaz, yalnızca adı/açıklamayı günceller. Kullanıcının
     * kanaldan yaptığı önem/ses değişikliklerine DOKUNMAZ (Android kilitler).
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "kelimeki_oyun",
            "Oyun bildirimleri",
            // ⚠ HIGH, DEFAULT DEĞİL — 28 Ağustos 2026'da gerçek cihazda ÖLÇÜLDÜ.
            // DEFAULT (3) ile bildirim geliyordu ama SESSİZ bir biçimde:
            // kullanıcı "mesaj sesi geldi, ikonda 1 yazdı, ama popup görmedim"
            // dedi — ses ✅, gölgelik ✅, rozet ✅, peek (açılır banner) ❌.
            // Android 8+'ta açılır banner YALNIZCA IMPORTANCE_HIGH (4) ile
            // çıkıyor.
            //
            // Sunucunun yolladığı `priority: 'high'` (_shared/push.ts) bunu
            // SAĞLAMAZ: o FCM'in TESLİMAT önceliği (cihazı uyandırma), sunum
            // değil. Sunumu kanal önemi belirliyor — ikisi ayrı kavram ve
            // birbirinin yerine geçmiyor.
            //
            // ⚠ ÖNEM SONRADAN YÜKSELTİLEMEZ: Android kanal önemini yaratıldığı
            // anda kilitliyor (ayar kullanıcıya ait). Kanalı DEFAULT'la almış
            // bir cihazda bu değişiklik ancak uygulama silinip yeniden
            // kurulunca etkili olur. Bugün bunun bedeli yok — kanal bu
            // sürümle (412) DOĞDU, yani yalnızca geliştirme cihazında var;
            // Play'deki 407 push'tan önceki sürüm. Kanal ileride yeniden
            // adlandırılırsa (id değişirse) `_shared/push.ts` de değişmeli;
            // `notification_channel_parity_test.dart` bunu zorluyor.
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Sıra sana geldiğinde, süren dolmak üzereyken ve " +
                "davet aldığında haber verir."
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
