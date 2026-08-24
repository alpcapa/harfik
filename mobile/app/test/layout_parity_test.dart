// Web ↔ port ELLE SENKRON düzen sayıları — web KANONİK kaynaktır.
//
// NEDEN VAR (21 Ağustos 2026): kullanıcı sordu — *"Web ve app her konuda
// paralel değil mi? Her seferinde o eksik bu diyip duruyorsun. Emin ol."*
// Ölçüldü ve o an hepsi tutuyordu, ama pariteyi KORUYAN bir mekanizma
// yoktu: bugüne kadar yalnızca BEŞ web dosyası (HelpModal, Terms/Privacy,
// offlineNotice, leagueRank) ve golden vector'lar zorlanıyordu. Aşağıdaki
// sayılar dokümanda "ELLE SENKRON, zorlayan test YOK" diye işaretliydi —
// yani web'de biri değişip portta değişmese hiçbir şey uyarmazdı.
//
// Bu test o boşluğu kapatıyor: her iki KAYNAK dosyayı okuyup sayıları
// karşılaştırıyor (`rank_tiers_parity_test.dart` ile aynı desen).
//
// ⚠ EN ÖNEMLİ KURAL: bir değer BULUNAMAZSA test DÜŞER, geçmez. Kaynak
// yeniden yazıldığında regex'in sessizce hiçbir şey eşleştirmemesi, bu tür
// testleri "yeşil ama hiçbir şey kanıtlamıyor" hâline getiren klasik
// hatadır — `_pick`/`_pickAll` bu yüzden her çağrıda varlık iddia ediyor.
//
// KAPSAM DIŞI (dürüst sınır):
//  - `TESLIM_FONT_SIZE`in KENDİSİ: portta akıcı bir karşılığı YOK, orada
//    FittedBox ile sığdırılıyor (bilinçli, bkz. GameHeader notu). Sayı
//    karşılaştırmak yanlış bir eşdeğerlik iddiası olurdu — onun yerine
//    ALTINDAKİ DEĞİŞMEZ kilitlendi (son test: teslim satırı skor satırıyla
//    aynı yükseklikte).
//  - Renk/metin/ikon paritesi: renkler `color_tokens_test`, metinler
//    `help_text_parity`/`legal_text`/`offline_notice` testlerinde.
//
// ⚠ REGEX TUZAĞI (CI 21 Ağustos 2026'da yakaladı): Dart'ın regex semantiği
// V8'e yakın, Python'a DEĞİL. `\w` Dart'ta yalnızca ASCII eşler; Python'da
// Unicode farkındadır. Bu yüzden `'ÇŞ'`yi `(\w+)` ile çekmek Python
// prototipinde ÇALIŞTI, Dart'ta HİÇ eşleşmedi ve test düştü. Kural: Türkçe
// harf içerebilecek bir yeri yakalarken `\w` KULLANMA, `[^']+` gibi açık bir
// sınıf kullan — ve prototipi Python'da değil node'da (V8) koştur.
import 'package:flutter_test/flutter_test.dart';

import 'support/web_source.dart';

List<double> _webClamp(String src, String name, String file) {
  final body = pick(
      src,
      RegExp("const $name = '(clamp\\([^']+\\))'"),
      '$file içinde $name');
  final m = RegExp(
          r'clamp\(\s*(-?[\d.]+)px,\s*calc\(\s*(-?[\d.]+)px\s*\+\s*(-?[\d.]+)vw\s*\),\s*(-?[\d.]+)px\s*\)')
      .firstMatch(body);
  expect(m, isNotNull, reason: '$name clamp biçimi tanınmadı: $body');
  return [for (var i = 1; i <= 4; i++) double.parse(m!.group(i)!)];
}

/// Dart `final <ad> = fluidSize(<genişlik>, MIN, A, B, MAX);`
List<double> _dartFluid(String src, String name, String file) {
  final m = RegExp(
          '$name = fluidSize\\(\\w+, (-?[\\d.]+), (-?[\\d.]+), (-?[\\d.]+), (-?[\\d.]+)\\)')
      .firstMatch(src);
  expect(m, isNotNull, reason: '$file içinde `$name = fluidSize(...)` bulunamadı');
  return [for (var i = 1; i <= 4; i++) double.parse(m!.group(i)!)];
}

void main() {
  test('GameHeader/UserMenu akıcı sabitleri (375-465 clamp ailesi)', () {
    final webHeader = readRepoFile('src/components/GameHeader.tsx');
    final webMenu = readRepoFile('src/components/UserMenu.tsx');
    final port = readRepoFile('mobile/app/lib/src/ui/game/game_header.dart');

    // web sabiti → (web dosyası, port değişkeni)
    const ciftler = <String, List<String>>{
      'PLAYER_BOX_WIDTH': ['header', 'playerBoxWidth'],
      'YZ_BOX_WIDTH': ['header', 'yzBoxWidth'],
      'LABEL_FONT_SIZE': ['header', 'labelFontSize'],
      'SCORE_FONT_SIZE': ['header', 'scoreFontSize'],
      'BOX_PADDING_X': ['header', 'boxPaddingX'],
      'BOX_GAP': ['header', 'boxGap'],
      'BOX_PADDING_Y': ['header', 'boxPaddingY'],
      'LOGO_HEIGHT': ['header', 'logoHeight'],
      // GİRİŞ butonu skor kutularıyla AYNI akıcı sistemde büyüyor; web'de
      // UserMenu.tsx'te, portta aynı GameHeader build'inde hesaplanıyor.
      'GIRIS_FONT_SIZE': ['menu', 'girisFontSize'],
      'GIRIS_PADDING_X': ['menu', 'girisPaddingX'],
      'GIRIS_PADDING_Y': ['menu', 'girisPaddingY'],
    };

    for (final e in ciftler.entries) {
      final webSrc = e.value[0] == 'header' ? webHeader : webMenu;
      final webFile =
          e.value[0] == 'header' ? 'GameHeader.tsx' : 'UserMenu.tsx';
      expect(_dartFluid(port, e.value[1], 'game_header.dart'),
          _webClamp(webSrc, e.key, webFile),
          reason: '${e.key} ↔ ${e.value[1]} ayrışmış');
    }
  });

  test('Board filigranları (köşe rakamı / X2 / X3)', () {
    // Üçü de `calc()`SIZ clamp: `clamp(MIN px, B vw, MAX px)` → portta A = 0.
    //
    // ⚠ "Board.tsx'teki TÜM clamp'leri topla, üç tane olmalı" YANLIŞ olurdu
    // (ilk sürüm tam bunu yapıyordu ve ölçümde düştü): dosyada bu üçünün
    // dışında İKİ clamp daha var — hücrenin taban puntosu ve "+puan" rozeti —
    // ve ikisinin portta akıcı bir karşılığı YOK. Bu yüzden her filigran,
    // ÇİZDİĞİ ŞEYE çapalanarak tek tek eşleştiriliyor.
    final web = readRepoFile('src/components/Board.tsx');
    final port = readRepoFile('mobile/app/lib/src/ui/game/board_widget.dart');

    const capalar = <String, List<String>>{
      'köşe rakamı': [
        r"fontSize: 'clamp\(([^']+)\)',\s*\}\}\s*>\s*\{num\}",
        r'cornerFont = fluidSize\(screenWidth, ([^)]+)\)',
      ],
      'X2 filigranı': [
        r"fontSize: 'clamp\(([^']+)\)',\s*\}\}\s*>\s*X2",
        r'zoneFont = fluidSize\(screenWidth, ([^)]+)\)',
      ],
      'X3 etiketi': [
        r"CENTER_TEXT, 'text-\[clamp\(([^\]]+)\)\]'",
        r"'X3',.*?fluidSize\(screenWidth, ([^)]+)\)",
      ],
    };

    for (final e in capalar.entries) {
      final w = pick(web, RegExp(e.value[0], dotAll: true),
              'Board.tsx ${e.key} clamp\'i')
          .replaceAll(RegExp(r'[a-z\s]'), '')
          .split(',')
          .map(double.parse)
          .toList();
      final p = pick(port, RegExp(e.value[1], dotAll: true),
              'board_widget.dart ${e.key} fluidSize\'ı')
          .replaceAll(' ', '')
          .split(',')
          .map(double.parse)
          .toList();
      expect(p, hasLength(4), reason: '${e.key}: fluidSize dört sayı almalı');
      expect(p[1], 0,
          reason: '${e.key}: web clamp\'inde calc() yok, A = 0 olmalı');
      expect([p[0], p[2], p[3]], w, reason: '${e.key} ayrışmış');
    }
  });

  test('GameOver sağ blok sütun genişlikleri', () {
    final web = readRepoFile('src/components/GameOver.tsx');
    final port = readRepoFile('mobile/app/lib/src/ui/game/game_over_modal.dart');

    // Tailwind boşluk birimi 4px: `w-5` = 20px.
    int webKalan = int.parse(
        pick(web, RegExp(r'w-\[(\d+)px\][^"]*">Kalan<'), 'GameOver "Kalan"'));
    int webToplam = int.parse(pick(
        web, RegExp(r'w-\[(\d+)px\][^"]*">Toplam<'), 'GameOver "Toplam"'));
    int webKlig = int.parse(
            pick(web, RegExp(r'w-(\d+)[^"]*">k-lig<'), 'GameOver "k-lig"')) *
        4;

    int portu(String etiket) => int.parse(pick(
        port,
        RegExp("_ColHeader\\('$etiket', width: (\\d+)\\)"),
        'game_over_modal.dart _ColHeader($etiket)'));

    expect(portu('KALAN'), webKalan, reason: 'Kalan sütunu ayrışmış');
    expect(portu('TOPLAM'), webToplam, reason: 'Toplam sütunu ayrışmış');
    expect(portu('k-lig'), webKlig, reason: 'k-lig sütunu ayrışmış');
  });

  test('k-lig listesi OHP sütun genişliği', () {
    final web = int.parse(pick(readRepoFile('src/components/Leaderboard.tsx'),
        RegExp(r'w-\[(\d+)px\]'), 'Leaderboard.tsx OHP sütunu'));
    final port = int.parse(pick(
        readRepoFile('mobile/app/lib/src/ui/score/leaderboard_modal.dart'),
        RegExp(r'_kOhpColumnWidth = (\d+)'),
        'leaderboard_modal.dart _kOhpColumnWidth'));
    expect(port, web);
  });

  test('Canlı liste dayanıklılığı: tekrar gecikmeleri + merdiven + '
      'çevrimdışı doğrulama', () {
    // 1) Ağ-özel tekrar (ms)
    final webRetry = pick(readRepoFile('src/lib/api.ts'),
            RegExp(r'RETRY_DELAYS_MS = \[([\d, ]+)\]'), 'api.ts RETRY_DELAYS_MS')
        .split(',')
        .map((s) => int.parse(s.trim()))
        .toList();
    final portApi = readRepoFile('mobile/app/lib/src/data/online_games_api.dart');
    final retryBlok = pick(portApi,
        RegExp(r'retryDelays = \[(.*?)\];', dotAll: true), 'retryDelays bloğu');
    final portRetry = pickAll(retryBlok, RegExp(r'milliseconds: (\d+)'),
            'retryDelays içindeki milliseconds')
        .map(int.parse)
        .toList();
    expect(portRetry, webRetry, reason: 'tekrar gecikmeleri ayrışmış');

    // 2) Otomatik merdiven (web ms, port saniye)
    final webLadder = pick(
            readRepoFile('src/components/LiveGamesTab.tsx'),
            RegExp(r'AUTO_RETRY_STEPS_MS = \[([\d, ]+)\]'),
            'LiveGamesTab.tsx AUTO_RETRY_STEPS_MS')
        .split(',')
        .map((s) => int.parse(s.trim()))
        .toList();
    final portTab = readRepoFile('mobile/app/lib/src/ui/live/live_games_tab.dart');
    final ladderBlok = pick(portTab,
        RegExp(r'autoRetrySteps = \[(.*?)\];', dotAll: true), 'autoRetrySteps bloğu');
    final portLadder = pickAll(
            ladderBlok, RegExp(r'seconds: (\d+)'), 'autoRetrySteps içindeki seconds')
        .map((s) => int.parse(s) * 1000)
        .toList();
    expect(portLadder, webLadder, reason: 'otomatik merdiven ayrışmış');

    // 3) Çevrimdışıya geçişin doğrulanma süresi
    final webConfirm = int.parse(pick(readRepoFile('src/hooks/useOnlineStatus.ts'),
        RegExp(r'OFFLINE_CONFIRM_MS = (\d+)'), 'useOnlineStatus OFFLINE_CONFIRM_MS'));
    final portConfirm = int.parse(pick(
        readRepoFile('mobile/app/lib/src/util/online_status.dart'),
        RegExp(r'kOfflineConfirmDelay = Duration\(milliseconds: (\d+)\)'),
        'online_status.dart kOfflineConfirmDelay'));
    expect(portConfirm, webConfirm, reason: 'çevrimdışı doğrulama süresi ayrışmış');
  });

  test('"← Geri" etiketi: punto ve logoyla arası', () {
    final web = readRepoFile('src/components/GameHeader.tsx');
    final port = readRepoFile('mobile/app/lib/src/ui/game/game_header.dart');
    expect(
        int.parse(pick(port, RegExp(r'kBackFontSize = (\d+)'), 'kBackFontSize')),
        int.parse(
            pick(web, RegExp(r"BACK_FONT_SIZE = '(\d+)px'"), 'BACK_FONT_SIZE')),
        reason: 'etiket puntosu ayrışmış');
    expect(int.parse(pick(port, RegExp(r'kBackGap = (\d+)'), 'kBackGap')),
        int.parse(pick(web, RegExp(r'BACK_GAP = (\d+)'), 'BACK_GAP')),
        reason: 'logo↔etiket boşluğu ayrışmış');
  });

  test('RankSeal geometrisi + punto merdiveni', () {
    // İki dosya AYNI sabit setini taşıyor ve dokümanda "ELLE senkron"
    // işaretliydi. Rozet bir SVG ↔ CustomPainter çifti olduğundan geometriyi
    // birebir karşılaştırmak mümkün: viewBox aynı (44), sayılar aynı ada
    // sahip.
    final web = readRepoFile('src/components/RankSeal.tsx');
    final port = readRepoFile('mobile/app/lib/src/ui/rank/rank_seal.dart');

    const ciftler = <String, String>{
      'CY': 'kSealCy',
      'TIP_R': 'kSealTipR',
      'VALLEY_R': 'kSealValleyR',
      'LOBES': 'kSealLobes',
      'EDGE_W': 'kSealEdgeW',
      'RING_R': 'kSealRingR',
      'RING_W': 'kSealRingW',
      'TAIL_TOP': '_kTailTop',
      'TAIL_BOTTOM': '_kTailBottom',
      'TAIL_W': '_kTailW',
      'TAIL_SPLAY': '_kTailSplay',
      'TAIL_NOTCH': '_kTailNotch',
      'TAIL_INNER_X': '_kTailInnerX',
      'INK_ASC_EM': 'kSealInkAscEm',
      'DESCENDER_EM': 'kSealDescenderEm',
    };
    ciftler.forEach((w, d) {
      final a = double.parse(
          pick(web, RegExp('const $w = ([\\d.]+);'), 'RankSeal.tsx $w'));
      final b = double.parse(pick(port,
          RegExp('const (?:double|int) $d = ([\\d.]+);'), 'rank_seal.dart $d'));
      expect(b, a, reason: '$w ↔ $d ayrışmış');
    });

    // Kurdele rengi: kademe renginin bir tık koyusu — katsayı iki tarafta da
    // aynı olmalı, yoksa kurdele sessizce farklı tonda çizilir.
    final katsayi = double.parse(pick(web,
        RegExp(r'function darken\(hex: string, f = ([\d.]+)\)'),
        'RankSeal.tsx darken katsayısı'));
    final portKatsayilari = pickAll(port, RegExp(r'\* 255 \* ([\d.]+)\)'),
            'rank_seal.dart darken katsayıları')
        .map(double.parse)
        .toSet();
    expect(portKatsayilari, {katsayi},
        reason: 'kurdele koyulaştırma katsayısı ayrışmış');

    // Kompakt eşiği: bunun altında iç halka çizilmez, harf büyütülür.
    expect(
        double.parse(pick(
            port,
            RegExp(r'sealIsCompact\(double size\) => size < ([\d.]+);'),
            'rank_seal.dart sealIsCompact eşiği')),
        double.parse(pick(web, RegExp(r'const compact = size < ([\d.]+);'),
            'RankSeal.tsx compact eşiği')),
        reason: 'kompakt eşiği ayrışmış');

    // Punto merdiveni: ÖLÇÜLMÜŞ tavanlar (harf madalyonun dışına taşmasın).
    // Gövdedeki sayılar SIRAYLA karşılaştırılıyor — eşik ve punto birlikte.
    List<double> merdiven(String src, RegExp bas, String ne) {
      final govde = pick(src, bas, ne);
      return pickAll(govde, RegExp(r'(?<![\w.])(\d+(?:\.\d+)?)'), '$ne sayıları')
          .map(double.parse)
          .toList();
    }

    expect(
        merdiven(
            port,
            RegExp(
                r'double sealFontSize\(String text, \{required bool compact\}\) \{(.*?)\n\}',
                dotAll: true),
            'rank_seal.dart sealFontSize'),
        merdiven(
            web,
            RegExp(
                r'function fontSizeFor\(text: string, compact: boolean\) \{(.*?)\n\}',
                dotAll: true),
            'RankSeal.tsx fontSizeFor'),
        reason: 'punto merdiveni ayrışmış');

    // Taban çizgisi düzeltmesi yalnızca sedillalı harflerde uygulanır.
    expect(
        // ⚠ `\w` KULLANMA: Dart'ta (V8 gibi) yalnızca ASCII eşler, yani
        // `ÇŞ` HİÇ eşleşmez. Python'ın `\w`si Unicode farkında olduğundan
        // prototip bunu göremedi ve CI yakaladı (bkz. dosya başlığı).
        pick(port, RegExp(r"kSealDescenderChars = '([^']+)';"),
            'rank_seal.dart kSealDescenderChars'),
        pick(web, RegExp(r'const DESCENDER_CHARS = /\[([^\]]+)\]/;'),
            'RankSeal.tsx DESCENDER_CHARS'),
        reason: 'sedillalı harf listesi ayrışmış');
  });

  test('teslim satırı skor satırıyla AYNI yükseklikte (iki tarafta da)', () {
    // Burada karşılaştırılacak bir SAYI çifti YOK ve olamaz: web akıcı bir
    // `TESLIM_FONT_SIZE` clamp'i kullanırken port metni `FittedBox` ile
    // sığdırıyor. Ortak olan şey DEĞİŞMEZ — teslim kutusu diğerleriyle aynı
    // boyda kalmalı (6 Ağustos 2026 kararı; öncesinde ~10px kısa duruyordu).
    //
    // Web bunu satır yüksekliğini skor puntosuna eşitleyerek, port da o
    // puntoda sabit bir `SizedBox` ile sağlıyor. İkisi de KAYNAKTA
    // doğrulanabilir; biri sabit bir sayıya çevrilirse kutular ayrışır.
    expect(
        pick(
            readRepoFile('src/components/GameHeader.tsx'),
            RegExp(r'fontSize: TESLIM_FONT_SIZE,\s*lineHeight: (\w+),'),
            'GameHeader.tsx teslim satırının lineHeight\'i'),
        'SCORE_FONT_SIZE',
        reason: 'web teslim satırı artık skor puntosuna bağlı değil');

    expect(
        pick(
            readRepoFile('mobile/app/lib/src/ui/game/game_header.dart'),
            RegExp(r'SizedBox\(\s*height: (\w+),.*?TESLİM', dotAll: true),
            'game_header.dart teslim satırını saran SizedBox yüksekliği'),
        'scoreFontSize',
        reason: 'port teslim satırı artık skor puntosuna bağlı değil');
  });

  test('sürükleme eşiği: fare/parmak ayrımı iki tarafta da AYNI', () {
    // 22 Ağustos 2026 — tek eşik (6px) dokunmatikte sessiz kayıp üretiyordu:
    // parmak 6px oynayan bir dokunuş "sürükleme" sayılıp aynı hücrede
    // bittiğinden hiçbir şey olmuyordu. Değerler ELLE SENKRON (web kanonik)
    // ve DÖRT dosyada birden yaşıyor — biri unutulursa iki ekran ya da iki
    // platform sessizce ayrışır, bu test tam onu yakalıyor.
    const webFiles = ['src/App.tsx', 'src/components/OnlineGameScreen.tsx'];
    const dartFiles = [
      'mobile/app/lib/src/ui/game/game_screen.dart',
      'mobile/app/lib/src/ui/live/online_game_screen.dart',
    ];

    for (final f in webFiles) {
      final src = readRepoFile(f);
      expect(pick(src, RegExp(r'const DRAG_THRESHOLD_MOUSE = ([\d.]+);'),
              '$f DRAG_THRESHOLD_MOUSE'),
          '6');
      expect(pick(src, RegExp(r'const DRAG_THRESHOLD_TOUCH = ([\d.]+);'),
              '$f DRAG_THRESHOLD_TOUCH'),
          '10');
      // Eşik SABİTİ doğru olsa bile kullanılmıyorsa değeri yok: hangi eşiğin
      // seçileceği pointer TÜRÜNE bağlı olmak zorunda.
      expect(
          pick(src, RegExp(r'if \(dist < (dragThresholdFor\(e\.pointerType\))\) return;'),
              '$f eşik karşılaştırması pointerType\'a bağlı değil'),
          'dragThresholdFor(e.pointerType)');
    }

    for (final f in dartFiles) {
      final src = readRepoFile(f);
      expect(pick(src, RegExp(r'_dragThresholdMouse = ([\d.]+);'),
              '$f _dragThresholdMouse'),
          '6');
      expect(pick(src, RegExp(r'_dragThresholdTouch = ([\d.]+);'),
              '$f _dragThresholdTouch'),
          '10');
      expect(
          pick(src, RegExp(r'distance < (_dragThresholdFor\(e\.kind\))\) return;'),
              '$f eşik karşılaştırması pointer türüne bağlı değil'),
          '_dragThresholdFor(e.kind)');
    }
  });

  test('alt şerit: dikey dolgu KABINDA değil BEŞ öğenin de üzerinde', () {
    // 24 Ağustos 2026 — kullanıcı cihazda bildirdi: *"board altındaki
    // hamleler, mesajlar ve nasıl oynanır linkleri tıklayınca hemen
    // açılmıyorlar. Kaç defa basmam gerekti."* Kök sebep 22 Ağustos jest
    // denetiminde ZATEN ölçülüp bilinçli olarak ertelenmişti: dolgu KABIN
    // üzerindeydi, dokunma hedefleri 18px kalıyordu (WCAG 2.2 asgarisi 24).
    // Dolgu her ÖĞEYE taşındı — şeridin DIŞ ölçüsü (4 + 18 + 10 = 32)
    // değişmiyor, hedefler 18 → 32 çıkıyor. Ölçüldü (390px, çevrimiçi):
    // Hamleler 1418 → 2521 px², Nasıl Oynanır? 2265 → 4027 px².
    //
    // Bu test tam olarak GERİ ALINMAYI yakalıyor: dolgu kaba geri konursa
    // hedefler sessizce 18'e döner ve hiçbir widget testi fark etmez.
    const web = 'src/components/Board.tsx';
    const dart = 'mobile/app/lib/src/ui/game/board_widget.dart';
    final w = readRepoFile(web);
    final d = readRepoFile(dart);

    // 1) Kap YALNIZCA yatay dolgu taşır.
    expect(
        pick(
            w,
            RegExp(r'z-10 flex items-center justify-between gap-2 shrink-0 '
                r'(px-\[10px\]) w-full'),
            '$web alt şerit kabı — dikey dolgu hâlâ KAPTA mı?'),
        'px-[10px]');
    expect(
        pick(d, RegExp(r'padding: const (EdgeInsets\.symmetric\(horizontal: 10\))'),
            '$dart alt şerit kabı yalnızca yatay dolgu taşımıyor'),
        'EdgeInsets.symmetric(horizontal: 10)');

    // 2) Ortak öğe dolgusu iki tarafta AYNI: üst 4 (pt-1), alt 10.
    expect(
        pick(d, RegExp(r'_footerItemPadding =\s*(EdgeInsets\.only\(top: 4, bottom: 10\))'),
            '$dart _footerItemPadding tanımı'),
        'EdgeInsets.only(top: 4, bottom: 10)');

    // 3) BEŞ öğenin de taşıması ŞART — yalnızca dokunulabilirler büyürse
    //    ayraç ve "Çevrimdışı" 32px'lik satırda ortalanıp ~3px kayar.
    expect(RegExp(r'pt-1 pb-\[10px\]').allMatches(w).length, 5,
        reason: '$web: alt şeritteki BEŞ öğenin de `pt-1 pb-[10px]` '
            'taşıması gerekiyor (Hamleler · ayraç · Mesajlaşma · '
            'Çevrimdışı · Nasıl Oynanır?)');
    final dartDikey = RegExp(r'padding: _footerItemPadding').allMatches(d).length +
        RegExp(r'EdgeInsets\.fromLTRB\(\d+, 4, \d+, 10\)').allMatches(d).length;
    expect(dartDikey, 5,
        reason: '$dart: alt şeritteki BEŞ öğenin de 4/10 dikey dolgu '
            'taşıması gerekiyor');

    // 4) Rozet METİN kutusuna çapalı kalmalı: web'de `relative` iç span'de,
    //    portta Padding Stack'in DIŞINDA. Dolgulu kutuya çapalanırsa
    //    `-top-1` 4px aşağı kayar.
    expect(
        pick(w, RegExp(r'<span className="(relative flex items-center gap-1)">'),
            '$web: rozetin çapası iç `relative` span değil'),
        'relative flex items-center gap-1');
    expect(
        pick(d, RegExp(r'child: Padding\(\s*padding: _footerItemPadding,\s*child: (Stack)\('),
            '$dart: Padding Stack\'in DIŞINDA değil'),
        'Stack');
  });
}
