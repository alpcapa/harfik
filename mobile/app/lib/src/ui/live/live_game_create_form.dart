// Canlı oyun kurulumu — src/components/LiveGameCreateForm.tsx portu.
// Kompozisyon kuralı (online_game_ai_slot_rule migration'ı, sunucu da
// zorluyor): 2 kişilikte YZ'ye hiç izin yok (tam 1 arkadaş); 4 kişilikte
// en az 2 arkadaş, yalnızca 4. koltuk YZ olabilir. 2 arkadaşla gönderimde
// önce "4. koltuk Yapay Zeka ile doldurulacak, tamam mı?" onayı — Hayır
// denirse YZ kalıcı bir liste satırı olur (bir daha sorulmaz, web'in aynı
// akışı). Gönderim sonrası "Davetiniz gönderilmiştir." onay ekranı
// (isimler gönderim anında dondurulur — web sentTo).
//
// Bilinçli sapma: web'in viewport'a sabitlenmiş alt barı (Davet Gönder/
// Vazgeç) YOK — o, web'in #root scroll yapısına özgü bir "buton görünmez
// kalıyor" düzeltmesiydi; mobilde arkadaş listesi kendi 280px sınırında
// kaydırıldığından butonlar normal akışta her zaman erişilebilir.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trLower, trUpper;

import '../../data/auth_service.dart';
import '../../data/chat_api.dart';
import '../../data/feedback_api.dart';
import '../../data/friends_api.dart';
import '../../data/online_games_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../friends/friends_modal.dart';
import '../game/neo_button.dart';
import '../tokens.dart';
import '../form_input.dart';

const Color _text = kText;
const Color _muted = kMuted;
const Color _accent = kAccent;
const Color _border = kBorder;
const Color _panel = kPanel;

class LiveGameCreateForm extends StatefulWidget {
  final AuthService auth;
  final FriendsRepo friends;
  final OnlineGamesRepo onlineGames;

  /// FriendsModal zinciri için (Arkadaş Ekle butonu).
  final StatsRepo? stats;
  final Future<GamesRepo>? games;
  final FeedbackRepo? feedback;

  /// "Arkadaşlarım" satırındaki moderasyon (sessize alma/şikayet) ikonu için
  /// — bu ekrandan açılan FriendsModal, hesap menüsünden açılanla AYNI
  /// görünmek zorunda; geçilmezse aynı satır orada ikonlu burada ikonsuz
  /// olurdu.
  final ChatRepo? chat;

  final VoidCallback onCancel;
  final VoidCallback onCreated;

  const LiveGameCreateForm({
    super.key,
    required this.auth,
    required this.friends,
    required this.onlineGames,
    required this.onCancel,
    required this.onCreated,
    this.stats,
    this.games,
    this.feedback,
    this.chat,
  });

  @override
  State<LiveGameCreateForm> createState() => _LiveGameCreateFormState();
}

class _LiveGameCreateFormState extends State<LiveGameCreateForm> {
  int _playerCount = 2;
  List<FriendRow>? _friends;
  final List<String> _selected = [];
  bool _showAiRow = false;
  bool _aiSelected = false;
  bool _busy = false;
  String? _error;
  final _query = TextEditingController();
  ({List<String> names, bool withAi})? _sentTo;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _lastUserId = widget.auth.user?.id;
    widget.auth.addListener(_onAuthEvent);
    _reloadFriends();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthEvent);
    _query.dispose();
    super.dispose();
  }

  // Web 5 Ağustos dersi: form tam bir görünüm, hesap değişimini mount'ta
  // kalarak atlatabilir — arkadaş listesi user.id değişince yeniden çekilir.
  void _onAuthEvent() {
    final id = widget.auth.user?.id;
    if (id == _lastUserId) return;
    _lastUserId = id;
    if (mounted) setState(() => _friends = null);
    _reloadFriends();
  }

  void _reloadFriends() {
    widget.friends.friends().then((f) {
      if (!mounted) return;
      setState(() {
        if (f != null) {
          _friends = f;
        } else {
          _friends ??= const [];
        }
      });
    });
  }

  void _setPlayerCount(int n) {
    if (n == _playerCount) return;
    setState(() {
      _playerCount = n;
      // 2↔4 kuralı tamamen farklı — seçimler sıfırlanır (web).
      _selected.clear();
      _showAiRow = false;
      _aiSelected = false;
    });
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_playerCount == 2) {
        if (_selected.contains(friendId)) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..add(friendId);
        }
        return;
      }
      if (_selected.contains(friendId)) {
        _selected.remove(friendId);
        return;
      }
      final cap = _aiSelected ? 2 : 3; // YZ koltuğu insan yerini kapatır
      if (_selected.length >= cap) return;
      _selected.add(friendId);
    });
  }

  bool get _canSubmit =>
      _playerCount == 2 ? _selected.length == 1 : _selected.length >= 2;

  Future<void> _submit({required bool withAiLastSlot}) async {
    final user = widget.auth.user;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final slots = [
        NewGameSlot.human(user.id),
        for (final id in _selected) NewGameSlot.human(id),
        if (withAiLastSlot) const NewGameSlot.ai(),
      ];
      await widget.onlineGames.create(_playerCount, slots);
      if (!mounted) return;
      final friends = _friends ?? const <FriendRow>[];
      setState(() => _sentTo = (
            names: [
              for (final id in _selected)
                friends
                        .where((f) => f.friendId == id)
                        .map((f) => f.name)
                        .firstOrNull ??
                    'Bir arkadaşın',
            ],
            withAi: withAiLastSlot,
          ));
    } catch (e) {
      if (mounted) setState(() => _error = friendErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_playerCount == 2 || _selected.length == 3) {
      await _submit(withAiLastSlot: false);
      return;
    }
    // 4 kişilik + 2 arkadaş
    if (_aiSelected) {
      await _submit(withAiLastSlot: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFB8C2D1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('4. koltuk Yapay Zeka ile doldurulacak, tamam mı?',
                  style: TextStyle(fontSize: 13, height: 1.5, color: _text)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: NeoButton(
                    label: 'EVET',
                    variant: NeoButtonVariant.accent,
                    fontSize: 11,
                    letterSpacing: 1,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeoButton(
                    label: 'HAYIR',
                    variant: NeoButtonVariant.neutral,
                    fontSize: 11,
                    letterSpacing: 1,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await _submit(withAiLastSlot: true);
    } else {
      // Hayır: YZ satırı kalıcı görünür olur, bir daha sorulmaz (web).
      setState(() => _showAiRow = true);
    }
  }

  void _openFriendsModal() {
    showFriendsModal(
      context,
      friends: widget.friends,
      auth: widget.auth,
      stats: widget.stats,
      games: widget.games,
      chat: widget.chat,
      initialTab: FriendsTab.search,
    ).then((_) => _reloadFriends());
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentTo;
    if (sent != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.check_circle, size: 48, color: _accent),
          const SizedBox(height: 12),
          const Text('Davetiniz gönderilmiştir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _text)),
          const SizedBox(height: 8),
          Text(
            '${sent.names.join(', ')} yanıt verince oyun başlayacak.'
            '${sent.withAi ? ' 4. koltuk Yapay Zeka.' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 16),
          Center(
            child: NeoButton(
              label: 'TAMAM',
              variant: NeoButtonVariant.accent,
              fontSize: 12,
              letterSpacing: 1,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              onPressed: widget.onCreated,
            ),
          ),
        ],
      );
    }

    final friends = _friends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('OYUNCU SAYISI'),
        const SizedBox(height: 8),
        Row(children: [
          for (final n in const [2, 4]) ...[
            if (n == 4) const SizedBox(width: 8),
            Expanded(
              child: NeoButton(
                label: '$n OYUNCULU',
                variant: _playerCount == n
                    ? NeoButtonVariant.accent
                    : NeoButtonVariant.neutral,
                fontSize: 13,
                letterSpacing: 1,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: () => _setPlayerCount(n),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        _SectionLabel(_playerCount == 2
            ? 'ARKADAŞINI SEÇ'
            : 'ARKADAŞLARINI SEÇ (${_selected.length}/3)'),
        const SizedBox(height: 8),
        if (friends == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Yükleniyor…',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
          )
        else if (friends.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Henüz hiç arkadaşın yok.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
          ),
          Center(
            child: NeoButton(
              label: 'ARKADAŞ EKLE / DAVET ET',
              variant: NeoButtonVariant.accent,
              fontSize: 11,
              letterSpacing: 1,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onPressed: _openFriendsModal,
            ),
          ),
        ] else ...[
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            style: kInputTextStyle,
            decoration: kInputDecoration(hint: 'İsim ya da takma ad ara…'),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(children: [
                ...(() {
                  final q = trLower(_query.text.trim());
                  final filtered = [
                    for (final f in friends)
                      if (trLower(f.name).contains(q)) f
                  ];
                  if (filtered.isEmpty) {
                    return [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Kimse bulunamadı.',
                            style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 11,
                                color: _muted)),
                      ),
                    ];
                  }
                  return [
                    for (final f in filtered)
                      _selectableRow(
                        key: ValueKey('friend-${f.friendId}'),
                        avatar:
                            KAvatar(url: f.avatarUrl, name: f.name, size: 28),
                        name: f.name,
                        checked: _selected.contains(f.friendId),
                        enabled: true,
                        onTap: () => _toggleFriend(f.friendId),
                      ),
                  ];
                })(),
                if (_playerCount == 4 && _showAiRow)
                  _selectableRow(
                    key: const ValueKey('ai-row'),
                    avatar: _robotAvatar(28),
                    name: 'Yapay Zeka',
                    checked: _aiSelected,
                    // 3 arkadaş seçiliyken YZ işaretlenemez (web simetri notu).
                    enabled: _selected.length < 3,
                    onTap: () {
                      if (_selected.length >= 3) return;
                      setState(() => _aiSelected = !_aiSelected);
                    },
                  ),
              ]),
            ),
          ),
        ],
        if (_playerCount == 4) ...[
          const SizedBox(height: 6),
          const Text(
            "En az 2 arkadaş seçmelisin. 3. oyuncuyu seçmeden Davet Gönder'e "
            'basarsan 4. oyuncu Yapay Zeka olur.',
            style: TextStyle(
                fontFamily: 'SpaceMono', fontSize: 10, color: _muted),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: kRed)),
        ],
        const SizedBox(height: 16),
        if (friends != null && friends.isNotEmpty) ...[
          GestureDetector(
            onTap: _openFriendsModal,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(children: [
                Icon(Icons.add, size: 18, color: _accent),
                SizedBox(width: 8),
                Text('Arkadaş Ekle',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _accent)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: NeoButton(
              label: _busy ? 'GÖNDERİLİYOR…' : 'DAVET GÖNDER',
              variant: NeoButtonVariant.accent,
              fontSize: 13,
              letterSpacing: 2,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: (!_canSubmit || _busy) ? null : _handleSubmit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NeoButton(
              label: 'VAZGEÇ',
              variant: NeoButtonVariant.neutral,
              fontSize: 13,
              letterSpacing: 2,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: _busy ? null : widget.onCancel,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _selectableRow({
    required Key key,
    required Widget avatar,
    required String name,
    required bool checked,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      key: key,
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _text)),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: checked ? _accent : Colors.white,
                border: Border.all(
                    color: checked ? _accent : _muted, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Robot avatarı — PendingGameCard/PlayerAvatarRow'daki aynı görsel dil.
Widget _robotAvatar(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _border),
      ),
      child: Icon(Icons.smart_toy_outlined,
          size: size * 0.6, color: _muted),
    );

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        trUpper(text),
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          letterSpacing: 1.5,
          color: _muted,
        ),
      );
}
