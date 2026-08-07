// Oyun İçi Mesajlaşma — Faz 2: sessize alma / raporlama ayarları.
// ChatModal'ın dişli ikonundan açılır — src/components/ChatSettingsModal.tsx
// portu. Liste görünümü ↔ kişi detay görünümü ↔ rapor akışı aynı KModal
// içinde, inline state ile değişir (HelpModal'ın Hızlı Başlangıç ↔ Detaylı
// Kurallar geçişiyle aynı desen) — üçüncü bir nested modal katmanı yok.
//
// Rozet mantığı: bayrak (🚩) yalnızca AKTİF (geri çekilmemiş) bir raporum
// varsa gösterilir; yoksa ve kişiyi sessize almışsam yasak işareti (🚫);
// ikisi de yoksa hiçbir işaret yok. Bu rozetler yalnızca işlemi yapan kişiye
// görünür — karşı taraf hiçbir zaman göremez.
//
// 3 Ağustos 2026'dan beri her iki durum da OYUNA değil KİŞİYE bağlı — bir
// oyunda sessize aldığın/rapor ettiğin kişi onunla açtığın sonraki
// oyunlarda da işaretli gelir; bu yüzden onay metinleri "bu oyunda" demiyor.
// Ama "kalıcı" DEĞİL: sessize alma tekrar açılıp kapatılabiliyor, rapor
// "Şikayeti Geri Çek" ile kapatılabiliyor.
//
// TERMİNOLOJİ: kullanıcıya görünen metinlerde "rapor" yerine "şikayet"
// kullanılıyor (web kararı) — kod tarafı (RPC/prop adları) bilerek değişmedi.
import 'package:flutter/material.dart';

import '../../data/chat_api.dart';
import '../auth/k_avatar.dart';
import '../game/modal_shell.dart';
import 'chat_modal.dart' show ChatParticipant;

const _text = Color(0xFF1B2430);
const _muted = Color(0xFF5A6673);
const _accent = Color(0xFF2563EB);
const _red = Color(0xFFE0483A);
const _border = Color(0xFFDCE2EA);
const _bg = Color(0xFFFFFFFF);
const _void = Color(0xFFEDF1F7);

const int kReportReasonMaxLength = 500;

sealed class _View {
  const _View();
}

class _ListView extends _View {
  const _ListView();
}

class _DetailView extends _View {
  final ChatParticipant participant;
  const _DetailView(this.participant);
}

class _MuteConfirmView extends _View {
  final ChatParticipant participant;
  final bool nextMuted;
  const _MuteConfirmView(this.participant, this.nextMuted);
}

class _ReportReasonView extends _View {
  final ChatParticipant participant;
  const _ReportReasonView(this.participant);
}

class _ReportConfirmView extends _View {
  final ChatParticipant participant;
  final String reason;
  const _ReportConfirmView(this.participant, this.reason);
}

class _ReportSentView extends _View {
  final ChatParticipant participant;
  const _ReportSentView(this.participant);
}

class _WithdrawConfirmView extends _View {
  final ChatParticipant participant;
  const _WithdrawConfirmView(this.participant);
}

Future<void> showChatSettingsModal(
  BuildContext context, {
  required String gameId,
  required ChatRepo chat,
  required List<ChatParticipant> participants,
  required Set<String> mutedUserIds,
  required Set<String> reportedUserIds,
  required void Function(String targetUserId, bool muted) onMuteChange,
  required void Function(String targetUserId) onReported,
  required void Function(String targetUserId) onWithdrawn,
  String? initialParticipantId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChatSettingsModal(
      gameId: gameId,
      chat: chat,
      participants: participants,
      mutedUserIds: mutedUserIds,
      reportedUserIds: reportedUserIds,
      onMuteChange: onMuteChange,
      onReported: onReported,
      onWithdrawn: onWithdrawn,
      initialParticipantId: initialParticipantId,
    ),
  );
}

class ChatSettingsModal extends StatefulWidget {
  final String gameId;
  final ChatRepo chat;

  /// Zaten çağıranın kendi user_id'si hariç filtrelenmiş gelir.
  final List<ChatParticipant> participants;
  final Set<String> mutedUserIds;
  final Set<String> reportedUserIds;
  final void Function(String targetUserId, bool muted) onMuteChange;
  final void Function(String targetUserId) onReported;
  final void Function(String targetUserId) onWithdrawn;

  /// Doluysa modal doğrudan bu kişinin detay görünümüyle açılır — sohbetteki
  /// bir rozete/mesaja tıklanınca kullanılır (listeyi atlar).
  final String? initialParticipantId;

  const ChatSettingsModal({
    super.key,
    required this.gameId,
    required this.chat,
    required this.participants,
    required this.mutedUserIds,
    required this.reportedUserIds,
    required this.onMuteChange,
    required this.onReported,
    required this.onWithdrawn,
    this.initialParticipantId,
  });

  @override
  State<ChatSettingsModal> createState() => _ChatSettingsModalState();
}

class _ChatSettingsModalState extends State<ChatSettingsModal> {
  late _View _view = () {
    final id = widget.initialParticipantId;
    if (id == null) return const _ListView();
    final match = widget.participants.where((p) => p.userId == id);
    return match.isEmpty ? const _ListView() : _DetailView(match.first);
  }();
  final _reasonController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _toggleMute(ChatParticipant p) async {
    final nextMuted = !widget.mutedUserIds.contains(p.userId);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.chat.setMute(widget.gameId, p.userId, nextMuted);
      widget.onMuteChange(p.userId, nextMuted);
    } catch (e) {
      setState(() => _error = 'İşlem başarısız oldu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(ChatParticipant p) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.chat.withdrawReports(p.userId);
      widget.onWithdrawn(p.userId);
      setState(() => _view = const _ListView());
    } catch (e) {
      setState(() => _error = 'İşlem başarısız oldu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitReport(ChatParticipant p, String reason) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.chat.report(widget.gameId, p.userId, reason);
      widget.onReported(p.userId);
      setState(() {
        _view = _ReportSentView(p);
        _reasonController.clear();
      });
    } catch (e) {
      setState(() => _error = 'Şikayet gönderilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KModal(title: 'Sohbet Ayarları', child: _buildBody());
  }

  Widget _buildBody() {
    final view = _view;
    return switch (view) {
      _ListView() => _buildList(),
      _DetailView(:final participant) => _buildDetail(participant),
      _MuteConfirmView(:final participant, :final nextMuted) =>
        _buildMuteConfirm(participant, nextMuted),
      _ReportReasonView(:final participant) => _buildReportReason(participant),
      _ReportConfirmView(:final participant, :final reason) =>
        _buildReportConfirm(participant, reason),
      _ReportSentView(:final participant) => _buildReportSent(participant),
      _WithdrawConfirmView(:final participant) =>
        _buildWithdrawConfirm(participant),
    };
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Buradan kişileri sessize alabilir ve/veya uygunsuz paylaşımları '
          'şikayet edebilirsiniz.',
          style: TextStyle(fontSize: 12, height: 1.5, color: _muted),
        ),
        const SizedBox(height: 12),
        for (final p in widget.participants)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _error = null;
                  _view = _DetailView(p);
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _bg,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    KAvatar(url: p.avatarUrl, name: p.name, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _text)),
                    ),
                    if (widget.reportedUserIds.contains(p.userId))
                      const _EmojiBadge('🚩', label: 'Şikayet edildi')
                    else if (widget.mutedUserIds.contains(p.userId))
                      const _EmojiBadge('🚫', label: 'Sessize alındı'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetail(ChatParticipant p) {
    final muted = widget.mutedUserIds.contains(p.userId);
    final reported = widget.reportedUserIds.contains(p.userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          KAvatar(url: p.avatarUrl, name: p.name, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(p.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
          ),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _busy
              ? null
              : () {
                  setState(() {
                    _error = null;
                    _view = _MuteConfirmView(p, !muted);
                  });
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _bg,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Opacity(
              opacity: _busy ? 0.5 : 1,
              child: Row(children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: muted ? _accent : _bg,
                    border: Border.all(
                        color: muted ? _accent : _muted, width: 2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: muted
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                const Text('Kişiyi Sessize Al',
                    style: TextStyle(fontSize: 13, color: _text)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (reported) ...[
          const Text('Bu kişiyi şikayet ettiniz.',
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 6),
          _NeoTextButton(
            label: 'ŞİKAYETİ GERİ ÇEK',
            style: _NeoButtonStyle.neutral,
            onPressed: _busy
                ? null
                : () => setState(() => _view = _WithdrawConfirmView(p)),
          ),
        ] else
          _NeoTextButton(
            label: 'KİŞİYİ ŞİKAYET ET',
            style: _NeoButtonStyle.danger,
            onPressed: () {
              _reasonController.clear();
              setState(() {
                _error = null;
                _view = _ReportReasonView(p);
              });
            },
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 10, color: _red)),
        ],
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _view = const _ListView()),
            child: const Text('← Geri',
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
          ),
        ),
      ],
    );
  }

  Widget _buildMuteConfirm(ChatParticipant p, bool nextMuted) {
    return _ConfirmView(
      title: 'Emin misiniz?',
      body: nextMuted
          ? '${p.name} kullanıcısını sessize almak istediğinize emin '
              'misiniz? Kullanıcının mesajları sohbette görünmeye devam '
              'eder ama sizin ekranınıza bildirim olarak gelmez.'
          : '${p.name} kullanıcısını sessizden çıkarmak istediğinize emin '
              'misiniz? Kullanıcıdan gelen yeni mesajlar için tekrar '
              'bildirim almaya başlarsınız.',
      boldName: p.name,
      error: _error,
      busy: _busy,
      confirmLabel: nextMuted ? 'SESSİZE AL' : 'SESSİZDEN ÇIKAR',
      onConfirm: () async {
        await _toggleMute(p);
        if (mounted) setState(() => _view = _DetailView(p));
      },
      onCancel: () => setState(() => _view = _DetailView(p)),
    );
  }

  Widget _buildWithdrawConfirm(ChatParticipant p) {
    return _ConfirmView(
      title: 'Emin misiniz?',
      body: '${p.name} için gönderdiğiniz şikayeti geri çekmek istediğinize '
          'emin misiniz? Bu kullanıcı hakkındaki tüm açık şikayetleriniz '
          'geri çekilir ama sessize alma durumu devam eder; isterseniz '
          'ayrıca mesajlaşma ayarlarından onu da kaldırabilirsiniz.',
      boldName: p.name,
      error: _error,
      busy: _busy,
      confirmLabel: 'ŞİKAYETİ GERİ ÇEK',
      onConfirm: () => _withdraw(p),
      onCancel: () => setState(() => _view = _DetailView(p)),
    );
  }

  Widget _buildReportReason(ChatParticipant p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(
              text: p.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _text, fontSize: 13)),
          const TextSpan(
              text: ' kullanıcısını neden şikayet ediyorsunuz?',
              style: TextStyle(color: _text, fontSize: 13)),
        ])),
        const SizedBox(height: 10),
        TextField(
          controller: _reasonController,
          maxLength: kReportReasonMaxLength,
          maxLines: 3,
          minLines: 3,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Kısaca açıklayın (zorunlu)…',
            filled: true,
            fillColor: _bg,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _accent)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
              '${_reasonController.text.length}/$kReportReasonMaxLength',
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 10, color: _muted)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _NeoTextButton(
              label: 'DEVAM ET',
              style: _NeoButtonStyle.danger,
              onPressed: _reasonController.text.trim().isEmpty
                  ? null
                  : () => setState(() => _view = _ReportConfirmView(
                      p, _reasonController.text.trim())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NeoTextButton(
              label: 'VAZGEÇ',
              style: _NeoButtonStyle.neutral,
              onPressed: () => setState(() => _view = _DetailView(p)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildReportConfirm(ChatParticipant p, String reason) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Emin misiniz?',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: p.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _text, fontSize: 13)),
          const TextSpan(
              text: ' kullanıcısı, yazdığınız nedenle Kelimeki ekibine '
                  'şikayet olarak iletilecektir. Bu şikayetinizi daha '
                  'sonra mesajlaşma ayarlarından geri çekebilirsiniz.',
              style: TextStyle(color: _text, fontSize: 13, height: 1.5)),
        ])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(reason,
              style: const TextStyle(fontSize: 11, color: _muted)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 10, color: _red)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _NeoTextButton(
              label: _busy ? '...' : 'ŞİKAYET ET',
              style: _NeoButtonStyle.danger,
              onPressed: _busy ? null : () => _submitReport(p, reason),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NeoTextButton(
              label: 'VAZGEÇ',
              style: _NeoButtonStyle.neutral,
              onPressed:
                  _busy ? null : () => setState(() => _view = _ReportReasonView(p)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildReportSent(ChatParticipant p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Şikayetiniz iletildi.',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: p.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _text, fontSize: 13)),
          const TextSpan(
              text: ' hakkındaki şikayetiniz Kelimeki ekibine ulaştı. Bu '
                  'kişi aynı zamanda sizin için sessize alındı; dilerseniz '
                  'şikayetinizi buradan geri çekebilirsiniz.',
              style: TextStyle(color: _text, fontSize: 13, height: 1.5)),
        ])),
        const SizedBox(height: 12),
        _NeoTextButton(
          label: 'TAMAM',
          style: _NeoButtonStyle.accent,
          onPressed: () => setState(() => _view = const _ListView()),
        ),
      ],
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  final String emoji;
  final String label;
  const _EmojiBadge(this.emoji, {required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Text(emoji,
            style: const TextStyle(
              fontSize: 14,
              fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji'],
            )),
      );
}

class _ConfirmView extends StatelessWidget {
  final String title;
  final String body;
  final String boldName;
  final String? error;
  final bool busy;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  const _ConfirmView({
    required this.title,
    required this.body,
    required this.boldName,
    required this.error,
    required this.busy,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final idx = body.indexOf(boldName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 8),
        idx < 0
            ? Text(body,
                style: const TextStyle(fontSize: 13, height: 1.5, color: _text))
            : Text.rich(TextSpan(children: [
                TextSpan(
                    text: body.substring(0, idx),
                    style:
                        const TextStyle(fontSize: 13, height: 1.5, color: _text)),
                TextSpan(
                    text: boldName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _text)),
                TextSpan(
                    text: body.substring(idx + boldName.length),
                    style:
                        const TextStyle(fontSize: 13, height: 1.5, color: _text)),
              ])),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 10, color: _red)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _NeoTextButton(
              label: busy ? '...' : confirmLabel,
              style: _NeoButtonStyle.accent,
              onPressed: busy ? null : () => onConfirm(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NeoTextButton(
              label: 'VAZGEÇ',
              style: _NeoButtonStyle.neutral,
              onPressed: busy ? null : onCancel,
            ),
          ),
        ]),
      ],
    );
  }
}

enum _NeoButtonStyle { accent, neutral, danger }

/// Bu modalın butonları web'in `btn-raised`/`btn-raised-neutral` küçük
/// varyantları — genel `NeoButton`'ın büyük punto/padding'i bu yoğun
/// formda uymuyor, sade bir `ElevatedButton` sarmalayıcısı yeterli.
class _NeoTextButton extends StatelessWidget {
  final String label;
  final _NeoButtonStyle style;
  final VoidCallback? onPressed;
  const _NeoTextButton(
      {required this.label, required this.style, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      _NeoButtonStyle.accent => (_accent, Colors.white, null),
      _NeoButtonStyle.danger => (_red, Colors.white, null),
      _NeoButtonStyle.neutral => (_void, _text, _border),
    };
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        disabledForegroundColor: fg.withValues(alpha: 0.7),
        side: border != null ? BorderSide(color: border) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}
