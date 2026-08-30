// Kelimeki — herhangi bir oyuncunun salt-okunur skor kartı (Admin Paneli >
// Üyeler ve k-lig'de bir satıra tıklanınca açılır)
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { GameHistoryModal } from './GameHistoryModal';
import { Leaderboard } from './Leaderboard';
import { KLigMark } from './KLigMark';
import { RankSeal } from './RankSeal';
import { RankInfoModal } from './RankInfoModal';
import { tierFor } from '../utils/leagueRank';
import { HowToRegIcon, PersonAddIcon } from './RelationIcons';
import { useAuth } from '../hooks/useAuth';
import { useModalA11y } from '../hooks/useModalA11y';
import {
  fetchAdminMemberActivityLog,
  fetchFriendRelation,
  fetchMyLeaderboardRank,
  fetchPlayerStats,
  fetchProfileAgeGender,
  removeFriend,
  respondFriendRequest,
  sendFriendRequest,
} from '../lib/api';
import type {
  AdminMemberActivityLogRow,
  FriendRelation,
  MyLeaderboardRank,
  PlayerStats,
} from '../lib/database.types';
import { type TabKey, SCORE_TABS, ScoreTabsBar, ScoreStatsSection } from './ScoreStatsSection';
import { formatAgeGender, shortDisplayName } from '../utils/profileFields';

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
  /** Yalnızca Admin Paneli > Üyeler'den açılınca true — kartın en altına
   * bu üyenin (oynadığı oyunlar hariç) kritik hesap geçmişini gösteren
   * "Kayıtlar" bölümünü ekler (bkz. `admin_get_member_activity_log`). */
  isAdminView?: boolean;
}

const ACTIVITY_LOG_ICON: Record<AdminMemberActivityLogRow['kind'], string> = {
  signup: '👤',
  ban: '🚫',
  unban: '✅',
  feedback_user: '✉️',
  feedback_admin: '📨',
  feedback_replied: '↩️',
  report_received: '🚩',
  report_withdrawn: '↩️',
};

function fmtLogDate(iso: string) {
  const d = new Date(iso);
  const date = d.toLocaleDateString('tr-TR');
  const time = d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
  return `${date} ${time}`;
}


// Skor kartı herkese açık olduğundan (k-lig'den herkes başkasının
// kartını açabilir) tam ad/soyad değil, oyun içindekiyle aynı kısa kimlik
// gösterilir — nickname yoksa sadece isim, soyadı hiç kullanılmaz.
function memberDisplayName(m: PlayerSummary) {
  return shortDisplayName(m, 'Oyuncu');
}

// k-lig'den herhangi birinin kartını açınca arkadaş ekleyebilmek için.
// İkon ilişkiye göre değişir: arkadaşsa yeşil how_to_reg (dokununca çıkarma
// onayı), değilse mavi person_add (duruma göre ekleme/kabul/iptal onayı).
// Dört dalın DÖRDÜ de önce bir onay diyaloğu açar. Bkz. RelationIcons.tsx.
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

export function PlayerScoreCard({ member, onClose, isAdminView }: PlayerScoreCardProps) {
  const { user } = useAuth();
  const [statsByTab, setStatsByTab] = useState<
    Record<TabKey, PlayerStats | null | undefined>
  >({ all: undefined, 2: undefined, 4: undefined });
  const [tab, setTab] = useState<TabKey>('all');
  const [showAllGames, setShowAllGames] = useState(false);
  const [showLeague, setShowLeague] = useState(false);
  const [showRankInfo, setShowRankInfo] = useState(false);
  const [rank, setRank] = useState<MyLeaderboardRank | null>(null);
  // "Y:59/C:E" satırı — `profiles` RLS'i başkasının satırını okutmadığından
  // ayrı bir RPC'den gelir (bkz. `fetchProfileAgeGender`); yüklenene kadar
  // ya da veri girilmemişse satır hiç çizilmez.
  const [ageGenderLabel, setAgeGenderLabel] = useState('');
  const [relation, setRelation] = useState<FriendRelation | null | undefined>(undefined);
  const [showFriendConfirm, setShowFriendConfirm] = useState(false);
  const [friendBusy, setFriendBusy] = useState(false);
  const [friendResultMsg, setFriendResultMsg] = useState<string | null>(null);
  const [activityLog, setActivityLog] = useState<AdminMemberActivityLogRow[] | null | undefined>(undefined);
  const friendConfirmRef = useModalA11y(showFriendConfirm, () => setShowFriendConfirm(false));
  const friendResultRef = useModalA11y(!!friendResultMsg, () => setFriendResultMsg(null));

  useEffect(() => {
    let cancelled = false;
    for (const { key } of SCORE_TABS) {
      fetchPlayerStats(key, member.id).then((s) => {
        if (!cancelled) setStatsByTab((cur) => ({ ...cur, [key]: s }));
      });
    }
    fetchMyLeaderboardRank(member.id).then((r) => {
      if (!cancelled) setRank(r);
    });
    fetchProfileAgeGender(member.id).then(({ age, gender }) => {
      if (!cancelled) setAgeGenderLabel(formatAgeGender(age, gender));
    });
    return () => {
      cancelled = true;
    };
  }, [member.id]);

  useEffect(() => {
    if (!isAdminView) return;
    let cancelled = false;
    setActivityLog(undefined);
    fetchAdminMemberActivityLog(member.id).then((rows) => {
      if (!cancelled) setActivityLog(rows.length ? rows : null);
    });
    return () => {
      cancelled = true;
    };
  }, [isAdminView, member.id]);

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
  // Rütbe mührü — ScoreCard'daki aynı kural: GÜNCEL puandan türetilir
  // (düşmeli sürüm); Genel istatistik yüklenene kadar gizli; modal
  // başlığının sağında, dokununca RankInfoModal.
  const rankTier = statsByTab.all !== undefined ? tierFor(statsByTab.all?.total_score) : null;

  return (
    <Modal
      title="Skor Kartı"
      onClose={onClose}
      headerCenter={
        rankTier ? (
          <button
            type="button"
            onClick={() => setShowRankInfo(true)}
            aria-label={`Rütbe: ${rankTier.name} — bilgi için dokun`}
            className="shrink-0 leading-none active:scale-90 transition-transform"
          >
            <RankSeal tier={rankTier} size={34} />
          </button>
        ) : undefined
      }
    >
      <div className="mb-4 flex items-center gap-3">
        <Avatar url={member.avatar_url ?? undefined} name={name} size={44} />
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            {/* Ad + mühür AYRI bir sarmalayıcıda (`gap-1` = 4px, 19 Ağustos
                2026): dıştaki `gap-2` arkadaşlık ikonunu ismin/mührün
                grubundan ayırıyor — ikisi tek kapta olsaydı mührü isme
                yaklaştırmak ikonu da yaklaştırırdı. */}
            <div className="flex items-center gap-1 min-w-0">
              <div className="text-base font-bold text-text truncate">{name}</div>
              {/* Rütbe mührü — ScoreCard'daki aynı karar (18 Ağustos 2026):
                  başlıktaki 34px'lik dokunulabilir mühür KALIR, bu yalnızca
                  ismin yanındaki rozettir. */}
              {rankTier && <RankSeal tier={rankTier} size={20} className="shrink-0" />}
            </div>
            {showFriendButton && (
            <button
              type="button"
              onClick={() => setShowFriendConfirm(true)}
              aria-label={relation === 'accepted' ? 'Arkadaşlıktan çıkar' : 'Arkadaş ekle'}
              /* Yuvarlak rozet (zemin+çerçeve) KALDIRILDI — port kapsız
                 çiziyor. Renk `currentColor` üzerinden SVG'ye iniyor.
                 Arkadaş durumu burada BİLİNÇLİ olarak yeşil `how_to_reg`
                 (kişi+onay), listelerdeki kırmızı `person_remove` DEĞİL —
                 kullanıcı kararı: isim hizasında duran bu simge bir aksiyon
                 sütunu değil, kimliğin yanındaki bir durum rozeti gibi
                 okunuyor ve "adam-" orada iyi durmuyor. Dokunuş yine de
                 çıkarma onayını açar (bkz. RelationIcons.tsx). */
              className={`shrink-0 leading-none active:scale-90 transition-transform ${
                relation === 'accepted' ? 'text-green' : 'text-accent'
              }`}
            >
              {relation === 'accepted' ? <HowToRegIcon /> : <PersonAddIcon />}
            </button>
          )}
          </div>
          {/* Yaş/cinsiyet — ismin ALTINDA, `ScoreCard`'daki (kendi kartı)
              satırla birebir aynı biçim ve sınıflar. Arkadaşlık ikonunun
              olduğu satırın DIŞINDA duruyor ki ikon hizası bozulmasın. */}
          {ageGenderLabel && (
            <div className="text-xs font-mono text-muted">{ageGenderLabel}</div>
          )}
        </div>
        <button
          type="button"
          onClick={() => setShowLeague(true)}
          aria-label="k-lig sıralamasını göster"
          className="text-right shrink-0 active:opacity-70 transition-opacity"
        >
          <div className="flex items-center justify-end gap-1 text-xs uppercase tracking-[1px] text-muted font-mono">
            <KLigMark height={16} className="inline-block" />
            <span className="w-3.5 h-3.5 rounded-full border border-muted text-muted flex items-center justify-center text-[9px] leading-none font-bold">
              ?
            </span>
          </div>
          <div className="font-mono text-sm font-bold text-accent">
            {rank && (
              <>
                #{rank.rank}
                <span className="mx-0.5">·</span>
              </>
            )}
            {totalScore}
            <span className="text-xs font-normal text-muted"> puan</span>
          </div>
        </button>
      </div>

      <ScoreTabsBar tab={tab} onChange={setTab} statsByTab={statsByTab} />

      <ScoreStatsSection
        stats={stats}
        emptyText={
          tab === 'all'
            ? 'Bu oyuncunun hiç oyun kaydı yok.'
            : `Bu oyuncunun ${tab} oyunculu oyun kaydı yok.`
        }
      />

      <div className="text-center mt-1.5">
        <button
          onClick={() => setShowAllGames(true)}
          className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-accent active:opacity-70 transition-opacity"
        >
          Tüm Geçmiş Oyunlar
        </button>
      </div>

      {isAdminView && (
        <div className="mt-4 pt-3 border-t border-border/60">
          <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono mb-1.5">
            Kayıtlar
          </div>
          {activityLog === undefined ? (
            <p className="text-muted text-xs font-mono text-center py-3">Yükleniyor…</p>
          ) : activityLog === null ? (
            <p className="text-muted text-[10px] font-mono text-center py-2">
              Bu üye için henüz bir kayıt yok.
            </p>
          ) : (
            <ul className="flex flex-col gap-1.5 max-h-56 overflow-y-auto pr-1">
              {activityLog.map((entry, i) => (
                <li
                  key={`${entry.kind}-${entry.created_at}-${i}`}
                  className="flex items-start gap-2 text-[11px] font-mono"
                >
                  <span className="shrink-0" aria-hidden>
                    {ACTIVITY_LOG_ICON[entry.kind]}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="text-text font-bold">{entry.title}</span>
                    {entry.detail && (
                      <span className="text-muted"> — {entry.detail}</span>
                    )}
                  </span>
                  <span className="shrink-0 text-muted whitespace-nowrap">{fmtLogDate(entry.created_at)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {showAllGames && (
        <GameHistoryModal
          playerCount={tab === 'all' ? null : tab}
          userId={member.id}
          targetName={name}
          title={tab === 'all' ? name : `${name} · ${tab} Oyunculu`}
          onClose={() => setShowAllGames(false)}
        />
      )}
      {showLeague && <Leaderboard onClose={() => setShowLeague(false)} />}

      {showRankInfo && rankTier && (
        <RankInfoModal
          tier={rankTier}
          totalScore={totalScore}
          bonusPoints={statsByTab.all?.bonus_points ?? 0}
          onClose={() => setShowRankInfo(false)}
        />
      )}

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
                className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none tap-expand w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
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
