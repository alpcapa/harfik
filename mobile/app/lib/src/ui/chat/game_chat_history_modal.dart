// Bitmiş bir Canlı oyunun dondurulmuş sohbet kaydı — web
// `GameChatHistoryModal.tsx` portu. `GameHistoryModal` kartındaki sohbet
// rozetinden açılır; kayıt kalıcı olarak erişilebilir kalıyor (ileride
// uygunsuz paylaşım kontrolü için).
//
// Sıra: `games.messages` eskiden-yeniye dondurulmuş geliyor
// (`_finish_online_game_records`), burada ters çevrilip EN YENİ EN ÜSTTE
// gösteriliyor — mesajların her yerde aynı yönde okunması kuralı (bkz.
// build()'deki not). Bu satır bir dönem tersini söylüyordu ("arşiv bir
// döküm, ters sıralama yalnızca canlı sohbete özel") — o ayrım kullanıcı
// isteği değil bir yorumdu, 9 Ağustos 2026'da dört ekran birden hizalandı.
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
                  // En yeni mesaj en ÜSTTE (`.reversed`) — `games.messages`
                  // eskiden-yeniye dondurulmuş geliyor, `ChatThread` kendi
                  // tarafında sıralama yapmıyor.
                  //
                  // **Kural: mesajlar HER YERDE en yeniden eskiye (9 Ağustos
                  // 2026, kullanıcı isteği).** İstek daha önce üç kez
                  // iletilmiş ama her seferinde yalnızca canlı sohbet
                  // penceresine (`chat_modal.dart`) uygulanmış; arşiv
                  // "döküm" sayılıp bilerek dışarıda bırakılmıştı — o gerekçe
                  // kullanıcıdan gelmiyordu. Aynı gün web'in İKİ arşiv ekranı
                  // (`GameChatHistoryModal`/`AdminChatTranscriptModal`) da
                  // aynı yöne çevrildi; dördünden biri değişirse hepsi
                  // değişmeli. Burada kaydırma eşleşmesi gerekmiyor:
                  // `SingleChildScrollView` en üstte açılıyor, otomatik
                  // kaydırma yok (canlı sohbette sıra ile kaydırma birlikte
                  // değişmek ZORUNDA — bkz. chat_modal.dart).
                  messages: [
                    for (final m in messages.reversed)
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
