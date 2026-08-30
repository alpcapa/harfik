// Canlı tahtayı açan TEK kapı fonksiyonu — Faz 3'te çıkarıldı.
//
// 28 Ağustos 2026'da `live_games_tab.dart` → `_openGame`'in yorumu bunu
// önceden görmüştü: *"Sürüm B Canlı tahtayı açan İKİNCİ bir kapı (bildirime
// dokun → doğru oyunu aç) ekliyor"* ve rozet tazelemesi tam bu yüzden
// callback yerine `didPopNext`e bağlanmıştı. İkinci kapı geldi; ekranın
// 14 parametrelik kurulumunu iki yerde tekrarlamak, birinin sessizce eksik
// kalmasıyla sonuçlanırdı (bu repoda "ikiz kopya" hatası tam böyle doğuyor)
// — kurulum artık TEK burada, iki kapı da bunu çağırıyor.
//
// Dönüş sonrası işler bilerek DIŞARIDA: `LiveGamesTab` dönüşte kendi
// listesini tazeliyor (`_reload`), Setup rozeti `didPopNext`le kendini
// tazeliyor — bu fonksiyon yalnızca AÇAR.
import 'package:flutter/material.dart';

import '../../bootstrap.dart';
import '../../data/online_games_api.dart';
import 'online_game_screen.dart';

Future<void> openOnlineGameScreen(
  BuildContext context, {
  required AppServices services,
  required OnlineGame game,
}) async {
  final repo = services.onlineGames;
  final user = services.auth.user;
  if (repo == null || user == null) return;
  final words = await services.dictionary;
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    // Rota adı hata telemetrisinin "hangi ekranda?" alanı — değiştirme
    // (bkz. app.dart, ErrorReporterRouteObserver).
    settings: const RouteSettings(name: 'online-game'),
    builder: (_) => OnlineGameScreen(
      game: game,
      myUserId: user.id,
      onlineGames: repo,
      words: words,
      meanings: services.meanings,
      auth: services.auth,
      stats: services.stats,
      games: services.games,
      feedback: services.feedback,
      friends: services.friends,
      chat: services.chat,
      storage: services.storage,
      leagueRewards: services.leagueRewards,
      onlineStatus: services.onlineStatus,
    ),
  ));
}
