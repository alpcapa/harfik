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

  static const _seenIntro = 'seen_intro';
  static const _seenQuickstart = 'seen_quickstart';
  static const _seenChatIntro = 'seen_chat_intro';
  static const _anonId = 'anon_id';
  static const _anonVisitDate = 'anon_visit_date';
  static const _utmSource = 'utm_source';

  /// İlk açılış tanıtımı (`IntroScreen`) bir kez gösterildi mi — web'in
  /// karşılama katmanındaki `kelimeki:seen-intro` anahtarının karşılığı
  /// (19 Ağustos 2026). Setup'taki "Tanıtım" linki bu bayrağa
  /// DOKUNMAZ: oradan açmak bir tekrar gösterim değil, kullanıcının kendi
  /// isteği.
  bool get seenIntro => prefs.getBool(_seenIntro) ?? false;
  Future<void> markIntroSeen() => prefs.setBool(_seenIntro, true);

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

  static const _feedbackTimes = 'feedback_submission_times';

  /// Görüş Bildir rate-limit geçmişi (epoch ms listesi) — web
  /// `kelimeki:feedback-submissions` eşleniği. Pencere/eşik kararı
  /// FeedbackRepo'nun işi; burada yalnızca ham saklama (sabit anahtar,
  /// küçük değer — dosya başındaki kurala uygun).
  List<int> get feedbackSubmissionTimes =>
      (prefs.getStringList(_feedbackTimes) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();

  Future<void> setFeedbackSubmissionTimes(List<int> times) =>
      prefs.setStringList(
          _feedbackTimes, [for (final t in times) t.toString()]);

  static const _pushSorulmaSayisi = 'push_sorulma_sayisi';
  static const _pushSonSorulma = 'push_son_sorulma';

  /// KENDİ izin sayfamızın kaç kez gösterildiği (sistem diyaloğu DEĞİL).
  int get pushSorulmaSayisi => prefs.getInt(_pushSorulmaSayisi) ?? 0;

  /// Son gösterim anı — iki sorma arasındaki yedi günlük aralık için.
  DateTime? get pushSonSorulma {
    final ms = prefs.getInt(_pushSonSorulma);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> pushSorulduIsaretle(DateTime an) async {
    await prefs.setInt(_pushSorulmaSayisi, pushSorulmaSayisi + 1);
    await prefs.setInt(_pushSonSorulma, an.millisecondsSinceEpoch);
  }

  // NOT: burada bir "sistem reddi sayacı" VARDI ve 28 Ağustos 2026'da
  // KALDIRILDI. Gerekçesi "firebase_messaging kalıcı reddi bildirmiyor"du;
  // ölçünce YANLIŞ çıktı — eklentinin `AuthorizationStatus` enum'unda
  // `deniedPermanently` var ve dokümanı tam da bunu diyor. Yetkili kaynak
  // varken yerel bir sayaç tutmak ikinci bir doğruluk kaynağı yaratırdı;
  // ikisi ayrışınca hangisinin doğru olduğu bilinemezdi.
}
