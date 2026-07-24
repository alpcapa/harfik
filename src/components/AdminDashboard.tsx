// Kelimeki — admin paneli: üyeler ve oyun istatistikleri
import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import {
  fetchAdminMembers,
  fetchAdminUserActivitySeries,
  fetchAdminGameActivitySeries,
  fetchAdminGuestSourceBreakdown,
  fetchAdminGuestDeviceBreakdown,
  fetchAdminGuestStandaloneBreakdown,
  fetchAdminFeedback,
  markFeedbackHandled,
  deleteFeedback,
} from '../lib/api';
import type {
  AdminMember,
  AdminUserActivityPoint,
  AdminGameActivityPoint,
  AdminGameScope,
  AdminGuestSourceRow,
  AdminGuestDeviceRow,
  AdminGuestStandaloneRow,
  AdminActivityGranularity,
  AdminFeedbackRow,
  FeedbackSource,
} from '../lib/database.types';
import { AdminPlayerDetail } from './AdminPlayerDetail';
import { GrowthChart, type ChartSeriesDef } from './GrowthChart';
import { trLower } from '../utils/turkish';
import { useModalA11y } from '../hooks/useModalA11y';

interface AdminDashboardProps {
  onClose: () => void;
}

type Tab = 'members' | 'growth' | 'feedback';
type GameSubTab = 'total' | 2 | 4;
type GrowthSubTab = 'user' | 'game';
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
  { key: 'guest_visits', label: 'Ziyaret', color: '#D97706' },
];
const GAME_COUNT_SERIES: ChartSeriesDef[] = [
  { key: 'games_finished', label: 'Bitirilen', color: '#008300' },
  { key: 'games_finished_same_session', label: 'Bitirilen (Aynı Oturum)', color: '#0891B2' },
  { key: 'games_finished_multi_session', label: 'Bitirilen (Çok Oturumlu)', color: '#7c3aed' },
  { key: 'games_surrendered', label: 'Teslim', color: '#D97706' },
  { key: 'games_abandoned', label: 'Terk', color: '#DC2626' },
];
const DURATION_SERIES: ChartSeriesDef[] = [
  { key: 'avg_duration_seconds', label: 'Genel', color: '#7c3aed' },
  { key: 'avg_duration_same_session_seconds', label: 'Aynı Oturum', color: '#0891B2' },
  { key: 'avg_duration_multi_session_seconds', label: 'Çok Oturumlu', color: '#DC2626' },
];

const selectCls =
  'w-auto shrink-0 py-1.5 px-2 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1px] bg-panel text-text border border-border';

/** GrowthChart'ın `controls` satırına konan bölüm başlığı — Tablo Görünümü linkiyle aynı hizada. */
const sectionTitleCls = 'text-[10px] font-mono font-bold uppercase tracking-[1px] text-muted';

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
}: {
  columnLabel: string;
  emptyLabel: string;
  rows: T[] | null;
  getKey: (row: T) => string;
  getLabel: (row: T) => string;
}) {
  if (rows === null) {
    return <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>;
  }
  if (rows.length === 0) {
    return <div className="text-xs font-mono text-muted text-center py-6">{emptyLabel}</div>;
  }
  const totalVisitors = rows.reduce((sum, row) => sum + row.visitors, 0);
  return (
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
  const [tab, setTab] = useState<Tab>('members');
  const [members, setMembers] = useState<AdminMember[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selectedMember, setSelectedMember] = useState<AdminMember | null>(null);
  const [growthSubTab, setGrowthSubTab] = useState<GrowthSubTab>('user');
  const [userActivity, setUserActivity] = useState<AdminUserActivityPoint[] | null>(null);
  const [userGranularity, setUserGranularity] = useState<AdminActivityGranularity>('day');
  const [userPeriod, setUserPeriod] = useState<number>(30);
  const [guestSources, setGuestSources] = useState<AdminGuestSourceRow[] | null>(null);
  const [guestDevices, setGuestDevices] = useState<AdminGuestDeviceRow[] | null>(null);
  const [guestStandalone, setGuestStandalone] = useState<AdminGuestStandaloneRow[] | null>(null);
  const [gameActivity, setGameActivity] = useState<AdminGameActivityPoint[] | null>(null);
  const [gameGranularity, setGameGranularity] = useState<AdminActivityGranularity>('day');
  const [gamePeriod, setGamePeriod] = useState<number>(30);
  const [gameScope, setGameScope] = useState<AdminGameScope>('total');
  const [gamePlayerCount, setGamePlayerCount] = useState<GameSubTab>('total');
  const [memberSearch, setMemberSearch] = useState('');
  const [sortKey, setSortKey] = useState<MemberSortKey>('created_at');
  const [sortDir, setSortDir] = useState<SortDir>('desc');
  const [feedback, setFeedback] = useState<AdminFeedbackRow[] | null>(null);
  const [feedbackSourceFilter, setFeedbackSourceFilter] = useState<'all' | FeedbackSource>('all');
  const [feedbackToDelete, setFeedbackToDelete] = useState<AdminFeedbackRow | null>(null);

  const panelRef = useModalA11y(true, onClose);
  const feedbackDeleteRef = useModalA11y(!!feedbackToDelete, () => setFeedbackToDelete(null));

  useEffect(() => {
    fetchAdminMembers()
      .then(setMembers)
      .catch((e) => setError(String(e)));
    fetchAdminFeedback()
      .then(setFeedback)
      .catch((e) => setError(String(e)));
  }, []);

  useEffect(() => {
    setUserActivity(null);
    fetchAdminUserActivitySeries(userPeriod, userGranularity)
      .then(setUserActivity)
      .catch((e) => setError(String(e)));
  }, [userPeriod, userGranularity]);

  useEffect(() => {
    setGuestSources(null);
    fetchAdminGuestSourceBreakdown(userPeriod * GRANULARITY_TO_DAYS[userGranularity])
      .then(setGuestSources)
      .catch((e) => setError(String(e)));
  }, [userPeriod, userGranularity]);

  useEffect(() => {
    setGuestDevices(null);
    fetchAdminGuestDeviceBreakdown(userPeriod * GRANULARITY_TO_DAYS[userGranularity])
      .then(setGuestDevices)
      .catch((e) => setError(String(e)));
  }, [userPeriod, userGranularity]);

  useEffect(() => {
    setGuestStandalone(null);
    fetchAdminGuestStandaloneBreakdown(userPeriod * GRANULARITY_TO_DAYS[userGranularity])
      .then(setGuestStandalone)
      .catch((e) => setError(String(e)));
  }, [userPeriod, userGranularity]);

  useEffect(() => {
    setGameActivity(null);
    fetchAdminGameActivitySeries(
      gamePeriod,
      gameGranularity,
      gameScope,
      gamePlayerCount === 'total' ? null : gamePlayerCount,
    )
      .then(setGameActivity)
      .catch((e) => setError(String(e)));
  }, [gamePeriod, gameGranularity, gameScope, gamePlayerCount]);

  function selectUserGranularity(g: AdminActivityGranularity) {
    setUserGranularity(g);
    setUserPeriod(PERIOD_OPTIONS[g][1]);
  }

  function selectGameGranularity(g: AdminActivityGranularity) {
    setGameGranularity(g);
    setGamePeriod(PERIOD_OPTIONS[g][1]);
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

  const tabBtn = (active: boolean) =>
    `flex-1 py-2.5 rounded-md font-sans text-[11px] font-bold uppercase tracking-[1px] transition-colors ${
      active ? 'bg-accent text-white' : 'bg-panel text-muted border border-border'
    }`;

  const unhandledFeedbackCount = feedback?.filter((f) => !f.handled).length ?? 0;
  const filteredFeedback = useMemo(
    () =>
      feedbackSourceFilter === 'all'
        ? feedback
        : feedback?.filter((f) => f.source === feedbackSourceFilter) ?? null,
    [feedback, feedbackSourceFilter],
  );

  function toggleFeedbackHandled(f: AdminFeedbackRow) {
    const next = !f.handled;
    setFeedback((prev) => prev?.map((x) => (x.id === f.id ? { ...x, handled: next } : x)) ?? prev);
    void markFeedbackHandled(f.id, next);
  }

  function confirmRemoveFeedback() {
    const f = feedbackToDelete;
    if (!f) return;
    setFeedbackToDelete(null);
    setFeedback((prev) => prev?.filter((x) => x.id !== f.id) ?? prev);
    deleteFeedback(f.id).catch((e) => setError(String(e)));
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
            <button className={tabBtn(tab === 'members')} onClick={() => setTab('members')}>
              Üyeler
            </button>
            <button className={tabBtn(tab === 'growth')} onClick={() => setTab('growth')}>
              Büyüme
            </button>
            <button className={tabBtn(tab === 'feedback')} onClick={() => setTab('feedback')}>
              Geri Bildirim{unhandledFeedbackCount > 0 ? ` (${unhandledFeedbackCount})` : ''}
            </button>
          </div>
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
                className="w-full bg-bg border border-border rounded-md px-3 py-2 text-[11px] font-mono text-text outline-none focus:border-accent transition-colors"
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
                        <SortHeader label="Rol" sortKeyFor="is_admin" className="pr-0" />
                      </tr>
                    </thead>
                    <tbody>
                      {filteredMembers?.map((m) => (
                        <tr
                          key={m.id}
                          onClick={() => setSelectedMember(m)}
                          className="border-b border-border/50 cursor-pointer hover:bg-bg/60 active:opacity-70"
                        >
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{memberName(m)}</td>
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{memberNickname(m)}</td>
                          <td className="py-2 pr-3 text-text whitespace-nowrap">{m.email ?? '—'}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{memberChannelLabel(m)}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{fmtDate(m.created_at)}</td>
                          <td className="py-2 pr-3 text-muted whitespace-nowrap">{fmtDate(m.last_sign_in_at)}</td>
                          <td className="py-2 whitespace-nowrap">
                            {m.is_admin ? (
                              <span className="text-accent font-bold">Admin</span>
                            ) : (
                              <span className="text-muted">Üye</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              <div className="text-[10px] font-mono text-muted text-right">
                {memberSearch.trim() && members
                  ? `${filteredMembers?.length ?? 0} / ${members.length} üye`
                  : `Toplam ${members?.length ?? 0} üye`}
              </div>
            </>
          )}

          {tab === 'growth' && (
            <>
              <div className="flex gap-1.5">
                <button className={tabBtn(growthSubTab === 'user')} onClick={() => setGrowthSubTab('user')}>
                  Kullanıcı
                </button>
                <button className={tabBtn(growthSubTab === 'game')} onClick={() => setGrowthSubTab('game')}>
                  Oyun
                </button>
              </div>

              {growthSubTab === 'user' &&
                (userActivity === null ? (
                  <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                ) : (
                  <GrowthChart
                    data={userActivity}
                    granularity={userGranularity}
                    series={USER_SERIES}
                    defaultActiveKeys={['signups']}
                    controls={
                      <>
                        <select
                          value={userGranularity}
                          onChange={(e) => selectUserGranularity(e.target.value as AdminActivityGranularity)}
                          className={selectCls}
                        >
                          <option value="day">Günlük</option>
                          <option value="week">Haftalık</option>
                          <option value="month">Aylık</option>
                          <option value="year">Yıllık</option>
                        </select>
                        <select
                          value={userPeriod}
                          onChange={(e) => setUserPeriod(Number(e.target.value))}
                          className={selectCls}
                        >
                          {PERIOD_OPTIONS[userGranularity].map((p) => (
                            <option key={p} value={p}>
                              Son {p} {PERIOD_UNIT_LABEL[userGranularity]}
                            </option>
                          ))}
                        </select>
                      </>
                    }
                  />
                ))}

              {growthSubTab === 'user' && (
                <div className="flex flex-col gap-5 pt-2">
                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Ziyaretçi Kaynağı (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <GuestBreakdownTable
                      columnLabel="Kaynak"
                      emptyLabel="Bu aralıkta misafir ziyareti yok."
                      rows={guestSources}
                      getKey={(row) => row.source}
                      getLabel={(row) => row.source}
                    />
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
                    />
                  </div>
                  <div className="flex flex-col gap-2">
                    <span className={sectionTitleCls}>
                      Ana Ekrana Ekleme (Son {userPeriod} {PERIOD_UNIT_LABEL[userGranularity]})
                    </span>
                    <GuestBreakdownTable
                      columnLabel="Durum"
                      emptyLabel="Bu aralıkta misafir ziyareti yok."
                      rows={guestStandalone}
                      getKey={(row) => String(row.is_standalone)}
                      getLabel={(row) => (row.is_standalone ? 'App' : 'Browser')}
                    />
                  </div>
                </div>
              )}

              {growthSubTab === 'game' && (
                <>
                  <div className="flex items-center flex-wrap gap-2">
                    <select
                      value={gameScope}
                      onChange={(e) => setGameScope(e.target.value as AdminGameScope)}
                      className={selectCls}
                    >
                      <option value="total">Toplam</option>
                      <option value="registered">Kayıtlı</option>
                      <option value="guest">Misafir</option>
                    </select>
                    <select
                      value={gamePlayerCount}
                      onChange={(e) =>
                        setGamePlayerCount(e.target.value === 'total' ? 'total' : (Number(e.target.value) as 2 | 4))
                      }
                      className={selectCls}
                    >
                      <option value="total">Toplam</option>
                      <option value={2}>2 Kişilik</option>
                      <option value={4}>4 Kişilik</option>
                    </select>
                    <select
                      value={gameGranularity}
                      onChange={(e) => selectGameGranularity(e.target.value as AdminActivityGranularity)}
                      className={selectCls}
                    >
                      <option value="day">Günlük</option>
                      <option value="week">Haftalık</option>
                      <option value="month">Aylık</option>
                      <option value="year">Yıllık</option>
                    </select>
                    <select
                      value={gamePeriod}
                      onChange={(e) => setGamePeriod(Number(e.target.value))}
                      className={selectCls}
                    >
                      {PERIOD_OPTIONS[gameGranularity].map((p) => (
                        <option key={p} value={p}>
                          Son {p} {PERIOD_UNIT_LABEL[gameGranularity]}
                        </option>
                      ))}
                    </select>
                  </div>

                  {gameActivity === null ? (
                    <div className="text-xs font-mono text-muted text-center py-6">Yükleniyor…</div>
                  ) : (
                    <>
                      <GrowthChart
                        data={gameActivity}
                        granularity={gameGranularity}
                        series={GAME_COUNT_SERIES}
                        defaultActiveKeys={['games_finished_same_session']}
                        controls={<span className={sectionTitleCls}>Oyun Sayısı</span>}
                      />
                      <GrowthChart
                        data={gameActivity}
                        granularity={gameGranularity}
                        series={DURATION_SERIES}
                        defaultActiveKeys={['avg_duration_same_session_seconds']}
                        formatValue={formatDuration}
                        controls={<span className={sectionTitleCls}>Ortalama Oyun Süresi</span>}
                      />
                    </>
                  )}
                </>
              )}
            </>
          )}

          {tab === 'feedback' && (
            <>
              <select
                value={feedbackSourceFilter}
                onChange={(e) => setFeedbackSourceFilter(e.target.value as 'all' | FeedbackSource)}
                className={selectCls}
              >
                <option value="all">Tüm</option>
                <option value="game_end">Oyun Sonu</option>
                <option value="general">Genel</option>
              </select>

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
                    const sender = f.user_id ? members?.find((m) => m.id === f.user_id) : null;
                    const senderLabel = sender ? memberName(sender) : (f.email || 'Anonim');
                    return (
                      <div
                        key={f.id}
                        className={`bg-bg border border-border rounded-lg p-3 flex flex-col gap-1.5 ${
                          f.handled ? 'opacity-60' : ''
                        }`}
                      >
                        <div className="flex items-center justify-between gap-2 text-[10px] font-mono text-muted">
                          <span className="truncate min-w-0 flex-1">
                            {senderLabel}
                            {sender && f.email ? ` · ${f.email}` : ''}
                          </span>
                          <span className="shrink-0 px-1.5 py-0.5 rounded bg-panel border border-border text-[9px] uppercase tracking-[0.5px]">
                            {f.source === 'game_end' ? 'Oyun Sonu' : 'Genel'}
                          </span>
                          <span className="shrink-0">{fmtDate(f.created_at)}</span>
                        </div>
                        <p className="text-xs text-text whitespace-pre-wrap">{f.message}</p>
                        <div className="flex items-center justify-between gap-2">
                          <button
                            onClick={() => toggleFeedbackHandled(f)}
                            className="text-[10px] font-mono text-accent hover:underline"
                          >
                            {f.handled ? 'Okunmadı işaretle' : 'Okundu işaretle'}
                          </button>
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
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {selectedMember && (
        <AdminPlayerDetail member={selectedMember} onClose={() => setSelectedMember(null)} />
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
    </div>,
    document.body,
  );
}
