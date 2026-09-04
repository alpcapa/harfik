// Rövanş kadrosunun kurulması — "Tekrar Oyna" biten bir Canlı oyunun
// kadrosunu AYNEN yeni bir oyuna taşır.
//
// NEDEN AYRI DOSYA (4 Eylül 2026): bu mantık 2 Eylül'e kadar yalnızca
// `OnlineGameScreen.tsx`in içinde, oyun ekranına gömülü bir yardımcıydı.
// "Tekrar Oyna" oyun geçmişindeki aksiyon menüsüne de eklenince İKİNCİ bir
// çağıran doğdu (`GameHistoryModal.tsx`) ve kopyalamak bu depoda defalarca
// ayrışmayla sonuçlanan hata sınıfının ta kendisi olurdu — sıralama kuralı
// sessizce değişse iki yüzey farklı kadro kurar ve `create_online_game`
// birinde patlar, ötekinde patlamaz.
//
// ⚠ SIRA KURALIN KENDİSİ, kozmetik değil. `create_online_game`in üç kısıtı:
//   (1) İlk koltuk ÇAĞIRAN olmak zorunda. Biten oyunu ben kurmamış
//       olabilirim (davet edilen taraf da rövanş açabilir), o yüzden kendimi
//       her hâlükârda başa alıyorum.
//   (2) 4 kişilikte YZ yalnız SON koltukta olabilir. İnsanları kendi
//       aralarındaki sırayla koruyup YZ'leri sona yazmak bunu kendiliğinden
//       sağlıyor.
//   (3) 2 kişilikte YZ zaten olamaz — biten oyun geçerliyse yenisi de
//       geçerli, ayrıca kontrol gerekmiyor.
//
// ⚠ RPC'ye YALNIZCA `type` + `user_id` gider. `list_my_online_games`in
// eklediği `name`/`avatar_url`/`relation`/`invite_status` alanları görüntü
// içindir; gönderilirse sunucu onları yok saymaz, gövdeyi şişirir ve
// ileride bir kısıt eklendiğinde sessizce reddedilme riski doğar.
//
// Dart ikizi: `mobile/app/lib/src/util/rematch_slots.dart`.
// Parite kontrolü: `npm run verify-rematch-slots`.
import type { OnlineGameSlot } from '../lib/database.types';

/**
 * Biten bir Canlı oyunun koltuklarından rövanş kadrosunu kurar.
 *
 * @param slots     Biten oyunun `online_games.slots` değeri.
 * @param myUserId  Rövanşı açan (çağıran) kullanıcı.
 * @returns `create_online_game`e verilecek koltuklar — çağıran başta,
 *          öteki insanlar özgün sıralarında, YZ'ler sonda.
 */
export function buildRematchSlots(
  slots: OnlineGameSlot[],
  myUserId: string,
): OnlineGameSlot[] {
  const humans = slots.filter(
    (s): s is Extract<OnlineGameSlot, { type: 'human' }> => s.type === 'human',
  );
  const aiCount = slots.filter((s) => s.type === 'ai').length;
  return [
    { type: 'human', user_id: myUserId },
    ...humans
      .filter((s) => s.user_id !== myUserId)
      .map((s) => ({ type: 'human' as const, user_id: s.user_id })),
    ...Array.from({ length: aiCount }, () => ({ type: 'ai' as const })),
  ];
}

/**
 * Rövanşta karşıya çıkacak insan oyuncuların adları — onay/sonuç metni için.
 *
 * Adı olmayan bir koltuk için `Bir arkadaşın` döner: `online_games.slots`
 * ham hâlde isim TAŞIMAZ (o alanı `list_my_online_games` ekliyor), yani
 * geçmişten açılan rövanşta isimler ayrıca verilmek zorunda.
 */
export function rematchOpponentNames(
  slots: OnlineGameSlot[],
  myUserId: string,
): string[] {
  return slots
    .filter(
      (s): s is Extract<OnlineGameSlot, { type: 'human' }> =>
        s.type === 'human' && s.user_id !== myUserId,
    )
    .map((s) => s.name ?? 'Bir arkadaşın');
}

/** Kadroda YZ var mı — onay metni "4. koltuk yine Yapay Zeka olacak" diyor. */
export function rematchHasAi(slots: OnlineGameSlot[]): boolean {
  return slots.some((s) => s.type === 'ai');
}
