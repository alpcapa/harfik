// Sözlük yükleyici — words_tr.txt asset'ini okuyup SetWordSource kurar.
//
// Web'deki wordSetLoader deseninin eşleniği: uygulama açılışında
// fire-and-forget başlatılır, oyun başlatma/YZ akışları hazır olmasını
// bekler (AppServices.dictionary Future'ı). Satır ayrıştırma + liste
// kurulumu ana isolate'i bloklamasın diye Isolate.run'da yapılır
// (Isolate.exit sonucu kopyasız devreder); rootBundle platform kanalı
// gerektirdiğinden okuma ana isolate'te kalır.
//
// WEB İSTİSNASI: web'de isolate YOK — `dart:isolate` derleniyor ama
// `Isolate.run` çalışma anında "Unsupported operation: new RawReceivePort"
// fırlatıyor, yani sözlük hiç yüklenemiyor. Web'de ayrıştırma ana thread'de
// yapılıyor (~64k satır, tek seferlik, kabul edilebilir bir donma).
// Mobil kod yolu BİREBİR AYNI kaldı — `kIsWeb` derleme zamanı sabiti
// olduğundan mobil derlemede bu dal tamamen eleniyor.
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show AssetBundle;
import 'package:kelimeki_core/kelimeki_core.dart';

const String dictionaryAssetPath = 'assets/dictionary/words_tr.txt';

List<String> _parse(String raw) => const LineSplitter()
    .convert(raw)
    .where((w) => w.isNotEmpty)
    .toList(growable: false);

Future<SetWordSource> loadDictionary(AssetBundle bundle) async {
  final raw = await bundle.loadString(dictionaryAssetPath);
  final words = kIsWeb ? _parse(raw) : await Isolate.run(() => _parse(raw));
  // SIRA KORUNUR: satır sırası = WORD_LIST sırası = YZ determinizmi sözleşmesi.
  return SetWordSource(words);
}
