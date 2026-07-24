// Kelimeki — admin paneli: genel amaçlı zaman serisi çizgi grafiği (kullanıcı/oyun/süre)
import { useMemo, useRef, useState } from 'react';
import type { AdminActivityGranularity } from '../lib/database.types';

export interface ChartSeriesDef {
  key: string;
  label: string;
  color: string;
}

interface GrowthChartProps<T extends { bucket: string }> {
  data: T[];
  granularity: AdminActivityGranularity;
  series: ChartSeriesDef[];
  /** Başlangıçta hangi seri(ler) görünsün — verilmezse ilk seri. */
  defaultActiveKeys?: string[];
  /** Aralık/periyot (+ varsa kombo) seçim kontrolleri — tablo görünümü linkiyle aynı satırda gösterilir. */
  controls?: React.ReactNode;
  /** Eksen/tooltip/tablo değerlerini biçimlendirir (örn. saniyeyi "dk" olarak) — verilmezse ham sayı. */
  formatValue?: (v: number) => string;
}

/** Satırdan dinamik bir seri anahtarının değerini okur — T'nin tam alan kümesi statik olarak bilinmez. */
function valueOf<T>(row: T, key: string): number | null {
  const v = (row as Record<string, unknown>)[key];
  return typeof v === 'number' ? v : null;
}

const W = 640;
const H = 240;
// left/right burada minimum değer — uzun değer etiketleri (örn. "3 hafta 6 gün"
// süre metinleri) kırpılmasın diye bileşen içinde içeriğe göre büyütülüyor.
const PAD = { top: 16, right: 58, bottom: 24, left: 34 };
const PLOT_H = H - PAD.top - PAD.bottom;

function niceCeil(n: number): number {
  if (n <= 0) return 1;
  const exp = Math.floor(Math.log10(n));
  const base = Math.pow(10, exp);
  const norm = n / base;
  const niceNorm = norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10;
  return niceNorm * base;
}

function fmtShortDate(iso: string, granularity: AdminActivityGranularity): string {
  const d = new Date(iso + 'T00:00:00');
  if (granularity === 'year') return d.toLocaleDateString('tr-TR', { year: 'numeric' });
  return granularity === 'month'
    ? d.toLocaleDateString('tr-TR', { month: 'short', year: '2-digit' })
    : d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit' });
}

function fmtFullDate(iso: string, granularity: AdminActivityGranularity): string {
  const d = new Date(iso + 'T00:00:00');
  if (granularity === 'year') return d.toLocaleDateString('tr-TR', { year: 'numeric' });
  if (granularity === 'month') return d.toLocaleDateString('tr-TR', { month: 'long', year: 'numeric' });
  const full = d.toLocaleDateString('tr-TR', { day: '2-digit', month: 'long', year: 'numeric' });
  return granularity === 'week' ? `${full} haftası` : full;
}

export function GrowthChart<T extends { bucket: string }>({
  data,
  granularity,
  series,
  defaultActiveKeys,
  controls,
  formatValue = (v) => String(v),
}: GrowthChartProps<T>) {
  const [showTable, setShowTable] = useState(false);
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);
  const [activeKeys, setActiveKeys] = useState<Set<string>>(
    () => new Set(defaultActiveKeys ?? (series[0] ? [series[0].key] : [])),
  );
  const wrapRef = useRef<HTMLDivElement | null>(null);

  const activeSeries = series.filter((s) => activeKeys.has(s.key));

  function toggleSeries(key: string) {
    setActiveKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  const n = data.length;
  const maxRaw = Math.max(
    1,
    ...data.flatMap((d) => activeSeries.map((s) => valueOf(d, s.key) ?? 0)),
  );
  const niceMax = niceCeil(maxRaw);
  const yTicks = niceMax <= 4 ? [0, niceMax] : [0, Math.round(niceMax / 2), niceMax];

  // Y ekseni ve uç değer etiketleri say/sürebilir uzunlukta olabildiğinden
  // (örn. "17" vs "3 hafta 6 gün"), kırpılmayı önlemek için kenar boşlukları
  // en uzun etiketin genişliğine göre büyütülüyor.
  const leftPad = useMemo(() => {
    const maxLen = yTicks.reduce((m, t) => Math.max(m, formatValue(t).length), 1);
    return Math.max(PAD.left, 14 + maxLen * 7.2);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [yTicks, formatValue]);

  const rightPad = useMemo(() => {
    if (n === 0) return PAD.right;
    const maxLen = activeSeries.reduce(
      (m, s) => Math.max(m, formatValue(valueOf(data[n - 1], s.key) ?? 0).length),
      2,
    );
    return Math.max(PAD.right, 16 + maxLen * 7.2);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [n, activeSeries, data, formatValue]);

  const plotW = W - leftPad - rightPad;

  const x = (i: number) => leftPad + (n <= 1 ? 0 : (i / (n - 1)) * plotW);
  const y = (v: number) => PAD.top + PLOT_H - (v / niceMax) * PLOT_H;

  const paths = useMemo(
    () =>
      activeSeries.map((s) => ({
        ...s,
        d: data.map((row, i) => `${i === 0 ? 'M' : 'L'} ${x(i)} ${y(valueOf(row, s.key) ?? 0)}`).join(' '),
      })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [data, niceMax, activeKeys],
  );

  // Son noktadaki değer etiketlerini üst üste binmeyecek şekilde dikey olarak ayır.
  const endLabels = useMemo(() => {
    if (n === 0) return [];
    const raw = activeSeries.map((s) => {
      const value = valueOf(data[n - 1], s.key) ?? 0;
      return { ...s, value, rawY: y(value) };
    }).sort((a, b) => a.rawY - b.rawY);
    const MIN_GAP = 16;
    for (let i = 1; i < raw.length; i++) {
      if (raw[i].rawY - raw[i - 1].rawY < MIN_GAP) {
        raw[i].rawY = raw[i - 1].rawY + MIN_GAP;
      }
    }
    return raw;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data, niceMax, activeKeys]);

  function handlePointerMove(e: React.PointerEvent<HTMLDivElement>) {
    const el = wrapRef.current;
    if (!el || n === 0) return;
    const rect = el.getBoundingClientRect();
    const xInViewBox = ((e.clientX - rect.left) / rect.width) * W;
    const idx = Math.round(((xInViewBox - leftPad) / plotW) * (n - 1));
    setHoverIndex(Math.min(n - 1, Math.max(0, idx)));
  }

  const hover = hoverIndex !== null ? data[hoverIndex] : null;
  const hoverPct = hoverIndex !== null ? { left: `${(x(hoverIndex) / W) * 100}%` } : null;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center flex-wrap gap-x-2 gap-y-1.5">
        {controls}
        <button
          type="button"
          onClick={() => setShowTable((v) => !v)}
          className="text-[9px] font-mono uppercase tracking-[0.5px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity shrink-0 ml-auto"
        >
          {showTable ? 'Grafik Görünümü' : 'Tablo Görünümü'}
        </button>
      </div>

      {series.length > 1 && (
        <div className="flex items-center gap-3 flex-wrap">
          {series.map((s) => {
            const active = activeKeys.has(s.key);
            return (
              <button
                key={s.key}
                type="button"
                onClick={() => toggleSeries(s.key)}
                className={`flex items-center gap-1.5 text-[10px] font-mono transition-opacity ${
                  active ? 'text-text' : 'text-muted opacity-45'
                }`}
              >
                <span
                  className="inline-block w-3 h-[2px] rounded-full"
                  style={{ background: active ? s.color : '#8A93A2' }}
                />
                {s.label}
              </button>
            );
          })}
        </div>
      )}

      {n === 0 ? (
        <div className="text-xs font-mono text-muted text-center py-8">Bu aralıkta veri yok.</div>
      ) : showTable ? (
        <div className="overflow-x-auto max-h-[280px] overflow-y-auto">
          <table className="w-full text-[11px] font-mono border-collapse">
            <thead>
              <tr className="text-left text-muted border-b border-border sticky top-0 bg-panel">
                <th className="py-1.5 pr-3 font-bold">Tarih</th>
                {series.map((s) => (
                  <th key={s.key} className="py-1.5 pr-3 font-bold text-right last:pr-0">
                    {s.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {[...data].reverse().map((row) => (
                <tr key={row.bucket} className="border-b border-border/50">
                  <td className="py-1.5 pr-3 text-text whitespace-nowrap">{fmtFullDate(row.bucket, granularity)}</td>
                  {series.map((s) => {
                    const v = valueOf(row, s.key);
                    return (
                      <td key={s.key} className="py-1.5 pr-3 text-text text-right last:pr-0">
                        {v == null ? '—' : formatValue(v)}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="relative w-full select-none">
          {/* Safari, bir aspect-ratio kutusu tablo görünümünden geri
              takılınca içinde bulunduğu overflow-y-auto panelin yüksekliğini
              yanlış hesaplayıp alttaki kardeşleri (Ziyaretçi Kaynağı vb.)
              görünümden düşürüyordu — aspect-ratio yerine tüm tarayıcılarda
              güvenilir çalışan klasik padding-top yüzdesi tekniği kullanılıyor. */}
          <div style={{ paddingTop: `${(H / W) * 100}%` }} />
          <div
            ref={wrapRef}
            className="absolute inset-0"
            onPointerMove={handlePointerMove}
            onPointerLeave={() => setHoverIndex(null)}
          >
            <svg width="100%" height="100%" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none">
              {yTicks.map((t) => (
                <g key={t}>
                  <line
                    x1={leftPad}
                    x2={W - rightPad}
                    y1={y(t)}
                    y2={y(t)}
                    stroke="#DCE2EA"
                    strokeWidth={1}
                  />
                  <text x={leftPad - 6} y={y(t)} textAnchor="end" dominantBaseline="middle" fontSize={13} fill="#8A93A2">
                    {formatValue(t)}
                  </text>
                </g>
              ))}

              <text x={leftPad} y={H - 4} textAnchor="start" fontSize={12} fill="#8A93A2">
                {fmtShortDate(data[0].bucket, granularity)}
              </text>
              {n > 2 && (
                <text x={x(Math.floor((n - 1) / 2))} y={H - 4} textAnchor="middle" fontSize={12} fill="#8A93A2">
                  {fmtShortDate(data[Math.floor((n - 1) / 2)].bucket, granularity)}
                </text>
              )}
              <text x={x(n - 1)} y={H - 4} textAnchor="end" fontSize={12} fill="#8A93A2">
                {fmtShortDate(data[n - 1].bucket, granularity)}
              </text>

              {hoverIndex !== null && (
                <line
                  x1={x(hoverIndex)}
                  x2={x(hoverIndex)}
                  y1={PAD.top}
                  y2={PAD.top + PLOT_H}
                  stroke="#8A93A2"
                  strokeWidth={1}
                />
              )}

              {paths.map((p) => (
                <path key={p.key} d={p.d} fill="none" stroke={p.color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
              ))}

              {activeSeries.map((s) => (
                <circle
                  key={s.key}
                  cx={x(n - 1)}
                  cy={y(valueOf(data[n - 1], s.key) ?? 0)}
                  r={4}
                  fill={s.color}
                  stroke="#FFFFFF"
                  strokeWidth={2}
                />
              ))}

              {endLabels.map((l) => (
                <g key={l.key}>
                  {Math.abs(l.rawY - y(l.value)) > 0.5 && (
                    <line x1={x(n - 1) + 5} x2={x(n - 1) + 10} y1={y(l.value)} y2={l.rawY} stroke="#DCE2EA" strokeWidth={1} />
                  )}
                  <text x={x(n - 1) + 12} y={l.rawY} dominantBaseline="middle" fontSize={13} fontWeight={700} fill="#1B2430">
                    {formatValue(l.value)}
                  </text>
                </g>
              ))}
            </svg>

            {hover && hoverPct && (
              <div
                className="absolute top-0 -translate-x-1/2 pointer-events-none bg-panel border border-border rounded-md shadow-[0_4px_12px_rgba(15,23,42,0.15)] px-2.5 py-1.5 text-[10px] font-mono whitespace-nowrap"
                style={{
                  left: hoverPct.left,
                  marginLeft: hoverIndex === 0 ? 8 : hoverIndex === n - 1 ? -8 : 0,
                  transform: hoverIndex === 0 ? 'translateX(0)' : hoverIndex === n - 1 ? 'translateX(-100%)' : 'translateX(-50%)',
                }}
              >
                <div className="text-muted mb-1">{fmtFullDate(hover.bucket, granularity)}</div>
                {activeSeries.map((s) => {
                  const v = valueOf(hover, s.key);
                  return (
                    <div key={s.key} className="flex items-center gap-1.5">
                      <span className="inline-block w-2.5 h-[2px] rounded-full" style={{ background: s.color }} />
                      <span className="font-bold text-text text-[12px]">{v == null ? '—' : formatValue(v)}</span>
                      <span className="text-muted">{s.label}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
