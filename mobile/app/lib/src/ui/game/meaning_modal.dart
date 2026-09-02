// Oynanan kelime(ler)in sözlük anlamı — src/components/MeaningModal.tsx
// portu. Bir dokunuş en fazla iki kelime üretir (yatay + dikey); ilki
// başlık olur, ikincisi ayraçlı bir alt başlıkla listelenir.
import 'package:flutter/material.dart';
import '../text_scale.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

import '../../data/meaning_entry.dart';
import 'modal_shell.dart';
import '../tokens.dart';
import '../../util/offline_notice.dart';

/// Kelime → anlam kaydı (yoksa null). Üretimde `MeaningStore.lookup`;
/// modal deponun tamamına değil YALNIZCA bu işleve bağlı — widget testleri
/// gerçek asset'ten önceden okunmuş veriyi doğrudan besleyebiliyor
/// (sqflite'ın gerçek async'i testWidgets'ın sahte zaman bölgesinde
/// çözülmüyor, bkz. mobile/CLAUDE.md).
typedef MeaningLookup = Future<MeaningEntry?> Function(String word);

/// TDK verisinde çapraz gönderme işareti "► kepenek (I)" gibi kullanılıyor.
/// ÖLÇÜLDÜ (fontTools ile, 6 Ağustos 2026): U+25BA ne Space Grotesk'te ne
/// Space Mono'da var — tarayıcı web'de sistem yedeğinden basıyor, Flutter'da
/// ise cihazın yedek font listesine kalıyor ve garanti değil (test ortamında
/// boş kutu çıktı). Veri setinin TAMAMI tarandı: fontların kapsamadığı tek
/// karakter bu (16.298 geçiş). Bundled fontlarda VAR olan "→" ile
/// değiştiriliyor — anlam aynı ("bkz."), her cihazda kesin çiziliyor.
String _renderable(String s) => s.replaceAll('►', '→');

const Color _text = kText;
const Color _muted = kMuted;
const Color _accent = kAccent;
const Color _border = kBorder;

Future<void> showMeaningModal(
  BuildContext context,
  MeaningLookup lookup,
  List<String> words, {
  bool Function()? isUnavailable,
}) {
  final unique = <String>[];
  for (final w in words) {
    if (w.length >= 2 && !unique.contains(w)) unique.add(w);
  }
  if (unique.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (context) =>
        MeaningModal(lookup: lookup, words: unique, isUnavailable: isUnavailable),
  );
}

class MeaningModal extends StatefulWidget {
  final MeaningLookup lookup;
  final List<String> words;

  /// Sözlüğün AÇILAMADIĞINI bildiren isteğe bağlı kanca — "kelime bulunamadı"
  /// ile "sözlüğe bakamadık" ayrımı için (bkz. `MeaningStore.unavailable`).
  /// Verilmezse eski davranış: her iki durumda da "bulunamadı".
  final bool Function()? isUnavailable;
  const MeaningModal(
      {super.key,
      required this.lookup,
      required this.words,
      this.isUnavailable});

  @override
  State<MeaningModal> createState() => _MeaningModalState();
}

class _MeaningModalState extends State<MeaningModal> {
  /// Kelime → yükleniyorsa yok, yüklendiyse (null olabilir) sonuç.
  final _loaded = <String, MeaningEntry?>{};

  @override
  void initState() {
    super.initState();
    for (final w in widget.words) {
      // Web'deki gibi her kelime bağımsız yüklenir; gelen ilk sonuç
      // diğerlerini beklemeden çizilir.
      widget.lookup(w).then((entry) {
        if (!mounted) return;
        setState(() => _loaded[w] = entry);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KModal(
      title: widget.words.first,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.words.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 16),
              Text(
                trUpper(widget.words[i]),
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _MeaningBody(
              loading: !_loaded.containsKey(widget.words[i]),
              entry: _loaded[widget.words[i]],
              unavailable: widget.isUnavailable?.call() ?? false,
            ),
          ],
        ],
      ),
    );
  }
}

class _MeaningBody extends StatelessWidget {
  final bool loading;
  final MeaningEntry? entry;

  /// Sözlük AÇILAMADI mı — "kelime bulunamadı"dan ayrı mesaj için.
  final bool unavailable;
  const _MeaningBody(
      {required this.loading, required this.entry, required this.unavailable});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Text(
        'Anlam yükleniyor…',
        style: TextStyle(fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
      );
    }
    final e = entry;
    if (e == null || e.meanings.isEmpty) {
      return Text(
        unavailable ? kOfflineMeaningNotice : 'Bu kelimenin anlamı bulunamadı.',
        style: const TextStyle(
            fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Web'de tür kısaltması (pos) ayrı gösterilmiyordu; burada da
        // gösterilmiyor — parite için bilinçli (veri asset'te duruyor,
        // ileride istenirse tek satırla açılır).
        for (var i = 0; i < e.meanings.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SINIF 3 (sarma): "10." ölçek 1,3'te 20 px'e sarıyordu.
              ScaledCell(
                width: 20,
                align: Alignment.topLeft,
                child: Text(
                  '${i + 1}.',
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    height: 1.35,
                    color: _muted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _renderable(e.meanings[i]),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: _text,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
