// Kırmızı yuvarlak "bekleyen iş" sayacı — web `CountBadge.tsx` portu.
// Web'deki anlam sözleşmesi aynen geçerli (kök CLAUDE.md, CountBadge):
// rozet HER ZAMAN bekleyen iş adedidir (cevaplanmamış istek, sırası gelen
// oyun…), bir durum/ilerleme sayacı DEĞİL. Yeni bir sayaç eklerken kapsayan
// seviyelerin toplamını da güncelle (web'in "zinciri yukarı takip et" dersi).
// Web 16px daire + 9px mono kullanır; font bileşende sabit (SpaceMono) —
// web'in "ebeveyn fontu miras alınınca dikey ortalama kayıyordu" dersi.
import 'package:flutter/material.dart';
import '../tokens.dart';

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: kRed, // web bg-red
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
