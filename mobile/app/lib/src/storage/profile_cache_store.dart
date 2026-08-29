// Girişli kullanıcının profilinin YEREL kopyası.
//
// NEDEN VAR (29 Ağustos 2026, cihaz testi 6.3 — kullanıcı uçak modunda
// bildirdi: *"T2 yerine KE yazıyor"*): profil her açılışta sunucudan
// çekiliyordu ve önbelleği YOKTU. Bağlantı olmayınca çekim düşüyor,
// `menuName` zinciri (`display_name` → `username` → ad soyad → **e-posta**)
// en sona, yani e-postaya iniyor ve avatar `kelimekitest2@…`'dan "KE"
// türetiyor. Oturum diskte yaşadığı için kullanıcı GİRİŞLİ, ama kim olduğu
// yanlış görünüyor.
//
// ⚠ **ANAHTAR user_id — bu bir tercih değil, güvenlik/doğruluk şartı.**
// Tek bir "son profil" kaydı tutulsaydı, hesap değiştiren kullanıcı offline
// açılışta ÖNCEKİ kişinin adını görürdü. Aynı sınıftan iki hata bu projede
// zaten yaşandı (`AccountScope`'un var olma sebebi; 29 Ağustos'ta push
// token'ında iki kez daha). Kimliğe göre anahtarlamak bunu yapısal olarak
// imkânsız kılıyor: yanlış kullanıcının kaydı OKUNAMAZ, çünkü aranan
// anahtar hiç eşleşmez.
//
// Saklanan şey profilin HAM satırı (`profiles` tablosundan gelen map) —
// `KProfile.fromMap` ile aynı ayrıştırıcıdan geçiyor, yani ikinci bir
// biçim/sözleşme doğmuyor.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileCacheStore {
  final SharedPreferences prefs;
  const ProfileCacheStore(this.prefs);

  static String _key(String userId) => 'profile_cache_$userId';

  /// Bozuk/eski bir kayıt uygulamayı düşürmemeli — okunamıyorsa yok sayılır
  /// (depolama katmanının "karantina" disiplini: silme, ama güvenme).
  Map<String, Object?>? read(String userId) {
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw);
      return d is Map ? d.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, Map<String, Object?> row) async {
    try {
      await prefs.setString(_key(userId), jsonEncode(row));
    } catch (_) {
      // Yazamamak bir hata DEĞİL: önbellek bir kolaylık, kaynak sunucu.
    }
  }

  Future<void> clear(String userId) => prefs.remove(_key(userId));
}
