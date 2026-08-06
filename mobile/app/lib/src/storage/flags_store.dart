// Küçük bayraklar/tekil değerler — SharedPreferences. Kural: buraya YALNIZCA
// sabit anahtarlı, küçük değerler girer; dinamik anahtar (oyun başına vb.)
// ya da yapısal veri SQLite'a gider (bkz. mobile/CLAUDE.md eşleme tablosu).
// Web→mobil veri taşınması YOK (localStorage okunamaz) — anahtarlar taze
// isim alanında.
import 'package:shared_preferences/shared_preferences.dart';

import '../util/uuid.dart';

class FlagsStore {
  final SharedPreferences prefs;
  FlagsStore(this.prefs);

  static const _seenQuickstart = 'seen_quickstart';
  static const _seenChatIntro = 'seen_chat_intro';
  static const _anonId = 'anon_id';
  static const _anonVisitDate = 'anon_visit_date';
  static const _utmSource = 'utm_source';

  bool get seenQuickstart => prefs.getBool(_seenQuickstart) ?? false;
  Future<void> markQuickstartSeen() => prefs.setBool(_seenQuickstart, true);

  bool get seenChatIntro => prefs.getBool(_seenChatIntro) ?? false;
  Future<void> markChatIntroSeen() => prefs.setBool(_seenChatIntro, true);

  /// Anonim ziyaretçi kimliği — ilk erişimde bir kez üretilir, sonra sabit
  /// (web visitTracking.ts anon-id davranışı).
  Future<String> anonId() async {
    final existing = prefs.getString(_anonId);
    if (existing != null) return existing;
    final id = uuidV4();
    await prefs.setString(_anonId, id);
    return id;
  }

  String? get anonVisitDate => prefs.getString(_anonVisitDate);
  Future<void> setAnonVisitDate(String yyyymmdd) =>
      prefs.setString(_anonVisitDate, yyyymmdd);

  /// UTM kaynağı FIRST-TOUCH'tır: bir kez yazılır, sonraki denemeler yok
  /// sayılır (web captureUtmSource ilkesi — üzerine yazmak kaynağı bozar).
  String? get utmSource => prefs.getString(_utmSource);
  Future<void> captureUtmSource(String source) async {
    if (prefs.getString(_utmSource) != null) return;
    await prefs.setString(_utmSource, source);
  }
}
