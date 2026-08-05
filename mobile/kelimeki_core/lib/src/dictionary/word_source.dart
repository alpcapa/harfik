// Kelimeki core — sözlük arayüzü. Verinin kendisi ve yüklenmesi core'un
// DIŞINDA (uygulama katmanı asset'ten yükler); motor yalnızca bu arayüzü görür.
import 'dart:collection';

import '../text/turkish.dart';

abstract interface class WordSource {
  /// Kelime sözlükte var mı? Çağıran ham (büyük/küçük karışık) verebilir;
  /// implementasyon trLower uygular.
  bool contains(String word);

  /// YZ'nin kelime havuzu için tüm kelimeler — EKLEME SIRASI KORUNMALI
  /// (TS'teki WORD_SET iterasyonu = WORD_LIST sırası; YZ'nin deterministik
  /// eş-hamle seçimi buna bağlı, bkz. mobile/CLAUDE.md).
  Iterable<String> get pool;
}

/// Düz HashSet tabanlı sözlük — mevcut YZ algoritması prefix araması
/// gerektirmediğinden bilinçli olarak en basit yapı (karar: mobile/CLAUDE.md).
class SetWordSource implements WordSource {
  final LinkedHashSet<String> _words;

  /// [words] önceden trLower'lanmış, sıralı kelime listesi (asset satırları).
  SetWordSource(Iterable<String> words)
      : _words = LinkedHashSet<String>.from(words);

  @override
  bool contains(String word) => _words.contains(trLower(word));

  @override
  Iterable<String> get pool => _words;

  int get length => _words.length;
}
