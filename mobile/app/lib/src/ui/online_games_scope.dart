// Canlı oyun deposunun AĞAÇ GENELİNDE erişilebilir hâli.
//
// NEDEN VAR (4 Eylül 2026): oyun geçmişindeki "Tekrar Oyna" (rövanş) bir
// `OnlineGamesRepo` istiyor, ama `GameHistoryModal`a kadar böyle bir bağımlılık
// hiç taşınmıyordu. Elden geçirmek İKİ ayrı zinciri birden değiştirmeyi
// gerektiriyordu — `app.dart → setup_screen → RecentGamesSection →
// showGameHistory` ve `account_button → showScoreCard → ScoreCardModal →
// showGameHistory` — yani altı-sekiz dosya ve her biri unutulmaya açık bir
// halka.
//
// **Bu depo o kararı zaten bir kez verdi ve parametreyle geçirmeyi ELEDİ:**
// bkz. `online_scope.dart` başlığı — *"yeni bir çağrı yerinde birinin
// unutması, hatayı sessizce geri getirirdi; bu kod tabanının en sık
// tekrarlayan hata sınıfı tam olarak bu"*. Aynı dosyanın kendi geçmişi de
// kanıt: `showGameHistory`nin beş çağrı yerinin dördü `auth` geçiyordu, biri
// geçmiyordu ve kafa kafaya çubuğu YALNIZCA orada sessizce kayboluyordu
// (Parça 185). Kapsam kökte bir kez kurulur, çağrı yerlerinin hiçbiri
// değişmez.
//
// Bilinçli olarak `maybeOf`: testler ve izole widget'lar kapsamsız da
// çalışabilmeli. Kapsam yoksa (ya da Supabase yapılandırılmamışsa `repo`
// null'dır) rövanş seçeneği hiç GÖSTERİLMEZ — çalışmayan bir kontrol koymak
// bu depoda bilerek kaçınılan bir şey.
library;

import 'package:flutter/widgets.dart';

import '../data/online_games_api.dart';

class OnlineGamesScope extends InheritedWidget {
  /// Supabase yapılandırılmamışsa null — çevrimdışı derlemede Canlı yok.
  final OnlineGamesRepo? repo;

  const OnlineGamesScope({super.key, required this.repo, required super.child});

  /// Kapsam yoksa `null` — çağıran rövanşı gizlemeli.
  static OnlineGamesRepo? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnlineGamesScope>()?.repo;

  @override
  bool updateShouldNotify(OnlineGamesScope oldWidget) =>
      !identical(oldWidget.repo, repo);
}
