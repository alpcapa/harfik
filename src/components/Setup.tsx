// Kelimeki — oyun kurulum ekranı: oyuncu sayısı (2/4) seçimi
import { useEffect, useState } from 'react';
import { SETUP_BG_WATERMARK_URL } from '../assets/setupBgWatermark';
import { PLAYER_COLORS } from '../game/constants';
import type { PlayerSetup } from '../game/gameReducer';
import { useAuth } from '../hooks/useAuth';
import { useModalA11y } from '../hooks/useModalA11y';
import { fetchOnlineGameTurns, fetchPlayerStats, listMyOnlineGames } from '../lib/api';
import { hasSeenQuickStart, markQuickStartSeen } from '../utils/onboarding';
import { ABANDON_TIMEOUT_MS, type SavedGame } from '../utils/gameStorage';
import { preloadWordSet, isWordSetReady } from '../data/wordSetLoader';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { HelpModal } from './HelpModal';
import { LiveGamesTab } from './LiveGamesTab';
import { LogoMark } from './LogoMark';
import { PlayerBadge } from './PlayerBadge';
import { TermsModal } from './TermsModal';
import { PrivacyModal } from './PrivacyModal';
import type { LocalGameSave, OnlineGame } from '../lib/database.types';

// "Devam Eden Oyun" satırındaki kalan süre — gameStorage.ts'teki
// ABANDON_TIMEOUT_MS (7 gün) ile aynı terk-silme kuralına göre, son kayıt
// (savedAt) anından itibaren. `willSurrender` true ise (turnCount>=2 — en az
// bir tam tur oynanmış, gerçek -2 teslim cezası uygulanır, bkz. CLAUDE.md
// "Terk edilen oyunun otomatik temizliği") "teslim sayılacak", değilse
// (henüz hiç hamle yok, ceza yok) "silinecek" metni kullanılır. Kırmızı (kalın
// değil — 31 Temmuz 2026'da kullanıcı isteğiyle font-bold kaldırıldı) kalan
// süre 24 saatin altına inince devreye giriyor — o noktadan itibaren metin de
// "gün" yerine dakika hassasiyetinde saat gösterir (LiveGamesTab'daki aktif
// Canlı oyun kalan-süre etiketiyle aynı mantık/stil).
function remainingTime(savedAt: number, willSurrender: boolean): { text: string; urgent: boolean } {
  const verb = willSurrender ? 'teslim sayılacak' : 'silinecek';
  const ms = savedAt + ABANDON_TIMEOUT_MS - Date.now();
  if (ms <= 0) return { text: `Bugün ${verb}`, urgent: true };
  const totalMinutes = Math.ceil(ms / (60 * 1000));
  const totalHours = Math.floor(totalMinutes / 60);
  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;
  const minutes = totalMinutes % 60;
  const text =
    days > 0
      ? `${days} gün ${hours} saat sonra ${verb}`
      : `${hours} saat ${minutes} dakika sonra ${verb}`;
  return { text, urgent: days < 1 };
}

/**
 * "Devam Eden Oyun" satırı — misafirin tekil localStorage kaydında (bkz.
 * `savedGame` prop'u) ve girişli kullanıcının `cloudSaves` listesindeki her
 * satırda AYNI görsel/etkileşim deseni kullanılsın diye ortak bileşene
 * çıkarıldı.
 */
function SavedGameRow({
  title,
  subtitle,
  savedAtMs,
  willSurrender,
  onClick,
}: {
  title: string;
  subtitle: string;
  savedAtMs: number;
  willSurrender: boolean;
  onClick: () => void;
}) {
  const remaining = remainingTime(savedAtMs, willSurrender);
  return (
    <button
      onClick={onClick}
      className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel w-full text-left active:scale-[0.99] transition-transform"
    >
      <span className="flex-1 min-w-0 flex flex-col gap-0.5">
        <span className="font-sans text-sm font-bold text-text truncate">{title}</span>
        <span className="text-[9px] font-mono text-muted truncate">{subtitle}</span>
      </span>
      <span className="flex flex-col items-end gap-0.5 shrink-0">
        <span className="text-[9px] font-mono uppercase tracking-[1px] text-green font-bold">
          Senin Hamlen Bekleniyor
        </span>
        <span
          className={`text-[8px] font-mono uppercase tracking-[0.5px] ${
            remaining.urgent ? 'text-red' : 'text-muted'
          }`}
        >
          {remaining.text}
        </span>
      </span>
    </button>
  );
}

interface SetupProps {
  // showTutorial: oyun ekranı açıldığında Tutorial (HelpModal) daha önce
  // görülmediyse gösterilsin mi — App.tsx bunu oyun ekranı render'ında kullanır.
  onStart: (players: PlayerSetup[], showTutorial: boolean) => void;
  // "Oyun Tipi" seçimi (Yapay Zeka ile / Arkadaşınla) — App.tsx'te tutulur,
  // çünkü Canlı oyun tamamen ayrı bir veri kaynağından (Supabase) besleniyor;
  // Setup burada yalnızca seçiciyi gösterip görünümü değiştirir.
  mainView: 'local' | 'live';
  onMainViewChange: (view: 'local' | 'live') => void;
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
  // Oturum açıldıysa 1. oyuncu her zaman hesap sahibidir. Profil henüz
  // çekilmediyse (profileLoading) e-posta önekine düşmüyoruz — aksi halde
  // sayfa her açılışta profil gelene kadar bir anlık yanlış/geçici bir isim
  // (ör. "alp.capa") gösterip hemen gerçek takma adla değişiyordu.
  const accountName =
    profile?.display_name ||
    profile?.first_name ||
    (user?.email && !profileLoading ? user.email.split('@')[0] : null);
  // Oturum var ama profil henüz gelmediyse (profileLoading) accountName
  // hâlâ null'dur — bu durumda 1. oyuncu satırını "Misafir" olarak
  // göstermek de yanlış: oturum açık biri için bir anlığına "Misafir" yazıp
  // hemen gerçek takma adla değişmek, tıpkı eski e-posta önekine düşme
  // hatası gibi kafa karıştırıcı bir kimlik değişimi izlenimi veriyordu.
  // Bu yüzden bu ara durumu ayrı, nötr bir "yükleniyor" hâli olarak ele
  // alıyoruz.
  const accountPending = !!user && !accountName;

  const [count, setCount] = useState<2 | 4>(2);

  // Kelime listesi main.tsx'te tetiklenen ayrı chunk'tan yükleniyor —
  // "Oyunu Başlat" hazır olana kadar devre dışı bırakılır (bkz.
  // wordSetLoader.ts). Kurulumda oyuncu sayısı seçilirken geçen birkaç
  // saniye içinde neredeyse her zaman zaten tamamlanmış olur.
  const [wordsReady, setWordsReady] = useState(isWordSetReady());
  useEffect(() => {
    if (wordsReady) return;
    preloadWordSet().then(() => setWordsReady(true));
  }, [wordsReady]);

  const [showWarningPopup, setShowWarningPopup] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const [showTerms, setShowTerms] = useState(false);
  const [showPrivacy, setShowPrivacy] = useState(false);
  const [shareCopied, setShareCopied] = useState(false);

  // "Arkadaşınla" sekmesindeki rozet: bekleyen davetler + sırası çağıranda
  // olan aktif Canlı oyunlar — kullanıcı sekmeye hiç girmeden kaç şeyin
  // dikkatini beklediğini görsün diye. `mainView`e bağlı: Live sekmesinden
  // (davet kabul/hamle sonrası) Local'e dönülünce sayı tazelensin diye.
  const [liveActionCount, setLiveActionCount] = useState(0);

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
  useEffect(() => {
    if (!user) {
      setLiveActionCount(0);
      return;
    }
    let cancelled = false;
    listMyOnlineGames().then((rows) => {
      if (cancelled) return;
      const inviteCount = rows.filter((g) => g.my_role === 'invitee' && g.my_invite_status === 'pending').length;
      const activeIds = rows.filter((g) => g.status === 'active').map((g) => g.id);
      if (activeIds.length === 0) {
        setLiveActionCount(inviteCount);
        return;
      }
      fetchOnlineGameTurns(activeIds).then((turns) => {
        if (cancelled) return;
        const myTurnCount = rows.filter((g) => {
          if (g.status !== 'active') return false;
          const idx = g.slots.findIndex((s) => s.type === 'human' && s.relation === 'self');
          return turns[g.id] === idx;
        }).length;
        setLiveActionCount(inviteCount + myTurnCount);
      });
    });
    return () => {
      cancelled = true;
    };
  }, [user, mainView]);

  // "Giriş Yap" / "Devam" ikisi de anlamlı birer karar, gerçek bir "vazgeç"
  // değil — bu yüzden Escape/X, oyunu misafir olarak başlatmadan ("Devam"
  // gibi) ya da giriş ekranını açmadan ("Giriş Yap" gibi) sadece popup'ı
  // kapatıp kullanıcıyı kurulum ekranında bırakır.
  const closeWarningPopup = () => setShowWarningPopup(false);
  const warningPopupRef = useModalA11y(showWarningPopup, closeWarningPopup);

  // "Nasıl oynanır?" linkinden elle açılırsa da Tutorial görülmüş sayılır —
  // oyun başlayınca tekrar otomatik açılmasın diye.
  const closeHelp = () => {
    markQuickStartSeen();
    setShowHelp(false);
  };

  // Arkadaşa paylaşılan link ?ref=arkadas taşır — admin panelindeki
  // "Ziyaretçi Kaynağı" dökümünde (bkz. src/utils/visitTracking.ts,
  // admin_guest_source_breakdown) diğer sosyal kaynaklardan ayrı bir satır
  // olarak görünür. Mobilde native paylaşım sayfası varsa onu kullanır;
  // yoksa (çoğu masaüstü tarayıcı) linki panoya kopyalayıp kısa bir
  // "Kopyalandı" geri bildirimi gösterir.
  const handleShare = async () => {
    const url = `${window.location.origin}/?ref=arkadas`;
    const text = 'Hemen ücretsiz dene!';
    if (navigator.share) {
      try {
        await navigator.share({ title: 'Kelimeki', text, url });
      } catch {
        // kullanıcı paylaşım sayfasını iptal etti — yoksay
      }
      return;
    }
    try {
      await navigator.clipboard.writeText(url);
      setShareCopied(true);
      setTimeout(() => setShareCopied(false), 2000);
    } catch {
      // panoya erişim yoksa sessizce yoksay
    }
  };

  // Toplam puan (isim yanında gösterilen) tüm oyun modlarının (2/4 kişilik)
  // toplamıdır — seçili sekmeye göre değişmez.
  const [accountTotalScore, setAccountTotalScore] = useState<number | undefined>(undefined);
  useEffect(() => {
    if (!user) {
      setAccountTotalScore(undefined);
      return;
    }
    let cancelled = false;
    Promise.all([fetchPlayerStats(2), fetchPlayerStats(4)]).then(([s2, s4]) => {
      if (cancelled) return;
      if (!s2 && !s4) {
        setAccountTotalScore(undefined);
        return;
      }
      setAccountTotalScore((s2?.total_score ?? 0) + (s4?.total_score ?? 0));
    });
    return () => {
      cancelled = true;
    };
  }, [user]);

  const doStart = () => {
    const list: PlayerSetup[] = Array.from({ length: count }, (_, i) => {
      // 1. oyuncu her zaman gerçek kişidir (giriş yapıldıysa hesap adıyla,
      // yapılmadıysa Misafir olarak). Aynı cihazda birden fazla kişi oynama
      // ihtimali göz ardı edilebilir olduğundan diğer tüm oyuncular her
      // zaman YZ'dir.
      if (i === 0) {
        return { name: accountName || 'Misafir', isAI: false };
      }
      return { name: `Yapay Zeka ${i + 1}`, isAI: true };
    });
    // Oyun ekranı açılınca Tutorial daha önce görülmediyse orada gösterilecek.
    onStart(list, !hasSeenQuickStart());
  };

  const handleStart = () => {
    if (!loading && !user) {
      setShowWarningPopup(true);
    } else {
      doStart();
    }
  };

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
          className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative"
        >
          <button
            onClick={closeWarningPopup}
            aria-label="Kapat"
            className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
          >
            ✕
          </button>
          <p className="text-sm text-text font-sans leading-relaxed pr-6">
            Oyunların istatistikleri, Sanal Lig ve arkadaşınla canlı oyun için lütfen giriş yapın.
          </p>
          <div className="flex gap-2 mt-1">
            <button
              onClick={() => { setShowWarningPopup(false); setShowAuthModal(true); }}
              className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Giriş Yap
            </button>
            <button
              onClick={() => { setShowWarningPopup(false); doStart(); }}
              className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Devam
            </button>
          </div>
        </div>
      </div>
    )}

    <div
      className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5"
      style={{
        backgroundImage: `url('${SETUP_BG_WATERMARK_URL}')`,
        backgroundSize: '480px auto',
        backgroundPosition: 'center 76px',
        backgroundRepeat: 'no-repeat',
      }}
    >
      <div className="text-center flex flex-col items-center gap-1 -mt-3">
        <h1 className="flex flex-col items-center gap-1" style={{ margin: 0 }}>
          <LogoMark height={52} />
          <span className="sr-only">
            Kelimeki — Ücretsiz Online Türkçe Stratejik Kelime Bulmaca Oyunu
          </span>
        </h1>
        <p className="text-muted text-xs font-mono mt-4">
          Kelimeler kurarak bölgeni genişlet, rakiplerini kuşat. Ama dikkat et:
          Hamlen rakibinin bölgesine temas ederse, kazandığın puanın bir
          kısmını onunla paylaşmak zorunda kalırsın. Her hamle bir strateji,
          her kelime bir mücadele.
        </p>
        <div className="mt-3 flex items-center gap-2">
          <button
            onClick={() => setShowHelp(true)}
            className="font-mono text-[11px] font-bold text-accent hover:underline active:opacity-70 transition-opacity"
          >
            Nasıl oynanır?
          </button>
          <span className="text-muted text-[11px]" aria-hidden="true">·</span>
          <button
            onClick={handleShare}
            className="font-mono text-[11px] font-bold text-accent hover:underline active:opacity-70 transition-opacity"
          >
            {shareCopied ? 'Link kopyalandı!' : 'Arkadaşınla paylaş'}
          </button>
        </div>
      </div>

      <div className="flex flex-col gap-2">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Oyun Tipi
        </div>
        <div className="flex gap-2">
          {([
            { key: 'local' as const, label: 'Yapay Zeka ile' },
            { key: 'live' as const, label: 'Arkadaşınla' },
          ]).map((tab) => (
            <button
              key={tab.key}
              onClick={() => onMainViewChange(tab.key)}
              className={[
                'flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97]',
                mainView === tab.key
                  ? 'btn-raised bg-accent text-white border-accent'
                  : 'btn-raised-neutral bg-panel text-text border-border',
              ].join(' ')}
            >
              {tab.label}
              {tab.key === 'live' && liveActionCount > 0 ? ` (${liveActionCount})` : ''}
              {tab.key === 'local' && localSaveCount > 0 ? ` (${localSaveCount})` : ''}
            </button>
          ))}
        </div>
      </div>

      {mainView === 'live' ? (
        <LiveGamesTab onOpenGame={onOpenLiveGame} />
      ) : !user && savedGame ? (
        // Misafir, tekil localStorage kaydı — yeni oyun bu bitene/teslim
        // olunana kadar engellenir (cihaza özel, cihazlar arası senkron yok).
        <div className="flex flex-col gap-2">
          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
            Devam Eden Oyun
          </div>
          <SavedGameRow
            title={`${savedGame.state.players.length} Kişilik Oyun`}
            subtitle={`Sıra: ${savedGame.state.players[savedGame.state.current]?.name ?? '—'}`}
            savedAtMs={savedGame.savedAt}
            willSurrender={savedGame.state.turnCount >= 2}
            onClick={onResumeGame}
          />
          <p className="text-[11px] text-muted font-mono leading-relaxed">
            Yeni bir Yapay Zeka oyunu başlatabilmen için önce bu oyunu
            bitirmen gerekir. Süre dolduğunda oyun otomatik biter ve teslim
            olmuş kabul edilirsin; ayrıca, lig puanından 2 puan düşülür.
          </p>
        </div>
      ) : user && !creatingLocal ? (
        // Girişli kullanıcı — cihazlar arası senkron olduğundan (bkz.
        // CLAUDE.md) çoklu oyun mümkün: `LiveGamesTab`'daki "+ Yeni Canlı
        // Oyun" ile BİREBİR AYNI desen — liste varsayılan görünüm, kurulum
        // formu yalnızca butona tıklanınca açılır.
        <>
          <button
            onClick={() => setCreatingLocal(true)}
            className="btn-raised py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform"
          >
            + Yeni Yapay Zeka Oyunu
          </button>
          {cloudSaves === null ? (
            <p className="text-center text-xs text-muted font-mono py-8">Yükleniyor…</p>
          ) : cloudSaves.length === 0 ? (
            <p className="text-center text-xs text-muted font-mono py-8">
              Henüz bir Yapay Zeka oyunun yok.
            </p>
          ) : (
            <div className="flex flex-col gap-2">
              <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
                Devam Eden Oyunlar
              </div>
              {cloudSaves.map((save) => (
                <SavedGameRow
                  key={save.id}
                  title={`${save.state.players.length} Kişilik Oyun`}
                  subtitle={`Sıra: ${save.state.players[save.state.current]?.name ?? '—'}`}
                  savedAtMs={Date.parse(save.updated_at)}
                  willSurrender={save.state.turnCount >= 2}
                  onClick={() => onResumeCloudSave(save)}
                />
              ))}
            </div>
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
                    'flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97]',
                    count === n
                      ? 'btn-raised bg-accent text-white border-accent'
                      : 'btn-raised-neutral bg-panel text-text border-border',
                  ].join(' ')}
                >
                  {n} Oyunculu
                </button>
              ))}
            </div>
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
                    <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
                      {accountName}
                      {accountTotalScore !== undefined && (
                        <span className="font-mono font-normal text-muted"> ({accountTotalScore})</span>
                      )}
                    </span>
                  ) : isPending ? (
                    <span className="flex-1 min-w-0 font-sans text-sm font-bold text-muted truncate animate-pulse">
                      Yükleniyor…
                    </span>
                  ) : (
                    <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
                      {i === 0 ? 'Misafir' : `Yapay Zeka ${i + 1}`}
                    </span>
                  )}

                  <span
                    className="text-[9px] font-mono uppercase tracking-[1px] shrink-0 px-1"
                    style={{ color: col.base }}
                  >
                    {i === 0 ? 'Sen' : `YZ${i + 1}`}
                  </span>
                </div>
              );
            })}
          </div>

          <div className="flex gap-2">
            <button
              onClick={handleStart}
              disabled={!wordsReady}
              className="flex-1 btn-raised py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-35 disabled:cursor-not-allowed"
            >
              {wordsReady ? 'Oyunu Başlat' : 'Hazırlanıyor…'}
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
        </>
      )}

      <div className="flex items-center justify-center gap-2 text-[10px] font-mono text-muted">
        <button onClick={() => setShowTerms(true)} className="hover:underline active:opacity-70 transition-opacity">
          Kullanım Koşulları
        </button>
        <span>·</span>
        <button onClick={() => setShowPrivacy(true)} className="hover:underline active:opacity-70 transition-opacity">
          Gizlilik Politikası
        </button>
      </div>
    </div>
    </>
  );
}
