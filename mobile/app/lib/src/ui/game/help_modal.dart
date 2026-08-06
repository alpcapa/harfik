// Nasıl oynanır / kurallar — src/components/HelpModal.tsx portu.
// İki adım: kısa "Hızlı Başlangıç" (varsayılan) ve başlıktaki linkle açılan
// "Detaylı Kurallar" (web'deki aynı `headerLink` + iç görünüm makinesi).
//
// KURAL METİNLERİ WEB'DEN BİREBİR KOPYALANMIŞTIR — özetlenmez, yeniden
// yazılmaz. Web metni değişirse buraya da aynen taşınmalı (iki taraf tek
// kaynaktan üretilmiyor; ayrık ama birebir).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show bingoBonus;

import 'modal_shell.dart';

const Color _text = Color(0xFF1B2430);
const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFDCE2EA);

enum HelpStep { quick, detailed }

Future<void> showHelpModal(BuildContext context,
    {HelpStep initial = HelpStep.quick}) {
  return showDialog<void>(
    context: context,
    builder: (context) => HelpModal(initial: initial),
  );
}

class HelpModal extends StatefulWidget {
  final HelpStep initial;
  const HelpModal({super.key, this.initial = HelpStep.quick});

  @override
  State<HelpModal> createState() => _HelpModalState();
}

class _HelpModalState extends State<HelpModal> {
  late HelpStep _step = widget.initial;

  void _toggle() => setState(() =>
      _step = _step == HelpStep.quick ? HelpStep.detailed : HelpStep.quick);

  @override
  Widget build(BuildContext context) {
    final quick = _step == HelpStep.quick;
    return KModal(
      title: quick ? 'Hızlı Başlangıç' : 'Detaylı Kurallar',
      headerLink: _LinkButton(
        label: quick ? 'Detaylı Kurallar →' : 'Hızlı Başlangıç →',
        onTap: _toggle,
      ),
      child: quick ? _QuickStart(onDetailed: _toggle) : const _DetailedRules(),
    );
  }
}

// ── Ortak küçük parçalar (web Section/P/Pill/TileRow/QuickItem) ───────────

/// Web'de `<strong>` ile kalınlaşan bölümler burada `**...**` ile yazılır —
/// Türkçe metin kaynakta okunur/kopyalanabilir kalsın diye.
List<TextSpan> _runs(String source, TextStyle base) {
  final spans = <TextSpan>[];
  var bold = false;
  for (final part in source.split('**')) {
    if (part.isNotEmpty) {
      spans.add(TextSpan(
        text: part,
        style: bold ? base.copyWith(fontWeight: FontWeight.bold) : base,
      ));
    }
    bold = !bold;
  }
  return spans;
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          letterSpacing: 1,
          color: _accent,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  /// Düz başlık; joker bölümündeki gibi ★ gerekiyorsa [titleWidget] verilir.
  final String? title;
  final Widget? titleWidget;
  final List<Widget> children;
  const _Section({this.title, this.titleWidget, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: titleWidget ??
              Text(
                title!,
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: _accent,
                ),
              ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

/// Web `<P>`: 12px sans, satır aralığı geniş.
class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  static const TextStyle style =
      TextStyle(fontSize: 12, height: 1.625, color: _text);

  @override
  Widget build(BuildContext context) =>
      Text.rich(TextSpan(children: _runs(text, style)));
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final String desc;
  const _Pill({required this.label, required this.color, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(desc, style: const TextStyle(fontSize: 12, color: _text)),
        ),
      ],
    );
  }
}

/// Puan tablosu satırı: "1 puan: A(×12) E(×8) …". Joker satırında harf
/// yerine ★ ikonu gelir (glyph hiçbir bundled fontta yok — taş jokerindeki
/// aynı karar, bkz. tile_widget.dart).
class _TileRow extends StatelessWidget {
  final String pts;
  final List<(String, int)> tiles;
  final String? note;
  const _TileRow({required this.pts, required this.tiles, this.note});

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(
        fontFamily: 'SpaceMono', fontSize: 12, height: 1.625, color: _text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$pts puan:',
            style: mono.copyWith(fontWeight: FontWeight.bold, color: _accent)),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (tiles[i].$1 == '★')
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.star, size: 14, color: _text),
                    )
                  else
                    TextSpan(
                      text: tiles[i].$1,
                      style: mono.copyWith(fontWeight: FontWeight.bold),
                    ),
                  TextSpan(
                      text: '(×${tiles[i].$2})'
                          '${i < tiles.length - 1 ? '  ' : ''}',
                      style: mono),
                ],
                if (note != null) TextSpan(text: note, style: mono),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickItem extends StatelessWidget {
  final String icon;
  final String text;

  /// Joker maddesinde metnin içinde ★ ikonu var (glyph yok) — o satır
  /// parçalı verilir.
  final List<InlineSpan>? spans;
  const _QuickItem({required this.icon, this.text = '', this.spans});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            icon,
            // Emoji uygulama asset'i değil, platform sağlar. Aileleri
            // AÇIKÇA yedek listesine yazmak iki işe yarar: (1) Flutter'ın
            // platform yedeğine güvenmek yerine belirli aileyi hedefler,
            // (2) test ortamında FontLoader'la yüklenen aile ancak böyle
            // devreye girer (ad verilmezse hiç kullanılmıyor — ekran
            // görüntüsünde boş kutu çıkmıştı).
            style: const TextStyle(
              fontSize: 14,
              fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji'],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(children: spans ?? _runs(text, _P.style)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hızlı Başlangıç ───────────────────────────────────────────────────────

class _QuickStart extends StatelessWidget {
  final VoidCallback onDetailed;
  const _QuickStart({required this.onDetailed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _QuickItem(
          icon: '🎯',
          text: '2 ya da 4 oyuncuyla, **Yapay Zekâ**\'ya veya arkadaşlarına '
              'karşı oynanır.',
        ),
        const SizedBox(height: 8),
        const _QuickItem(
          icon: '🏠',
          text: 'Kendi bölgenden başlar, tahtanın **ortasına doğru** bölgeni '
              'genişletirsin.',
        ),
        const SizedBox(height: 8),
        const _QuickItem(
          icon: '🔗',
          text: 'Yeni kelimeler tahtadaki mevcut harflere (rakiplerinki dahil) '
              'bağlanmalıdır.',
        ),
        const SizedBox(height: 8),
        const _QuickItem(
          icon: '💰',
          text: 'Rakip bölgesine değen/giren hamlede, **bölge vergisi** '
              'ödersin.',
        ),
        const SizedBox(height: 8),
        const _QuickItem(
          icon: '✨',
          text: 'Ortadaki 5×5 bonus bölgesi puanlarını **ikiye**, **üçe** '
              'katlar.',
        ),
        const SizedBox(height: 8),
        _QuickItem(
          icon: '🎁',
          text: '7 taşını tek hamlede koyarsan **+$bingoBonus Bingo bonus** '
              'kazanırsın.',
        ),
        const SizedBox(height: 8),
        _QuickItem(
          icon: '⭐',
          spans: [
            const TextSpan(text: 'Joker (', style: _P.style),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.star, size: 14, color: _text),
            ),
            ..._runs(
              ') istediğin harfe dönüşür, puan değeri 0\'dır. Elindeki son '
              'taş(lar) jokerse ve onunla bitirirsen **+25/+50 bonus** '
              'kazanırsın.',
              _P.style,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _QuickItem(
          icon: '📖',
          text: 'Sadece **TDK sözlüğündeki** Türkçe kelimeler geçerlidir.',
        ),
        const SizedBox(height: 8),
        const _QuickItem(
          icon: '🏁',
          text: 'Harf kutunu bitirir ve torbada başka taş kalmazsa oyun biter. '
              'Art arda 2 tur pas geçilince de oyun biter.',
        ),
        const SizedBox(height: 12),
        _LinkButton(label: 'Detaylı Kurallar →', onTap: onDetailed),
      ],
    );
  }
}

// ── Detaylı Kurallar ──────────────────────────────────────────────────────

class _DetailedRules extends StatelessWidget {
  const _DetailedRules();

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      const _Section(
        title: 'Nasıl Oynanır?',
        children: [
          _P('Kelimeki, Yapay Zekâ\'ya veya arkadaşlarına karşı oynanan '
              'strateji odaklı bir kelime oyunudur. Her oyuncu kendi '
              'köşesinden başlar; kurduğu her kelimeyle puan toplar, '
              'bölgesini büyütür ve tahtanın merkezine doğru ilerleyerek '
              'üstünlük kurmaya çalışır.'),
          _P('İlk hamle bölgenin köşesinden başlar ama ondan sonraki hamleler '
              'tahtanın dilediğin herhangi bir yerine yapılabilir. Ancak '
              'önemli bir kural var: Eğer yaptığın hamle başka bir oyuncunun '
              'bölgesine temas ederse, kazandığın puanın üçte birini o '
              'oyuncuyla paylaşırsın. Bu nedenle en iyi strateji, mümkün '
              'olduğunca kendi bölgeni büyütürken rakiplerinin genişlemesini '
              'zorlaştıracak hamleler yapmaktır. Oyuncuların kontrol ettiği '
              'bölgeler kalın çizgilerle gösterilir. Hamlen herhangi bir '
              'oyuncunun bölgesine temas etmiyorsa puan paylaşımı olmaz ve '
              'kazandığın puanın tamamı sana kalır.'),
        ],
      ),
      const _Section(
        title: 'Temel Kurallar',
        children: [
          _P('**Başlangıç:** Her oyuncu tahtanın köşelerindeki 4×4\'lük '
              'bölgelere sahiptir. Köşelerdeki ev işaretli kare, o oyuncunun '
              'başlangıç noktasıdır.'),
          _P('**Bağlantı:** Her hamle, oyun tahtasındaki mevcut harflere '
              '(rakipler de dahil) yatay ya da dikey olarak bağlanmalıdır.'),
        ],
      ),
      const _Section(
        title: 'Bölge Vergisi',
        children: [
          _P('Her oyuncu 4×4\'lük kendi köşesinden başlar ve kelimeleri '
              'bağladıkça bölgesini büyütür. Tahta üzerinde güncel bölgeler '
              'her oyuncunun kendi renginde kalın çizgiyle belirlenmiştir.'),
          _P('İlk hamleden sonra rakibin bölgesine de taş koyabilirsin; ancak '
              'yerleştirdiğin harflerden herhangi biri rakibin bölgesine '
              'temas eder ya da içine yerleşirse, o hamleden kazandığın '
              'puanın 1/3\'ü bölge sahibine gider, 2/3\'ü sende kalır. Aynı '
              'hamle iki farklı rakip bölgesiyle birden etkileşirse puanın '
              'yarısı sende kalır, diğer yarısı rakipler arasında eşit '
              'paylaştırılır. 3 farklı bölge temasında ise 1/3 sende kalır, '
              '2/3 diğer 3 rakiple eşit paylaşılır.'),
          _P('Rakip bölgesine temas eden ama senin bölgene bağlı olmayan '
              'kelimeler sana vergi kazandırmaz. Ancak ilerleyen hamlelerde '
              'bu kelimeyi kendi bölgene bağlarsan artık bölgene dahil olur '
              've bundan sonra o kelime üzerinden vergi kazanmaya '
              'başlayabilirsin.'),
        ],
      ),
      const _Section(
        title: 'Bonus Bölgesi',
        children: [
          _Pill(
            label: 'X2',
            color: Color(0xFFFBBF24),
            desc: 'En ortadaki 5×5 sarı alanda yapılan kelime puanı ikiye '
                'katlanır',
          ),
          _Pill(
            label: 'X3',
            color: Color(0xFFF97316),
            desc: 'Tam merkezdeki tek karede yapılan kelime puanı üçe '
                'katlanır',
          ),
          _P('X2 ve X3 bonusları yalnızca o kare ilk kez kullanıldığında '
              'geçerlidir; daha önce kullanılmış karelere yapılan bağlantılar '
              'bonus kazandırmaz. X2 bölgesi içinde olmasına rağmen, X3 '
              'hücresi kullanıldığında ayrıca X2 eklenmez.'),
        ],
      ),
      const _Section(
        title: 'Hamle Seçenekleri',
        children: [
          _P('**Oyna:** Harf kutundan seçtiğin harfleri oyun tahtasına koy, '
              'kelimelerin geçerli olup olmadığını gör ve ardından "Oyna" '
              'düğmesine bas.'),
          _P('**Değiştir:** Harf kutundan istediğin taşları torbaya geri at, '
              'yerine yeni taş çek. Sıran sonraki oyuncuya geçer. Torba '
              'boşken değiştirme pasif olur.'),
          _P('**Pas Geç:** Sıranı kullanmadan pas geçmeni sağlar. Tüm '
              'oyuncular arka arkaya 2 tur pas geçerse oyun sona erer.'),
          _P('**Karıştır:** Harf kutundaki taşların yerlerini değiştirerek '
              'kelime bulmanı kolaylaştırır.'),
          _P('**Geri Al:** Oyun tahtasına koyup deneme yaptığın taşları '
              'kutuya geri alır.'),
          _P('**Torba:** Torbada kalan taş sayısını ve dışarıda kalan '
              'taşların dağılımını gösterir.'),
        ],
      ),
      _Section(
        title: 'Bingo Bonusu',
        children: [
          _P('Harf kutundaki 7 taşın tamamını tek hamlede kullanırsan '
              '**+$bingoBonus puan** bonus kazanırsın.'),
        ],
      ),
      _Section(
        titleWidget: Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              letterSpacing: 1.5,
              color: _accent,
            ),
            children: const [
              TextSpan(text: 'Joker ('),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.star, size: 14, color: _accent),
              ),
              TextSpan(text: ') Taşı'),
            ],
          ),
        ),
        children: const [
          _P('Torbada 2 adet joker bulunur. Joker taşı oynandığında istediğin '
              'herhangi bir Türkçe harfe dönüşebilir ve puan değeri **0**\'dır.'),
          _P('Oyun sonunda elinde kalan son taş joker ise ve onu yerleştirerek '
              'bitersen **+25 yıldız bonus** puan kazanırsın. 2 joker taş ile '
              'bitiş ise **+50 puan** kazandırır. Becerebilirsen jokerlerini '
              'en sona taşa bırak, bonusu kap.'),
        ],
      ),
      const _Section(
        title: 'Sözlük',
        children: [
          _P('Yalnızca Türkçe kelimeler geçerlidir ve sadece Türk Dil Kurumu '
              '(TDK) sözlüğünde yer alan kelimeler bulunur. TDK sözlüğünde '
              'olmayan ama bulmacalarda sık kullanılan bazı kelimeler '
              'eklenmiştir.'),
        ],
      ),
      const _Section(
        title: 'Oyunun Sonu',
        children: [
          _P('Bir oyuncu harf kutusundaki tüm harfleri yerleştirdiğinde ve '
              'torbada başka taş kalmadığında oyun biter. Oyun bittiğinde '
              'harf kutusunda taş kalan oyuncuların puanından o taşların '
              'toplam değeri düşülür. Ancak bu puanlar bitiren oyuncuya '
              'eklenmez.'),
          _P('Tüm oyuncular arka arkaya 2 tur boyunca pas geçerse de oyun '
              'sona erer. Bu durumda da tüm oyuncuların puanından elinde '
              'kalan taşların değeri düşer. En yüksek puana sahip oyuncu '
              'kazanır.'),
        ],
      ),
      const _Section(
        title: 'Skor Kartı ve Puanlama',
        children: [
          _P('Oyun oynamak için giriş yapman gerekmez. Sadece arkadaşınla '
              'canlı oyun, k-lig puanları ve oyun istatistikleri için giriş '
              'yapman gerekir. Giriş yapmış kullanıcıların oyun sonuçları '
              'Skor Kartı\'na kaydedilir. Oyun içi puanının yanında, '
              'sıralamana göre bir k-lig puanı da kazanırsın. 4 kişilik '
              'oyunda birinci bitirirsen **+2**, ikinci bitirirsen **+1** '
              'puan alırsın; üçüncü ve dördüncü puan almaz. 2 kişilik oyunda '
              'ise sadece birinci **+2** puan alır; ikinci puan almaz. '
              'Beraberlikte aynı sırayı paylaşan oyuncuların hepsi o sıranın '
              'puanını alır.'),
        ],
      ),
      const _Section(
        title: 'Puan Tablosu',
        children: [
          _P('Torbada oyuncu sayısından bağımsız olarak sabit toplam 100 taş '
              'bulunur. Aşağıdaki döküm bu değere göredir.'),
          _TileRow(pts: '1', tiles: [
            ('A', 12),
            ('E', 8),
            ('İ', 7),
            ('K', 7),
            ('L', 7),
            ('R', 6),
            ('N', 5),
            ('T', 5),
          ]),
          _TileRow(
              pts: '2',
              tiles: [('I', 4), ('M', 4), ('O', 3), ('S', 3), ('U', 3)]),
          _TileRow(
              pts: '3',
              tiles: [('B', 2), ('Ç', 2), ('D', 2), ('Ü', 2), ('Y', 2)]),
          _TileRow(pts: '4', tiles: [('C', 2), ('Ş', 2), ('Z', 2)]),
          _TileRow(pts: '5', tiles: [('G', 1), ('H', 1), ('P', 1)]),
          _TileRow(pts: '7', tiles: [('F', 1), ('Ö', 1), ('V', 1)]),
          _TileRow(pts: '8', tiles: [('Ğ', 1)]),
          _TileRow(pts: '10', tiles: [('J', 1)]),
          _TileRow(pts: '0', tiles: [('★', 2)], note: ' Joker'),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 20), // web gap-5
          sections[i],
        ],
      ],
    );
  }
}
