// Zorunlu güncelleme ekranı — sürüm kapısı updateRequired dediğinde
// uygulamanın TAMAMININ yerine geçer (geri dönüş yolu yok; eşik yalnızca
// sunucu sözleşmesi kırıldığında yükseltilir, bkz. version_gate.dart).
// Mağaza linkleri uygulama yayınlanınca eklenecek.
import 'package:flutter/material.dart';

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
            ],
          ),
        ),
      ),
    );
  }
}
