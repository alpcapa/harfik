// "Son Oynananlar"/"Son Oynadıklarım" listesinde katılımcı avatarlarını
// çözen SAF kural — web ikizi `src/utils/recentGameAvatars.ts` ile BİREBİR
// aynı mantık. Biri değişirse öteki de.
//
// NEDEN VAR (2 Eylül 2026, kullanıcı isteği): bu listede avatarlar HİÇ
// çıkmıyordu, yalnızca baş harfler. Gerekçe "dondurulmuş `games.players`
// anlık görüntüsü bilerek `avatar_url` taşımıyor, o snapshot girişli
// herkese açık" diye yazılıydı. Kullanıcı çürüttü ve HAKLI: `leaderboard`
// view'ı zaten `security_invoker = false` ile RLS'i bypass edip herkesin
// takma adını VE avatarını açıyor. Fotoğraf zaten herkese açıktı; burada
// gizlemek tutarsızlıktı.
//
// ⚠ SNAPSHOT'A DOKUNULMADI, migration GEREKMEDİ. İlk analizde "anahtar yok,
// migration şart" denmişti; yanlıştı. `games` satırı `online_game_id`
// taşıyor ve bitmiş çevrimiçi oyunların `online_games` satırı SİLİNMİYOR —
// canlı koltuklar (user_id + profillerden join'lenen avatar_url) duruyor.

/// Bir oyunun canlı koltuğu — yalnızca burada kullanılan alanlar.
class AvatarSlot {
  final String? name;
  final String? avatarUrl;
  const AvatarSlot({this.name, this.avatarUrl});
}

/// Çevrimiçi oyunlar için `online_game_id → (isim → avatar)` sözlüğü.
///
/// Eşleme OYUNUN KENDİ koltukları içinde yapılıyor, global bir isim
/// aramasıyla DEĞİL — takma adlar değiştirilebildiği için global arama, adı
/// sonradan devralan BAŞKA birinin yüzünü gösterebilirdi. Oyun içi
/// eşlemede en kötü ihtimal: oyuncu oyundan sonra adını değiştirmiştir,
/// donmuş ad canlı adla tutmaz, eşleşme olmaz ve baş harfe düşülür.
/// Yanlış yüz DEĞİL, zarif geri düşüş.
Map<String, Map<String, String>> buildOnlineAvatarIndex(
    Iterable<({String id, List<AvatarSlot> slots})> games) {
  final index = <String, Map<String, String>>{};
  for (final g in games) {
    final byName = <String, String>{};
    for (final s in g.slots) {
      final n = s.name;
      final a = s.avatarUrl;
      if (n != null && a != null) byName[n] = a;
    }
    if (byName.isNotEmpty) index[g.id] = byName;
  }
  return index;
}

/// Tek bir katılımcının avatarı. `null` → çağıran baş harfe düşer.
///
/// - **Yerel/YZ oyunu** (`onlineGameId == null`): tek insan koltuk HER ZAMAN
///   satırın sahibidir, yani ada hiç bakmadan hesabın kendi avatarı
///   verilebilir — kullanıcı sonradan takma adını değiştirse bile doğru
///   kalır. Misafir koltuk hariç: orada hesap yok, "?" yedeği korunur.
/// - **Çevrimiçi oyun**: oyunun kendi koltukları içinde isimle (yukarı bkz.).
String? avatarForRecentPlayer({
  required bool isAi,
  required bool isGuest,
  required String name,
  required String? onlineGameId,
  required Map<String, Map<String, String>> onlineIndex,
  required String? ownAvatarUrl,
}) {
  if (isAi || isGuest) return null;
  if (onlineGameId == null) return ownAvatarUrl;
  return onlineIndex[onlineGameId]?[name];
}
