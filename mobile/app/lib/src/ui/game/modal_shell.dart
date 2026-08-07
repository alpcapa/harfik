// Paylaşılan modal kabuğu — src/components/Modal.tsx portu.
// Web'de ~15 modal bu kabuğu paylaşıyor (başlık: mono/kalın/uppercase/accent,
// sağda ✕, altında ayraç; gövde kaydırılabilir). Flutter tarafında ilk
// modaller (Kalan Taşlar, GameOver) kendi Dialog'larını kurmuştu — hamle
// geçmişi üçüncü modal olunca ortak kabuk çıkarıldı, diğer ikisi de buna
// taşındı (web'le aynı tek-kaynak disiplini).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

const Color _panel = Color(0xFFF5F7FA);
const Color _panelBorder = Color(0xFFB8C2D1);
const Color _divider = Color(0xFFDCE2EA);
const Color _accent = Color(0xFF2563EB);
const Color _muted = Color(0xFF5A6673);

/// Web `Modal`: 360px'lik panel, %85 yükseklik sınırı, kaydırılabilir gövde.
class KModal extends StatelessWidget {
  /// Boş bırakılabilir — web'de GameOver `title=""` geçip yalnızca ✕ gösterir.
  final String title;

  /// Metin yerine bir widget başlık (web'de `title` bir ReactNode olabiliyor:
  /// k-lig sıralamasının başlığı 🏆 + wordmark). Verilirse [title] yok sayılır.
  final Widget? titleWidget;
  final Widget child;

  /// Başlığın ÜSTÜNDE gösterilen küçük gezinme linki (web `headerLink` —
  /// HelpModal'ın Hızlı Başlangıç ↔ Detaylı Kurallar geçişi).
  final Widget? headerLink;

  /// ✕'in davranışı — web Modal'ın `onClose` prop'u. Verilmezse Navigator
  /// pop (showDialog ile açılan olağan kullanım). Bir route OLMADAN inline
  /// render edilen modal (ResetPasswordModal'ın kök recovery kapısı) pop
  /// edilecek bir dialog route'u taşımadığından bunu geçmek ZORUNDA — aksi
  /// halde ✕ alttaki gerçek ekran route'unu pop ederdi.
  final VoidCallback? onClose;

  const KModal({
    super.key,
    required this.title,
    required this.child,
    this.titleWidget,
    this.headerLink,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _panel,
      insetPadding: const EdgeInsets.all(16), // web p-4
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // web rounded-xl
        side: const BorderSide(color: _panelBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (headerLink != null) ...[
                    headerLink!,
                    const SizedBox(height: 8), // web gap-2
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: titleWidget ??
                            Text(
                              // Web'de CSS `uppercase` (tr locale ile doğru
                              // çalışır); Dart'ta karşılığı trUpper — native
                              // toUpperCase 'İ'yi bozar (proje kuralı).
                              trUpper(title),
                              style: const TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: _accent,
                              ),
                            ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Kapat',
                        onPressed:
                            onClose ?? () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
