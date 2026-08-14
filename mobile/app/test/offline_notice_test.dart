// Çevrimdışı uyarı metinleri web ile AYNI mı?
//
// `color_tokens_test`/`rank_tiers_parity_test`'in aynı deseni: web dosyasını
// OKUYUP karşılaştırır. Bu metinler iki platformda birebir aynı olmak
// zorunda (kullanıcı isteği, 14 Ağustos 2026: "hem web hem de app için") ve
// hiçbir derleyici bunu yakalamaz — biri değişip öteki kalırsa test düşer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/offline_notice.dart';

/// `export const NAME = 'tek tırnaklı' + 'bitişik parçalar';` biçimini okur.
String? _readConst(String source, String name) {
  final start = source.indexOf('export const $name =');
  if (start < 0) return null;
  final end = source.indexOf(';', start);
  if (end < 0) return null;
  final body = source.substring(start, end);
  final parts = RegExp(r"'((?:[^'\\]|\\.)*)'").allMatches(body);
  if (parts.isEmpty) return null;
  return parts.map((m) => m.group(1)!.replaceAll(r"\'", "'")).join();
}

void main() {
  final web = File('../../src/utils/offlineNotice.ts');

  test('web dosyası bulunabiliyor (yol değişirse test sessizce geçmesin)', () {
    expect(web.existsSync(), isTrue,
        reason: 'src/utils/offlineNotice.ts bulunamadı — yol mu değişti?');
  });

  test('metinlerin HEPSİ web ile birebir aynı', () {
    final source = web.readAsStringSync();
    // Ad → portun karşılığı. Yeni bir metin eklenirse buraya da eklenmeli;
    // ayrıştırıcının kendi sessiz başarısızlığına karşı hepsi isNotNull.
    final pairs = <String, String>{
      'OFFLINE_LIVE_TITLE': kOfflineLiveTitle,
      'OFFLINE_LIVE_BODY': kOfflineLiveBody,
      'OFFLINE_MOVE_NOTICE': kOfflineMoveNotice,
      'OFFLINE_BACK_LABEL': kOfflineBackLabel,
      'OFFLINE_NO_CONNECTION': kOfflineNoConnection,
      'OFFLINE_AI_SUGGESTION': kOfflineAiSuggestion,
      'OFFLINE_AI_CTA': kOfflineAiCta,
    };
    for (final e in pairs.entries) {
      final web = _readConst(source, e.key);
      expect(web, isNotNull, reason: '${e.key} ayrıştırılamadı');
      expect(e.value, web, reason: '${e.key} ayrışmış');
    }
  });

  group('isNetworkError', () {
    test('ağ katmanı hatalarını tanır', () {
      // Native + tarayıcı + Safari'nin kendi metni.
      for (final e in [
        'SocketException: Failed host lookup: "xyz.supabase.co"',
        'ClientException: Failed to fetch, uri=https://xyz.supabase.co',
        'TypeError: Load failed',
        'Connection refused',
        'TimeoutException after 0:00:20.000000',
      ]) {
        expect(isNetworkError(Exception(e)), isTrue, reason: e);
      }
    });

    test('sunucunun KENDİ reddi ham hâliyle geçmeli', () {
      // Bunlar `submit_move`'un iş kuralı hataları — "bağlantı yok" diye
      // maskelenirlerse kullanıcı yanlış bilgilendirilir.
      for (final e in [
        'Sıra sende değil.',
        'Yalnızca arkadaşlarını davet edebilirsin.',
        'Bu oyunun tarafı değilsin.',
      ]) {
        expect(isNetworkError(Exception(e)), isFalse, reason: e);
      }
    });
  });
}
