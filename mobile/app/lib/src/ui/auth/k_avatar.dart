// Kullanıcı avatarı — src/components/Avatar.tsx portu: fotoğraf varsa o,
// yoksa isimden türetilen baş harfler (Türkçe trUpper ile), boş isimde "?".
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;
import '../game/count_badge.dart';
import '../tokens.dart';
import '../online_scope.dart';

const Color _panel = kPanel;
const Color _border = kBorder;
// Web `bg-accent`/`border-accent` (tailwind.config.js `accent: '#2563EB'`) —
// fotoğrafsız/yüklenemeyen avatarın YEDEK durumu HER ZAMAN bu mavi zeminle
// çizilir (`Avatar.tsx`'in `<span className="... bg-accent border-accent
// text-white">` dalı — hem gerçek kullanıcı hem misafirin "?" hâli aynı
// stili kullanıyor, web hiçbir zaman gri/nötr bir yedek göstermiyor).
const Color _accent = kAccent;

/// `Border.all` varsayılanı — web `border` (1px) karşılığı. Görüntünün
/// kırpılacağı iç dairenin çapı bu kadar küçüktür (bkz. `_circle`).
const double _borderWidth = 1.0;

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

  /// Sağ üstte bekleyen iş SAYISI — web `Avatar`'ın `badgeCount` prop'u.
  /// 16 Ağustos 2026'ya kadar sayısız bir noktaydı (`dot`) ve bilinçli
  /// olarak `CountBadge` DEĞİLDİ; kullanıcı noktaların fark edilmediğini
  /// bildirince iki platformda birden rozete çevrildi.
  final int badgeCount;

  const KAvatar(
      {super.key, this.url, this.name, this.size = 32, this.badgeCount = 0});

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

  /// Bir önceki karede çevrimdışı mıydık? Geçişi (çevrimdışı → çevrimiçi)
  /// yakalamak için; her bildirimde körlemesine sıfırlamak, gerçekten BOZUK
  /// bir URL'de sonsuz yeniden denemeye dönerdi.
  bool _wasOffline = false;

  @override
  void didUpdateWidget(covariant KAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _broken = false;
    }
  }

  /// ÇEVRİMİÇİNE DÖNÜNCE yüklenememiş görseli yeniden dener (29 Ağustos
  /// 2026, kullanıcı cihazda bildirdi: *"app açıkken internet gelince avatar
  /// güncellenmedi, sadece aç kapa yapınca düzeliyor"*). `_broken` yalnızca
  /// url değişince sıfırlandığından, bağlantı kesikken bir kez düşen görsel
  /// o widget yaşadığı sürece baş harflerde kalıyordu.
  ///
  /// `OnlineScope` bir `InheritedNotifier`; durum değişince bu widget zaten
  /// yeniden bağımlılık çözüyor, yani ayrı bir dinleyici/abonelik YOK.
  /// Kapsam yoksa (izole testler) davranış eskisiyle aynı.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final online = OnlineScope.maybeOf(context)?.online ?? true;
    if (online && _wasOffline && _broken) _broken = false;
    _wasOffline = !online;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _circle();
    if (widget.badgeCount <= 0) return avatar;
    // Konum, projedeki diğer tüm rozetlerle aynı (`top: -4, right: -4` —
    // web'in `-top-1 -right-1`'i). Beyaz halka web'deki `ring-2 ring-panel`
    // karşılığı: rozet avatarın kenarından ayrışsın diye.
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        top: -4,
        right: -4,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CountBadge(count: widget.badgeCount),
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
        border: Border.all(
            color: showImage ? _border : _accent, width: _borderWidth),
      ),
      // Web `<img className="rounded-full object-cover border border-border">`:
      // CSS'te `border-radius` BORDER kutusuna uygulanır ve halkanın İÇ kenarı
      // da yuvarlanır — görüntü, halkanın içindeki DAİREYE kırpılır, halka her
      // yönde eşit 1px kalır. Flutter'da ise `Container`ın kırpması DIŞ daireye
      // (çap `size`) göre yapılıyor, çocuk ise kenarlık kadar içeri itilmiş bir
      // KARE (kenar `size − 2`) oluyordu: kare, köşegenlerde halkanın üzerine
      // taşıp onu ÖRTÜYOR, yalnızca N/S/E/W'de halka görünüyordu. Sonuç dört
      // noktada gri "düz kenar", aralarda hiç çerçeve olmayan bozuk bir halka
      // (9 Ağustos 2026; kullanıcı cihaz testinde İKİ KEZ bildirdi, ilk iki
      // turda yanlışlıkla ekran görüntüsü artefaktı sanılıp kapatılmıştı).
      // GERÇEK widget CanvasKit'te render edilip halka açı açı ölçülerek
      // kanıtlandı: 24 açının yalnızca 4'ünde (0/90/180/270°) #DCE2EA vardı,
      // düzeltmeden sonra 24/24. `ClipOval` görüntüyü tam halkanın iç
      // kenarına oturan daireye kırpar = CSS davranışı.
      child: showImage
          ? ClipOval(
              child: Image.network(
              u,
              width: widget.size - _borderWidth * 2,
              height: widget.size - _borderWidth * 2,
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
            ))
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
