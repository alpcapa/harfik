import 'package:flutter/material.dart';

import '../tap_target.dart';
import '../tokens.dart';
import 'neo_box.dart';
import 'neo_button.dart';

/// Web'in ONAY / UYARI kartı — `KModal` ile KARIŞTIRILMAMALI.
///
/// Web'de İKİ ayrı kabuk var ve ikisi de bilinçli:
///   * `Modal.tsx` → başlıklı, ✕'li, ayraçlı 360px'lik pencere (port:
///     `modal_shell.dart` / `KModal`) — içerik gösteren ekranlar.
///   * `App.tsx` / `OnlineGameScreen.tsx` / `FriendsModal.tsx`'in satır içi
///     `fixed inset-0 z-[200]` popup'ları → 384px'lik onay kartı. ÜÇ dosya da
///     BİREBİR AYNI sınıfları taşıyor, yani tek bir kanonik kart var.
///
/// Bu dosya ikincisinin portu. **15 Ağustos 2026'ya kadar port bunu hiç
/// taşımamıştı:** sekiz diyalog düz `AlertDialog` idi (Material varsayılanı —
/// beyaz kart, Material tipografisi, mavi metin butonları) ve kullanıcı cihaz
/// testinde bildirdi: *"çıkan popup bizim site genelinde kullandığımız
/// tasarımlarla alakası yok"*. `friends_modal.dart` kartı elle çizmişti ama
/// o da sapmıştı (başlık 15, gövde 13/1.5, buton 11, gölge yok).
///
/// Değerler TAHMİN EDİLMEDİ — derlenmiş `dist/assets/*.css` gerçek DOM'a
/// uygulanıp Chromium'da ölçüldü (Parça 33'ün dersi: Tailwind sınıfından
/// zihnen türetme yok):
///
/// | Öğe | Ölçülen |
/// |---|---|
/// | kart | 384 genişlik · 24 dolgu · 16 yarıçap · 1px `#B8C2D1` |
/// | zemin / gölge | `kPanel` · `0 20px 45px rgba(15,23,42,.5)` |
/// | başlık | 16px / 700 / satır 24 |
/// | gövde | 14px / 400 / satır 1.625 (`leading-relaxed`) |
/// | başlık→gövde | 16 (`gap-4`) |
/// | gövde→butonlar | 20 (`gap-4` + `mt-1`) |
/// | buton | 12px / 700 / tracking 1 / uppercase / yarıçap 6 / dikey 10 |
/// | buton satırı | 8 boşluk · yükseklik 38 |
const double kDialogMaxWidth = 384;
const double kDialogPadding = 24;
const double kDialogRadius = 16;

/// Kartın çerçevesi. `KModal` de AYNI rengi taşıyor (`modal_shell.dart`) —
/// ikisi web'de de aynı `border-[#B8C2D1]`; biri değişirse öteki de.
const Color kDialogBorderColor = Color(0xFFB8C2D1);

const TextStyle kDialogTitleStyle = TextStyle(
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.bold,
  color: kText,
);

const TextStyle kDialogBodyStyle = TextStyle(
  fontSize: 14,
  height: 1.625,
  color: kText,
);

/// Kartın kendisi. Özel içerik (avatarlı başlık, vurgulu `TextSpan`'ler)
/// gerektiren yerler bunu doğrudan kullanır; düz onay/bilgi için aşağıdaki
/// [showKConfirm] / [showKInfo] yeterli.
class KDialogCard extends StatelessWidget {
  /// Genelde `Text(..., style: kDialogTitleStyle)`; yeni mesaj popup'ında
  /// avatar + isim satırı (web'de de öyle).
  final Widget? title;

  /// Genelde `Text(..., style: kDialogBodyStyle)`.
  final Widget? content;

  /// Butonlar. TEK buton verilirse web'deki gibi tam genişlik olur; iki (ya
  /// da daha fazla) verilirse 8px boşlukla eşit bölünür. Kabul eden buton
  /// HER ZAMAN ilk sırada = SOLDA (Parça 25 — web'in JSX sırası).
  final List<Widget> actions;

  /// Verilirse sağ üste bir ✕ konur (web: `absolute top-3 right-3`, 28×28).
  ///
  /// Web'de bu kartların ÇOĞUNDA ✕ YOK — vazgeçme yolu zaten "VAZGEÇ"
  /// butonu (kök `CLAUDE.md`: *"Vazgeç'i zaten olan dialoglara ayrıca X
  /// eklenmedi, gereksiz"*). ✕ yalnızca iptal butonu OLMAYAN kartta var:
  /// Setup'ın "Giriş Yap / Devam" uyarısı — orada Escape'in "Devam"a
  /// basılmış gibi davranması yanlış olurdu, o yüzden ayrı bir "sadece
  /// kapat" yolu gerekiyor. Yeni bir kullanım yeri eklerken önce web'de
  /// gerçekten ✕ olup olmadığına bak.
  final VoidCallback? onClose;

  const KDialogCard({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (title != null) children.add(title!);
    if (content != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      // ✕ varken gövde onun ALTINA girmesin — web'de aynı paragraf `pr-6`
      // (24) taşıyor. Butonlara uygulanMAZ (web'de de satırın dolgusu yok).
      children.add(onClose == null
          ? content!
          : Padding(
              padding: const EdgeInsets.only(right: 24), child: content!));
    }
    if (actions.isNotEmpty) {
      // web: `gap-4` (16) + butonlar satırının kendi `mt-1`i (4).
      if (children.isNotEmpty) children.add(const SizedBox(height: 20));
      if (actions.length == 1) {
        children.add(actions.first);
      } else {
        children.add(
          // Web'de satır `flex` ve varsayılan `align-items: stretch` —
          // accent butonun çerçevesi olmadığından tek başına 36 olurdu, ama
          // kenarlıklı neutral kardeşi 38 yaptığından ikisi de 38 çiziliyor.
          // `IntrinsicHeight` bunun Flutter karşılığı.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ),
        );
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Web'in kaplaması `px-4` (16) — Flutter'ın varsayılanı yanlardan 40.
      // Fark dar ekranda GERÇEK: 420px'lik bir telefonda web kartı 384
      // çizerken port 340'a sıkışıyordu (15 Ağustos 2026, yeni testin
      // ölçümüyle bulundu).
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      // Flutter'ın `Dialog`ı VARSAYILAN olarak yalnızca `minWidth: 280`
      // taşıyor, ÜST sınır YOK (kaynak: dialog.dart) — geniş ekranda
      // (iPad) `insetPadding`in bıraktığı tüm alana yayılıyordu.
      constraints: const BoxConstraints(maxWidth: kDialogMaxWidth),
      // `DecoratedBox` DEĞİL `Container`: yalnızca Container
      // `Decoration.padding`i onurlandırıyor ve çerçeveyi içeriğin ÜSTÜNE
      // bindirmeden içeri itiyor — web'in `border-box`ı da böyle (içerik
      // 384 − 2×1 çerçeve − 2×24 dolgu = 334).
      child: Container(
        // Gölge `BoxShadow` DEĞİL `CssShadow` ile — Flutter'ın `boxShadow`u
        // CSS'ten daha yoğun boyuyor ve katman sırası TERS (bkz. neo_box.dart
        // ve Parça "Tahta dış gölgesi").
        decoration: const ShapeDecorationWithCssShadows(
          color: kPanel,
          radius: kDialogRadius,
          borderColor: kDialogBorderColor,
          borderWidth: 1,
          shadows: kFloatingCardShadows,
        ),
        // Dolgu ✕ YOKKEN Container'da kalır (mevcut 8 çağrı yerinin ağacı
        // ve `dialog_shell_test`in `Container.padding == all(24)` kontratı
        // AYNEN korunuyor — 17 Ağustos 2026'da bu ikisini ayırmayan ilk
        // sürüm CI'da o testi düşürdü). ✕ VARSA dolgu çocuğa iner: aksi
        // halde Container'ın 24'ü içindeki bir `Positioned` kartın
        // kenarından 12 değil 36 uzakta çizilirdi (web `top-3 right-3`).
        padding:
            onClose == null ? const EdgeInsets.all(kDialogPadding) : null,
        child: _withCloseButton(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  /// `onClose` yoksa gövdeyi olduğu gibi döner (sıfır davranış farkı).
  Widget _withCloseButton(Widget body) {
    if (onClose == null) return body;
    return Stack(
      children: [
        Padding(
            padding: const EdgeInsets.all(kDialogPadding), child: body),
        // Dokunma kutusu 28×28'di (web'in `w-7 h-7`'si birebir taşınmıştı) —
        // projedeki EN KÜÇÜK dokunma hedefi, Material asgarisinin yarısından
        // az. 48'e çıkarıldı ve `Positioned` 12 → 2 ile telafi edildi:
        // ikonun merkezi iki durumda da kenardan 26 px içeride, yani
        // GÖRSEL DEĞİŞMEDİ (27 Ağustos 2026, bkz. `KIconButton`).
        Positioned(
          top: 2,
          right: 2,
          child: KIconButton(
            icon: Icons.close,
            tooltip: 'Kapat',
            // KModal'ın ✕'iyle AYNI glyph/boy/renk — web'de ikisi de
            // `text-lg text-muted` (`modal_shell.dart`).
            color: kMuted,
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}

/// Kart içindeki bir buton — web'in `btn-raised` / `btn-raised-neutral`
/// ölçüleriyle (12px/700/tracking 1/dikey 10/satır 16).
Widget kDialogButton({
  required String label,
  required VoidCallback? onPressed,
  NeoButtonVariant variant = NeoButtonVariant.neutral,
}) {
  return NeoButton(
    label: label,
    variant: variant,
    fontSize: 12,
    letterSpacing: 1,
    lineHeight: 16 / 12,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    onPressed: onPressed,
  );
}

/// İki butonlu onay — kabul SOLDA. `true` = kabul, `false`/`null` = vazgeç.
Future<bool> showKConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'VAZGEÇ',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => KDialogCard(
      title: Text(title, style: kDialogTitleStyle),
      content: Text(message, style: kDialogBodyStyle),
      actions: [
        kDialogButton(
          label: confirmLabel,
          variant: NeoButtonVariant.accent,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        kDialogButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Tek butonlu bilgi/sonuç kartı — buton web'deki gibi TAM GENİŞLİK.
Future<void> showKInfo(
  BuildContext context, {
  String? title,
  required String message,
  String buttonLabel = 'TAMAM',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => KDialogCard(
      title: title == null ? null : Text(title, style: kDialogTitleStyle),
      content: Text(message, style: kDialogBodyStyle),
      actions: [
        kDialogButton(
          label: buttonLabel,
          variant: NeoButtonVariant.accent,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
