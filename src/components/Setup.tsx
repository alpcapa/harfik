// Kelimeki — oyun kurulum ekranı: oyuncu sayısı (2/4) seçimi
import { useCallback, useEffect, useRef, useState } from "react";
import { GUEST_PLAYER_NAME, PLAYER_COLORS } from "../game/constants";
import type { PlayerSetup } from "../game/gameReducer";
import type { AiLevel } from "../game/types";
import { AI_LEVEL_LABEL, SELECTABLE_AI_LEVELS, aiLevelDescription, aiLevelOf } from "../utils/aiLevel";
import { scoreLine } from "../utils/scoreLine";
import { AiLevelBadge } from "./AiLevelBadge";
import { useAuth } from "../hooks/useAuth";
import { useModalA11y } from "../hooks/useModalA11y";
import { subscribeMyOnlineGames } from "../lib/api";
import { hasSeenQuickStart, markQuickStartSeen } from "../utils/onboarding";
import { ABANDON_TIMEOUT_MS, type SavedGame } from "../utils/gameStorage";
import {
  decideInitialMainView,
  fetchPendingLiveGameCounts,
  type PendingLiveGameCounts,
} from "../utils/pendingLiveGames";
import { preloadWordSet, isWordSetReady } from "../data/wordSetLoader";
import { Avatar } from "./Avatar";
import { AuthModal } from "./AuthModal";
import { CountBadge } from "./CountBadge";
import { HelpModal } from "./HelpModal";
import { LiveGamesTab, TurnTriangle } from "./LiveGamesTab";
import { orderByExpiry } from "../utils/gameListOrder";
import { LogoMark } from "./LogoMark";
import { PlayerAvatarRow, type AvatarRowPlayer } from "./PlayerAvatarRow";
import { PlayerBadge } from "./PlayerBadge";
import { RankSeal } from "./RankSeal";
import { useRankScores } from "../hooks/useRankScores";
import { RecentGamesSection } from "./RecentGamesSection";
import { ShareIcon } from "./RelationIcons";
import { shareKelimekiLink } from "../utils/shareLink";
import { createAwayTracker } from "../utils/awayReturn";
import { useOnlineStatus } from "../hooks/useOnlineStatus";
import { OFFLINE_AI_SUGGESTION, OFFLINE_AI_CTA } from "../utils/offlineNotice";
import { TermsModal } from "./TermsModal";
import { PrivacyModal } from "./PrivacyModal";
import type { LocalGameSave, OnlineGame } from "../lib/database.types";

// "Devam Eden Oyun" satırındaki kalan süre — gameStorage.ts'teki
// ABANDON_TIMEOUT_MS (7 gün) ile aynı terk-silme kuralına göre, son kayıt
// (savedAt) anından itibaren. `willSurrender` yalnızca GİRİŞLİ kullanıcının
// bulut kaydı için anlamlı: true ise (turnCount>=2 — en az bir tam tur
// oynanmış) süre dolunca hesabına GERÇEKTEN/hemen -2 teslim cezası uygulanır
// (bkz. CLAUDE.md "Terk edilen oyunun otomatik temizliği"), "teslim
// sayılacak" gösterilir; false ise (henüz hiç hamle yok, ceza yok) "silinecek"
// metni kullanılır. Misafirin (girişsiz) tekil kaydı için bu her zaman
// `false` geçilir — misafirin bir hesabı olmadığından hiçbir puan hemen
// düşmez; süre dolunca o kaydın kesin/garanti sonucu yalnızca localStorage'dan
// silinmesidir (turnCount>=2 ise ayrıca bir teslim kaydı sessizce kuyruğa
// alınır ama bu yalnızca kişi AYNI cihazda 7 gün içinde üye olursa devreye
// girer — koşullu bir iç detay, misafire "teslim sayılacaksın" demek
// yanıltıcı olurdu). Kırmızı (kalın değil — 31 Temmuz 2026'da kullanıcı
// isteğiyle font-bold kaldırıldı) kalan süre 24 saatin altına inince devreye
// giriyor — o noktadan itibaren metin de "gün" yerine dakika hassasiyetinde
// saat gösterir (LiveGamesTab'daki aktif Canlı oyun kalan-süre etiketiyle
// aynı mantık/stil).
function remainingTime(
  savedAt: number,
  willSurrender: boolean,
): { text: string; urgent: boolean } {
  const verb = willSurrender ? "teslim sayılacak" : "silinecek";
  const ms = savedAt + ABANDON_TIMEOUT_MS - Date.now();
  // ⚠ Fiil (`verb`) YALNIZCA süre DOLDUĞUNDA görünüyor artık. 30 Ağustos
  // 2026'da kullanıcı üç sayacın da yalnızca "… kaldı" demesini istedi
  // (LiveGamesTab'ın iki sayacıyla aynı kalıp). Geri sayarken kartın kendisi
  // zaten "devam eden oyun" diyor; ama süre dolmuş bir satırda "Bugün"
  // tek başına hiçbir şey anlatmayacağından o dalda fiil KALDI — ve tam
  // orada bilgi değeri en yüksek (silinme ↔ teslim cezası ayrımı).
  if (ms <= 0) return { text: `Bugün ${verb}`, urgent: true };
  const totalMinutes = Math.ceil(ms / (60 * 1000));
  const totalHours = Math.floor(totalMinutes / 60);
  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;
  const minutes = totalMinutes % 60;
  // Parantez içindeki sonuç (30 Ağustos 2026, kullanıcı isteği) —
  // `LiveGamesTab`'ın aktif oyun sayacıyla aynı kalıp. ⚠ İki dal AYRI:
  // `willSurrender` false iken -2 diye bir ceza YOK (henüz bir tam tur
  // oynanmamış), o kayıt yalnızca siliniyor — oraya "Teslim -2 puan" yazmak
  // olmayan bir cezayla korkutmak olurdu. Ayrım zaten `verb`de vardı.
  const sonuc = willSurrender ? "teslim (-2 puan)" : "silinecek";
  const text =
    days > 0
      ? `${days} gün ${hours} saat sonra ${sonuc}`
      : `${hours} saat ${minutes} dk sonra ${sonuc}`;
  return { text, urgent: days < 1 };
}

// Misafire (girişsiz) kurulum formunun altında gösterilen üyelik faydaları
// kutusu — 31 Temmuz 2026'da kullanıcı isteğiyle eklendi. Yalnızca "Yapay
// Zeka ile" sekmesinde, hem 2 hem 4 oyunculu alt sekmede görünür (bu kutunun
// kullanıldığı `else` dalı `count`'tan bağımsız olduğundan otomatik ikisinde
// de çıkıyor); girişli kullanıcı "+ Yeni Yapay Zeka Oyunu" formunu açtığında
// (aynı `else` dalına düşse de) `!user` koşuluyla gizli kalır.
const MEMBERSHIP_PERKS = [
  "Arkadaşlarınla çoklu canlı oyun oynama",
  "Skor takibi ve k-lig sıralaması",
  "Aynı anda birden fazla Yapay Zeka oyunu oynama",
  "Cihazlar arası kesintisiz devam etme",
  "Oyun geçmişini saklama, beğenme ve paylaşma",
  "Arkadaş ekleyip listende tutma",
];

function MembershipPerksBox({
  onSignup,
  className = "",
}: {
  onSignup: () => void;
  className?: string;
}) {
  return (
    <div
      className={`shadow-raised flex flex-col gap-2.5 rounded-md px-3.5 py-3 border border-accent/30 bg-accent/5 ${className}`}
    >
      <div className="font-sans text-sm font-bold text-text">
        Neden Ücretsiz Üye Olmalıyım?
      </div>
      <ul className="flex flex-col gap-1.5">
        {MEMBERSHIP_PERKS.map((perk) => (
          <li
            key={perk}
            className="flex items-start gap-2 text-[11px] font-mono text-muted leading-snug"
          >
            <span className="text-green font-bold shrink-0" aria-hidden="true">
              ✓
            </span>
            {perk}
          </li>
        ))}
      </ul>
      <button
        onClick={onSignup}
        className="btn-raised-neutral py-2 rounded-md font-sans text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform"
      >
        Giriş Yap / Kayıt Ol
      </button>
    </div>
  );
}

/**
 * Kaydedilmiş bir yerel (YZ) oyunun oyuncularını "Devam Eden Oyun"
 * satırındaki avatarlara çevirir — YZ koltukları robot avatarı alır.
 *
 * İnsan koltuğu yerel oyunda HER ZAMAN 0. koltuktur ve her zaman bu
 * cihazdaki kişidir (bkz. `doStart`), ama `GameState` avatar taşımaz
 * (`Player`'da böyle bir alan yok) — bu yüzden fotoğraf dondurulmuş
 * state'ten değil O ANKİ profilden okunur. Kullanıcı isteğinin "misafirken
 * '?' görünür, giriş yapınca kişinin gerçek avatarına döner" kısmı bu
 * sayede ek bir taşıma/migration gerektirmeden kendiliğinden çalışıyor:
 * misafirin kaydı giriş sonrası zaten hesaba taşınıyor (bkz. CLAUDE.md,
 * `migratingSavedGameRef`) ve o satır artık `profile` ile render ediliyor.
 */
function savedGameAvatars(
  players: { name: string; isAI: boolean }[],
  avatarUrl: string | null | undefined,
  isGuest: boolean,
): AvatarRowPlayer[] {
  return players.map((p) =>
    p.isAI
      ? { name: "Yapay Zeka", isAi: true }
      : { name: p.name, avatarUrl, isGuest },
  );
}

/**
 * "Devam Eden Oyun" satırı — misafirin tekil localStorage kaydında (bkz.
 * `savedGame` prop'u) ve girişli kullanıcının `cloudSaves` listesindeki her
 * satırda AYNI görsel/etkileşim deseni kullanılsın diye ortak bileşene
 * çıkarıldı.
 */
function SavedGameRow({
  players,
  savedAtMs,
  willSurrender,
  aiLevel,
  scores,
  onClick,
}: {
  players: AvatarRowPlayer[];
  savedAtMs: number;
  willSurrender: boolean;
  /** `aiLevelOf(GameState.aiLevel)` — yerel kayıt her zaman YZ oyunu, rozet her seviyede (Normal turuncu). */
  aiLevel: AiLevel;
  /** Koltuk sırasıyla anlık puanlar (`state.players[].score`) — avatarların altındaki puan satırı. */
  scores: number[];
  onClick: () => void;
}) {
  const remaining = remainingTime(savedAtMs, willSurrender);
  return (
    <button
      onClick={onClick}
      className="shadow-raised flex flex-col rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left active:scale-[0.99] transition-transform"
    >
      {/* 2 Eylül 2026 — SÜRE SATIRI KARTIN ALTINA ALINDI (kullanıcı, cihazda:
          *"Sıra Sende kutunun ortasında çıkıyor, Sıra Rakipte düzgün; Sıra
          Sende'yi de aynı şekle getirelim, sadece kalan süre en altta
          çıkabilir"*). Önceki yapıda durum ve süre TEK bir sağ sütundaydı ve
          o sütunun enini SÜRE belirliyordu — ölçüldü (portun ikizinde,
          320 px): "SIRA SENDE" 89,6 px, süre satırı **194,3 px**. Yani
          isim alanını daraltan etiket değil süreydi, üstelik yazı ölçeği
          1,0'da bile. Şimdi üst satır sol=oyuncular / sağ=durum, süre altta
          tam genişlik (sağa yaslı — görsel çapa değişmedi). */}
      <span className="flex items-center gap-2.5">
        {/* Avatar şeridi + zorluk rozeti YAN YANA (6 Eylül 2026 gece, kullanıcı:
            rozet alt satırda tam genişliğe uzuyordu — `flex-col` çocuğu
            yatayda geriliyor; satırda rozet kendi eninde kalır). */}
        <span className="flex-1 min-w-0 flex flex-col gap-0.5">
          <span className="flex items-center gap-1.5">
          {/* "N Kişilik Oyun" başlığının yerine katılımcı avatarları —
            `LiveGamesTab`'daki Canlı oyun kartlarıyla BİREBİR AYNI desen
            (kullanıcı isteği: YZ oyunlarında da Canlı'daki gibi avatar).
            Avatar sayısı zaten oyuncu sayısını gösterdiğinden metin bilgi
            kaybettirmiyor. */}
          {/* 2 Eylül 2026 — altındaki "Sıra: X" satırı KALDIRILDI (kullanıcı
            isteği): yanındaki `SIRA SENDE` ile aynı şeyi söylüyordu. Canlı
            oyun kartının (`LiveGamesTab`) aynı yerdeki "X açtı" satırı da 6
            Eylül 2026'da kalktı (kurucu zaten ilk avatar); iki kartın sol
            sütunu artık aynı: avatar şeridi + altında PUAN SATIRI. */}
          <PlayerAvatarRow players={players} />
          {/* Zorluk rozeti (ROADMAP #23 Faz 3; 6 Eylül 2026'dan beri Normal
            de çizilir, turuncu) — avatarların hemen sağında. ⚠ Aynı düzeni
            paylaşan `LiveGamesTab` kartı ETKİLENMEZ — o Canlı, orada seviye
            yok. */}
          <AiLevelBadge level={aiLevel} />
          </span>
          {/* PUAN SATIRI (6 Eylül 2026, kullanıcı isteği) — koltuk sırasıyla,
            N'inci sayı N'inci yüzün altında; punto/harf aralığı alttaki
            kalan-süre satırıyla AYNI. Canlı kartı (`LiveGamesTab`) ve "Son
            Oynananlar" da aynı satırı çiziyor (`utils/scoreLine.ts`). */}
          <span className="text-[8px] font-mono tracking-[0.5px] text-muted truncate">
            {scoreLine(scores)}
          </span>
        </span>
        {/* Metin ve punto `LiveGamesTab`'ın aktif oyun kartıyla BİREBİR
          (30 Ağustos 2026, kullanıcı isteği) — bu kart YZ oyunu, orası
          Canlı oyun, ama ikisi de "devam eden oyun" satırı ve kullanıcı
          ikisini yan yana görüyor. Burada koşul yok: yerel kayıt her zaman
          hesap sahibinin sırasında duruyor. */}
        {/* Punto ve üçgen `LiveGamesTab`'ın aktif oyun kartıyla BİREBİR
          (13 → 15 px, 2 Eylül 2026 kullanıcı isteği) — port tarafında ikisi
          de `devamEdenDurumStil`den besleniyor. */}
        <span className="shrink-0 text-[15px] font-mono uppercase tracking-[1px] text-green font-bold">
          SIRA SENDE
          <TurnTriangle />
        </span>
      </span>
      <span
        /* mt-1.5 — LiveGamesTab'ın aktif oyun kartıyla aynı: süre satırı
           durum etiketine yapışmasın (kullanıcı isteği). */
        className={`mt-1.5 self-end text-[8px] font-mono uppercase tracking-[0.5px] ${
          remaining.urgent ? "text-red" : "text-muted"
        }`}
      >
        {remaining.text}
      </span>
    </button>
  );
}

interface SetupProps {
  // showTutorial: oyun ekranı açıldığında Tutorial (HelpModal) daha önce
  // görülmediyse gösterilsin mi — App.tsx bunu oyun ekranı render'ında kullanır.
  /** `aiLevel`: formdaki ZORLUK seçimi (ROADMAP #23 Faz 3) — 4 kişilikte üç YZ'ye birden. */
  onStart: (players: PlayerSetup[], showTutorial: boolean, aiLevel: AiLevel) => void;
  // "Oyun Tipi" seçimi (Yapay Zeka ile / Arkadaşınla) — App.tsx'te tutulur,
  // çünkü Canlı oyun tamamen ayrı bir veri kaynağından (Supabase) besleniyor;
  // Setup burada yalnızca seçiciyi gösterip görünümü değiştirir.
  mainView: "local" | "live";
  onMainViewChange: (view: "local" | "live") => void;
  // "Devam Eden" bir Canlı oyuna tıklanınca (LiveGamesTab), gerçek oyun
  // ekranını açmak için App.tsx'e iletilir (Faz 3, 4. adım).
  onOpenLiveGame: (game: OnlineGame) => void;
  // Yarım kalan yerel (YZ) oyun (localStorage'dan, App.tsx'te tutulur) —
  // yalnızca MİSAFİR (girişsiz) kullanıcı için anlamlıdır: varsa "Yapay Zeka
  // ile" sekmesinde normal kurulum formu yerine tek bir "Devam Eden Oyun"
  // satırı gösterilir, yeni bir yerel oyun bu kayıt bitene/teslim olunana
  // kadar başlatılamaz (bkz. CLAUDE.md "Devam eden oyunun kalıcılığı").
  // Girişli kullanıcı için bunun yerine `cloudSaves` kullanılır.
  savedGame: SavedGame | null;
  onResumeGame: () => void;
  // Girişli kullanıcının `local_game_saves`'teki devam eden YZ oyunları
  // (App.tsx, cihazlar arası + çoklu oyun) — null: misafir ya da henüz
  // çekilmedi, []: girişli ama hiç devam eden oyunu yok. Doluysa/boşsa fark
  // etmeksizin, girişli kullanıcı için normal kurulum formu HER ZAMAN
  // gösterilir (misafirin aksine yeni oyun engellenmez) — liste varsa
  // formun üstünde ayrıca gösterilir.
  cloudSaves: LocalGameSave[] | null;
  onResumeCloudSave: (save: LocalGameSave) => void;
}

export function Setup({
  onStart,
  mainView,
  onMainViewChange,
  onOpenLiveGame,
  savedGame,
  onResumeGame,
  cloudSaves,
  onResumeCloudSave,
}: SetupProps) {
  const { user, profile, loading, profileLoading } = useAuth();
  // 1. koltuktaki hesap sahibinin rütbe mührü. Puan `leaderboard`
  // view'ından geliyor, yani ÖDÜL puanları dahil — 17 Ağustos 2026'da
  // kaldırılan parantezli sayı `player_stats` mod toplamıydı ve o, ödülleri
  // İÇERMEDİĞİ için gerçek k-lig puanından sapıyordu (bkz. kök CLAUDE.md).
  const rankTierOf = useRankScores([user?.id]);
  // Oturum açıldıysa 1. oyuncu her zaman hesap sahibidir. Profil henüz
  // çekilmediyse (profileLoading) e-posta önekine düşmüyoruz — aksi halde
  // sayfa her açılışta profil gelene kadar bir anlık yanlış/geçici bir isim
  // (ör. "alp.capa") gösterip hemen gerçek takma adla değişiyordu.
  const accountName =
    profile?.display_name ||
    profile?.first_name ||
    (user?.email && !profileLoading ? user.email.split("@")[0] : null);
  // Oturum var ama profil henüz gelmediyse (profileLoading) accountName
  // hâlâ null'dur — bu durumda 1. oyuncu satırını "Misafir" olarak
  // göstermek de yanlış: oturum açık biri için bir anlığına "Misafir" yazıp
  // hemen gerçek takma adla değişmek, tıpkı eski e-posta önekine düşme
  // hatası gibi kafa karıştırıcı bir kimlik değişimi izlenimi veriyordu.
  // Bu yüzden bu ara durumu ayrı, nötr bir "yükleniyor" hâli olarak ele
  // alıyoruz.
  const accountPending = !!user && !accountName;

  const [count, setCount] = useState<2 | 4>(2);
  // ZORLUK (ROADMAP #23 Faz 3) — varsayılan Normal (bugünkü motor), her yeni
  // oyun formu açılışında Normal'e döner; misafirde de var (misafir de YZ'ye
  // karşı oynuyor: kaydı/puanı yok ama seçim yine anlamlı). Zor, Faz 5'e
  // kadar seçenek listesinde YOK (`SELECTABLE_AI_LEVELS`).
  const [level, setLevel] = useState<AiLevel>("normal");

  // Kelime listesi main.tsx'te tetiklenen ayrı chunk'tan yükleniyor —
  // "Oyunu Başlat" hazır olana kadar devre dışı bırakılır (bkz.
  // wordSetLoader.ts). Kurulumda oyuncu sayısı seçilirken geçen birkaç
  // saniye içinde neredeyse her zaman zaten tamamlanmış olur.
  const [wordsReady, setWordsReady] = useState(isWordSetReady());
  useEffect(() => {
    if (wordsReady) return;
    let cancelled = false;
    let retryTimer: ReturnType<typeof setTimeout> | undefined;
    const attempt = () => {
      preloadWordSet()
        .then(() => {
          if (!cancelled) setWordsReady(true);
        })
        .catch((err) => {
          // Bir kerelik ağ hatasında sonsuza dek "Hazırlanıyor…" kilidinde
          // kalınmasın diye birkaç saniye sonra otomatik tekrar deneniyor
          // (preloadWordSet artık başarısızlıkta kendi önbelleğini
          // temizleyip yeniden denemeye izin veriyor, bkz. wordSetLoader.ts).
          console.error(
            "[Kelimeki] Kelime listesi yüklenemedi, tekrar denenecek:",
            err,
          );
          if (!cancelled) retryTimer = setTimeout(attempt, 5000);
        });
    };
    attempt();
    return () => {
      cancelled = true;
      if (retryTimer) clearTimeout(retryTimer);
    };
  }, [wordsReady]);

  const [showWarningPopup, setShowWarningPopup] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const [showTerms, setShowTerms] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [shareCopied, setShareCopied] = useState(false);

  // "Arkadaşınla" sekmesindeki rozet: bekleyen davetler + sırası çağıranda
  // olan aktif Canlı oyunlar — kullanıcı sekmeye hiç girmeden kaç şeyin
  // dikkatini beklediğini görsün diye.
  const [liveActionCount, setLiveActionCount] = useState(0);

  // Bitişini GÖRMEDİĞİ Canlı oyunlar (3 Eylül 2026, kullanıcı isteği).
  // Sahibi burası, çünkü aynı liste İKİ yeri birden besliyor: "Arkadaşınla"
  // ÜST sekmesinin rozeti (aşağıda) ve `LiveGamesTab`'ın "Son Oynananlar"
  // ALT sekmesinin rozeti + satırlardaki "YENİ" işaretleri.
  //
  // ⚠ Rozet yalnızca UYGULAMA İÇİNDE: uygulama ikonu rozetine
  // (`useAppIconBadge`) ve girişte hangi sekmenin açılacağına
  // (`decideInitialMainView`) BİLEREK karışmıyor — o ikisi "yapacak işin
  // var" demek, biten bir oyun ise haber. Kullanıcı kararı.
  const [finishedUnseen, setFinishedUnseen] = useState<readonly string[]>([]);
  // Referans KARARLI olmalı (LiveGamesTab'ın effect'i buna bağlı).
  const handleFinishesSeen = useCallback(() => setFinishedUnseen([]), []);

  // Giriş varsayılanı kararının HAM girdisi. Rozetten (`liveActionCount`)
  // ayrı tutuluyor çünkü karar bir de YZ tarafının BİLİNMESİNİ bekliyor
  // (aşağı bkz.) — rozet ise ilk sayı gelir gelmez güncellenmeli.
  const [liveCounts, setLiveCounts] = useState<PendingLiveGameCounts | null>(
    null,
  );

  // "Yapay Zeka ile" sekmesindeki rozet — misafirde tekil localStorage kaydı
  // (0 ya da 1), girişli kullanıcıda `cloudSaves`'in gerçek uzunluğu (birden
  // fazla olabilir, bkz. CLAUDE.md).
  const localSaveCount = user ? (cloudSaves?.length ?? 0) : savedGame ? 1 : 0;

  // Girişli kullanıcı için "Yapay Zeka ile" sekmesi varsayılan olarak listeyi
  // gösterir (Canlı'daki "Devam Eden Oyunlar" listesiyle aynı görsel/etkileşim
  // deseni) — kurulum formu "+ Yeni Yapay Zeka Oyunu" butonuna tıklanınca
  // açılır (`LiveGamesTab`'daki "+ Yeni Canlı Oyun" → `LiveGameCreateForm`
  // akışıyla BİREBİR AYNI desen). Misafirde bu buton hiç yok — tek slot
  // olduğundan form zaten doğrudan gösteriliyor (aşağıya bkz.).
  const [creatingLocal, setCreatingLocal] = useState(false);
  const online = useOnlineStatus();
  // "Yapay Zeka ile" liste görünümünün Devam Edenler/Son Oynananlar tabı —
  // `LiveGamesTab`'daki (Arkadaşınla) BİREBİR AYNI çözüm, buraya da aynı
  // gerekçeyle taşındı: çok sayıda devam eden YZ oyunu olan biri için "Son
  // Oynadıklarım" listesi ekranın altına düşüp scroll etmeden görünmüyordu.
  // Burada "Oyun Davetleri" kavramı olmadığından yalnızca iki tab var.
  const [localSubTab, setLocalSubTab] = useState<"active" | "recent">("active");
  // Sekme değişiminde (Arkadaşınla ↔ Yapay Zeka ile) "Devam Edenler"e dön.
  // `LiveGamesTab` bunu zaten yapıyordu ama KASITLI OLARAK DEĞİL: o bileşen
  // koşullu render edildiğinden (aşağıda, `mainView === 'live' ? ...`) sekme
  // değişiminde unmount olup state'ini kaybediyor. `Setup` ise mount'ta
  // kaldığından `localSubTab` korunuyordu — sonuç, kimsenin karar vermediği
  // bir asimetriydi: Canlı tarafı sıfırlanıyor, YZ tarafı "Son Oynananlar"da
  // kalıyordu (kullanıcı bildirdi, 4 Ağustos 2026). İkisi de sıfırlanacak
  // şekilde hizalandı — bu yön seçildi çünkü Canlı taraftaki "bekleyen davet
  // varsa Oyun Davetleri'ni aç" akıllı varsayılanı (bkz. `appliedDefaultTabRef`,
  // `LiveGamesTab`) ancak sıfırlanan bir sekmede çalışabiliyor; hatırlayan bir
  // sekme, dikkat bekleyen işi öne çıkaran o davranışı devre dışı bırakırdı.
  useEffect(() => {
    setLocalSubTab("active");
  }, [mainView]);
  // Rozet artık `mainView`e (tab değişimine) bağlı DEĞİL — önceden bir davet
  // kabul edilip Canlı sekmesinden hiç çıkılmazsa (mainView 'live' olarak
  // sabit kalırsa) sayı asla tazelenmiyordu, yalnızca Local'e geçip geri
  // dönmek düzeltiyordu. `subscribeMyOnlineGames` (online_games/game_invites
  // Realtime'ı, LiveGamesTab'daki aynı desen) + foreground/visibility
  // dinleyicileri sayesinde artık sekme hiç değişmeden de kendiliğinden
  // güncelleniyor.
  //
  // Kişi login olduğunda Canlı'da dikkat bekleyen bir şey varsa "Arkadaşınla"
  // sekmesi otomatik açık gelsin — hamle bekleyen (sırası kendisinde olan)
  // aktif bir oyun YA DA yanıtlanmamış bir davet. İkisi de aynı rozette
  // (`liveActionCount`) sayıldığından ikisinin de sekmeyi açması gerekiyor;
  // 3 Ağustos 2026'ya kadar yalnızca `myTurnCount` bakılıyordu, yani sadece
  // bekleyen bir daveti olan kişi login olduğunda hâlâ "Yapay Zeka ile"
  // sekmesiyle karşılaşıyor, daveti ancak rozeti fark edip elle sekme
  // değiştirirse görüyordu (kullanıcı bildirdi).
  //
  // "Davetler oyunlardan öncelikli" kısmı burada değil, sekmenin İÇİNDE
  // çözülüyor: LiveGamesTab'ın kendi varsayılan alt-sekme effect'i, bekleyen
  // bir davet varsa "Devam Edenler" yerine "Oyun Davetleri"ni açıyor. Yani
  // ikisi de varsa kullanıcı doğrudan davetlerin üstüne düşüyor.
  //
  // Yalnızca BİR KEZ (bu ref sayesinde) uygulanır, yoksa kullanıcı elle
  // "Yapay Zeka ile"ye dönse bile aşağıdaki effect'in refresh()'i (Realtime/
  // foreground tetiklemeleriyle tekrar tekrar çağrıldığında) onu tekrar
  // Live'a geri çekerdi.
  const appliedLoginDefaultRef = useRef(false);
  // ...ama "bir kez" HESAP BAŞINA bir kez olmalı. Bu bileşen çıkışta unmount
  // olmadığından (`!user` dalını render edip mount'ta kalıyor) ref yaşıyordu:
  // ilk hesap onu tükettikten sonra, aynı sekmede giren İKİNCİ hesap bekleyen
  // bir daveti/sırası olsa bile Canlı sekmesine hiç geçirilmiyordu
  // (`LiveGamesTab`'ın 5 Ağustos 2026'da düzeltilen aynı sınıf hatası).
  // Karar `user` REFERANSINA değil `user.id`'ye bakar — `useAuth` her
  // `onAuthStateChange` olayında (TOKEN_REFRESHED dahil, kabaca saatte bir)
  // yeni bir `User` nesnesi verdiğinden, referansa bakmak "bir kez"i saatlik
  // bir tekrara çevirip kullanıcıyı oturduğu sekmeden habersizce atardı.
  // Ref `user?.id` ile başlatıldığından mount yolu hiç değişmiyor (blok
  // mount'ta çalışmıyor). Aşağıdaki effect'ten ÖNCE tanımlı olması şart:
  // React aynı commit'te setup'ları tanım sırasıyla çalıştırdığından,
  // sıfırlama `refresh()`'ten önce gerçekleşir.
  const lastUserIdRef = useRef<string | null>(user?.id ?? null);
  useEffect(() => {
    const id = user?.id ?? null;
    if (lastUserIdRef.current === id) return;
    lastUserIdRef.current = id;
    appliedLoginDefaultRef.current = false;
    // Sayılar da sıfırlanmalı: aksi halde karar effect'i YENİ hesabın
    // `cloudSaves`i ile ESKİ hesabın Canlı sayılarını eşleştirip yanlış
    // sekmeyi açardı (aynı bayat-veri sınıfı).
    setLiveCounts(null);
  }, [user]);
  // ...ve "bir kez" GİRİŞ BAŞINA değil, EKRANA GİRİŞ başına bir kez olmalı.
  // Arka planda açık kalan bir sekme/masaüstü penceresi hiç unmount olmadığı
  // için ref aylar boyunca dolu kalıyordu: kullanıcı uygulamayı öne
  // getirdiğinde, sırası kendisinde olsa bile "Yapay Zeka ile" sekmesiyle
  // karşılaşıyordu (21 Ağustos 2026, kullanıcı bildirdi). Uygulamadan
  // GERÇEKTEN uzaklaşıp dönmek (bkz. `LONG_AWAY_MS`) yeni bir giriş sayılır
  // ve varsayılan yeniden silahlanır; kısa bir alt-tab sayılmaz — "kullanıcı
  // bir sekmede otururken yeni davet/hamle onu oradan koparmaz" kuralı
  // aynen duruyor. Yeniden silahlanmak tek başına sekmeyi DEĞİŞTİRMEZ:
  // aşağıdaki karar effect'i hâlâ `decideInitialMainView`e soruyor ve yalnızca
  // "live" dönerse sekmeyi değiştiriyor — bekleyen iş yokken dönüş kullanıcıyı
  // hiç oynatmıyor. (Kurtarma sırasında güncellendi: 21 Ağustos'ta bu karar
  // `applyLoginDefaultOnce` adlı tek bir yardımcıydı, sonradan üç sinyalli
  // `decideInitialMainView`e ayrıldı.)
  const awayTrackerRef = useRef(createAwayTracker());
  useEffect(() => {
    if (!user) {
      setLiveActionCount(0);
      setFinishedUnseen([]);
      return;
    }
    let cancelled = false;
    const refresh = () => {
      fetchPendingLiveGameCounts().then((counts) => {
        // `null` = sayılar bilinmiyor (ağ). Son bilinen rozet KORUNUR ve
        // tek seferlik giriş kararı TÜKETİLMEZ — bir sonraki başarılı
        // tazeleme (retry merdiveni/öne dönüş/Realtime) hâlâ uygulayabilsin.
        if (cancelled || counts === null) return;
        setLiveActionCount(counts.inviteCount + counts.myTurnCount);
        // ⚠ `null` = bilinmiyor → son bilineni KORU (yukarıdaki iki sayının
        // aynı doktrini). Boş dizi yazmak rozeti sessizce kaybettirirdi.
        if (counts.finishedUnseenIds !== null) {
          setFinishedUnseen(counts.finishedUnseenIds);
        }
        setLiveCounts(counts);
      });
    };
    // 300ms debounce — `LiveGamesTab`'daki aynı desen/gerekçe. Tek bir olay
    // gibi görünen şeyler birden fazla tablo değişikliği üretiyor (davet
    // kabulünde `game_invites` + `online_games`, oyun bitişinde
    // `online_game_states` + `online_games`); ayrıca abonelik artık her
    // hamleyi de dinlediğinden (bkz. `subscribeMyOnlineGames`) art arda gelen
    // olaylar tek bir sorguya iniyor. Masaüstünde sekmeye dönüş de
    // visibilitychange + focus'u neredeyse aynı anda tetikliyor.
    let debounceId: number | null = null;
    const scheduleRefresh = () => {
      if (debounceId != null) window.clearTimeout(debounceId);
      debounceId = window.setTimeout(() => {
        debounceId = null;
        refresh();
      }, 300);
    };
    refresh();
    const unsubscribe = subscribeMyOnlineGames(scheduleRefresh);
    const markAway = () => awayTrackerRef.current.markAway();
    const onForeground = () => {
      if (document.visibilityState !== "visible") return;
      // Uzun bir aradan sonra dönüldüyse varsayılan sekme kararı yeniden
      // silahlanır (yukarı bkz.) — kararı aşağıdaki karar effect'i taze
      // sayılarla verecek; burada yalnızca izin veriliyor.
      if (awayTrackerRef.current.takeLongAway())
        appliedLoginDefaultRef.current = false;
      scheduleRefresh();
    };
    const onVisibility = () => {
      if (document.visibilityState === "visible") onForeground();
      else markAway();
    };
    // `blur`/`focus` de dinlenmek ZORUNDA: masaüstünde başka bir pencereye
    // geçmek çoğu zaman `visibilitychange` üretmiyor (pencere hâlâ "visible"
    // sayılıyor, yalnızca odağı kaybediyor) — tam da kullanıcının bildirdiği
    // senaryo. Yalnızca visibilitychange dinlenseydi uzakta geçen süre hiç
    // ölçülemez, ref bir daha hiç sıfırlanmazdı.
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("blur", markAway);
    window.addEventListener("focus", onForeground);
    window.addEventListener("online", onForeground);
    return () => {
      cancelled = true;
      if (debounceId != null) window.clearTimeout(debounceId);
      unsubscribe();
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("blur", markAway);
      window.removeEventListener("focus", onForeground);
      window.removeEventListener("online", onForeground);
    };
  }, [user, onMainViewChange]);

  // "Giriş Yap" / "Oyna" ikisi de anlamlı birer karar, gerçek bir "vazgeç"
  // değil — bu yüzden Escape/X, oyunu misafir olarak başlatmadan ("Oyna"
  // gibi) ya da giriş ekranını açmadan ("Giriş Yap" gibi) sadece popup'ı
  // kapatıp kullanıcıyı kurulum ekranında bırakır.
  //
  // Buton "DEVAM" DEĞİL "OYNA" (18 Ağustos 2026, kullanıcı bildirdi):
  // uyarı metni üyeliğin faydalarını anlattığından "Devam", cümlenin
  // devamı gibi okunup "üyeliğe devam et" izlenimi veriyordu. "Oyna" ne
  // olacağını söylüyor — misafir olarak oyun başlar. Flutter portundaki
  // eşi (`setup_screen.dart`, `_showGuestWarning`) AYNI turda değişti;
  // ikisi birlikte değişmeli.
  const closeWarningPopup = () => setShowWarningPopup(false);
  const warningPopupRef = useModalA11y(showWarningPopup, closeWarningPopup);

  // "Nasıl oynanır?" linkinden elle açılırsa da Tutorial görülmüş sayılır —
  // oyun başlayınca tekrar otomatik açılmasın diye.
  const closeHelp = () => {
    markQuickStartSeen();
    setShowHelp(false);
  };

  // Giriş varsayılanı — HANGİ sekmeyle karşılaşılacağı.
  //
  // İki koşul, ikisi de kullanıcı isteği:
  //   1) Canlı'da BEKLEYEN İŞ varsa (sırası kendisinde bir oyun ya da
  //      yanıtlanmamış bir davet) → "Arkadaşınla". 3 Ağustos 2026.
  //   2) YZ tarafında HİÇ devam eden oyun yokken Canlı'da devam eden bir
  //      oyun varsa → yine "Arkadaşınla", sırası kendisinde OLMASA BİLE.
  //      21 Ağustos 2026, kullanıcı bildirdi: hesabında 0 YZ oyunu ve 6
  //      aktif Canlı oyun varken (hiçbirinde sıra kendisinde değil)
  //      uygulama her açılışta BOŞ "Yapay Zeka ile" sekmesiyle
  //      karşılıyordu — kural (1) doğru çalışıyordu, eksik olan kuralın
  //      KENDİSİYDİ. Boş bir sekmeyle karşılamaktansa oyunların olduğu
  //      sekmeyi açmak doğru; hangi alt sekmenin açılacağına LiveGamesTab
  //      kendi karar veriyor (davet varsa "Oyun Davetleri", yoksa
  //      "Devam Edenler").
  //
  // ⚠ Karar YZ tarafı BİLİNMEDEN verilemez: `cloudSaves` çekilene kadar
  // `null` ve o sırada "YZ'de oyun yok" diye okumak kullanıcıyı devam eden
  // YZ oyunu VARKEN de Canlı'ya atardı. Bu, bu kod tabanında iki kez
  // yaşanmış bir hatanın (tek seferlik kararın BAYAT/EKSİK veriyle
  // tüketilmesi — bkz. `CountBadge` → `hasFreshGames`) üçüncü yüzü.
  // Misafirde bu effect zaten hiç çalışmıyor (`!user` dalı).
  useEffect(() => {
    if (!user || appliedLoginDefaultRef.current) return;
    // `null` = henüz karar verme (veri eksik) — ref TÜKETİLMEZ.
    const hedef = decideInitialMainView(liveCounts, cloudSaves);
    if (hedef === null) return;
    appliedLoginDefaultRef.current = true;
    if (hedef === "live") onMainViewChange("live");
  }, [user, liveCounts, cloudSaves, onMainViewChange]);

  // `shareKelimekiLink` (`src/utils/shareLink.ts`) — Setup.tsx VE karşılama
  // katmanının main.tsx'i (React DEĞİL, düz JS) AYNI fonksiyonu paylaşıyor;
  // link `?ref=arkadas` taşımak ZORUNDA (admin panelindeki "Ziyaretçi
  // Kaynağı"/"Kaynak Hunisi" dökümlerinin ziyaretçi ucunu besleyen TEK
  // üretici) — kendi başına bir paylaşım yolu yazmak bu etiketi sessizce
  // kaybettirebilirdi (18 Ağustos 2026'da tam bu tekrarlanan hatayı önlemek
  // için ortak dosyaya çıkarıldı).
  const handleShare = async () => {
    const result = await shareKelimekiLink();
    if (result === "copied") {
      setShareCopied(true);
      setTimeout(() => setShareCopied(false), 2000);
    }
  };

  // 17 Ağustos 2026 — hesap adının yanındaki parantezli toplam puan KALDIRILDI
  // (kullanıcı isteği: "gerçek puan değil, düzeltme, oradan kaldır").
  // Sayı `player_stats`in İKİ mod satırını (2+4 kişilik) topluyordu; k-lig
  // ödül sistemi (11 Ağustos 2026) geldiğinden beri bu toplam `bonus_points`
  // İÇERMİYOR — yani kullanıcının her yerde gördüğü gerçek lig puanından
  // (`player_stats_overall.total_score`; k-lig listesi, hesap menüsü, Skor
  // Kartı) eksik kalıyordu. Ekran görüntüsündeki 92 ↔ 97 farkı tam olarak
  // kazanılmış 5 puanlık eşik ödülüydü. Doğru sayıyı göstermek mümkündü ama
  // kullanıcı bunun yerine göstergenin tamamen kalkmasını istedi — oyun
  // kurulum satırının işi kadroyu göstermek, puanı değil; puan zaten hesap
  // menüsünde ve Skor Kartı'nda var. Flutter portunda bu gösterge hiç
  // OLMADIĞINDAN kaldırma aynı zamanda bir web↔port ayrışmasını da kapatıyor.
  const doStart = () => {
    const list: PlayerSetup[] = Array.from({ length: count }, (_, i) => {
      // 1. oyuncu her zaman gerçek kişidir (giriş yapıldıysa hesap adıyla,
      // yapılmadıysa Misafir olarak). Aynı cihazda birden fazla kişi oynama
      // ihtimali göz ardı edilebilir olduğundan diğer tüm oyuncular her
      // zaman YZ'dir.
      if (i === 0) {
        return { name: accountName || GUEST_PLAYER_NAME, isAI: false };
      }
      return { name: `Yapay Zeka ${i + 1}`, isAI: true };
    });
    // Oyun ekranı açılınca Tutorial daha önce görülmediyse orada gösterilecek.
    onStart(list, !hasSeenQuickStart(), level);
  };

  const handleStart = () => {
    if (!loading && !user) {
      setShowWarningPopup(true);
    } else {
      doStart();
    }
  };

  /**
   * "Yapay Zeka ile" sekmesinin çevrimdışı hâli — Canlı sekmesinin düz
   * "İnternet bağlantısı yok"undan (LiveGamesTab) BİLİNÇLİ olarak farklı:
   * burada gerçekten oynanabilir bir şey var, o yüzden kullanıcı bir
   * çıkmaza değil bir seçeneğe yönlendiriliyor (14 Ağustos 2026, kullanıcı
   * isteği). Link "+ Yeni Yapay Zeka Oyunu" butonuyla AYNI şeyi yapar —
   * ikisi de `setCreatingLocal(true)`; biri değişirse öteki de.
   */
  const offlineAiNotice = (
    <div className="flex flex-col items-center gap-4 py-8">
      <p className="text-center text-xs text-muted font-mono leading-relaxed">
        {OFFLINE_AI_SUGGESTION}
      </p>
      {/* Metin-içi link DEĞİL gerçek buton (kullanıcı isteği, 14 Ağustos
          2026) — dokunma hedefi tam boy ve "+ Yeni Yapay Zeka Oyunu"yla
          aynı görsel ağırlıkta. Davranışı da aynı: setCreatingLocal(true). */}
      <button
        type="button"
        onClick={() => setCreatingLocal(true)}
        className="btn-raised btn-raised-orange w-full py-3 rounded-md bg-orange text-white font-sans text-sm font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
      >
        {OFFLINE_AI_CTA}
      </button>
    </div>
  );

  return (
    <>
      {showAuthModal && <AuthModal onClose={() => setShowAuthModal(false)} />}
      {showHelp && <HelpModal onClose={closeHelp} />}
      {showTerms && <TermsModal onClose={() => setShowTerms(false)} />}
      {showPrivacy && <PrivacyModal onClose={() => setShowPrivacy(false)} />}

      {showWarningPopup && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
          <div
            ref={warningPopupRef}
            role="dialog"
            aria-modal="true"
            aria-label="Giriş uyarısı"
            tabIndex={-1}
            className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] px-6 pb-6 pt-12 flex flex-col gap-4 outline-none relative"
          >
            <button
              onClick={closeWarningPopup}
              aria-label="Kapat"
              className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none tap-expand w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
            >
              ✕
            </button>
            {/* ⚠ Üst dolgu `pt-12` (24 değil 48): ✕ mutlak konumlu ve kartın
              SAĞ ÜST köşesini kaplıyor, metin onun ALTINDAN başlamalı.
              Alternatif olarak metne sağ dolgu vermek denendi ve ÖLÇÜLDÜ:
              `pr-8` cümleyi 2 satırdan 3 satıra çıkarıp kartı 153 → 176px
              yapıyor ve ilk satırın sağında 38px'lik boşluk bırakıyordu.
              Bu yol 2 satırı koruyor. Metnin `pr`'ı bilerek YOK — ✕ ile
              artık aynı hizada değil. */}
            <p className="text-sm text-text font-sans leading-relaxed">
              Oyunların istatistikleri, k-lig ve arkadaşınla canlı oyun için
              lütfen giriş yapın.
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={() => {
                  setShowWarningPopup(false);
                  setShowAuthModal(true);
                }}
                className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Giriş Yap
              </button>
              <button
                onClick={() => {
                  setShowWarningPopup(false);
                  doStart();
                }}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Oyna
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
        {/* `-mt-5` (−20px), kaptaki `py-6`nın (24px) üst yarısını yiyerek
          GİRİŞ/avatar satırı ile logo arasını 0'a indirir (17 Ağustos 2026; 13 Ağustos'ta 4'tü) — 13 Ağustos
          2026, kullanıcı isteği: "App'de logoyla avatar satırı arası ideal,
          web'de ekstra boşluk var". Mobil port da AYNI 4px'i kullanıyor
          (`setup_screen.dart`); biri değişirse öteki de değişmeli. */}
        <div className="text-center flex flex-col items-center gap-1 -mt-6">
          <h1
            className="flex flex-col items-center gap-1"
            style={{ margin: 0 }}
          >
            <LogoMark height={52} />
            <span className="sr-only">
              Kelimeki — Ücretsiz Online Türkçe Stratejik Kelime Bulmaca Oyunu
            </span>
          </h1>
          {/* 17 Ağustos 2026 — bu iki öğe (tanıtım paragrafı, "Nasıl oynanır?")
            yalnızca MİSAFİR (girişsiz) kullanıcıda görünür. Kullanıcı isteği:
            "girişli ise logo altındaki yazıları olmayan, direkt oyun tipi
            başlığından itibaren başlayan versiyonu görecek." Girişli
            kullanıcının erişimi kaybolmuyor — "Nasıl oynanır?" hesap
            menüsünde ve oyun içi tahta şeridinde duruyor. ÖLÇÜLDÜ: bu blok
            kalkınca logo altı → "OYUN TİPİ" arası kabın kendi `gap-5`'i
            (20px) kadar kalıyor — telafi amaçlı ekstra bir `mt-*`/`gap`
            EKLEME.

            "Arkadaşınla paylaş" burada 18 Ağustos 2026'da kaldırıldı
            (kullanıcı isteği: "arkadaşınla paylaş linkini de kaldırıp
            tanıtımdaki gibi alta paylaş koyalım") — küçük bir metin linki
            yerine sayfanın en altında, footer'ın hemen üstünde Landing'in
            Oyna/Giriş CTA butonlarıyla AYNI stilde tam genişlikte bir "Paylaş"
            butonu var (aşağı bkz., footer'ın hemen üstü) — artık girişli/
            girişsiz FARK ETMEKSİZİN aynı tek giriş noktası, önceden ikisi
            farklı yerdeydi (misafir burada, girişli footer'da). */}
          {!user && (
            <>
              <p className="text-muted text-xs font-mono mt-4">
                Kelimeler kurarak bölgeni genişlet, rakiplerini kuşat. Ama
                dikkat et: Hamlen rakibinin bölgesine temas ederse, kazandığın
                puanın bir kısmını onunla paylaşmak zorunda kalırsın. Her hamle
                bir strateji, her kelime bir mücadele.
              </p>
              <div className="mt-3 flex items-center gap-2">
                <button
                  onClick={() => setShowHelp(true)}
                  className="flex items-center min-h-[48px] font-mono text-[11px] font-bold text-accent hover:underline active:opacity-70 transition-opacity"
                >
                  Nasıl oynanır?
                </button>
              </div>
            </>
          )}
        </div>

        <div className="flex flex-col gap-2">
          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
            Oyun Tipi
          </div>
          <div className="flex gap-2">
            {[
              {
                key: "local" as const,
                label: "Yapay Zeka ile",
                badge: localSaveCount,
              },
              {
                key: "live" as const,
                label: "Arkadaşınla",
                // 3 Eylül 2026: bekleyen iş (davet + sırası sende) YANINDA
                // bitişini görmediğin oyunlar da sayılıyor — "Son
                // Oynananlar" bir ALT sekme olduğundan, üst sekmede
                // görünmezse kullanıcı "Yapay Zeka ile" tarafında açılıp
                // haberi hiç görmeyebilirdi (kullanıcı kararı).
                badge: liveActionCount + finishedUnseen.length,
              },
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => onMainViewChange(tab.key)}
                className={[
                  "relative flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97] flex items-center justify-center",
                  mainView === tab.key
                    ? "btn-raised bg-accent text-white border-accent"
                    : "btn-raised-neutral bg-panel text-text border-border",
                ].join(" ")}
              >
                {tab.label}
                {tab.badge > 0 && (
                  <CountBadge
                    count={tab.badge}
                    className="absolute -top-1 -right-1"
                  />
                )}
              </button>
            ))}
          </div>
        </div>

        {mainView === "live" ? (
          <LiveGamesTab
            onOpenGame={onOpenLiveGame}
            newlyFinishedIds={finishedUnseen}
            onFinishesSeen={handleFinishesSeen}
          />
        ) : !user && savedGame ? (
          // Misafir, tekil localStorage kaydı — yeni oyun bu bitene/teslim
          // olunana kadar engellenir (cihaza özel, cihazlar arası senkron yok).
          <div className="flex flex-col gap-2">
            <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
              Devam Eden Oyun
            </div>
            <SavedGameRow
              players={savedGameAvatars(savedGame.state.players, null, true)}
              savedAtMs={savedGame.savedAt}
              willSurrender={false}
              aiLevel={aiLevelOf(savedGame.state.aiLevel)}
              scores={savedGame.state.players.map((p) => p.score)}
              onClick={onResumeGame}
            />
            <p className="text-[11px] text-muted font-mono leading-relaxed">
              Bu oyun 7 gün boyunca cihazınızın hafızasında saklanır ve bir
              sonraki gelişinizde devam edilebilir. Üye değilseniz bu oyunu
              bitirmeden yeni oyun açamazsınız.
            </p>
            <MembershipPerksBox
              onSignup={() => setShowAuthModal(true)}
              className="mt-2"
            />
          </div>
        ) : user && !creatingLocal ? (
          // Girişli kullanıcı — cihazlar arası senkron olduğundan (bkz.
          // CLAUDE.md) çoklu oyun mümkün: `LiveGamesTab`'daki "+ Yeni Canlı
          // Oyun" ile BİREBİR AYNI desen — liste varsayılan görünüm, kurulum
          // formu yalnızca butona tıklanınca açılır. Devam Edenler/Son
          // Oynananlar tabı da `LiveGamesTab`'daki BİREBİR AYNI çözüm.
          <>
            <button
              onClick={() => setCreatingLocal(true)}
              className="btn-raised-orange py-2.5 rounded-md font-sans text-sm font-bold uppercase tracking-[1.5px] bg-orange text-white active:scale-[0.97] transition-transform"
            >
              + Yeni Yapay Zeka Oyunu Aç
            </button>

            <div className="flex gap-2">
              {[
                {
                  key: "active" as const,
                  label: "Devam Edenler",
                  badge: cloudSaves?.length ?? 0,
                },
                { key: "recent" as const, label: "Son Oynananlar", badge: 0 },
              ].map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => setLocalSubTab(tab.key)}
                  className={[
                    "relative flex-1 py-2.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[0.5px] border transition-transform active:scale-[0.97] flex items-center justify-center",
                    localSubTab === tab.key
                      ? "btn-raised bg-accent text-white border-accent"
                      : "btn-raised-neutral bg-panel text-text border-border",
                  ].join(" ")}
                >
                  {tab.label}
                  {tab.badge > 0 && (
                    <CountBadge
                      count={tab.badge}
                      className="absolute -top-1 -right-1"
                    />
                  )}
                </button>
              ))}
            </div>

            {localSubTab === "active" ? (
              // Çevrimdışıyken GÖSTERİLECEK KAYIT VARSA liste aynen çizilir —
              // devam eden YZ oyunları çevrimdışı da oynanabiliyor (bkz.
              // `cloudSaveMirror`), o listeyi bir uyarıyla değiştirmek gerçek
              // bir yeteneği gizlerdi. Mesaj yalnızca elde bir şey yokken.
              // `cloudSaves === null` BİLEREK dışarıda: liste henüz
              // bilinmiyorken "hiç oyunun yok, yeni aç" demek erken bir
              // yargı — çevrimdışıyken ağ denemesi ~3sn sürüp ardından
              // AYNADAN gerçek liste geliyor ve kullanıcı önce öneriyi,
              // sonra listeyi görüyordu (14 Ağustos 2026, cihaz testi).
              // Bilinmiyorken "Yükleniyor…" doğru cevap.
              !online && cloudSaves !== null && cloudSaves.length === 0 ? (
                offlineAiNotice
              ) : cloudSaves === null ? (
                <p className="text-center text-xs text-muted font-mono py-8">
                  Yükleniyor…
                </p>
              ) : cloudSaves.length === 0 ? (
                <p className="text-center text-xs text-muted font-mono py-8">
                  Devam eden bir Yapay Zeka oyunun yok.
                </p>
              ) : (
                <div className="flex flex-col gap-2">
                  <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                    Devam Eden Oyunlar
                  </div>
                  {/* Silinmeye en yakın kayıt ÜSTTE (3 Eylül 2026, kullanıcı
                    isteği). Yerel kaydın 7 günü `updated_at`ten işliyor
                    (bkz. `remainingTime`), yani EN ESKİ güncellenen en
                    yakın olandır — sorgu `updated_at desc` döndüğü için
                    burada TERS çevriliyor. Kural web/port ortak:
                    `utils/gameListOrder.ts`. */}
                  {orderByExpiry(cloudSaves, (s) => Date.parse(s.updated_at) || null).map((save) => (
                    <SavedGameRow
                      key={save.id}
                      players={savedGameAvatars(
                        save.state.players,
                        profile?.avatar_url,
                        false,
                      )}
                      savedAtMs={Date.parse(save.updated_at)}
                      willSurrender={save.state.turnCount >= 2}
                      aiLevel={aiLevelOf(save.state.aiLevel)}
                      scores={save.state.players.map((p) => p.score)}
                      onClick={() => onResumeCloudSave(save)}
                    />
                  ))}
                </div>
              )
            ) : (
              <RecentGamesSection
                onlineOnly={false}
                emptyMessage="Henüz bitmiş bir Yapay Zeka oyunun yok."
                offlineNode={offlineAiNotice}
              />
            )}
          </>
        ) : (
          <>
            <div className="flex flex-col gap-2">
              <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                Oyuncu sayısı
              </div>
              <div className="flex gap-2">
                {([2, 4] as const).map((n) => (
                  <button
                    key={n}
                    onClick={() => setCount(n)}
                    className={[
                      "flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97]",
                      count === n
                        ? "btn-raised bg-accent text-white border-accent"
                        : "btn-raised-neutral bg-panel text-text border-border",
                    ].join(" ")}
                  >
                    {n} Oyunculu
                  </button>
                ))}
              </div>
            </div>

            {/* ZORLUK (ROADMAP #23 Faz 3, 6 Eylül 2026) — "Oyuncu sayısı"
              bloğunun altında; port `_buildNewGameForm`de aynı sırada (Faz 4).
              Buton stili "Oyuncu sayısı"nın BÜYÜK butonu DEĞİL, Arkadaşınla
              sekmesinin alt-sekme pilleri (`LiveGamesTab` → Devam Edenler /
              Oyun Davetleri / Son Oynananlar: `py-2.5 text-[11px]
              tracking-[0.5px]`) — kullanıcı kararı (6 Eylül 2026 gece);
              sınıf dizesi oradakiyle BİREBİR, biri değişirse öteki de.
              Terminoloji TEK: "Zorluk: Kolay · Normal · Zor" (23.4). Seviye
              oyun BAŞINDA kilitlenir; 4 kişilikte üç YZ'ye birden uygulanır.
              Zor Faz 5'e kadar gösterilmez — iki buton da `flex-1`, üçüncüsü
              gelince yerleşim kendiliğinden üçe bölünür. */}
            <div className="flex flex-col gap-2">
              <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                Zorluk
              </div>
              <div className="flex gap-2" role="radiogroup" aria-label="Zorluk">
                {SELECTABLE_AI_LEVELS.map((lv) => (
                  <button
                    key={lv}
                    role="radio"
                    aria-checked={level === lv}
                    onClick={() => setLevel(lv)}
                    className={[
                      "relative flex-1 py-2.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[0.5px] border transition-transform active:scale-[0.97] flex items-center justify-center",
                      level === lv
                        ? "btn-raised bg-accent text-white border-accent"
                        : "btn-raised-neutral bg-panel text-text border-border",
                    ].join(" ")}
                  >
                    {AI_LEVEL_LABEL[lv]}
                  </button>
                ))}
              </div>
              {/* Her seviyenin altında kullanıcıya hitap eden bir açıklama +
                o seviyenin k-lig puanı; 4 kişilikte ikincilik de yazılır.
                Metin `aiLevelDescription`ta (leaguePoints'ten türetilir),
                port ikizi aynı şablon. */}
              <p className="text-[11px] text-muted font-mono leading-relaxed">
                {aiLevelDescription(level, count)}
              </p>
            </div>

            <div className="flex flex-col gap-2.5">
              <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                Oyuncular
              </div>
              {Array.from({ length: count }, (_, i) => {
                const col = PLAYER_COLORS[i];
                // 1. oyuncu giriş yapan hesaptır: kilitli isim + avatar, YZ olamaz.
                const isAccount = i === 0 && !!accountName;
                const isPending = i === 0 && accountPending;
                return (
                  <div
                    key={i}
                    className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border"
                    style={{ background: col.tint, borderColor: col.base }}
                  >
                    {isAccount ? (
                      <Avatar
                        url={profile?.avatar_url}
                        name={accountName}
                        size={20}
                        className="shrink-0"
                      />
                    ) : isPending ? (
                      <span className="w-5 h-5 rounded-full bg-panel border border-border shrink-0 animate-pulse" />
                    ) : (
                      <PlayerBadge index={i} />
                    )}

                    {isAccount ? (
                      <span className="flex-1 min-w-0 flex items-center gap-1">
                        <span className="font-sans text-sm font-bold text-text truncate">
                          {accountName}
                        </span>
                        {rankTierOf(user?.id) && (
                          <RankSeal
                            tier={rankTierOf(user?.id)!}
                            size={18}
                            className="shrink-0"
                          />
                        )}
                      </span>
                    ) : isPending ? (
                      <span className="flex-1 min-w-0 font-sans text-sm font-bold text-muted truncate animate-pulse">
                        Yükleniyor…
                      </span>
                    ) : (
                      <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
                        {i === 0 ? GUEST_PLAYER_NAME : `Yapay Zeka ${i + 1}`}
                      </span>
                    )}

                    <span
                      className="text-[9px] font-mono uppercase tracking-[1px] shrink-0 px-1"
                      style={{ color: col.base }}
                    >
                      {i === 0 ? "Sen" : `YZ${i + 1}`}
                    </span>
                  </div>
                );
              })}
            </div>

            <div className="flex gap-2">
              <button
                onClick={handleStart}
                disabled={!wordsReady || accountPending}
                className="flex-1 btn-raised py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
              >
                {/* accountPending iken de "Hazırlanıyor…" gösterilir — girişli
                  kullanıcı için profil gelmeden basılırsa oyuncu adı kısa
                  süreliğine 'Misafir' kaydedilebiliyordu (RENAME_PLAYER
                  sonradan düzeltiyordu ama önlemek daha temiz). */}
                {wordsReady && !accountPending
                  ? "Oyunu Başlat"
                  : "Hazırlanıyor…"}
              </button>
              {/* Yalnızca girişli kullanıcı için (creatingLocal) — LiveGameCreateForm'un
                "Vazgeç" butonuyla BİREBİR AYNI, Devam Eden Oyunlar listesine
                dönmeyi sağlar. Misafirde bu form zaten tek/koşulsuz gösterilen
                yol olduğundan (dönülecek bir liste yok) hiç render edilmez. */}
              {creatingLocal && (
                <button
                  onClick={() => setCreatingLocal(false)}
                  className="flex-1 btn-raised-neutral py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-void border border-border text-text active:scale-[0.97] transition-transform"
                >
                  Vazgeç
                </button>
              )}
            </div>

            {!user && (
              <MembershipPerksBox onSignup={() => setShowAuthModal(true)} />
            )}
          </>
        )}

        {/* "Son Oynananlar" artık yalnızca girişli kullanıcının liste
          görünümündeki kendi tabında gösteriliyor (yukarıda) — kurulum
          formunun (creatingLocal, ör. oyuncu seçimi) hemen altında tekrar
          çıkması `LiveGamesTab`'daki aynı kullanıcı geri bildirimiyle
          gürültü olarak değerlendirilip kaldırıldı. Misafirin tekil kayıt
          görünümünde zaten hiç görünmüyordu (RecentGamesSection girişsiz
          kullanıcı için `null` döner), o yüzden bu satırın kaldırılması
          misafir tarafında hiçbir görsel fark yaratmıyor. */}

        {/* Alt satır Landing.tsx'in "Son çağrı" footer'ıyla AYNI iki katmanlı
          yapı: hukuki linkler + hemen altında "© Kelimeki" (18 Ağustos 2026,
          kullanıcı isteği: "setup altındaki footer'ın altına 'c Kelimeki'
          (tanıtımdaki gibi) olsun") — `gap-3` ikisini tek bir footer bloğu
          gibi gruplar, dıştaki kabın `gap-5`'i (üstteki içerikle arasını)
          hiç etkilemez. 19 Ağustos 2026'da `gap-1`den `gap-3`e çekildi
          (kullanıcı: "tanıtım sayfasındaki kadar boşluk olsun") — Landing'in
          "Son çağrı" section'ı da hukuki satır ile "© Kelimeki" arasını kendi
          `gap-3`üyle veriyor, yani iki footer artık BİREBİR aynı (ölçüldü:
          4.0 → 12.0px). Biri değişirse öteki de değişmeli. */}
        <div className="flex flex-col items-center gap-3">
          {/* `flex-wrap` bir emniyet ağı — 356px'in altındaki viewport'larda
            (320/344 gibi) üç öğe tek satıra sığmıyor; ÖLÇÜLDÜ, `gap-x-2 gap-y-1`
            320'de iki satıra sarıp yatay taşmayı 0'da tutuyor, 356+ genişlikte
            hiçbir şey değişmiyor. */}
          <div className="flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-[10px] font-mono text-muted">
            <button
              onClick={() => setShowTerms(true)}
              className="flex items-center min-h-[48px] hover:underline active:opacity-70 transition-opacity"
            >
              Kullanım Koşulları
            </button>
            <span>·</span>
            <button
              onClick={() => setShowPrivacy(true)}
              className="flex items-center min-h-[48px] hover:underline active:opacity-70 transition-opacity"
            >
              Gizlilik Politikası
            </button>
            {/* "Paylaş" (18 Ağustos 2026, aynı gün üçüncü/dördüncü tur —
              kullanıcı: "Yanlış anladın, buton istemedim. Tanıtım
              footerındakinin aynısını istedim", sonra: "Daha önce tanıtım
              sayfasına universal paylaş ikonlu paylaş linki koymuştuk...
              İki tarafa da ikonlu şekilde koy") — küçük metin linki stili
              (Kullanım Koşulları/Gizlilik Politikası ile AYNI className)
              korunuyor, yalnızca başına `ShareIcon` eklendi — Landing.tsx'in
              footer'ındaki AYNI ikonla (aşağı bkz.), `fill="currentColor"`
              olduğundan satırın `text-muted` rengini otomatik miras alıyor.
              `handleShare` girişten bağımsız çalıştığından `user &&` gibi
              bir koşula BAĞLANMADI, misafir/girişli aynı satırı görüyor. */}
            <span>·</span>
            <button
              onClick={handleShare}
              className="flex items-center min-h-[48px] gap-1 hover:underline active:opacity-70 transition-opacity"
            >
              <ShareIcon size={12} />
              {shareCopied ? "Link kopyalandı!" : "Paylaş"}
            </button>
          </div>
          <p className="font-mono text-[10px] text-muted" style={{ margin: 0 }}>
            © Kelimeki
          </p>
        </div>
      </div>
    </>
  );
}
