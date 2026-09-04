// Canlı oyun testlerinin paylaştığı sahte uçlar — davet/kabul akışı
// (live_games_test), oynanış ekranı (online_game_screen_test) ve oyun içi
// mesajlaşma (chat_test/online_game_chat_test) aynı gateway'leri kullanıyor.
import 'package:kelimeki/src/data/chat_api.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'dart:async';

class FakeOnlineGamesGateway implements OnlineGamesGateway {
  // ── Liste tarafı (davet/kabul) ──────────────────────────────────────────
  List<Map<String, Object?>> rows = [];
  List<Map<String, Object?>> turnRows = [];
  List<Map<String, Object?>> deadlineRows = [];

  final createdCounts = <int>[];
  final createdSlots = <List<Map<String, Object?>>>[];
  final notified = <String>[];
  final responded = <(String, bool)>[];
  final turnTimeoutChecks = <String>[];
  final inviteExpiryChecks = <String>[];

  Object? failWith;
  Object? notifyFailWith;
  int listCalls = 0;
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  /// Süpürme RPC'lerinin sunucu etkisini taklit etmek için.
  void Function(String gameId)? onCheckInviteExpiry;
  void Function(String gameId)? onCheckTurnTimeout;

  // ── Oynanış tarafı ──────────────────────────────────────────────────────
  Map<String, Object?>? stateRow;
  List<Map<String, Object?>> rackRows = [];
  List<Map<String, Object?>> moveRows = [];

  final submitted = <Map<String, Object?>>[];
  final aiTriggers = <String>[];

  /// `set_online_game_platform` çağrıları — (gameId, platform).
  final platformReports = <(String, String)>[];

  /// Telemetri hatasının oyunu ETKİLEMEDİĞİNİ kanıtlamak için.
  Object? platformFailWith;
  int gameStateCalls = 0;
  int gameSubscribeCount = 0;
  int gameUnsubscribeCount = 0;
  Object? submitFailWith;
  Object? aiFailWith;
  Object? gameLoadFailWith;

  /// subscribeGame'in verdiği geri çağrı — testler "sunucudan olay geldi"
  /// senaryosunu bununla sürer.
  void Function()? gameListener;

  void _maybeFail() {
    final f = failWith;
    if (f != null) throw f;
  }

  /// true ise liste ucu HİÇ CEVAP VERMEZ (asılı future) — "ağ cevabını
  /// beklemeden karar veriliyor mu?" testleri için.
  bool listHangs = false;

  /// İlk N `listMine()` çağrısı AĞ hatasıyla düşer, sonrakiler normal —
  /// "yarıda kalan istek boş liste gibi okunmasın" (21 Ağustos 2026).
  int netFailFirst = 0;
  int netFailCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listMine() async {
    // Sayaç EN BAŞTA: "tekrar denendi mi?" testleri düşen denemeleri de
    // saymak zorunda.
    listCalls++;
    _maybeFail();
    if (netFailCalls < netFailFirst) {
      netFailCalls++;
      throw Exception('ClientException: Failed to fetch');
    }
    if (listHangs) return Completer<List<Map<String, Object?>>>().future;
    return [for (final r in rows) Map<String, Object?>.of(r)];
  }

  /// `create_online_game`in KENDİ reddi (ör. "Yalnızca arkadaşlarını davet
  /// edebilirsin.") — genel `failWith`ten ayrı, çünkü ekran o sırada
  /// yüklenmiş durumda ve öteki uçların çalışmaya devam etmesi gerekiyor.
  Object? createError;

  @override
  Future<String> create(
      int playerCount, List<Map<String, Object?>> slots) async {
    final ce = createError;
    if (ce != null) throw ce;
    _maybeFail();
    createdCounts.add(playerCount);
    createdSlots.add(slots);
    return 'new-game';
  }

  @override
  Future<void> notifyGameInvite(String gameId) async {
    final f = notifyFailWith;
    if (f != null) throw f;
    notified.add(gameId);
  }

  @override
  Future<void> respondInvite(String inviteId, bool accept) async {
    _maybeFail();
    responded.add((inviteId, accept));
  }

  @override
  Future<List<Map<String, Object?>>> turns(List<String> gameIds) async =>
      [for (final r in turnRows) if (gameIds.contains(r['online_game_id'])) r];

  @override
  Future<List<Map<String, Object?>>> deadlines(List<String> gameIds) async => [
        for (final r in deadlineRows)
          if (gameIds.contains(r['online_game_id'])) r
      ];

  @override
  Future<void> checkTurnTimeout(String gameId) async {
    turnTimeoutChecks.add(gameId);
    onCheckTurnTimeout?.call(gameId);
  }

  @override
  Future<void> checkInviteExpiry(String gameId) async {
    inviteExpiryChecks.add(gameId);
    onCheckInviteExpiry?.call(gameId);
  }

  /// Biten oyunun ham koltukları — oyun geçmişindeki "Tekrar Oyna" testleri
  /// doldurur. Varsayılan `null` = "erişilemedi", yani rövanşın hata dalı.
  Map<String, List<Map<String, Object?>>?> finishedSlots = {};

  @override
  Future<List<Map<String, Object?>>?> finishedGameSlots(
      String onlineGameId) async =>
      finishedSlots[onlineGameId];

  /// Bitişi görülmemiş oyunlar — testler tek tek doldurabilsin diye alan.
  List<String> unseenFinished = const [];

  /// `markFinishesSeen` çağrıları: `null` = toplu (sekme ziyareti),
  /// dolu = tek oyun (bitiş modalı). Sıra ve içerik testlerde sınanıyor.
  final List<String?> finishesSeenCalls = [];

  /// true ise işaretleme AĞ HATASI verir — "yalnızca sunucu onaylarsa
  /// sıfırla" kuralının negatif eşi için.
  bool failMarkFinishesSeen = false;

  /// true ise görülmemiş çekimi AĞ HATASI verir — "haber düşse de sayılar
  /// gelmeli" kuralının negatif eşi.
  bool unseenFinishedThrows = false;

  @override
  Future<List<String>> unseenFinishedGames() async {
    if (unseenFinishedThrows) throw Exception('ağ');
    return unseenFinished;
  }

  @override
  Future<void> markFinishesSeen({String? onlineGameId}) async {
    if (failMarkFinishesSeen) throw Exception('ağ');
    finishesSeenCalls.add(onlineGameId);
    unseenFinished = const [];
  }

  @override
  void Function() subscribe(void Function() onChange,
      {void Function()? onResubscribe}) {
    subscribeCount++;
    lastOnChange = onChange;
    lastOnResubscribe = onResubscribe;
    onChanges.add(onChange);
    if (onResubscribe != null) onResubscribes.add(onResubscribe);
    return () {
      unsubscribeCount++;
      onChanges.remove(onChange);
      if (onResubscribe != null) onResubscribes.remove(onResubscribe);
    };
  }

  /// Testler "sunucudan Realtime olayı geldi"yi buradan sürer.
  void Function()? lastOnChange;

  /// Testler kanalın KOPUP yeniden bağlanmasını buradan taklit eder.
  void Function()? lastOnResubscribe;

  /// ⚠ AYNI ANDA BİRDEN FAZLA ABONE OLABİLİR — `lastOn*` yalnızca SONUNCUSUNU
  /// tutar ve bu 27 Ağustos 2026'da bir testi sessizce yanlış yere baktırdı:
  /// `SetupScreen` (rozet) ve `LiveGamesTab` (liste) ikisi de abone oluyor,
  /// sekme açıkken `lastOnResubscribe` LİSTENİNKİNİ gösteriyordu; test
  /// listeyi tetikleyip rozetten sonuç bekliyordu. Birden fazla abonenin
  /// olabildiği yerde `fireAllOn*` kullan.
  final onChanges = <void Function()>[];
  final onResubscribes = <void Function()>[];

  void fireAllOnChange() {
    for (final f in [...onChanges]) {
      f();
    }
  }

  void fireAllOnResubscribe() {
    for (final f in [...onResubscribes]) {
      f();
    }
  }

  @override
  Future<Map<String, Object?>?> gameState(String gameId) async {
    final f = gameLoadFailWith;
    if (f != null) throw f;
    gameStateCalls++;
    return stateRow;
  }

  @override
  Future<List<Map<String, Object?>>> myRack(String gameId) async => rackRows;

  @override
  Future<List<Map<String, Object?>>> moves(String gameId) async => moveRows;

  @override
  Future<void> triggerAiTurn(String gameId) async {
    final f = aiFailWith;
    if (f != null) throw f;
    aiTriggers.add(gameId);
  }

  @override
  Future<void> setPlatform(String gameId, String platform) async {
    final f = platformFailWith;
    if (f != null) throw f;
    platformReports.add((gameId, platform));
  }

  @override
  Future<void> submitMove({
    required String gameId,
    required String action,
    List<Map<String, Object?>>? placements,
    List<String>? exchangeLetters,
    List<String> words = const [],
    List<Map<String, Object?>>? wordScores,
    int basePoints = 0,
    List<Map<String, Object?>> lostShares = const [],
  }) async {
    final f = submitFailWith;
    if (f != null) throw f;
    submitted.add({
      'gameId': gameId,
      'action': action,
      'placements': placements,
      'exchangeLetters': exchangeLetters,
      'words': words,
      'wordScores': wordScores,
      'basePoints': basePoints,
      'lostShares': lostShares,
    });
  }

  @override
  void Function() subscribeGame(String gameId, void Function() onChange) {
    gameSubscribeCount++;
    gameListener = onChange;
    return () {
      gameUnsubscribeCount++;
      gameListener = null;
    };
  }
}

class FakeChatGateway implements ChatGateway {
  List<Map<String, Object?>> rows = [];
  List<String> mutes = [];
  List<String> activeReports = [];
  final sent = <(String, String)>[];
  final mutedCalls = <(String, String, bool)>[];
  final reportedCalls = <(String, String, String)>[];
  final withdrawnCalls = <String>[];

  Object? messagesFailWith;
  Object? sendFailWith;
  Object? mutesFailWith;
  Object? reportsFailWith;
  Object? muteFailWith;
  Object? reportFailWith;
  Object? withdrawFailWith;

  /// subscribe'ın verdiği geri çağrı — testler "sunucudan yeni mesaj geldi"
  /// senaryosunu bununla sürer.
  void Function(Map<String, Object?> row)? insertListener;
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  /// Kaç kez çekildi — ön plana dönüş tazelemesi bunu artırmalı.
  int messagesCalls = 0;

  @override
  Future<List<Map<String, Object?>>> messages(String gameId) async {
    messagesCalls++;
    final f = messagesFailWith;
    if (f != null) throw f;
    return rows;
  }

  @override
  Future<void> send(String gameId, String message) async {
    final f = sendFailWith;
    if (f != null) throw f;
    sent.add((gameId, message));
  }

  @override
  void Function() subscribe(
      String gameId, void Function(Map<String, Object?> row) onInsert) {
    subscribeCount++;
    insertListener = onInsert;
    return () => unsubscribeCount++;
  }

  @override
  Future<List<String>> myMutes() async {
    final f = mutesFailWith;
    if (f != null) throw f;
    return mutes;
  }

  @override
  Future<List<String>> myActiveReports() async {
    final f = reportsFailWith;
    if (f != null) throw f;
    return activeReports;
  }

  /// Kişi → kaynak oyun id'si. Sahte uç GERÇEK ucun sözleşmesini taklit
  /// etmek ZORUNDA (Parça 46'nın dersi): gerçek `myModeration` oyun id'sini
  /// de döndürüyor ve sessizden çıkarma o id'ye bağlı — sahte yalnızca
  /// kimlikleri döndürseydi, o bağın kopması testlerde görünmezdi.
  Map<String, String> moderationMuted = const {};
  Map<String, String> moderationReported = const {};
  Object? moderationFailWith;

  @override
  Future<({Map<String, String> muted, Map<String, String> reported})>
      myModeration() async {
    final f = moderationFailWith;
    if (f != null) throw f;
    return (muted: moderationMuted, reported: moderationReported);
  }

  @override
  Future<void> setMute(String gameId, String targetUserId, bool muted) async {
    final f = muteFailWith;
    if (f != null) throw f;
    mutedCalls.add((gameId, targetUserId, muted));
  }

  @override
  Future<void> report(
      String gameId, String targetUserId, String reason) async {
    final f = reportFailWith;
    if (f != null) throw f;
    reportedCalls.add((gameId, targetUserId, reason));
  }

  @override
  Future<void> withdrawReports(String targetUserId) async {
    final f = withdrawFailWith;
    if (f != null) throw f;
    withdrawnCalls.add(targetUserId);
  }
}

Map<String, Object?> chatRow({
  required String id,
  required String senderUserId,
  required String message,
  String? createdAt,
}) =>
    {
      'id': id,
      'sender_user_id': senderUserId,
      'message': message,
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    };

class FakeFriendsGateway implements FriendsGateway {
  @override
  String? currentUserId;
  FakeFriendsGateway({this.currentUserId = 'me'});

  List<Map<String, Object?>> friendsRows = [];
  final sentRequests = <String>[];

  @override
  Future<List<Map<String, Object?>>> listFriends() async => friendsRows;

  @override
  Future<String> sendRequest(String targetId) async {
    sentRequests.add(targetId);
    return 'pending';
  }

  @override
  Future<void> notifyFriendRequest(String friendId) async {}

  @override
  Future<List<Map<String, Object?>>> searchUsers(String query) async => [];
  @override
  Future<List<Map<String, Object?>>> listUsers(int offset, int limit) async =>
      [];
  @override
  Future<void> acceptRequest(String requesterId) async {}
  @override
  Future<void> deleteRelation(String otherId) async {}
  @override
  Future<List<Map<String, Object?>>> listIncomingRequests() async => [];
  @override
  Future<Map<String, Object?>?> relationRow(String targetId) async => null;
  @override
  Future<String?> createInviteToken() async => null;
  @override
  Future<String?> inviteInfo(String token) async => null;
  @override
  Future<String?> acceptInvite(String token) async => null;
}

// ── Satır kurucuları (list_my_online_games şekli) ───────────────────────────

Map<String, Object?> slotHuman(String userId,
        {String? name, String? relation, String? inviteStatus}) =>
    {
      'type': 'human',
      'user_id': userId,
      'name': name ?? userId,
      'avatar_url': null,
      'relation': relation,
      'invite_status': inviteStatus,
    };

/// Hesabı silinmiş bir oyuncunun koltuğu: uuid `online_games.slots` içinde
/// KALIR (koltuk eşlemesi ötekinin arşivi için gerekli) ama `profiles`
/// satırı gittiğinden `list_my_online_games` adı NULL döndürür.
Map<String, Object?> slotDeletedHuman(String userId) => {
      'type': 'human',
      'user_id': userId,
      'name': null,
      'avatar_url': null,
      'relation': null,
      'invite_status': null,
    };

const Map<String, Object?> slotAi = {'type': 'ai'};

/// `created_by` BİLEREK nullable: kurucusu hesabını silmiş bir oyunda sunucu
/// NULL döndürüyor (`on delete set null`, bkz. account-deletion kararı).
/// Koltuklardaki uuid ise silinmiyor — bu yüzden varsayılan koltuk kurgusu
/// `createdBy` null olsa bile kurucunun eski uuid'sini taşımaya devam eder,
/// tıpkı üretimdeki satır gibi.
Map<String, Object?> gameRow({
  required String id,
  required String myId,
  String? createdBy = 'esiner',
  int playerCount = 2,
  String status = 'active',
  String myRole = 'invitee',
  String? myInviteStatus,
  String? myInviteId,
  String? createdAt,
  List<Map<String, Object?>>? slots,
}) =>
    {
      'id': id,
      'created_by': createdBy,
      'player_count': playerCount,
      'status': status,
      'slots': slots ??
          [
            if (createdBy == null)
              slotDeletedHuman('silinmis-kurucu-uuid')
            else
              slotHuman(createdBy, name: 'Esiner', relation: 'accepted'),
            slotHuman(myId,
                name: 'Ironman', relation: 'self', inviteStatus: myInviteStatus),
          ],
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
      'my_role': myRole,
      'my_invite_status': myInviteStatus,
      'my_invite_id': myInviteId,
    };

OnlineGame game(Map<String, Object?> row) => OnlineGame.fromJson(row);

User fakeUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: '$id@ornek.com',
    );
