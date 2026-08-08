// Kullanıcı avatarı — src/components/Avatar.tsx portu: fotoğraf varsa o,
// yoksa isimden türetilen baş harfler (Türkçe trUpper ile), boş isimde "?".
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

const Color _panel = Color(0xFFF5F7FA);
const Color _border = Color(0xFFDCE2EA);
// Web `bg-accent`/`border-accent` (tailwind.config.js `accent: '#2563EB'`) —
// fotoğrafsız/yüklenemeyen avatarın YEDEK durumu HER ZAMAN bu mavi zeminle
// çizilir (`Avatar.tsx`'in `<span className="... bg-accent border-accent
// text-white">` dalı — hem gerçek kullanıcı hem misafirin "?" hâli aynı
// stili kullanıyor, web hiçbir zaman gri/nötr bir yedek göstermiyor).
const Color _accent = Color(0xFF2563EB);

/// Web `initials()`: e-postaysa @ öncesi; boşluk/nokta/altçizgi/tire ile
/// bölünen iki parçadan birer harf, tek parçaysa ilk iki harf.
String avatarInitials(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return '?';
  final base = n.contains('@') ? n.split('@').first : n;
  final parts =
      base.split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return trUpper(parts[0][0] + parts[1][0]);
  return trUpper(base.length >= 2 ? base.substring(0, 2) : base);
}

class KAvatar extends StatefulWidget {
  final String? url;
  final String? name;
  final double size;

  /// Sağ üstte küçük kırmızı nokta — web `Avatar`'ın `dot` prop'u:
  /// SAYI taşımayan, "var/yok" bilgisi (bekleyen arkadaşlık isteği).
  /// Bilinçli olarak CountBadge DEĞİL (web'in aynı ayrımı).
  final bool dot;

  const KAvatar(
      {super.key, this.url, this.name, this.size = 32, this.dot = false});

  @override
  State<KAvatar> createState() => _KAvatarState();
}

class _KAvatarState extends State<KAvatar> {
  // Web `useState<boolean>(broken=false)` + `useEffect(() =>
  // setBroken(false), [url])` — fotoğraf yüklenemediyse baş harf yedeğine
  // düşer; `url` DEĞİŞİNCE (ör. yeni bir fotoğraf yüklenince) bu bayrak
  // sıfırlanır, aksi halde eski bir yükleme hatası kalıcı olarak baş
  // harflerde takılı kalırdı (web'in kod incelemesiyle düzelttiği hata).
  bool _broken = false;

  @override
  void didUpdateWidget(covariant KAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _broken = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _circle();
    if (!widget.dot) return avatar;
    final d = (widget.size * 0.34).clamp(10.0, 14.0);
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        top: -1,
        right: -1,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: const Color(0xFFE0483A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    ]);
  }

  Widget _circle() {
    final text = avatarInitials(widget.name);
    // Web dersi: iki harfe göre ayarlı 0.4 oranı tek karakterde ("?") optik
    // olarak zayıf kalıyor → tek karakter 0.55 (bkz. PlayerAvatarRow notu).
    final fontSize = (widget.size * (text.length == 1 ? 0.55 : 0.4))
        .roundToDouble();
    final u = widget.url;
    final showImage = u != null && u.isNotEmpty && !_broken;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Fotoğraf başarıyla yüklenmişse nötr panel/gri çerçeve (web `<img
        // className="... border-border bg-panel">`); yoksa (yok/yüklenemedi)
        // mavi yedek (web `<span className="... bg-accent border-accent">`).
        color: showImage ? _panel : _accent,
        shape: BoxShape.circle,
        border: Border.all(color: showImage ? _border : _accent),
      ),
      child: showImage
          ? Image.network(
              u,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // Ağ hatasında baş harflere düş (web <img> onError eşleniği).
              // `errorBuilder` build sırasında çağrıldığından `setState`'i
              // doğrudan burada tetiklemek "called during build" hatası
              // verir — web'in reaktif `broken` state'inin eşleniği bir
              // sonraki kareye ertelenir.
              errorBuilder: (_, __, ___) {
                if (!_broken) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_broken) setState(() => _broken = true);
                  });
                }
                return _initialsText(text, fontSize);
              },
            )
          : _initialsText(text, fontSize),
    );
  }

  Widget _initialsText(String text, double fontSize) => Text(
        text,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          height: 1,
          color: Colors.white,
        ),
      );
}
