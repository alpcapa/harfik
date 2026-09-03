// "Son Oynananlar"/"Son Oynadıklarım" listesinde katılımcı avatarlarını
// çözen SAF kural — web ve Flutter portu aynı mantığı okusun diye ayrı
// dosyada (port ikizi: `util/recent_game_avatars.dart`).
//
// NEDEN VAR (2 Eylül 2026, kullanıcı isteği): bu listede avatarlar HİÇ
// çıkmıyordu, yalnızca baş harfler. Gerekçe "dondurulmuş `games.players`
// anlık görüntüsü bilerek `avatar_url` taşımıyor, o snapshot girişli
// herkese açık" diye yazılıydı. Kullanıcı bu gerekçeyi çürüttü ve HAKLI:
// `leaderboard` view'ı zaten `security_invoker = false` ile RLS'i bypass
// edip herkesin takma adını VE avatarını açıyor (bkz.
// `20260722114853_lock_down_profiles_games_select.sql`). Yani fotoğraf
// zaten herkese açık; burada gizlemek tutarsızlıktı.
//
// ⚠ SNAPSHOT'A DOKUNULMADI, migration da GEREKMEDİ. İlk analizde "anahtar
// yok, migration şart" denmişti; yanlıştı. `games` satırı `online_game_id`
// taşıyor ve bitmiş çevrimiçi oyunların `online_games` satırı SİLİNMİYOR —
// yani canlı koltuklar (user_id + profillerden join'lenen avatar_url)
// duruyor ve okunabiliyor. Kapalı sanılan kapının yanında açık olanı vardı.

/** Bir oyunun canlı koltuğu — yalnızca burada kullanılan alanlar. */
export interface AvatarSlot {
  name: string | null;
  avatarUrl: string | null;
}

/**
 * Çevrimiçi oyunlar için `online_game_id → (isim → avatar)` sözlüğü.
 *
 * Eşleme OYUNUN KENDİ koltukları içinde yapılıyor, global bir isim
 * aramasıyla DEĞİL — takma adlar değiştirilebildiği için (bkz.
 * `AccountSettingsModal`) global arama, adı sonradan devralan BAŞKA birinin
 * yüzünü gösterebilirdi. Oyun içi eşlemede en kötü ihtimal: oyuncu oyundan
 * sonra adını değiştirmiştir, donmuş ad canlı adla tutmaz, eşleşme olmaz ve
 * baş harfe düşülür. Yanlış yüz DEĞİL, zarif geri düşüş.
 */
export function buildOnlineAvatarIndex(
  games: { id: string; slots: AvatarSlot[] }[],
): Map<string, Map<string, string>> {
  const index = new Map<string, Map<string, string>>();
  for (const g of games) {
    const byName = new Map<string, string>();
    for (const s of g.slots) {
      if (s.name && s.avatarUrl) byName.set(s.name, s.avatarUrl);
    }
    if (byName.size > 0) index.set(g.id, byName);
  }
  return index;
}

/**
 * Tek bir katılımcının avatarı. `null` → çağıran baş harfe düşer.
 *
 * İki yol var ve ikisi de İSİM EŞLEMESİNE DAYANMIYOR olabildiğince:
 * - **Yerel/YZ oyunu** (`onlineGameId == null`): tek insan koltuk HER ZAMAN
 *   satırın sahibidir (`games.user_id` = o kullanıcı, `buildGameRecord`
 *   yalnızca 0. koltuk insanken kayıt üretiyor). Yani ada hiç bakmadan
 *   hesabın kendi avatarı verilebilir — kullanıcı oyundan sonra takma adını
 *   değiştirmiş olsa bile doğru kalır. Misafir koltuk hariç: orada bir hesap
 *   yok, "?" yedeği korunuyor.
 * - **Çevrimiçi oyun**: oyunun kendi koltukları içinde isimle (yukarı bkz.).
 */
export function avatarForRecentPlayer(opts: {
  isAi: boolean;
  isGuest: boolean;
  name: string;
  onlineGameId: string | null;
  onlineIndex: Map<string, Map<string, string>>;
  ownAvatarUrl: string | null;
}): string | null {
  const { isAi, isGuest, name, onlineGameId, onlineIndex, ownAvatarUrl } = opts;
  if (isAi || isGuest) return null;
  if (onlineGameId == null) return ownAvatarUrl;
  return onlineIndex.get(onlineGameId)?.get(name) ?? null;
}
