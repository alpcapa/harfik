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
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../util/offline_notice.dart';
import '../util/platform.dart';

/// Sunucudaki kırpma ile aynı tavan — ağa gereksiz bayt göndermemek için.
const int _maxMessage = 500;
const int _maxStack = 4000;

/// Çökme döngüsü koruması: son [_windowMs] içinde en fazla [_maxPerWindow]
/// kayıt, ve aynı imza pencere başına BİR kez.
///
/// ⚠ PENCERE, SÜREÇ ÖMRÜ DEĞİL (31 Ağustos 2026, ROADMAP #10). Önceki hâl
/// "oturum başına 10"du ve sayaç/imza kümesi hiç temizlenmiyordu. Webde bir
/// sayfa yenilemesi ikisini de sıfırladığı için orada bedeli yoktu;
/// **app süreci ise günlerce yaşıyor** — 10 FARKLI hatadan sonra cihaz
/// kalıcı olarak susuyor ve tekrar eden bir hata süreç başına yalnızca BİR
/// kez sayılıyordu. Yani bu maddenin asıl adresi TAM OLARAK portun kendisi.
///
/// Sayılar web `errorReporting.ts` ile AYNI olmak zorunda —
/// `error_rate_limit_parity_test` ikisini de kaynaktan okuyup karşılaştırıyor.
const int _maxPerWindow = 10;
const int _windowMs = 60 * 60 * 1000;

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

/// Kök rotanın adı. Web'de `location.pathname` karşılığı yok; kök ekran
/// (Setup / tanıtım / güncelleme kapısı) hepsi burada toplanıyor.
const String kRootRouteName = 'app';

/// Hangi ekranda olduğumuzu telemetriye taşıyan gözlemci — `MaterialApp`'in
/// `navigatorObservers`ına takılır.
///
/// NEDEN VAR (23 Ağustos 2026): kayıtların `route` alanı portta SABİT `'app'`
/// yazıyordu. Web'de o alan '/'/'/game/:id'/'/davet/:token' diye ayrışıyor ve
/// panelde "hangi ekranda?" sorusunu cevaplıyor; mağaza sonrası app trafiği
/// baskın hâle gelince kolon tamamen ölürdü. Yığın izi ekranı çoğu zaman
/// söylüyor ama HER ZAMAN değil (release'de sembolleri çözülmüş bir yığın
/// yok) — ve gruplanmış panelde yığın yalnızca ÖRNEK olarak duruyor.
///
/// Rota adları push yerlerinde `RouteSettings(name: …)` ile veriliyor; ad
/// verilmemiş bir rota kök sayılır. Yani yeni bir ekran eklenip adı
/// unutulursa kayıt YANLIŞ olmaz, yalnızca ayrıntısını kaybeder.
class ErrorReporterRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    errorReporter.route = _routeAdi(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    errorReporter.route = _routeAdi(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    errorReporter.route = _routeAdi(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Yığının ORTASINDAN bir rota kaldırılırsa bu, üstteki rotayı değiştirmez
    // ve buradaki güncelleme kısa süreliğine yanlış olur. Uygulamada
    // `removeRoute` HİÇ kullanılmıyor (yalnız push/pop var, ölçüldü); yine de
    // override ediliyor ki ileride kullanılırsa alan bayat kalmasın.
    errorReporter.route = _routeAdi(previousRoute);
  }
}

String _routeAdi(Route<dynamic>? route) {
  final ad = route?.settings.name;
  // MaterialApp'in `home:`i '/' adını taşır — kök ekran, yani 'app'.
  if (ad == null || ad.isEmpty || ad == '/') return kRootRouteName;
  return ad;
}

class ErrorReporter {
  /// Şu an görünen ekran — `ErrorReporterRouteObserver` günceller.
  String route = kRootRouteName;

  ClientErrorSink? _sink;
  Future<String>? _anonId;

  /// Pencere içinde gönderilmiş kayıtların zaman damgaları (ms).
  final List<int> _gonderimZamanlari = <int>[];

  /// İmza → o imzanın en son gönderildiği an (ms).
  final Map<String, int> _imzaZamanlari = <String, int>{};

  bool _raporlaniyor = false;

  /// Saat — testler dışında her zaman `DateTime.now` (portun `GamesRepo`'daki
  /// `DateTime Function()? now` deseninin aynısı).
  DateTime Function() _now = DateTime.now;

  /// Pencerenin dışına düşen kayıtları/imzaları unutur.
  ///
  /// ⚠ GELECEKTEKİ damga da düşer (`t > simdi`). Kaynak duvar saati; cihazın
  /// saati geriye alınabilir (elle ayar, NTP düzeltmesi) ve o durumda
  /// `simdi - t` negatif olur, yani girdi normalde HİÇ eskimezdi — düzeltmenin
  /// bedeli tam da bu maddenin kapatmaya çalıştığı körlük olurdu.
  void _pencereyiKaydir(int simdi) {
    bool gecerli(int t) => t <= simdi && simdi - t < _windowMs;
    _gonderimZamanlari.removeWhere((t) => !gecerli(t));
    _imzaZamanlari.removeWhere((_, t) => !gecerli(t));
  }

  /// Supabase ve anonim kimlik hazır olunca `bootstrap` çağırır. Bundan
  /// ÖNCE gelen raporlar sessizce düşer — bilinçli: açılışın ilk
  /// milisaniyelerini kuyruklamak için ayrı bir depo açmak, telemetrinin
  /// kendisini bir açılış riski hâline getirirdi.
  void configure({
    required ClientErrorSink? sink,
    required Future<String>? anonId,
    DateTime Function()? now,
  }) {
    _sink = sink;
    _anonId = anonId;
    if (now != null) _now = now;
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
      final simdi = _now().millisecondsSinceEpoch;
      _pencereyiKaydir(simdi);
      if (_gonderimZamanlari.length >= _maxPerWindow) return;

      var mesaj = error.toString();
      if (context != null) mesaj = '[$context] $mesaj';
      if (mesaj.length > _maxMessage) mesaj = mesaj.substring(0, _maxMessage);

      // İmza mesajın BAŞINDAN türetiliyor: aynı hatanın farklı satır
      // numaralarıyla gelen kopyaları tek kayda inmeli.
      final imza = '$kind|${mesaj.length > 120 ? mesaj.substring(0, 120) : mesaj}';
      if (_imzaZamanlari.containsKey(imza)) return;
      _imzaZamanlari[imza] = simdi;
      _gonderimZamanlari.add(simdi);

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
        // 23 Ağustos 2026'ya kadar SABİT 'app'ti; artık gözlemciden geliyor
        // (bkz. `ErrorReporterRouteObserver`).
        'route': route,
        // ÜRÜN SÜRÜMÜ — web'de bu alan null, çünkü orada aynı anda tek bir
        // canlı derleme var ve `build` (sha) onu tekil belirliyor. Mağazada
        // ise aynı anda birden çok sürüm yaşayacağından bu, "hangi sürümde
        // düzeldi?" sorusunun tek cevabı (`telemetry_app_version`).
        'app_version': appVersion,
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
    route = kRootRouteName;
    _sink = null;
    _anonId = null;
    _gonderimZamanlari.clear();
    _imzaZamanlari.clear();
    _raporlaniyor = false;
    _now = DateTime.now;
  }
}
