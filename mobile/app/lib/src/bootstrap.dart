// Uygulama açılış kablolaması — main() ile UI arasındaki tek köprü.
//
// Widget testleri KelimekiApp'i sahte bir AppServices ile pump edebilsin
// diye tüm dış dünya (Supabase, asset, sürüm kapısı) burada toplanır.
import 'package:flutter/services.dart' show AssetBundle;
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/version_gate.dart';
import 'data/dictionary_loader.dart';
import 'data/supabase_client.dart';

class AppServices {
  /// Sözlük — açılışta fire-and-forget başlar, oyun başlatma bekler
  /// (web'deki preloadWordSet/isWordSetReady deseni).
  final Future<SetWordSource> dictionary;

  /// null = Supabase yapılandırılmamış → tam offline mod.
  final SupabaseClient? supabase;

  final VersionGateStatus versionGate;

  const AppServices({
    required this.dictionary,
    required this.supabase,
    required this.versionGate,
  });
}

Future<AppServices> bootstrap(AssetBundle bundle) async {
  // Sözlük yüklemesi ilk kareyi BEKLETMEZ — Future olarak taşınır.
  final dictionary = loadDictionary(bundle);
  final supabase = await initSupabase();
  final versionGate = await checkVersionGate(supabase);
  return AppServices(
    dictionary: dictionary,
    supabase: supabase,
    versionGate: versionGate,
  );
}
