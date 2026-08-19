// Uygulamanın ilk açılış tanıtımı (19 Ağustos 2026).
//
// NEDEN VAR: web'de ilk gelen ziyaretçiyi karşılama katmanı (`src/landing/`)
// karşılıyor; portta böyle bir şey YOKTU — uygulamayı ilk açan kişi doğrudan
// Setup'a düşüyor, oyunun ne olduğunu hiçbir yerde okumadan "OYUNU BAŞLAT"
// görüyordu. Kullanıcı sordu: *"App'e gelenler tanıtım görmeyecek mi?"*
//
// DÖRT SLAYT (19 Ağustos 2026, kullanıcı spesifikasyonu — ilk sürüm yalnızca
// metindi ve reddedildi: *"Bu tanıtım değil kaçırım olmuş"*):
//   1. kahraman + dört rakam kutusu + GERÇEK tahta ("Tahtaya bir bak")
//   2. "Nasıl oynanır?" — dört adım
//   3. "Neler var" — altı özellik kutusu
//   4. "k-lig" — dokuz rütbe
// Dördü de `src/landing/Landing.tsx`'in AYNI bölümlerinin portu; metinler,
// ölçüler, renkler ve yerleşim oradan BİREBİR alınır — biri değişirse öteki
// de değişmeli (bunu zorlayan bir test YOK, kural metinlerinde
// `help_modal.dart` ile aynı disiplin).
//
// WEB'İN KATMANININ TAMAMI TAŞINMADI ve bu bilinçli: o sayfa SEO/paylaşım
// için de var (SSS, "Uygulama indirmem gerekiyor mu?" maddesi, paylaş
// linkleri, ham HTML'de taranabilir metin, kapı script'i). Uygulamada
// bunların karşılığı yok.
//
// SETUP BAŞLIĞINA GERİ OKU KONMADI (web'de var, portta YOK — bkz.
// mobile/CLAUDE.md "Karşılama Katmanı"): native'de kök ekranın sol üstündeki
// geri oku navigasyon yığınını pop eder ve iOS'ta sistem geri hareketiyle
// çakışır. Tanıtıma dönüş Setup'ın logo altındaki link satırından
// (yalnız misafirde — bkz. mobile/CLAUDE.md, Parça 117).
import 'package:flutter/material.dart';

import '../../data/game_record.dart';
import '../game/board_widget.dart';
import '../game/logo_mark.dart';
import '../game/neo_box.dart';
import '../game/neo_button.dart';
import '../game/player_colors.dart';
import '../rank/league_rank.dart';
import '../rank/rank_seal.dart';
import '../tokens.dart';
import 'demo_board_data.dart';
import 'ozellik_ikonlari.dart';

/// Tanıtımın sayfa sayısı — nokta göstergesi ve "son sayfa mı" kararı bunu
/// kullanır (testler de bu sabiti okuyor, elle 4 yazılmıyor).
const int kIntroPageCount = 4;

/// Sözlük büyüklüğü — web `Landing.tsx`'teki `KELIME_SAYISI` ile ELLE
/// senkron (orada da düz bir sabit; `words_tr.txt` derleme anında
/// sayılmıyor). Sözlük gerçekte büyürse iki tarafta da güncellenmeli.
const String kKelimeSayisi = '63.000';

/// Metin sütununun genişliği — web `max-w-[460px] px-4` (içerik 428).
/// Setup ekranıyla AYNI ölçü (bkz. Parça 72).
const double _kMetinGenisligi = 460;

/// Tahta bölümünün kabı — web `max-w-[680px] px-3` (içerik 656). Oyun
/// ekranıyla BİREBİR aynı olmak ZORUNDA: taş harfi `vw` tabanlı bir
/// `clamp()` ile çiziliyor ama hücre boyu KABIN genişliğinden türüyor,
/// yani dar bir kapta harf/hücre oranı gerçek oyundan sapar (web'de bu
/// hata iki kez yapıldı, bkz. kök CLAUDE.md "AYNI GÜN İKİ KEZ YANLIŞ
/// FONT — ve kök sebep font DEĞİL GENİŞLİKTİ").
const double _kTahtaGenisligi = 680;

class IntroScreen extends StatefulWidget {
  /// Son sayfadaki "HEMEN OYNA"ya basıldığında çağrılır — tanıtımın TEK
  /// çıkışı bu (atlama yok). İlk açılışta bayrağı yazıp Setup'a geçmek
  /// çağıranın işi; Setup'taki "Tanıtım" linkinden açıldığında yalnızca
  /// `Navigator.pop`.
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
        child: Column(
          children: [
            // ATLAMA YOK (19 Ağustos 2026, kullanıcı isteği: "sadece
            // introyu atlama olmasın. Sonuna kadar geçip Hemen Oyna ...
            // ile setup'a gitmeli"). Tanıtımın TEK çıkışı son sayfadaki
            // "HEMEN OYNA". Bu, web'in karşılama katmanıyla da tutarlı:
            // orada da kapatma/atlama düğmesi yok.
            //
            // Sabit üst boşluk: `_Sayfa`nın kendi `top: 8` dolgusu tek
            // başına sayfayı ekranın tepesine yapıştırıyordu.
            const SizedBox(height: 24),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _HosGeldinSayfasi(),
                  _NasilOynanirSayfasi(),
                  _NelerVarSayfasi(),
                  _RutbeSayfasi(),
                ],
              ),
            ),
            _Noktalar(aktif: _page),
            // Butonun kabı da metin sütunuyla aynı genişlikte — geniş bir
            // ekranda (tablet) kenardan kenara uzamasın.
            _Kolon(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: NeoButton(
                    label: _isLast ? 'HEMEN OYNA' : 'DEVAM',
                    onPressed: _next,
                    variant: NeoButtonVariant.accent,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sayfa 1 — kahraman + rakamlar + tahta
// ---------------------------------------------------------------------------

class _HosGeldinSayfasi extends StatelessWidget {
  const _HosGeldinSayfasi();

  @override
  Widget build(BuildContext context) {
    return _Sayfa(
      children: [
        _Kolon(
          child: Column(
            children: const [
              LogoMark(height: 52),
              SizedBox(height: 16),
              Text(
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
              SizedBox(height: 12),
              Text(
                'Kelimeki, 2 veya 4 kişi yapay zekaya veya arkadaşlarına '
                'karşı oynanabilen, strateji odaklı Türkçe kelime oyunudur.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6, color: kMuted),
              ),
              SizedBox(height: 20),
              _Kutular(),
            ],
          ),
        ),
        // Web'de bu bölüm `my-9` (36px) ile ayrılıyor.
        const SizedBox(height: 36),
        const _TahtaBolumu(),
      ],
    );
  }
}

/// Web'in dört rakam kutusu (`Landing.tsx` → `Kutu`, `flex gap-2`).
class _Kutular extends StatelessWidget {
  const _Kutular();

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight` ŞART: `crossAxisAlignment: stretch` bir Row'da
    // DİKEY eksende esnetir ve bu sayfa kaydırılabilir bir Column'un
    // içinde (yükseklik sınırsız) — sarmalayıcı olmadan Flutter
    // "BoxConstraints forces an infinite height" ile patlar. Kardeş
    // ızgaralar (`_NelerVarSayfasi`, `_RutbeSayfasi`) aynı deseni
    // kullanıyor; dördü de eşit yükseklik alsın diye stretch korunuyor
    // (web'de `flex`in varsayılan `align-items: stretch`i).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(child: _Kutu(sayi: '$kKelimeSayisi+', etiket: 'Kelime')),
          SizedBox(width: 8),
          Expanded(child: _Kutu(sayi: '13×13', etiket: 'Tahta')),
          SizedBox(width: 8),
          Expanded(child: _Kutu(sayi: '2–4', etiket: 'Oyuncu')),
          SizedBox(width: 8),
          Expanded(child: _Kutu(sayi: 'Ücretsiz', etiket: 'Fiyat')),
        ],
      ),
    );
  }
}

/// Web `Kutu`: `flex-1 min-w-0 bg-panel border border-border rounded-xl
/// px-1 py-2.5 shadow-raised text-center`.
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dar ekranda "Ücretsiz" 14px mono ile kutuya sığmıyor —
          // web'de kutu `min-w-0` + yatay kaydırma güvenlik ağıyla
          // idare ediyor, Flutter'da taşan bir Row "RenderFlex
          // overflowed" çubuğu basardı (Parça 110'un dersi).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              sayi,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1,
                color: kAccent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              etiket.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 8,
                letterSpacing: 0.5,
                height: 1.3,
                color: kMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tahtaya bir bak" — GERÇEK `BoardWidget`, ekran görüntüsü ya da elle
/// çizim DEĞİL (web'in aynı kararı: köşe tonlaması, bölge dış hattı, X2/X3
/// tek kaynaktan gelsin diye). Taşlar `demo_board_data.dart`'tan geliyor ve
/// o dosya web'in `src/landing/demoBoard.ts`'inden ÜRETİLİYOR
/// (`npm run generate-demo-board-dart`) — kelimelerin gerçekten sözlükte
/// olduğunu `npm run verify-demo-board` ölçüyor.
class _TahtaBolumu extends StatelessWidget {
  const _TahtaBolumu();

  @override
  Widget build(BuildContext context) {
    final state = buildSnapshotGameState(
      kDemoTiles2,
      2,
      const [
        GamePlayerSnapshot(
          name: 'Sen',
          score: 0,
          isAi: false,
          surrendered: false,
          colorIndex: 0,
        ),
        GamePlayerSnapshot(
          name: 'Rakip',
          score: 0,
          isAi: false,
          surrendered: false,
          colorIndex: 1,
        ),
      ],
    );

    return Column(
      children: [
        const _Kolon(
          child: _BolumBasligi(
            ustBaslik: 'Tahtaya bir bak',
            baslik: 'Oyun tam olarak böyle görünüyor',
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kTahtaGenisligi),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Semantics(
                image: true,
                label: '2 kişilik oyun tahtası örneği — KELİME, IRMAK, ZAMAN '
                    'gibi kelimelerle dolu 13×13 tahta',
                child: ExcludeSemantics(
                  child: BoardWidget(state: state, hideFooter: true),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Kolon(
          child: Column(
            children: [
              _Rozet(renk: Color(0xFFFDE68A), metin: 'X2 — Kelime puanının 2 katı'),
              SizedBox(height: 6),
              _Rozet(renk: Color(0xFFF97316), metin: 'X3 — Kelime puanının 3 katı'),
              SizedBox(height: 12),
              Text(
                'Köşenden başla, orta bölgedeki sarı alana ulaş, puanlarını '
                'ikiye hatta üçe katla. Rakip bölgesine değen hamle yaparsan '
                'kazandığının üçte birini ona vergi olarak ödersin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.6, color: kMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Web `Rozet`: renk kutucuğu + açıklama (`text-[11px] leading-tight`).
class _Rozet extends StatelessWidget {
  final Color renk;
  final String metin;
  const _Rozet({required this.renk, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: renk,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: kBorder),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            metin,
            style: const TextStyle(fontSize: 11, height: 1.25, color: kMuted),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sayfa 2 — "Nasıl oynanır?" (dört adım)
// ---------------------------------------------------------------------------

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

class _NasilOynanirSayfasi extends StatelessWidget {
  const _NasilOynanirSayfasi();

  @override
  Widget build(BuildContext context) {
    return _Sayfa(
      children: const [
        _Kolon(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BolumBasligi(
                ustBaslik: 'Dört adımda',
                baslik: 'Nasıl oynanır?',
              ),
              SizedBox(height: 12),
              _AdimKarti(adim: _adim1),
              SizedBox(height: 10),
              _AdimKarti(adim: _adim2),
              SizedBox(height: 10),
              _AdimKarti(adim: _adim3),
              SizedBox(height: 10),
              _AdimKarti(adim: _adim4),
            ],
          ),
        ),
      ],
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

// ---------------------------------------------------------------------------
// Sayfa 3 — "Neler var" (altı özellik)
// ---------------------------------------------------------------------------

class _NelerVarSayfasi extends StatelessWidget {
  const _NelerVarSayfasi();

  @override
  Widget build(BuildContext context) {
    const kutular = [
      _Ozellik(
        ikon: OzellikIkonTuru.robot,
        baslik: 'Yapay zekaya karşı oyna',
        metin: 'Kurabildiği en yüksek puanlı kelimeyi arayan amansız bir '
            'rakip. İster 1 rakip, ister 3 rakibe karşı oyna.',
      ),
      _Ozellik(
        ikon: OzellikIkonTuru.ikiKisi,
        baslik: 'Arkadaşınla canlı oyna',
        metin: 'Oyun aç, davet gönder, ister canlı, ister 48 saat içinde '
            'hamle yaparak rahatça oyna.',
      ),
      _Ozellik(
        ikon: OzellikIkonTuru.sohbet,
        baslik: 'Oyun içi sohbet',
        metin: 'Canlı oyunlarda masadan ayrılmadan yazışın; rahatsız eden '
            'olursa sessize al ya da bildir.',
      ),
      _Ozellik(
        ikon: OzellikIkonTuru.cevrimdisi,
        baslik: 'Çevrimdışı da oynar',
        metin: 'Yapay zekaya karşı internet bağlantısı olmadan da '
            'oynayabilirsin. Canlı oyun için İnternet gerekiyor.',
      ),
      _Ozellik(
        ikon: OzellikIkonTuru.tahta,
        baslik: 'Kelime denemesi',
        metin: 'Sıra sendeyken veya rakipteyken tahtada her zaman kelime '
            'denemeleri yapabilirsin.',
      ),
      _Ozellik(
        ikon: OzellikIkonTuru.madalya,
        baslik: 'k-lig ve rütbeler',
        metin: 'Kazandıkça puan toplar; puan topladıkça eşikleri geçip '
            'rütbeni yükseltir, bonusları kaparsın.',
      ),
    ];

    return _Sayfa(
      children: [
        _Kolon(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BolumBasligi(
                ustBaslik: 'Neler var',
                baslik: 'Kelimeki\'de neler yapabilirsin?',
              ),
              const SizedBox(height: 12),
              // Web `grid grid-cols-2 gap-2` — Flutter'da `GridView`
              // KULLANILMADI: hücre yüksekliği metne göre değişiyor
              // (`GridView` sabit bir en-boy oranı ister) ve sayfa zaten
              // kaydırılabilir bir Column.
              for (var i = 0; i < kutular.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: kutular[i]),
                      const SizedBox(width: 8),
                      Expanded(child: kutular[i + 1]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Web `Ozellik`: `bg-panel border border-border rounded-xl p-3
/// shadow-raised flex flex-col gap-1`.
class _Ozellik extends StatelessWidget {
  final OzellikIkonTuru ikon;
  final String baslik;
  final String metin;
  const _Ozellik({
    required this.ikon,
    required this.baslik,
    required this.metin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: kPanel,
        radius: 12,
        shadows: kRaisedShadows,
        borderColor: kBorder,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Web `items-start` + `mt-[1px]`: 390px'te kart iç genişliği
              // ~151px ve başlıkların çoğu iki satıra sarıyor; ortalanan
              // ikon o iki satırın arasına düşüp ilk satırla bağını
              // koparıyordu.
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: OzellikIkon.turden(ikon, color: kAccent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    color: kText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            metin,
            style: const TextStyle(fontSize: 11, height: 1.6, color: kMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sayfa 4 — k-lig rütbeleri
// ---------------------------------------------------------------------------

class _RutbeSayfasi extends StatelessWidget {
  const _RutbeSayfasi();

  @override
  Widget build(BuildContext context) {
    return _Sayfa(
      children: [
        _Kolon(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BolumBasligi(
                ustBaslik: 'k-lig',
                baslik: 'Çaylak\'tan Tanrı\'ya dokuz rütbe',
              ),
              const SizedBox(height: 12),
              const Text(
                'Kazandığın her oyun k-lig puanı getirir. Eşiği geçtiğin an '
                'rütben yükselir ve o eşiğe özel, bir kereye mahsus bir ödül '
                'puanı kazanırsın.',
                style: TextStyle(fontSize: 12, height: 1.6, color: kMuted),
              ),
              const SizedBox(height: 12),
              // Dokuz kademe — liste `league_rank.dart`ten geliyor, elle
              // YAZILMIYOR (eşik/ad/renk değişirse bu ekran kendiliğinden
              // takip eder; web'in aynı kuralı). Web `grid-cols-3 gap-2`.
              for (var i = 0; i < kRankTiers.length; i += 3) ...[
                if (i > 0) const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + 3; j++) ...[
                        if (j > i) const SizedBox(width: 8),
                        Expanded(child: _RutbeKutusu(tier: kRankTiers[j])),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Web: `bg-panel border border-border rounded-xl py-2.5 shadow-raised
/// flex flex-col items-center gap-1`.
class _RutbeKutusu extends StatelessWidget {
  final RankTier tier;
  const _RutbeKutusu({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: kPanel,
        radius: 12,
        shadows: kRaisedShadows,
        borderColor: kBorder,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RankSeal(tier: tier, size: 30),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tier.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1,
                color: kText,
              ),
            ),
          ),
          const SizedBox(height: 4),
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

// ---------------------------------------------------------------------------
// Ortak parçalar
// ---------------------------------------------------------------------------

/// Sayfaların ortak iskeleti: taşarsa kaydırılabilir.
class _Sayfa extends StatelessWidget {
  final List<Widget> children;
  const _Sayfa({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

/// Metin sütunu — web `max-w-[460px] px-4` (içerik 428px).
class _Kolon extends StatelessWidget {
  final Widget child;
  const _Kolon({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMetinGenisligi),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    );
  }
}

/// Web `Bolum`un başlık bloğu (`gap-0.5` = 2px).
class _BolumBasligi extends StatelessWidget {
  final String ustBaslik;
  final String baslik;
  const _BolumBasligi({required this.ustBaslik, required this.baslik});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ustBaslik.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 9,
            letterSpacing: 1.5,
            height: 1.5,
            color: kAccent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          baslik,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.25,
            color: kText,
          ),
        ),
      ],
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
