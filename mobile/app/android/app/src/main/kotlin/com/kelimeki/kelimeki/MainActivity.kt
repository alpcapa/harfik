package com.kelimeki.kelimeki

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
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
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Sıra sana geldiğinde, süren dolmak üzereyken ve " +
                "davet aldığında haber verir."
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
