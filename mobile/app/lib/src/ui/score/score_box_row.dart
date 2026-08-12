// Tahta önizlemesinin üstündeki tek satır skor kutuları — web
// `ScoreBoxRow` (GameHistoryModal.tsx içinde) portu.
//
// `GameHeader`'daki oyun içi skor kutularıyla AYNI görsel dil (zone.tint
// dolgu + base çerçeve, üstte isim, altta puan); farkı dört kutunun da
// (2 ya da 4 oyunculu fark etmeksizin) eşit genişlikte tek satıra
// sığdırılması — burada `GameHeader`'ın akıcı clamp() genişlik sistemi
// kullanılmıyor, sabit küçük punto yeterli.
//
// Bu satır paylaşılan GÖRSELİN parçası: yakalanan PNG yalnızca tahtayı
// değil kimin kaç puan aldığını da taşısın diye (web'de skor/tarih bir
// dönem paylaşım METNİNDEYDİ, sonra görsele taşındı).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

import '../../data/game_record.dart';
import '../game/player_colors.dart';

class ScoreBoxRow extends StatelessWidget {
  final List<GamePlayerSnapshot> players;

  /// Koltuk kimliği çözücü — final sıralamadan bağımsız renk eşlemesi için
  /// (`GameHistoryModal._seatIndexFor`; iki yerde ayrışmasın diye çağıran
  /// veriyor).
  final int Function(GamePlayerSnapshot player, int position) seatIndexOf;

  /// Kendi satırında dondurulmuş ad yerine gösterilecek GÜNCEL ad; -1 ise
  /// hiçbir satır "ben" değil.
  final int meIndex;
  final String? currentName;

  const ScoreBoxRow({
    super.key,
    required this.players,
    required this.seatIndexOf,
    required this.meIndex,
    required this.currentName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < players.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _Box(
            player: players[i],
            color: playerColors[
                seatIndexOf(players[i], i) % playerColors.length],
            label: i == meIndex && currentName != null
                ? currentName!
                : players[i].name,
          )),
        ],
      ],
    );
  }
}

class _Box extends StatelessWidget {
  final GamePlayerSnapshot player;
  final PlayerColor color;
  final String label;

  const _Box({required this.player, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: color.tint,
          // Web dersi: burada inset box-shadow DEĞİL gerçek çerçeve — bu
          // düğüm görsele yakalandığından çerçevenin yakalamada güvenilir
          // görünmesi gerekiyor.
          border: Border.all(color: color.base, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // Web'de `uppercase` — Türkçe kuralı gereği trUpper.
              trUpper(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 7,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: color.base,
              ),
            ),
            Text(
              '${player.score}',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.bold,
                color: color.base,
              ),
            ),
          ],
        ),
      );
}
