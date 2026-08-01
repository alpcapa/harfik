// Kelimeki — herhangi bir oyuncunun salt-okunur skor kartı (Admin Paneli >
// Üyeler ve Sanal Lig'de bir satıra tıklanınca açılır)
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { GameHistoryModal } from './GameHistoryModal';
import { Leaderboard } from './Leaderboard';
import { useAuth } from '../hooks/useAuth';
import { useModalA11y } from '../hooks/useModalA11y';
import {
  fetchFriendRelation,
  fetchMyLeaderboardRank,
  fetchPlayerStats,
  removeFriend,
  respondFriendRequest,
  sendFriendRequest,
} from '../lib/api';
import type { FriendRelation, MyLeaderboardRank, PlayerStats } from '../lib/database.types';

/** Bir skor kartı çizmek için gereken asgari oyuncu kimliği. */
export interface PlayerSummary {
  id: string;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  display_name: string | null;
  avatar_url?: string | null;
}

interface PlayerScoreCardProps {
  member: PlayerSummary;
  onClose: () => void;
}

type TabKey = 'all' | 2 | 4;
const TABS: { key: TabKey; label: string }[] = [
  { key: 'all', label: 'Genel' },
  { key: 2, label: '2 Oyunculu' },
  { key: 4, label: '4 Oyunculu' },
];

// Skor kartı herkese açık olduğundan (Sanal Lig'den herkes başkasının
// kartını açabilir) tam ad/soyad değil, oyun içindekiyle aynı kısa kimlik
// gösterilir — nickname yoksa sadece isim, soyadı hiç kullanılmaz.
function memberDisplayName(m: PlayerSummary) {
  return m.display_name || m.first_name || 'Oyuncu';
}

// Henüz canlı oyun olmadığından arkadaş eklemenin somut bir faydası yok —
// bu yüzden Sanal Lig'den herhangi birinin kartını görünce arkadaş
// ekleyebilmek önemli: arkadaşsa yeşil ✓ (dokununca çıkarma onayı), değilse
// + (dokununca duruma göre ekleme/kabul/iptal onayı) gösterir.
function friendDialogCopy(relation: FriendRelation | null, name: string) {
  switch (relation) {
    case 'accepted':
      return {
        title: 'Arkadaşlıktan Çıkar',
        message: `${name} ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?`,
        action: 'Çıkar',
      };
    case 'pending_outgoing':
      return {
        title: 'İsteği İptal Et',
        message: `${name} oyuncusuna gönderdiğin arkadaşlık isteğini iptal etmek istiyor musun?`,
        action: 'İptal Et',
      };
    case 'pending_incoming':
      return {
        title: 'Arkadaşlık İsteği',
        message: `${name} oyuncusu sana arkadaşlık isteği gönderdi. Kabul etmek istiyor musun?`,
        action: 'Kabul Et',
      };
    default:
      return {
        title: 'Arkadaş Ekle',
        message: `${name} oyuncusunu arkadaş olarak eklemek istiyor musun?`,
        action: 'Ekle',
      };
  }
}

export function PlayerScoreCard({ member, onClose }: PlayerScoreCardProps) {
  const { user } = useAuth();
  const [statsByTab, setStatsByTab] = useState<
    Record<TabKey, PlayerStats | null | undefined>
  >({ all: undefined, 2: undefined, 4: undefined });
  const [tab, setTab] = useState<TabKey>('all');
  const [showAllGames, setShowAllGames] = useState(false);
  const [showLeague, setShowLeague] = useState(false);
  const [rank, setRank] = useState<MyLeaderboardRank | null>(null);
  const [relation, setRelation] = useState<FriendRelation | null | undefined>(undefined);
  const [showFriendConfirm, setShowFriendConfirm] = useState(false);
  const [friendBusy, setFriendBusy] = useState(false);
  const [friendResultMsg, setFriendResultMsg] = useState<string | null>(null);
  const friendConfirmRef = useModalA11y(showFriendConfirm, () => setShowFriendConfirm(false));
  const friendResultRef = useModalA11y(!!friendResultMsg, () => setFriendResultMsg(null));

  useEffect(() => {
    for (const { key } of TABS) {
      fetchPlayerStats(key, member.id).then((s) =>
        setStatsByTab((cur) => ({ ...cur, [key]: s })),
      );
    }
    fetchMyLeaderboardRank(member.id).then(setRank);
  }, [member.id]);

  useEffect(() => {
    if (!user || user.id === member.id) {
      setRelation(null);
      return;
    }
    let cancelled = false;
    fetchFriendRelation(member.id).then((r) => {
      if (!cancelled) setRelation(r);
    });
    return () => {
      cancelled = true;
    };
  }, [user, member.id]);

  const showFriendButton = !!user && user.id !== member.id && relation !== undefined;

  const handleFriendAction = async () => {
    setFriendBusy(true);
    try {
      let resultMsg = '';
      if (relation === 'accepted') {
        await removeFriend(member.id); // arkadaşlıktan çıkar
        resultMsg = 'Arkadaşlıktan çıkarıldı.';
      } else if (relation === 'pending_outgoing') {
        await removeFriend(member.id); // gönderilen isteği iptal et
        resultMsg = 'Arkadaşlık isteği iptal edildi.';
      } else if (relation === 'pending_incoming') {
        await respondFriendRequest(member.id, true); // kabul et
        resultMsg = 'Arkadaş oldunuz.';
      } else {
        await sendFriendRequest(member.id);
        resultMsg = 'Arkadaşlık isteğiniz iletilmiştir.';
      }
      setRelation(await fetchFriendRelation(member.id));
      setFriendResultMsg(resultMsg);
    } catch (err) {
      console.error('[Kelimeki] arkadaşlık aksiyonu hatası:', err);
    } finally {
      setFriendBusy(false);
      setShowFriendConfirm(false);
    }
  };

  const name = memberDisplayName(member);
  const stats = statsByTab[tab];
  const totalScore = statsByTab.all?.total_score ?? 0;

  const pct = (n: number) =>
    stats && stats.games_played > 0 ? `%${Math.round((n / stats.games_played) * 100)}` : '%0';

  // "Genel" sekmesi tablo yapısı olarak 4 kişilikle aynı (ScoreCard.tsx'teki
  // aynı gerekçe) — 2 kişilikte 2. olmak lig puanı getirmediğinden
  // "İkincilik" hücresi yalnızca o sekmede hiç gösterilmez.
  const useWideLayout = tab === 4 || tab === 'all';
  const secondCellValue = stats?.second_places ?? 0;

  type Cell = { label: string; value: number | string; rate?: string; cls?: string; span2?: boolean };

  // Oyuncu istatistikleri (davranış/sonuç sayıları) üstte, oyun istatistikleri
  // (tek oyun/hamle/kelime rekorları) altta — ScoreCard.tsx'teki aynı
  // düzenleme, birlikte güncellendi (bkz. dosya başındaki not).
  const playerCells: Cell[] = [
    { label: 'Toplam Oyun', value: stats?.games_played ?? 0 },
    {
      label: 'Yapay Zeka ile',
      value: stats?.local_games_played ?? 0,
      rate: pct(stats?.local_games_played ?? 0),
    },
    {
      label: 'Arkadaşınla',
      value: stats?.online_games_played ?? 0,
      rate: pct(stats?.online_games_played ?? 0),
    },
    {
      label: 'Birincilik',
      value: stats?.first_places ?? 0,
      rate: pct(stats?.first_places ?? 0),
      cls: 'text-gold',
    },
    ...(useWideLayout
      ? [
          {
            label: 'İkincilik',
            value: secondCellValue,
            rate: pct(secondCellValue),
            cls: 'text-accent',
          },
        ]
      : []),
    {
      label: 'Teslim Olma',
      value: stats?.surrendered_count ?? 0,
      rate: pct(stats?.surrendered_count ?? 0),
      cls: 'text-red',
    },
  ];

  const gameCells: Cell[] = [
    { label: 'En Yüksek Oyun Puanı', value: stats?.best_score ?? 0, cls: 'text-gold' },
    { label: 'En İyi Hamle Puanı', value: stats?.best_move_score ?? 0, cls: 'text-accent' },
    { label: 'En Yüksek Puanlı Kelime', value: stats?.best_word_score ?? 0, cls: 'text-gold' },
    {
      label: 'Ortalama Hamle Puanı',
      value: Number(stats?.avg_move_score ?? 0).toFixed(2),
      cls: 'text-accent',
    },
    { label: 'En Uzun Kelime', value: stats?.longest_word ?? '—', cls: 'text-text', span2: true },
  ];

  return (
    <Modal title="Skor Kartı" onClose={onClose}>
      <div className="mb-4 flex items-center gap-3">
        <Avatar url={member.avatar_url ?? undefined} name={name} size={44} />
        <div className="min-w-0 flex-1 flex items-center gap-2">
          <div className="text-base font-bold text-text truncate">{name}</div>
          {showFriendButton && (
            <button
              type="button"
              onClick={() => setShowFriendConfirm(true)}
              aria-label={relation === 'accepted' ? 'Arkadaşlık durumunu yönet' : 'Arkadaş ekle'}
              className={`shrink-0 w-5 h-5 rounded-full border flex items-center justify-center font-bold leading-none active:scale-90 transition-transform ${
                relation === 'accepted'
                  ? 'bg-green/15 text-green border-green/40 text-sm'
                  : 'bg-accent/15 text-accent border-accent/40 text-lg'
              }`}
            >
              {relation === 'accepted' ? '✓' : '+'}
            </button>
          )}
        </div>
        <button
          type="button"
          onClick={() => setShowLeague(true)}
          aria-label="Sanal Lig sıralamasını göster"
          className="text-right shrink-0 active:opacity-70 transition-opacity"
        >
          <div className="flex items-center justify-end gap-1 text-xs uppercase tracking-[1px] text-muted font-mono">
            <span className="font-bold">Sanal Lig</span>
            <span className="w-3.5 h-3.5 rounded-full border border-muted text-muted flex items-center justify-center text-[9px] leading-none font-bold">
              ?
            </span>
          </div>
          <div className="font-mono text-xl font-bold text-gold">
            {rank && (
              <span className="text-sm font-normal text-muted">
                #{rank.rank}
                <span className="mx-0.5">·</span>
              </span>
            )}
            {totalScore}
            <span className="text-xs font-normal text-muted"> puan</span>
          </div>
        </button>
      </div>

      <div className="mb-3 flex gap-2">
        {TABS.map(({ key, label }) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={[
              'flex-1 py-2 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97] flex flex-col items-center',
              tab === key
                ? 'btn-raised bg-accent text-white border-accent'
                : 'btn-raised-neutral bg-panel text-text border-border',
            ].join(' ')}
          >
            <span className="leading-none">{label}</span>
            <span className="text-[10px] font-normal normal-case leading-none mt-0.5">
              ({statsByTab[key]?.total_score ?? 0} puan)
            </span>
          </button>
        ))}
      </div>

      {stats === undefined ? (
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : (
        <>
          {!stats && (
            <p className="text-muted text-[10px] font-mono text-center pb-2">
              {tab === 'all' ? 'Bu oyuncunun hiç oyun kaydı yok.' : `Bu oyuncunun ${tab} oyunculu oyun kaydı yok.`}
            </p>
          )}
          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mb-1.5">
            Oyuncu İstatistikleri
          </div>
          <div className="grid grid-cols-3 gap-2">
            {playerCells.map((c) => (
              <div
                key={c.label}
                className={`btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center ${c.span2 ? 'col-span-2' : ''}`}
              >
                <div className={`font-mono text-xl font-bold ${c.cls ?? 'text-text'}`}>
                  {c.value}
                </div>
                {c.rate && (
                  <div className="font-mono text-xs text-muted mt-0.5">({c.rate})</div>
                )}
                <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                  {c.label}
                </div>
              </div>
            ))}
          </div>

          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mt-4 mb-1.5">
            Oyun İstatistikleri
          </div>
          <div className="grid grid-cols-3 gap-2">
            {gameCells.map((c) => (
              <div
                key={c.label}
                className={`btn-raised-neutral bg-bg border border-border rounded-md py-3 px-1 text-center ${c.span2 ? 'col-span-2' : ''}`}
              >
                <div className={`font-mono text-xl font-bold ${c.cls ?? 'text-text'}`}>
                  {c.value}
                </div>
                {c.rate && (
                  <div className="font-mono text-xs text-muted mt-0.5">({c.rate})</div>
                )}
                <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                  {c.label}
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      <div className="text-center mt-4">
        <button
          onClick={() => setShowAllGames(true)}
          className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity"
        >
          Tüm Oyunları Gör
        </button>
      </div>

      {showAllGames && (
        <GameHistoryModal
          playerCount={tab === 'all' ? null : tab}
          userId={member.id}
          title={tab === 'all' ? name : `${name} · ${tab} Oyunculu`}
          onClose={() => setShowAllGames(false)}
        />
      )}
      {showLeague && <Leaderboard onClose={() => setShowLeague(false)} />}

      {showFriendConfirm &&
        relation !== undefined &&
        createPortal(
          (() => {
            const copy = friendDialogCopy(relation, name);
            return (
              <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
                <div
                  ref={friendConfirmRef}
                  role="dialog"
                  aria-modal="true"
                  aria-label={copy.title}
                  tabIndex={-1}
                  className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
                >
                  <p className="text-base font-bold text-text font-sans">{copy.title}</p>
                  <p className="text-sm text-text font-sans leading-relaxed">{copy.message}</p>
                  <div className="flex gap-2 mt-1">
                    <button
                      onClick={handleFriendAction}
                      disabled={friendBusy}
                      className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                    >
                      {friendBusy ? '...' : copy.action}
                    </button>
                    <button
                      onClick={() => setShowFriendConfirm(false)}
                      disabled={friendBusy}
                      className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                    >
                      Vazgeç
                    </button>
                  </div>
                </div>
              </div>
            );
          })(),
          document.body,
        )}

      {friendResultMsg &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={friendResultRef}
              role="dialog"
              aria-modal="true"
              aria-label="Arkadaşlık durumu"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative"
            >
              <button
                onClick={() => setFriendResultMsg(null)}
                aria-label="Kapat"
                className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
              >
                ✕
              </button>
              <p className="text-sm text-text font-sans leading-relaxed pr-6">{friendResultMsg}</p>
              <button
                onClick={() => setFriendResultMsg(null)}
                className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Tamam
              </button>
            </div>
          </div>,
          document.body,
        )}
    </Modal>
  );
}
