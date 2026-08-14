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

  test('üç metin de web ile birebir aynı', () {
    final source = web.readAsStringSync();
    // Ayrıştırıcının kendi sessiz başarısızlığına karşı: üçü de okunabilmeli.
    final title = _readConst(source, 'OFFLINE_LIVE_TITLE');
    final body = _readConst(source, 'OFFLINE_LIVE_BODY');
    final move = _readConst(source, 'OFFLINE_MOVE_NOTICE');
    expect(title, isNotNull, reason: 'OFFLINE_LIVE_TITLE ayrıştırılamadı');
    expect(body, isNotNull, reason: 'OFFLINE_LIVE_BODY ayrıştırılamadı');
    expect(move, isNotNull, reason: 'OFFLINE_MOVE_NOTICE ayrıştırılamadı');

    expect(kOfflineLiveTitle, title, reason: 'panel BAŞLIĞI ayrışmış');
    expect(kOfflineLiveBody, body, reason: 'panel GÖVDESİ ayrışmış');
    expect(kOfflineMoveNotice, move, reason: 'mesaj satırı metni ayrışmış');
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
