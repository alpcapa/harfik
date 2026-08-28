// `PushRepo`nun GERÇEK uçları — Firebase eklentisi ve Supabase tablosu.
//
// `push_repo.dart`tan AYRI bir dosya, çünkü orası saf karar mantığı ve
// testlerde sahte uçlarla koşuyor; burası ise Firebase/Supabase'e bağlı ve
// birim testine girmiyor. Aynı ayrım `friends_api.dart` ↔ gateway'lerinde
// de var.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_repo.dart';

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

class SupabasePushTokenStore implements PushTokenStore {
  final SupabaseClient client;
  SupabasePushTokenStore(this.client);

  @override
  Future<void> upsert({
    required String token,
    required String userId,
    required String platform,
  }) async {
    // ⚠ Çakışma anahtarı TOKEN. Aynı cihazda A çıkıp B girerse token AYNI
    // kalır ve satır B'ye DEVREDİLİR — çoğalmaz. Varsayılan (birincil
    // anahtar) davranış zaten bu, ama açıkça yazmak niyeti görünür kılıyor:
    // `user_id` üzerinden bir upsert, aynı kişinin ikinci cihazını silerdi.
    await client.from('push_tokens').upsert({
      'token': token,
      'user_id': userId,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  @override
  Future<void> remove(String token) async {
    await client.from('push_tokens').delete().eq('token', token);
  }
}
