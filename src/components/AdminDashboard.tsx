// Kelimeki — admin paneli: üyeler ve oyun istatistikleri
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import {
  fetchAdminMembers,
  fetchAdminUserActivitySeries,
  fetchAdminGameActivitySeries,
  fetchAdminEngagementActivitySeries,
  fetchAdminEngagementTotals,
  fetchAdminAiBalance,
  fetchAdminFriendActivitySeries,
  fetchAdminFriendTotals,
  fetchAdminActivePlayersSeries,
  fetchAdminRetentionCohorts,
  fetchAdminActivationStats,
  fetchAdminSourceFunnel,
  fetchAdminDeviceBreakdown,
  fetchAdminAppVersionBreakdown,
  fetchAdminPushVersionBreakdown,
  fetchAdminClientErrors,
  fetchAdminFeedback,
  fetchSupportInboxUnseenCount,
  markSupportInboxSeen,
  markFeedbackHandled,
  deleteFeedback,
  sendFeedbackReply,
  fetchAdminChatReports,
  markChatReportHandled,
  setUserBanned,
} from '../lib/api';
import type {
  AdminMember,
  AdminUserActivityPoint,
  AdminGameActivityPoint,
  AdminGameScope,
  AdminGameSourceType,
  AdminEngagementActivityPoint,
  AdminEngagementTotals,
  AdminAiBalanceRow,
  AdminFriendActivityPoint,
  AdminFriendTotals,
  AdminActivePlayersPoint,
  AdminRetentionCell,
  AdminActivationStats,
  AdminSourceFunnelRow,
  AdminAppVersionRow,
  AdminPushVersionRow,
  AdminDeviceBreakdownRow,
  AdminActivityGranularity,
  AdminFeedbackRow,
  AdminChatReportRow,
  AdminClientErrorRow,
} from '../lib/database.types';
import { PlayerScoreCard } from './PlayerScoreCard';
import { MemberMessageModal } from './MemberMessageModal';
import { AdminChatTranscriptModal } from './AdminChatTranscriptModal';
import { CountBadge } from './CountBadge';
import { GrowthChart, type ChartSeriesDef } from './GrowthChart';
import { trLower } from '../utils/turkish';
import { GENDER_OPTIONS, isoToTrDate } from '../utils/profileFields';
import { useModalA11y } from '../hooks/useModalA11y';
import { downloadCsv } from '../utils/csvExport';

interface AdminDashboardProps {
  onClose: () => void;
}

type Tab = 'members' | 'growth' | 'feedback' | 'errors';

/**
 * `destek@kelimeki.com` gelen kutusu — "Zoho" rozeti buraya götürür.
 *
 * ⚠ `.eu` bilerek: kutu Zoho'nun AVRUPA veri merkezinde açıldı (25 Ağustos
 * 2026, bkz. marketing/play-store/console-formlari.md → "destek@kelimeki.com
 * — kurulum"). `.com`'a giden bir link boş bir hesapla karşılar.
 */
const ZOHO_INBOX_URL = 'https://mail.zoho.eu/zm/#mail/folder/inbox';
type GameSubTab = 'total' | 2 | 4;
type GrowthSubTab = 'user' | 'game';
type FeedbackSubTab = 'inbox' | 'flags';
type MemberSortKey =
  | 'name'
  | 'nickname'
  | 'email'
  | 'created_at'
  | 'last_sign_in_at'
  | 'is_admin'
  | 'signup_channel';
type SortDir = 'asc' | 'desc';

const PERIOD_OPTIONS: Record<AdminActivityGranularity, readonly number[]> = {
  day: [7, 30, 90],
  week: [8, 12, 26],
  month: [6, 12, 24],
  year: [2, 3, 5],
};

const PERIOD_UNIT_LABEL: Record<AdminActivityGranularity, string> = {
  day: 'Gün',
  week: 'Hafta',
  month: 'Ay',
  year: 'Yıl',
};

/** Ziyaretçi Kaynağı tablosunu Kullanıcı grafiğiyle aynı aralığa bağlamak için — grafiğin
 * granülerlik + periyodunu (ör. "Son 12 Hafta") admin_guest_source_breakdown'ın beklediği
 * gün sayısına çevirir. Hafta/ay/yıl için takvimsel değil yaklaşık bir gün karşılığı kullanılır. */
const GRANULARITY_TO_DAYS: Record<AdminActivityGranularity, number> = {
  day: 1,
  week: 7,
  month: 30,
  year: 365,
};

const USER_SERIES: ChartSeriesDef[] = [
  { key: 'signups', label: 'Yeni Üye', color: '#2a78d6' },
  // "M." = misafir. `guest_visits` satırı YALNIZCA oturum kapalıyken yazılıyor
  // (`App.tsx`: `if (... || authLoading || user) return;` + RLS insert'i yalnız
  // `anon` rolünde), yani bu seri tanımı gereği çıkış yapmış ziyaretçiyi
  // sayıyor. Etiket 16 Ağustos 2026'da bu yüzden netleştirildi: kullanıcı
  // "ziyaretler kayıtlı mı misafir mi belli olmuyor" diye sordu ve Kayıtlı/
  // Misafir filtresi eklemek YANILTICI olurdu — "Kayıtlı" her zaman 0
  // çıkardı, çünkü girişli kullanıcının "uygulamayı açtı" sinyali bu şemada
  // HİÇ YOK (bkz. kök CLAUDE.md, "Bu bilerek MAU DEĞİL").
  { key: 'guest_visits', label: 'M. Ziyaret', color: '#D97706' },
];
// Aynı Oturum / Çok Oturumlu kırılımı buradan 16 Ağustos 2026'da KALDIRILDI
// (kullanıcı sordu: "çok oturumlu tam olarak ne demek?"). Ölçüldü: bayrak
// (`GameState.multiSession`) yalnızca `loadGameState()` içinde işaretleniyor,
// yani uygulama GERÇEKTEN kapanıp localStorage'dan devam edildiğinde —
// Setup'a çıkıp hemen dönmek saymaz (o yol belleği kullanır). Girişli
// kullanıcıda ise 31 Temmuz'daki bulut kayıtlarından beri localStorage hiç
// kullanılmıyor, dolayısıyla bayrak fiilen ölü: canlıda son "girişli + çok
// oturumlu" kayıt 2 Ağustos, 9 Ağustos'tan beri hiçbir türden yok.
// `admin_game_activity_series` ayrıca TÜM Canlı oyunları koşulsuz "çok
// oturumlu" tarafına yazıyor (`+ o.cnt_done`) — sonuçta bu iki seri, hemen
// üstteki Toplam/Canlı/Yapay Zeka filtresinin YAPTIĞI ayrımı yanlış bir
// etiketle tekrarlıyordu. Sunucu üç sütunu döndürmeye devam ediyor; burada
// yalnızca okunmuyor.
const GAME_COUNT_SERIES: ChartSeriesDef[] = [
  { key: 'games_finished', label: 'Bitirilen', color: '#008300' },
  { key: 'games_surrendered', label: 'Teslim', color: '#D97706' },
];
// Süre grafiğinde AYNI kırılım KALIYOR — orada gerçek iş yapıyor: Canlı
// oyunlar 48 saatlik sıra penceresi yüzünden günlere yayılıyor ve tek bir
// ortalamaya katılırlarsa "bir oyun ne kadar sürer" sayısı anlamsızlaşıyor.
// Değişen yalnızca ETİKET: seriler "oturum" değil, sürenin günlere yayılıp
// yayılmadığını anlatıyor.
//
// ORTALAMA → MEDYAN (16 Ağustos 2026, `admin_game_duration_median`):
// dağılım aşırı çarpık olduğundan ortalama bilgi taşımıyordu — "tek
// oturumda" biten 200 yerel oyunda ortalama 246,6 dk, medyan 18,1 dk.
// p90 varsayılan KAPALI: medyanın gizlediği kuyruğu isteyen açar,
// grafiğin normal okuması dört çizgiyle kalabalıklaşmasın.
const DURATION_SERIES: ChartSeriesDef[] = [
  { key: 'med_duration_seconds', label: 'Genel', color: '#7c3aed' },
  { key: 'med_duration_same_session_seconds', label: 'Tek Oturumda', color: '#0891B2' },
  { key: 'med_duration_multi_session_seconds', label: 'Günlere Yayılan', color: '#DC2626' },
  { key: 'p90_duration_seconds', label: 'Uzun kuyruk (p90)', color: '#8A93A2' },
];
const DURATION_DEFAULT_KEYS = [
  'med_duration_seconds',
  'med_duration_same_session_seconds',
  'med_duration_multi_session_seconds',
];
const ENGAGEMENT_SERIES: ChartSeriesDef[] = [
  { key: 'likes', label: 'Beğeni', color: '#DC2626' },
  { key: 'shares', label: 'Paylaşma', color: '#2a78d6' },
];
const FRIEND_SERIES: ChartSeriesDef[] = [
  { key: 'requests_sent', label: 'Gönderilen İstek', color: '#2a78d6' },
  { key: 'friendships_formed', label: 'Kurulan Arkadaşlık', color: '#008300' },
];
// Mavi+amber çifti ölçülerek seçildi (renk körlüğü ayrım testi): mavi+mor
// deutan'da ΔE 5.2 ile AYIRT EDİLEMİYOR, bu çift ise protan 27.0 / tritan 28.8 /
// normal 32.9 ile altı kontrolün hepsinden geçiyor. USER_SERIES ile aynı çift.
const ACTIVE_PLAYER_SERIES: ChartSeriesDef[] = [
  { key: 'active_28d', label: 'Aktif Oyuncu (28 gün)', color: '#2a78d6' },
  { key: 'active_in_bucket', label: 'Dönem İçi Aktif', color: '#D97706' },
];

/**
 * Filtre kombosu — `tabBtn` (Kullanıcı/Oyun) ile AYNI 11px görsel boyutta.
 * Gerçek `<select>` (iOS zoom-önleme kuralı gereği hep ≥16px olmak zorunda
 * — `input,textarea,select{font-size:16px!important}`, `src/index.css`)
 * görünmez (`opacity-0`) ama tıklama/klavye/native picker'ı hâlâ o veriyor;
 * üstündeki görsel etiket kutusu tamamen ayrı, küçük punto ile render
 * ediliyor. `appearance-none`/sabit yükseklik gibi önceki denemeler (31
 * Temmuz 2026) kutunun DIŞ boyutunu küçültüyordu ama METNİN kendisi hâlâ
 * 16px kaldığından `tabBtn`'in 11px'ine göre göze hâlâ "büyük" batıyordu —
 * bu, punto farkını da ortadan kaldıran asıl çözüm.
 */
function AdminSelect({
  value,
  onChange,
  options,
  disabled,
}: {
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  disabled?: boolean;
}) {
  const current = options.find((o) => o.value === value);
  return (
    <div className="relative inline-block shrink-0">
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        className={`absolute inset-0 w-full h-full opacity-0 ${disabled ? 'cursor-default' : 'cursor-pointer'}`}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <div
        aria-hidden="true"
        className={`pointer-events-none flex items-center gap-1 py-1.5 px-2 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1px] bg-panel text-text border border-border whitespace-nowrap ${
          disabled ? 'opacity-50' : ''
        }`}
      >
        <span>{current?.label ?? ''}</span>
        <svg width="9" height="6" viewBox="0 0 10 6" fill="none" className="shrink-0">
          <path d="M1 1l4 4 4-4" stroke="#5A6673" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
    </div>
  );
}

/** GrowthChart'ın `controls` satırına konan bölüm başlığı — Tablo Görünümü linkiyle aynı hizada. */
const sectionTitleCls = 'text-[10px] font-mono font-bold uppercase tracking-[1px] text-accent';

/**
 * Metrik tanımları — 16 Ağustos 2026'ya kadar grafiklerin ALTINDA paragraf
 * olarak duruyordu. Tanımın ekranın kendisinde yaşaması hâlâ doğru (dokümanda
 * kalsa ilk yanlış yorum kaçınılmaz olurdu) ama beş uzun paragraf paneli
 * "hikaye" gibi gösteriyordu (kullanıcı isteği) — metinler buraya taşındı,
 * ekranda yalnızca bir `?` duruyor.
 *
 * **Kapsam kararı:** `?` her CSV'nin yanında — yani tanımı olmayan altı yere
 * de yazıldı, panel tek tip olsun diye. CSV'si OLMAYAN iki panelde
 * (Aktivasyon, YZ Dengesi) `?` bölüm başlığının yanında: o ikisinin açıklaması
 * yalnızca CSV'lere bakılsaydı hiçbir yere düşmeden kaybolurdu.
 */
const HINTS: Record<string, { title: string; body: ReactNode }> = {
  'yeni-uye-ziyaret': {
    title: 'Yeni Üye / Ziyaret',
    body: (
      <>
        <b>Kayıtlı</b> = o kovada açılan hesap sayısı. <b>M. Ziyaret</b> = o kovadaki benzersiz
        MİSAFİR ziyaretçi (girişsizken üretilen anonim bir cihaz kimliği; aynı kişi farklı
        cihaz/tarayıcıda ayrı sayılır). Girişli kullanıcının "uygulamayı açtı" sinyali şemada
        olmadığından bu iki seri Kayıtlı/Misafir diye bölünemez — ziyaret satırı tanımı gereği
        yalnızca misafirdir.
      </>
    ),
  },
  'aktif-oyuncu': {
    title: 'Aktif Oyuncu',
    body: (
      <>
        <b>Aktif</b> = oyun bitirme, Canlı hamle, sohbet mesajı, beğeni, arkadaşlık isteği ya da
        Canlı oyun kurma. <b>Kova içi</b> o dönemde aktif olanı, <b>28 günlük</b> kovanın sonunda
        biten 28 günlük pencereyi sayar (dört tam hafta — hafta içi/sonu dalgalanması pencereye
        eşit dağılsın diye 30 değil).
        <br />
        <br />
        Bu sayı bilerek <b>MAU değil</b>: girişli kullanıcı için "uygulamayı açtı" sinyali şemada
        yok, yani uygulamayı açıp hiçbir şey yapmadan çıkan sayılmaz.
      </>
    ),
  },
  aktivasyon: {
    title: 'Aktivasyon',
    body: (
      <>
        <b>Aktive</b> = en az bir oyunu BİTİRMİŞ üye. Aktif Oyuncu'dan farklı bir soru: yalnızca
        arkadaşlık isteği gönderen biri aktif oyuncu SAYILIR ama aktive SAYILMAZ.
        <br />
        <br />
        Süre negatif çıkabilir ve bu bir hata değil: misafirken bitirilen bir oyun kişi sonradan
        üye olunca hesabına işleniyor ve oyunun gerçek bitiş anı hesaptan eski olabiliyor — sıfıra
        kırpılıyor.
      </>
    ),
  },
  retention: {
    title: 'Retention (Kayıt Haftasına Göre)',
    body: (
      <>
        <b>Satır</b> = kayıt haftası · <b>Sütun</b> = kayıttan sonraki hafta (H0 = kayıt
        haftasının kendisi) · <b>Hücre</b> = o kohorttan o hafta aktif olan üye oranı. "Aktif"in
        tanımı Aktif Oyuncu panelindekiyle AYNI kaynaktan geliyor.
        <br />
        <br />
        Yalnızca TAMAMLANMIŞ haftalar gösterilir — yarım bir hafta her zaman yapay olarak düşük
        görünür ve tablonun son köşegenini yalancı bir düşüş gibi gösterirdi.
        <br />
        <br />
        Hücre tonu yalnızca ikincil bir işaret; oran her hücrede sayıyla da yazıyor. CSV yüzde
        değil HAM SAYI indirir (yuvarlama kaybı olmasın diye — payda "Üye" sütununda).
      </>
    ),
  },
  'kaynak-hunisi': {
    title: 'Kaynak Hunisi',
    body: (
      <>
        <b>Bu tablo baştan sona MİSAFİR hunisidir:</b> bir kanaldan gelip{' '}
        <b>henüz üye olmadan</b> ürünü deneyen insanları ölçer. <b>Gelen</b> = o kaynaktan gelen
        benzersiz misafir ziyaretçi; <b>Üye</b> = o kaynak damgasıyla açılan hesap;{' '}
        <b>Başlayan</b> = üye olmadan BAŞLATILAN yerel (YZ) oyun; <b>Biten</b> = üye olmadan
        BİTİRİLEN yerel (YZ) oyun. Pencere her adıma KENDİ olay tarihinden uygulanır (kohort
        değil).
        <br />
        <br />
        <b>Neden yalnızca misafir?</b> Aylardır oynayan bir üyenin oyunları "bu kanal işe
        yaradı mı" sorusunun cevabını boğuyordu — ölçüldü, "arkadas" satırında 292 üye oyunu
        vardı. "Gelen" zaten baştan beri yalnızca misafir sayıyordu (ziyaret kaydı yalnızca
        oturum kapalıyken yazılır), yani tablo üç farklı kitleyi yan yana koyuyordu. Artık
        tek kitle.
        <br />
        <br />
        <b>Başlayan ile Biten bir ÇİFT</b> — ikisi de aynı kitleyi, aynı kapsamı (yerel/YZ) ve
        aynı etiket sözleşmesini ölçer, o yüzden "başlayanların kaçı bitirdi" sorusu ancak bu
        ikisiyle sorulabilir. Yerel oyunun medyan süresi 18,1 dakika olduğundan soğuk bir
        ziyaretçi çoğu zaman oynar ama bitirmez: "Başlayan" yüksek + "Biten" 0 ise açılış
        sayfası çalışıyor, oyun uzun geliyor demektir; ikisi de 0 ise sorun açılış sayfasında.
        <br />
        <br />
        <b>ÜYE tarafı bu tabloda YOK</b> — üyelerin oyunları kaynak kırılımlı olarak CSV'de
        duruyor ("Üye Oyunu", "Oynayan Üye"), ve bunlar cihaz etiketinden değil üyenin KAYIT
        damgasından gelir: hesabı takip ettiği için "bu kanal değerli üye getirdi mi"
        sorusunun daha güvenilir cevabıdır (bir üye başka cihazdan oynarsa cihaz etiketi
        kaybolur, kayıt damgası kaybolmaz). Üyelerin ne kadar oynadığını zaman içinde görmek
        için Büyüme &gt; Oyun sekmesindeki Misafir/Kayıtlı kırılımı var.
        <br />
        <br />
        <b>Başlayan ve Biten 22 Ağustos 2026'da misafire indirildi, geriye dönük
        doldurulamaz</b> — o tarihten önceki başlangıçlarda "misafir miydi" bilgisi hiç
        tutulmuyordu, bu yüzden HİÇ sayılmıyorlar ve "Başlayan" bir süre düşük görünecek.
        Eski bitişler ise damgasız olduklarından "bilinmiyor" satırında toplanır.
        <br />
        <br />
        Yüzde modunda <b>Üye</b> = üye / gelen. <b>Başlayan</b> = başlatan benzersiz CİHAZ /
        gelen; <b>Gelen</b> ile aynı anonim koddan sayıldığı için bu, tablodaki tek cihaz-bazlı
        dönüşüm oranı — <b>Üye</b> oranı ise ayrı bir kaynaktan (kayıt damgası) gelir.{' '}
        <b>Biten</b> yüzdesinin tabanı "Gelen" DEĞİL <b>o satırın "Başlayan"ı</b> — yani
        tamamlanma oranı. Taban 0 ise oran hesaplanmaz, "—" gösterilir.
        <br />
        <br />
        <b>Direkt</b> = web'e <code>?ref=</code> olmadan geliş. <b>Bilinmiyor</b> = kaynak
        damgası olmayan satırlar — damgalama 16 Ağustos 2026'da eklendi ve mobil uygulamadan
        gelenler henüz damgalanmıyor. "Gelen" ile "Üye" İKİ AYRI ölçüm (ziyaretler anonim,
        hesaba bağlanmaz), bu yüzden oran %100'ü aşabilir ve bu bir hata değildir. CSV her
        zaman ham sayı indirir.
      </>
    ),
  },
  'surum-dagilimi': {
    title: 'Sürüm Dağılımı',
    body: (
      <>
        Son N günde <b>hangi istemci sürümünden kaç YEREL (YZ) oyun açıldığı</b>. Zorunlu
        güncelleme eşiğini (<code>mobile_min_supported_version</code>) yükseltmenin güvenli
        olup olmadığını gösteren tek veri: eşiği erken yükseltmek eski sürümdeki kullanıcıları
        uygulamadan kilitler, geç yükseltmek düzeltilmiş bir hatayı sahada yaşatır.
        <br />
        <b>Kullanıcı DEĞİL oyun açılışı sayar.</b> Port anonim cihaz kodu göndermediğinden app
        satırlarında cihaz sayılamıyor. Web'in sürümü yok ve bu doğru — orada aynı anda tek bir
        canlı derleme var, sürüm yerine <b>—</b> yazılır. Kapsam yalnızca YZ oyunları: yalnız
        Canlı oynayan biri burada hiç görünmez.
      </>
    ),
  },
  'kurulu-surum': {
    title: 'Kurulu Sürümler — Kişi',
    body: (
      <>
        Son N günde <b>uygulamayı AÇAN kaç KİŞİ hangi sürümde</b>. Kaynak{' '}
        <code>push_tokens</code>: satır hesaba bağlı ve token her açılışta yeniden
        hizalanıyor, yani <b>oyun oynanması gerekmiyor</b>.
        <br />
        <b>"Sürüm Dağılımı" tablosunun kopyası değil</b> — o tablo <code>game_starts</code>tan
        beslendiği için OYUN AÇILIŞI sayar, yalnızca YZ oyunlarını görür ve app satırlarında
        kişi sayamaz. İkisi farklı soru cevaplıyor; "kaç kişi yeni sürümde?" sorusunun cevabı
        BURASI.
        <br />
        <b>Kapsam:</b> yalnızca giriş yapmış <i>ve</i> bildirim izni vermiş kişiler. İzin
        vermeyen burada hiç görünmez — bu dürüst bir sınır ve zaten "kaça bildirim gidiyor"
        kapsamının aynısı. <b>Kişi</b> ile <b>cihaz</b> farklı olabilir: bir kişinin birden
        çok telefonu olabilir.
        <br />
        Sürüm damgası <b>31 Ağustos 2026'da doğdu</b> ve geriye dönük doldurulamaz: bir cihaz
        1.0.4 ya da sonrasıyla açılana kadar <b>—</b> görünür. Yani ilk günlerde "—" çoğunluk
        olacak; bu bir arıza değil.
      </>
    ),
  },
  cihaz: {
    title: 'Cihaz',
    body: (
      <>
        Gelen TÜM ziyaretçilerin (girişli VEYA girişsiz) işletim sistemi — iOS mü Android mi
        masaüstü mü. <b>Kaynak Hunisi'nden BAĞIMSIZ</b> — huni bilinçli olarak yalnızca misafir
        trafiğini izole ediyor (bkz. huni'nin kendi açıklaması), bu tablo ise o ayrımı hiç
        yapmadan herkesi sayıyor; girişli bir ziyaret hiçbir hesap kimliğiyle eşleştirilmeden,
        tamamen anonim (`device_visits`, `user_id` taşımaz) kaydediliyor.{' '}
        <b>"App mi web mi" DEĞİL</b> — iOS/Android satırları o cihazlardaki TARAYICIYI da
        içeriyor, yalnız kurulu uygulamayı değil ("Sürüm Dağılımı" tablosu o soruyu yanıtlıyor).
        24 Ağustos 2026'dan ÖNCEki misafir-only ölçüm (eski "Cihaz" tablosu) veritabanında
        duruyor ama artık çizilmiyor.
      </>
    ),
  },
  arkadaslik: {
    title: 'Arkadaşlık',
    body: (
      <>
        <b>Gönderilen istek</b> = o kovada açılan arkadaşlık isteği. <b>Kurulan arkadaşlık</b> = o
        kovada KABUL EDİLEN istek — kabul, isteğin gönderildiği kovada değil yanıtlandığı kovada
        sayılır, yani iki seri aynı kovada eşleşmek zorunda değil.
      </>
    ),
  },
  'oyun-sayisi': {
    title: 'Oyun Sayısı',
    body: (
      <>
        <b>Bitirilen</b> = torba+raf boşalarak ya da pas turuyla gerçekten sonuna kadar oynanmış
        oyunlar. <b>Teslim</b> = süre aşımıyla biten oyunlar (yerelde 7 gün, Canlı'da 48 saatlik
        sıra penceresi) — gerçek bir oyun süresi yansıtmadıklarından "Bitirilen"e karışmaz ve süre
        grafiğine hiç girmezler.
        <br />
        <br />
        Üstteki kombolar birlikte çalışır: kaynak (Toplam/Canlı/Yapay Zeka), kapsam
        (Toplam/Kayıtlı/Misafir) ve oyuncu sayısı. Canlı ile Misafir birlikte seçilemez — Canlı
        oyunda tüm katılımcılar girişlidir.
      </>
    ),
  },
  'oyun-suresi': {
    title: 'Oyun Süresi (Medyan)',
    body: (
      <>
        <b>Medyan</b> — yarısı bundan kısa, yarısı uzun. Ortalama BİLEREK kullanılmıyor: dağılım
        çarpık (açık unutulan oyunlar) ve ortalamayı tipik oyunun kat kat üstüne çekiyor —
        ölçüldüğünde ortalama 246,6 dk iken medyan 18,1 dk çıkmıştı.
        <br />
        <br />
        <b>Uzun kuyruk (p90)</b> serisini açarsan en uzun %10'un nerede başladığını görürsün.
        <br />
        <br />
        <b>Günlere Yayılan</b> = Canlı oyunlar (48 saatlik sıra penceresi nedeniyle her zaman bu
        tarafta) + uygulama kapatılıp devam edilen yerel oyunlar. <b>Tek Oturumda</b> yalnızca
        uygulama hiç kapatılmadan bitirilen Yapay Zeka oyunlarını kapsar.
        <br />
        <br />
        Hiç biten oyunu olmayan kovada değer 0 değil BOŞ döner — 0 dakika "çok hızlı bitmiş oyun"
        gibi okunurdu.
      </>
    ),
  },
  'begeni-paylasma': {
    title: 'Beğeni / Paylaşma',
    body: (
      <>
        <b>Beğeni</b> = o kovada basılan kalp. <b>Paylaşma</b> = o kovada İLK KEZ paylaşılan oyun.
        <br />
        <br />
        25 Temmuz 2026'dan önce paylaşılmış oyunlarda paylaşım tarihi tutulmuyordu; onlar hiçbir
        kovaya düşmez ama yukarıdaki toplam paylaşılan oyun sayısına dahildir — iki sayının
        birbirini tutmaması bu yüzden beklenen bir durum.
      </>
    ),
  },
  'yz-dengesi': {
    title: 'YZ Dengesi',
    body: (
      <>
        Yapay Zeka'ya karşı oynanan, teslimle bitmemiş oyunlarda İNSANIN derece oranı. Teslim
        satırları hariç — onlar bir beceri sonucu değil, 7 günlük terk-edilme cezasının kaydı;
        dahil edilseler YZ olduğundan güçlü görünürdü. Canlı oyunlar hiç sayılmaz.
        <br />
        <br />
        Sayıyı kutudaki <b>"rastgele"</b> değerine göre oku: insan oranı onun belirgin ALTINDAysa
        YZ fazla güçlü, çok ÜSTÜNDEyse fazla zayıf demektir. Bu, YZ algoritmasına dokunan bir
        değişikliğin regresyonunu yakalayan tek sayı.
        <br />
        <br />
        <b>İkincilik yalnızca 4 kişilikte var</b>, çünkü k-lig puanı orada ikinciliğe de veriliyor
        (2 kişilikte ikinci olmak kaybetmekle aynı şey, puan getirmez). Dengeyi asıl anlatan sayı
        bu ikisinin TOPLAMI: insan "puan alan" ilk iki dereceye ne sıklıkla giriyor? Rastgele bir
        sonuçta bu %50 olurdu — birincilik ve ikincilik yüzdelerini toplayıp o değerle karşılaştır.
      </>
    ),
  },
  uyeler: {
    title: 'Üyeler',
    body: (
      <>
        Tüm kayıtlı kullanıcılar ve kayıt sırasında doldurdukları her alan — izinler dahil.
        Değerler CANLI: üye Hesap Ayarları'ndan bir alanı sonradan değiştirirse panel yeni
        değeri gösterir. Girilmemiş alanlar <b>—</b> ile yazılır. Tablo yana kaydırılır.
        <br />
        <br />
        <b>Koşullar</b> = Kullanım Koşulları/Gizlilik onayı; kayıt formunda ZORUNLUDUR, yani
        "Hayır" pratikte yalnızca onayın kayda hiç geçmediği çok eski hesaplarda görünür.
        <b> Pazarlama</b> isteğe bağlıdır ve sonradan geri çekilebilir — "Hayır" bir eksik
        değil, kullanıcının tercihidir. <b>E-posta Bildirimi</b> ise tersi yönde çalışır
        (varsayılanı Açık, kullanıcı kapatabilir).
        <br />
        <br />
        <b>Kanal</b> kaydın hangi formdan geldiğini söyler (Direkt/Form); <b>Kaynak</b> ise
        kayıt anındaki `?ref=` etiketidir (Kaynak Hunisi'yle aynı alan). İkisi BAĞIMSIZ,
        karıştırılmamalı.
        <br />
        <br />
        CSV ekranda görüneni indirir: arama ve sıralama uygulanmış hâli.
      </>
    ),
  },
  hatalar: {
    title: 'Hatalar',
    body: (
      <>
        İstemcide (tarayıcı/uygulama) oluşup <b>hiçbir sunucu logunda iz bırakmayan</b> hatalar.
        Satırlar tek tek değil <b>gruplanmış</b> gelir: aynı tür + aynı mesaj imzası (ilk 160
        karakter) tek satırdır.
        <br />
        <br />
        <b>Kez</b> toplam kayıt sayısı, <b>Cihaz</b> ise kaç FARKLI cihazda olduğu —
        karıştırılmamalı: 40 kez / 1 cihaz bir kişinin döngüsü, 3 kez / 3 cihaz gerçek bir
        yaygın hatadır. <b>Derleme</b> sütunu hatanın hangi sürümde görüldüğünü söyler; düzeltme
        sonrası yalnızca ESKİ derlemede kalması "düzeldi" demektir.
        <br />
        <br />
        Beklenen durumlar (çevrimdışılık, sunucunun kendi reddi) <b>bilerek kaydedilmez</b> —
        buradaki her satır "birinin bakması gereken bir şey" olmalı. Yol (route) kimliklerden
        arındırılır (<code>/game/:id</code>), oturum başına en fazla 10 kayıt gönderilir.
      </>
    ),
  },
  'geri-bildirim': {
    title: 'Geri Bildirim',
    body: (
      <>
        <b>Gelen</b> = kullanıcıların gönderdiği görüşler. <b>Gönderilen</b> = admin'in "Mesaj
        Gönder" ile yolladıkları (kayıt olarak burada durur, yanıtlanmaz).
        <br />
        <br />
        CSV ekranda görüneni indirir: seçili filtre uygulanmış hâli.
      </>
    ),
  },
};

type HintId = keyof typeof HINTS;

/**
 * Grafik/tablo altındaki tek satırlık VERİ notu. Artık açıklama için
 * kullanılmıyor (o metinler `HINTS`e taşındı) — geriye yalnızca kutulara
 * sığmayan aktivasyon dağılımı kaldı.
 */
const captionCls = 'text-[9px] font-mono text-muted leading-relaxed';

/**
 * Saati okunaklı bir etiketе çevirir (ilk oyuna kadar geçen medyan süre).
 * `formatDuration` BİLEREK kullanılmıyor: o, bir saatin altını "48:00" gibi
 * saat:dakika biçiminde yazıyor ve "48 saat" diye okunabiliyor — burada
 * ölçülen şey zaten çoğunlukla dakikalar mertebesinde.
 */
function formatHours(hours: number | null): string {
  if (hours === null) return '—';
  if (hours < 1) return `${Math.round(hours * 60)} dk`;
  if (hours < 48) return `${hours.toFixed(1).replace('.', ',')} sa`;
  return `${(hours / 24).toFixed(1).replace('.', ',')} gün`;
}

/**
 * Hata türünün okunabilir adı. Ham değerler (`uncaught`/`promise`/`boundary`/
 * `manual`) `src/utils/errorReporting.ts`'teki `ClientErrorKind` ile birebir —
 * biri değişirse burası da değişmeli. Tanınmayan bir tür OLDUĞU GİBİ gösterilir
 * (portun ileride ekleyeceği bir tür sessizce "—" olmasın diye).
 */
function errorKindLabel(kind: string): string {
  switch (kind) {
    case 'uncaught':
      return 'Yakalanmamış';
    case 'promise':
      return 'Promise';
    case 'boundary':
      return 'Çökme';
    case 'manual':
      return 'Bildirilen';
    default:
      return kind;
  }
}

/** "CSV İndir"/"Tablo Görünümü" gibi küçük alt çizgili aksiyon linkleri için ortak stil. */
const csvLinkCls =
  'text-[9px] font-mono uppercase tracking-[0.5px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity shrink-0';

/**
 * Metrik tanımını açan `?` rozeti — her CSV'nin yanında, CSV'si olmayan iki
 * panelde bölüm başlığının yanında.
 *
 * Görsel dil `ScoreCard`/`PlayerScoreCard`'daki k-lig "?" rozetinden alındı
 * (yuvarlak, `border-muted`) — yeni bir gösterge icat edilmedi. Boyut oradaki
 * 14px yerine 13px: kardeşi olan "CSV İndir" 9px'lik bir satır ve 14px rozet
 * o satırı büyütüyordu.
 *
 * `py-1 -my-1`: dokunma alanını büyütürken layout ayak izini DEĞİŞTİRMİYOR
 * (negatif margin dolguyu birebir geri alıyor) — `SourceFunnelTable`'ın
 * "% / Sayı" düğmesindeki aynı desen.
 */
function InfoHint({ id, onOpen }: { id: HintId; onOpen: (id: HintId) => void }) {
  return (
    <button
      type="button"
      onClick={() => onOpen(id)}
      aria-label={`${HINTS[id].title} — bu nedir?`}
      className="shrink-0 p-1 -m-1 active:opacity-70 transition-opacity"
    >
      {/* Daire İÇ span'de: dolgu doğrudan butona verilseydi `rounded-full`
          15×23'lük bir elips üretirdi. */}
      <span className="w-[13px] h-[13px] rounded-full border border-muted text-muted text-[9px] font-mono leading-none flex items-center justify-center">
        ?
      </span>
    </button>
  );
}

/** CSV dosya adına (uzantısız temel isim) bugünün tarihini ekler — ör. "kelimeki-uyeler-2026-07-25.csv". */
function csvFilename(baseName: string): string {
  return `${baseName}-${new Date().toISOString().slice(0, 10)}.csv`;
}

/**
 * Büyüme > Kullanıcı altındaki "Kaynak/Cihaz/Ana Ekrana Ekleme" gibi tek
 * boyutlu ziyaretçi dökümlerini (satır başına {label, visitors}) ortak bir
 * tablo olarak çizer — üçü de aynı yükleniyor/boş/toplam mantığını paylaşır.
 */
function GuestBreakdownTable<T extends { visitors: number }>({
  columnLabel,
  emptyLabel,
  rows,
  getKey,
  getLabel,
  csvBaseName,
  infoHint,
  valueLabel = 'Ziyaretçi',
}: {
  columnLabel: string;
  emptyLabel: string;
  rows: T[] | null;
  getKey: (row: T) => string;
  getLabel: (row: T) => string;
  csvBaseName: string;
  infoHint?: ReactNode;
  /**
   * Sayı sütununun başlığı. Varsayılanı "Ziyaretçi" — üç ziyaretçi dökümü
   * onu kullanıyor. Sürüm dağılımı ziyaretçi DEĞİL oyun açılışı saydığından
   * kendi etiketini geçiyor; başlığı sabit bırakmak sayının ne olduğu
   * konusunda yalan söylerdi (CSV başlığı da bunu izliyor).
   */
  valueLabel?: string;
}) {
  // Boş/yüklenirken de `?` çizilir — "bu tablo neyi sayıyor?" sorusu tam da
  // hiç veri yokken sorulur (CSV ise indirilecek satır olmadan gizleniyor).
  if (rows === null || rows.length === 0) {
    return (
      <div className="flex flex-col gap-1.5">
        {infoHint && <div className="self-end">{infoHint}</div>}
        <div className="text-xs font-mono text-muted text-center py-6">
          {rows === null ? 'Yükleniyor…' : emptyLabel}
        </div>
      </div>
    );
  }
  const totalVisitors = rows.reduce((sum, row) => sum + row.visitors, 0);
  const visibleRows = rows;

  function handleExportCsv() {
    downloadCsv(
      csvFilename(csvBaseName),
      [columnLabel, valueLabel, '%'],
      [
        ...visibleRows.map((row) => [
          getLabel(row),
          row.visitors,
          totalVisitors > 0 ? ((row.visitors / totalVisitors) * 100).toFixed(2) : '0.00',
        ]),
        ['TOPLAM', totalVisitors, '100.00'],
      ],
    );
  }

  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-end gap-2">
        {infoHint}
        <button type="button" onClick={handleExportCsv} className={csvLinkCls}>
          CSV İndir
        </button>
      </div>
      <div className="overflow-x-auto">
        <table className="w-auto text-[11px] font-mono border-collapse">
          <thead>
            <tr className="text-left text-muted border-b border-border">
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px]">{columnLabel}</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">{valueLabel}</th>
              <th className="py-1.5 font-bold uppercase tracking-[1px] text-center">%</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={getKey(row)} className="border-b border-border/50">
                <td className="py-1.5 pr-8 text-text whitespace-nowrap">{getLabel(row)}</td>
                <td className="py-1.5 pr-8 text-muted whitespace-nowrap text-center">{row.visitors}</td>
                <td className="py-1.5 text-muted whitespace-nowrap text-center">
                  {totalVisitors > 0 ? ((row.visitors / totalVisitors) * 100).toFixed(2) : '0.00'}%
                </td>
              </tr>
            ))}
            <tr className="border-b border-border/50">
              <td className="py-1.5 pr-8 text-text font-bold whitespace-nowrap">TOPLAM</td>
              <td className="py-1.5 pr-8 text-text font-bold whitespace-nowrap text-center">{totalVisitors}</td>
              <td className="py-1.5 text-text font-bold whitespace-nowrap text-center">100.00%</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}

/**
 * Kaynak hunisi (Büyüme > Kullanıcı): kaynak → kişi → başlayan → üye → oyun.
 *
 * "Ziyaretçi Kaynağı" tablosunun yerini aldı (16 Ağustos 2026, kullanıcı
 * isteği). İlk sütun eskisiyle AYNI sayı; üzerine iki adım eklendi.
 *
 * SÜTUNLAR İKİ AYRI KAYNAKTAN GELİYOR ve bu bilinçli: "Kişi" anonim
 * `guest_visits`ten, "Üye"/"Oyun" ise kayıt anında profile damgalanan
 * `profiles.signup_utm_source`tan. Aralarında join YOK — ziyaret satırlarını
 * hesaba bağlamak `PrivacyModal`daki anonimlik taahhüdünü bozardı. Bunun
 * doğal sonucu: bir satırda yalnızca ziyaretçi ya da yalnızca üye olabilir.
 *
 * `% / Sayı` düğmesi (16 Ağustos 2026, kullanıcı isteği: "basınca değerden
 * yüzdeye dönsün, basınca % sayı olsun, dönüşümlü çalışsın") üç sütunu birden
 * çevirir. Düğme iki etiketi de gösterip aktif olanı vurguluyor: tek kelimelik
 * bir düğme ("%") "şu an yüzde mi gösteriyorum, yoksa basınca yüzdeye mi
 * geçerim" belirsizliğini taşırdı.
 *
 * YÜZDELERİN TABANI SÜTUNA GÖRE DEĞİŞİR (aynı gün, kullanıcının ikinci
 * turu: *"kişi %'ye dönünce toplamın yüzdesini göstersin. Ama üye yüzdesi
 * kişinin % kaçı üye olmuş, oyun yüzdesi de kişinin % kaçı oyun oynamışı
 * göstersin."*):
 *   - **Gelen**    = sütun payı (o kaynak tüm ziyaretçilerin yüzde kaçı),
 *   - **Üye**      = `üye / gelen` — o kaynaktan gelenlerin yüzde kaçı üye oldu,
 *   - **Başlayan** = `başlatan cihaz / gelen` — yüzde kaçı oyuna oturdu,
 *   - **Biten**    = `biten / BAŞLAYAN` — başlayanların yüzde kaçı bitirdi.
 *
 * Son satırın tabanı bilinçli olarak "gelen" DEĞİL: "Biten" ile "Başlayan"
 * AYNI dimension'dan (anonim cihaz tabloları, misafir dahil) geliyor, yani
 * aralarındaki oran gerçek bir tamamlanma oranı.
 *
 * "Başlayan" 21 Ağustos 2026'da eklendi (ROADMAP #9) ve huninin KÖR olan
 * adımını kapatıyor: ilk Instagram kampanyasında 80 kişi / 0 üye / 0 oyun
 * ölçüldü, ama "Oyun" hem yalnızca BİTMİŞ oyunu hem yalnızca GİRİŞLİ
 * kullanıcıyı sayıyor — yani o 0, "kimse oynamadı" mı "kimse bitirmedi" mi
 * ayırt edilemiyordu. `game_starts` misafiri de sayıyor ve etiketini
 * ziyaretle AYNI anonim koddan alıyor, dolayısıyla `başlatan / kişi` bu
 * tablodaki tek gerçek cihaz-bazlı dönüşüm oranı.
 *
 * TABLO BAŞTAN SONA MİSAFİR HUNİSİ (22 Ağustos 2026, kullanıcı isteği:
 * *"gelenler üye olmadan kaç oyun başlatmış (başlayan), gelenler üye olmadan
 * kaç oyun bitirmiş (biten)"*). "Gelen" BAŞTAN BERİ misafir-only idi
 * (`App.tsx`: ziyaret kaydı yalnızca oturum kapalıyken yazılıyor), "Başlayan"
 * ile "Biten" karışıktı — yani tablo üç farklı kitleyi yan yana koyuyor ve
 * bunu hiçbir yerde söylemiyordu. Artık üçü de aynı kitle.
 *
 * "Biten"i ayırıp "Başlayan"ı bırakmak YANLIŞ olurdu: ikisi bir çift ve
 * `biten/başlayan` tamamlanma oranını besliyor; yalnız birini indirmek oranı
 * "misafir bitişi ÷ TÜM başlangıçlar" yapıp sessizce düşük gösterirdi. Bunun
 * için `game_starts`e bir `is_guest` bayrağı eklendi — `user_id` DEĞİL, çünkü
 * o tablo bilerek hesap kimliği taşımıyor (gizlilik taahhüdü); bir bayrak
 * hangi hesap olduğunu söylemediğinden taahhüt aynen ayakta.
 *
 * "Biten" sütunu 22 Ağustos 2026'da ESKİ "Oyun" sütununun YERİNE geldi ve bu
 * bir yeniden adlandırma DEĞİL, ölçünün kendisinin değişmesi. Eski sütun
 * `games` üzerinden yalnızca ÜYELERİN bitirdiği oyunu sayıyordu — yani
 * reklamdan gelen misafir trafiğinde TANIM GEREĞİ hep 0 görünüyordu (ölçüldü,
 * Instagram: 47 başlayan / 3 üye / 0 üye-oyunu) ve huninin son adımı gerçekte
 * hâlâ kördü: "Başlayan" ile karşılaştırılabilir bir bitiş ölçüsü yoktu.
 * `game_finishes` misafiri de sayıyor ve 22 Ağustos'tan beri kendi
 * `utm_source`'unu taşıyor. Eski ölçü SİLİNMEDİ — RPC hâlâ `member_games`
 * (üyelerin oyun adedi) ve `players` (benzersiz oynayan üye) döndürüyor,
 * ikisi de CSV'de duruyor, yalnızca tabloda gösterilmiyor. İkisi BİLEREK
 * korunuyor ve bu, üye tarafını ekrana taşımamanın da gerekçesi: onlar
 * üyenin KAYIT damgasından gelir, yani hesabı takip eder — bir üye başka bir
 * cihazdan oynarsa cihaz etiketi 'bilinmiyor'a düşer, kayıt damgası düşmez.
 * "Bu kanal değerli üye getirdi mi" sorusunun daha güvenilir cevabı budur;
 * cihaz etiketiyle ikinci bir üye ölçüsü üretmek aynı sorunun iki farklı
 * yanıtını doğururdu (bu kod tabanının en sık tekrarlayan hata sınıfı).
 *
 * SINIR: `üye/gelen` yalnızca İKİ UCU DA damgalanmış bir kaynakta gerçek bir
 * dönüşüm oranıdır — `?ref=instagram` ile gelen ziyaretçi de oradan üye olan
 * hesap da aynı etiketi taşıdığı için anlamlı. Taban 0 olan satırlarda (ör.
 * damgalama öncesi üyelerin toplandığı "bilinmiyor") oran HİÇ hesaplanmaz,
 * "—" gösterilir; sıfıra bölmek yerine "bilinmiyor" demek doğrusu. Oran
 * %100'ü aşabilir (iki ölçü ayrı dimension) ve bu bir hata değil — ekrandaki
 * `?` açıklaması bunu da söylüyor.
 *
 * CSV her zaman HAM SAYI verir (düğmeden bağımsız) — retention tablosundaki
 * aynı karar: yuvarlama kaybı olmaz, yüzde zaten yeniden hesaplanabilir.
 * `starters`/`member_games`/`players` tabloda hiç ayrı sütun değil, CSV'de var.
 */
function SourceFunnelTable({
  rows,
  infoHint,
}: {
  rows: AdminSourceFunnelRow[] | null;
  infoHint?: ReactNode;
}) {
  const [asPercent, setAsPercent] = useState(false);
  // Boş/yüklenirken de `?` çizilir (GuestBreakdownTable ile aynı gerekçe).
  if (rows === null || rows.length === 0) {
    return (
      <div className="flex flex-col gap-1.5">
        {infoHint && <div className="self-end">{infoHint}</div>}
        <div className="text-xs font-mono text-muted text-center py-6">
          {rows === null ? 'Yükleniyor…' : 'Bu aralıkta veri yok.'}
        </div>
      </div>
    );
  }
  const total = rows.reduce(
    (acc, row) => ({
      visitors: acc.visitors + row.visitors,
      starts: acc.starts + row.starts,
      starters: acc.starters + row.starters,
      signups: acc.signups + row.signups,
      finishes: acc.finishes + row.finishes,
      member_games: acc.member_games + row.member_games,
      players: acc.players + row.players,
    }),
    { visitors: 0, starts: 0, starters: 0, signups: 0, finishes: 0, member_games: 0, players: 0 },
  );

  function handleExportCsv() {
    downloadCsv(
      csvFilename('kelimeki-kaynak-funnel'),
      [
        'Kaynak',
        'Gelen',
        'Üye',
        'Başlayan Oyun',
        'Başlatan Cihaz',
        'Biten Oyun',
        'Üye Oyunu',
        'Oynayan Üye',
      ],
      [
        ...rows!.map((row) => [
          row.source,
          row.visitors,
          row.signups,
          row.starts,
          row.starters,
          row.finishes,
          row.member_games,
          row.players,
        ]),
        [
          'TOPLAM',
          total.visitors,
          total.signups,
          total.starts,
          total.starters,
          total.finishes,
          total.member_games,
          total.players,
        ],
      ],
    );
  }

  const pct = (value: number, base: number) =>
    `${((value / base) * 100).toFixed(1)}%`;

  /** "Gelen" sütunu — yüzdesi SÜTUN payı. */
  function visitorCell(value: number): string {
    if (!asPercent) return String(value);
    return total.visitors > 0 ? pct(value, total.visitors) : '0.0%';
  }

  /**
   * "Üye"/"Başlayan"/"Biten" sütunları — yüzdeleri SATIR YÖNÜNDE dönüşüm
   * oranı. Taban 0 ise oran yok ("—"): sıfıra bölmek yerine bilinmediğini
   * söylemek doğrusu (bugün "bilinmiyor" satırı tam bu durumda).
   *
   * ⚠ TABAN SÜTUNA GÖRE DEĞİŞİR ve bu bilinçli: "Üye"/"Başlayan"ın tabanı o
   * satırın "Gelen"i, "Biten"in tabanı ise o satırın "Başlayan"ı — çünkü
   * "Biten"in sorduğu soru "gelenlerin kaçı bitirdi" değil "başlayanların kaçı
   * bitirdi" (tamamlanma oranı). İkisi de AYNI dimension'dan (anonim cihaz
   * tabloları) geldiğinden bu oran gerçek; `member_games`/`players` ise
   * profil damgasından gelir, o yüzden artık tabloda hiç gösterilmiyor.
   *
   * [percentOf] ayrı bir parametre çünkü bazı sütunlarda gösterilen SAYI ile
   * oranın PAYI farklı: "Başlayan" oyun ADEDİNİ gösterir ama oranı benzersiz
   * CİHAZ üzerinden hesaplanır (bir kişi 50 oyun açarsa oran %100'ü aşardı).
   */
  function conversionCell(value: number, base: number, percentOf: number): string {
    if (!asPercent) return String(value);
    if (base <= 0) return '—';
    return pct(percentOf, base);
  }

  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-end gap-3">
        <button
          type="button"
          onClick={() => setAsPercent((v) => !v)}
          aria-pressed={asPercent}
          aria-label={asPercent ? 'Sayıya dön' : 'Yüzdeye çevir'}
          /* `py-1 -my-1`: dokunma alanı 13.5 → 21.5px olurken layout ayak izi
             DEĞİŞMİYOR (negatif margin dolguyu birebir geri alıyor) — aynı
             desen "Tüm Oyunlarım"daki hamle ikonunda da kullanıldı. Kardeşi
             olan "CSV İndir" de aynı payı alıyor ki ikisi asimetrik olmasın. */
          className="text-[9px] font-mono uppercase tracking-[0.5px] py-1 -my-1 active:opacity-70 transition-opacity shrink-0"
        >
          <span className={asPercent ? 'text-accent font-bold' : 'text-muted'}>%</span>
          <span className="text-muted"> / </span>
          <span className={asPercent ? 'text-muted' : 'text-accent font-bold'}>Sayı</span>
        </button>
        <button type="button" onClick={handleExportCsv} className={`${csvLinkCls} py-1 -my-1`}>
          CSV İndir
        </button>
        {infoHint}
      </div>
      <div className="overflow-x-auto">
        <table className="w-auto text-[11px] font-mono border-collapse">
          <thead>
            <tr className="text-left text-muted border-b border-border">
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px]">Kaynak</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">Gelen</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">Üye</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">
                Başlayan
              </th>
              <th className="py-1.5 font-bold uppercase tracking-[1px] text-center">Biten</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.source} className="border-b border-border/50">
                <td className="py-1.5 pr-8 text-text whitespace-nowrap">{row.source}</td>
                <td className="py-1.5 pr-8 text-muted whitespace-nowrap text-center">
                  {visitorCell(row.visitors)}
                </td>
                <td className="py-1.5 pr-8 text-muted whitespace-nowrap text-center">
                  {conversionCell(row.signups, row.visitors, row.signups)}
                </td>
                <td className="py-1.5 pr-8 text-muted whitespace-nowrap text-center">
                  {conversionCell(row.starts, row.visitors, row.starters)}
                </td>
                <td className="py-1.5 text-muted whitespace-nowrap text-center">
                  {conversionCell(row.finishes, row.starts, row.finishes)}
                </td>
              </tr>
            ))}
            <tr className="border-b border-border/50">
              <td className="py-1.5 pr-8 text-text font-bold whitespace-nowrap">TOPLAM</td>
              <td className="py-1.5 pr-8 text-text font-bold whitespace-nowrap text-center">
                {visitorCell(total.visitors)}
              </td>
              <td className="py-1.5 pr-8 text-text font-bold whitespace-nowrap text-center">
                {conversionCell(total.signups, total.visitors, total.signups)}
              </td>
              <td className="py-1.5 pr-8 text-text font-bold whitespace-nowrap text-center">
                {conversionCell(total.starts, total.visitors, total.starters)}
              </td>
              <td className="py-1.5 text-text font-bold whitespace-nowrap text-center">
                {conversionCell(total.finishes, total.starts, total.finishes)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}

/**
 * Retention kohort tablosu (Büyüme > Kullanıcı) — satır: kayıt haftası,
 * sütun: kayıttan sonraki hafta (H0 = kayıt haftasının kendisi).
 *
 * Hücrenin zemin tonu TEK bir hueyle (accent) açıktan koyuya gider — kohort
 * tablolarında gökkuşağı palet bir anti-desendir (renk sırası büyüklük sırası
 * değildir). Ton yalnızca ikincil bir işaret: oran her hücrede SAYIYLA da
 * yazıyor, yani bilgi asla renge tek başına bağlı değil (renk körlüğü/baskı).
 *
 * Azami ton `MAX_TINT`te durur ve bu ölçülmüş bir sınırdır: `text-text`
 * (#1B2430) o zeminde 6.7:1 kontrast veriyor (WCAG AA 4.5:1'in üstünde).
 * Hücre yazısı bu yüzden `text-muted` DEĞİL — muted, 0.25 tonun üstünde
 * 4.5:1'in altına düşüyor (ölçüldü).
 */
const MAX_TINT = 0.55;

function RetentionCohortTable({
  cells,
  csvBaseName,
  infoHint,
}: {
  cells: AdminRetentionCell[] | null;
  csvBaseName: string;
  infoHint?: ReactNode;
}) {
  const grid = useMemo(() => {
    if (!cells) return null;
    const byWeek = new Map<string, { size: number; offsets: Map<number, number> }>();
    let maxOffset = -1;
    for (const c of cells) {
      let row = byWeek.get(c.cohort_week);
      if (!row) {
        row = { size: c.cohort_size, offsets: new Map() };
        byWeek.set(c.cohort_week, row);
      }
      row.offsets.set(c.week_offset, c.active_users);
      if (c.week_offset > maxOffset) maxOffset = c.week_offset;
    }
    // En yeni kohort üstte — taze kohort kaydırmadan görünsün.
    const weeks = [...byWeek.entries()].sort((a, b) => (a[0] < b[0] ? 1 : -1));
    return { weeks, maxOffset };
  }, [cells]);

  // Boş/yüklenirken de `?` çizilir (GuestBreakdownTable ile aynı gerekçe).
  if (grid === null || grid.weeks.length === 0 || grid.maxOffset < 0) {
    return (
      <div className="flex flex-col gap-1.5">
        {infoHint && <div className="self-end">{infoHint}</div>}
        <div className="text-xs font-mono text-muted text-center py-6">
          {grid === null ? 'Yükleniyor…' : 'Henüz tamamlanmış bir hafta yok.'}
        </div>
      </div>
    );
  }

  // Destructure: `handleExportCsv` bir fonksiyon bildirimi olduğundan TS,
  // yukarıdaki `grid === null` erken dönüşünün daralttığı tipi closure içinde
  // korumuyor (TS18047).
  const { weeks, maxOffset } = grid;
  const offsets = Array.from({ length: maxOffset + 1 }, (_, i) => i);

  function handleExportCsv() {
    // Yüzde değil HAM SAYI dışa aktarılıyor: yuvarlama kaybı olmuyor ve
    // "Üye" sütunu paydayı taşıdığından oran her zaman yeniden hesaplanabilir.
    downloadCsv(
      csvFilename(csvBaseName),
      ['Kohort (kayıt haftası)', 'Üye', ...offsets.map((o) => `H${o}`)],
      weeks.map(([week, row]) => [
        week,
        row.size,
        ...offsets.map((o) => {
          const v = row.offsets.get(o);
          return v === undefined ? '' : v;
        }),
      ]),
    );
  }

  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-end gap-2">
        {infoHint}
        <button type="button" onClick={handleExportCsv} className={csvLinkCls}>
          CSV İndir
        </button>
      </div>
      <div className="overflow-x-auto">
        <table className="w-auto text-[11px] font-mono border-collapse">
          <thead>
            <tr className="text-left text-muted border-b border-border">
              <th className="py-1.5 pr-4 font-bold uppercase tracking-[1px] whitespace-nowrap">Kohort</th>
              <th className="py-1.5 pr-4 font-bold uppercase tracking-[1px] text-center">Üye</th>
              {offsets.map((o) => (
                <th key={o} className="py-1.5 px-1.5 font-bold uppercase tracking-[1px] text-center">
                  H{o}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {weeks.map(([week, row]) => (
              <tr key={week} className="border-b border-border/50">
                <td className="py-1.5 pr-4 text-text whitespace-nowrap">
                  {new Date(week + 'T00:00:00').toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit' })}
                </td>
                <td className="py-1.5 pr-4 text-muted whitespace-nowrap text-center">{row.size}</td>
                {offsets.map((o) => {
                  const active = row.offsets.get(o);
                  if (active === undefined) {
                    // Penceresi henüz TAMAMLANMAMIŞ hafta — boş bırakılıyor.
                    // Yarım bir haftayı çizmek tablonun son köşegenini her zaman
                    // yalancı bir "düşüş" gibi gösterirdi.
                    return <td key={o} className="py-1.5 px-1.5" />;
                  }
                  const ratio = row.size > 0 ? active / row.size : 0;
                  return (
                    <td
                      key={o}
                      className="py-1.5 px-1.5 text-text text-center whitespace-nowrap"
                      style={{
                        // taban 0.06 (sıfır oranda bile hücre "veri var" desin) → azami MAX_TINT
                        backgroundColor: `rgba(37, 99, 235, ${(0.06 + (MAX_TINT - 0.06) * ratio).toFixed(3)})`,
                      }}
                      title={`${active}/${row.size} üye aktif`}
                    >
                      %{Math.round(ratio * 100)}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/**
 * Saniyeyi kısa bir süre etiketine çevirir (grafik ekseni/tooltip/tablo için).
 * 1 saatin altı saat:dakika:saniye biçiminde saat gibi ("6:34"); üstü kısaltılmış
 * birimlerle ("2s 15dk", "5g 18s", "3h 2g", "2a 1h", "1y 5a") — çok oturumlu
 * oyunlarda başlangıç-bitiş arası gerçekte saatler/günler/haftalar hatta
 * aylar/yıllar sürebildiğinden gün/hafta/ay/yıl kademeleri de var, yoksa örn.
 * 3 günlük bir ara "72s" gibi okunaksız gösterilirdi. Ay/yıl kademeleri
 * takvimsel değil yaklaşık (30/365 gün) — burada amaç kesin tarih farkı değil,
 * okunaklı bir ortalama süre etiketi.
 */
function formatDuration(totalSeconds: number): string {
  const s = Math.round(totalSeconds);
  if (s < 3600) {
    const m = Math.floor(s / 60);
    const rs = s % 60;
    return `${m}:${String(rs).padStart(2, '0')}`;
  }
  const totalMin = Math.floor(s / 60);
  const h = Math.floor(totalMin / 60);
  const rm = totalMin % 60;
  if (h < 24) return rm ? `${h}s ${rm}dk` : `${h}s`;
  const d = Math.floor(h / 24);
  const rh = h % 24;
  if (d < 7) return rh ? `${d}g ${rh}s` : `${d}g`;
  if (d < 30) {
    const w = Math.floor(d / 7);
    const rd = d % 7;
    return rd ? `${w}h ${rd}g` : `${w}h`;
  }
  if (d < 365) {
    const mo = Math.floor(d / 30);
    const rw = Math.floor((d % 30) / 7);
    return rw ? `${mo}a ${rw}h` : `${mo}a`;
  }
  const y = Math.floor(d / 365);
  const rmo = Math.floor((d % 365) / 30);
  return rmo ? `${y}y ${rmo}a` : `${y}y`;
}

function fmtDate(iso: string | null) {
  if (!iso) return '—';
  const d = new Date(iso);
  const date = d.toLocaleDateString('tr-TR');
  const time = d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
  return `${date} ${time}`;
}

function memberName(m: AdminMember) {
  return [m.first_name, m.last_name].filter(Boolean).join(' ').trim() || m.username || '—';
}

function memberNickname(m: AdminMember) {
  return m.display_name || '—';
}

function memberChannelLabel(m: AdminMember) {
  return m.signup_channel === 'form' ? 'Form' : 'Direkt';
}

/** Boş/eksik her alan için TEK gösterim — tabloda ve CSV'de aynı. */
const BOS = '—';

/**
 * Üyeler tablosunda İSİM kolonu yana kaydırırken SABİT kalır (21 Ağustos
 * 2026, kullanıcı isteği: *"sola doğru kaydırınca isim kolonunu
 * sabitleyebilir miyiz? Tabloda kişiyi takip etmek zor oluyor."*). Tablo 18
 * kolonla ~1800px olduğundan sağa kaydırırken hangi satırın kime ait olduğu
 * kayboluyordu.
 *
 * İki zorunluluk:
 * - **Opak zemin ŞART.** `sticky` hücre altındaki hücrelerin ÜSTÜNDE durur;
 *   arka planı saydam kalırsa kayan metin içinden geçer. Zemin `bg-panel`,
 *   yani modal gövdesinin kendi rengi.
 * - **GENİŞLİK KAPAKLANMALI.** İsim alanının uzunluk sınırı YOK ve bu kolon
 *   tablonun en genişi; kapaklanmazsa 320px'lik bir ekranda (tablo kabı
 *   246px) sabitlenen kolon görünür alanın TAMAMINI yer ve geri kalan 17
 *   kolon hiç görünmez. Ölçüldü: üretimdeki en uzun ad 18 karakter (~131px),
 *   yani 150px bugünkü hiçbir adı kırpmıyor — yalnızca uç durumlar `truncate`
 *   ile kısalır ve tam hâli `title`da kalır.
 * - **Sağ kenardaki ayraç `border-r` DEĞİL `box-shadow`.** Sabit hücre kayan
 *   içeriğin üstünde durduğundan ikisi arasında hiçbir sınır yoktu ve
 *   kırpılmış bir ad altından geçen kolonun metnine yapışık görünüyordu
 *   (ölçüm turunda ekran görüntüsünde yakalandı). `border-r` DENENDİ ve
 *   ÇİZİLMEDİ: tablo `border-collapse: collapse` olduğundan kenarlık hücreye
 *   değil TABLOYA ait olur, yani kaydıkça yerinde kalıp sabit hücrenin
 *   altında kaybolur. Gölge hücrenin kendisiyle birlikte taşınıyor. Renk
 *   `border` token'ının değeri (#DCE2EA) — Tailwind gölge yardımcısı token
 *   adı kabul etmiyor, biri değişirse öteki de değişmeli.
 */
const STICKY_NAME_CELL =
  'sticky left-0 z-[1] bg-panel max-w-[150px] truncate shadow-[1px_0_0_0_#DCE2EA]';

/**
 * Üyeler tablosunun BAŞLIK SATIRI dikeyde sabit (31 Ağustos 2026, kullanıcı
 * isteği: *"Admin/Üyeler başlık satırı sabitlenecek"*). Uzun listede
 * kaydırırken hangi kolonun ne olduğu kayboluyordu — `STICKY_NAME_CELL`'in
 * yatay karşılığı.
 *
 * ⚠ BU YALNIZCA TABLONUN KABI KENDİ DİKEY KAYDIRICISI OLDUĞUNDA ÇALIŞIR ve
 * bu ÖLÇÜLDÜ. Kap eskiden sadece `overflow-x-auto` idi; naif bir
 * `sticky top-0` HİÇ yapışmıyordu, çünkü `overflow-x: auto` verilen bir
 * elemanda `overflow-y` de `auto`ya hesaplanır (harness'te doğrulandı:
 * `computed overflowY === 'auto'`) — yani iç kap kendi başına bir kaydırma
 * bağlamı oluyor, ama yüksekliği sınırsız olduğundan hiç kaymıyor ve
 * başlık modalın gövdesiyle birlikte yukarı kayıp gidiyordu (ölçüldü:
 * modal 600px kaydırılınca başlığın `top`u −538). Kaba yükseklik sınırı +
 * `overflow-y` verilince başlık kabın üstüne yapışıyor (ölçüldü: başlığın
 * `top`u = kabın `top`u).
 *
 * Z-SIRASI ÜÇ KATMANLI: gövdedeki sabit isim hücresi `z-[1]`, başlık
 * hücreleri `z-[2]`, ikisi birden sabit olan BAŞLIK İSİM hücresi `z-[3]` —
 * aksi halde yana kaydırırken başlığın ismi diğer başlıkların altında
 * kalırdı.
 */
const STICKY_HEAD_CELL = 'sticky top-0 z-[2] bg-panel';
const STICKY_HEAD_NAME_CELL = `${STICKY_NAME_CELL} sticky top-0 z-[3]`;

/**
 * Geri Bildirim ve Şikayetler kartlarının başlığı — İKİ SATIR, tek satır DEĞİL
 * (23 Ağustos 2026, kullanıcı bildirdi: *"Görüş bildirim'de gelen mesajlarda
 * gönderenin ismi görünmüyor. Onu tam açık görmek lazım her durumda."*).
 *
 * Öncesinde ad/e-posta ile rozetler ve tarih AYNI satırdaydı: ad
 * `truncate min-w-0 flex-1`, rozetler ve tarih `shrink-0`. Yani satır
 * daraldıkça KIRPILAN tek şey addı — telefonda "Ser…" / "Ebr…" /
 * "kelimekitest4@sh…" kalıyordu. Bir gelen kutusunda kırpılacak EN SON şey
 * kimden geldiğidir: mesaj metni zaten kapalı kartta bilerek kırpılıyor
 * (açınca tamamı görünüyor), ama gönderenin kim olduğu hiçbir yerde
 * açılmıyordu.
 *
 * Ad artık KENDİ satırında ve `break-words` ile sarıyor (uzun bir e-posta
 * adresi boşluksuz olduğundan `break-words` şart, `truncate` yok); rozetler
 * ve tarih alttaki satırda, tarih `ml-auto` ile sağ uçta. Kart bir satır
 * (~14px) uzuyor — bilinçli takas.
 *
 * **Tek satırlık esnek bir çözüm DENENDİ ve ELENDİ:** `flex-wrap` + adın
 * `min-w-0` olması, flexbox'ın rozetleri alt satıra İTMESİ yerine adı bir
 * karaktere kadar DARALTIP dikey sarmasına yol açıyor (sarma kararı öğe
 * bazında ve esnek öğe önce yerleşiyor); ada `min-w-[…]` vermek ise rozet
 * grubunun kendisi kaba sığmadığında taşıyor. İki satır deterministik.
 *
 * Üyeler tablosundaki `STICKY_NAME_CELL` BİLEREK dokunulmadı — orası kapaklı
 * bir sabit kolon ve gerekçesi yukarıda ölçümle yazılı (bugünkü en uzun ad
 * 18 karakter/~131px, yani kırpılmıyor; uç durumda tam hâli `title`da).
 */
const CARD_HEADER = 'flex flex-col gap-1 text-[10px] font-mono text-muted';
const CARD_HEADER_NAME = 'break-words';
const CARD_HEADER_META = 'flex flex-wrap items-center gap-1.5';

/**
 * Cinsiyet etiketi. Kaynak `GENDER_OPTIONS` (kayıt formu ve Hesap Ayarları
 * ile AYNI liste) — ikinci bir eşleme yazmak, seçenekler değişince sessizce
 * ayrışırdı. `'unspecified'` formda seçilebilir DEĞİL ama şema kabul
 * ediyor, o yüzden ayrıca karşılanıyor: listede bulunamadığı için `BOS`a
 * düşseydi "hiç girmemiş" ile karışırdı.
 */
function memberGenderLabel(m: AdminMember) {
  if (!m.gender) return BOS;
  if (m.gender === 'unspecified') return 'Belirtilmemiş';
  return GENDER_OPTIONS.find((o) => o.value === m.gender)?.label ?? BOS;
}

/** Sadece TARİH (saat yok) — doğum tarihi için `fmtDate` fazla bilgi. */
function memberBirthDateLabel(m: AdminMember) {
  return isoToTrDate(m.birth_date).replace(/\//g, '.') || BOS;
}

/**
 * İzin/tercih hücresi. Onay verilmiş olan yeşil, verilmemiş olan nötr —
 * kırmızı BİLEREK kullanılmıyor: "pazarlama iznini vermemiş" bir hata ya da
 * uyarı değil, kullanıcının meşru tercihi (kırmızı bu panelde "Donduruldu"
 * gibi gerçek bir sorun demek).
 */
function ConsentCell({ on, onLabel = 'Evet', offLabel = 'Hayır' }: {
  on: boolean;
  onLabel?: string;
  offLabel?: string;
}) {
  return on ? (
    <span className="text-green font-bold">{onLabel}</span>
  ) : (
    <span className="text-muted">{offLabel}</span>
  );
}

/** `banned_until` gelecekte bir tarihse hesap şu an devre dışıdır. */
function isBanned(bannedUntil: string | null | undefined): boolean {
  return !!bannedUntil && new Date(bannedUntil).getTime() > Date.now();
}

function memberSortValue(m: AdminMember, key: MemberSortKey): string | number {
  switch (key) {
    case 'name':
      return trLower(memberName(m));
    case 'nickname':
      return trLower(memberNickname(m));
    case 'email':
      return trLower(m.email ?? '');
    case 'created_at':
      return m.created_at ? new Date(m.created_at).getTime() : 0;
    case 'last_sign_in_at':
      return m.last_sign_in_at ? new Date(m.last_sign_in_at).getTime() : 0;
    case 'is_admin':
      return m.is_admin ? 1 : 0;
    case 'signup_channel':
      return trLower(memberChannelLabel(m));
  }
}

export function AdminDashboard({ onClose }: AdminDashboardProps) {
  const [tab, setTab] = useState<Tab>('growth');
  const [members, setMembers] = useState<AdminMember[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selectedMember, setSelectedMember] = useState<AdminMember | null>(null);
  const [growthSubTab, setGrowthSubTab] = useState<GrowthSubTab>('user');
  const [userActivity, setUserActivity] = useState<AdminUserActivityPoint[] | null>(null);
  const [userGranularity, setUserGranularity] = useState<AdminActivityGranularity>('day');
  const [userPeriod, setUserPeriod] = useState<number>(30);
  const [sourceFunnel, setSourceFunnel] = useState<AdminSourceFunnelRow[] | null>(null);
  const [deviceBreakdown, setDeviceBreakdown] = useState<AdminDeviceBreakdownRow[] | null>(null);
  const [appVersions, setAppVersions] = useState<AdminAppVersionRow[] | null>(null);
  const [pushVersions, setPushVersions] = useState<AdminPushVersionRow[] | null>(null);
  const [friendActivity, setFriendActivity] = useState<AdminFriendActivityPoint[] | null>(null);
  const [activePlayers, setActivePlayers] = useState<AdminActivePlayersPoint[] | null>(null);
  const [retention, setRetention] = useState<AdminRetentionCell[] | null>(null);
  const [activation, setActivation] = useState<AdminActivationStats | null>(null);
  const [friendTotals, setFriendTotals] = useState<AdminFriendTotals | null>(null);
  const [gameActivity, setGameActivity] = useState<AdminGameActivityPoint[] | null>(null);
  const [gameGranularity, setGameGranularity] = useState<AdminActivityGranularity>('day');
  const [gamePeriod, setGamePeriod] = useState<number>(30);
  const [gameScope, setGameScope] = useState<AdminGameScope>('total');
  const [gameSource, setGameSource] = useState<AdminGameSourceType>('total');
  const [gamePlayerCount, setGamePlayerCount] = useState<GameSubTab>('total');
  const [engagementActivity, setEngagementActivity] = useState<AdminEngagementActivityPoint[] | null>(null);
  const [engagementTotals, setEngagementTotals] = useState<AdminEngagementTotals | null>(null);
  const [aiBalance, setAiBalance] = useState<AdminAiBalanceRow[] | null>(null);
  const [memberSearch, setMemberSearch] = useState('');
  const [sortKey, setSortKey] = useState<MemberSortKey>('created_at');
  const [sortDir, setSortDir] = useState<SortDir>('desc');
  const [feedback, setFeedback] = useState<AdminFeedbackRow[] | null>(null);
  // destek@ kutusuna gelen ve henüz haber verilmemiş cevap sayısı — "Zoho"
  // rozetinin kaynağı. `null` = henüz yüklenmedi (rozet çizilmez).
  const [supportUnseen, setSupportUnseen] = useState<number | null>(null);
  const [feedbackOriginFilter, setFeedbackOriginFilter] = useState<'all' | 'user' | 'admin'>('all');
  const [feedbackToDelete, setFeedbackToDelete] = useState<AdminFeedbackRow | null>(null);
  const [messageTarget, setMessageTarget] = useState<AdminMember | null>(null);
  const [expandedFeedbackId, setExpandedFeedbackId] = useState<string | null>(null);
  const [replyDrafts, setReplyDrafts] = useState<Record<string, string>>({});
  const [replyOpenId, setReplyOpenId] = useState<string | null>(null);
  const [replySendingId, setReplySendingId] = useState<string | null>(null);
  const [replyError, setReplyError] = useState<string | null>(null);
  const [feedbackSubTab, setFeedbackSubTab] = useState<FeedbackSubTab>('inbox');
  const [chatReports, setChatReports] = useState<AdminChatReportRow[] | null>(null);
  const [clientErrors, setClientErrors] = useState<AdminClientErrorRow[] | null>(null);
  /**
   * "Hatalar" penceresi — kaç günlük. Büyüme'nin periyot kontrollerinden
   * BİLEREK bağımsız: orada soru "zaman içinde nasıl gidiyor", burada "şu an
   * bakılması gereken ne var" ve gruplama zaten zamanı düzleştiriyor.
   */
  const [errorDays, setErrorDays] = useState(7);
  const [expandedErrorKey, setExpandedErrorKey] = useState<string | null>(null);
  const [expandedReportId, setExpandedReportId] = useState<string | null>(null);
  const [transcriptGameId, setTranscriptGameId] = useState<string | null>(null);
  const [banTarget, setBanTarget] = useState<{ id: string; name: string; banned: boolean } | null>(null);
  /** Açık metrik tanımı popup'ı (`?` rozetleri) — tek state, tek dialog. */
  const [hint, setHint] = useState<HintId | null>(null);
  const [banBusy, setBanBusy] = useState(false);
  const [banError, setBanError] = useState<string | null>(null);
  const [highlightedMemberId, setHighlightedMemberId] = useState<string | null>(null);

  const panelRef = useModalA11y(true, onClose);
  const feedbackDeleteRef = useModalA11y(!!feedbackToDelete, () => setFeedbackToDelete(null));
  const banConfirmRef = useModalA11y(!!banTarget, () => setBanTarget(null));
  const hintRef = useModalA11y(!!hint, () => setHint(null));

  useEffect(() => {
    if (tab !== 'members' || !highlightedMemberId) return;
    const el = document.getElementById(`admin-member-row-${highlightedMemberId}`);
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    const timer = setTimeout(() => setHighlightedMemberId(null), 2500);
    return () => clearTimeout(timer);
  }, [tab, highlightedMemberId]);

  // Hata dökümü kendi penceresine (`errorDays`) bağlı, o yüzden ayrı bir
  // effect. Panel açılır açılmaz çekiliyor — sekmeye girilmesini beklemiyoruz:
  // "Hatalar" sekmesinin kendisi bir rozet taşımadığından (bekleyen İŞ değil,
  // gözlem), admin oraya ancak bir sebep varsa girer ve o zaman veri hazır olur.
  useEffect(() => {
    fetchAdminClientErrors(errorDays)
      .then(setClientErrors)
      .catch((e) => setError(String(e)));
  }, [errorDays]);

  useEffect(() => {
    fetchAdminMembers()
      .then(setMembers)
      .catch((e) => setError(String(e)));
    fetchAdminFeedback()
      .then(setFeedback)
      .catch((e) => setError(String(e)));
    fetchSupportInboxUnseenCount()
      .then(setSupportUnseen)
      .catch((e) => setError(String(e)));
    fetchAdminChatReports()
      .then(setChatReports)
      .catch((e) => setError(String(e)));
    fetchAdminEngagementTotals()
      .then(setEngagementTotals)
      .catch((e) => setError(String(e)));
    // YZ dengesi de retention/aktivasyon gibi periyot kontrollerine bağlı
    // DEĞİL: tüm zamanların dağılımı, "son N gün" penceresiyle anlam
    // değiştirmez (bugünkü hacimde günlük kırılım zaten gürültü olurdu).
    fetchAdminAiBalance()
      .then(setAiBalance)
      .catch((e) => setError(String(e)));
    fetchAdminFriendTotals()
      .then(setFriendTotals)
      .catch((e) => setError(String(e)));
    // Retention/aktivasyon üstteki periyot kontrollerine BİLEREK bağlı değil:
    // kohort tablosunun ekseni kayıt haftası (sabit 8 hafta), aktivasyon ise
    // tüm zamanların oranı — ikisi de "son N gün" penceresiyle anlam değiştirmez.
    fetchAdminRetentionCohorts(8)
      .then(setRetention)
      .catch((e) => setError(String(e)));
    fetchAdminActivationStats()
      .then(setActivation)
      .catch((e) => setError(String(e)));
  }, []);

  // Varsayılan tab: bekleyen iş varsa "Geri Bildirim" açık gelsin — panel
  // baştan beri "Büyüme" ile açılıyordu, yani okunmamış bir geri bildirim/
  // şikayet varken bile admin'i önce grafiklere düşürüyordu (kullanıcı
  // isteği, 4 Ağustos 2026). `LiveGamesTab` (bekleyen davet varsa "Oyun
  // Davetleri") ve `FriendsModal` (bekleyen istek varsa "İstekler") ile
  // BİREBİR aynı desen ve gerekçe: bekleyen iş her zaman ön plana çıkmalı.
  //
  // Alt sekme de aynı mantığı izliyor: gelen kutusunda bekleyen yoksa ama
  // şikayet varsa doğrudan "Şikayetler" açılır — aksi halde admin, rozeti
  // gördüğü hâlde boş bir "Gelen Kutusu" ile karşılaşırdı.
  //
  // Yalnızca İKİ liste de yüklendikten sonra bir kez uygulanır; elle sekme
  // seçildiği anda devre dışı kalır (aşağıdaki `selectTab`).
  const appliedDefaultTabRef = useRef(false);
  /**
   * Elle sekme seçimi — varsayılan-sekme effect'ini (aşağı) devre dışı
   * bırakır. Veri henüz yüklenmemişken bir sekmeye dokunulursa listeler
   * gelince effect seçimi ezerdi (`LiveGamesTab`/`FriendsModal`'daki aynı guard).
   */
  const selectTab = (next: Tab) => {
    appliedDefaultTabRef.current = true;
    setTab(next);
  };
  useEffect(() => {
    if (feedback === null || chatReports === null || appliedDefaultTabRef.current) return;
    appliedDefaultTabRef.current = true;
    const pendingFeedback = feedback.filter((f) => !f.handled).length;
    const pendingReports = chatReports.filter((r) => !r.handled).length;
    if (pendingFeedback + pendingReports === 0) return;
    setTab('feedback');
    if (pendingFeedback === 0) setFeedbackSubTab('flags');
  }, [feedback, chatReports]);

  // Not: period/granülerlik değişince önceki veriyi `null`'a çekip
  // "Yükleniyor…" göstermiyoruz — bu, o anda ekranda kaç grafik/tablo varsa
  // hepsini aynı anda küçük bir yer tutucuya küçültüp scroll konumunu (ör.
  // en alttaki Arkadaşlık bölümünü) kaybettiriyordu (kullanıcı geri bildirimi,
  // 27 Temmuz 2026). Yeni veri gelene kadar eski veri ekranda kalıp üzerine
  // yazılıyor — düzen boyutu sabit kaldığından scroll konumu korunuyor.
  // Beşi de aynı [userPeriod, userGranularity] bağımlılığına sahipti — ayrı
  // useEffect'ler yerine tek bir Promise.all'a birleştirildi (davranış aynı:
  // her biri kendi setX'ini bağımsız çağırır, biri reddederse diğerleri yine
  // de sonuçlanır, tek bir setError yeterli).
  useEffect(() => {
    const days = userPeriod * GRANULARITY_TO_DAYS[userGranularity];
    Promise.all([
      fetchAdminUserActivitySeries(userPeriod, userGranularity).then(setUserActivity),
      fetchAdminSourceFunnel(days).then(setSourceFunnel),
      fetchAdminDeviceBreakdown(days).then(setDeviceBreakdown),
      fetchAdminAppVersionBreakdown(days).then(setAppVersions),
      fetchAdminPushVersionBreakdown(days).then(setPushVersions),
      fetchAdminFriendActivitySeries(userPeriod, userGranularity).then(setFriendActivity),
      fetchAdminActivePlayersSeries(userPeriod, userGranularity).then(setActivePlayers),
    ]).catch((e) => setError(String(e)));
  }, [userPeriod, userGranularity]);

  useEffect(() => {
    fetchAdminGameActivitySeries(
      gamePeriod,
      gameGranularity,
      gameScope,
      gamePlayerCount === 'total' ? null : gamePlayerCount,
      gameSource,
    )
      .then(setGameActivity)
      .catch((e) => setError(String(e)));
  }, [gamePeriod, gameGranularity, gameScope, gamePlayerCount, gameSource]);

  useEffect(() => {
    fetchAdminEngagementActivitySeries(gamePeriod, gameGranularity)
      .then(setEngagementActivity)
      .catch((e) => setError(String(e)));
  }, [gamePeriod, gameGranularity]);

  function selectUserGranularity(g: AdminActivityGranularity) {
    setUserGranularity(g);
    setUserPeriod(PERIOD_OPTIONS[g][1]);
  }

  function selectGameGranularity(g: AdminActivityGranularity) {
    setGameGranularity(g);
    setGamePeriod(PERIOD_OPTIONS[g][1]);
  }

  // Canlı oyunlarda misafir kavramı yok (tüm katılımcılar girişli) — Canlı
  // seçilince Kayıtlı/Misafir kombosu tek seçeneğe ("Kayıtlı") düşüyor,
  // scope'u da buna göre sabitliyoruz.
  function selectGameSource(s: AdminGameSourceType) {
    setGameSource(s);
    if (s === 'online') setGameScope('registered');
  }

  // Aynı kısıtın TERSİ (16 Ağustos 2026, kullanıcı fark etti): kilit uzun
  // süre tek yönlüydü — Misafir seçiliyken kaynak kombosu hâlâ "Canlı"yı
  // gösteriyordu ve seçilince scope SESSİZCE "Kayıtlı"ya atlıyordu, yani
  // kullanıcının az önce seçtiği filtre habersizce değişiyordu. Misafir bir
  // Canlı oyun olamayacağından o kombinasyon zaten her zaman 0 satır döner.
  function selectGameScope(s: AdminGameScope) {
    setGameScope(s);
    if (s === 'guest') setGameSource('local');
  }

  function toggleSort(key: MemberSortKey) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  }

  const filteredMembers = useMemo(() => {
    if (!members) return null;
    const q = trLower(memberSearch.trim());
    const filtered = q
      ? members.filter(
          (m) => trLower(memberName(m)).includes(q) || trLower(memberNickname(m)).includes(q),
        )
      : members;
    return [...filtered].sort((a, b) => {
      const av = memberSortValue(a, sortKey);
      const bv = memberSortValue(b, sortKey);
      const cmp =
        typeof av === 'string' ? av.localeCompare(bv as string, 'tr') : (av as number) - (bv as number);
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }, [members, memberSearch, sortKey, sortDir]);

  function SortHeader({ label, sortKeyFor, className }: { label: string; sortKeyFor: MemberSortKey; className?: string }) {
    const active = sortKey === sortKeyFor;
    return (
      <th
        onClick={() => toggleSort(sortKeyFor)}
        className={`py-2 pr-3 font-bold cursor-pointer select-none hover:text-text transition-colors ${STICKY_HEAD_CELL} ${className ?? ''}`}
      >
        <span className="inline-flex items-center gap-1">
          {label}
          <span className={active ? 'text-accent' : 'text-border'}>{active && sortDir === 'desc' ? '▼' : '▲'}</span>
        </span>
      </th>
    );
  }

  // `relative`, sekmenin sağ üst köşesine oturan `CountBadge` için gerekli —
  // bekleyen iş sayısı artık başlığa " (N)" olarak gömülmüyor, Setup/
  // LiveGamesTab/FriendsModal sekmelerindeki kırmızı yuvarlak rozetin
  // aynısıyla gösteriliyor (kullanıcı isteği: "bu bir standart, her yerde
  // öyle olmalı", 3 Ağustos 2026).
  /**
   * Rozete tıklanınca sayaç sıfırlanır. Link'in kendisi `href`/`target` ile
   * çalışmaya devam ediyor (preventDefault YOK) — orta tık/yeni sekmede aç
   * gibi tarayıcı davranışları korunsun diye.
   *
   * İşaretleme başarısız olursa link yine de açılır; sayaç bir sonraki
   * yüklemede geri gelir. Bilerek: admin'i Zoho'ya götürmek, sayacı
   * güncellemekten önemli.
   */
  const handleZohoClick = () => {
    setSupportUnseen(0);
    markSupportInboxSeen().catch((e) => setError(String(e)));
  };

  const tabBtn = (active: boolean) =>
    `relative flex-1 py-2.5 px-3 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1px] transition-colors ${
      active ? 'bg-accent text-white' : 'bg-panel text-muted border border-border'
    }`;

  /**
   * Üyeler CSV'si — ekrandaki tabloyla AYNI kolonlar, AYNI sırada. İkisi
   * ayrışırsa "CSV ekranda görüneni indirir" sözü (bkz. `?` popup'ı) yalan
   * olur; yeni bir kolon eklenirse buraya da eklenmeli.
   *
   * CSV'de boş hücre `BOS` (—) DEĞİL gerçekten boş: bir tablo hücresinde
   * tire okunabilirlik içindir, elektronik tabloda ise sahte bir değer olur
   * (filtre/sıralama onu veri sanır).
   */
  function exportMembersCsv() {
    if (!filteredMembers || filteredMembers.length === 0) return;
    downloadCsv(
      csvFilename('kelimeki-uyeler'),
      [
        'Ad', 'Soyad', 'Nickname', 'E-posta', 'Cinsiyet', 'Doğum Tarihi',
        'Fotoğraf', 'Koşullar Onayı', 'Pazarlama Onayı', 'Pazarlama Onay Tarihi',
        'E-posta Bildirimi', 'Kanal', 'Kaynak', 'Davet Eden', 'Katılma',
        'Son Giriş', 'Rol', 'Durum',
      ],
      filteredMembers.map((m) => [
        m.first_name ?? '',
        m.last_name ?? '',
        m.display_name ?? '',
        m.email ?? '',
        m.gender ? memberGenderLabel(m) : '',
        m.birth_date ? memberBirthDateLabel(m) : '',
        m.avatar_url ? 'Var' : '',
        m.agreed_to_terms ? 'Evet' : 'Hayır',
        m.marketing_consent ? 'Evet' : 'Hayır',
        m.marketing_consent_at ? fmtDate(m.marketing_consent_at) : '',
        m.email_notifications_enabled ? 'Açık' : 'Kapalı',
        memberChannelLabel(m),
        m.signup_utm_source ?? '',
        m.invited_by_name ?? '',
        fmtDate(m.created_at),
        m.last_sign_in_at ? fmtDate(m.last_sign_in_at) : '',
        m.is_admin ? 'Admin' : 'Üye',
        isBanned(m.banned_until) ? 'Donduruldu' : 'Aktif',
      ]),
    );
  }

  // Sekme rozetlerini besleyen iki sayaç. Filtreler `fetchAdminPendingCount`
  // (UserMenu'deki "Admin Paneli" rozeti) ile BİREBİR aynı olmalı — oradaki
  // toplam, buradaki iki sayının toplamıdır.
  const unhandledFeedbackCount = feedback?.filter((f) => !f.handled).length ?? 0;
  const unhandledChatReportCount = chatReports?.filter((r) => !r.handled).length ?? 0;
  const filteredFeedback = useMemo(
    () =>
      feedbackOriginFilter === 'all'
        ? feedback
        : feedback?.filter((f) => f.origin === feedbackOriginFilter) ?? null,
    [feedback, feedbackOriginFilter],
  );

  /**
   * "YZ Dengesi" kutuları. Satır başına bir kutu DEĞİL: 4 kişilik oyunlar
   * ikinci bir "İkincilik" kutusu daha üretiyor (17 Ağustos 2026, kullanıcı
   * isteği) — 4 kişilikte k-lig ikinciliğe de puan verdiğinden yalnız
   * birinciliğe bakmak "insan puan alıyor mu" sorusunun yarısını ölçüyordu.
   *
   * İkincilik kutusu 2 kişilikte BİLEREK YOK: orada rank=2 kaybetmenin
   * kendisi (canlıda ölçüldü: second_places === losses) ve k-lig puanı
   * getirmiyor, yani kutu yeni bir şey söylemeyip kayıp oranını ikinci kez
   * yazardı.
   *
   * Rastgele referansı iki kutuda da `100 / oyuncu sayısı`: rastgele bir
   * sonuçta 1. olma da 2. olma da aynı olasılıkta (4 kişilikte %25).
   */
  const aiBalanceCards = useMemo(() => {
    const cards: { key: string; rate: number | null; label: string; detail: string }[] = [];
    for (const r of aiBalance ?? []) {
      const baseline = Math.round(100 / r.players);
      cards.push({
        key: `${r.players}-first`,
        rate: r.games > 0 ? Math.round((100 * r.wins) / r.games) : null,
        label: `${r.players} Kişilik — İnsan Birincilik`,
        detail: `${r.wins}G / ${r.ties}B / ${r.losses}M · rastgele %${baseline}`,
      });
      if (r.players > 2) {
        cards.push({
          key: `${r.players}-second`,
          rate: r.games > 0 ? Math.round((100 * r.second_places) / r.games) : null,
          label: `${r.players} Kişilik — İnsan İkincilik`,
          detail: `${r.second_places}/${r.games} · rastgele %${baseline}`,
        });
      }
    }
    return cards;
  }, [aiBalance]);

  function exportFeedbackCsv() {
    if (!filteredFeedback || filteredFeedback.length === 0) return;
    downloadCsv(
      csvFilename('kelimeki-geri-bildirim'),
      ['Gönderen', 'E-posta', 'Kaynak', 'Tarih', 'Okundu', 'Mesaj', 'Yanıt'],
      filteredFeedback.map((f) => {
        const sender = f.user_id ? members?.find((m) => m.id === f.user_id) : null;
        return [
          sender ? memberName(sender) : f.email || 'Anonim',
          f.email ?? '',
          f.origin === 'admin' ? 'Gönderilen' : f.source === 'game_end' ? 'Oyun Sonu' : 'Genel',
          fmtDate(f.created_at),
          f.handled ? 'Evet' : 'Hayır',
          f.message,
          f.reply ?? '',
        ];
      }),
    );
  }

  /**
   * Hata dökümü CSV'si — ekranda görünen gruplanmış satırların AYNISI, artı
   * `sample_stack` (tabloda yalnızca kart açılınca görünüyor, ama bir hatayı
   * dışarı taşırken en çok gereken alan o).
   */
  function exportClientErrorsCsv() {
    if (!clientErrors || clientErrors.length === 0) return;
    downloadCsv(
      csvFilename('kelimeki-hatalar'),
      ['Tür', 'Mesaj', 'Kez', 'Cihaz', 'Platform', 'Derleme', 'Yol', 'İlk', 'Son', 'Yığın'],
      clientErrors.map((e) => [
        errorKindLabel(e.kind),
        e.message,
        e.occurrences,
        e.devices,
        e.platforms,
        e.builds,
        e.routes,
        fmtDate(e.first_seen),
        fmtDate(e.last_seen),
        e.sample_stack ?? '',
      ]),
    );
  }

  function toggleFeedbackHandled(f: AdminFeedbackRow) {
    const next = !f.handled;
    setFeedback((prev) => prev?.map((x) => (x.id === f.id ? { ...x, handled: next } : x)) ?? prev);
    void markFeedbackHandled(f.id, next).then((ok) => {
      if (!ok) {
        // Sunucu güncellemesi başarısız oldu — iyimser güncellemeyi geri al.
        setFeedback((prev) => prev?.map((x) => (x.id === f.id ? { ...x, handled: f.handled } : x)) ?? prev);
      }
    });
  }

  function confirmRemoveFeedback() {
    const f = feedbackToDelete;
    if (!f) return;
    setFeedbackToDelete(null);
    setFeedback((prev) => prev?.filter((x) => x.id !== f.id) ?? prev);
    deleteFeedback(f.id).catch((e) => {
      setError(String(e));
      // Silme başarısız oldu — kayıt listeden yanlışlıkla kaybolmuş olmasın.
      setFeedback((prev) => (prev ? [...prev, f].sort((a, b) => b.created_at.localeCompare(a.created_at)) : prev));
    });
  }

  async function confirmSetUserBanned() {
    const target = banTarget;
    if (!target) return;
    setBanBusy(true);
    setBanError(null);
    try {
      await setUserBanned(target.id, target.banned);
      setMembers((prev) =>
        prev?.map((m) =>
          m.id === target.id
            ? { ...m, banned_until: target.banned ? new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 100).toISOString() : null }
            : m,
        ) ?? prev,
      );
      setBanTarget(null);
    } catch (e) {
      setBanError(e instanceof Error ? e.message : String(e));
    } finally {
      setBanBusy(false);
    }
  }

  async function submitFeedbackReply(f: AdminFeedbackRow) {
    const reply = (replyDrafts[f.id] ?? '').trim();
    if (!reply) return;
    setReplyError(null);
    setReplySendingId(f.id);
    try {
      const sender = f.user_id ? members?.find((m) => m.id === f.user_id) : null;
      const recipientName = sender?.display_name || sender?.first_name || undefined;
      await sendFeedbackReply(f.id, reply, recipientName);
      setFeedback(
        (prev) =>
          prev?.map((x) =>
            x.id === f.id
              ? { ...x, reply, replied_at: new Date().toISOString() }
              : x,
          ) ?? prev,
      );
      setReplyDrafts((prev) => {
        const next = { ...prev };
        delete next[f.id];
        return next;
      });
      setReplyOpenId(null);
    } catch (e) {
      setReplyError(e instanceof Error ? e.message : String(e));
    } finally {
      setReplySendingId(null);
    }
  }

  return createPortal(
    <div
      className="fixed inset-0 z-[150] flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label="Admin Paneli"
        tabIndex={-1}
        className="w-full max-w-[640px] bg-panel border border-[#B8C2D1] rounded-xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] max-h-[85vh] flex flex-col overflow-hidden outline-none"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="shrink-0 flex flex-col gap-3 px-5 pt-5 pb-4 border-b border-border">
          <div className="flex items-center justify-between">
            <h2 className="font-mono text-sm font-bold tracking-[1.5px] uppercase text-accent">
              Admin Paneli
            </h2>
            <button
              onClick={onClose}
              aria-label="Kapat"
              className="text-muted hover:text-text text-lg leading-none tap-expand w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
            >
              ✕
            </button>
          </div>
          {/* ÖLÇÜLDÜ (derlenmiş CSS + Chromium): dördüncü sekme ("Hatalar")
              eklenince tek sıra 320px'te kabı 77px, 390px'te 7px AŞIYOR ve
              `overflow-hidden` bunu SESSİZCE kırpıyordu — `flex-1` sekmeyi
              `min-width:auto` yüzünden en uzun kelimesinin (BİLDİRİM) altına
              indiremiyor. Negatif eş: dördüncü buton kaldırılınca üç genişlikte
              de taşma 0. Bu yüzden dar ekranda 2×2 ızgara, tek sıraya ancak
              dört etiketin de TEK SATIRDA sığdığı genişlikten (≥580px; eşik
              "GERİ BİLDİRİM"in max-content'i olan ~120px'ten türetildi, dördü
              + boşluklar ≈ 498px) itibaren geçiliyor — daha erken geçmek
              etiketleri iki satıra bölüp başlığı yükseltiyordu. */}
          <div className="grid grid-cols-2 min-[580px]:grid-cols-4 gap-1.5">
            <button className={tabBtn(tab === 'members')} onClick={() => selectTab('members')}>
              Üyeler
            </button>
            <button className={tabBtn(tab === 'growth')} onClick={() => selectTab('growth')}>
              Büyüme
            </button>
            <button className={tabBtn(tab === 'feedback')} onClick={() => selectTab('feedback')}>
              Geri Bildirim
              {unhandledFeedbackCount + unhandledChatReportCount > 0 && (
                <CountBadge
                  count={unhandledFeedbackCount + unhandledChatReportCount}
                  className="absolute -top-1 -right-1"
                />
              )}
            </button>
            {/* Rozet YOK ve bu bilinçli: `CountBadge` bu projede "bekleyen İŞ"
                demek (bkz. CLAUDE.md → CountBadge). Bir hata kaydı admin'in
                yapması gereken bir kuyruk maddesi değil, bir gözlem — sayaç
                koymak rozet dilini sulandırırdı. */}
            <button className={tabBtn(tab === 'errors')} onClick={() => selectTab('errors')}>
              Hatalar
            </button>
          </div>

          {tab === 'growth' && (
            <div className="flex flex-col gap-2">
              <div className="flex gap-1.5">
                <button className={tabBtn(growthSubTab === 'user')} onClick={() => setGrowthSubTab('user')}>
                  Kullanıcı
                </button>
                <button className={tabBtn(growthSubTab === 'game')} onClick={() => setGrowthSubTab('game')}>
                  Oyun
                </button>
              </div>

              {growthSubTab === 'user' && (
                <div className="flex items-center flex-wrap gap-2">
                  <AdminSelect
                    value={userGranularity}
                    onChange={(v) => selectUserGranularity(v as AdminActivityGranularity)}
                    options={[
                      { value: 'day', label: 'Günlük' },
                      { value: 'week', label: 'Haftalık' },
                      { value: 'month', label: 'Aylık' },
                      { value: 'year', label: 'Yıllık' },
                    ]}
                  />
                  <AdminSelect
                    value={String(userPeriod)}
                    onChange={(v) => setUserPeriod(Number(v))}
                    options={PERIOD_OPTIONS[userGranularity].map((p) => ({
                      value: String(p),
                      label: `Son ${p} ${PERIOD_UNIT_LABEL[userGranularity]}`,
                    }))}
                  />
                </div>
              )}

              {growthSubTab === 'game' && (
                <div className="flex items-center flex-wrap gap-2">
                  <AdminSelect
                    value={gameSource}
                    onChange={(v) => selectGameSource(v as AdminGameSourceType)}
                    disabled={gameScope === 'guest'}
                    options={
                      gameScope === 'guest'
                        ? [{ value: 'local', label: 'Yapay Zeka' }]
                        : [
                            { value: 'total', label: 'Toplam' },
                            { value: 'online', label: 'Canlı' },
                            { value: 'local', label: 'Yapay Zeka' },
                          ]
                    }
                  />
                  <AdminSelect
                    value={gameScope}
                    onChange={(v) => selectGameScope(v as AdminGameScope)}
                    disabled={gameSource === 'online'}
                    options={
                      gameSource === 'online'
                        ? [{ value: 'registered', label: 'Kayıtlı' }]
                        : [
                            { value: 'total', label: 'Toplam' },
                            { value: 'registered', label: 'Kayıtlı' },
                            { value: 'guest', label: 'Misafir' },
                          ]
                    }
                  />
                  <AdminSelect
                    value={String(gamePlayerCount)}
                    onChange={(v) => setGamePlayerCount(v === 'total' ? 'total' : (Number(v) as 2 | 4))}
                    options={[
                      { value: 'total', label: 'Toplam' },
                      { value: '2', label: '2 Kişilik' },
                      { value: '4', label: '4 Kişilik' },
                    ]}
                  />
                  <AdminSelect
                    value={gameGranularity}
                    onChange={(v) => selectGameGranularity(v as AdminActivityGranularity)}
                    options={[
                      { value: 'day', label: 'Günlük' },
                      { value: 'week', label: 'Haftalık' },
                      { value: 'month', label: 'Aylık' },
                      { value: 'year', label: 'Yıllık' },
                    ]}
                  />
                  <AdminSelect
                    value={String(gamePeriod)}
                    onChange={(v) => setGamePeriod(Number(v))}
                    options={PERIOD_OPTIONS[gameGranularity].map((p) => ({
                      value: String(p),
                      label: `Son ${p} ${PERIOD_UNIT_LABEL[gameGranularity]}`,
                    }))}
                  />
                </div>
              )}
            </div>
          )}

          {/* Geri Bildirim'in alt sekmeleri + filtre satırı, Büyüme'dekiyle
              AYNI şekilde kaydırma kabının DIŞINDA (sabit başlık bölgesinde)
              duruyor — uzun bir listede aşağı inince filtreler gözden
              kaybolmasın diye (kullanıcı isteği, 15 Ağustos 2026). */}
          {tab === 'feedback' && (
            <div className="flex flex-col gap-2">
              <div className="flex gap-1.5">
                <button className={tabBtn(feedbackSubTab === 'inbox')} onClick={() => setFeedbackSubTab('inbox')}>
                  Gelen Kutusu
                  {unhandledFeedbackCount > 0 && (
                    <CountBadge count={unhandledFeedbackCount} className="absolute -top-1 -right-1" />
                  )}
                </button>
                <button className={tabBtn(feedbackSubTab === 'flags')} onClick={() => setFeedbackSubTab('flags')}>
                  Şikayetler
                  {unhandledChatReportCount > 0 && (
                    <CountBadge count={unhandledChatReportCount} className="absolute -top-1 -right-1" />
                  )}
                </button>
                {/* "Zoho" bir SEKME DEĞİL, dışarı çıkan bir link — bu yüzden
                    `tabBtn` kullanmıyor (aktif hâli yok) ve `flex-1` almıyor:
                    yanındaki iki gerçek sekme daralsın ama bu küçük kalsın
                    (kullanıcı isteği, 25 Ağustos 2026).

                    Rozet burada da "bekleyen İŞ" demek (bkz. CLAUDE.md →
                    CountBadge): destek@ kutusuna admin'in haberi olmadığı bir
                    cevap düşmüş. Tıklama iki şey yapar — sayacı sıfırlar ve
                    Zoho'yu açar; mailin kendisi panelde OKUNMAZ, orada okunur. */}
                <a
                  href={ZOHO_INBOX_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  title="destek@kelimeki.com gelen kutusunu Zoho'da aç"
                  onClick={handleZohoClick}
                  className="relative shrink-0 flex items-center py-2.5 px-3 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1px] bg-panel text-muted border border-border hover:text-text transition-colors"
                >
                  Zoho
                  {!!supportUnseen && (
                    <CountBadge count={supportUnseen} className="absolute -top-1 -right-1" />
                  )}
                </a>
              </div>

              {feedbackSubTab === 'inbox' && (
                <div className="flex items-center justify-between gap-2 flex-wrap">
                  <div className="flex gap-1.5">
                    <button className={tabBtn(feedbackOriginFilter === 'all')} onClick={() => setFeedbackOriginFilter('all')}>
                      Tümü
                    </button>
                    <button className={tabBtn(feedbackOriginFilter === 'user')} onClick={() => setFeedbackOriginFilter('user')}>
                      Gelen
                    </button>
                    <button className={tabBtn(feedbackOriginFilter === 'admin')} onClick={() => setFeedbackOriginFilter('admin')}>
                      Gönderilen
                    </button>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    {filteredFeedback && filteredFeedback.length > 0 && (
                      <button type="button" onClick={exportFeedbackCsv} className={csvLinkCls}>
                        CSV İndir
                      </button>
                    )}
                    <InfoHint id="geri-bildirim" onOpen={setHint} />
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Hatalar: pencere seçici + CSV + `?`, aynı gerekçeyle (uzun listede
              kaybolmasın) kaydırma kabının DIŞINDA. */}
          {tab === 'errors' && (
            <div className="flex items-center justify-between gap-2 flex-wrap">
              <AdminSelect
                value={String(errorDays)}
                onChange={(v) => setErrorDays(Number(v))}
                options={[
                  { value: '1', label: 'Son 24 Saat' },
                  { value: '7', label: 'Son 7 Gün' },
                  { value: '30', label: 'Son 30 Gün' },
                  { value: '90', label: 'Son 90 Gün' },
                ]}
              />
              <div className="flex items-center gap-2 shrink-0">
                {clientErrors && clientErrors.length > 0 && (
                  <button type="button" onClick={exportClientErrorsCsv} className={csvLinkCls}>
                    CSV İndir
                  </button>
                )}
                <InfoHint id="hatalar" onOpen={setHint} />
              </div>
            </div>
          )}
        </div>

        <div className="overflow-y-auto min-h-0 px-5 pt-4 pb-5 flex flex-col gap-4">
          {error && <div className="text-xs font-mono text-red">{error}</div>}

          {tab === 'members' && (
            <>
              <input
                type="text"
                value={memberSearch}
                onChange={(e) => setMemberSearch(e.target.value)}
                placeholder="İsim ya da nickname ara…"
                className="w-full bg-bg border border-border rounded-md px-2.5 py-1.5 text-[11px] font-mono text-text outline-none focus:border-accent transition-colors"
              />

              {members === null ? (
                <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
              ) : members.length === 0 ? (
                <div className="text-xs font-mono text-muted text-center py-6">
                  Kayıtlı üye yok.
                </div>
              ) : filteredMembers && filteredMembers.length === 0 ? (
                <div className="text-xs font-mono text-muted text-center py-6">
                  Aramayla eşleşen üye yok.
                </div>
              ) : (
                <div className="overflow-auto max-h-[60vh]">
                  <table className="w-full text-[11px] font-mono border-collapse">
                    <thead>
                      <tr className="text-left text-muted border-b border-border">
                        <SortHeader label="İsim" sortKeyFor="name" className={STICKY_HEAD_NAME_CELL} />
                        <SortHeader label="Nickname" sortKeyFor="nickname" />
                        <SortHeader label="E-posta" sortKeyFor="email" />
                        {/* Kayıt formunun geri kalanı + izinler (21 Ağustos
                            2026, kullanıcı isteği). Sıralama BİLEREK
                            eklenmedi: bu kolonlar tarama/dışa aktarma için,
                            sıralama ölçütü olarak anlamlı değiller ve yedi
                            yeni sıralama anahtarı başlığı gürültüye
                            boğardı. */}
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Cinsiyet</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Doğum</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Fotoğraf</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Koşullar</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Pazarlama</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Pazarlama Tarihi</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>E-posta Bildirimi</th>
                        <SortHeader label="Kanal" sortKeyFor="signup_channel" />
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Kaynak</th>
                        <th className={`py-2 pr-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Davet Eden</th>
                        <SortHeader label="Katılma" sortKeyFor="created_at" />
                        <SortHeader label="Son Giriş" sortKeyFor="last_sign_in_at" />
                        <SortHeader label="Rol" sortKeyFor="is_admin" />
                        <th className={`py-2 pl-3 text-left font-normal ${STICKY_HEAD_CELL}`}>Durum</th>
                        <th className={`py-2 pl-3 text-left font-normal ${STICKY_HEAD_CELL}`}></th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredMembers?.map((m) => {
                        const banned = isBanned(m.banned_until);
                        return (
                        <tr
                          key={m.id}
                          id={`admin-member-row-${m.id}`}
                          onClick={() => setSelectedMember(m)}
                          className={`group border-b border-border/50 cursor-pointer hover:bg-bg/60 active:opacity-70 transition-colors ${
                            highlightedMemberId === m.id ? 'bg-accent/20' : ''
                          }`}
                        >
                          {/* Sabit isim hücresi. Satırın vurgu/hover tonu
                              hücrenin OPAK zemininin üstüne ayrı bir katmanla
                              biniyor — aksi halde sabit hücre `bg-panel`de
                              kalır ve "Kişiye Git →" vurgusu ya da hover tam
                              o hücrede kaybolurdu (satır tonları saydam). */}
                          <td
                            title={memberName(m)}
                            className={`relative py-2 pr-3 text-text whitespace-nowrap ${STICKY_NAME_CELL}`}
                          >
                            <span
                              aria-hidden="true"
                              className={`absolute inset-0 pointer-events-none transition-colors group-hover:bg-bg/60 ${
                                highlightedMemberId === m.id ? 'bg-accent/20' : ''
                              }`}
                            />
                            <span className="relative">{memberName(m)}</span>
                          </td>
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{memberNickname(m)}</td>
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{m.email ?? BOS}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{memberGenderLabel(m)}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{memberBirthDateLabel(m)}</td>
                          <td className="py-2 pr-3 whitespace-nowrap">
                            {/* URL gösterilmiyor: okunmaz ve satırı metrelerce
                                uzatır — sorulan soru "fotoğraf koymuş mu". */}
                            <ConsentCell on={!!m.avatar_url} onLabel="Var" offLabel={BOS} />
                          </td>
                          <td className="py-2 pr-3 whitespace-nowrap">
                            <ConsentCell on={m.agreed_to_terms} />
                          </td>
                          <td className="py-2 pr-3 whitespace-nowrap">
                            <ConsentCell on={m.marketing_consent} />
                          </td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">
                            {fmtDate(m.marketing_consent_at)}
                          </td>
                          <td className="py-2 pr-3 whitespace-nowrap">
                            <ConsentCell
                              on={m.email_notifications_enabled}
                              onLabel="Açık"
                              offLabel="Kapalı"
                            />
                          </td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{memberChannelLabel(m)}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">
                            {m.signup_utm_source ?? BOS}
                          </td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">
                            {m.invited_by_name ?? BOS}
                          </td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{fmtDate(m.created_at)}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{fmtDate(m.last_sign_in_at)}</td>
                          <td className="py-2 pr-3 whitespace-nowrap">
                            {m.is_admin ? (
                              <span className="text-accent font-bold">Admin</span>
                            ) : (
                              <span className="text-muted">Üye</span>
                            )}
                          </td>
                          <td className="py-2 pl-3 whitespace-nowrap">
                            {banned ? (
                              <span className="text-red font-bold">Donduruldu</span>
                            ) : (
                              <span className="text-muted">Aktif</span>
                            )}
                          </td>
                          <td className="py-2 whitespace-nowrap" onClick={(e) => e.stopPropagation()}>
                            <div className="flex items-center gap-2">
                              {m.email ? (
                                <button
                                  onClick={() => setMessageTarget(m)}
                                  className="text-[10px] font-mono text-accent hover:underline"
                                >
                                  Mesaj Gönder
                                </button>
                              ) : (
                                <span className="text-[10px] font-mono text-muted">—</span>
                              )}
                              <button
                                onClick={() => {
                                  setBanError(null);
                                  setBanTarget({ id: m.id, name: memberName(m), banned: !banned });
                                }}
                                className={`text-[10px] font-mono hover:underline ${banned ? 'text-accent' : 'text-red'}`}
                              >
                                {banned ? 'Dondurmayı Kaldır' : 'Hesabı Dondur'}
                              </button>
                            </div>
                          </td>
                        </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2 shrink-0">
                  {filteredMembers && filteredMembers.length > 0 && (
                    <button type="button" onClick={exportMembersCsv} className={csvLinkCls}>
                      CSV İndir
                    </button>
                  )}
                  <InfoHint id="uyeler" onOpen={setHint} />
                </div>
                <div className="text-[10px] font-mono text-muted text-right">
                  {memberSearch.trim() && members
                    ? `${filteredMembers?.length ?? 0} / ${members.length} üye`
                    : `Toplam ${members?.length ?? 0} üye`}
                </div>
              </div>
            </>
          )}

          {tab === 'growth' && (
            <>
              {growthSubTab === 'user' &&
                (userActivity === null ? (
                  <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                ) : (
                  <GrowthChart
                    data={userActivity}
                    granularity={userGranularity}
                    series={USER_SERIES}
                    // İKİSİ de açık gelir (16 Ağustos 2026, kullanıcı isteği):
                    // "yeni üye 0 ama ziyaret var" ilişkisi ancak iki seri
                    // birlikte çizilince okunuyor — misafir serisini elle
                    // açmak gerekiyordu.
                    defaultActiveKeys={['signups', 'guest_visits']}
                    controls={<span className={sectionTitleCls}>Yeni Üye / M. Ziyaret</span>}
                    csvBaseName="kelimeki-yeni-uye-ziyaret"
                    infoHint={<InfoHint id="yeni-uye-ziyaret" onOpen={setHint} />}
                  />
                ))}

              {growthSubTab === 'user' && (
                <div className="flex flex-col gap-5 pt-2">
                  <div className="flex flex-col gap-2">
                    {activePlayers === null ? (
                      <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                    ) : (
                      <GrowthChart
                        data={activePlayers}
                        granularity={userGranularity}
                        series={ACTIVE_PLAYER_SERIES}
                        defaultActiveKeys={['active_28d', 'active_in_bucket']}
                        controls={<span className={sectionTitleCls}>Aktif Oyuncu</span>}
                        csvBaseName="kelimeki-aktif-oyuncu"
                        infoHint={<InfoHint id="aktif-oyuncu" onOpen={setHint} />}
                      />
                    )}
                  </div>

                  <div className="flex flex-col gap-2">
                    {/* CSV'si olmayan iki panelden biri — `?` bölüm başlığının
                        yanında; yalnızca CSV'lere bakılsaydı bu açıklama
                        hiçbir yere düşmeden kaybolurdu. */}
                    <div className="flex items-center gap-2">
                      <span className={sectionTitleCls}>Aktivasyon</span>
                      <InfoHint id="aktivasyon" onOpen={setHint} />
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {activation === null
                            ? '…'
                            : activation.total_users > 0
                              ? `%${Math.round((activation.activated_users / activation.total_users) * 100)}`
                              : '—'}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Aktivasyon Oranı
                        </div>
                      </div>
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {activation === null ? '…' : activation.never_activated}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Hiç Oyun Bitirmemiş
                        </div>
                      </div>
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {activation === null ? '…' : formatHours(activation.median_hours_to_first_game)}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          İlk Oyuna Medyan Süre
                        </div>
                      </div>
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {activation === null ? '…' : activation.activated_same_day}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Aynı Gün Aktive
                        </div>
                      </div>
                    </div>
                    {/* Bu satır bir AÇIKLAMA değil VERİ — kutulara sığmayan üçlü
                        dağılım. Tanım `?`e taşındı ama sayıları da oraya gömmek
                        canlı veriyi bir tıklamanın arkasına saklardı.
                        Sayıya iyelik eki TAKILMIYOR ("2'i" mi "2'si" mi?) —
                        Türkçe ünlü uyumu programatik olarak garanti
                        edilemediğinden kural, eki gerektirmeyen bir kalıp
                        seçmek (bkz. "Sıra: {isim}" ve k-lig eşik metinleri). */}
                    {activation !== null && (
                      <p className={captionCls}>
                        İlk oyununu bitirme dağılımı — aynı gün: {activation.activated_same_day} · 1-3
                        gün: {activation.activated_within_3_days} · sonra: {activation.activated_later}
                      </p>
                    )}
                  </div>

                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>Retention (Kayıt Haftasına Göre)</span>
                    <RetentionCohortTable
                      cells={retention}
                      csvBaseName="kelimeki-retention"
                      infoHint={<InfoHint id="retention" onOpen={setHint} />}
                    />
                  </div>

                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Kaynak Hunisi (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <SourceFunnelTable
                      rows={sourceFunnel}
                      infoHint={<InfoHint id="kaynak-hunisi" onOpen={setHint} />}
                    />
                  </div>
                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Cihaz (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <GuestBreakdownTable
                      columnLabel="Cihaz"
                      emptyLabel="Bu aralıkta ziyaret yok."
                      rows={deviceBreakdown}
                      getKey={(row) => row.device_type}
                      getLabel={(row) =>
                        row.device_type === 'ios'
                          ? 'iOS'
                          : row.device_type === 'android'
                            ? 'Android'
                            : row.device_type === 'desktop'
                              ? 'Masaüstü'
                              : 'Bilinmiyor'
                      }
                      csvBaseName="kelimeki-cihaz"
                      infoHint={<InfoHint id="cihaz" onOpen={setHint} />}
                    />
                  </div>
                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Sürüm Dağılımı (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <GuestBreakdownTable
                      columnLabel="İstemci"
                      valueLabel="Başlangıç"
                      emptyLabel="Bu aralıkta oyun açılışı yok."
                      rows={appVersions?.map((r) => ({ ...r, visitors: r.starts })) ?? null}
                      getKey={(row) => `${row.platform}|${row.app_version}`}
                      // Sürümü olmayan istemci (web, ve kolondan ÖNCEKİ tüm
                      // satırlar) "bilinmiyor" döner — ekranda "—" yazılıyor:
                      // web'in sürümü YOK, bu bir eksik veri değil.
                      getLabel={(row) =>
                        `${row.platform} · ${row.app_version === 'bilinmiyor' ? '—' : row.app_version}`
                      }
                      csvBaseName="kelimeki-surum"
                      infoHint={<InfoHint id="surum-dagilimi" onOpen={setHint} />}
                    />
                  </div>
                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Kurulu Sürümler — Kişi (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    {/* ⚠ ÜSTTEKİ TABLONUN KOPYASI DEĞİL — farklı soru, farklı
                        kapsam (bkz. AdminPushVersionRow). "Sürüm Dağılımı"
                        `game_starts`tan besleniyor ve OYUN AÇILIŞI sayıyor
                        (app satırlarında kişi sayılamıyor: port `anon_id`
                        göndermiyor). Bu tablo `push_tokens`tan besleniyor ve
                        KİŞİ sayıyor — token her uygulama açılışında
                        hizalandığından oyun oynanması gerekmiyor.
                        Bedeli kapsam: yalnızca giriş yapmış VE bildirim izni
                        vermiş kişiler görünür. */}
                    <GuestBreakdownTable
                      columnLabel="İstemci"
                      valueLabel="Kişi"
                      emptyLabel="Bu aralıkta uygulamayı açan yok."
                      rows={pushVersions?.map((r) => ({ ...r, visitors: r.kisi })) ?? null}
                      getKey={(row) => `${row.platform}|${row.app_version}`}
                      // `app_version` kolonu 31 Ağustos 2026'da doğdu ve
                      // GERİYE DÖNÜK DOLDURULAMAZ: bir cihaz 1.0.4+ ile
                      // açılana kadar "—" kalır. Kolonun doğum tarihi, eksik
                      // veri değil.
                      getLabel={(row) =>
                        `${row.platform} · ${row.app_version === 'bilinmiyor' ? '—' : row.app_version}`
                      }
                      csvBaseName="kelimeki-kurulu-surum"
                      infoHint={<InfoHint id="kurulu-surum" onOpen={setHint} />}
                    />
                  </div>
                  {/* "Platform" ve "Ana Ekrana Ekleme" tabloları 15 Ağustos 2026'da
                      kullanıcı kararıyla KALDIRILDI — ikisi de bugün anlamlı bir şey
                      söylemiyordu. Platform: kolon 14 Ağustos'ta eklendiği için 337
                      oyunun 326'sı "Bilinmiyor"du (ölçüldü: kolondan SONRA biten 11
                      oyunun 11'i doğru çözülüyor, yani veri sağlamdı — sorun yalnızca
                      geçmişin doldurulamamasıydı). Ana Ekrana Ekleme: `guest_visits`
                      yalnızca GİRİŞSİZKEN yazıldığından, PWA'yı kuran (tipik olarak
                      girişli) kesimi yapısal olarak ölçemiyordu.
                      VERİ TOPLAMA DEVAM EDİYOR — `games.platform`, `online_game_clients`
                      ve `guest_visits.is_standalone` yazılmaya devam ediyor; yalnızca
                      bu iki tablo çizilmiyor. Uygulamalar mağazaya çıkınca platform
                      dökümü web/iOS/Android/diğer olarak yeniden yapılandırılacak
                      (`fetchAdminPlatformBreakdown` + `AdminPlatformRow` bu yüzden
                      `api.ts`'te BİLEREK duruyor, şu an hiçbir yerden çağrılmıyor). */}
                  <div className="flex flex-col gap-2">
                    {friendActivity === null ? (
                      <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                    ) : (
                      <GrowthChart
                        data={friendActivity}
                        granularity={userGranularity}
                        series={FRIEND_SERIES}
                        defaultActiveKeys={['requests_sent', 'friendships_formed']}
                        controls={<span className={sectionTitleCls}>Arkadaşlık</span>}
                        csvBaseName="kelimeki-arkadaslik"
                        infoHint={<InfoHint id="arkadaslik" onOpen={setHint} />}
                      />
                    )}
                    <div className="grid grid-cols-2 gap-2">
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {friendTotals === null ? '…' : friendTotals.total_friendships}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Toplam Arkadaşlık
                        </div>
                      </div>
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {friendTotals === null ? '…' : friendTotals.total_pending_requests}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Bekleyen İstek
                        </div>
                      </div>
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {friendTotals === null ? '…' : friendTotals.total_invite_links}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Oluşturulan Davet Linki
                        </div>
                      </div>
                      <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                        <div className="font-mono text-xl font-bold text-text">
                          {friendTotals === null ? '…' : friendTotals.total_invite_signups}
                        </div>
                        <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                          Davetle Katılan Üye
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {growthSubTab === 'game' && (
                <>
                  {gameActivity === null ? (
                    <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                  ) : (
                    <>
                      <GrowthChart
                        data={gameActivity}
                        granularity={gameGranularity}
                        series={GAME_COUNT_SERIES}
                        defaultActiveKeys={['games_finished']}
                        controls={<span className={sectionTitleCls}>Oyun Sayısı</span>}
                        csvBaseName="kelimeki-oyun-sayisi"
                        infoHint={<InfoHint id="oyun-sayisi" onOpen={setHint} />}
                      />
                      <div className="flex flex-col gap-2">
                        <GrowthChart
                          data={gameActivity}
                          granularity={gameGranularity}
                          series={DURATION_SERIES}
                          defaultActiveKeys={DURATION_DEFAULT_KEYS}
                          formatValue={formatDuration}
                          controls={<span className={sectionTitleCls}>Oyun Süresi (Medyan)</span>}
                          csvBaseName="kelimeki-oyun-suresi-medyan"
                          infoHint={<InfoHint id="oyun-suresi" onOpen={setHint} />}
                        />
                      </div>
                    </>
                  )}

                  {engagementActivity === null ? (
                    <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                  ) : (
                    <GrowthChart
                      data={engagementActivity}
                      granularity={gameGranularity}
                      series={ENGAGEMENT_SERIES}
                      defaultActiveKeys={['likes', 'shares']}
                      controls={<span className={sectionTitleCls}>Beğeni / Paylaşma</span>}
                      csvBaseName="kelimeki-begeni-paylasma"
                      infoHint={<InfoHint id="begeni-paylasma" onOpen={setHint} />}
                    />
                  )}

                  <div className="grid grid-cols-2 gap-2">
                    <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                      <div className="font-mono text-xl font-bold text-text">
                        {engagementTotals === null ? '…' : engagementTotals.total_likes}
                      </div>
                      <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                        Toplam Beğeni
                      </div>
                    </div>
                    <div className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center">
                      <div className="font-mono text-xl font-bold text-text">
                        {engagementTotals === null ? '…' : engagementTotals.total_shared_games}
                      </div>
                      <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                        Toplam Paylaşılan Oyun
                      </div>
                    </div>
                  </div>

                  {/* YZ Dengesi — 16 Ağustos 2026. Veri `games`te baştan beri
                      vardı ama hiçbir yerde gösterilmiyordu; oysa bu, YZ'ye
                      (`src/utils/ai.ts` / `kelimeki_core`) dokunan her
                      değişikliğin regresyonunu yakalayan tek sayı. Rastgele
                      referansı (2 kişilikte %50, 4 kişilikte %25) BİLEREK
                      ekranda yazıyor — onsuz "%31" alarm verici görünürken
                      aslında rastgelenin üstünde.
                      17 Ağustos 2026'da 4 kişilik için bir de "İkincilik"
                      kutusu eklendi (kullanıcı isteği): k-lig orada ikinciliğe
                      de puan verdiğinden yalnız birinciliğe bakmak "insan
                      puan alıyor mu" sorusunun yarısını ölçüyordu. */}
                  <div className="flex flex-col gap-2">
                    {/* CSV'si olmayan ikinci panel — `?` başlığın yanında. */}
                    <div className="flex items-center gap-2">
                      <span className={sectionTitleCls}>YZ Dengesi</span>
                      <InfoHint id="yz-dengesi" onOpen={setHint} />
                    </div>
                    {aiBalance === null ? (
                      <div className="text-xs font-mono text-muted text-center py-4">Yükleniyor…</div>
                    ) : aiBalance.length === 0 ? (
                      <div className="text-xs font-mono text-muted text-center py-4">
                        Henüz Yapay Zeka'ya karşı tamamlanmış oyun yok.
                      </div>
                    ) : (
                      /* Kutu sayısı satır sayısına bağlı (1-3) olduğundan
                         sütun sayısı inline `style` ile veriliyor: Tailwind
                         yalnızca KAYNAKTA geçen sınıfları üretir, çalışma
                         anında kurulan bir `grid-cols-${n}` sessizce
                         uygulanmazdı (bkz. CountBadge'in ölçüm tuzağı). */
                      <div
                        className="grid gap-2"
                        style={{
                          gridTemplateColumns: `repeat(${Math.min(aiBalanceCards.length, 3)}, minmax(0, 1fr))`,
                        }}
                      >
                        {aiBalanceCards.map((c) => (
                          <div
                            key={c.key}
                            className="btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center"
                          >
                            <div className="font-mono text-xl font-bold text-text">
                              {c.rate === null ? '—' : `%${c.rate}`}
                            </div>
                            <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                              {c.label}
                            </div>
                            <div className="text-[8px] font-mono text-muted mt-0.5">{c.detail}</div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </>
              )}
            </>
          )}

          {tab === 'errors' && (
            <>
              {clientErrors === null ? (
                <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
              ) : clientErrors.length === 0 ? (
                <div className="text-xs font-mono text-muted text-center py-6">
                  Bu pencerede hata kaydı yok.
                </div>
              ) : (
                <div className="flex flex-col gap-2">
                  {clientErrors.map((e) => {
                    // Anahtar id DEĞİL, çünkü satırlar gruplanmış geliyor —
                    // grubun kimliği tam olarak `(kind, mesaj imzası)` çifti.
                    const key = `${e.kind}|${e.message}`;
                    const isExpanded = expandedErrorKey === key;
                    return (
                      <div
                        key={key}
                        onClick={() => setExpandedErrorKey((prev) => (prev === key ? null : key))}
                        className="bg-bg border border-border rounded-lg p-3 flex flex-col gap-1.5 cursor-pointer"
                      >
                        <div className="flex items-center justify-between gap-2 text-[10px] font-mono text-muted">
                          <span className="shrink-0 px-1.5 py-0.5 rounded bg-red/20 text-red text-[9px] uppercase tracking-[0.5px]">
                            {errorKindLabel(e.kind)}
                          </span>
                          <span className="flex-1 min-w-0 truncate text-right">{e.platforms}</span>
                          <span className="shrink-0">{fmtDate(e.last_seen)}</span>
                        </div>

                        <p className={`text-xs text-text font-mono ${isExpanded ? 'break-words' : 'truncate'}`}>
                          {e.message}
                        </p>

                        {/* "Kez" ile "Cihaz" YAN YANA ve eşit vurguda: ikisi
                            ayrılmadan bir hatanın yaygın mı yoksa tek kişinin
                            döngüsü mü olduğu okunamıyor (bkz. `?` popup'ı). */}
                        <div className="flex items-center gap-3 text-[10px] font-mono text-muted">
                          <span>
                            <b className="text-text">{e.occurrences}</b> kez
                          </span>
                          <span>
                            <b className="text-text">{e.devices}</b> cihaz
                          </span>
                          <span className="truncate min-w-0">{e.builds}</span>
                        </div>

                        {/* Sürüm YALNIZCA varsa çizilir: web sürüm göndermez
                            (orada `build` sha'sı zaten tekil) ve boş bir
                            "Sürüm: —" satırı her web hatasında gürültü olurdu.
                            App'te ise mağazada aynı anda birden çok sürüm
                            yaşayacağından bu, "hangi sürümde düzeldi?"nin
                            tek cevabı. */}
                        {e.versions && (
                          <div className="text-[10px] font-mono text-muted">
                            Sürüm: <span className="text-text">{e.versions}</span>
                          </div>
                        )}

                        {isExpanded && (
                          <div className="flex flex-col gap-1.5 pt-1 border-t border-border">
                            <div className="text-[10px] font-mono text-muted">
                              Yol: <span className="text-text">{e.routes}</span>
                            </div>
                            <div className="text-[10px] font-mono text-muted">
                              İlk görülme: <span className="text-text">{fmtDate(e.first_seen)}</span>
                            </div>
                            {e.sample_stack && (
                              <pre className="text-[9px] font-mono text-muted bg-panel border border-border rounded-md p-2 overflow-x-auto whitespace-pre">
                                {e.sample_stack}
                              </pre>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}

          {tab === 'feedback' && (
            <>
              {feedbackSubTab === 'inbox' && (
            <>
              {feedback === null ? (
                <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
              ) : feedback.length === 0 ? (
                <div className="text-xs font-mono text-muted text-center py-6">
                  Henüz geri bildirim yok.
                </div>
              ) : filteredFeedback && filteredFeedback.length === 0 ? (
                <div className="text-xs font-mono text-muted text-center py-6">
                  Bu kategoride geri bildirim yok.
                </div>
              ) : (
                <div className="flex flex-col gap-2">
                  {filteredFeedback?.map((f) => {
                    const relatedMember = f.user_id ? members?.find((m) => m.id === f.user_id) : null;
                    const relatedLabel = relatedMember ? memberName(relatedMember) : (f.email || 'Anonim');
                    const headerLabel = f.origin === 'admin' ? `→ ${relatedLabel}` : relatedLabel;
                    const parent = f.related_to ? feedback?.find((x) => x.id === f.related_to) : null;
                    const isExpanded = expandedFeedbackId === f.id;
                    return (
                      <div
                        key={f.id}
                        onClick={() =>
                          setExpandedFeedbackId((prev) => (prev === f.id ? null : f.id))
                        }
                        className={`bg-bg border border-border rounded-lg p-3 flex flex-col gap-1.5 cursor-pointer ${
                          f.handled ? 'opacity-60' : ''
                        }`}
                      >
                        {/* Kimden geldiği KIRPILMAZ — bkz. CARD_HEADER. */}
                        <div className={CARD_HEADER}>
                          <span className={CARD_HEADER_NAME}>
                            {headerLabel}
                            {relatedMember && f.email ? ` · ${f.email}` : ''}
                          </span>
                          <div className={CARD_HEADER_META}>
                            {f.origin === 'admin' && (
                              <span className="shrink-0 px-1.5 py-0.5 rounded bg-accent/20 text-accent text-[9px] uppercase tracking-[0.5px]">
                                Gönderilen
                              </span>
                            )}
                            {f.related_to && (
                              <span className="shrink-0 px-1.5 py-0.5 rounded bg-panel border border-border text-[9px] uppercase tracking-[0.5px]">
                                ↳ Cevaben
                              </span>
                            )}
                            {f.reply && (
                              <span className="shrink-0 px-1.5 py-0.5 rounded bg-accent/20 text-accent text-[9px] uppercase tracking-[0.5px]">
                                Yanıtlandı
                              </span>
                            )}
                            {f.origin !== 'admin' && (
                              <span className="shrink-0 px-1.5 py-0.5 rounded bg-panel border border-border text-[9px] uppercase tracking-[0.5px]">
                                {f.source === 'game_end' ? 'Oyun Sonu' : 'Genel'}
                              </span>
                            )}
                            <span className="ml-auto shrink-0">{fmtDate(f.created_at)}</span>
                          </div>
                        </div>

                        {!isExpanded ? (
                          <p className="text-xs text-muted truncate">
                            {f.subject ? `${f.subject} — ${f.message}` : f.message}
                          </p>
                        ) : (
                          <>
                            {parent && (
                              <div className="bg-panel border border-border rounded-md p-2 flex flex-col gap-0.5">
                                <span className="text-[9px] uppercase tracking-[0.5px] text-muted font-mono">
                                  ↳ Şu mesaja cevaben ({fmtDate(parent.created_at)})
                                </span>
                                <p className="text-xs text-muted whitespace-pre-wrap truncate">
                                  {parent.subject ? `${parent.subject}: ` : ''}
                                  {parent.reply || parent.message}
                                </p>
                              </div>
                            )}
                            {f.subject && <p className="text-xs font-bold text-text">{f.subject}</p>}
                            <p className="text-xs text-text whitespace-pre-wrap">{f.message}</p>
                            {f.reply && (
                              <div className="bg-panel border border-border rounded-md p-2 flex flex-col gap-0.5">
                                <span className="text-[9px] uppercase tracking-[0.5px] text-muted font-mono">
                                  Yanıtın ({fmtDate(f.replied_at ?? f.created_at)})
                                </span>
                                <p className="text-xs text-text whitespace-pre-wrap">{f.reply}</p>
                              </div>
                            )}
                            <div
                              className="flex items-center justify-between gap-2"
                              onClick={(e) => e.stopPropagation()}
                            >
                              <div className="flex items-center gap-3">
                                <button
                                  onClick={() => toggleFeedbackHandled(f)}
                                  className="text-[10px] font-mono text-accent hover:underline"
                                >
                                  {f.handled ? 'Okunmadı işaretle' : 'Okundu işaretle'}
                                </button>
                                {f.origin === 'user' && !f.reply && (
                                  f.email ? (
                                    <button
                                      onClick={() => {
                                        setReplyError(null);
                                        setReplyOpenId((prev) => (prev === f.id ? null : f.id));
                                      }}
                                      className="text-[10px] font-mono text-accent hover:underline"
                                    >
                                      {replyOpenId === f.id ? 'Vazgeç' : 'Yanıtla'}
                                    </button>
                                  ) : (
                                    <span className="text-[10px] font-mono text-muted">E-posta yok, yanıtlanamaz</span>
                                  )
                                )}
                              </div>
                              <button
                                onClick={() => setFeedbackToDelete(f)}
                                aria-label="Sil"
                                title="Sil"
                                className="shrink-0 text-muted hover:text-red transition-colors"
                              >
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                                  <polyline points="3 6 5 6 21 6" />
                                  <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
                                  <path d="M10 11v6" />
                                  <path d="M14 11v6" />
                                  <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                                </svg>
                              </button>
                            </div>
                            {replyOpenId === f.id && (
                              <div
                                className="flex flex-col gap-1.5 pt-1 border-t border-border"
                                onClick={(e) => e.stopPropagation()}
                              >
                                <textarea
                                  className="w-full bg-panel border border-border rounded-md px-2 py-1.5 text-xs text-text outline-none focus:border-accent transition-colors resize-none"
                                  rows={3}
                                  maxLength={5000}
                                  placeholder={`${f.email} adresine yanıt yaz...`}
                                  value={replyDrafts[f.id] ?? ''}
                                  onChange={(e) =>
                                    setReplyDrafts((prev) => ({ ...prev, [f.id]: e.target.value }))
                                  }
                                  autoFocus
                                />
                                {replyError && (
                                  <p className="text-red text-[10px] font-mono">{replyError}</p>
                                )}
                                <button
                                  onClick={() => submitFeedbackReply(f)}
                                  disabled={
                                    replySendingId === f.id || !(replyDrafts[f.id] ?? '').trim()
                                  }
                                  className="self-end btn-raised bg-accent text-white rounded-md py-1.5 px-4 text-[10px] font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                                >
                                  {replySendingId === f.id ? '...' : 'Gönder'}
                                </button>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </>
              )}

              {feedbackSubTab === 'flags' && (
                <div className="flex flex-col gap-2">
                  {chatReports === null ? (
                    <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                  ) : chatReports.length === 0 ? (
                    <div className="text-xs font-mono text-muted text-center py-6">Henüz şikayet yok.</div>
                  ) : (
                    chatReports.map((r) => {
                      const isExpanded = expandedReportId === r.id;
                      return (
                        <div
                          key={r.id}
                          onClick={() => setExpandedReportId((prev) => (prev === r.id ? null : r.id))}
                          className={`bg-bg border border-border rounded-lg p-3 flex flex-col gap-1.5 cursor-pointer ${
                            r.handled ? 'opacity-60' : ''
                          }`}
                        >
                          {/* Kim kimi şikayet etti KIRPILMAZ — bkz. CARD_HEADER. */}
                          <div className={CARD_HEADER}>
                            <span className={CARD_HEADER_NAME}>
                              {r.reporter_name} → {r.reported_name}
                            </span>
                            <div className={CARD_HEADER_META}>
                              {r.withdrawn_at ? (
                                <span className="shrink-0 px-1.5 py-0.5 rounded bg-panel border border-border text-[9px] uppercase tracking-[0.5px]">
                                  Geri Çekildi
                                </span>
                              ) : r.handled ? (
                                <span className="shrink-0 px-1.5 py-0.5 rounded bg-accent/20 text-accent text-[9px] uppercase tracking-[0.5px]">
                                  İncelendi
                                </span>
                              ) : (
                                <span className="shrink-0 px-1.5 py-0.5 rounded bg-red/20 text-red text-[9px] uppercase tracking-[0.5px]">
                                  Yeni
                                </span>
                              )}
                              <span className="ml-auto shrink-0">{fmtDate(r.created_at)}</span>
                            </div>
                          </div>

                          {!isExpanded ? (
                            <p className="text-xs text-muted truncate">{r.reason}</p>
                          ) : (
                            <>
                              <p className="text-xs text-text whitespace-pre-wrap">{r.reason}</p>
                              <div className="flex items-center flex-wrap justify-between gap-2" onClick={(e) => e.stopPropagation()}>
                                <div className="flex items-center flex-wrap gap-3">
                                  <button
                                    onClick={() => {
                                      const next = !r.handled;
                                      const prevHandled = r.handled;
                                      setChatReports((prev) =>
                                        prev?.map((x) => (x.id === r.id ? { ...x, handled: next } : x)) ?? prev,
                                      );
                                      void markChatReportHandled(r.id, next).then((ok) => {
                                        if (!ok) {
                                          setChatReports((prev) =>
                                            prev?.map((x) => (x.id === r.id ? { ...x, handled: prevHandled } : x)) ?? prev,
                                          );
                                        }
                                      });
                                    }}
                                    className="text-[10px] font-mono text-accent hover:underline"
                                  >
                                    {r.handled ? 'Okunmadı işaretle' : 'Okundu işaretle'}
                                  </button>
                                  {r.game_finished ? (
                                    <button
                                      onClick={() => setTranscriptGameId(r.online_game_id)}
                                      className="text-[10px] font-mono text-accent hover:underline"
                                    >
                                      Sohbeti Görüntüle
                                    </button>
                                  ) : (
                                    <span className="text-[10px] font-mono text-muted">
                                      Oyun sürüyor, sohbet henüz görüntülenemez
                                    </span>
                                  )}
                                  <button
                                    onClick={() => {
                                      setTab('members');
                                      setMemberSearch('');
                                      setHighlightedMemberId(r.reported_user_id);
                                    }}
                                    className="text-[10px] font-mono text-accent hover:underline"
                                  >
                                    {r.reported_name} — Kişiye Git →
                                  </button>
                                </div>
                              </div>
                            </>
                          )}
                        </div>
                      );
                    })
                  )}
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {selectedMember && (
        <PlayerScoreCard member={selectedMember} onClose={() => setSelectedMember(null)} isAdminView />
      )}

      {transcriptGameId && (
        <AdminChatTranscriptModal onlineGameId={transcriptGameId} onClose={() => setTranscriptGameId(null)} />
      )}

      {messageTarget?.email && (
        <MemberMessageModal
          toUserId={messageTarget.id}
          toEmail={messageTarget.email}
          toName={memberName(messageTarget)}
          onClose={() => setMessageTarget(null)}
          onSent={() => fetchAdminFeedback().then(setFeedback).catch((e) => setError(String(e)))}
        />
      )}

      {feedbackToDelete && (
        <div
          className="fixed inset-0 z-[200] flex items-center justify-center px-4"
          onClick={(e) => e.stopPropagation()}
        >
          <div
            ref={feedbackDeleteRef}
            role="dialog"
            aria-modal="true"
            aria-label="Geri bildirim silme onayı"
            tabIndex={-1}
            className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
          >
            <p className="text-base font-bold text-text font-sans">Dikkat!</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              Bu geri bildirimi silmek istediğine emin misin?
            </p>
            <div className="flex gap-2 mt-1">
              <button
                onClick={confirmRemoveFeedback}
                className="btn-raised-red flex-1 py-2.5 rounded-md bg-red text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Sil
              </button>
              <button
                onClick={() => setFeedbackToDelete(null)}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Vazgeç
              </button>
            </div>
          </div>
        </div>
      )}

      {banTarget && (
        <div
          className="fixed inset-0 z-[200] flex items-center justify-center px-4"
          onClick={(e) => e.stopPropagation()}
        >
          <div
            ref={banConfirmRef}
            role="dialog"
            aria-modal="true"
            aria-label={banTarget.banned ? 'Hesabı dondurma onayı' : 'Dondurmayı kaldırma onayı'}
            tabIndex={-1}
            className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
          >
            <p className="text-base font-bold text-text font-sans">Emin misiniz?</p>
            <p className="text-sm text-text font-sans leading-relaxed">
              {banTarget.banned ? (
                <>
                  <span className="font-bold">{banTarget.name}</span> hesabını dondurmak istediğinize emin misiniz?
                  Bu kullanıcı bir sonraki girişte/oturum yenilemede reddedilir.
                </>
              ) : (
                <>
                  <span className="font-bold">{banTarget.name}</span> hesabının dondurulmasını kaldırmak istediğinize
                  emin misiniz?
                </>
              )}
            </p>
            {banError && <p className="text-red text-[10px] font-mono">{banError}</p>}
            <div className="flex gap-2 mt-1">
              <button
                onClick={confirmSetUserBanned}
                disabled={banBusy}
                className={`flex-1 py-2.5 rounded-md text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50 ${
                  banTarget.banned ? 'btn-raised-red bg-red text-white' : 'btn-raised bg-accent text-white'
                }`}
              >
                {banBusy ? '...' : banTarget.banned ? 'Hesabı Dondur' : 'Dondurmayı Kaldır'}
              </button>
              <button
                onClick={() => setBanTarget(null)}
                disabled={banBusy}
                className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
              >
                Vazgeç
              </button>
            </div>
          </div>
        </div>
      )}

      {hint && (
        <div
          className="fixed inset-0 z-[200] flex items-center justify-center px-4"
          onClick={(e) => e.stopPropagation()}
        >
          <div
            ref={hintRef}
            role="dialog"
            aria-modal="true"
            aria-label={`${HINTS[hint].title} tanımı`}
            tabIndex={-1}
            className="w-full max-w-sm max-h-[80vh] overflow-y-auto bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-3"
          >
            <p className="text-base font-bold text-text font-sans">{HINTS[hint].title}</p>
            {/* Gövde `font-sans` 13px: `captionCls`in 9px mono'su bir paragraf
                için okunaksız — ekranda değil popup'ta olduğundan yer sıkıntısı
                yok. */}
            <div className="text-[13px] text-text font-sans leading-relaxed">{HINTS[hint].body}</div>
            <button
              onClick={() => setHint(null)}
              className="btn-raised-neutral mt-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:opacity-70 transition-opacity"
            >
              Kapat
            </button>
          </div>
        </div>
      )}
    </div>,
    document.body,
  );
}
