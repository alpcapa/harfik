// web Setup.tsx: MembershipPerksBox — yalnızca misafir (auth.user == null)
// için gösterilen "Neden Ücretsiz Üye Olmalıyım?" kutusu. İki çağrı yeri
// web'le birebir aynı: (1) misafirin "Devam Eden Oyun" görünümünün altında
// (topMargin: true — web className="mt-2"), (2) boş kurulum formunun
// altında (topMargin: false). Kutunun kendisi `auth.user == null` kontrolü
// YAPMAZ — AccountButton deseniyle tutarlı, çağıran (setup_screen.dart)
// zaten yalnızca misafir dallarında çağırıyor: `_buildSavedGameView` bu
// dala yalnızca misafirken düşüyor, `_buildNewGameForm` girişli kullanıcının
// "+ Yeni" formunda da paylaşıldığından widget'ın kendisi burada gate ediyor.
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../auth/auth_modal.dart';
import '../game/neo_box.dart';
import '../game/neo_button.dart';

const _text = Color(0xFF1B2430);
const _muted = Color(0xFF5A6673);
const _green = Color(0xFF16A34A);

// web MEMBERSHIP_PERKS (Setup.tsx) ile birebir aynı sıra/metin.
const List<String> _kMembershipPerks = [
  'Arkadaşlarınla çoklu canlı oyun oynama',
  'Skor takibi ve k-lig sıralaması',
  'Aynı anda birden fazla Yapay Zeka oyunu oynama',
  'Cihazlar arası kesintisiz devam etme',
  'Oyun geçmişini saklama, beğenme ve paylaşma',
  'Arkadaş ekleyip listende tutma',
];

class MembershipPerksBox extends StatelessWidget {
  final AuthService auth;

  /// web `className="mt-2"` — yalnızca "Devam Eden Oyun" görünümündeki
  /// çağrı yerinde true (paragraftan sonra gelen ekstra boşluk).
  final bool topMargin;

  const MembershipPerksBox({
    super.key,
    required this.auth,
    this.topMargin = false,
  });

  @override
  Widget build(BuildContext context) {
    // Web: yalnızca `!user` kontrol ediyor, `configured`'a hiç bakmıyor
    // (Setup.tsx `useAuth()`'tan yalnızca user/profile/loading'i okuyor) —
    // birebir aynı davranış korunuyor. Pratikte önemsiz: `AuthService`
    // Supabase'siz durumda `signIn`/`signUp` çağrılarını kendi içinde
    // sessizce no-op'a düşürüyor (bkz. auth_service.dart), yani buton
    // yapılandırılmamış ortamda tıklanabilir ama zararsız kalıyor — tıpkı
    // web'deki gibi.
    if (auth.user != null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: topMargin ? 8 : 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // web: `shadow-raised` — index.css'teki değerlerle, NeoButton'ın
        // neutral gölgesiyle BİREBİR AYNI (ölçüldü: ikisi de aynı CSS sınıfı
        // gölge değerlerini paylaşıyor, yalnızca zemin/çerçeve rengi farklı).
        decoration: const ShapeDecorationWithCssShadows(
          color: Color(0x0D2563EB), // web bg-accent/5
          radius: 6,
          shadows: [
            CssShadow(color: Color(0x80A3B1C6), offset: Offset(2, 2), blur: 6),
            CssShadow(
                color: Color(0xD9FFFFFF), offset: Offset(-2, -2), blur: 5),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: const Color(0x4D2563EB)), // border-accent/30
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Neden Ücretsiz Üye Olmalıyım?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            const SizedBox(height: 10),
            for (final perk in _kMembershipPerks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Web '✓' (U+2713) yazıyor ama bu karakter gömülü
                    // fontların hiçbirinde yok (bkz. auth_modal.dart
                    // _StatusLine — aynı ders, aynı çözüm: ikon).
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.check, size: 12, color: _green),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        perk,
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          height: 1.3,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              child: NeoButton(
                label: 'GİRİŞ YAP / KAYIT OL',
                variant: NeoButtonVariant.neutral,
                fontSize: 12,
                letterSpacing: 1,
                onPressed: () => showLoginModal(context, auth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
