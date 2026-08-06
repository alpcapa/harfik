// Bitmiş bir Canlı oyunun dondurulmuş sohbet kaydı — web
// `GameChatHistoryModal.tsx` portu. `GameHistoryModal` kartındaki sohbet
// rozetinden açılır; kayıt kalıcı olarak erişilebilir kalıyor (ileride
// uygunsuz paylaşım kontrolü için).
//
// Sıra: `games.messages` zaten eskiden-yeniye dondurulmuş geliyor
// (`_finish_online_game_records`) ve BURADA hiç ters çevrilmiyor — web'de
// bir dönem `.reverse()` vardı, aynı veriyi gösteren admin ekranıyla farklı
// sırada göründüğü için kaldırıldı. Ters sıralama yalnızca CANLI sohbet
// kutusuna özel (yazma alanı üstte olduğundan), arşiv bir döküm.
import 'package:flutter/material.dart';

import '../../data/games_api.dart';
import '../game/modal_shell.dart';
import 'chat_thread.dart';

const _muted = Color(0xFF5A6673);

Future<void> showGameChatHistory(
  BuildContext context, {
  required GamesRepo games,
  required String gameId,

  /// Bu kaydın geldiği Canlı oyun — sessize alma/şikayet rozetlerini
  /// çözmek için. Yerel/YZ oyunlarında null (zaten sohbet de olmaz), o
  /// durumda hiç rozet sorgusu yapılmaz.
  String? onlineGameId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => GameChatHistoryModal(
      games: games,
      gameId: gameId,
      onlineGameId: onlineGameId,
    ),
  );
}

class GameChatHistoryModal extends StatefulWidget {
  final GamesRepo games;
  final String gameId;
  final String? onlineGameId;

  const GameChatHistoryModal({
    super.key,
    required this.games,
    required this.gameId,
    this.onlineGameId,
  });

  @override
  State<GameChatHistoryModal> createState() => _GameChatHistoryModalState();
}

class _GameChatHistoryModalState extends State<GameChatHistoryModal> {
  List<GameChatMessage>? _messages;
  // Renk indeksi bazlı rozet kümeleri (kimlik istemciye hiç gelmez).
  Set<int> _mutedSeats = const {};
  Set<int> _reportedSeats = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final messages = await widget.games.messages(widget.gameId);
    if (!mounted) return;
    setState(() => _messages = messages);

    final ogid = widget.onlineGameId;
    if (ogid == null) return;
    final flags = await widget.games.chatFlags(ogid);
    if (!mounted) return;
    setState(() {
      _mutedSeats = flags.muted;
      _reportedSeats = flags.reported;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return KModal(
      title: 'Sohbet Geçmişi',
      child: messages == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Yükleniyor…',
                    style: TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: SingleChildScrollView(
                child: ChatThread(
                  emptyText: 'Bu oyunda hiç mesaj gönderilmemiş.',
                  messages: [
                    for (final m in messages)
                      ChatThreadMessage(
                        name: m.name,
                        colorIndex: m.colorIndex,
                        message: m.message,
                        createdAt: m.createdAt,
                        // Arşivde "kimin ekranı" kavramı yok — hepsi solda.
                        mine: false,
                        badge: _reportedSeats.contains(m.colorIndex)
                            ? ChatBadge.reported
                            : _mutedSeats.contains(m.colorIndex)
                                ? ChatBadge.muted
                                : null,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
