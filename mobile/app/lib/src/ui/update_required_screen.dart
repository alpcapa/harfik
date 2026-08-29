// Zorunlu güncelleme ekranı — sürüm kapısı updateRequired dediğinde
// uygulamanın TAMAMININ yerine geçer (geri dönüş yolu yok; eşik yalnızca
// sunucu sözleşmesi kırıldığında ya da eski sürümde ciddi bir hata
// bulunduğunda yükseltilir, bkz. version_gate.dart).
//
// ⚠ **MAĞAZA BUTONU EKLENDİ (29 Ağustos 2026).** Bu dosyanın başlığı uzun
// süre "Mağaza linkleri uygulama yayınlanınca eklenecek" diyordu ve ekran
// yalnızca metinden ibaretti — yani eşiği yükselttiğimiz an kullanıcı
// ÇIKIŞSIZ bir ekranda kalıyordu: "güncelleyin" diyoruz ama güncellemenin
// yolunu göstermiyoruz. Zorunlu güncellemeyi ilk kez gerçekten kullanmaya
// hazırlanırken fark edildi; kapıyı açmadan önce çıkışı yapmak gerekiyordu.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play mağaza sayfası. `market://` yüklü Play uygulamasını DOĞRUDAN açar
/// (tarayıcı sekmesi olmadan); yoksa https'e düşülür — emülatörde ve Play'in
/// bulunmadığı cihazlarda tek çalışan yol o.
const String _kPaket = 'com.kelimeki.kelimeki';
final Uri _kMarket = Uri.parse('market://details?id=$_kPaket');
final Uri _kWeb =
    Uri.parse('https://play.google.com/store/apps/details?id=$_kPaket');

Future<void> _magazayiAc() async {
  try {
    if (await launchUrl(_kMarket, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Play yüklü değil ya da şema tanınmıyor — https yedeği aşağıda.
  }
  try {
    await launchUrl(_kWeb, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[Kelimeki] mağaza açılamadı: $e');
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update, size: 56),
              const SizedBox(height: 16),
              Text(
                'Güncelleme Gerekli',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kelimeki\'nin bu sürümü artık desteklenmiyor. '
                'Devam etmek için lütfen uygulamayı güncelleyin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('update-store-button'),
                onPressed: _magazayiAc,
                child: const Text('PLAY STORE\'DA AÇ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
