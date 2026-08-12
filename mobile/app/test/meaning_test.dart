// Kelime anlamı — üretilmiş SQLite asset'i (GERÇEK dosya), MeaningStore'un
// kopyala-ve-aç akışı ve MeaningModal'ın render dalları.
//
// Kaynak doğruluğu ayrıca src/data/meanings.json ile karşılaştırılır: asset
// üreticisi (scripts/generate-meanings-db.mjs) sessizce bozulursa test
// düşer.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/meaning_entry.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/ui/game/meaning_modal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// Asset'leri paketten değil doğrudan diskten okuyan test bundle'ı —
/// flutter_test'in rootBundle'ı `assets/` yolunu bilmez.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw FlutterError('yok: $key');
    return ByteData.sublistView(f.readAsBytesSync());
  }
}

late Directory tmp;

/// Widget testleri için GERÇEK asset'ten önceden okunmuş kayıtlar: sqflite'ın
/// gerçek async'i testWidgets'ın sahte zaman bölgesinde ÇÖZÜLMEZ (initState'te
/// başlayan Future o bölgeye bağlanır, runAsync'te beklemek işe yaramaz).
/// Bu yüzden veri burada — fake zone DIŞINDA — okunur, modala doğrudan
/// beslenir; deponun kendi doğruluğu ayrı `test()` vakalarında sınanıyor.
final _prefetched = <String, MeaningEntry?>{};

Future<MeaningEntry?> fakeLookup(String word) async => _prefetched[word];

MeaningStore newStore() => MeaningStore(
      bundle: _DiskBundle(),
      factory: databaseFactoryFfi,
      dbDir: () async => tmp.path,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    await loadAppFonts();
    tmp = Directory.systemTemp.createTempSync('kelimeki_meanings_test');
    final store = newStore();
    for (final w in ['KELİME', 'ABA', 'ZZZZZZ']) {
      _prefetched[w] = await store.lookup(w);
    }
    await store.close();
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('asset kaynakla tutarlı: örnek kelimeler + toplam sayı', () async {
    final store = newStore();
    // Kaynak JSON web tarafında; asset ondan üretiliyor.
    final raw =
        jsonDecode(File('../../src/data/meanings.json').readAsStringSync())
            as Map;
    for (final word in ['aba', 'kelime', 'yıldız', 'ırmak', 'işlem']) {
      final entry = await store.lookup(word);
      final src = raw[word] as Map;
      expect(entry, isNotNull, reason: '$word asset\'te yok');
      expect(entry!.meanings, (src['meanings'] as List).cast<String>(),
          reason: '$word anlamları kaynakla eşleşmiyor');
      expect(entry.pos, src['pos']);
    }
    // Türkçe normalizasyon: BÜYÜK harfli sorgu da aynı kaydı bulmalı
    // (tahtadaki harfler büyük yazılır — trLower sözleşmesi).
    final upper = await store.lookup('İŞLEM');
    expect(upper?.meanings.first, (raw['işlem']['meanings'] as List).first);

    expect(await store.lookup('zzzzzz'), isNull); // sözlükte olmayan
    await store.close();
  });

  test('kopya bir kez yapılır, damga değişince yenilenir', () async {
    final dbFile = File('${tmp.path}/meanings.db');
    final stampFile = File('${tmp.path}/meanings.db.sha256');
    expect(dbFile.existsSync(), isTrue); // önceki test kopyaladı
    final stamp = stampFile.readAsStringSync();

    // Damga bozulursa (yeni sürümde sözlük değişti) kopya yenilenir.
    stampFile.writeAsStringSync('eski-surum');
    final store = newStore();
    expect((await store.lookup('aba'))?.meanings, isNotEmpty);
    expect(stampFile.readAsStringSync(), stamp);
    await store.close();
  });

  testWidgets('modal: anlam listesi + iki kelime + bulunamadı hâli',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: key,
        child: MeaningModal(lookup: fakeLookup, words: const ['KELİME', 'ABA']),
      ),
    ));
    await tester.pump(); // initState'teki lookup'lar (mikrotask) çözülür

    expect(find.text('KELİME'), findsOneWidget); // KModal başlığı
    expect(find.text('ABA'), findsOneWidget); // ikinci kelimenin alt başlığı
    expect(
        find.textContaining('Bir veya birkaç heceden oluşan'), findsOneWidget);
    expect(find.textContaining('Yünün dövülmesiyle'), findsOneWidget);
    expect(find.text('Anlam yükleniyor…'), findsNothing);
    // Fontların kapsamadığı tek karakter (►) ekrana ULAŞMAMALI — ölçüm ve
    // gerekçe meaning_modal.dart'ta.
    expect(find.textContaining('►'), findsNothing);
    expect(find.textContaining('→ kepenek'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/meaning_modal.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('sözlükte olmayan kelime: "bulunamadı"', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'SpaceGrotesk'),
      home: MeaningModal(lookup: fakeLookup, words: const ['ZZZZZZ']),
    ));
    await tester.pump();
    expect(find.text('Bu kelimenin anlamı bulunamadı.'), findsOneWidget);
  });
}
