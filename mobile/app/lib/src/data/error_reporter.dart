// Kelimeki app — istemci hata telemetrisi (ROADMAP #3, 21 Ağustos 2026).
// Web karşılığı: `src/utils/errorReporting.ts` — kurallar BİREBİR aynı,
// yalnızca yakalama noktaları platforma özgü.
//
// NEDEN VAR: portta her çökme `debugPrint`e gidiyordu, yani kullanıcının
// cihazında ölüyordu. Bu projede bedeli ölçülmüş: Parça 45'te "depo
// açılamadı → offline hamleler sessizce kayboldu" teşhisi TAHMİNLE yapılmak
// zorunda kaldı ve görebilmek için Setup'a bir teşhis satırı eklendi.
//
// ÜÇ DEĞİŞMEZ (biri bozulursa telemetri ürünü bozar):
//   1. FIRE-AND-FORGET — asla `await` edilmez, ASLA fırlatmaz.
//   2. TEKRAR BASTIRMA + HIZ SINIRI — bir çökme döngüsü aksi halde binlerce
//      satır yazar.
//   3. DERLEME KİMLİĞİ her kayda eklenir (`buildSha`) — "hangi sürümde?"
//      sorusu bu projede iki kez gerçek zaman yaktı.
//
// NE KAYDEDİLMEZ: çevrimdışılık ve `isNetworkError`'a düşen her şey,
// sunucunun KENDİ reddi. Bunlar BEKLENEN durumlar; gürültü sinyali boğarsa
// panel bir daha açılmaz. (Ayrıntı için web dosyasının başlığı.)
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../util/offline_notice.dart';
import '../util/platform.dart';

/// Sunucudaki kırpma ile aynı tavan — ağa gereksiz bayt göndermemek için.
const int _maxMessage = 500;
const int _maxStack = 4000;

/// Uygulama oturumu başına toplam rapor tavanı (çökme döngüsü koruması).
const int _maxPerSession = 10;

/// Hata türleri — web `ClientErrorKind` ile BİREBİR aynı dizeler; admin
/// panelindeki `errorKindLabel` bunları okuyor. Portta `boundary` karşılığı
/// `FlutterError.onError` (widget ağacındaki hata), `uncaught` ise zone
/// dışına kaçan hata.
class ClientErrorKind {
  static const flutter = 'boundary';
  static const zone = 'uncaught';
  static const manual = 'manual';
}

/// Kaydın gideceği yer. Gerçek uç Supabase; testler bellek içi sahte geçer
/// (portun her yerindeki gateway deseni — karar mantığı ağdan bağımsız
/// sınanabilsin diye).
abstract class ClientErrorSink {
  Future<void> send(Map<String, Object?> record);
}

class SupabaseClientErrorSink implements ClientErrorSink {
  final SupabaseClient client;
  const SupabaseClientErrorSink(this.client);

  @override
  Future<void> send(Map<String, Object?> record) async {
    await client.from('client_errors').insert(record);
  }
}

/// Tek örnek — `main()`/`bootstrap()` ve tüm çağrı yerleri bunu kullanır.
final ErrorReporter errorReporter = ErrorReporter();

class ErrorReporter {
  ClientErrorSink? _sink;
  Future<String>? _anonId;
  final Set<String> _gonderilen = <String>{};
  int _toplam = 0;
  bool _raporlaniyor = false;

  /// Supabase ve anonim kimlik hazır olunca `bootstrap` çağırır. Bundan
  /// ÖNCE gelen raporlar sessizce düşer — bilinçli: açılışın ilk
  /// milisaniyelerini kuyruklamak için ayrı bir depo açmak, telemetrinin
  /// kendisini bir açılış riski hâline getirirdi.
  void configure({required ClientErrorSink? sink, required Future<String>? anonId}) {
    _sink = sink;
    _anonId = anonId;
    // Hiç rapor gelmezse bu future hiç `await` EDİLMEZ; depo açılamayıp
    // reddederse "unhandled async error" olur ve — ironik biçimde — zone
    // yakalayıcısını tetikleyip telemetrinin kendisini bir hata kaynağına
    // çevirirdi. Buradaki dinleyici onu sessizce işaretliyor; gerçek rapor
    // anındaki `await` yine kendi try/catch'ine düşüyor.
    anonId?.catchError((Object _) => '');
  }

  /// Bir hatayı anonim olarak bildirir. Fire-and-forget: dönüşü beklenmez ve
  /// hiçbir koşulda fırlatmaz.
  ///
  /// [context] çağıranın verdiği kısa etiket ("cloud_save_repo" gibi) —
  /// mesajın başına eklenir ki panelde aynı mesaj farklı yerlerden geldiğinde
  /// ayrışsın.
  void report(
    Object error, {
    String kind = ClientErrorKind.manual,
    String? context,
    StackTrace? stack,
  }) {
    try {
      final sink = _sink;
      if (sink == null) return;
      // BEKLENEN durum — bkz. dosya başlığı.
      //
      // ⚠ Filtre YALNIZCA otomatik yakalamalara uygulanır. `manual`
      // çağrılarda sinyal hatanın KENDİSİ değil, ÇAĞIRANIN bildiği
      // bağlamdır: `cloud_save_repo`'nun "KAYIP" noktasında elimizdeki hata
      // çoğu zaman ağ hatasıdır, ama raporlanmaya değer kılan şey AYNANIN DA
      // yazılamamış olmasıdır.
      if (kind != ClientErrorKind.manual && isNetworkError(error)) return;
      if (_raporlaniyor) return;
      if (_toplam >= _maxPerSession) return;

      var mesaj = error.toString();
      if (context != null) mesaj = '[$context] $mesaj';
      if (mesaj.length > _maxMessage) mesaj = mesaj.substring(0, _maxMessage);

      // İmza mesajın BAŞINDAN türetiliyor: aynı hatanın farklı satır
      // numaralarıyla gelen kopyaları tek kayda inmeli.
      final imza = '$kind|${mesaj.length > 120 ? mesaj.substring(0, 120) : mesaj}';
      if (_gonderilen.contains(imza)) return;
      _gonderilen.add(imza);
      _toplam += 1;

      _raporlaniyor = true;
      var yigin = stack?.toString();
      if (yigin != null && yigin.length > _maxStack) {
        yigin = yigin.substring(0, _maxStack);
      }
      _gonder(sink, kind: kind, message: mesaj, stack: yigin);
    } catch (_) {
      _raporlaniyor = false;
    }
  }

  Future<void> _gonder(
    ClientErrorSink sink, {
    required String kind,
    required String message,
    required String? stack,
  }) async {
    try {
      final anon = _anonId == null ? null : await _anonId;
      await sink.send({
        'anon_id': anon,
        'platform': currentPlatform,
        'build': buildSha.isEmpty ? null : buildSha,
        'kind': kind,
        'message': message,
        'stack': stack,
        // Portta web'in `location.pathname`'i yok; ekran adı taşımak yerine
        // sabit bir işaret bırakılıyor — hangi ekranda olduğu zaten yığında.
        'route': 'app',
      });
    } catch (_) {
      // Yutuluyor: telemetri hatası hiçbir yere yazılmıyor, çünkü hata
      // yakalayıcıyı sarmalayan bir yol bunu döngüye çevirirdi.
    } finally {
      _raporlaniyor = false;
    }
  }

  /// Yalnızca testler için — sayaçları ve hedefi sıfırlar.
  void resetForTests() {
    _sink = null;
    _anonId = null;
    _gonderilen.clear();
    _toplam = 0;
    _raporlaniyor = false;
  }
}
