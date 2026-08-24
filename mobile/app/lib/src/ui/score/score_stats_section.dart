// Skor kartı sekme çubuğu + istatistik kutuları — web
// `ScoreStatsSection.tsx` portu. Web'de olduğu gibi ScoreCard (kendi kartın)
// ve PlayerScoreCard (başkasının kartı) BU dosyayı paylaşır: iki kopya
// açmak web'de bir kez yaşanmış ve kod incelemesiyle tek kaynağa çekilmişti.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

import '../../data/stats_api.dart';
import '../tokens.dart';
import '../loading_note.dart';
import '../game/neo_box.dart';

const _panel = kPanel;
const _border = kBorder;
const _muted = kMuted;
const _text = kText;
const _accent = kAccent;
const _gold = kGold;
const _red = kRed;

class _Cell {
  final String label;
  final String value;

  /// Yüzde satırı (Toplam Oyun hariç oyuncu kutularında).
  final String? rate;
  final Color color;

  /// "En Uzun Kelime" iki sütun kaplar (web col-span-2).
  final bool span2;
  const _Cell(this.label, this.value,
      {this.rate, this.color = _text, this.span2 = false});
}

/// Web `buildScoreCells` birebir — 2 kişilikte "İkincilik" lig puanı
/// getirmese de bilgi amaçlı gösterilir (web'in 1 Ağustos 2026 kararı).
({List<_Cell> player, List<_Cell> game}) _buildCells(PlayerStats? s) {
  String pct(int n) => s != null && s.gamesPlayed > 0
      ? '%${(n / s.gamesPlayed * 100).round()}'
      : '%0';

  final player = <_Cell>[
    _Cell('Toplam Oyun', '${s?.gamesPlayed ?? 0}'),
    _Cell('Yapay Zeka ile', '${s?.localGamesPlayed ?? 0}',
        rate: pct(s?.localGamesPlayed ?? 0)),
    _Cell('Arkadaşınla', '${s?.onlineGamesPlayed ?? 0}',
        rate: pct(s?.onlineGamesPlayed ?? 0)),
    _Cell('Birincilik', '${s?.firstPlaces ?? 0}',
        rate: pct(s?.firstPlaces ?? 0), color: _gold),
    _Cell('İkincilik', '${s?.secondPlaces ?? 0}',
        rate: pct(s?.secondPlaces ?? 0), color: _accent),
    _Cell('Teslim Olma', '${s?.surrenderedCount ?? 0}',
        rate: pct(s?.surrenderedCount ?? 0), color: _red),
  ];

  final game = <_Cell>[
    _Cell('En Yüksek Oyun Puanı', '${s?.bestScore ?? 0}', color: _gold),
    _Cell('En İyi Hamle Puanı', '${s?.bestMoveScore ?? 0}', color: _accent),
    _Cell('En Yüksek Puanlı Kelime', '${s?.bestWordScore ?? 0}', color: _gold),
    // "(OHP)" — k-lig listesindeki OHP sütunuyla AYNI sayı olduğunu söyleyen
    // tek ipucu bu (kullanıcı isteği, 20 Ağustos 2026; web ile birebir).
    _Cell('Ortalama Hamle Puanı (OHP)',
        (s?.avgMoveScore ?? 0).toStringAsFixed(2), color: _accent),
    _Cell('En Uzun Kelime', s?.longestWord ?? '—', span2: true),
  ];
  return (player: player, game: game);
}

/// Sekme çubuğu — her sekme kendi lig puanını da gösterir ("(N puan)").
class ScoreTabsBar extends StatelessWidget {
  final StatsTab tab;
  final ValueChanged<StatsTab> onChanged;

  /// Sekme başına istatistik: yok (henüz yüklenmedi) / null (kayıt yok).
  final Map<StatsTab, PlayerStats?> statsByTab;

  const ScoreTabsBar({
    super.key,
    required this.tab,
    required this.onChanged,
    required this.statsByTab,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in StatsTab.values) ...[
          if (t != StatsTab.values.first) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: ShapeDecorationWithCssShadows(
                  color: tab == t ? _accent : _panel,
                  borderColor: tab == t ? _accent : _border,
                  radius: 6,
                  shadows:
                      tab == t ? kRaisedAccentShadows : kRaisedShadows,
                ),
                child: Column(
                  children: [
                    // Web: `text-sm` (14px) + `leading-none` (line-height 1).
                    // Port 13px kullanıyordu ve `leading-none`u hiç
                    // taşımamıştı — Flutter'ın varsayılanı fontun DOĞAL
                    // satır yüksekliği (~1.3×) olduğundan çubuk web'in
                    // 44px'ine karşı 53px çiziliyordu (9 Ağustos 2026,
                    // derlenmiş Tailwind CSS'i Chromium'da ölçülerek
                    // doğrulandı). `height: 1` = CSS `leading-none`.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        trUpper(t.label),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: tab == t ? Colors.white : _text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(${statsByTab[t]?.totalScore ?? 0} puan)',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1,
                        color: tab == t ? Colors.white : _text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// İki istatistik ızgarası + yükleniyor/boş durumu. [loaded] false iken
/// "Yükleniyor…" gösterilir (web'in `stats === undefined` dalı); [stats]
/// null ise kutular sıfırlarla çizilir ve üstte [emptyText] görünür.
class ScoreStatsSection extends StatelessWidget {
  final PlayerStats? stats;
  final bool loaded;
  final String emptyText;

  const ScoreStatsSection({
    super.key,
    required this.stats,
    required this.loaded,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      // ⚠ YÜKLENİRKEN DE TAM IZGARA ÇİZİLİR (24 Ağustos 2026, kullanıcı
      // cihazda bildirdi): *"önce 1-2 saniye bir popup görüyorum, sonra
      // sıralama üstüne geliyor... Halbuki tek pencere açılmalı ve datanın
      // olduğu kısımda yükleniyor yazmalı"*. Önceden burası tek satırlık
      // bir metindi; `KModal` yüksekliğini içeriğe göre aldığından pencere
      // önce küçük açılıp veri gelince büyüyordu — iki ayrı pencere gibi.
      // Aynı ızgara "—" değerleriyle çizilerek yükseklik BAŞTAN doğru
      // ayrılıyor, sayılar yerinde doluyor.
      final bos = _buildCells(null);
      List<_Cell> tire(List<_Cell> cells) => [
            for (final c in cells)
              _Cell(c.label, '—', color: _muted, span2: c.span2)
          ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KLoadingNote(vertical: 4),
          const _SectionLabel('OYUNCU İSTATİSTİKLERİ'),
          const SizedBox(height: 6),
          _CellsGrid(cells: tire(bos.player)),
          const SizedBox(height: 16),
          const _SectionLabel('OYUN İSTATİSTİKLERİ'),
          const SizedBox(height: 6),
          _CellsGrid(cells: tire(bos.game)),
        ],
      );
    }
    final cells = _buildCells(stats);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 10, color: _muted)),
          ),
        const _SectionLabel('OYUNCU İSTATİSTİKLERİ'),
        const SizedBox(height: 6),
        _CellsGrid(cells: cells.player),
        const SizedBox(height: 16),
        const _SectionLabel('OYUN İSTATİSTİKLERİ'),
        const SizedBox(height: 6),
        _CellsGrid(cells: cells.game),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 10,
            letterSpacing: 1.5,
            color: _muted),
      );
}

class _CellsGrid extends StatelessWidget {
  final List<_Cell> cells;
  const _CellsGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    // Web: `grid grid-cols-3 gap-2`, span2 hücre iki sütun kaplar. Flutter'da
    // Wrap yerine elle satırlara bölünüyor — hücre yüksekliği içeriğe göre
    // değiştiğinden GridView'ın sabit en/boy oranı uymuyor.
    const gap = 8.0;
    return LayoutBuilder(builder: (context, c) {
      final unit = (c.maxWidth - gap * 2) / 3;
      final rows = <List<_Cell>>[];
      var current = <_Cell>[];
      var used = 0;
      for (final cell in cells) {
        final w = cell.span2 ? 2 : 1;
        if (used + w > 3) {
          rows.add(current);
          current = [];
          used = 0;
        }
        current.add(cell);
        used += w;
      }
      if (current.isNotEmpty) rows.add(current);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            // IntrinsicHeight ŞART: `stretch` bir Column içinde (sınırsız
            // yükseklik) doğrudan kullanılırsa "BoxConstraints forces an
            // infinite height" ile patlar — parça 3'teki raf satırında
            // öğrenilen aynı ders. Amaç: aynı satırdaki kutular en uzun
            // olanın boyunda hizalansın (web'de grid bunu bedava veriyor).
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < rows[i].length; k++) ...[
                    if (k > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: rows[i][k].span2 ? unit * 2 + gap : unit,
                      child: _CellBox(cell: rows[i][k]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _CellBox extends StatelessWidget {
  final _Cell cell;
  const _CellBox({required this.cell});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const ShapeDecorationWithCssShadows(
        color: Colors.white, // web bg-bg
        borderColor: _border, radius: 6,
        shadows: kRaisedShadows, // web btn-raised-neutral
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              cell.value,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cell.color),
            ),
          ),
          if (cell.rate != null) ...[
            const SizedBox(height: 2),
            // Web `ScoreStatsSection.tsx`: `({c.rate})` — parantezler
            // RENDER'da ekleniyor, `pct()` yalnızca "%83" döndürüyor.
            // Port bu sarmalamayı hiç taşımamıştı (9 Ağustos 2026, cihaz
            // testinde web↔mobil ekran görüntüsü karşılaştırmasıyla
            // bulundu — web "(%83)", mobil "%83" gösteriyordu).
            Text('(${cell.rate!})',
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
          ],
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              trUpper(cell.label),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 8,
                  letterSpacing: 1,
                  color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}
