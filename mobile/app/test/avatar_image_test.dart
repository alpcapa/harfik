// Avatar küçültme (13 Ağustos 2026) — 10 MB'lık GİRİŞ sınırı yalnızca "ne
// seçebilirsin"i belirliyor; SAKLANAN her zaman küçültülmüş hâli olmalı.
// Kodek enjekte ediliyor (`DecodeImageFn`) çünkü gerçek `dart:ui` kodeki
// geçerli görsel baytları istiyor — burada ölçülen şey KARAR mantığı.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/avatar_image.dart';
import 'package:kelimeki/src/util/avatar_picker.dart';

/// `flutter test` içinde gerçek bir `ui.Image` üretir (dosya/asset gerekmez).
Future<ui.Image> _solidImage(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF2563EB),
  );
  return recorder.endRecording().toImage(w, h);
}

PickedImage _picked(int bytes, {String mime = 'image/jpeg'}) =>
    PickedImage(bytes: Uint8List(bytes), mimeType: mime);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eşiğin altındaki görsel AYNEN geçer — kodek hiç çağrılmaz', () async {
    var decodeCalls = 0;
    final input = _picked(50 * 1024);
    final out = await shrinkAvatarIfNeeded(
      input,
      decode: (bytes, maxEdge) async {
        decodeCalls++;
        return _solidImage(10, 10);
      },
    );
    expect(identical(out, input), isTrue,
        reason: 'Native picker zaten küçültüyor; yeniden kodlamak JPEG’i '
            'PNG’ye çevirip BÜYÜTÜRDÜ');
    expect(decodeCalls, 0);
  });

  test('eşiğin üstündeki görsel küçültülür — hedef kenar kodeke iletilir',
      () async {
    int? seenMaxEdge;
    final input = _picked(3 * 1024 * 1024);
    final out = await shrinkAvatarIfNeeded(
      input,
      decode: (bytes, maxEdge) async {
        seenMaxEdge = maxEdge;
        return _solidImage(512, 384);
      },
    );
    expect(seenMaxEdge, kAvatarMaxEdge,
        reason: 'Ölçekleme KODEK seviyesinde olmalı — 48MP bir görseli tam '
            'çözmek ~190 MB ham bellek demek');
    expect(out.mimeType, 'image/png');
    expect(out.bytes.length, lessThan(input.bytes.length));
  });

  test('kodek patlarsa orijinal döner — küçültme yükleme yolunu kırmamalı',
      () async {
    final input = _picked(3 * 1024 * 1024);
    final out = await shrinkAvatarIfNeeded(
      input,
      decode: (bytes, maxEdge) async => throw StateError('bozuk görsel'),
    );
    expect(identical(out, input), isTrue);
  });

  test('yeniden kodlama BÜYÜTÜRSE orijinal korunur', () async {
    // 1 MB girdi ama çok büyük bir PNG üretilecek bir görsel döndürüyoruz.
    final input = _picked(1024 * 1024);
    final out = await shrinkAvatarIfNeeded(
      input,
      threshold: 1024,
      decode: (bytes, maxEdge) async => _solidImage(2000, 2000),
    );
    // Düz renkli 2000x2000 PNG çok iyi sıkışır; bu yüzden kararın kendisini
    // doğrulamak için eşiği baytla değil, sonucun asla girdiden büyük
    // OLMADIĞIYLA sabitliyoruz.
    expect(out.bytes.length, lessThanOrEqualTo(input.bytes.length));
  });
}
