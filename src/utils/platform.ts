// Kelimeki — bu istemcinin platformu (telemetri).
//
// Mobil lansmanı ölçülebilsin diye 14 Ağustos 2026'da eklendi: girişli tarafta
// bir kullanıcının app'ten mi web'den mi oynadığını söyleyen hiçbir alan yoktu
// (`guest_visits.device_type` yalnızca oturum KAPALIYKEN yazılıyor ve "tarayıcı
// mobil mi masaüstü mü" sorusunu yanıtlıyor — "app mi web mi" DEĞİL).
//
// Bu dosya, web istemcisinin "ben neyim" cevabının TEK yeri: hem oyun kaydı
// (`buildGameRecord` → games.platform) hem Canlı oyun telemetrisi
// (`setOnlineGamePlatform` → online_game_clients) buradan okur, iki yere ayrı
// ayrı literal yazılmaz.
//
// Flutter portundaki karşılığı: `mobile/app/lib/src/util/platform.dart`
// (`currentPlatform` — ios/android/app-web). İkisi AYNI değer kümesini
// paylaşmak zorunda; sunucudaki check kısıtı da aynı dörtlüyü zorluyor
// (`games.platform` ve `online_game_clients.platform`).
import type { ClientPlatform } from '../lib/database.types';

export const CLIENT_PLATFORM: ClientPlatform = 'web';
