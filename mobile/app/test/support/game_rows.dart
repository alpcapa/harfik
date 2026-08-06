// `games` satırı/oyuncu snapshot'ı üreten ortak test yardımcıları —
// oyun geçmişi (5a) ve beğeni/sohbet (5b) testleri paylaşıyor.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_games_gateway.dart';

/// Yalnızca liste sütunları (web ile aynı set — board_snapshot/messages yok).
Map<String, Object?> gameRow({
  required String id,
  String userId = 'u-me',
  String createdAt = '2026-08-01T12:00:00.000Z',
  int playerCount = 2,
  int playerScore = 238,
  int aiScore = 179,
  int? rank = 1,
  bool surrendered = false,
  String? onlineGameId,
  List<Map<String, Object?>>? players,
  int messageCount = 0,
}) =>
    {
      'id': id,
      'user_id': userId,
      'created_at': createdAt,
      'player_count': playerCount,
      'player_score': playerScore,
      'ai_score': aiScore,
      'rank': rank,
      'surrendered': surrendered,
      'online_game_id': onlineGameId,
      'players': players,
      'message_count': messageCount,
    };

Map<String, Object?> snap(String name, int score,
        {bool ai = false, bool surrendered = false, int colorIndex = 0}) =>
    {
      'name': name,
      'score': score,
      'is_ai': ai,
      'surrendered': surrendered,
      'colorIndex': colorIndex,
    };

Future<GamesRepo> newRepo(FakeGamesGateway gw) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => DateTime.now().millisecondsSinceEpoch,
  );
  return GamesRepo(gw, storage.queue);
}

/// Widget testlerinde repoyu HAZIRLARKEN gerçek sqflite I/O'sunun sahte
/// zamanla (fake-async) kilitlenmemesi için: `runAsync` gerçek saati
/// kullandırır. Doğrudan `await newRepo(...)` bazı ekranlarda testi süresiz
/// asıyor (5c'de RecentGamesSection'da yaşandı) — widget testinde HER ZAMAN
/// bunu kullan.
Future<GamesRepo> newRepoForWidget(
    WidgetTester tester, FakeGamesGateway gw) async {
  late GamesRepo repo;
  await tester.runAsync(() async {
    repo = await newRepo(gw);
  });
  return repo;
}
