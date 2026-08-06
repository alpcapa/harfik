// flutter_test varsayılan fontu (Ahem) metinleri blok çizer — ekran
// görüntüsü üreten testler Flutter SDK'nın kendi Roboto'sunu yükler.
// Bulunamazsa sessizce atlanır (görüntü bloklu olur, test yine geçer).
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadRobotoIfAvailable() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final f = File('${dir.path}/$name');
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}
