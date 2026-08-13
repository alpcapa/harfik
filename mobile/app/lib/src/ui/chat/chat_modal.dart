// Oyun İçi Mesajlaşma — Faz 1: Canlı oyundaki gerçek sohbet penceresi.
// Board'un "Mesajlaşma" butonuyla açılır — src/components/ChatModal.tsx
// portu. Mesaj listesi/mute/rapor setleri ÇAĞIRANDAN (OnlineGameScreen)
// gelir; bu widget yalnızca gönderim formunu ve `ChatThread`'i render eder.
import 'package:flutter/material.dart';

import 'chat_thread.dart';
import '../game/modal_shell.dart';
import '../tokens.dart';
import '../form_input.dart';

const _accent = kAccent;
const _muted = kMuted;
const _red = kRed;

const int kChatMaxLength = 200;

class ChatParticipant {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int colorIndex;
  const ChatParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.colorIndex,
  });
}

class ChatMessage {
  final String id;
  final String senderUserId;
  final String message;
  final String createdAt;
  const ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.message,
    required this.createdAt,
  });
}

Future<void> showChatModal(
  BuildContext context, {
  required List<ChatMessage> messages,
  required List<ChatParticipant> participants,
  required String myUserId,
  required Future<void> Function(String text) onSend,
  required VoidCallback onOpenSettings,
  required Set<String> mutedUserIds,
  required Set<String> reportedUserIds,
  required void Function(String userId) onOpenParticipantSettings,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChatModal(
      messages: messages,
      participants: participants,
      myUserId: myUserId,
      onSend: onSend,
      onOpenSettings: onOpenSettings,
      mutedUserIds: mutedUserIds,
      reportedUserIds: reportedUserIds,
      onOpenParticipantSettings: onOpenParticipantSettings,
    ),
  );
}

class ChatModal extends StatefulWidget {
  final List<ChatMessage> messages;
  final List<ChatParticipant> participants;
  final String myUserId;
  final Future<void> Function(String text) onSend;
  final VoidCallback onOpenSettings;
  final Set<String> mutedUserIds;
  final Set<String> reportedUserIds;
  final void Function(String userId) onOpenParticipantSettings;

  const ChatModal({
    super.key,
    required this.messages,
    required this.participants,
    required this.myUserId,
    required this.onSend,
    required this.onOpenSettings,
    required this.mutedUserIds,
    required this.reportedUserIds,
    required this.onOpenParticipantSettings,
  });

  @override
  State<ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<ChatModal> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void didUpdateWidget(ChatModal old) {
    super.didUpdateWidget(old);
    // En yeni mesaj en ÜSTTE (aşağıdaki `.reversed`) — yeni mesaj gelince
    // listenin başına kaydırılır (web `scrollTop = 0`).
    if (widget.messages.length != old.messages.length &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(trimmed);
      _controller.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web: eskiden-yeniye gelen listeyi ters çevirip en yeniyi üste alır —
    // ChatThread kendi tarafında sıralama yapmaz.
    final threadMessages = [
      for (final m in widget.messages.reversed)
        ChatThreadMessage(
          name: widget.participants
                  .where((p) => p.userId == m.senderUserId)
                  .map((p) => p.name)
                  .firstOrNull ??
              'Oyuncu',
          colorIndex: widget.participants
                  .where((p) => p.userId == m.senderUserId)
                  .map((p) => p.colorIndex)
                  .firstOrNull ??
              0,
          avatarUrl: widget.participants
              .where((p) => p.userId == m.senderUserId)
              .map((p) => p.avatarUrl)
              .firstOrNull,
          message: m.message,
          createdAt: m.createdAt,
          mine: m.senderUserId == widget.myUserId,
          senderId: m.senderUserId,
          // Bayrak rapora, yasak işareti yalnızca sessize almaya bakar —
          // biri rapor edildiyse bayrak kazanır (ikisi asla birlikte).
          badge: widget.reportedUserIds.contains(m.senderUserId)
              ? ChatBadge.reported
              : widget.mutedUserIds.contains(m.senderUserId)
                  ? ChatBadge.muted
                  : null,
        ),
    ];

    return KModal(
      title: 'Mesajlaşma',
      headerAction: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Sohbet Ayarları',
        onPressed: widget.onOpenSettings,
        icon: const Icon(Icons.settings, size: 18, color: _muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLength: kChatMaxLength,
            maxLines: 2,
            minLines: 2,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
            style: kInputTextStyle,
            // counterText: '' — özel sayaç aşağıda (web de öyle).
            decoration: kInputDecoration(hint: 'Mesajınızı girin'),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_controller.text.length}/$kChatMaxLength',
                  style: const TextStyle(
                      fontFamily: 'SpaceMono', fontSize: 10, color: _muted)),
              ElevatedButton(
                onPressed: (_sending || _controller.text.trim().isEmpty)
                    ? null
                    : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                ),
                child: Text(_sending ? 'Gönderiliyor…' : 'Gönder',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 10, color: _red)),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 288), // web max-h-72
            child: SingleChildScrollView(
              controller: _scrollController,
              child: ChatThread(
                messages: threadMessages,
                emptyText: 'Henüz mesaj yok. İlk mesajı sen gönder!',
                onBadgeClick: widget.onOpenParticipantSettings,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
