// Arkadaş listesinden moderasyon durumunu YÖNETME paneli — web
// `FriendModerationModal.tsx` portu.
//
// NEDEN VAR (14 Ağustos 2026, kullanıcı isteği): sessize alma/şikayet 3
// Ağustos'tan beri KİŞİ bazlı, ama geri almanın TEK giriş noktası o kişiyle
// AKTİF bir oyunun sohbet ayarlarıydı (`ChatSettingsModal`, dişli). Oyun
// bitince `LiveGamesTab` onu listelemiyor, arşiv (`GameChatHistoryModal`)
// ise bilerek salt-görsel — yani şikayeti geri çekmek için raporladığın
// kişiyle YENİ bir oyun açmak gerekiyordu. Kullanıcı cihaz testinde bu
// duvara çarptı.
//
// KAPSAM bilinçli olarak yalnızca GERİ ALMA (sessizden çıkar / şikayeti
// geri çek). YENİ şikayet burada YOK: bir şikayet hakkında olduğu
// KONUŞMAYA bağlı (`online_game_chat_reports.online_game_id`) ve admin
// panelindeki "Sohbeti Görüntüle" o dökümü açıyor; arkadaş listesinden
// açılan bir şikayet zorunlu olarak ESKİ bir oyuna iliştirilir ve admin
// şikayetle ilgisi olmayan bir yazışma okurdu. Bu yüzden ikon da yalnızca
// durum VARKEN çiziliyor — bu bir "geri al" kısayolu, moderasyon menüsü
// değil.
import 'package:flutter/material.dart';

import '../../data/chat_api.dart';
import '../auth/k_avatar.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import '../tokens.dart';

const _muted = kMuted;
const _text = kText;

class FriendModerationTarget {
  final String userId;
  final String name;
  final String? avatarUrl;

  /// Sessize alınmışsa kaydın geldiği oyun id'si — RPC'nin katılımcılık
  /// kontrolü için (bkz. `ChatRepo.myModeration`).
  final String? mutedGameId;
  final bool reported;

  const FriendModerationTarget({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.mutedGameId,
    required this.reported,
  });
}

/// Değişiklik yapıldıysa `true` döner — çağıran ikonu tazelemek için kullanır.
Future<bool> showFriendModeration(
  BuildContext context, {
  required ChatRepo chat,
  required FriendModerationTarget target,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _FriendModerationSheet(chat: chat, target: target),
  );
  return changed ?? false;
}

enum _View { menu, unmuteConfirm, withdrawConfirm, done }

class _FriendModerationSheet extends StatefulWidget {
  final ChatRepo chat;
  final FriendModerationTarget target;

  const _FriendModerationSheet({required this.chat, required this.target});

  @override
  State<_FriendModerationSheet> createState() => _FriendModerationSheetState();
}

class _FriendModerationSheetState extends State<_FriendModerationSheet> {
  _View _view = _View.menu;
  bool _busy = false;
  String? _error;
  String _doneMsg = '';
  bool _changed = false;

  bool get _isMuted => widget.target.mutedGameId != null;

  Future<void> _run(Future<void> Function() action, String msg) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _changed = true;
        _doneMsg = msg;
        _view = _View.done;
      });
    } catch (_) {
      // Sessizce yutma YOK — kullanıcı gerçekleşmemiş bir sonucu "olmuş"
      // sanmamalı (Parça 89'un dersi).
      if (!mounted) return;
      setState(() => _error = 'İşlem başarısız oldu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    return KModal(
      title: 'Kişi Ayarları',
      onClose: () => Navigator.of(context).pop(_changed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            KAvatar(url: t.avatarUrl, name: t.name, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            ),
          ]),
          const SizedBox(height: 12),
          if (_view == _View.menu) ..._menu(t),
          if (_view == _View.unmuteConfirm || _view == _View.withdrawConfirm)
            ..._confirm(t),
          if (_view == _View.done) ..._done(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 10, color: kRed)),
          ],
        ],
      ),
    );
  }

  List<Widget> _menu(FriendModerationTarget t) => [
        Text(
          t.reported && _isMuted
              ? 'Bu kişiyi şikayet ettiniz ve sessize aldınız.'
              : t.reported
                  ? 'Bu kişiyi şikayet ettiniz.'
                  : 'Bu kişiyi sessize aldınız.',
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        if (t.reported) ...[
          NeoButton(
            label: 'Şikayeti Geri Çek',
            variant: NeoButtonVariant.neutral,
            onPressed: _busy ? null : () => setState(() => _view = _View.withdrawConfirm),
          ),
          const SizedBox(height: 8),
        ],
        if (_isMuted) ...[
          NeoButton(
            label: 'Sessizden Çıkar',
            variant: NeoButtonVariant.neutral,
            onPressed: _busy ? null : () => setState(() => _view = _View.unmuteConfirm),
          ),
          const SizedBox(height: 8),
        ],
        const Text(
          'Şikayet etmek ve sessize almak, o kişiyle oynadığın Canlı oyunun '
          'mesajlaşma ayarlarından yapılır.',
          style: TextStyle(fontFamily: 'SpaceMono', fontSize: 10, color: _muted, height: 1.5),
        ),
      ];

  List<Widget> _confirm(FriendModerationTarget t) {
    final unmute = _view == _View.unmuteConfirm;
    return [
      const Text('Emin misiniz?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
      const SizedBox(height: 8),
      Text(
        unmute
            ? '${t.name} artık sessize alınmayacak; mesajları için bildirim '
                'almaya devam edeceksiniz.'
            : '${t.name} hakkındaki şikayetiniz geri çekilecek. Dilerseniz '
                'daha sonra tekrar şikayet edebilirsiniz.',
        style: const TextStyle(fontSize: 14, color: _text, height: 1.5),
      ),
      const SizedBox(height: 12),
      // Kabul butonu SOLDA (Parça 25 kuralı).
      Row(children: [
        Expanded(
          child: NeoButton(
            variant: NeoButtonVariant.accent,
            label: _busy ? '...' : (unmute ? 'Sessizden Çıkar' : 'Geri Çek'),
            onPressed: _busy
                ? null
                : () => unmute
                    ? _run(
                        () => widget.chat
                            .setMute(t.mutedGameId!, t.userId, false),
                        'Kişi sessizden çıkarıldı.')
                    : _run(() => widget.chat.withdrawReports(t.userId),
                        'Şikayetiniz geri çekildi.'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NeoButton(
            label: 'Vazgeç',
            variant: NeoButtonVariant.neutral,
            onPressed: _busy ? null : () => setState(() => _view = _View.menu),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _done() => [
        Text(_doneMsg,
            style: const TextStyle(fontSize: 14, color: _text, height: 1.5)),
        const SizedBox(height: 12),
        NeoButton(
          label: 'Tamam',
          variant: NeoButtonVariant.neutral,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ];
}
