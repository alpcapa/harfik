// Kök widget — sürüm kapısına göre ya güncelleme ekranı ya uygulama.
import 'dart:async';

import 'package:flutter/material.dart';

import '../bootstrap.dart';
import '../config/version_gate.dart';
import '../data/error_reporter.dart';
import '../data/store_update.dart';
import '../storage/app_storage.dart';
import 'auth/reset_password_modal.dart';
import 'intro/intro_screen.dart';
import 'route_observer.dart';
import 'setup/setup_screen.dart';
import 'theme.dart';
import 'tokens.dart';
import 'push/push_permission_flow.dart';
import 'update_required_screen.dart';
import 'text_scale.dart';
import 'game/logo_mark.dart';
import 'online_scope.dart';

class KelimekiApp extends StatelessWidget {
  final AppServices services;
  const KelimekiApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimeki',
      // Hata telemetrisinin "hangi ekranda?" alanı — rota adları push
      // yerlerinde veriliyor, adsız rota kök sayılır (bkz.
      // `ErrorReporterRouteObserver`).
      // İkincisi Setup'ın "bir ekrandan dönüldü" kancası — gerekçe
      // route_observer.dart'ta (callback yerine neden observer).
      navigatorObservers: [ErrorReporterRouteObserver(), kRouteObserver],
      // Tema TEK yerde (`ui/theme.dart`) — testler de aynı fonksiyonu
      // kullanıyor, yoksa üründe değişen bir tema testlerde eski hâliyle
      // render edilip sapma görünmez kalıyor.
      theme: kelimekiTheme(),
      // Şifre sıfırlama kapısı — web App.tsx'in `if (passwordRecovery)`
      // erken dönüşünün eşleniği. builder Navigator'ı SARDIĞINDAN kapı
      // hangi rota açık olursa olsun (Setup, oyun, açık bir dialog) en
      // önde belirir; alttaki ağaç sökülmez (state korunur), yalnızca
      // web'deki "boş sayfa + ortada modal" görünümünü veren beyaz bir
      // bariyerle örtülür. Kendi Overlay'i şart: bu katman Navigator'ın
      // (dolayısıyla onun Overlay'inin) DIŞINDA yaşar — KModal'daki ✕
      // tooltip'i gibi Overlay isteyen her şey onsuz fırlatırdı.
      // ⚠ SİSTEM FONT ÖLÇEĞİ 1,3 İLE SINIRLI (28 Ağustos 2026, kullanıcı
      // cihazda bildirdi: *"Görmediği için telefon fontlarını büyütenlerde
      // ciddi sorunlar çıkıyor."*). Android/iOS'ta yazı boyutu 200%'e kadar
      // çıkabiliyor ve BU YALNIZCA METNİ büyütüyor — kutular, ikonlar,
      // dolgular sabit kalıyor, yani her satır kendi kabını taşırıyor.
      //
      // ÖLÇÜLDÜ (tüm test takımı, `platformDispatcher.textScaleFactorTestValue`
      // ile yeniden koşturularak): taşma sayısı ölçek 1,0'da **0**, 1,3'te
      // **10** (tek bir gerçek nokta + tekrarları), 1,6'da **27** (4 nokta),
      // 2,0'da **73** (9 nokta, en büyüğü 392 px). Yani hasar 1,3'ten sonra
      // patlıyor.
      //
      // Bedeli BİLİNÇLİ: fontu 200%'e alan kullanıcı uygulamada 130% görür.
      // 1,0'a kilitlemek (yani ölçeği tamamen yok saymak) erişilebilirlik
      // açısından savunulamazdı; 1,3 kullanıcı kararı (28 Ağustos 2026).
      //
      // ⚠ BU BİR TAVAN, ÇÖZÜM DEĞİL. Kısıt yalnızca TAŞMAYI sınırlar;
      // "esnek öğe sıfıra sıkışıyor" sınıfını ÇÖZMEZ — o taşma üretmediği
      // için buradaki hiçbir ölçüme de girmez (bkz. friends_modal.dart'taki
      // istek satırı: 360 px ekranda isim 1,0'da 77,6 px, 1,3'te 53,2 px,
      // 2,0'da 0,0 px). Yeni bir ekran yazarken "nasılsa kısıtlı" deme.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: kMaxTextScale,
        // Bağlantı durumu ağaç genelinde — bugün tek tüketicisi `KAvatar`
        // (çevrimiçine dönünce yüklenememiş görseli yeniden dener), ama
        // kapsam kökte durduğundan yeni tüketiciler parametre gerektirmiyor.
        child: OnlineScope(
          status: services.onlineStatus,
          child: ListenableBuilder(
          listenable: services.auth,
          builder: (context, _) {
            final app = child ?? const SizedBox.shrink();
            if (!services.auth.passwordRecovery) return app;
            return Stack(
              children: [
                app,
                const ModalBarrier(color: Colors.white, dismissible: false),
                // Bariyerin üstünde LOGO — arka plan bomboş DEĞİL (29 Ağustos
                // 2026, kullanıcı cihazda bildirdi: *"Şifre değiştirme
                // modalının arkası boş ekran. En azından kelimeki logosu
                // görünmeli."*). Web'de de böyleydi ve orada da düzeltildi
                // (`App.tsx`, `passwordRecovery` dalı) — bu bir port farkı
                // değildi, iki tarafın ORTAK eksiğiydi.
                //
                // Gerekçe kozmetikten fazlası: bu ekrana kullanıcı bir
                // E-POSTA LİNKİNDEN düşüyor, yani uygulamayı henüz hiç
                // görmemiş olabilir. Beyaz bir sayfada şifre isteyen bir
                // kutu, kimlik avı ekranından ayırt edilemez.
                //
                // Logo modalın ARKASINDA, üst tarafta: `Overlay` bunun
                // üstüne biniyor ve modal zaten dikeyde ortalı olduğundan
                // çakışma yok. Boyut Setup'la AYNI (52).
                const Positioned.fill(
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment(0, -0.62),
                      // ⚠ Anahtar TESTİN İHTİYACI ve LOGONUN KENDİSİNDE
                      // olmalı: (a) arkadaki Setup ekranı da bir `LogoMark`
                      // çiziyor, yani `find.byType(LogoMark)` bu logo hiç
                      // olmasa BİLE eşleşir; (b) anahtar `Positioned.fill`e
                      // konursa ölçülen kutu TÜM EKRAN olur ve konum testi
                      // her zaman ekran merkezini görür. İkisi de ölçüldü,
                      // ikisi de testi sessizce anlamsız kılıyordu.
                      child: LogoMark(
                          key: ValueKey('recovery-logo'), height: 52),
                    ),
                  ),
                ),
                Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => ResetPasswordModal(
                        auth: services.auth,
                        onDone: services.auth.clearPasswordRecovery,
                      ),
                    ),
                  ],
                ),
              ],
            );
            },
          ),
        ),
      ),
      home: services.versionGate == VersionGateStatus.updateRequired
          ? UpdateRequiredScreen(storeUpdate: services.storeUpdate)
          : _HomeGate(services: services),
    );
  }
}

/// İlk açılış kapısı — tanıtım bir kez gösterilir, sonra hep Setup.
///
/// Web'in karşılama katmanı bu kararı `<head>`e gömülü senkron bir script'le
/// veriyor (İLK BOYAMADAN önce, FOUC olmasın diye). Portta o kısıt yok ama
/// bayrak SharedPreferences'ta (asenkron) olduğundan aynı incelik geçerli:
/// karar netleşene kadar HİÇBİR ekran çizilmiyor — önce Setup gösterip
/// üstüne tanıtımı atlamak görünür bir sıçrama olurdu.
///
/// `services.storage == null` iken (widget testleri, depolamasız
/// önizlemeler) kapı hiç devreye girmez ve doğrudan Setup açılır — mevcut
/// testlerin HİÇBİRİ `storage` geçmiyor, yani davranışları birebir aynı
/// kalıyor.
class _HomeGate extends StatefulWidget {
  final AppServices services;
  const _HomeGate({required this.services});

  @override
  State<_HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<_HomeGate> with WidgetsBindingObserver {
  /// null = karar henüz verilmedi (depo açılıyor).
  bool? _showIntro;
  AppStorage? _storage;

  /// Push token'ını izinle hizalayan son oturumun kimliği — oturum
  /// değişimini (giriş/çıkış/hesap değiştirme) burada yakalıyoruz.
  String? _sonPushUserId;

  /// Token durumunu sistem izniyle hizalar.
  ///
  /// **NEDEN BURADA (28 Ağustos 2026, cihaz testinde bulundu):** bu çağrı
  /// eskiden YALNIZCA Canlı sekmesinin `_reload()`'undaydı. Bildirimi sistem
  /// ayarlarından kapatıp o sekmeye girmeyen kullanıcının token'ı tabloda
  /// kalıyordu (cihazda ölçüldü) — sunucu gönderiyor, işletim sistemi
  /// sessizce yutuyordu. Ayar uygulamanın DIŞINDA değiştiği için tek
  /// güvenilir an öne dönüş; kapı bu yüzden `WidgetsBindingObserver`.
  ///
  /// Fırlatmaz ve beklenmez: hizalama bir ekran geçişini geciktirmemeli.
  void _pushHizala() {
    final repo = widget.services.push;
    final messaging = widget.services.pushMessaging;
    if (repo == null || messaging == null) return; // web / Firebase yok
    final userId = widget.services.auth.user?.id;
    if (userId == null) {
      // ÇIKIŞ: satır kalırsa sunucu, o hesabın oturumu kapalı bir cihaza
      // göndermeye devam eder. `temizle` başka hiçbir yerden çağrılmıyordu.
      if (_sonPushUserId != null) {
        _sonPushUserId = null;
        unawaited(repo.temizle());
      }
      return;
    }
    _sonPushUserId = userId;
    unawaited(pushTokenlariHizala(
      messaging: messaging,
      repo: repo,
      userId: userId,
    ));
  }

  /// Bu açılışta "daha yeni sürüm var mı" sorusu bir SONUCA vardı mı.
  /// `false` kalırsa (ağ yoktu, Play cevap vermedi) öne dönüşte tekrar
  /// sorulur — bir kez susup bir daha hiç sormamak, tam da bu özelliğin
  /// çözdüğü hatanın aynısı olurdu.
  bool _guncellemeSorusuKapandi = false;
  bool _guncellemeSorusuSuruyor = false;

  /// Play'e sorar, gerekiyorsa Immediate güncelleme akışını başlatır.
  ///
  /// Kullanıcı isteği (30 Ağustos 2026): *"Kimde hangi versiyon olursa
  /// olsun, app'i açtığında daha yeni bir sürüm varsa uyarsın ve yapsın."*
  /// Gerekçe ve sınırlar: `data/store_update.dart`.
  ///
  /// ⚠ **Beklenmez.** Bir güncelleme kontrolü ekran geçişini geciktiremez;
  /// uç zaten hiçbir koşulda fırlatmıyor.
  void _guncellemeKontrol() {
    final gateway = widget.services.storeUpdate;
    if (gateway == null) return; // widget testleri / depolamasız önizleme
    if (_guncellemeSorusuKapandi || _guncellemeSorusuSuruyor) return;
    _guncellemeSorusuSuruyor = true;
    unawaited(magazaGuncellemesiniCalistir(gateway).then((kapandi) {
      _guncellemeSorusuSuruyor = false;
      _guncellemeSorusuKapandi = kapandi;
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pushHizala();
      _guncellemeKontrol();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.services.auth.removeListener(_pushHizala);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Oturum değişimi (giriş/çıkış/hesap değiştirme) + ilk açılış.
    widget.services.auth.addListener(_pushHizala);
    _pushHizala();
    _guncellemeKontrol();
    final storage = widget.services.storage;
    if (storage == null) {
      _showIntro = false;
      return;
    }
    storage.then((s) {
      if (!mounted) return;
      setState(() {
        _storage = s;
        _showIntro = !s.flags.seenIntro;
      });
    }).catchError((Object e) {
      // Depo açılamazsa tanıtım GÖSTERİLMEZ: bayrak yazılamayacağından her
      // açılışta tekrar çıkardı (bkz. Parça 45 — depo yokluğu sessizce
      // kabul edilir, akış durmaz).
      if (!mounted) return;
      setState(() => _showIntro = false);
    });
  }

  void _finishIntro() {
    // Bayrak yazımı beklenmez (fire-and-forget): ekran geçişi bir yazma
    // gecikmesine takılmamalı. Yazma düşerse en kötü ihtimalle tanıtım bir
    // kez daha çıkar — veri kaybı yok.
    _storage?.flags.markIntroSeen();
    setState(() => _showIntro = false);
  }

  @override
  Widget build(BuildContext context) {
    final show = _showIntro;
    if (show == null) return const ColoredBox(color: kBg);
    if (show) return IntroScreen(onDone: _finishIntro);
    return SetupScreen(services: widget.services);
  }
}
