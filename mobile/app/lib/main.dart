import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/bootstrap.dart';
import 'src/ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portre kilidi — web'deki LandscapeHint banner'ının yerini alan kesin
  // çözüm (mobile/CLAUDE.md, "yeniden yazılanlar": native API yalan söylemez).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final services = await bootstrap(rootBundle);
  runApp(KelimekiApp(services: services));
}
