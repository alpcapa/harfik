// Kök widget — sürüm kapısına göre ya güncelleme ekranı ya uygulama.
import 'package:flutter/material.dart';

import '../bootstrap.dart';
import '../config/version_gate.dart';
import 'auth/reset_password_modal.dart';
import 'setup/setup_screen.dart';
import 'theme.dart';
import 'update_required_screen.dart';

class KelimekiApp extends StatelessWidget {
  final AppServices services;
  const KelimekiApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimeki',
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
          : SetupScreen(services: services),
    );
  }
}
