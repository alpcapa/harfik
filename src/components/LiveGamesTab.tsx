// Kelimeki — Canlı sekmesi: davet bekleyen/rakip bekleyen/aktif Canlı
// oyunların listesi, gelen davetlerde kiminle oynayacağını gösterme +
// Kabul/Reddet + "+ Yeni Canlı Oyun" ile kurulum formuna geçiş (bkz.
// src/App.tsx'teki mainView tab'ı, src/components/LiveGameCreateForm.tsx).
//
// 1 Ağustos 2026 — üç bölüm (Devam Eden Oyunlar / davet+bekleme grupları /
// Son Oynadıklarım) alt alta dizildiğinde, çok sayıda devam eden oyunu olan
// biri için "Davet Bekliyor" listesi ekranın altına düşüp scroll etmeden
// görünmüyordu — halbuki ikisi de (devam eden VE davet) aynı derecede
// dikkat gerektiriyor. Kullanıcı isteğiyle üçü, "+ Yeni Canlı Oyun"un
// altına yerleştirilen bir tab satırına (Devam Edenler / Oyun Davetleri /
// Son Oynananlar) taşındı; her tab AÇILDIĞINDA içindeki bölüm başlıkları
// ("Devam Eden Oyunlar", "Davet Bekliyor" vb.) eskisiyle birebir aynı
// kalıyor — yalnızca hangi bölümün ne zaman göründüğü değişti. İlk iki
// tabın kırmızı sayaç rozeti dikkat gerektiren gerçek sayıyı gösteriyor
// (Setup'taki "Arkadaşınla (N)" rozetiyle aynı iki bileşen: yanıt bekleyen
// davet sayısı / sırası çağıranda olan aktif oyun sayısı) — "Son
// Oynananlar" hiçbir zaman dikkat gerektirmediğinden rozet almıyor.
// Bekleyen bir davet varsa uygulama açılışında doğrudan "Oyun Davetleri"
// tabı açık gelir (yoksa "Devam Edenler") — bu yalnızca veri İLK yüklendiğinde
// bir kez uygulanır, kullanıcı sonradan elle başka bir taba geçerse bir
// daha zorlanmaz. Rozetler `games`/`turns`'ten TÜRETİLDİĞİNDEN (ayrı bir
// sayaç state'i tutulmuyor) her `reload()` sonrası (bir davet kabul
// edilince/reddedilince, bir hamle oynanınca) otomatik doğru sayıya
// düşer/artar — ör. 2 bekleyen davetten biri kabul edilince `invites`
// dizisinden çıkıp rozet kendiliğinden 1'e iner, sıfıra inmeden rozet asla
// erken kaybolmaz (yalnızca gerçekten 0 olunca `tab.badge > 0` koşuluyla
// gizlenir).
import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import {
  checkInviteExpiry,
  checkOnlineGameTurnTimeout,
  fetchOnlineGameGlances,
  fetchOnlineGameTurns,
  listMyOnlineGames,
  markGameFinishesSeen,
  respondToGameInvite,
  subscribeMyOnlineGames,
} from '../lib/api';
import { ABANDON_TIMEOUT_MS } from '../utils/gameStorage';
import type { OnlineGame, OnlineGameSlot } from '../lib/database.types';
import type { OnlineGameGlance } from '../lib/api';
import { scoreLine } from '../utils/scoreLine';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { CountBadge } from './CountBadge';
import { createAwayTracker } from '../utils/awayReturn';
import { useOnlineStatus } from '../hooks/useOnlineStatus';
import { orderActiveGames, orderByExpiry } from '../utils/gameListOrder';
import {
  LOAD_FAILED_NOTICE,
  OFFLINE_NO_CONNECTION,
  RETRY_LABEL,
  STALE_DATA_NOTICE,
} from '../utils/offlineNotice';
import { PlayerAvatarRow } from './PlayerAvatarRow';
import { FriendSuggestModal } from './FriendSuggestModal';
import { LiveGameCreateForm } from './LiveGameCreateForm';
import { RecentGamesSection } from './RecentGamesSection';
import { RankSeal } from './RankSeal';
import { RankTierProvider, useRankTier } from '../hooks/useRankScores';

type SubTab = 'active' | 'invites' | 'recent';

// `user.id` -> son çekilen liste/sıra/son-tarih durumu. Modül seviyesinde
// (bileşenin kendi state'i DEĞİL) tutuluyor çünkü `LiveGamesTab`, `Setup`'ın
// "Oyun Tipi" sekmeleri arasında geçişte tamamen UNMOUNT/MOUNT oluyor (bkz.
// CLAUDE.md, "yükleniyor uzun sürüyor" regresyonu, 3 Ağustos 2026) — önceden
// her dönüşte state sıfırlanıp `games===null` yüzünden yeniden "Yükleniyor…"
// gösteriliyordu. Bu önbellek sayesinde bir sonraki mount, son bilinen
// veriyi anında gösterir; `loadGames` yine her mount'ta arka planda taze
// veriyi çekip hem state'i hem bu önbelleği günceller.
const liveGamesCache = new Map<
  string,
  { games: OnlineGame[]; turns: Record<string, number>; glances: Record<string, OnlineGameGlance> }
>();

type HumanSlot = Extract<OnlineGameSlot, { type: 'human' }>;

/** `game.slots`teki, çağıranın kendi koltuğunun indeksi (`relation==='self'`). */
function mySlotIndex(game: OnlineGame): number {
  return game.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
}

// ⚠ Aktif oyunun iki etiketi KAYNAKTA BÜYÜK HARFLE yazılı (30 Ağustos 2026,
// kullanıcı isteği: *"'Senin hamlen bekleniyor' → 'SIRA SENDE', 'Rakibin
// hamlesi bekleniyor' → 'SIRA RAKİPTE'"*). CSS `uppercase` zaten uyguluyor
// ama Türkçe i→İ dönüşümü tarayıcının `lang` duyarlılığına kalıyor;
// kaynağın kendisi büyükse o belirsizlik hiç doğmuyor ve portun `trUpper`ı
// da idempotent kalıyor. Öteki iki etiket (Rakip bekleniyor/Bitti/Terk
// edildi) dokunulmadı — onlar bir SIRA bildirmiyor.
/**
 * "SIRA SENDE"nin yanındaki yeşil ÜÇGEN — oynat tuşu gibi (30 Ağustos
 * 2026, kullanıcı isteği: *"yeşil ok yerine yeşil üçgen (play tuşu gibi)
 * deneyelim"*).
 *
 * Öncesinde bir `>` glifiydi ve iki tur ayar istemişti: Space Mono'da `>`
 * matematik hizasında oturup harf boyuna ÇIKMADIĞINDAN 13 px'te mürekkep
 * yüksekliği yalnızca 17/27'ydi (pixelRatio 3) — 21 px'e büyütülüp 2,67 px
 * aşağı kaydırılmıştı. Çizilmiş üçgen o iki ayarı birden gereksiz kılıyor:
 * ölçüsünü doğrudan veriyoruz.
 *
 * ⚠ **Glif DEĞİL, çizilmiş vektör** — `TurnDot`'takiyle aynı gerekçe:
 * `▶`/`►` Space Mono'da yok, kullanılsaydı tarayıcı ve Flutter ayrı yedek
 * fontlara düşüp FARKLI üçgenler çizerdi. Geometri portla ELLE senkron ve
 * senkronu ZORLAYAN bir test var: `relation_icon_parity_test.dart`.
 *
 * Ölçü büyük harflerin mürekkep yüksekliğinden: 13 px puntoda 9,0 mantıksal
 * px. Üçgen 8×9, taban çizgisine oturuyor.
 */
export function TurnTriangle() {
  return (
    <svg
      width="9"
      height="10"
      viewBox="0 0 9 10"
      fill="currentColor"
      aria-hidden
      className="ml-[25px] inline-block align-baseline text-green"
    >
      <path d="M0 0L9 5L0 10Z" />
    </svg>
  );
}


/**
 * "SIRA RAKİPTE"nin sonundaki kırmızı yuvarlak (30 Ağustos 2026, kullanıcı
 * isteği) — `TurnTriangle`'ın simetriği: yeşil üçgen "git oyna", kırmızı
 * nokta "bekle".
 *
 * ⚠ **Glif DEĞİL, çizilmiş bir kutu.** `●` (U+25CF) Space Mono'da YOK;
 * kullanılsaydı tarayıcı/Flutter yedek bir fonta düşerdi ve iki platform
 * farklı bir daire çizerdi — bu dosyanın "web ve port AYNI vektör" kuralının
 * sessizce kırılması olurdu. Kutu ölçüsü ölçümden: büyük harflerin mürekkep
 * yüksekliği 13 px puntoda 9,0 mantıksal px (pixelRatio 3'te 27), yuvarlak
 * da 9 — taban çizgisine oturduğunda tam harf bandını dolduruyor.
 *
 * `align-baseline` + `inline-block`: içeriği olmayan bir inline-block'un
 * taban çizgisi ALT kenarıdır, yani yuvarlak harflerin üstünde yüzmez.
 *
 * Boşluk `TurnTriangle`ınkiyle AYNI (25) — ama üç turdur öyle değildi ve
 * her seferinde sebep başkaydı: `>` glifinin yan boşluğu (25/29), sonra
 * üçgene geçiş (25/27), sonunda etiketten `!`in kalkması (iki etiket de
 * artık `E` ile bitiyor → 25/25). Ölçümle ayarlandı, hesapla değil;
 * gerekçenin tamamı portun `kTurnDotGap`inde.
 *
 * Port ikizi: `live_games_tab.dart` → `turnDotSpan` / `kTurnDotGap`.
 */
export function TurnDot() {
  return (
    <span
      aria-hidden
      className="ml-[25px] inline-block h-[10px] w-[10px] rounded-full bg-red align-baseline"
    />
  );
}

function statusLabel(game: OnlineGame, isMyTurn?: boolean): string {
  if (game.status === 'active') return isMyTurn ? 'SIRA SENDE' : 'SIRA RAKİPTE';
  if (game.status === 'pending') return 'Rakip bekleniyor';
  if (game.status === 'finished') return 'Bitti';
  return 'Terk edildi';
}

// Sırası gelen oyuncunun 48 saatlik zaman aşımına kalan süresi — Setup'taki
// "Devam Eden Oyun" satırının remainingDays'iyle aynı ilke (kalan süre
// düşükse kırmızı, kalın değil), burada saat cinsinden çünkü pencere gün
// değil saat mertebesinde (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6"). Kırmızı
// (kalın değil) kalan süre 24 saatin altına inince devreye giriyor.
function remainingTimeLabel(deadline: string | null | undefined): { text: string; urgent: boolean } | null {
  if (!deadline) return null;
  const ms = new Date(deadline).getTime() - Date.now();
  if (ms <= 0) return { text: 'Süresi doldu - teslim oldu', urgent: true };
  const totalMinutes = Math.ceil(ms / (60 * 1000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  // ⚠ "… sonra teslim sayılacak" → "… kaldı" (30 Ağustos 2026, kullanıcı
  // isteği). Fiil BİLİNÇLİ olarak düştü: sayaç zaten yalnızca SIRASI
  // ÇAĞIRANDA olan oyunlarda çiziliyor ve hemen üstünde "SIRA SENDE"
  // yazıyor, yani "ne olacak" bilgisini satırın kendisi değil kart taşıyor.
  // Üç sayaç da (bu, davet iptali, Setup'ın yerel kaydı) aynı kalıba çekildi.
  // Parantez içindeki sonuç (30 Ağustos 2026, kullanıcı isteği) — fiil
  // metinden çıkarılınca kaybolan "süre dolunca ne olacak" bilgisini geri
  // getiriyor, ama bu kez ceza MİKTARIYLA: 48 saat dolunca sıra sendeyken
  // otomatik teslim olunuyor ve k-lig puanından -2 düşülüyor
  // (`check_turn_timeout`, bkz. docs/decisions/live-game.md).
  const text =
    hours > 0
      ? `${hours} saat ${minutes} dk sonra teslim (-2 puan)`
      : `${minutes} dk sonra teslim (-2 puan)`;
  return { text, urgent: totalMinutes < 24 * 60 };
}

// Bekleyen bir davetin/oyunun 7 günlük iptal süresine kalan süre — Setup'taki
// "Devam Eden Oyun" satırının remainingTime'ıyla aynı ilke ve aynı süre
// (ABANDON_TIMEOUT_MS), oluşturulma anından itibaren. "N gün M saat kaldı"
// biçiminde (24 saatin altına düşünce dakika hassasiyetinde saate geçer,
// aynı zamanda kırmızı/kalın olur — remainingTimeLabel'daki aynı mantık).
function remainingInviteDays(createdAt: string): { text: string; urgent: boolean } {
  const ms = Date.parse(createdAt) + ABANDON_TIMEOUT_MS - Date.now();
  // Süre dolduğunda "Bugün iptal edilir" yazıyordu — hem yanlış (iptal
  // GELECEKTE değil, süre ZATEN doldu) hem de projedeki diğer sayaçlarla
  // tutarsızdı. `remainingTimeLabel`'ın "Süresi doldu - teslim oldu"
  // kalıbıyla hizalandı. Bu durum artık yalnızca geçici: süresi dolmuş bir
  // davet, `check_invite_expiry` süpürmesi çalışana kadar (saniyeler)
  // görünür, sonra listeden kalkar (bkz. `invites` kovasındaki status filtresi).
  if (ms <= 0) return { text: 'Süresi doldu', urgent: true };
  const totalMinutes = Math.ceil(ms / (60 * 1000));
  const totalHours = Math.floor(totalMinutes / 60);
  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;
  const minutes = totalMinutes % 60;
  // Üç sayaç da aynı kalıpta: yalnızca SÜRE + "kaldı" (30 Ağustos 2026,
  // kullanıcı isteği). Öncesinde her biri kendi fiilini taşıyordu ("sonra
  // iptal edilecek" / "sonra teslim sayılacak" / "sonra silinecek") — süre +
  // o sürenin sonunda NE olacağı. Fiiller düştü; kartın kendisi (davet mi,
  // sıra mı, kayıt mı) zaten hangi sürenin işlediğini söylüyor.
  const text =
    days > 0
      ? `${days} gün ${hours} saat kaldı`
      : `${hours} saat ${minutes} dakika kaldı`;
  return { text, urgent: days < 1 };
}

// Bir davet satırındaki tek katılımcının, o oyundaki rolüne göre etiketi —
// "kim arkadaşım" değil "kim ne durumda" sorusuna cevap verir (relation
// tabanlı +/✓ göstergesi kafa karıştırdığı için kaldırıldı). Çağıranın
// kendi koltuğu da özel bir "Sen" etiketi almıyor — o da diğer davetliler
// gibi kendi gerçek adıyla ve invite_status'una göre gösterilir (bu
// listede zaten her zaman 'pending'dir, yani "Bekliyor" çıkar).
function participantLabel(slot: HumanSlot, game: OnlineGame): string {
  if (slot.user_id === game.created_by) return 'Davet gönderen';
  if (slot.invite_status === 'accepted') return 'Kabul etti';
  if (slot.invite_status === 'declined') return 'Reddetti';
  return 'Bekliyor';
}

// `participantLabel`in RENGİ — dallar birebir yukarıdaki sırayla, çünkü
// ikisi tek bir karardır: etiket değişirse rengi de aynı yerde değişsin
// (bu projede "zincirin bir halkası" hatası tam böyle doğuyor).
//
// Kullanıcı isteği (30 Ağustos 2026): "Kabul etti" YEŞİL, "Bekliyor"
// KIRMIZI — davet kartına bakan kişi tek bakışta kimin cevap verdiğini
// görsün. "Reddetti" ve "Davet gönderen" bilinçli olarak NÖTR kalıyor:
// buradaki kırmızı "hâlâ cevap bekleniyor" uyarısı, "olumsuz sonuç"
// değil; ikisini aynı renge boyamak o ayrımı silerdi.
//
// "Reddetti" zaten bu listede GÖRÜNMÜYOR (ölçüldü, 30 Ağustos 2026):
// `respond_to_game_invite`in ret dalı oyunu anında `abandoned` yapıyor
// (kompozisyon kuralı gereği tek ret kadroyu tamamlanamaz kılıyor) ve
// aşağıdaki dört kova yalnızca `pending`/`active` eşliyor — canlıda 86
// davetin 2'si reddedilmiş, ikisi de görünmez oyunlarda. Dal yine de
// duruyor: etiketin kendisi var, rengi de onunla aynı yerde kalsın.
//
// Port ikizi: mobile/app/lib/src/ui/live/live_games_tab.dart →
// `_participantLabelColor` (aynı dal sırası, aynı tokenler).
function participantLabelClass(slot: HumanSlot, game: OnlineGame): string {
  if (slot.user_id === game.created_by) return 'text-muted';
  if (slot.invite_status === 'accepted') return 'text-green';
  if (slot.invite_status === 'declined') return 'text-muted';
  return 'text-red';
}

function ParticipantRow({ slot, game }: { slot: HumanSlot; game: OnlineGame }) {
  // Rütbe mührü context'ten okunuyor: bu satır listeyi tutan
  // `LiveGamesTab`'tan dört kat uzakta (GameRow/PendingSection →
  // PendingGameCard → burası), prop drilling yerine tek bir sağlayıcı.
  // Boy 16, çünkü isim 12px (14px isimlerde 18 kullanılıyor).
  const tier = useRankTier(slot.user_id);
  return (
    <div className="flex items-center gap-2">
      <Avatar url={slot.avatar_url} name={slot.name} size={26} />
      <span className="flex-1 min-w-0 flex items-center gap-1">
        <span className="min-w-0 text-xs text-text truncate">{slot.name ?? 'Oyuncu'}</span>
        {tier && <RankSeal tier={tier} size={16} className="shrink-0" />}
      </span>
      <span className={`text-[9px] font-mono uppercase tracking-[0.5px] shrink-0 ${participantLabelClass(slot, game)}`}>
        {participantLabel(slot, game)}
      </span>
    </div>
  );
}

// Bir davetin (yanıt bekleyen) ya da henüz `pending` bir oyunun (kabul
// ettin/kurdun ama diğerleri henüz tamamlanmadı) "kiminle oynayacaksın"
// detayı — katılımcı listesi hem yanıt bekleyen davetlerde hem de
// aşağıdaki "Kabul Ettin — Diğerleri Bekleniyor"/"Rakip Bekleniyor"
// bölümlerinde aynı görünür, çünkü ikisinde de asıl soru aynı: bu oyunda
// kim var, kim ne durumda. Yalnızca `onRespond` verildiğinde Kabul/Reddet
// butonları eklenir.
function PendingGameCard({
  game,
  title,
  onRespond,
  busy,
}: {
  game: OnlineGame;
  title: string;
  onRespond?: (accept: boolean) => void;
  busy?: boolean;
}) {
  const humanSlots = game.slots.filter((s): s is HumanSlot => s.type === 'human');
  const hasAi = game.slots.some((s) => s.type === 'ai');
  const remaining = remainingInviteDays(game.created_at);

  return (
    <div className="shadow-raised flex flex-col gap-2.5 rounded-md px-2.5 py-2.5 border border-border bg-panel">
      <div className="flex items-start gap-2">
        <span className="flex-1 min-w-0 font-sans text-[12px] font-bold text-text leading-snug">{title}</span>
        <span
          className={`shrink-0 text-[9px] font-mono uppercase tracking-[0.5px] whitespace-nowrap ${
            remaining.urgent ? 'text-red font-bold' : 'text-muted'
          }`}
        >
          {remaining.text}
        </span>
      </div>
      <div className="flex flex-col gap-1.5">
        <div className="text-[9px] uppercase tracking-[1px] text-muted font-mono">Oyuncular</div>
        {humanSlots.map((slot) => (
          <ParticipantRow key={slot.user_id} slot={slot} game={game} />
        ))}
        {hasAi && (
          <div className="flex items-center gap-2">
            <span
              className="w-[26px] h-[26px] rounded-full bg-void border border-border flex items-center justify-center text-sm shrink-0"
              aria-hidden
            >
              🤖
            </span>
            <span className="flex-1 min-w-0 text-xs text-text truncate">Yapay Zeka</span>
          </div>
        )}
      </div>
      {onRespond && (
        <div className="flex gap-1.5">
          <button
            onClick={() => onRespond(true)}
            disabled={busy}
            className="flex-1 btn-raised bg-accent text-white rounded-md py-1.5 text-[10px] font-bold uppercase tracking-[0.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            Kabul Et
          </button>
          <button
            onClick={() => onRespond(false)}
            disabled={busy}
            className="flex-1 btn-raised-neutral bg-panel border border-border text-muted rounded-md py-1.5 text-[10px] font-bold uppercase tracking-[0.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            Reddet
          </button>
        </div>
      )}
    </div>
  );
}

interface GameRowProps {
  game: OnlineGame;
  onRespond?: (accept: boolean) => void;
  busy?: boolean;
  /** Yalnızca `status==='active'` oyunlarda verilir — satıra tıklanınca gerçek oyun ekranını açar. */
  onOpen?: () => void;
  /** `status==='active'` oyunlarda: sıra şu an çağırandaysa `true`. */
  isMyTurn?: boolean;
  /** `status==='active'` oyunlarda: sırası gelen oyuncunun zaman aşımı son tarihi. */
  deadline?: string | null;
  /**
   * `status==='active'` oyunlarda: koltuk sırasıyla anlık puanlar
   * (`online_game_states.players[].score`) — avatarların altındaki puan
   * satırı. `undefined` = henüz yüklenmedi (satır çizilmez).
   */
  scores?: number[];
}

function GameRow({ game, onRespond, busy, onOpen, isMyTurn, deadline, scores }: GameRowProps) {
  const isPendingInvite = game.my_role === 'invitee' && game.my_invite_status === 'pending';

  if (isPendingInvite && onRespond) {
    const humanSlots = game.slots.filter((s): s is HumanSlot => s.type === 'human');
    const inviterName = humanSlots.find((s) => s.user_id === game.created_by)?.name;

    return (
      <PendingGameCard
        game={game}
        title={`${inviterName ?? 'Bir arkadaşın'} seni ${game.player_count} kişilik oyuna davet etti`}
        onRespond={onRespond}
        busy={busy}
      />
    );
  }

  // Kalan süre YALNIZCA sırası çağıranda olan oyunlarda gösterilir.
  // `turn_deadline` her zaman SIRASI GELEN oyuncuya ait; "Rakibin hamlesi
  // bekleniyor" satırının altında "N saat sonra teslim sayılacak" yazınca
  // kullanıcı bunu KENDİ süresi sanıyordu (kullanıcı bildirdi) — oysa o süre
  // dolduğunda teslim olan taraf rakip. Sırası kendisinde olmayan oyunda
  // kullanıcının yapabileceği bir şey de yok, yani gösterilmemesi bilgi
  // kaybı değil. `isMyTurn` henüz `undefined` iken (turns tablosu yüklenmemiş)
  // de gizli kalır — yanlış tarafa ait bir sürenin bir an görünmesindense
  // hiç görünmemesi tercih edildi.
  const remaining = isMyTurn ? remainingTimeLabel(deadline) : null;
  const Wrapper = onOpen ? 'button' : 'div';
  return (
    <Wrapper
      type={onOpen ? 'button' : undefined}
      onClick={onOpen}
      className={`shadow-raised flex flex-col rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left ${
        onOpen ? 'active:scale-[0.99] transition-transform' : ''
      }`}
    >
      {/* 2 Eylül 2026 — SÜRE SATIRI KARTIN ALTINA ALINDI. Setup'ın YZ kartı
          aynı gün bu şekle sokulmuştu, burası dokunulmadan kalmıştı ve iki
          sekme AYRIŞMIŞTI (kullanıcı cihazda bildirdi, 1.0.5). Önceki
          yapıda durum ve süre TEK bir sağ sütundaydı ve o sütunun enini
          SÜRE belirliyordu — portun ikizinde ölçüldü (320 px): "SIRA SENDE"
          89,6 px, süre satırı **194,3 px**. Yani sol sütunu (o gün "X açtı")
          daraltan etiket değil süreydi. Şimdi üst satır sol=oyuncular /
          sağ=durum, süre altta tam genişlik (sağa yaslı — görsel çapa
          değişmedi). Port ikizi: `devam_eden_govde.dart`. */}
      <span className="flex items-center gap-2.5">
        <span className="flex-1 min-w-0 flex flex-col gap-0.5">
          {/* "N Kişilik Oyun" başlığının yerine katılımcı avatarları — avatar
              sayısı zaten oyuncu sayısını gösterdiğinden metin bilgi
              kaybettirmiyor (bkz. PlayerAvatarRow). YZ koltukları bu kartın
              davet hâlindeki karşılığıyla (PendingGameCard) aynı robot
              avatarını alıyor. */}
          <PlayerAvatarRow
            players={game.slots.map((s) =>
              s.type === 'human'
                ? { name: s.name ?? 'Oyuncu', avatarUrl: s.avatar_url }
                : { name: 'Yapay Zeka', isAi: true },
            )}
          />
          {/* 6 Eylül 2026 — "X açtı" satırı KALKTI, yerine PUAN SATIRI
              (kullanıcı isteği: *"Ironman açtı kalksın çünkü zaten ilk
              baştaki her zaman oyunu başlatan oluyor"* — `slots[0]` her
              zaman kurucu, bkz. migration `online_games_invites`; avatar
              şeridi o bilgiyi zaten taşıyor). Puanlar koltuk sırasıyla,
              yani N'inci sayı N'inci yüzün altında; punto/harf aralığı
              alttaki kalan-süre satırıyla AYNI (kullanıcı: "font kalan süre
              ile aynı olsun"). Setup'ın YZ kartı (`SavedGameRow`) ve "Son
              Oynananlar" aynı satırı çiziyor; port ikizi `_GameRow`. */}
          {scores && scores.length > 0 && (
            <span className="text-[8px] font-mono tracking-[0.5px] text-muted truncate">
              {scoreLine(scores)}
            </span>
          )}
        </span>
        {/* 11 → 13 px (30 Ağustos 2026) → 15 px (2 Eylül 2026, kullanıcı
            isteği: "Sıra Sende ve Sıra Rakipte fontu biraz daha büyüt").
            Üçgen/noktanın ölçüsü bu puntoya çapalı (bkz. TurnTriangle). */}
        <span
          className={`shrink-0 text-[15px] font-mono uppercase tracking-[1px] ${
            game.status === 'active'
              ? isMyTurn
                ? 'text-green font-bold'
                : 'text-red font-bold'
              : 'text-muted'
          }`}
        >
          {statusLabel(game, isMyTurn)}
          {game.status === 'active' && (isMyTurn ? <TurnTriangle /> : <TurnDot />)}
        </span>
      </span>
      {remaining && (
        <span
          /* mt-1.5 — SavedGameRow'la aynı: süre satırı durum etiketine
             YAPIŞMASIN (kullanıcı isteği). */
          className={`mt-1.5 self-end text-[8px] font-mono uppercase tracking-[0.5px] ${
            remaining.urgent ? 'text-red' : 'text-muted'
          }`}
        >
          {remaining.text}
        </span>
      )}
    </Wrapper>
  );
}

function Section({
  title,
  games,
  onOpenGame,
  turns,
  glances,
}: {
  title: string;
  games: OnlineGame[];
  onOpenGame?: (game: OnlineGame) => void;
  turns?: Record<string, number>;
  glances?: Record<string, OnlineGameGlance>;
}) {
  if (games.length === 0) return null;
  return (
    <div className="flex flex-col gap-2">
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">{title}</div>
      <div className="flex flex-col gap-2">
        {games.map((g) => (
          <GameRow
            key={g.id}
            game={g}
            onOpen={onOpenGame ? () => onOpenGame(g) : undefined}
            isMyTurn={turns ? turns[g.id] === mySlotIndex(g) : undefined}
            deadline={glances ? glances[g.id]?.deadline : undefined}
            scores={glances ? glances[g.id]?.scores : undefined}
          />
        ))}
      </div>
    </div>
  );
}

// "Kabul Ettin — Diğerleri Bekleniyor"/"Rakip Bekleniyor" için: her oyunu
// tek satırlık bir özet yerine tam "Kiminle Oynayacaksın" detay kartıyla
// gösterir — bu iki bölümde asıl merak edilen şey zaten "hangi arkadaşım
// henüz kabul etmedi", o yüzden `Section`'ın kompakt `GameRow`'u yerine
// doğrudan `PendingGameCard` kullanılır (bkz. yukarıdaki davet kartı).
function PendingSection({ title, games }: { title: string; games: OnlineGame[] }) {
  if (games.length === 0) return null;
  return (
    <div className="flex flex-col gap-2">
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">{title}</div>
      <div className="flex flex-col gap-2">
        {games.map((g) => (
          <PendingGameCard key={g.id} game={g} title={`${g.player_count} Kişilik Oyun`} />
        ))}
      </div>
    </div>
  );
}

interface LiveGamesTabProps {
  /** `status==='active'` bir oyuna tıklanınca gerçek oyun ekranını açmak için (Faz 3, 4. adım). */
  onOpenGame: (game: OnlineGame) => void;
  /**
   * Bitişini kullanıcının GÖRMEDİĞİ oyunların `games.id`'leri (3 Eylül 2026).
   * "Son Oynananlar" alt sekmesinin kırmızı sayısı ve satırlardaki "YENİ"
   * rozetleri bundan geliyor.
   *
   * ⚠ Sahibi `Setup` — çünkü aynı sayı ÜST sekmenin ("Arkadaşınla") rozetine
   * de giriyor. Burada ayrıca çekilseydi iki kopya birbirinden sapardı.
   * ⚠ Referansı KARARLI olmalı (Setup'ta state), yoksa aşağıdaki effect her
   * render'da yeniden koşup sunucuya işaretleme isteği yağdırır.
   */
  newlyFinishedIds: readonly string[];
  /** Sekme ziyaret edilip sunucu işaretlemeyi ONAYLADIĞINDA çağrılır. */
  onFinishesSeen: () => void;
}

export function LiveGamesTab({
  onOpenGame,
  newlyFinishedIds,
  onFinishesSeen,
}: LiveGamesTabProps) {
  const { user, loading: authLoading } = useAuth();
  const online = useOnlineStatus();
  // null = henüz çekilmedi (yükleniyor), [] = çekildi ama hiç oyun yok.
  // İlk değer, varsa bu kullanıcı için önbellekteki son bilinen listeden
  // geliyor (bkz. `liveGamesCache` tanımındaki not) — yeniden mount'ta
  // spinner göstermeden son durumu anında çizip arkada tazeliyoruz.
  const [games, setGames] = useState<OnlineGame[] | null>(
    () => (user ? (liveGamesCache.get(user.id)?.games ?? null) : null),
  );
  // gameId -> sırası gelen koltuk indeksi ("Sıra sende" rozeti için).
  const [turns, setTurns] = useState<Record<string, number>>(
    () => (user ? (liveGamesCache.get(user.id)?.turns ?? {}) : {}),
  );
  // gameId -> sırası gelen oyuncunun zaman aşımı son tarihi ("kalan süre"
  // için) + koltuk sırasıyla anlık puanlar (kart altı puan satırı, 6 Eylül
  // 2026) — ikisi aynı `online_game_states` satırından, tek istekle.
  const [glances, setGlances] = useState<Record<string, OnlineGameGlance>>(
    () => (user ? (liveGamesCache.get(user.id)?.glances ?? {}) : {}),
  );
  // Son yükleme ağ katmanında düştü mü. `games`'i EZMİYOR: elde liste varsa
  // liste yerinde kalır ve üstünde yalnızca "Güncellenemedi" şeridi görünür;
  // elde hiçbir şey yoksa "yüklenemedi" paneli çıkar. Eskiden başarısız bir
  // istek `[]` olarak geldiğinden ekran "Devam eden bir Canlı oyunun yok."
  // diyordu — sunucunun gerçekten boş dediği durumdan ayırt edilemiyordu.
  const [loadFailed, setLoadFailed] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [creating, setCreating] = useState(false);
  const [busyInviteId, setBusyInviteId] = useState<string | null>(null);
  // Bir daveti kabul ettikten sonra, o oyundaki henüz arkadaş olunmayan
  // katılımcılara toplu istek gönderme önerisi (bkz. FriendSuggestModal).
  const [suggestCandidates, setSuggestCandidates] = useState<HumanSlot[] | null>(null);

  // İlk yükleme (mount effect) ve sonraki tüm reload() çağrıları (Realtime,
  // foreground, davet yanıtı, yeni oyun oluşturma) AYNI unmount korumasını
  // paylaşır — önceden yalnızca ilk yükleme kendi yerel cancelledRef'ini
  // taşıyordu, reload() unmount sonrası tetiklenirse setGames/setTurns/
  // setDeadlines unmounted bir bileşende çalışabiliyordu (tutarsız/kırılgan).
  // Bu ref, o an GEÇERLİ olan iptal jetonunu tutar: jetonun kendisi her
  // effect çalıştırmasında yenilenir (bkz. aşağıdaki effect), böylece
  // kullanıcı değişiminde önceki çalıştırmanın uçuştaki isteği kalıcı
  // olarak iptal kalır ve eski hesabın listesini yazamaz.
  const cancelledRef = useRef({ current: false });

  const [subTab, setSubTab] = useState<SubTab>('active');
  // Varsayılan tab seçimi ("bekleyen davet varsa Oyun Davetleri, yoksa
  // Devam Edenler") yalnızca veri İLK kez yüklendiğinde bir kez uygulanır —
  // bu ref sayesinde kullanıcı sonradan elle başka bir taba geçerse (ör. Son
  // Oynanan'a bakarken bir Realtime güncellemesi gelirse) bir daha zorlanmaz.
  const appliedDefaultTabRef = useRef(false);
  // Varsayılan sekme kararı SUNUCUDAN gelen taze listeye göre verilmeli, mount
  // anında `liveGamesCache`'ten okunan bayat listeye göre değil (bkz. 5 Ağustos
  // 2026 hatası, CLAUDE.md) — önbellek dolu olduğunda `games` mount'ta hiç
  // `null` olmadığından effect bayat veriyle çalışıp ref'i tüketiyor, taze veri
  // daveti getirdiğinde sekme bir daha düzelmiyordu.
  const [hasFreshGames, setHasFreshGames] = useState(false);
  // Son uygulanan hesabın id'si — `user` referansı hesap değişmeden de
  // değiştiğinden (aşağı bkz.) sıfırlama kararı buna göre veriliyor.
  const lastUserIdRef = useRef<string | null>(user?.id ?? null);
  // Uzun bir aradan sonra öne dönüş = sekmeye yeniden giriş (bkz.
  // `src/utils/awayReturn.ts` ve Setup.tsx'teki eşi). Kullanıcı "Son
  // Oynananlar"dayken uygulamayı saatlerce arka planda bırakıp dönerse ve o
  // arada bir davet geldiyse, ref tükendiği için varsayılan sekme kararı bir
  // daha hiç verilmiyordu — badge artıyor ama davet görünmüyordu.
  const awayTrackerRef = useRef(createAwayTracker());

  // Otomatik yeniden deneme merdiveni — kullanıcı "Tekrar Dene"ye basmak
  // ZORUNDA kalmasın diye. Bir yükleme düştüğünde ekran kendi kendini
  // onarır: 3s → 8s → 20s → sonra 30s'de bir. Yalnızca sekme GÖRÜNÜRKEN
  // zamanlanır (arka planda pil/veri yakmaz; öne dönüşte zaten
  // `scheduleReload` tetikleniyor). Bu merdiven olmadan tek bir düşen istek
  // kalıcı bir yanlış ekrana dönüşüyordu: `loadGames`'i yeniden çağıran tek
  // şey öne dönüş ya da bir Realtime olayıydı ve ekrana bakıp bekleyen
  // birinde ikisi de olmuyor (21 Ağustos 2026 vakası — kullanıcı oyununu
  // ~9 dakika bulamadı).
  const AUTO_RETRY_STEPS_MS = [3000, 8000, 20000, 30000];
  const autoRetryStepRef = useRef(0);
  const autoRetryTimerRef = useRef<number | null>(null);
  const clearAutoRetry = () => {
    if (autoRetryTimerRef.current != null) {
      window.clearTimeout(autoRetryTimerRef.current);
      autoRetryTimerRef.current = null;
    }
  };
  // `loadGames` ile karşılıklı bağımlı olduklarından (merdiven loadGames'i
  // çağırır, loadGames merdiveni kurar) çağrı bir ref üzerinden yapılıyor.
  const loadGamesRef = useRef<(t?: { current: boolean }) => void>(() => {});
  const scheduleAutoRetry = () => {
    if (autoRetryTimerRef.current != null) return;
    if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return;
    const step = Math.min(autoRetryStepRef.current, AUTO_RETRY_STEPS_MS.length - 1);
    const delay = AUTO_RETRY_STEPS_MS[step];
    autoRetryStepRef.current = step + 1;
    autoRetryTimerRef.current = window.setTimeout(() => {
      autoRetryTimerRef.current = null;
      loadGamesRef.current(cancelledRef.current);
    }, delay);
  };

  // Listeyi çeker, aktif oyunların sırasını/son tarihini yükler; süresi
  // ZATEN dolmuş bir sıra varsa `check_turn_timeout`'u (no-op değilse
  // otomatik teslim uygulanır), 7 gündür yanıtlanmamış bir davet/oyun varsa
  // `check_invite_expiry`'yi (no-op değilse oyun iptal edilir) tetikleyip
  // listeyi bir kez daha tazeler — böylece asılı kalmış bir Canlı oyun,
  // kullanıcı bu sekmeyi her açtığında kendiliğinden çözülür (bkz. CLAUDE.md
  // "Canlı Oyun — Faz 3.6").
  const loadGames = async (cancelledRef?: { current: boolean }) => {
    const rows = await listMyOnlineGames();
    if (cancelledRef?.current) return;
    if (rows === null) {
      // ELDE VAR OLANI EZME. `setGames([])` demek "sunucu boş dedi" demekti.
      setLoadFailed(true);
      scheduleAutoRetry();
      return;
    }
    setLoadFailed(false);
    clearAutoRetry();
    autoRetryStepRef.current = 0;
    setGames(rows);
    setHasFreshGames(true);

    const expiredInviteIds = rows
      .filter((g) => g.status === 'pending' && Date.parse(g.created_at) + ABANDON_TIMEOUT_MS <= Date.now())
      .map((g) => g.id);
    const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
    if (activeIds.length === 0 && expiredInviteIds.length === 0) {
      setTurns({});
      setGlances({});
      return;
    }

    // Tip açıkça yazılmak zorunda: `[{}, {}]` dalı olmasa çıkarım doğru
    // çalışırdı, onunla birlikte birleşim `{}`e düşüp indekslemeyi kırıyor.
    const [turnMap, glanceMap]: [
      Record<string, number> | null,
      Record<string, OnlineGameGlance> | null,
    ] =
      activeIds.length > 0
        ? await Promise.all([fetchOnlineGameTurns(activeIds), fetchOnlineGameGlances(activeIds)])
        : [{}, {}];
    if (cancelledRef?.current) return;
    // Liste geldi ama sıra/son tarih gelmediyse SON BİLİNENİ koru: boş
    // haritayla ezmek "sıra sende"yi sessizce "sıra rakipte"ye çevirirdi
    // (`turns[g.id] === mySlotIndex(g)` false kalır) — kullanıcıya yanlış bir
    // gerçeklik anlatıp beklemesine yol açan, listeden daha kötü bir hata.
    if (turnMap === null || glanceMap === null) {
      setLoadFailed(true);
      scheduleAutoRetry();
    }
    if (turnMap !== null) setTurns(turnMap);
    if (glanceMap !== null) setGlances(glanceMap);

    const expiredTurns = activeIds.filter((id) => {
      const d = glanceMap?.[id]?.deadline;
      return d && new Date(d).getTime() <= Date.now();
    });
    if (expiredTurns.length === 0 && expiredInviteIds.length === 0) return;
    await Promise.all([
      ...expiredTurns.map((id) => checkOnlineGameTurnTimeout(id)),
      ...expiredInviteIds.map((id) => checkInviteExpiry(id)),
    ]);
    if (cancelledRef?.current) return;
    const rows2 = await listMyOnlineGames();
    if (cancelledRef?.current) return;
    if (rows2 === null) {
      setLoadFailed(true);
      scheduleAutoRetry();
      return;
    }
    setGames(rows2);
    const activeIds2 = rows2.filter((g) => g.status === 'active').map((g) => g.id);
    if (activeIds2.length === 0) {
      setTurns({});
      setGlances({});
      return;
    }
    const [turnMap2, glanceMap2] = await Promise.all([
      fetchOnlineGameTurns(activeIds2),
      fetchOnlineGameGlances(activeIds2),
    ]);
    if (cancelledRef?.current) return;
    if (turnMap2 === null || glanceMap2 === null) {
      setLoadFailed(true);
      scheduleAutoRetry();
    }
    if (turnMap2 !== null) setTurns(turnMap2);
    if (glanceMap2 !== null) setGlances(glanceMap2);
  };
  loadGamesRef.current = (t) => {
    void loadGames(t);
  };

  const reload = () => {
    void loadGames(cancelledRef.current);
  };

  // "Tekrar Dene" — merdiven zaten arka planda deniyor, bu yalnızca sabırsız
  // kullanıcı için. Merdiveni sıfırlamak şart: elle deneme başarısız olursa
  // otomatik zincir en baştan (3s) devam etsin, 30s'lik son basamaktan değil.
  const handleManualRetry = () => {
    clearAutoRetry();
    autoRetryStepRef.current = 0;
    setLoadFailed(false);
    reload();
  };

  // Bir daveti gönderilen/kabul edilen/reddedilen taraf bu sekmeyi zaten
  // açık tutuyorsa (ör. davet gönderilirken alıcı "Arkadaşınla" sekmesinde
  // bekliyorsa), önceden bunu görmenin tek yolu sekmeden çıkıp geri dönmek
  // (yeniden mount) ya da uygulamayı aç/kapa etmekti — online_games/
  // game_invites hiçbir Realtime olayı yayınlamıyordu. Artık ikisi de
  // supabase_realtime publication'ında (bkz. ilgili migration); burada
  // herhangi bir değişiklikte listeyi yeniden çekiyoruz. Art arda gelen
  // birden fazla olayı (ör. bir davet kabul edilince hem game_invites hem
  // online_games değişir) tek bir reload'a indirmek için kısa bir debounce.
  const reloadTimeoutRef = useRef<number | null>(null);
  const scheduleReload = () => {
    if (reloadTimeoutRef.current != null) window.clearTimeout(reloadTimeoutRef.current);
    reloadTimeoutRef.current = window.setTimeout(() => {
      reloadTimeoutRef.current = null;
      reload();
    }, 300);
  };

  useEffect(() => {
    // Hesap değişimi varsayılan-tab kararını sıfırlar: bu bileşen çıkış
    // yapıldığında unmount OLMUYOR (`mainView` çıkışta sıfırlanmıyor), yani
    // ref'ler yaşıyor — sıfırlamasak yeni hesap varsayılan sekme kararını hiç
    // alamazdı. İki kısıt var: (1) karşılaştırma `user` REFERANSINA değil
    // `user.id`'ye bakmak ZORUNDA, çünkü `useAuth` her onAuthStateChange
    // olayında (TOKEN_REFRESHED dahil, kabaca saatte bir) yeni bir User
    // nesnesi set ediyor — referansa bakılsaydı varsayılan sekme saatler
    // sonra yeniden uygulanıp kullanıcıyı oturduğu sekmeden koparırdı
    // ("Sekme OTOMATİK değişmez" kuralı, aşağıda); (2) burada `games`e
    // DOKUNULMAZ — aşağıdaki önbellek-yazma effect'i aynı commit'te ESKİ
    // `games` closure'ıyla çalıştığından, burada yeni hesabın listesini
    // yazmak "yeni user + eski liste" anını açıp önbelleğe yanlış anahtarla
    // yazma penceresi yaratıyordu. O pencereyi kapalı tutan şey, aşağıdaki
    // `!user` dalının çıkışta `games`i `null`a çekmesi (eski davranış,
    // bilerek korundu).
    const uid = user?.id ?? null;
    if (uid !== lastUserIdRef.current) {
      lastUserIdRef.current = uid;
      appliedDefaultTabRef.current = false;
      setHasFreshGames(false);
    }
    if (!user) {
      setGames(null);
      return;
    }
    // Her çalıştırma KENDİ iptal jetonunu alır; `cancelledRef` yalnızca
    // "şu an geçerli olan jeton"u tutar (handleRespond bunu kullanıyor).
    // İlk sürüm tek bir paylaşılan nesneyi yeniden kullanıp her çalıştırmada
    // `false`'a çekiyordu — kullanıcı değişiminde önceki çalıştırmanın hâlâ
    // uçuşta olan isteği böylece iptal edilmemiş sayılıp ESKİ hesabın oyun
    // listesini yazabiliyordu (3 Ağustos 2026 regresyon geçişi).
    const token = { current: false };
    cancelledRef.current = token;
    void loadGames(token);
    // İkinci parametre: soket yeniden bağlandığında (ağ değişimi/uyanma)
    // kaçırılan olaylar kalıcı kayıp olduğundan gerçeği yeniden okuyoruz.
    const unsubscribe = subscribeMyOnlineGames(scheduleReload, scheduleReload);
    // Mobil tarayıcılar (özellikle iOS Safari) arka plana alınan bir
    // sekmenin Realtime websocket'ini askıya alabiliyor — o sırada gelen
    // bir davet/kabul olayı kaçırılabilir (bkz. OnlineGameScreen'deki aynı
    // gerekçe). Ön plana/çevrimiçi'ye dönüşte emniyet için elle de tazele.
    // Masaüstünde sekmeye dönüş genelde visibilitychange+focus'u (bazen
    // online'ı da) neredeyse aynı anda tetiklediğinden `reload()`'u
    // doğrudan değil, realtime olaylarıyla aynı 300ms'lik `scheduleReload`
    // debounce'ından çağırıyoruz — art arda gelenler tek bir isteğe iner.
    const markAway = () => awayTrackerRef.current.markAway();
    const onForeground = () => {
      if (document.visibilityState !== 'visible') return;
      // Yeniden silahlanmak tek başına sekmeyi DEĞİŞTİRMEZ: aşağıdaki
      // varsayılan-sekme effect'i yalnızca bekleyen bir DAVET varsa
      // "Oyun Davetleri"ne geçiyor, yoksa kullanıcı bulunduğu sekmede
      // kalıyor — yani bekleyen iş yokken dönüş hiçbir şeyi oynatmıyor.
      if (awayTrackerRef.current.takeLongAway()) appliedDefaultTabRef.current = false;
      scheduleReload();
    };
    const onVisibility = () => {
      if (document.visibilityState === 'visible') onForeground();
      else markAway();
    };
    // `blur` şart — masaüstünde başka pencereye geçmek `visibilitychange`
    // üretmiyor (bkz. Setup.tsx'teki aynı not).
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('blur', markAway);
    window.addEventListener('focus', onForeground);
    window.addEventListener('online', onForeground);
    return () => {
      token.current = true;
      unsubscribe();
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('blur', markAway);
      window.removeEventListener('focus', onForeground);
      window.removeEventListener('online', onForeground);
      if (reloadTimeoutRef.current != null) window.clearTimeout(reloadTimeoutRef.current);
      clearAutoRetry();
    };
  }, [user]);

  // Varsayılan tab: SUNUCUDAN taze liste geldiğinde bekleyen bir davet varsa
  // "Oyun Davetleri", yoksa "Devam Edenler" açık gelsin. `hasFreshGames`
  // beklemek şart — önbellekten hidrate edilmiş bayat bir listeyle karar
  // verilirse ref tükenip sekme kalıcı olarak yanlış kalıyor (yukarı bkz.).
  // Önbellek doluyken sekmenin kısa bir an sonra "Devam Edenler"den
  // "Oyun Davetleri"ne kayması olağan; kalıcı yanlış sekmeden iyi.
  useEffect(() => {
    if (!hasFreshGames || games === null || appliedDefaultTabRef.current) return;
    appliedDefaultTabRef.current = true;
    // `status === 'pending'` şartı `invites` kovasıyla aynı olmalı (aşağı bkz.)
    // — yoksa süresi dolmuş bir davet, kullanıcıyı hiçbir şeyin görünmediği
    // boş "Oyun Davetleri" sekmesine düşürürdü.
    const hasInvites = games.some(
      (g) => g.my_role === 'invitee' && g.my_invite_status === 'pending' && g.status === 'pending',
    );
    if (hasInvites) setSubTab('invites');
  }, [games, hasFreshGames]);

  // `liveGamesCache`'i her güncellemede tazeler — bir sonraki mount'un
  // gösterebileceği "son bilinen" durum.
  useEffect(() => {
    if (!user || games === null) return;
    liveGamesCache.set(user.id, { games, turns, glances });
  }, [user, games, turns, glances]);

  // ⚠ AŞAĞIDAKİ İKİ HOOK ERKEN `return`LERİN ÜSTÜNDE KALMAK ZORUNDA.
  // 3 Eylül 2026: eklendikleri turda dosyanın SONUNA, yani `if (creating)` /
  // `if (!user)` dallarının ALTINA yazılmışlardı. Sonuç: "Yeni Canlı Oyun"a
  // basınca bileşen erkenden dönüp önceki render'dan DAHA AZ hook çalıştırdı
  // ve React #300 ile ErrorBoundary'ye düştü (canlıda yakalandı, kullanıcı
  // bildirdi). Bu bileşene yeni bir hook eklerken yerini dalların ÜSTÜNE koy.
  // "YENİ" rozetlerinin ZİYARET BOYUNCA sabit kalan enstantanesi (3 Eylül
  // 2026, kullanıcı isteği).
  //
  // Kullanıcının tarifi iki ayrı an içeriyor ve ikisi aynı anda olmuyor:
  //   "Bir kere girip gördüğünde tab numarası SIFIRLANIR"  → giriş anında
  //   "…ve yeni kalkar, sadece Oyun bitti kalır"           → ÇIKIŞTA
  // Yani sunucudaki işaret sekmeye girer girmez temizleniyor (sayı hemen
  // sıfırlanıyor), ama satırdaki rozetler ziyaret bitene kadar duruyor.
  // Anlık listeyi doğrudan bağlasaydık rozetler kullanıcı tam bakarken
  // gözünün önünde kaybolurdu.
  const [freshFinished, setFreshFinished] = useState<ReadonlySet<string>>(
    () => new Set(),
  );
  useEffect(() => {
    if (subTab !== 'recent') {
      // Çıkış: "bir daha girdiğinde yeni rozetleri gösterilmez".
      setFreshFinished((prev) => (prev.size === 0 ? prev : new Set()));
      return;
    }
    // Boşken erken çıkmak ŞART: işaretleme başarılı olunca liste [] olarak
    // geri gelip bu effect'i tekrar koşturuyor — enstantaneyi burada
    // temizleseydik rozetler girişten saniyeler sonra silinirdi.
    if (newlyFinishedIds.length === 0) return;
    setFreshFinished(new Set(newlyFinishedIds));
    let cancelled = false;
    void markGameFinishesSeen().then((ok) => {
      // ⚠ Yalnızca sunucu ONAYLARSA sıfırla. Çevrimdışıyken yerelde
      // sıfırlamak rozeti kaybettirir, sunucuda ise hâlâ görülmemiş durur —
      // bir sonraki tazelemede geri gelir ve "kayboldu sonra döndü" diye
      // tuhaf görünürdü. Bu kod tabanında tek seferlik kararların BAŞARISIZ
      // veriyle tüketilmesi üç kez hata olarak kayıtlı.
      if (!cancelled && ok) onFinishesSeen();
    });
    return () => {
      cancelled = true;
    };
  }, [subTab, newlyFinishedIds, onFinishesSeen]);

  if (authLoading) return null;

  if (creating) {
    // "Son Oynananlar" burada bilerek gösterilmiyor — artık kendi tabında
    // (aşağıdaki tab satırı) her zaman erişilebilir; kurulum formunun
    // (arkadaş seçimi vb.) hemen altında tekrar çıkması yalnızca gürültü
    // yaratıyordu (kullanıcı geri bildirimi).
    return (
      <div className="w-full flex flex-col gap-5">
        <LiveGameCreateForm
          onCancel={() => setCreating(false)}
          onCreated={() => {
            setCreating(false);
            reload();
          }}
        />
      </div>
    );
  }

  if (!user) {
    return (
      <>
        {showAuthModal && <AuthModal onClose={() => setShowAuthModal(false)} />}
        <div className="w-full flex flex-col items-center gap-4 text-center py-4">
          <p className="text-sm text-muted font-sans">
            Canlı oyun oynamak için giriş yapmalısın.
          </p>
          <button
            onClick={() => setShowAuthModal(true)}
            className="btn-raised py-2.5 px-6 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
          >
            Giriş Yap
          </button>
        </div>
      </>
    );
  }

  const handleRespond = async (game: OnlineGame, accept: boolean) => {
    if (!game.my_invite_id) return;
    setBusyInviteId(game.my_invite_id);
    try {
      await respondToGameInvite(game.my_invite_id, accept);
      if (accept) {
        const candidates = game.slots.filter(
          (s): s is HumanSlot => s.type === 'human' && s.relation !== 'self' && s.relation !== 'accepted',
        );
        if (candidates.length > 0) setSuggestCandidates(candidates);
      }
      // reload()'un aksine (fire-and-forget) burada bilerek await ediliyor —
      // önceden busy göstergesi liste tazelenmeden kayboluyordu, kullanıcı
      // aynı davete art arda iki kez tıklayabiliyordu.
      await loadGames(cancelledRef.current);
    } catch (err) {
      console.error('[Kelimeki] respondToGameInvite hatası:', err);
    } finally {
      setBusyInviteId(null);
    }
  };

  // `g.status === 'pending'` ŞART: `check_invite_expiry` süresi dolan bir
  // daveti iptal ederken yalnızca `online_games.status`'ü `'abandoned'` yapıp
  // `game_invites` satırına (kayıt kalsın diye) bilerek dokunmuyor. Bu kontrol
  // olmadan iptal edilmiş bir davet DAVETLİNİN listesinde sonsuza dek
  // duruyordu — kuranın tarafı (`waiting`, aşağıda) baştan beri `status`'e
  // baktığından orada doğru kayboluyordu, asimetri buradaydı (4 Ağustos 2026).
  // Süresi bitmeye en yakın davet ÜSTTE (3 Eylül 2026, kullanıcı isteği).
  // Davet süresi `created_at + ABANDON_TIMEOUT_MS` (bkz.
  // `remainingInviteDays`), yani EN ESKİ davet en yakın olandır.
  const davetBitis = (g: OnlineGame) => Date.parse(g.created_at) || null;
  const invites = orderByExpiry(
    (games ?? []).filter(
      (g) => g.my_role === 'invitee' && g.my_invite_status === 'pending' && g.status === 'pending',
    ),
    davetBitis,
  );
  // Sırası kendisinde olan oyunlar ("Senin Hamlen Bekleniyor") listenin en
  // üstünde — dikkat gerektiren oyunlar her zaman ilk bakışta görünsün diye.
  // İKİNCİ ölçüt: son oynanan üstte.
  //
  // ⚠ 31 Ağustos 2026 — burada eskiden ikinci ölçüt YOKTU; yorum, kararlı
  // sort sayesinde `games`'in geldiği sıranın "en son güncellenen önce"
  // olduğunu VARSAYIYORDU. Yanlıştı: `list_my_online_games` RPC'si
  // `order by og.created_at desc` ile dönüyor, yani oyunun KURULMA sırası.
  // Sonuç, kullanıcının bildirdiği davranıştı — az önce oynadığın oyun
  // listede yerinde kalıyordu (*"son oynanan her zaman en üstte olacak"*).
  //
  // Ölçüt olarak `turn_deadline` kullanılıyor: `submit_move` her hamlede onu
  // `now() + 48 saat` yapıyor, dolayısıyla deadline'ı geç olan = son
  // oynanan. Ek bir sorgu/alan gerekmiyor, `glances` zaten yüklü. Null
  // (henüz kurulmamış state) EN SONA düşer.
  // ⚠ Null → NULL döner, 0 DEĞİL. Eski hâli 0'dı ve yalnızca AZALAN
  // sıralamada zararsızdı (dibe düşerdi); "sıra bende" grubu 3 Eylül'de
  // ARTANA çevrilince 0 "en yakın bitiş" sanılıp EN ÜSTE çıkardı.
  // `orderActiveGames` null'ı her iki grupta da sona koyuyor.
  const sonHamle = (g: OnlineGame) => {
    const d = glances[g.id]?.deadline;
    return d ? new Date(d).getTime() : null;
  };
  const active = orderActiveGames(
    (games ?? []).filter((g) => g.status === 'active'),
    { myTurn: (g) => turns[g.id] === mySlotIndex(g), deadlineMs: sonHamle },
  );
  const waiting = orderByExpiry(
    (games ?? []).filter((g) => g.my_role === 'creator' && g.status === 'pending'),
    davetBitis,
  );
  // Daveti kabul ettin ama oyun (4 kişilikte diğer davetliler henüz
  // kabul etmediğinden) hâlâ 'pending' — `invites`/`active`/`waiting`
  // hiçbirine düşmediğinden bir kategori eksikti, oyun listede hiç
  // görünmüyordu (kabul ettikten sonra "kayboluyor" gibi görünüyordu).
  const acceptedWaiting = orderByExpiry(
    (games ?? []).filter(
      (g) => g.my_role === 'invitee' && g.my_invite_status === 'accepted' && g.status === 'pending',
    ),
    davetBitis,
  );
  // İlk iki tabın kırmızı rozeti — Setup'taki "Arkadaşınla (N)" rozetiyle
  // aynı iki sayı: gerçekten hamle bekleyen (sırası çağıranda olan) aktif
  // oyun sayısı, ve yanıt bekleyen davet sayısı. "Kabul Ettin — Diğerleri
  // Bekleniyor"/"Bekleyen Oyunlar" bilerek dahil değil — onlar başkasının
  // hamlesini/yanıtını bekliyor, kullanıcının kendisinden bir eylem
  // gerektirmiyor.
  const myTurnCount = active.filter((g) => turns[g.id] === mySlotIndex(g)).length;
  const inviteCount = invites.length;


  const SUB_TABS: { key: SubTab; label: string; badge: number }[] = [
    { key: 'active', label: 'Devam Edenler', badge: myTurnCount },
    { key: 'invites', label: 'Oyun Davetleri', badge: inviteCount },
    // 3 Eylül 2026: bu rozet "yapacak iş" DEĞİL, HABER — bitişini görmediğin
    // oyunlar. İlk ikisinden farkı bu; yine de aynı görsel dille gösteriliyor
    // çünkü kullanıcının fark etmesini istediğimiz şey aynı.
    { key: 'recent', label: 'Son Oynananlar', badge: newlyFinishedIds.length },
  ];

  // Davet/bekleme kartlarındaki TÜM insan koltuklarının puanları tek çekimde
  // (ParticipantRow bunları context'ten okuyor).
  const participantIds = (games ?? []).flatMap((g) =>
    g.slots.filter((s): s is HumanSlot => s.type === 'human').map((s) => s.user_id),
  );

  return (
    <RankTierProvider userIds={participantIds}>
    <div className="w-full flex flex-col gap-5">
      {suggestCandidates && (
        <FriendSuggestModal candidates={suggestCandidates} onDone={() => setSuggestCandidates(null)} />
      )}

      <button
        onClick={() => setCreating(true)}
        className="btn-raised-orange py-2.5 rounded-md font-sans text-sm font-bold uppercase tracking-[1.5px] bg-orange text-white active:scale-[0.97] transition-transform"
      >
        + Yeni Canlı Oyun Aç
      </button>

      <div className="flex gap-2">
        {SUB_TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => {
              // Elle bir sekme seçildiği an varsayılan-sekme effect'i (yukarı)
              // devre dışı bırakılır: `games` henüz yüklenmemişken (null)
              // kullanıcı bir sekmeye dokunursa, liste birkaç yüz ms sonra
              // gelince effect çalışıp seçimi eziyordu — dar ama gerçek bir
              // yarış durumu (4 Ağustos 2026).
              appliedDefaultTabRef.current = true;
              setSubTab(tab.key);
            }}
            className={[
              'relative flex-1 py-2.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[0.5px] border transition-transform active:scale-[0.97] flex items-center justify-center',
              subTab === tab.key
                ? 'btn-raised bg-accent text-white border-accent'
                : 'btn-raised-neutral bg-panel text-text border-border',
            ].join(' ')}
          >
            {tab.label}
            {tab.badge > 0 && <CountBadge count={tab.badge} className="absolute -top-1 -right-1" />}
          </button>
        ))}
      </div>

      {/* Çevrimdışıyken ÜÇ alt sekme de aynı şeyi söyler: Canlı oyunun her
          parçası (liste, davet, geçmiş) sunucudan geliyor, dolayısıyla
          "Devam eden bir Canlı oyunun yok." / "Yükleniyor…" gibi metinler
          çevrimdışıyken YANILTICI — kullanıcı bunu bizzat bildirdi
          (14 Ağustos 2026): oyun ekranından geri dönünce "davetiniz yok"
          ve "yükleniyor" görüyordu. Bayat bir liste göstermek de çözüm
          değil; o listeden bir oyuna dokunmak zaten "bağlantı yok"
          paneline çıkıyor (bkz. OnlineGameScreen). Yapay Zeka sekmesi
          BİLİNÇLİ olarak farklı konuşur — orada çevrimdışı oynanabilir bir
          şey var (bkz. Setup.tsx). */}
      {!online ? (
        <p className="text-center text-xs text-muted font-mono py-8">{OFFLINE_NO_CONNECTION}</p>
      ) : games === null ? (
        // Elde HİÇ liste yok. `loadFailed` ile "henüz gelmedi"yi ayırmak
        // şart: ikisi de "Yükleniyor…" gösterseydi ekran sonsuza dek asılı
        // kalırdı (14 Ağustos 2026'da oyun ekranında yaşanan aynı hata).
        loadFailed ? (
          <div className="flex flex-col items-center gap-3 py-8">
            <p className="text-center text-xs text-muted font-mono">{LOAD_FAILED_NOTICE}</p>
            <button
              onClick={handleManualRetry}
              className="btn-raised py-2.5 px-6 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              {RETRY_LABEL}
            </button>
          </div>
        ) : (
          <p className="text-center text-xs text-muted font-mono py-8">Yükleniyor…</p>
        )
      ) : (
        <>
          {/* Liste DOĞRU, yalnızca bayat — o yüzden ekranı kaplamayan ince
              bir not. Kullanıcının yapması gereken bir şey yok; merdiven
              arka planda deniyor ve başarınca bu şerit kendiliğinden kalkar. */}
          {loadFailed && (
            <p className="text-center text-[10px] text-muted font-mono uppercase tracking-[0.5px]">
              {STALE_DATA_NOTICE}
            </p>
          )}
          {subTab === 'active' ? (
        active.length === 0 ? (
          <p className="text-center text-xs text-muted font-mono py-8">Devam eden bir Canlı oyunun yok.</p>
        ) : (
          <Section title="Devam Eden Oyunlar" games={active} onOpenGame={onOpenGame} turns={turns} glances={glances} />
        )
      ) : subTab === 'invites' ? (
        invites.length === 0 && acceptedWaiting.length === 0 && waiting.length === 0 ? (
          <p className="text-center text-xs text-muted font-mono py-8">Bekleyen bir davet ya da oyunun yok.</p>
        ) : (
          <>
            {invites.length > 0 && (
              <div className="flex flex-col gap-2">
                <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                  Davet Bekliyor
                </div>
                <div className="flex flex-col gap-2">
                  {invites.map((g) => (
                    <GameRow
                      key={g.id}
                      game={g}
                      onRespond={(accept) => handleRespond(g, accept)}
                      busy={busyInviteId === g.my_invite_id}
                    />
                  ))}
                </div>
              </div>
            )}
            <PendingSection title="Kabul Ettin — Diğerleri Bekleniyor" games={acceptedWaiting} />
            <PendingSection title="Bekleyen Oyunlar" games={waiting} />
          </>
        )
          ) : (
            <RecentGamesSection
              onlineOnly
              emptyMessage="Henüz bitmiş bir Canlı oyunun yok."
              newlyFinishedIds={freshFinished}
              /* Avatar çözümü için canlı koltuklar (2 Eylül 2026). Bu liste
                 ZATEN elde: `list_my_online_games` durum filtresi taşımıyor,
                 yani bitmiş oyunlar da içinde — ikinci bir istek yok. */
              onlineGames={(games ?? []).map((g) => ({
                id: g.id,
                slots: g.slots.map((s) => ({
                  name: s.type === 'human' ? (s.name ?? null) : null,
                  avatarUrl: s.type === 'human' ? (s.avatar_url ?? null) : null,
                })),
              }))}
            />
          )}
        </>
      )}
    </div>
    </RankTierProvider>
  );
}
