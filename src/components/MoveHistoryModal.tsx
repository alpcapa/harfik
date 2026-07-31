// Kelimeki — oyundaki tüm oyuncuların hamle/puan geçmişi
import { Modal } from './Modal';
import { BINGO_BONUS, jokerFinishBonus } from '../game/constants';
import type { GameState } from '../game/types';

interface MoveHistoryModalProps {
  state: GameState;
  onClose: () => void;
}

/** Standart hamle dışı durumlar (sınır ihlali vb.) için küçük renkli rozet. */
function Flag({ label, tone }: { label: string; tone: 'green' | 'red' }) {
  return (
    <span
      className={`text-[8px] font-mono font-bold uppercase tracking-[0.5px] rounded px-1 py-[1px] border shrink-0 ${
        tone === 'green'
          ? 'text-green border-green/40 bg-green/10'
          : 'text-red border-red/40 bg-red/10'
      }`}
    >
      {label}
    </span>
  );
}

/**
 * ×2/×3 kelime çarpanı rozeti — bir kelimenin parantez içi puanının hemen
 * yanına konur. Yüksekliği (12px = h-3), yanındaki puan yazısıyla AYNI
 * `leading-none` satırda olduğu için birebir eşleşir: `leading-none`
 * (line-height:1) tarayıcıdan/fonttan bağımsız kesin bir değerdir — satır
 * yüksekliğini tarayıcının "normal" varsayılanına (fonta göre değişir,
 * Chrome/Safari farklı sonuç verebilir) bırakmak yerine burada açıkça
 * sabitliyoruz, böylece her cihazda aynı sonucu verir.
 */
/** Rafın 7 harfinin birden kullanıldığı hamlede puanın soluna konan rozet. */
function BingoBadge() {
  return (
    <span
      className="text-[8px] font-mono font-bold uppercase tracking-[0.5px] rounded px-1 py-[1px] border shrink-0 text-gold border-gold/40 bg-gold/10"
      title={`Bingo bonusu +${BINGO_BONUS}`}
    >
      Bingo
    </span>
  );
}

/** Jokerli bitiş bonusu rozeti — 1 joker ★, 2 joker ★★. */
function StarBadge({ jokerCount }: { jokerCount: number }) {
  return (
    <span
      className="text-[8px] font-mono font-bold uppercase tracking-[0.5px] rounded px-1 py-[1px] border shrink-0 text-accent border-accent/40 bg-accent/10"
      title={`Jokerli bitiş bonusu +${jokerFinishBonus(jokerCount)}`}
    >
      <span className="inline-block scale-150">{jokerCount >= 2 ? '★★' : '★'}</span>
    </span>
  );
}

function BonusBadge({ tier }: { tier: 2 | 3 }) {
  return (
    <span
      className="inline-flex items-center justify-center h-3 px-1 text-[10px] font-mono font-bold leading-none rounded"
      style={{
        background: tier === 3
          ? 'linear-gradient(135deg, #FDBA74, #F97316)'
          : 'linear-gradient(135deg, #FDE68A, #FBBF24)',
        color: '#7C2D12',
      }}
      title={tier === 3 ? 'Üç kat kelime puanı' : 'İki kat kelime puanı'}
    >
      ×{tier}
    </span>
  );
}

export function MoveHistoryModal({ state, onClose }: MoveHistoryModalProps) {
  const entries = state.moveHistory;
  const total = entries.reduce((s, e) => s + e.points, 0);
  // Vergi geliri satırı ayrı bir kart olarak gösterilmez: aynı hamle zaten
  // hamleyi yapanın kendi satırında (kelime + net puan + kaptırılan pay
  // notu) tam olarak anlatılıyor, ikinci satır sadece tekrar olur. Aynı
  // sebeple bu satırlar hamle sayısına da katılmaz — yoksa bir bölge
  // vergisi paylaşımı tek hamleyi iki "hamle" gibi saydırır.
  const displayEntries = entries.filter((e) => e.invasionFrom === undefined);
  const scoringMoveCount = displayEntries.filter((e) => !e.action).length;

  return (
    <Modal title="Oyun Geçmişi" onClose={onClose}>
      <p className="text-[10px] font-mono text-muted mb-3 leading-relaxed">
        Bu oyunda kazanılan {scoringMoveCount} hamle ve puanları. Toplam{' '}
        <span className="font-bold text-accent text-[15px]">{total}</span> puan.
      </p>

      {displayEntries.length === 0 ? (
        <p className="text-[11px] font-mono text-muted text-center py-4">
          Henüz kazanılmış bir puan yok.
        </p>
      ) : (
        <div className="flex flex-col gap-1.5 max-h-72 overflow-y-auto pr-1">
          {[...displayEntries].reverse().map((e, i) => {
            const player = state.players[e.player];
            const isInvasionLoss = !!e.lostShares && e.lostShares.length > 0;
            const hasWordScores = !!e.wordScores && e.wordScores.length > 0;
            const plainLabel = e.action === 'pass'
              ? 'Pas geçti'
              : e.action === 'exchange'
                ? `${e.tileCount} taş değiştirdi`
                : e.action === 'surrender'
                  ? 'Teslim oldu'
                  : hasWordScores
                  ? null
                  : e.words.length > 0
                    ? e.words.join(', ')
                    : '—';
            return (
              <div
                key={i}
                className="shadow-raised flex flex-col gap-0.5 py-1.5 px-2 rounded-md bg-bg border border-border"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex flex-col min-w-0 gap-0.5">
                    <span className="text-[9px] font-mono text-muted uppercase tracking-[0.5px]">
                      {e.turn + 1}. {player?.name ?? '?'}
                    </span>
                    <span className="text-[12px] leading-none font-mono font-bold text-text flex flex-wrap items-center gap-x-1 gap-y-0.5">
                      {!hasWordScores
                        ? plainLabel
                        : e.wordScores!.map((w, wi) => (
                            <span key={wi} className="inline-flex items-center gap-0.5">
                              {w.word} ({w.score}
                              {(w.x2 || w.x3) && ' '}
                              {w.x3 ? <BonusBadge tier={3} /> : w.x2 ? <BonusBadge tier={2} /> : null})
                              {wi < e.wordScores!.length - 1 && <span className="text-muted">,</span>}
                            </span>
                          ))}
                    </span>
                  </div>
                  {!e.action && (
                    <span className="flex items-center gap-1 shrink-0">
                      {e.bingo && <BingoBadge />}
                      {!!e.finishJokerCount && <StarBadge jokerCount={e.finishJokerCount} />}
                      {isInvasionLoss && <Flag label="Sınır İhlali" tone="red" />}
                      <span className="text-[13px] font-mono font-bold text-green">
                        +{e.points}
                      </span>
                    </span>
                  )}
                </div>
                {isInvasionLoss && (
                  <span className="text-[9px] font-mono text-red">
                    {e.lostShares!
                      .map((s) => `${s.amount} puanı ${state.players[s.to]?.name ?? '?'} kaptı`)
                      .join(', ')}
                  </span>
                )}
                {!!e.finishJokerCount && (
                  <span className="text-[9px] font-mono text-accent">
                    {e.finishJokerCount >= 2 ? 'Çift' : 'Tek'} yıldız ile biterek +
                    {jokerFinishBonus(e.finishJokerCount)} puan kazandı.
                  </span>
                )}
                {e.bingo && (
                  <span className="text-[9px] font-mono text-gold">
                    7 harfi birden koyup +{BINGO_BONUS} puan Bingo Bonus kazandı.
                  </span>
                )}
              </div>
            );
          })}
        </div>
      )}
    </Modal>
  );
}
