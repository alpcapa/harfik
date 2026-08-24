// Dokunma hedefi ÖLÇÜMÜ — kaynak deseni değil, EKRANDAKİ kutu.
//
// NEDEN VAR (24 Ağustos 2026): kullanıcı cihazda arka arkaya beş kontrol
// bildirdi ve hepsi aynı cümleyle: *"biraz üstüne basınca çalışıyor"* —
// alt şerit linkleri, "Detaylı Kurallar", "← Geri", avatar. Alt şerit için
// bir gün önce bir düzeltme çıkılmıştı ama **portta ekrandaki kutu hiç
// ölçülmemişti**: `layout_parity_test.dart` yalnızca KAYNAKTA dolgunun
// durduğunu doğruluyor, render edilen boyutu değil. Kullanıcı düzeltmeden
// sonra da aynı şikayeti bildirince bu boşluk görünür oldu.
//
// KÜRESEL BİR KAYMA DEĞİL: eğer dokunuş koordinatları topluca kaysaydı taş
// sürükleme de bozulurdu (tahta hücreleri 390px'te ~24px) — kullanıcı taş
// koyup OYNA'ya basabiliyor. Yani sorun tek tek hedeflerin KÜÇÜKLÜĞÜ.
//
// İLK TURDA (ölçüm turu) iddia YOKTU, yalnızca sayı basılıyordu:
//   alt şerit: Hamleler         78.8 × 31.0
//   alt şerit: Mesajlaşma       94.4 × 31.0
//   alt şerit: Nasıl Oynanır?  125.8 × 31.0
//   başlık: ← Geri              90.8 × 29.3
//   yardım: Detaylı Kurallar   128.2 × 14.0
// Beşi de 48'in altındaydı. Düzeltmeden sonra bu dosya artık İDDİA ediyor.
//
// ⚠ ÖLÇÜM ÜST SINIRDIR: widget'lar burada İZOLE render ediliyor. `< 48`
// çıkması hedefin küçük olduğunu KANITLAR; `>= 48` çıkması gerçek ekranda
// da öyle olduğunu kanıtlamaz (bir ata kırpabilir/daraltabilir). Bir hedef
// bilinçli olarak küçük kalacaksa buraya GEREKÇESİYLE bir istisna yazılır —
// sessizce küçülmesi engellenir.
//
// BUGÜNKÜ İSTİSNALAR (ikisinin de gerekçesi kendi dosyasında yazılı):
//   * `auth/legal_modals.dart` → akan paragrafın İÇİNDEKİ "Görüş Bildir
//     formu" linki (`WidgetSpan`): büyütmek satır yüksekliğini bozar.
//   * `chat/chat_thread.dart` → mesaj başlığındaki 9 puntoluk sessize
//     alma/raporlama rozeti: HER baloncukta olduğundan sohbeti şişirirdi;
//     aynı panele pencere başlığındaki dişliden de ulaşılıyor.
//   * `game/game_header.dart` → "← Geri" etiketi 48 GENİŞ ama 24 YÜKSEK:
//     header ile tahta arasında duruyor, 48 oraya 20 px'lik boş bir bant
//     açardı; hemen üstündeki logo aynı eylem için tam boy hedef.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/auth/k_avatar.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/game_header.dart';
import 'package:kelimeki/src/ui/game/help_modal.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/tap_target.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';
import 'support/web_source.dart';

/// Kutusuna hiçbir ÖLÇÜ vermeyen dokunulabilirler — her biri GEREKÇELİ.
/// Yeni bir tanesi çıkarsa test düşer; ya `TapTarget`e alınır ya buraya
/// gerekçesiyle yazılır.
///
/// ⚠ NEDEN VAR (24 Ağustos 2026, ÜÇÜNCÜ tur): ilk taramam
/// "GestureDetector'ın DOĞRUDAN çocuğu `Text` mi" diye bakıyordu ve
/// Setup'ın footer'ındaki "Paylaş" linki (çocuğu ikon+metin taşıyan bir
/// `Row`) gözden kaçtı — kullanıcı Android'de tekrar bildirdi. Ders: tarama
/// çocuğun TÜRÜNE değil, kutuya bir ölçü veren bir şey olup olmadığına
/// bakmalı; ve elle koşulan bir tarama bir daha koşulmaz — teste girmeli.
const Map<String, String> _olcusuzIstisnalar = {
  'auth/auth_modal.dart': 'onay kutusu satırı — boyu çok satırlı etiketten',
  'auth/legal_modals.dart': 'akan paragrafın İÇİNDEKİ link (WidgetSpan)',
  'chat/chat_thread.dart': 'her baloncuktaki 9 puntoluk moderasyon rozeti',
  'friends/friends_modal.dart': 'liste satırı — boyu avatardan',
  'game/board_widget.dart': 'tahta hücresi — ızgara ölçüsü kuralın kendisi',
  'game/neo_button.dart': 'kendi dolgulu kutusunu çizen buton',
  'game/rack_widget.dart': 'raf taşı — boyu taşın kendisi',
  'rank/rank_header_seal.dart': 'başlıktaki 34 px mühür; bilgi kısayolu',
  'score/game_history_modal.dart': 'liste satırı, tahta önizlemesi ve '
      'hamle ikonu (Parça 65: 44 px bilinçli reddedildi)',
  'score/leaderboard_modal.dart': 'ipucunu kapatan tam alan bariyeri',
  'tap_target.dart': 'çözümün kendisi',
};

User _user() => User(
      id: 'u-test',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'alp.capa@hotmail.com',
    );

const _profile = KProfile(id: 'u-test', displayName: 'Ironman');

Player _player(String name, {required bool isAI, required int index}) => Player(
      name: name,
      corners: cornersFor(2)[index],
      colorIndex: index,
      isAI: isAI,
      surrendered: false,
      rack: const [],
      score: 0,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState _state() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: const [],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        _player('Ben', isAI: false, index: 0),
        _player('Rakip', isAI: false, index: 1),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 5,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

/// Bir metnin/ikonun İÇİNDE bulunduğu dokunulabilirin gerçek kutusu.
/// `GestureDetector` bulunamazsa `InkWell`e düşer; ikisi de yoksa test
/// SESSİZCE geçmesin diye düşer.
Size _tapBox(WidgetTester t, Finder inner, String label) {
  // EN YAKIN ata — türe göre önceliklendirme DEĞİL: `find.ancestor` içten
  // dışa sıralı döndüğünden `.first` gerçekten dokunuşu ilk yakalayan
  // kutudur. (Önceden önce tüm GestureDetector'lara, sonra InkWell'lere
  // bakılıyordu; avatar gibi InkWell ile sarılı bir hedefte bu, ÇOK daha
  // yukarıdaki alakasız bir GestureDetector'ı ölçme riski taşıyordu.)
  final f = find.ancestor(
    of: inner,
    matching: find.byWidgetPredicate((w) => w is GestureDetector || w is InkWell),
  );
  if (f.evaluate().isNotEmpty) return t.getSize(f.first);
  fail('$label: çevresinde GestureDetector/InkWell YOK — '
      'ayrıştırıcı bayatlamış olabilir, sessizce geçmesin diye düşürüldü');
}

final List<String> _rapor = [];

/// [minHeight] yalnızca GEREKÇELİ istisnalarda düşürülür (bkz. başlık).
void _olc(WidgetTester t, Finder inner, String label,
    {double minHeight = kMinTapTarget}) {
  final s = _tapBox(t, inner, label);
  final kucuk = s.height < minHeight || s.width < kMinTapTarget;
  _rapor.add('  ${label.padRight(28)} ${s.width.toStringAsFixed(1)} × '
      '${s.height.toStringAsFixed(1)}  (alan ${(s.width * s.height).round()} px²)'
      '${kucuk ? '   ← ASGARİNİN ALTINDA' : ''}');
  expect(s.height, greaterThanOrEqualTo(minHeight),
      reason: '$label: dokunma kutusunun YÜKSEKLİĞİ asgarinin altında — '
          'kullanıcı "biraz üstüne basınca çalışıyor" diye bildiren hata '
          'sınıfı tam olarak budur');
  expect(s.width, greaterThanOrEqualTo(kMinTapTarget),
      reason: '$label: dokunma kutusunun GENİŞLİĞİ Material asgarisinin '
          'altında');
}

void main() {
  setUpAll(() async {
    await loadRobotoIfAvailable();
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== DOKUNMA HEDEFİ ÖLÇÜMLERİ (390×844) ===\n${_rapor.join('\n')}\n');
  });

  // Widget testi DEĞİL: ekranı olmayan yüzeyleri de kapsayan kaynak
  // taraması. Bir dokunulabiliri kutusuz bırakmak, onu ölçmeyi hiç akla
  // getirmediğimiz anlamına gelir — asıl kaçış yolu bu.
  test('kutusuna ölçü vermeyen yeni bir dokunulabilir eklenmemiş', () {
    final kok = Directory('${repoRoot.path}/mobile/app/lib/src/ui');
    final olcuVeren = RegExp(r'padding:|SizedBox\(\s*(height|width)|\bwidth:'
        r'|\bheight:|minHeight|TapTarget|NeoBox|NeoButton|Container\('
        r'|IconButton|constraints:');
    final bulunan = <String>[];
    for (final f in kok
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      final rel = f.path.split('lib/src/ui/').last;
      for (final m in RegExp(r'\b(GestureDetector|InkWell)\(').allMatches(src)) {
        final seg = src.substring(
            m.start, m.start + 700 > src.length ? src.length : m.start + 700);
        if (!seg.substring(0, seg.length < 200 ? seg.length : 200)
            .contains('onTap')) continue;
        if (olcuVeren.hasMatch(seg)) continue;
        if (_olcusuzIstisnalar.containsKey(rel)) continue;
        bulunan.add('$rel:${'\n'.allMatches(src.substring(0, m.start)).length + 1}');
      }
    }
    expect(bulunan, isEmpty,
        reason: 'Kutusuna hiçbir ölçü vermeyen dokunulabilir(ler): '
            '${bulunan.join(', ')}. Ya `TapTarget`e al ya da '
            '`_olcusuzIstisnalar`a GEREKÇESİYLE ekle.');
  });

  testWidgets('alt şerit linkleri', (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: BoardWidget(
          state: _state(),
          onOpenHistory: () {},
          onOpenMessaging: () {},
          onOpenHelp: () {},
        ),
      ),
    ));
    await tester.pump();

    _olc(tester, find.text('Hamleler'), 'alt şerit: Hamleler');
    _olc(tester, find.text('Mesajlaşma'), 'alt şerit: Mesajlaşma');
    _olc(tester, find.text('Nasıl Oynanır?'), 'alt şerit: Nasıl Oynanır?');
  });

  testWidgets('oyun başlığı: ← Geri (girişsiz — GİRİŞ butonu)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: GameHeader(
            state: _state(), onLogoTap: () {}, auth: AuthService.fake()),
      ),
    ));
    await tester.pump();

    _olc(tester, find.byType(LogoMark), 'başlık: logo');
    // ⚠ GEREKÇELİ İSTİSNA — 48 değil 24 (WCAG 2.2 asgarisi): etiket header
    // satırının ALTINDA, tahtayla arasındaki boşlukta duruyor; 48'lik bir
    // yükseklik oraya 20 px'lik boş bir bant açardı. Aynı eylem için hemen
    // üstündeki logo zaten tam boy bir hedef (yukarıda ölçülüyor).
    _olc(tester, find.text('← Geri'), 'başlık: ← Geri', minHeight: 24);
    _olc(tester, find.text('GİRİŞ'), 'başlık: GİRİŞ');
  });

  testWidgets('oyun başlığı: avatar (girişli)', (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: GameHeader(
          state: _state(),
          onLogoTap: () {},
          auth: AuthService.fake(user: _user(), profile: _profile),
        ),
      ),
    ));
    await tester.pump();

    _olc(tester, find.byType(KAvatar), 'başlık: avatar');
  });

  testWidgets('Nasıl Oynanır? penceresi: Detaylı Kurallar linki',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: const HelpModal(),
    ));
    await tester.pumpAndSettle();

    _olc(tester, find.text('Detaylı Kurallar →'), 'yardım: Detaylı Kurallar');
  });
}
