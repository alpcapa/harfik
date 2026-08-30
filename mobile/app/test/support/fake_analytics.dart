// Testlerin ortak sahte Analytics ucu.
//
// ⚠ `analytics` GLOBAL bir tek örnek (gerekçe: data/analytics.dart) — sahteyi
// takan her test tearDown'da `analytics.reset()` çağırmak ZORUNDA, yoksa
// logger bir sonraki teste sızar ve o testin olay saymadığı hâlde saydığı
// görülür (errorReporter'ın testlerdeki aynı disiplini).
import 'package:kelimeki/src/data/analytics.dart';

class FakeAnalytics implements AnalyticsLogger {
  final List<(String, Map<String, Object>?)> events = [];

  @override
  Future<void> log(String name, Map<String, Object>? params) async {
    events.add((name, params));
  }

  List<String> get names => [for (final (n, _) in events) n];
}
