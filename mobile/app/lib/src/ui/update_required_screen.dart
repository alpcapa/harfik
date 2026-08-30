// Zorunlu güncelleme ekranı — sürüm kapısı updateRequired dediğinde
// uygulamanın TAMAMININ yerine geçer (geri dönüş yolu yok; eşik yalnızca
// sunucu sözleşmesi kırıldığında ya da eski sürümde ciddi bir hata
// bulunduğunda yükseltilir, bkz. version_gate.dart).
//
// ⚠ **BU EKRAN ARTIK NADİR OLMALI (30 Ağustos 2026).** Günlük "yeni sürüm
// var" işi Play In-App Update'e geçti (`data/store_update.dart`): uygulama
// açılışta Play'e soruyor ve gerekiyorsa güncellemeyi kendi içinde
// yaptırıyor, kimsenin `app_config`'te bir satır yükseltmesi gerekmiyor.
// Buradaki kapı yalnızca ACİL FREN — eski istemciyi bir sunucu değişikliği
// kırdığında. Yine de butonu Immediate akışına bağlıyoruz: kapı fırladıysa
// güncellemek EN ÇOK burada gerekiyor, kullanıcıyı mağazaya yollamak yerine
// akışı yerinde çalıştırmak bir dokunuş kazandırıyor.
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

import '../data/store_update.dart';

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
  /// Play In-App Update dikişi. null ise buton eski davranışını sürdürür
  /// (mağazayı dışarıda açar) — testler ve Android dışı yüzeyler için.
  final StoreUpdateGateway? storeUpdate;

  const UpdateRequiredScreen({super.key, this.storeUpdate});

  /// Önce uygulama İÇİNDEKİ akışı dener; Play "güncelleme yok" derse ya da
  /// akış başlatılamazsa mağazayı dışarıda açar.
  ///
  /// **Yedek yolu SİLME:** bu ekranı gören kitle tanım gereği ESKİ sürümde
  /// ve Play'in In-App Update'i yan yüklenmiş pakette hiç çalışmıyor
  /// (bkz. `store_update.dart` → sınırlar). Yedek yol olmadan o kullanıcı
  /// yine çıkışsız kalırdı — bu ekranın 1.0.0'da yaptığı hatanın aynısı.
  Future<void> _guncelle() async {
    final gw = storeUpdate;
    if (gw != null &&
        await gw.kontrolEt() == StoreUpdateDurumu.hemenGuncellenebilir &&
        await gw.hemenGuncelle()) {
      return;
    }
    await _magazayiAc();
  }

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
                onPressed: _guncelle,
                child: const Text('PLAY STORE\'DA AÇ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
