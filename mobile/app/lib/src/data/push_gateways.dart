// `PushRepo`nun GERÇEK uçları — Firebase eklentisi ve Supabase tablosu.
//
// `push_repo.dart`tan AYRI bir dosya, çünkü orası saf karar mantığı ve
// testlerde sahte uçlarla koşuyor; burası ise Firebase/Supabase'e bağlı ve
// birim testine girmiyor. Aynı ayrım `friends_api.dart` ↔ gateway'lerinde
// de var.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_repo.dart';
import 'push_taps.dart';

/// `AuthorizationStatus` → bizim üç durumumuz.
///
/// `provisional` (yalnız iOS: sessiz teslim, kullanıcı sonradan onaylıyor)
/// VERİLMİŞ sayılıyor — bildirim gerçekten gidiyor, yalnızca sessiz kutuda.
/// Bunu `denied` saymak, izni olan kullanıcıya tekrar tekrar sormak olurdu.
PushPermission izinDurumu(AuthorizationStatus s) => switch (s) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermission.granted,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.deniedPermanently => PushPermission.permanentlyDenied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };

class FirebasePushMessaging implements PushMessaging {
  final FirebaseMessaging _fm;
  FirebasePushMessaging([FirebaseMessaging? fm])
      : _fm = fm ?? FirebaseMessaging.instance;

  @override
  Future<String?> token() => _fm.getToken();

  @override
  Stream<String> onTokenRefresh() => _fm.onTokenRefresh;

  @override
  Future<PushPermission> permission() async =>
      izinDurumu((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      izinDurumu((await _fm.requestPermission()).authorizationStatus);
}

/// Bildirime dokunma akışının gerçek ucu (Faz 3) — bkz. push_taps.dart.
///
/// FCM'in "notification" mesajlarında sistem tepsisindeki bildirime
/// dokunmak iki yoldan gelir ve İKİSİ AYRI API: uygulama arka plandaysa
/// `onMessageOpenedApp` akışı, kapalıysa `getInitialMessage` (tek seferlik).
/// `friend_invite_inbox.dart`ın AppLinks'te öğrendiği ders burada da
/// geçerli: soğuk başlangıç ayrı bir yol, akışa güvenip atlanamaz.
class FirebasePushTapSource implements PushTapSource {
  final FirebaseMessaging _fm;
  FirebasePushTapSource([FirebaseMessaging? fm])
      : _fm = fm ?? FirebaseMessaging.instance;

  @override
  Stream<Uri> get taps => FirebaseMessaging.onMessageOpenedApp
      .map((m) => pushMessageLink(m.data))
      .where((u) => u != null)
      .cast<Uri>();

  @override
  Future<Uri?> initialTap() async {
    final m = await _fm.getInitialMessage();
    if (m == null) return null;
    return pushMessageLink(m.data);
  }
}

class SupabasePushTokenStore implements PushTokenStore {
  final SupabaseClient client;
  SupabasePushTokenStore(this.client);

  @override
  Future<void> upsert({
    required String token,
    required String userId,
    required String platform,
    String? appVersion,
  }) async {
    // ⚠ TABLOYA DOĞRUDAN UPSERT ETME — RLS devri SESSİZCE reddediyor
    // (29 Ağustos 2026, gerçek cihaz testi adım 2.5'te bulundu).
    //
    // Burada eskiden `from('push_tokens').upsert(..., onConflict: 'token')`
    // vardı ve yorumu "aynı cihazda A çıkıp B girerse satır B'ye DEVREDİLİR"
    // diyordu. Kağıt üzerinde doğru, üretimde YANLIŞ: birincil anahtar
    // `token` olduğundan ikinci kullanıcının upsert'ü UPDATE dalına düşüyor,
    // `push_tokens_update_own` politikası ise `USING (auth.uid() = user_id)`
    // ile MEVCUT satıra bakıyor — satır hâlâ A'nın, dolayısıyla B için
    // görünmez. Cihazda ölçüldü:
    //   ERROR 42501: new row violates row-level security policy
    //                (USING expression) for table "push_tokens"
    //
    // Bedeli boşa gönderim değil YANLIŞ KİŞİYE gönderim: A'ya gidecek
    // bildirim, B'nin girişli olduğu telefona düşer.
    //
    // Devri artık sunucu üstleniyor (`register_push_token`, SECURITY
    // DEFINER). `user_id` GÖNDERİLMİYOR — fonksiyon onu `auth.uid()`ten
    // alıyor, yani istemci token'ı başkasının üstüne yazamaz. [userId]
    // parametresi imzada duruyor çünkü çağıran taraf (PushRepo) hangi hesap
    // için hizaladığını hâlâ biliyor olmalı; sunucuya geçmiyor.
    // ⚠ `p_app_version` fonksiyonda VARSAYILANLI (null) — yani bu parametreyi
    // hiç göndermeyen sahadaki 1.0.0-1.0.3 istemcileri aynı fonksiyona
    // çözülmeye devam ediyor (migration'da kanıtlandı: 2 argümanlı çağrı
    // 42883/42725 DEĞİL, fonksiyonun kendi 'Oturum gerekli.' hatasını
    // veriyor). Eski 2 parametreli sürüm DÜŞÜRÜLDÜ, üstüne yazılmadı —
    // yan yana dursalardı 2 argümanlı çağrı ikisine birden uyup
    // "function is not unique" (42725) verirdi.
    await client.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': platform,
      'p_app_version': appVersion,
    });
  }

  @override
  Future<void> remove(String token) async {
    await client.from('push_tokens').delete().eq('token', token);
  }
}
