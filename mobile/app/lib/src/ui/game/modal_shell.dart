// Paylaşılan modal kabuğu — src/components/Modal.tsx portu.
// Web'de ~15 modal bu kabuğu paylaşıyor (başlık: mono/kalın/uppercase/accent,
// sağda ✕, altında ayraç; gövde kaydırılabilir). Flutter tarafında ilk
// modaller (Kalan Taşlar, GameOver) kendi Dialog'larını kurmuştu — hamle
// geçmişi üçüncü modal olunca ortak kabuk çıkarıldı, diğer ikisi de buna
// taşındı (web'le aynı tek-kaynak disiplini).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;
import '../tokens.dart';

const Color _panel = kPanel;
const Color _panelBorder = Color(0xFFB8C2D1);
const Color _divider = kBorder;
const Color _accent = kAccent;
const Color _muted = kMuted;

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

  /// Başlığın YANINDA, ✕'in solunda gösterilen küçük bir aksiyon ikonu
  /// (web `headerAction` — ChatModal'ın Ayarlar/dişli ikonu, Oyun İçi
  /// Mesajlaşma Faz 2). `headerLink`'in aksine aynı satırda render edilir.
  final Widget? headerAction;

  /// Başlık ile ✕ arasındaki BOŞLUĞUN ortasında gösterilen öğe (web
  /// `headerCenter` — Skor Kartı'nın rütbe mührü). [headerAction]'dan farkı
  /// hizalama: o ✕'e bitişik sağda durur, bu ikisinin arasında ortalanır.
  /// Verilmezse hiçbir şey değişmez (başlık eskisi gibi tüm boşluğu alır).
  final Widget? headerCenter;

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
    this.headerAction,
    this.headerCenter,
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
                      // headerCenter varsa başlık yalnızca kendi genişliğini
                      // alır (web `shrink-0`) ve kalan boşluğu ortalanmış
                      // yuva doldurur; yoksa eski davranış (başlık esner).
                      _headerTitle(),
                      if (headerCenter != null)
                        Expanded(child: Center(child: headerCenter!)),
                      if (headerAction != null) headerAction!,
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

  Widget _headerTitle() {
    final label = titleWidget ??
        Text(
          // Web'de CSS `uppercase` (tr locale ile doğru çalışır); Dart'ta
          // karşılığı trUpper — native toUpperCase 'İ'yi bozar (proje kuralı).
          trUpper(title),
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: _accent,
          ),
        );
    // headerCenter yokken başlık kalan tüm genişliği alır (eski davranış:
    // uzun bir başlık ✕'e kadar uzanıp kırpılır). Varken web'deki gibi
    // `shrink-0`: kendi doğal genişliğinde durur ki ortalama gerçekten
    // "başlık ile ✕ arası" olsun.
    //
    // ÇIPLAK widget döner — `Flexible` DEĞİL (12 Ağustos 2026, kullanıcı
    // cihazda "X kaymış" diye bildirdi). `Flexible`ın varsayılanı
    // `flex: 1`'dir, yani başlık boş alanın YARISINI pay olarak alır;
    // `fit: loose` olduğundan doğal genişliğinde kalır ama ARTAN pay
    // yeniden dağıtılmaz ve Row'un sonunda ölü boşluk olarak birikir.
    // Ölçüldü: ✕'in merkezi kartın sağ kenarından 75.3px içerideydi
    // (olması gereken 32, web'de 34). Web'in `shrink-0`'ının doğru
    // karşılığı hiç flex vermemektir.
    return headerCenter == null ? Expanded(child: label) : label;
  }
}
