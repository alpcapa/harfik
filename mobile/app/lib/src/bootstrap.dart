// Uygulama açılış kablolaması — main() ile UI arasındaki tek köprü.
//
// Widget testleri KelimekiApp'i sahte bir AppServices ile pump edebilsin
// diye tüm dış dünya (Supabase, asset, sürüm kapısı) burada toplanır.
import 'package:flutter/services.dart' show AssetBundle;
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/version_gate.dart';
import 'data/dictionary_loader.dart';
import 'data/meaning_store.dart';
import 'data/supabase_client.dart';
import 'storage/app_storage.dart';

class AppServices {
  /// Sözlük — açılışta fire-and-forget başlar, oyun başlatma bekler
  /// (web'deki preloadWordSet/isWordSetReady deseni).
  final Future<SetWordSource> dictionary;

  /// Kelime anlamları — asset'teki SQLite'ı İLK SORGUDA açar (açılışta
  /// hiçbir maliyeti yok), bu yüzden Future değil doğrudan nesne.
  final MeaningStore meanings;

  /// null = Supabase yapılandırılmamış → tam offline mod.
  final SupabaseClient? supabase;

  final VersionGateStatus versionGate;

  /// Depolama — açılışta fire-and-forget açılır (sözlükle aynı desen);
  /// widget testleri null geçebilir (yalnızca durum satırı gizlenir).
  final Future<AppStorage>? storage;

  const AppServices({
    required this.dictionary,
    required this.meanings,
    required this.supabase,
    required this.versionGate,
    this.storage,
  });
}

Future<AppServices> bootstrap(AssetBundle bundle) async {
  // Sözlük ve depolama ilk kareyi BEKLETMEZ — Future olarak taşınır.
  final dictionary = loadDictionary(bundle);
  final meanings = MeaningStore(bundle: bundle);
  final storage = AppStorage.open();
  final supabase = await initSupabase();
  final versionGate = await checkVersionGate(supabase);
  return AppServices(
    dictionary: dictionary,
    meanings: meanings,
    supabase: supabase,
    versionGate: versionGate,
    storage: storage,
  );
}
