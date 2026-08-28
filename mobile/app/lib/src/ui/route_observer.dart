// Setup'ın "bir ekrandan DÖNÜLDÜ" kancası — tek örnek, `MaterialApp`e bağlı.
//
// **NEDEN CALLBACK DEĞİL (28 Ağustos 2026, ROADMAP madde 1 + 13):** Canlı
// tahtayı açan tek kapı `LiveGamesTab._openGame` iken dönüşte "Arkadaşınla"
// rozetini tazeleyen şey bir callback'ti (`onGameClosed`). Sürüm B İKİNCİ bir
// kapı ekliyor: bildirime dokununca doğru oyunu aç. O kapı callback'i çağırmayı
// unutursa 28 Ağustos'ta düzeltilen hata yeni kapıdan aynen geri gelir —
// derleyici bunu yakalamaz, çünkü unutulan şey bir çağrı, eksik bir tip değil.
//
// Kök sebep bir web↔port YAPI farkıydı ve çare de oradan çıkıyor: web'de oyuna
// girince Setup **unmount** olur, dönüşte remount olup rozet effect'ini baştan
// koşturur — yani web bu garantiyi mimarisinden BEDAVA alır. Flutter'da Setup
// `MaterialApp.home` ve oyun üstüne `push` edilir, Setup hiç unmount olmaz.
// `RouteAware.didPopNext` tam olarak web'in bedavaya aldığı sinyali elle verir:
// "üstündeki rota kapandı, yeniden görünürsün".
//
// **Kapsam bilinçli olarak GENİŞ.** Tip `PageRoute` olduğundan yalnızca tam
// ekran rotalar raporlanır; `showDialog`/`showModalBottomSheet` birer
// `PopupRoute` olduğu için modal açıp kapamak bunu TETİKLEMEZ (ölçülebilir bir
// ayrım, tesadüf değil). Buna karşılık YEREL (YZ) oyundan dönüş de tetikler —
// önceki callback'te tetiklemiyordu. Bu bir yan etki değil, istenen davranış:
// yirmi dakika YZ'ye karşı oynarken rozet pekâlâ bayatlamış olabilir ve
// tazeleme 300 ms debounce'lu tek bir sorgu.
import 'package:flutter/widgets.dart';

/// Tüm uygulama için TEK örnek — `MaterialApp.navigatorObservers` ve
/// `SetupScreen` aynı nesneyi paylaşmak ZORUNDA (ayrı örnekler sessizce
/// hiçbir şey yapmaz: abone olunan observer ile rotayı gözleyen observer
/// farklı olur).
final RouteObserver<PageRoute<dynamic>> kRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
