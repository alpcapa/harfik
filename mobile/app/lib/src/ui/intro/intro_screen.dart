// Uygulamanın ilk açılış tanıtımı (19 Ağustos 2026).
//
// NEDEN VAR: web'de ilk gelen ziyaretçiyi karşılama katmanı (`src/landing/`)
// karşılıyor; portta böyle bir şey YOKTU — uygulamayı ilk açan kişi doğrudan
// Setup'a düşüyor, oyunun ne olduğunu hiçbir yerde okumadan "OYUNU BAŞLAT"
// görüyordu. Web'in ilk oyunda otomatik açılan "Hızlı Başlangıç" penceresi
// de porta hiç bağlanmamıştı (`FlagsStore.seenQuickstart` depoda vardı ama
// hiçbir UI onu okumuyordu). Kullanıcı sordu: *"App'e gelenler tanıtım
// görmeyecek mi?"* — bu ekran o boşluğu kapatıyor.
//
// WEB'İN LANDING'İ OLDUĞU GİBİ TAŞINMADI ve bu bilinçli: o sayfa SEO/
// paylaşım için yazıldı (SSS, "Uygulama indirmem gerekiyor mu?" maddesi,
// paylaş linkleri, ham HTML'de taranabilir metin). Uygulamada bunların
// hiçbirinin karşılığı yok. Taşınan şey METİN: kahraman cümlesi ve dört
// adımlık "Nasıl oynanır" anlatısı `Landing.tsx` ile BİREBİR aynı — biri
// değişirse öteki de değişmeli (kural metinlerinde `help_modal.dart` ile
// aynı disiplin).
//
// SETUP BAŞLIĞINA GERİ OKU KONMADI (web'de var, portta YOK — bkz.
// mobile/CLAUDE.md "Karşılama Katmanı"): native'de kök ekranın sol üstündeki
// geri oku navigasyon yığınını pop eder ve iOS'ta sistem geri hareketiyle
// çakışır. Tanıtıma dönüş hesap menüsündeki "Tanıtım" satırından.
import 'package:flutter/material.dart';

import '../game/logo_mark.dart';
import '../game/neo_box.dart';
import '../game/neo_button.dart';
import '../game/player_colors.dart';
import '../rank/league_rank.dart';
import '../rank/rank_seal.dart';
import '../tokens.dart';

/// Tanıtımın sayfa sayısı — nokta göstergesi ve "son sayfa mı" kararı bunu
/// kullanır (testler de bu sabiti okuyor, elle 4 yazılmıyor).
const int kIntroPageCount = 4;

/// Sözlük büyüklüğü — web `Landing.tsx`'teki `KELIME_SAYISI` ile ELLE
/// senkron (orada da düz bir sabit; `words_tr.txt` derleme anında
/// sayılmıyor). Sözlük gerçekte büyürse iki tarafta da güncellenmeli.
const String kKelimeSayisi = '63.000';

class IntroScreen extends StatefulWidget {
  /// Tanıtım bittiğinde (ya da "Atla"ya basıldığında) çağrılır. İlk açılışta
  /// bayrağı yazıp Setup'a geçmek çağıranın işi; hesap menüsünden açıldığında
  /// yalnızca `Navigator.pop`.
  final VoidCallback onDone;

  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page >= kIntroPageCount - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          // Web'in katmanı gibi 460px'lik metin kolonu — Setup ile aynı ölçü.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // "Atla" — son sayfada yerini alttaki "BAŞLA" aldığından
                // gizleniyor; satırın kendisi DURUYOR ki sayfalar arasında
                // içerik yukarı/aşağı zıplamasın.
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _isLast
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: TextButton(
                              onPressed: widget.onDone,
                              child: const Text(
                                'Atla',
                                style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 12,
                                  color: kMuted,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [
                      _HosGeldinSayfasi(),
                      _AdimlarSayfasi(
                        baslik: 'Nasıl oynanır?',
                        adimlar: [_adim1, _adim2],
                      ),
                      _AdimlarSayfasi(
                        baslik: 'Puanı katla, vergiye dikkat',
                        adimlar: [_adim3, _adim4],
                      ),
                      _RutbeSayfasi(),
                    ],
                  ),
                ),
                _Noktalar(aktif: _page),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: NeoButton(
                      label: _isLast ? 'BAŞLA' : 'DEVAM',
                      onPressed: _next,
                      variant: NeoButtonVariant.accent,
                      fontSize: 13,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek bir "Nasıl oynanır" adımı — metinler `Landing.tsx`'in `<Adim>`
/// listesiyle BİREBİR aynı (bkz. dosya başlığı).
class _Adim {
  final int no;
  final String baslik;
  final String metin;

  /// 5×5 mini şema — web'in `MiniIzgara`sıyla aynı harf sözlüğü.
  final List<String> izgara;

  const _Adim({
    required this.no,
    required this.baslik,
    required this.metin,
    required this.izgara,
  });
}

const _adim1 = _Adim(
  no: 1,
  baslik: 'Köşenden başla',
  metin: 'İlk kelimen köşendeki ev karesine değmek zorunda. Herkes kendi '
      'köşesinden başlar.',
  izgara: ['AAA~.', '~~~~.', '~~~~.', '~~~~.', '.....'],
);

const _adim2 = _Adim(
  no: 2,
  baslik: 'Bölgeni büyüt',
  metin: 'Köşenden kesintisiz bağlanan her taş bölgeni büyütür. Bölgen sabit '
      'bir alan değildir, sen oynadıkça büyür.',
  izgara: ['AAAA.', '~~~A.', '~~~A.', '~~~A.', '...A.'],
);

const _adim3 = _Adim(
  no: 3,
  baslik: 'Merkeze oyna',
  metin: 'Ortadaki 5×5 bölge kelime puanını ikiye, tam merkezdeki tek kare '
      'ise üçe katlar. Oraya git!',
  izgara: ['..A..', '.###.', '.#*#.', '.###.', '.....'],
);

const _adim4 = _Adim(
  no: 4,
  baslik: 'Bölge vergisine dikkat!',
  metin: 'İlk hamleden sonra istediğin zaman rakibin bölgesine değen/giren '
      'hamle yapabilirsin; ama vergisini ödersin, unutma!',
  izgara: ['.....', '.bbb.', '.bAb.', '.bbb.', '.....'],
);

class _HosGeldinSayfasi extends StatelessWidget {
  const _HosGeldinSayfasi();

  @override
  Widget build(BuildContext context) {
    return _Sayfa(
      children: [
        const LogoMark(height: 52),
        const SizedBox(height: 16),
        const Text(
          // Web kahraman cümlesi (Landing.tsx) — birebir.
          'Kelime bul, bölgeni büyüt, tahtayı ele geçir.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            height: 1.3,
            color: kText,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Kelimeki, 2 veya 4 kişi yapay zekaya veya arkadaşlarına karşı '
          'oynanabilen, strateji odaklı Türkçe kelime oyunudur.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.6, color: kMuted),
        ),
        const SizedBox(height: 20),
        // Web'in dört rakam kutusu (Landing.tsx). `Row` DEĞİL `Wrap`:
        // Flutter'da taşan bir Row "RenderFlex overflowed" çubuğu basar,
        // web'in sessiz yatay kaydırmasından çok daha yıkıcı — dar
        // ekranda alt satıra sarsın (Parça 110'un footer dersi).
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Kutu(sayi: '$kKelimeSayisi+', etiket: 'Kelime'),
            _Kutu(sayi: '13×13', etiket: 'Tahta'),
            _Kutu(sayi: '2–4', etiket: 'Oyuncu'),
            _Kutu(sayi: 'Ücretsiz', etiket: 'Fiyat'),
          ],
        ),
      ],
    );
  }
}

class _AdimlarSayfasi extends StatelessWidget {
  final String baslik;
  final List<_Adim> adimlar;
  const _AdimlarSayfasi({required this.baslik, required this.adimlar});

  @override
  Widget build(BuildContext context) {
    return _Sayfa(
      children: [
        Text(
          baslik,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: kText,
          ),
        ),
        const SizedBox(height: 16),
        for (final adim in adimlar) ...[
          _AdimKarti(adim: adim),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RutbeSayfasi extends StatelessWidget {
  const _RutbeSayfasi();

  @override
  Widget build(BuildContext context) {
    return _Sayfa(
      children: [
        const Text(
          'Kazandıkça yüksel',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: kText,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Her oyun k-lig puanı getirir. Eşiği geçtiğin an rütben yükselir '
          've o eşiğe özel, bir kereye mahsus bir ödül puanı kazanırsın.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.6, color: kMuted),
        ),
        const SizedBox(height: 18),
        // Dokuz kademe — liste `league_rank.dart`ten geliyor, elle YAZILMIYOR
        // (eşik/ad/renk değişirse bu ekran kendiliğinden takip eder; web'in
        // "Rütbeler ve Ödüller" bölümündeki aynı kural).
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final tier in kRankTiers) _RutbeKutusu(tier: tier),
          ],
        ),
      ],
    );
  }
}

/// Sayfaların ortak iskeleti: dikeyde ortalı, taşarsa kaydırılabilir.
class _Sayfa extends StatelessWidget {
  final List<Widget> children;
  const _Sayfa({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _AdimKarti extends StatelessWidget {
  final _Adim adim;
  const _AdimKarti({required this.adim});

  @override
  Widget build(BuildContext context) {
    // Kod tabanının deseni: gölgeli kutular `Container(decoration:, padding:)`
    // ile kuruluyor — `DecoratedBox` DEĞİL, çünkü çerçevenin çocuğu içeri
    // itmesi (`Decoration.padding`) yalnızca Container tarafından uygulanır.
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: kPanel,
        radius: 12,
        shadows: kRaisedShadows,
        borderColor: kBorder,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniIzgara(satirlar: adim.izgara),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${adim.no}. ',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          color: kAccent,
                        ),
                      ),
                      TextSpan(text: adim.baslik),
                    ]),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adim.metin,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

/// Web `MiniIzgara` — 5×5, 10px hücre, 2px boşluk. Harf sözlüğü birebir aynı.
class _MiniIzgara extends StatelessWidget {
  final List<String> satirlar;
  const _MiniIzgara({required this.satirlar});

  static const Color _bos = Color(0xFFDDE4EE);
  static const Color _bonus = Color(0xFFFDE68A);
  static const Color _merkez = Color(0xFFF97316);

  Color _zemin(String h) {
    switch (h) {
      case '~':
        return playerColors[0].zone;
      case '#':
        return _bonus;
      case '*':
        return _merkez;
      case 'b':
        return playerColors[1].zone;
      case 'A':
        return playerColors[0].base;
      case 'B':
        return playerColors[1].base;
      default:
        return _bos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: _bos,
        radius: 8,
        shadows: kRaisedShadows,
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < satirlar.length; r++) ...[
              if (r > 0) const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < satirlar[r].length; c++) ...[
                    if (c > 0) const SizedBox(width: 2),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _zemin(satirlar[r][c]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
      ),
    );
  }
}

/// Kahraman sayfasındaki küçük rakam kutusu (web `Kutu`).
class _Kutu extends StatelessWidget {
  final String sayi;
  final String etiket;
  const _Kutu({required this.sayi, required this.etiket});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: kPanel,
        radius: 12,
        shadows: kRaisedShadows,
        borderColor: kBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sayi,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiket,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                color: kMuted,
              ),
            ),
          ],
      ),
    );
  }
}

class _RutbeKutusu extends StatelessWidget {
  final RankTier tier;
  const _RutbeKutusu({required this.tier});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankSeal(tier: tier, size: 30),
          const SizedBox(height: 4),
          Text(
            tier.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1,
              color: kText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${tier.threshold}',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              height: 1,
              color: kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Noktalar extends StatelessWidget {
  final int aktif;
  const _Noktalar({required this.aktif});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kIntroPageCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == aktif ? kAccent : kBorder,
            ),
          ),
        ],
      ],
    );
  }
}
