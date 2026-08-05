// Sözlük yükleyici — words_tr.txt asset'ini okuyup SetWordSource kurar.
//
// Web'deki wordSetLoader deseninin eşleniği: uygulama açılışında
// fire-and-forget başlatılır, oyun başlatma/YZ akışları hazır olmasını
// bekler (AppServices.dictionary Future'ı). Satır ayrıştırma + liste
// kurulumu ana isolate'i bloklamasın diye Isolate.run'da yapılır
// (Isolate.exit sonucu kopyasız devreder); rootBundle platform kanalı
// gerektirdiğinden okuma ana isolate'te kalır.
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:kelimeki_core/kelimeki_core.dart';

const String dictionaryAssetPath = 'assets/dictionary/words_tr.txt';

Future<SetWordSource> loadDictionary(AssetBundle bundle) async {
  final raw = await bundle.loadString(dictionaryAssetPath);
  final words = await Isolate.run(
    () => const LineSplitter()
        .convert(raw)
        .where((w) => w.isNotEmpty)
        .toList(growable: false),
  );
  // SIRA KORUNUR: satır sırası = WORD_LIST sırası = YZ determinizmi sözleşmesi.
  return SetWordSource(words);
}
