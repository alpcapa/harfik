// `Analytics`in GERÇEK ucu — firebase_analytics eklentisi.
//
// `analytics.dart`tan AYRI dosya: orası saf ve birim testli, burası
// Firebase'e bağlı (push_repo.dart ↔ push_gateways.dart ayrımının aynısı).
//
// `firebase_analytics ^12.5.0` pubspec'te 28 Ağustos 2026'dan beri
// duruyordu ama `lib/` altında TEK kullanım yeri yoktu (ROADMAP Faz 3
// bunu ölçmüştü) — ilk gerçek kullanıcı bu dosya. Manifest'teki AD_ID
// kaldırması (`tools:node="remove"`) bu eklenti için konmuştu ve aynen
// geçerli: reklam kimliği OLMADAN olay toplamak destekleniyor.
import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics.dart';

class FirebaseAnalyticsLogger implements AnalyticsLogger {
  final FirebaseAnalytics _fa;
  FirebaseAnalyticsLogger([FirebaseAnalytics? fa])
      : _fa = fa ?? FirebaseAnalytics.instance;

  @override
  Future<void> log(String name, Map<String, Object>? params) =>
      _fa.logEvent(name: name, parameters: params);
}
