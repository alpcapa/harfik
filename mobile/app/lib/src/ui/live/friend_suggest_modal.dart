// Davet kabulü sonrası "bu kişileri arkadaş ekle" önerisi —
// src/components/FriendSuggestModal.tsx portu. Karşılıklı istekler sunucu
// trigger'ıyla otomatik kabul olur (web'in aynı notu); tekil hatalar (zaten
// bekleyen istek → unique violation) sessizce yutulur, diğerlerini
// engellemez.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trCompare;

import '../../data/friends_api.dart';
import '../auth/k_avatar.dart';
import '../game/neo_button.dart';

const Color _text = Color(0xFF1B2430);
const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFDCE2EA);

class SuggestCandidate {
  final String userId;
  final String? name;
  final String? avatarUrl;
  const SuggestCandidate(
      {required this.userId, this.name, this.avatarUrl});
}

Future<void> showFriendSuggestModal(
  BuildContext context, {
  required FriendsRepo friends,
  required List<SuggestCandidate> candidates,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        FriendSuggestModal(friends: friends, candidates: candidates),
  );
}

class FriendSuggestModal extends StatefulWidget {
  final FriendsRepo friends;
  final List<SuggestCandidate> candidates;
  const FriendSuggestModal(
      {super.key, required this.friends, required this.candidates});

  @override
  State<FriendSuggestModal> createState() => _FriendSuggestModalState();
}

class _FriendSuggestModalState extends State<FriendSuggestModal> {
  late final List<SuggestCandidate> _sorted = [...widget.candidates]
    ..sort((a, b) => trCompare(a.name ?? '', b.name ?? ''));
  late final Set<String> _selected = {
    for (final c in widget.candidates) c.userId
  }; // hepsi önceden işaretli (web)
  bool _busy = false;
  bool _done = false;

  Future<void> _continue() async {
    if (_selected.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    await Future.wait([
      for (final id in _selected)
        widget.friends.sendRequest(id).then<void>((_) {}).catchError(
            (Object e) =>
                debugPrint('[Kelimeki] arkadaşlık isteği hatası: $e')),
    ]);
    if (mounted) {
      setState(() {
        _busy = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _done
              ? [
                  const Text('Arkadaşlık davetiniz iletilmiştir.',
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: _text)),
                  const SizedBox(height: 16),
                  NeoButton(
                    label: 'TAMAM',
                    variant: NeoButtonVariant.accent,
                    fontSize: 11,
                    letterSpacing: 1,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]
              : [
                  const Text('Bu kişileri arkadaşın olarak eklemek ister misin?',
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: _text)),
                  const SizedBox(height: 12),
                  for (final c in _sorted) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        if (!_selected.remove(c.userId)) {
                          _selected.add(c.userId);
                        }
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          KAvatar(url: c.avatarUrl, name: c.name, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(c.name ?? 'Oyuncu',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _text)),
                          ),
                          _CheckMark(checked: _selected.contains(c.userId)),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  NeoButton(
                    label: _busy ? '…' : 'DEVAM',
                    variant: NeoButtonVariant.accent,
                    fontSize: 11,
                    letterSpacing: 1,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: _busy ? null : _continue,
                  ),
                ],
        ),
      ),
    );
  }
}

/// Web CheckMark — işaretliyse accent dolgulu kutu (✓ glyph'i yerine ikon;
/// bundled fontlarda U+2713 yok dersi).
class _CheckMark extends StatelessWidget {
  final bool checked;
  const _CheckMark({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: checked ? _accent : Colors.white,
        border: Border.all(color: checked ? _accent : _border, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: checked
          ? const Icon(Icons.check, size: 11, color: Colors.white)
          : null,
    );
  }
}
