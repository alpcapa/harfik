// Paylaşılan mesaj listesi — web `ChatThread.tsx` portu.
//
// İki tüketicisi var: ARŞİV (`GameChatHistoryModal`: bitmiş bir Canlı
// oyunun dondurulmuş sohbeti — `senderId`/`onBadgeClick` hiç verilmez,
// rozetler salt-görsel kalır, donmuş snapshot kimlik taşımaz) ve CANLI
// sohbet (`ChatModal`, Oyun İçi Mesajlaşma — Faz 2): `senderId` + kendi
// mesajı olmayan bir balona/rozete dokunmak `onBadgeClick`'i tetikleyip
// o kişinin Ayarlar panelini açar (web'in aynı ayrım kararı).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

import '../auth/k_avatar.dart';
import '../game/player_colors.dart';
import '../tokens.dart';

const _muted = kMuted;
const _text = kText;

/// Rozet: kişi sessize alınmış / şikayet edilmiş. Durum KİŞİ bazlı ve
/// güncel olduğundan (bkz. kök CLAUDE.md `person_scoped_chat_moderation`)
/// arşivde bile "o oyundaki" değil BUGÜNKÜ durumu gösterir.
enum ChatBadge { muted, reported }

class ChatThreadMessage {
  final String name;
  final int colorIndex;
  final String message;
  final String createdAt;

  /// Yalnızca canlı sohbette dolu — arşivde isimden baş harf üretilir.
  final String? avatarUrl;

  /// true ise mesaj sağa, kendi rengiyle hizalanır. Arşivde her zaman false
  /// ("kimin ekranı" kavramı geçmişte anlamsız — web'in aynı kararı).
  final bool mine;

  final ChatBadge? badge;

  /// Gönderenin user_id'si — yalnızca canlı sohbette dolu. Arşivde
  /// BİLEREK yok: donmuş snapshot kimlik taşımaz, dolayısıyla rozet/mesaj
  /// tıklaması orada hiçbir zaman aktif olamaz.
  final String? senderId;

  const ChatThreadMessage({
    required this.name,
    required this.colorIndex,
    required this.message,
    required this.createdAt,
    this.avatarUrl,
    this.mine = false,
    this.badge,
    this.senderId,
  });
}

/// Web `formatMessageTime` — "GG.AA.YYYY · SS:DD".
String formatMessageTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

class ChatThread extends StatelessWidget {
  final List<ChatThreadMessage> messages;
  final String emptyText;

  /// Rozete/mesaja tıklanınca çağrılır (o kişinin ayarlar detayını açmak
  /// için) — yalnızca canlı sohbette (`ChatModal`) verilir; arşivde
  /// verilmediğinden rozetler/balonlar salt-görsel kalır.
  final void Function(String userId)? onBadgeClick;

  const ChatThread({
    super.key,
    required this.messages,
    required this.emptyText,
    this.onBadgeClick,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 10, color: _muted)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < messages.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: _Bubble(message: messages[i], onBadgeClick: onBadgeClick),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatThreadMessage message;
  final void Function(String userId)? onBadgeClick;
  const _Bubble({required this.message, this.onBadgeClick});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final col = m.colorIndex >= 0 && m.colorIndex < playerColors.length
        ? playerColors[m.colorIndex]
        : playerColors[0];
    final badgeText = switch (m.badge) {
      ChatBadge.reported => '🚩',
      ChatBadge.muted => '🚫',
      null => null,
    };

    final avatar = KAvatar(url: m.avatarUrl, name: m.name, size: 22);

    // Kendi mesajını sessize alamayacağın/rapor edemeyeceğin için yalnızca
    // başkasının mesajına dokunmak ayarlar panelini açar (web `canOpenSettings`).
    final senderId = m.senderId;
    final canOpenSettings = !m.mine && senderId != null && onBadgeClick != null;

    final nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            // Web'de bu satır `uppercase` — Türkçe kuralı gereği native
            // toUpperCase DEĞİL trUpper (i→İ, I→ı).
            trUpper(m.name),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: col.base,
            ),
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: canOpenSettings ? () => onBadgeClick!(senderId) : null,
            child: Text(badgeText,
                style: const TextStyle(
                  fontSize: 9,
                  // Emoji SDK'nın varsayılan fontunda yok — testlerde ve
                  // bazı cihazlarda kutu çıkmasın diye açık fallback
                  // (bkz. mobile/CLAUDE.md, 🏆 dersi).
                  fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji'],
                )),
          ),
        ],
      ],
    );

    final bubble = LayoutBuilder(
      builder: (context, c) => ConstrainedBox(
        // Web `max-w-[75%]`: uzun bir mesaj balonu satırın tamamını
        // kaplamasın. ConstrainedBox içeriğine göre küçülür, yalnızca ÜST
        // sınır koyar (FractionallySizedBox olsaydı kısa mesajlar da zorla
        // %75 genişlerdi).
        constraints: BoxConstraints(maxWidth: c.maxWidth * 0.75),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: col.tint,
            border: Border.all(color: col.base),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(m.message,
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  height: 1.35,
                  color: _text)),
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment:
          m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        nameRow,
        const SizedBox(height: 2),
        canOpenSettings
            ? GestureDetector(
                onTap: () => onBadgeClick!(senderId), child: bubble)
            : bubble,
        const SizedBox(height: 2),
        Text(formatMessageTime(m.createdAt),
            style: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 8, color: _muted)),
      ],
    );

    // Kendi mesajın sağda: `textDirection` ile çevirmek yerine çocukların
    // SIRASI değiştiriliyor — yön çevirmek metnin okuma yönünü de ters
    // çevirdiğinden içeride ayrıca geri almak gerekirdi.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: m.mine
          ? [Expanded(child: body), const SizedBox(width: 6), avatar]
          : [avatar, const SizedBox(width: 6), Expanded(child: body)],
    );
  }
}
