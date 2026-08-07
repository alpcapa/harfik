// Canlı oyun testlerinin paylaştığı sahte uçlar — davet/kabul akışı
// (live_games_test) ve oynanış ekranı (online_game_screen_test) aynı
// gateway'i kullanıyor.
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

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

  @override
  Future<List<Map<String, Object?>>> listMine() async {
    _maybeFail();
    listCalls++;
    return [for (final r in rows) Map<String, Object?>.of(r)];
  }

  @override
  Future<String> create(
      int playerCount, List<Map<String, Object?>> slots) async {
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

  @override
  void Function() subscribe(void Function() onChange) {
    subscribeCount++;
    return () => unsubscribeCount++;
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

const Map<String, Object?> slotAi = {'type': 'ai'};

Map<String, Object?> gameRow({
  required String id,
  required String myId,
  String createdBy = 'esiner',
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
