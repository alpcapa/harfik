// Kullanıcı avatarı — src/components/Avatar.tsx portu: fotoğraf varsa o,
// yoksa isimden türetilen baş harfler (Türkçe trUpper ile), boş isimde "?".
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

const Color _panel = Color(0xFFF5F7FA);
const Color _border = Color(0xFFDCE2EA);
const Color _muted = Color(0xFF5A6673);

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

class KAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final avatar = _circle();
    if (!dot) return avatar;
    final d = (size * 0.34).clamp(10.0, 14.0);
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
    final text = avatarInitials(name);
    // Web dersi: iki harfe göre ayarlı 0.4 oranı tek karakterde ("?") optik
    // olarak zayıf kalıyor → tek karakter 0.55 (bkz. PlayerAvatarRow notu).
    final fontSize = (size * (text.length == 1 ? 0.55 : 0.4)).roundToDouble();
    final u = url;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panel,
        shape: BoxShape.circle,
        border: Border.all(color: _border),
      ),
      child: u != null && u.isNotEmpty
          ? Image.network(
              u,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Ağ hatasında baş harflere düş (web <img> onError eşleniği).
              errorBuilder: (_, __, ___) => _initialsText(text, fontSize),
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
          color: _muted,
        ),
      );
}
