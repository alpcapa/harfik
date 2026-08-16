// Kelimeki — admin paneli: üyeler ve oyun istatistikleri
import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import {
  fetchAdminMembers,
  fetchAdminUserActivitySeries,
  fetchAdminGameActivitySeries,
  fetchAdminEngagementActivitySeries,
  fetchAdminEngagementTotals,
  fetchAdminFriendActivitySeries,
  fetchAdminFriendTotals,
  fetchAdminActivePlayersSeries,
  fetchAdminRetentionCohorts,
  fetchAdminActivationStats,
  fetchAdminSourceFunnel,
  fetchAdminGuestDeviceBreakdown,
  fetchAdminFeedback,
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
  AdminFriendActivityPoint,
  AdminFriendTotals,
  AdminActivePlayersPoint,
  AdminRetentionCell,
  AdminActivationStats,
  AdminSourceFunnelRow,
  AdminGuestDeviceRow,
  AdminActivityGranularity,
  AdminFeedbackRow,
  AdminChatReportRow,
} from '../lib/database.types';
import { PlayerScoreCard } from './PlayerScoreCard';
import { MemberMessageModal } from './MemberMessageModal';
import { AdminChatTranscriptModal } from './AdminChatTranscriptModal';
import { CountBadge } from './CountBadge';
import { GrowthChart, type ChartSeriesDef } from './GrowthChart';
import { trLower } from '../utils/turkish';
import { useModalA11y } from '../hooks/useModalA11y';
import { downloadCsv } from '../utils/csvExport';

interface AdminDashboardProps {
  onClose: () => void;
}

type Tab = 'members' | 'growth' | 'feedback';
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
const DURATION_SERIES: ChartSeriesDef[] = [
  { key: 'avg_duration_seconds', label: 'Genel', color: '#7c3aed' },
  { key: 'avg_duration_same_session_seconds', label: 'Tek Oturumda', color: '#0891B2' },
  { key: 'avg_duration_multi_session_seconds', label: 'Günlere Yayılan', color: '#DC2626' },
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
 * Grafik/tablo altındaki açıklama satırı. Bu paneldeki birkaç metrik (aktif
 * oyuncu, aktivasyon, retention) tanımı bilinmeden YANLIŞ okunabildiğinden
 * tanım ekranın kendisinde yazıyor — dokümanda kalsa ilk yanlış yorum
 * kaçınılmaz olurdu.
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

/** "CSV İndir"/"Tablo Görünümü" gibi küçük alt çizgili aksiyon linkleri için ortak stil. */
const csvLinkCls =
  'text-[9px] font-mono uppercase tracking-[0.5px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity shrink-0';

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
}: {
  columnLabel: string;
  emptyLabel: string;
  rows: T[] | null;
  getKey: (row: T) => string;
  getLabel: (row: T) => string;
  csvBaseName: string;
}) {
  if (rows === null) {
    return <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>;
  }
  if (rows.length === 0) {
    return <div className="text-xs font-mono text-muted text-center py-6">{emptyLabel}</div>;
  }
  const totalVisitors = rows.reduce((sum, row) => sum + row.visitors, 0);
  const visibleRows = rows;

  function handleExportCsv() {
    downloadCsv(
      csvFilename(csvBaseName),
      [columnLabel, 'Ziyaretçi', '%'],
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
      <button type="button" onClick={handleExportCsv} className={`${csvLinkCls} self-end`}>
        CSV İndir
      </button>
      <div className="overflow-x-auto">
        <table className="w-auto text-[11px] font-mono border-collapse">
          <thead>
            <tr className="text-left text-muted border-b border-border">
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px]">{columnLabel}</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">Ziyaretçi</th>
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
 * Kaynak hunisi (Büyüme > Kullanıcı): kaynak → kişi → üye → oyun.
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
 *   - **Kişi** = sütun payı (o kaynak tüm ziyaretçilerin yüzde kaçı),
 *   - **Üye**  = `üye / kişi` — o kaynaktan gelenlerin yüzde kaçı üye oldu,
 *   - **Oyun** = `oynayan kişi / kişi` — yüzde kaçı oyun oynadı.
 *
 * "Oyun" sütunu sayı modunda oyun ADEDİNİ, yüzde modunda OYNAYAN KİŞİ oranını
 * gösterir — taban bilinçli olarak farklı, çünkü "kişilerin yüzde kaçı
 * oynadı" sorusu oyun adediyle yanıtlanamaz (bir kişi 50 oyun oynayabilir,
 * `oyun / kişi` %100'ü kolayca aşar ve başka bir şey ölçer). Bu yüzden RPC
 * ayrı bir `players` (benzersiz oynayan) ölçüsü döndürüyor.
 *
 * SINIR: `üye/kişi` ve `oynayan/kişi` yalnızca İKİ UCU DA damgalanmış bir
 * kaynakta gerçek bir dönüşüm oranıdır — `?ref=instagram` ile gelen ziyaretçi
 * de oradan üye olan hesap da aynı etiketi taşıdığı için anlamlı. `kişi = 0`
 * olan satırlarda (ör. damgalama öncesi üyelerin toplandığı "bilinmiyor")
 * oran HİÇ hesaplanmaz, "—" gösterilir; sıfıra bölmek yerine "bilinmiyor"
 * demek doğrusu. Oran %100'ü aşabilir (iki ölçü ayrı dimension) ve bu bir
 * hata değil — ekrandaki açıklama satırı bunu da söylüyor.
 *
 * CSV her zaman HAM SAYI verir (düğmeden bağımsız) — retention tablosundaki
 * aynı karar: yuvarlama kaybı olmaz, yüzde zaten yeniden hesaplanabilir.
 * `players` tabloda yalnızca yüzdenin içinde görünür, CSV'de ayrı bir sütun.
 */
function SourceFunnelTable({ rows }: { rows: AdminSourceFunnelRow[] | null }) {
  const [asPercent, setAsPercent] = useState(false);
  if (rows === null) {
    return <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>;
  }
  if (rows.length === 0) {
    return (
      <div className="text-xs font-mono text-muted text-center py-6">
        Bu aralıkta veri yok.
      </div>
    );
  }
  const total = rows.reduce(
    (acc, row) => ({
      visitors: acc.visitors + row.visitors,
      signups: acc.signups + row.signups,
      games: acc.games + row.games,
      players: acc.players + row.players,
    }),
    { visitors: 0, signups: 0, games: 0, players: 0 },
  );

  function handleExportCsv() {
    downloadCsv(
      csvFilename('kelimeki-kaynak-funnel'),
      ['Kaynak', 'Kişi', 'Üye', 'Oyun', 'Oynayan Kişi'],
      [
        ...rows!.map((row) => [row.source, row.visitors, row.signups, row.games, row.players]),
        ['TOPLAM', total.visitors, total.signups, total.games, total.players],
      ],
    );
  }

  const pct = (value: number, base: number) =>
    `${((value / base) * 100).toFixed(1)}%`;

  /** "Kişi" sütunu — yüzdesi SÜTUN payı. */
  function visitorCell(value: number): string {
    if (!asPercent) return String(value);
    return total.visitors > 0 ? pct(value, total.visitors) : '0.0%';
  }

  /**
   * "Üye"/"Oyun" sütunları — yüzdeleri SATIR YÖNÜNDE dönüşüm oranı, tabanı o
   * satırın "Kişi"si. Taban 0 ise oran yok ("—"): sıfıra bölmek yerine
   * bilinmediğini söylemek doğrusu (bugün "bilinmiyor" satırı tam bu durumda).
   */
  function conversionCell(value: number, rowVisitors: number, percentOf: number): string {
    if (!asPercent) return String(value);
    if (rowVisitors <= 0) return '—';
    return pct(percentOf, rowVisitors);
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
      </div>
      <div className="overflow-x-auto">
        <table className="w-auto text-[11px] font-mono border-collapse">
          <thead>
            <tr className="text-left text-muted border-b border-border">
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px]">Kaynak</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">Kişi</th>
              <th className="py-1.5 pr-8 font-bold uppercase tracking-[1px] text-center">Üye</th>
              <th className="py-1.5 font-bold uppercase tracking-[1px] text-center">Oyun</th>
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
                <td className="py-1.5 text-muted whitespace-nowrap text-center">
                  {conversionCell(row.games, row.visitors, row.players)}
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
              <td className="py-1.5 text-text font-bold whitespace-nowrap text-center">
                {conversionCell(total.games, total.visitors, total.players)}
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

function RetentionCohortTable({ cells, csvBaseName }: { cells: AdminRetentionCell[] | null; csvBaseName: string }) {
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

  if (grid === null) {
    return <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>;
  }
  if (grid.weeks.length === 0 || grid.maxOffset < 0) {
    return (
      <div className="text-xs font-mono text-muted text-center py-6">
        Henüz tamamlanmış bir hafta yok.
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
      <button type="button" onClick={handleExportCsv} className={`${csvLinkCls} self-end`}>
        CSV İndir
      </button>
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
  const [guestDevices, setGuestDevices] = useState<AdminGuestDeviceRow[] | null>(null);
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
  const [memberSearch, setMemberSearch] = useState('');
  const [sortKey, setSortKey] = useState<MemberSortKey>('created_at');
  const [sortDir, setSortDir] = useState<SortDir>('desc');
  const [feedback, setFeedback] = useState<AdminFeedbackRow[] | null>(null);
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
  const [expandedReportId, setExpandedReportId] = useState<string | null>(null);
  const [transcriptGameId, setTranscriptGameId] = useState<string | null>(null);
  const [banTarget, setBanTarget] = useState<{ id: string; name: string; banned: boolean } | null>(null);
  const [banBusy, setBanBusy] = useState(false);
  const [banError, setBanError] = useState<string | null>(null);
  const [highlightedMemberId, setHighlightedMemberId] = useState<string | null>(null);

  const panelRef = useModalA11y(true, onClose);
  const feedbackDeleteRef = useModalA11y(!!feedbackToDelete, () => setFeedbackToDelete(null));
  const banConfirmRef = useModalA11y(!!banTarget, () => setBanTarget(null));

  useEffect(() => {
    if (tab !== 'members' || !highlightedMemberId) return;
    const el = document.getElementById(`admin-member-row-${highlightedMemberId}`);
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    const timer = setTimeout(() => setHighlightedMemberId(null), 2500);
    return () => clearTimeout(timer);
  }, [tab, highlightedMemberId]);

  useEffect(() => {
    fetchAdminMembers()
      .then(setMembers)
      .catch((e) => setError(String(e)));
    fetchAdminFeedback()
      .then(setFeedback)
      .catch((e) => setError(String(e)));
    fetchAdminChatReports()
      .then(setChatReports)
      .catch((e) => setError(String(e)));
    fetchAdminEngagementTotals()
      .then(setEngagementTotals)
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
      fetchAdminGuestDeviceBreakdown(days).then(setGuestDevices),
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
        className={`py-2 pr-3 font-bold cursor-pointer select-none hover:text-text transition-colors ${className ?? ''}`}
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
  const tabBtn = (active: boolean) =>
    `relative flex-1 py-2.5 px-3 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1px] transition-colors ${
      active ? 'bg-accent text-white' : 'bg-panel text-muted border border-border'
    }`;

  function exportMembersCsv() {
    if (!filteredMembers || filteredMembers.length === 0) return;
    downloadCsv(
      csvFilename('kelimeki-uyeler'),
      ['İsim', 'Nickname', 'E-posta', 'Kanal', 'Katılma', 'Son Giriş', 'Rol'],
      filteredMembers.map((m) => [
        memberName(m),
        memberNickname(m),
        m.email ?? '',
        memberChannelLabel(m),
        fmtDate(m.created_at),
        fmtDate(m.last_sign_in_at),
        m.is_admin ? 'Admin' : 'Üye',
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
              className="text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
            >
              ✕
            </button>
          </div>
          <div className="flex gap-1.5">
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
                  {filteredFeedback && filteredFeedback.length > 0 && (
                    <button type="button" onClick={exportFeedbackCsv} className={csvLinkCls}>
                      CSV İndir
                    </button>
                  )}
                </div>
              )}
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
                <div className="overflow-x-auto">
                  <table className="w-full text-[11px] font-mono border-collapse">
                    <thead>
                      <tr className="text-left text-muted border-b border-border">
                        <SortHeader label="İsim" sortKeyFor="name" />
                        <SortHeader label="Nickname" sortKeyFor="nickname" />
                        <SortHeader label="E-posta" sortKeyFor="email" />
                        <SortHeader label="Kanal" sortKeyFor="signup_channel" />
                        <SortHeader label="Katılma" sortKeyFor="created_at" />
                        <SortHeader label="Son Giriş" sortKeyFor="last_sign_in_at" />
                        <SortHeader label="Rol" sortKeyFor="is_admin" />
                        <th className="py-2 pl-3 text-left font-normal">Durum</th>
                        <th className="py-2 pl-3 text-left font-normal"></th>
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
                          className={`border-b border-border/50 cursor-pointer hover:bg-bg/60 active:opacity-70 transition-colors ${
                            highlightedMemberId === m.id ? 'bg-accent/20' : ''
                          }`}
                        >
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{memberName(m)}</td>
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{memberNickname(m)}</td>
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{m.email ?? '—'}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{memberChannelLabel(m)}</td>
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
                {filteredMembers && filteredMembers.length > 0 ? (
                  <button type="button" onClick={exportMembersCsv} className={csvLinkCls}>
                    CSV İndir
                  </button>
                ) : (
                  <span />
                )}
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
                      />
                    )}
                    <p className={captionCls}>
                      Aktif = oyun bitirme, Canlı hamle, sohbet mesajı, beğeni, arkadaşlık isteği ya da Canlı
                      oyun kurma. Girişli kullanıcı için “uygulamayı açtı” sinyali şemada yok — bu yüzden bu
                      sayı bilerek MAU değil, uygulamayı açıp hiçbir şey yapmadan çıkanı saymaz.
                    </p>
                  </div>

                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>Aktivasyon</span>
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
                    <p className={captionCls}>
                      Aktive = en az bir oyunu BİTİRMİŞ üye (yalnızca arkadaşlık isteği gönderen aktif oyuncu
                      sayılır ama aktive sayılmaz — iki ayrı soru).
                      {/* Sayıya iyelik eki TAKILMIYOR ("2'i" mi "2'si" mi?) — Türkçe ünlü
                          uyumu programatik olarak garanti edilemediğinden bu projede
                          kural, eki gerektirmeyen bir kalıp seçmek (bkz. "Sıra: {isim}"
                          ve k-lig eşik metinlerindeki aynı karar). */}
                      {activation === null
                        ? ''
                        : ` İlk oyununu bitirme dağılımı — aynı gün: ${activation.activated_same_day}, 1-3 gün içinde: ${activation.activated_within_3_days}, daha sonra: ${activation.activated_later}.`}
                    </p>
                  </div>

                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>Retention (Kayıt Haftasına Göre)</span>
                    <RetentionCohortTable cells={retention} csvBaseName="kelimeki-retention" />
                    <p className={captionCls}>
                      Satır: kayıt haftası · Sütun: kayıttan sonraki hafta (H0 = kayıt haftasının kendisi) ·
                      Hücre: o kohorttan o hafta aktif olan üye oranı. Yalnızca TAMAMLANMIŞ haftalar gösterilir —
                      yarım bir hafta her zaman yapay olarak düşük görünür ve son köşegeni yalancı bir düşüş gibi
                      gösterirdi.
                    </p>
                  </div>

                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Kaynak Hunisi (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <SourceFunnelTable rows={sourceFunnel} />
                    {/* Tanım ekranın KENDİSİNDE yazıyor — dokümanda kalsaydı ilk
                        yanlış yorum kaçınılmazdı (retention/aktif oyuncu panellerinde
                        aynı karar). */}
                    <p className="text-[10px] font-mono text-muted leading-relaxed max-w-[560px]">
                      <b>Kişi</b> = o kaynaktan gelen benzersiz misafir ziyaretçi;{' '}
                      <b>Üye</b> = o kaynak damgasıyla açılan hesap; <b>Oyun</b> = o
                      hesapların bitirdiği oyun. Pencere her adıma kendi olay tarihinden
                      uygulanır (kohort değil): 2 ay önce üye olup bugün oynayan biri
                      "Oyun"a girer, "Üye"ye girmez.{' '}
                      <b>Bilinmiyor</b> = kaynak damgası olmayan hesaplar — bu özellik
                      16 Ağustos 2026'da eklendi ve geriye dönük doldurulamıyor, ayrıca
                      mobil uygulamadan gelen kayıtlar henüz damgalanmıyor.{' '}
                      <b>Direkt</b> = web'e <code>?ref=</code> olmadan geliş. "Kişi" ile
                      "Üye" iki ayrı ölçümdür (ziyaretler anonim, hesaba bağlanmaz).{' '}
                      <b>% / Sayı</b> düğmesi üç sütunu birden çevirir: <b>Kişi</b> yüzdesi o
                      sütunun payı, <b>Üye</b> ve <b>Oyun</b> yüzdeleri ise o satırın
                      "Kişi"sine göre dönüşüm — sırasıyla kaçının üye olduğu ve kaçının oyun
                      oynadığı (oyun ADEDİ değil, oynayan KİŞİ). Kişi 0 ise oran hesaplanmaz
                      ("—"); iki ucu da damgalanmamış kaynaklarda oran %100'ü aşabilir. CSV
                      her zaman ham sayı verir (oynayan kişi sayısı da ayrı bir sütun olarak).
                    </p>
                  </div>
                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Cihaz (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <GuestBreakdownTable
                      columnLabel="Cihaz"
                      emptyLabel="Bu aralıkta misafir ziyareti yok."
                      rows={guestDevices}
                      getKey={(row) => row.device_type}
                      getLabel={(row) =>
                        row.device_type === 'mobile' ? 'Mobil' : row.device_type === 'desktop' ? 'Masaüstü' : 'Bilinmiyor'
                      }
                      csvBaseName="kelimeki-cihaz"
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
                      />
                      <div className="flex flex-col gap-2">
                        <GrowthChart
                          data={gameActivity}
                          granularity={gameGranularity}
                          series={DURATION_SERIES}
                          defaultActiveKeys={DURATION_SERIES.map((s) => s.key)}
                          formatValue={formatDuration}
                          controls={<span className={sectionTitleCls}>Ortalama Oyun Süresi</span>}
                          csvBaseName="kelimeki-ortalama-oyun-suresi"
                        />
                        <p className={captionCls}>
                          Canlı oyunlar 48 saatlik sıra penceresi nedeniyle her zaman “günlere yayılan”
                          tarafında sayılır; “tek oturumda” yalnızca uygulama hiç kapatılmadan bitirilen
                          Yapay Zeka oyunlarını kapsar.
                        </p>
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
                </>
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
                        <div className="flex items-center justify-between gap-2 text-[10px] font-mono text-muted">
                          <span className="truncate min-w-0 flex-1">
                            {headerLabel}
                            {relatedMember && f.email ? ` · ${f.email}` : ''}
                          </span>
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
                          <span className="shrink-0">{fmtDate(f.created_at)}</span>
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
                          <div className="flex items-center justify-between gap-2 text-[10px] font-mono text-muted">
                            <span className="truncate min-w-0 flex-1">
                              {r.reporter_name} → {r.reported_name}
                            </span>
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
                            <span className="shrink-0">{fmtDate(r.created_at)}</span>
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
    </div>,
    document.body,
  );
}
