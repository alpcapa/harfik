// Kök widget — sürüm kapısına göre ya güncelleme ekranı ya uygulama.
import 'package:flutter/material.dart';

import '../bootstrap.dart';
import '../config/version_gate.dart';
import '../data/error_reporter.dart';
import '../storage/app_storage.dart';
import 'auth/reset_password_modal.dart';
import 'intro/intro_screen.dart';
import 'setup/setup_screen.dart';
import 'theme.dart';
import 'tokens.dart';
import 'update_required_screen.dart';

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
      navigatorObservers: [ErrorReporterRouteObserver()],
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
      builder: (context, child) => ListenableBuilder(
        listenable: services.auth,
        builder: (context, _) {
          final app = child ?? const SizedBox.shrink();
          if (!services.auth.passwordRecovery) return app;
          return Stack(
            children: [
              app,
              const ModalBarrier(color: Colors.white, dismissible: false),
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
      home: services.versionGate == VersionGateStatus.updateRequired
          ? const UpdateRequiredScreen()
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

class _HomeGateState extends State<_HomeGate> {
  /// null = karar henüz verilmedi (depo açılıyor).
  bool? _showIntro;
  AppStorage? _storage;

  @override
  void initState() {
    super.initState();
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
