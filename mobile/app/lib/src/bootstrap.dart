// Uygulama açılış kablolaması — main() ile UI arasındaki tek köprü.
//
// Widget testleri KelimekiApp'i sahte bir AppServices ile pump edebilsin
// diye tüm dış dünya (Supabase, asset, sürüm kapısı) burada toplanır.
import 'package:flutter/services.dart' show AssetBundle;
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/version_gate.dart';
import 'data/auth_service.dart';
import 'data/chat_api.dart';
import 'data/cloud_save_repo.dart';
import 'data/dictionary_loader.dart';
import 'data/feedback_api.dart';
import 'data/friend_invite_inbox.dart';
import 'data/friends_api.dart';
import 'data/games_api.dart';
import 'data/league_rewards_api.dart';
import 'data/online_games_api.dart';
import 'data/stats_api.dart';
import 'data/meaning_store.dart';
import 'data/supabase_client.dart';
import 'storage/app_storage.dart';
import 'util/online_status.dart';

class AppServices {
  /// Sözlük — açılışta fire-and-forget başlar, oyun başlatma bekler
  /// (web'deki preloadWordSet/isWordSetReady deseni).
  final Future<SetWordSource> dictionary;

  /// Kelime anlamları — asset'teki SQLite'ı İLK SORGUDA açar (açılışta
  /// hiçbir maliyeti yok), bu yüzden Future değil doğrudan nesne.
  final MeaningStore meanings;

  /// null = Supabase yapılandırılmamış → tam offline mod.
  final SupabaseClient? supabase;

  /// Oturum/profil durumu — web AuthProvider'ın eşleniği. Supabase
  /// yapılandırılmamışsa `configured=false` olur ve hesap UI'ı hiç çizilmez.
  final AuthService auth;

  final VersionGateStatus versionGate;

  /// Bağlantı durumu — web `useOnlineStatus` portu. Çevrimdışı mesajlarının
  /// ANINDA çıkması için (bkz. util/online_status.dart).
  final OnlineStatus onlineStatus;

  /// Depolama — açılışta fire-and-forget açılır (sözlükle aynı desen);
  /// widget testleri null geçebilir (yalnızca durum satırı gizlenir).
  final Future<AppStorage>? storage;

  /// Girişli kullanıcının sunucu kayıtları (`local_game_saves`) — Supabase
  /// yapılandırılmamışsa null (tam offline mod, yalnızca misafir slotu).
  /// Testler sahte bir gateway'li repo geçer.
  final CloudSaveRepo? cloudSaves;

  /// Bitmiş/terk edilmiş oyun kayıtları (`games` + `game_finishes`) —
  /// depolama açıldıktan sonra kurulur (kuyruk deposuna ihtiyaç duyar),
  /// bu yüzden Future. Supabase yoksa null (kayıt tutulmaz).
  final Future<GamesRepo>? games;

  /// Skor kartı / k-lig verisi — Supabase yoksa null (menüde bu satırlar
  /// hiç çizilmez).
  final StatsRepo? stats;

  /// k-lig ödül/rütbe kutlamaları (`league_rewards`) — Supabase yoksa null
  /// (misafirde de kullanılmaz: satırlar sunucuda hesaba bağlı üretilir,
  /// kutlama girişten sonraki ilk kontrolde çıkar).
  final LeagueRewardsRepo? leagueRewards;

  /// Arkadaşlık sistemi — Supabase yoksa null (tamamen online bir özellik;
  /// hesap menüsündeki "Arkadaşlar" satırı hiç çizilmez).
  final FriendsRepo? friends;

  /// Canlı oyun davet/kabul akışı — Supabase yoksa null (ARKADAŞINLA
  /// sekmesi girişsiz uyarı/giriş çağrısı gösterir).
  final OnlineGamesRepo? onlineGames;

  /// Oyun içi mesajlaşma (yalnızca Canlı oyunlarda) — Supabase yoksa null
  /// (Board footer'ındaki "Mesajlaşma" butonu hiç çizilmez).
  final ChatRepo? chat;

  /// Gelen arkadaş daveti linkleri (kelimeki://davet/... ve
  /// kelimeki.com/davet/...) — token'ları `pending_events`e kuyruklar,
  /// SetupScreen işler. Depolamasız test ortamında null.
  final FriendInviteInbox? inviteInbox;

  /// "Görüş Bildir" — GamesRepo'nun aksine Supabase YOKKEN de dolu
  /// (gateway'i null olur, mesajlar kuyrukta bekler — web feedbackSync'in
  /// "Supabase hiç yapılandırılmamışken de kuyrukla" davranışı); yalnızca
  /// depolamasız widget testlerinde null.
  final FeedbackRepo? feedback;

  const AppServices({
    required this.onlineStatus,
    required this.dictionary,
    required this.meanings,
    required this.auth,
    required this.supabase,
    required this.versionGate,
    this.storage,
    this.cloudSaves,
    this.games,
    this.stats,
    this.leagueRewards,
    this.feedback,
    this.friends,
    this.inviteInbox,
    this.onlineGames,
    this.chat,
  });
}

Future<AppServices> bootstrap(AssetBundle bundle) async {
  // Sözlük ve depolama ilk kareyi BEKLETMEZ — Future olarak taşınır.
  final dictionary = loadDictionary(bundle);
  final meanings = MeaningStore(bundle: bundle);
  final storage = AppStorage.open();
  final supabase = await initSupabase();
  final auth = AuthService(supabase);
  final versionGate = await checkVersionGate(supabase);
  return AppServices(
    onlineStatus: OnlineStatus(),
    dictionary: dictionary,
    meanings: meanings,
    auth: auth,
    supabase: supabase,
    versionGate: versionGate,
    storage: storage,
    cloudSaves:
        supabase != null
            ? CloudSaveRepo(SupabaseCloudSaveGateway(supabase),
                mirrorStore: storage.then((s) => s.cloudMirror),
                cacheStore: storage.then((s) => s.cloudCache),
                deleteQueue: storage.then((s) => s.cloudDeletes))
            : null,
    games: supabase != null
        ? storage.then((s) => GamesRepo(SupabaseGamesGateway(supabase), s.queue))
        : null,
    stats: supabase != null ? StatsRepo(SupabaseStatsGateway(supabase)) : null,
    leagueRewards: supabase != null
        ? LeagueRewardsRepo(SupabaseLeagueRewardsGateway(supabase))
        : null,
    feedback: FeedbackRepo(
      supabase != null ? SupabaseFeedbackGateway(supabase) : null,
      storage,
    ),
    friends:
        supabase != null ? FriendsRepo(SupabaseFriendsGateway(supabase)) : null,
    onlineGames: supabase != null
        ? OnlineGamesRepo(SupabaseOnlineGamesGateway(supabase))
        : null,
    chat: supabase != null ? ChatRepo(SupabaseChatGateway(supabase)) : null,
    inviteInbox: createFriendInviteInbox(storage),
  );
}
