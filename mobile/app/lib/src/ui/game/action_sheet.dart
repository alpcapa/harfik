// iOS tarzı alttan açılan aksiyon menüsü — web `ActionSheet.tsx` portu.
//
// Web'de karartma katmanı ve kayarak beliriş ELLE yazılmıştı (kullanıcı
// "en altta çıkıyor, fark edilmiyor bile" demişti); Flutter'ın
// `showModalBottomSheet`'i ikisini de yerleşik veriyor — barrier rengi ve
// yukarı kayan geçiş hazır. Bu yüzden port bir widget değil bir çağrı
// yardımcısı: görsel dil (iki ayrı yuvarlatılmış panel, aralarında ince
// ayraç, altta ayrı "Vazgeç" paneli) web'le aynı.
import 'package:flutter/material.dart';

const _panel = Color(0xFFF5F7FA);
const _border = Color(0xFFDCE2EA);
const _text = Color(0xFF1B2430);
const _accent = Color(0xFF2563EB);
const _red = Color(0xFFDC2626);

class ActionSheetItem {
  final String label;
  final VoidCallback onSelect;
  final bool destructive;

  const ActionSheetItem({
    required this.label,
    required this.onSelect,
    this.destructive = false,
  });
}

/// Menüyü açar; bir seçenek seçilirse menü ÖNCE kapanır sonra `onSelect`
/// çalışır (web'in sırası — seçim bir başka modal açabiliyor).
Future<void> showActionSheet(
  BuildContext context, {
  required List<ActionSheetItem> actions,
}) async {
  final selected = await showModalBottomSheet<ActionSheetItem>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _border),
                      _SheetButton(
                        label: actions[i].label,
                        color: actions[i].destructive ? _red : _accent,
                        onTap: () => Navigator.of(sheetContext).pop(actions[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Panel(
                child: _SheetButton(
                  label: 'Vazgeç',
                  color: _text,
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  selected?.onSelect();
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x8017253F), blurRadius: 45, offset: Offset(0, 20)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      );
}
