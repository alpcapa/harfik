// Kelimeki — "Son Oynadıklarım": hem "Yapay Zeka ile" hem "Arkadaşınla"
// sekmelerinde, o sekmenin türüne uygun (yerel/Canlı) son 5 biten oyunu
// gösteren kompakt liste. Bir satıra tıklamak Tüm Oyunlarım'ı
// (`GameHistoryModal`) doğrudan o oyunun tahta önizlemesi açık hâlde açar —
// ayrı bir mini tahta/sohbet gösterimi yazmak yerine mevcut modalın tüm
// davranışını (paylaş/beğen/sohbet geçmişi) olduğu gibi devralır.
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { GUEST_PLAYER_NAME } from '../game/constants';
import { useAuth } from '../hooks/useAuth';
import { useOnlineStatus } from '../hooks/useOnlineStatus';
import { buildOnlineAvatarIndex, avatarForRecentPlayer } from '../utils/recentGameAvatars';
import { fetchMyGames } from '../lib/api';
import type { GameHistoryEntry } from '../lib/database.types';
import { leaguePoints, formatLeaguePoints } from '../utils/leaguePoints';
import { GameHistoryModal } from './GameHistoryModal';
import { PlayerAvatarRow } from './PlayerAvatarRow';
import { AiLevelBadge } from './AiLevelBadge';
import { scoreLine } from '../utils/scoreLine';
import { aiLevelForBadge } from '../utils/aiLevel';

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('tr-TR');
}

// `user.id:onlineOnly` -> son çekilen 5 oyunluk liste. Bkz. bileşen
// gövdesindeki not.
const recentGamesCache = new Map<string, GameHistoryEntry[]>();

// Eski (rank hiç yazılmamış) kayıtlarda bile en azından 1./2. tahmini için
// puan karşılaştırmasına düşülür — GameHistoryModal'daki fallbackPlayers'ın
// aynı ilkesi.
function rankFor(entry: GameHistoryEntry): number {
  return entry.rank ?? (entry.player_score >= entry.ai_score ? 1 : 2);
}

// 2 kişilik bir oyunda rakibin adını (varsa donmuş `players` anlık
// görüntüsünden) gösterir. Canlı 4 kişilik bir oyunda rakiplerin hepsi
// gerçek kişiler olabildiğinden (kimle oynadığını görmek anlamlı) hepsi
// yan yana virgülle yazılır; yerel (Yapay Zeka) 4 kişilik oyunlarda
// rakipler zaten hep YZ olduğundan bu bilgi eklemez, jenerik "N Kişilik
// Oyun" başlığına düşülür.
function titleFor(entry: GameHistoryEntry): string {
  if (!entry.players || entry.players.length < 2) return `${entry.player_count} Kişilik Oyun`;
  const meIdx = rankFor(entry) - 1;
  const others = entry.players.filter((_, i) => i !== meIdx);
  if (entry.player_count === 2 && others.length === 1) {
    return others[0].is_ai ? 'Yapay Zeka' : others[0].name;
  }
  if (entry.online_game_id && others.length > 0) {
    return others.map((p) => (p.is_ai ? 'Yapay Zeka' : p.name)).join(', ');
  }
  return `${entry.player_count} Kişilik Oyun`;
}

interface RecentGamesSectionProps {
  /** true: yalnızca Canlı (Arkadaşınla) oyunlar, false: yalnızca Yapay Zeka. */
  onlineOnly: boolean;
  /**
   * Verilirse, hiç bitmiş oyun yokken (ya da henüz yüklenmemişken) sessizce
   * `null` dönmek yerine bu metni gösterir — `LiveGamesTab`'daki "Son
   * Oynanan" sekmesi gibi, bileşenin TEK içerik olduğu bir sekme/alan boş
   * kaldığında kullanıcıya hâlâ bir şeyin orada olması gerektiğini
   * hatırlatmak için. Verilmezse eski davranış (boşsa hiçbir şey
   * render etmeme) aynen korunur — ör. "Yapay Zeka ile" sekmesinde ya da
   * Canlı oyun kurulum formunun altında, zaten başka içerik olduğundan
   * boş bir mesaj gösterilmesine gerek yok.
   */
  emptyMessage?: string;
  /**
   * Çevrimdışıyken, gösterilecek hiç oyun YOKKEN [emptyMessage]/hata metni
   * yerine render edilir (14 Ağustos 2026). Kullanım yerine göre farklı
   * konuşulduğu için düğüm olarak alınıyor: Canlı sekmesi düz bir
   * "İnternet bağlantısı yok" derken Yapay Zeka sekmesi tıklanabilir bir
   * "Hemen oyun aç." önerisi sunuyor (bkz. `utils/offlineNotice.ts`).
   * Elde önbellekten gelen bir liste VARSA o gösterilmeye devam eder —
   * çevrimdışı diye zaten çizilmiş bir listeyi silmek bilgi kaybı olurdu.
   */
  offlineNode?: ReactNode;
  /**
   * Çevrimiçi oyunların CANLI koltukları — avatar çözümü için (2 Eylül
   * 2026). `LiveGamesTab` bu listeyi zaten `list_my_online_games` ile
   * çekiyor ve o RPC durum filtresi TAŞIMIYOR, yani bitmiş oyunlar da
   * içinde; ikinci bir istek atmak yerine prop olarak iniyor. Yerel (YZ)
   * kullanımında verilmez — orada tek insan koltuk hesabın kendisidir.
   */
  onlineGames?: { id: string; slots: { name: string | null; avatarUrl: string | null }[] }[];
  /**
   * Bitişini kullanıcının GÖRMEDİĞİ oyunların `games.id`'leri — o satırlarda
   * etiketin YANINA kırmızı bir "YENİ" rozeti düşer (3 Eylül 2026,
   * kullanıcı isteği).
   *
   * ⚠ Yalnızca Canlı tarafta verilir. YZ oyunlarında bitişi ZATEN görüyorsun
   * (oyun senin cihazında bitiyor), yani orada "yeni" diye bir kavram yok —
   * kullanıcı kapsamı bilerek Canlı ile sınırladı.
   *
   * ⚠ Sekme AÇIKKEN sabit kalmalı: sunucudaki işaret sekmeye girer girmez
   * temizleniyor (rozet sıfırlansın diye), ama satırdaki rozetler ziyaret
   * boyunca DURMALI — yoksa kullanıcı tam bakarken gözünün önünde kaybolur.
   * Bu yüzden çağıran anlık listeyi değil, sekmeye girerken aldığı bir
   * ENSTANTANEyi geçiyor (bkz. `LiveGamesTab`).
   */
  newlyFinishedIds?: ReadonlySet<string>;
}

export function RecentGamesSection({
  onlineOnly,
  emptyMessage,
  offlineNode,
  onlineGames,
  newlyFinishedIds,
}: RecentGamesSectionProps) {
  const online = useOnlineStatus();
  const { user, profile } = useAuth();
  // `online_game_id → (isim → avatar)`. Kural saf bir yardımcıda, çünkü
  // portun ikizi AYNI kuralı okumak zorunda (bkz. recentGameAvatars.ts).
  const onlineAvatarIndex = useMemo(
    () => buildOnlineAvatarIndex(onlineGames ?? []),
    [onlineGames],
  );
  // 3 Ağustos 2026 — bu bileşen `Setup`/`LiveGamesTab`'ın kendi sekmeleri
  // arasında geçişte UNMOUNT/MOUNT olur (bkz. CLAUDE.md, "yükleniyor uzun
  // sürüyor" regresyonu); önceden her dönüşte state sıfırlanıp yeniden
  // "Yükleniyor…" gösteriliyordu. Modül seviyesindeki bu önbellek (bileşenin
  // kendi state'i DEĞİL, JS modülü yüklü kaldığı sürece yaşıyor) sayesinde
  // ilk render'da varsa son bilinen veri ANINDA gösterilir; aşağıdaki effect
  // yine de her mount'ta arka planda taze veriyi çekip hem state'i hem bu
  // önbelleği günceller — yalnızca görünür spinner ortadan kalkıyor.
  const cacheKey = user ? `${user.id}:${onlineOnly}` : null;
  const [games, setGames] = useState<GameHistoryEntry[] | null>(() =>
    cacheKey ? (recentGamesCache.get(cacheKey) ?? null) : null,
  );
  const [focusedId, setFocusedId] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);
  // Ağ hatası mı, gerçekten hiç oyun mu yok — ikisi de boş liste üretiyor
  // ama söylenecek şey farklı (bkz. `fetchMyGames`'in `failed` alanı).
  const [loadFailed, setLoadFailed] = useState(false);

  useEffect(() => {
    if (!user) {
      setGames(null);
      return;
    }
    let cancelled = false;
    const key = `${user.id}:${onlineOnly}`;
    fetchMyGames(null, 0, 5, undefined, false, onlineOnly).then(({ games: rows, failed }) => {
      if (cancelled) return;
      setLoadFailed(failed);
      // Başarısız çekim ne önbelleği ne de ekrandaki listeyi EZMELİ — bir
      // önceki yüklemenin listesi çevrimdışıyken göstermeye devam edilsin.
      // Elde hiç liste yoksa boş listeyi yazıyoruz ki `loadFailed` dalı
      // devreye girip hata mesajını gösterebilsin. (Mobil portun
      // `RecentGamesSection`'ıyla birebir aynı koşul.)
      if (!failed) recentGamesCache.set(key, rows);
      setGames((cur) => (!failed || cur === null ? rows : cur));
    });
    return () => {
      cancelled = true;
    };
  }, [user, onlineOnly]);

  // Girişsiz kullanıcı için oyun geçmişi hiç yok; henüz yüklenmediyse ya da
  // hiç bitmiş oyun yoksa da bilerek sessizce gizleniyor — boş bir bölüm
  // başlığı göstermenin bir değeri yok. `emptyMessage` verilmişse (bileşen
  // kendi başına bir sekmenin tek içeriğiyse) bunun yerine o metin gösterilir.
  const failedMessage = 'Oyun geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.';
  if (!user) return null;
  // Çevrimdışıyken "yüklenemedi" demek teknik olarak doğru ama kullanıcıya
  // ne yapacağını söylemiyor — çağıran bir düğüm verdiyse o konuşur.
  const nothingToShow = !games || games.length === 0;
  if (nothingToShow && !online && offlineNode) return <>{offlineNode}</>;
  if (!games)
    return emptyMessage ? (
      <p className="text-center text-xs text-muted font-mono py-8">{loadFailed ? failedMessage : 'Yükleniyor…'}</p>
    ) : null;
  if (games.length === 0)
    return emptyMessage ? (
      <p className="text-center text-xs text-muted font-mono py-8">{loadFailed ? failedMessage : emptyMessage}</p>
    ) : null;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Son Oynadıklarım
        </div>
        <button
          onClick={() => setShowAll(true)}
          className="text-[10px] font-mono font-bold uppercase tracking-[0.5px] text-accent active:opacity-70 transition-opacity"
        >
          Tüm Oyunlarım
        </button>
      </div>
      <div className="flex flex-col gap-2">
        {games.map((g) => {
          const points = leaguePoints(rankFor(g), g.player_count, g.surrendered, g.ai_level);
          return (
            <button
              key={g.id}
              onClick={() => setFocusedId(g.id)}
              className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left active:scale-[0.99] transition-transform"
            >
              {/* ⚠ `flex-1` KOŞULLU (3 Eylül 2026): Canlı'da boşluğu ORTADAKİ
                  etiket alıyor (kullanıcı: "ortadaki boşluğa koy"), o yüzden
                  sol sütun içeriğine küçülüyor. YZ'de etiket HİÇ YOK — orada
                  boşluğu sol sütun almalı, yoksa skor bloğu sağ kenardan
                  kopup ortaya kayardı. */}
              <span
                className={`min-w-0 flex flex-col gap-0.5 ${onlineOnly ? '' : 'flex-1'}`}
              >
                {/* 6 Eylül 2026 — TARİH (+ zorluk rozeti) AVATARLARIN ÜSTÜNE
                    çıktı, altına PUAN SATIRI girdi (kullanıcı isteği: *"Son
                    oynananlarda da aynı şekilde bitiş puanlarını koy. Oradaki
                    tarihi avatarların üstüne koy. (Kutu biraz büyüyebilir,
                    sorun değil)"*). Devam eden kartlarla aynı düzen: yüzler,
                    hemen altında koltuk sırasıyla puanlar. Port ikizi
                    `_RecentRow`. */}
                <span className="flex items-center gap-1.5 min-w-0">
                  <span className="text-[9px] font-mono text-muted truncate">{formatDate(g.created_at)}</span>
                  {/* Zorluk rozeti (ROADMAP #23 Faz 3): tarihin yanında, YZ
                      oyununda her seviyede (Normal turuncu); Canlı kartlarda
                      hiç çıkmaz. */}
                  <AiLevelBadge level={aiLevelForBadge(g.ai_level, !g.online_game_id)} />
                </span>
                {/* Rakip isimlerinin yerine katılımcı avatarları.
                    ⚠ 2 EYLÜL 2026'DA DEĞİŞTİ. Burada şu yazılıydı:
                    "dondurulmuş `players` snapshot'ı avatar_url TAŞIMIYOR
                    (bilerek — o snapshot girişli herkese açık), bu yüzden
                    burada her zaman baş harfler görünür". Snapshot hâlâ
                    avatar taşımıyor (doğru), ama ONDAN ÇIKARILAN SONUÇ
                    yanlıştı: `leaderboard` view'ı zaten `security_invoker =
                    false` ile herkesin takma adını VE avatarını açıyor, yani
                    fotoğrafı burada gizlemek tutarsızlıktı — kullanıcı
                    haklı olarak itiraz etti.
                    Avatar artık çözülüyor ve SNAPSHOT'A DOKUNULMADI:
                    `games.online_game_id` → bitmiş oyunun (silinmeyen)
                    canlı koltukları. Kural: `utils/recentGameAvatars.ts`.
                    Snapshot'ı hiç olmayan eski kayıtlarda hâlâ eski metin
                    başlığına düşülüyor. */}
                {g.players && g.players.length > 0 ? (
                  <PlayerAvatarRow
                    players={g.players.map((p) => ({
                      name: p.name,
                      isAi: p.is_ai,
                      // Misafirken oynanıp bitirilen, sonra (aynı cihazda üye
                      // olunca) `flushPendingGames` ile hesaba taşınan yerel
                      // oyunlar: snapshot'taki isim kalıcı olarak
                      // GUEST_PLAYER_NAME kalıyor (`buildGameRecord` state'teki
                      // adı donduruyor), yani baş harf "MI" çıkıp misafiri
                      // gerçek bir üye gibi gösteriyordu. Snapshot bilerek
                      // `user_id` taşımadığından tespitin tek yolu isim.
                      // `online_game_id` kontrolü yanlış pozitifi daraltıyor:
                      // Canlı'da misafir koltuk YOK, oradaki herkes kayıtlı —
                      // takma adı gerçekten "Misafir" olan bir üye (nickname
                      // benzersiz olduğundan en fazla bir kişi) Canlı
                      // kartlarında baş harflerini korur.
                      isGuest: !p.is_ai && !g.online_game_id && p.name === GUEST_PLAYER_NAME,
                      // 2 Eylül 2026: bu liste avatarları HİÇ göstermiyordu.
                      // Kural ve gerekçesi `recentGameAvatars.ts`'te —
                      // snapshot'a da migration'a da dokunulmadı.
                      avatarUrl: avatarForRecentPlayer({
                        isAi: p.is_ai,
                        isGuest:
                          !p.is_ai && !g.online_game_id && p.name === GUEST_PLAYER_NAME,
                        name: p.name,
                        onlineGameId: g.online_game_id ?? null,
                        onlineIndex: onlineAvatarIndex,
                        ownAvatarUrl: profile?.avatar_url ?? null,
                      }),
                    }))}
                  />
                ) : (
                  <span className="font-sans text-[12px] font-bold text-text truncate">{titleFor(g)}</span>
                )}
                {/* Bitiş puanları — snapshot sırası avatar sırasıyla AYNI
                    dizi (`g.players`), yani N'inci sayı N'inci yüzün
                    altında. Punto devam-eden kartların kalan-süre satırıyla
                    aynı (`utils/scoreLine.ts`). Snapshot'sız eski kayıtta
                    satır çizilmez (avatar da yok, başlık metni var). */}
                {g.players && g.players.length > 0 && (
                  <span className="text-[8px] font-mono tracking-[0.5px] text-muted truncate">
                    {scoreLine(g.players.map((p) => p.score))}
                  </span>
                )}
              </span>
              {/* "Oyun Bitti" — 3 Eylül 2026, kullanıcı isteği.
                  ⚠ YALNIZCA Canlı tarafta. YZ oyunları senin cihazında
                  bitiyor, yani bitişi zaten gözünle görüyorsun; orada bu
                  etiket bilgi taşımaz, yalnızca gürültü olurdu (kullanıcı
                  aynı gün ikinci turda bunu istedi). Canlı'da ise tam tersi:
                  hamleni yapıp gittiğinde oyun SEN YOKKEN bitiyor ve bugün
                  bunu hiçbir yer söylemiyor.
                  Bitişini görmediğin oyunlarda YANINA kırmızı "YENİ" düşer;
                  sekmeden çıkınca o rozet kalkar, "OYUN BİTTİ" kalır. */}
              {onlineOnly && (
                <span className="flex-1 min-w-0 flex items-center justify-center gap-1">
                  {/* Teslimle biten oyunda metin "TESLİM" (3 Eylül 2026,
                      kullanıcı isteği). AYRI bir sütun EKLENMEDİ: satır
                      zaten avatar+tarih | etiket | skor | k-lig, dördüncü
                      bir metin sütunu 360 px'lik ekranda sıkışırdı
                      (kullanıcı da bunu sordu). Aynı kutuyu kullanmak yer
                      maliyetini SIFIRA indiriyor — üstelik "TESLİM" 6
                      karakter, "OYUN BİTTİ" 10; sütun DARALIYOR.
                      ⚠ Bayrak SATIR SAHİBİNE ait: `games.surrendered` kişi
                      başına, yani rakibin süresi dolduysa BENİM satırım
                      `OYUN BİTTİ` kalır (ben kazandım). `GameHistoryModal`
                      da "Teslim Oldu"yu yalnızca teslim olanın kendi
                      satırında gösteriyor — aynı kural.
                      Renk BİLEREK nötr: teslimin kırmızısı zaten sağdaki
                      -2 k-lig puanında; ikinci bir kırmızı, yanındaki
                      "YENİ" rozetiyle yarışırdı. */}
                  {/* ⚠ Metin KAYNAKTA büyük harf, CSS `uppercase` ile
                      DEĞİL: `text-transform` Türkçe'yi belgenin diline
                      göre çeviriyor ve "Bitti"nin i'si yanlış locale'de
                      "BITTI" (noktasız I) olur. Bu repo native
                      büyük/küçük dönüşümünü zaten yasaklıyor
                      (`trUpper`) — burada dönüşüme hiç gerek yok. */}
                  {/* ⚠ PUNTO 11 px, ve bu bir OKUNABİLİRLİK ZORUNLULUĞU,
                      tercih değil: `İ`nin noktası Space Mono'da 8-9 px'te
                      harfin gövdesine yapışıyor ve rozet ekranda "YENI"
                      diye okunuyor (kullanıcı bildirdi; 6× büyütmeyle
                      ölçüldü — nokta ancak 10 px'ten sonra ayrılıyor).
                      Karakter HER ZAMAN doğruydu: U+0130 olduğu ayrıca
                      doğrulandı, kaybolan şey GLİF, kod değil.
                      ⚠ Bu iki puntoyu düşürürsen aynı hata geri gelir. */}
                  <span className="text-[11px] font-mono tracking-[0.5px] text-muted leading-none whitespace-nowrap">
                    {g.surrendered ? 'TESLİM OLDUN' : 'OYUN BİTTİ'}
                  </span>
                  {newlyFinishedIds?.has(g.id) && (
                    <span className="shrink-0 text-[11px] font-mono font-bold tracking-[0.5px] text-white bg-red rounded px-1 py-px leading-none">
                      YENİ
                    </span>
                  )}
                </span>
              )}
              {/* ⚠ SABİT GENİŞLİK + SAĞA YASLI. Portta bu iki sütun düz
                  metindi ve kullanıcı cihazda bozukluğu yakaladı (3 Eylül
                  2026: "puan ve k-lig bozulmuş, sağda hizalı olmaları
                  lazım") — genişlik içeriğe göre değişince ("0" bir
                  karakter, "253" üç; k-lig "-" bir, "+2" iki) satırın sonu
                  her satırda başka yerde bitiyor. Web'de aynı kırılganlık
                  DAHA DAR ama var: k-lig `-` (0 puan) olduğunda skorun sağ
                  kenarı kayar. İki taraf da aynı çözümü kullanıyor —
                  portta `ScaledCell`, burada `w-*` + `text-right`. */}
              <span className="flex items-center gap-2 shrink-0">
                <span className="w-7 text-right font-mono text-[11px] font-bold text-text">
                  {g.player_score}
                </span>
                <span
                  className={`w-[18px] text-right font-mono text-[11px] font-bold ${
                    points > 0 ? 'text-green' : points < 0 ? 'text-red' : 'text-muted'
                  }`}
                >
                  {formatLeaguePoints(points)}
                </span>
              </span>
            </button>
          );
        })}
      </div>

      {(focusedId || showAll) && (
        <GameHistoryModal
          playerCount={null}
          onClose={() => {
            setFocusedId(null);
            setShowAll(false);
          }}
          initialExpandedId={focusedId ?? undefined}
        />
      )}
    </div>
  );
}
