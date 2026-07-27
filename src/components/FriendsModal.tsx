// Kelimeki — Arkadaşlar modalı: mevcut kullanıcıyı arayıp ekleme (e-postasız,
// uygulama içi istek/kabul) + kalıcı davet linkini WhatsApp/SMS/DM gibi
// kanallardan paylaşarak henüz üye olmayanları da davet etme (asıl büyüme
// mekanizması — bkz. CLAUDE.md "Arkadaşlık Sistemi").
import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { PlayerScoreCard, type PlayerSummary } from './PlayerScoreCard';
import { useModalA11y } from '../hooks/useModalA11y';
import {
  createFriendInviteLink,
  fetchFriends,
  fetchIncomingFriendRequests,
  removeFriend,
  respondFriendRequest,
  searchUsersForFriend,
  sendFriendRequest,
} from '../lib/api';
import type { FriendRow, FriendSearchResult, IncomingFriendRequest } from '../lib/database.types';

/** Bir arkadaşı `PlayerScoreCard` açabilecek şekle çevirir — henüz canlı oyun
 * olmadığından arkadaş eklemenin somut faydası şu an bu: kişinin skor
 * kartına bakabilmek. */
function friendToPlayerSummary(f: FriendRow): PlayerSummary {
  return {
    id: f.friend_id,
    username: null,
    first_name: null,
    last_name: null,
    display_name: f.name,
    avatar_url: f.avatar_url,
  };
}

interface FriendsModalProps {
  onClose: () => void;
  /** İlk açılışta hangi sekmenin görüneceği — `UserMenu`'den bir bekleyen istek rozetine tıklanınca "requests" ile açılır. */
  initialTab?: Tab;
}

type Tab = 'friends' | 'requests' | 'search';

function buildInviteUrl(token: string): string {
  return `${window.location.origin}/davet/${token}`;
}

const INVITE_SHARE_TEXT = "Kelimeki'de birlikte kelime oyunu oynayalım!";

const rowCls = 'flex items-center gap-2.5 bg-bg rounded-md px-2.5 py-2';
const listCls = 'flex flex-col gap-1.5';
const nameCls = 'flex-1 min-w-0 text-sm text-text font-bold truncate';
const smallBtn =
  'shrink-0 btn-raised rounded-md py-1.5 px-3 text-[10px] font-bold uppercase tracking-[0.5px] active:scale-[0.97] transition-transform disabled:opacity-50';

export function FriendsModal({ onClose, initialTab = 'friends' }: FriendsModalProps) {
  const [tab, setTab] = useState<Tab>(initialTab);
  const [friends, setFriends] = useState<FriendRow[] | null>(null);
  const [requests, setRequests] = useState<IncomingFriendRequest[] | null>(null);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<FriendSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [inviteStatus, setInviteStatus] = useState<'idle' | 'busy' | 'copied'>('idle');
  const [selectedFriend, setSelectedFriend] = useState<PlayerSummary | null>(null);
  const [confirmRemove, setConfirmRemove] = useState<FriendRow | null>(null);
  const [removeResultMsg, setRemoveResultMsg] = useState<string | null>(null);
  const confirmRemoveRef = useModalA11y(!!confirmRemove, () => setConfirmRemove(null));
  const removeResultRef = useModalA11y(!!removeResultMsg, () => setRemoveResultMsg(null));
  const [confirmReject, setConfirmReject] = useState<IncomingFriendRequest | null>(null);
  const [rejectResultMsg, setRejectResultMsg] = useState<string | null>(null);
  const confirmRejectRef = useModalA11y(!!confirmReject, () => setConfirmReject(null));
  const rejectResultRef = useModalA11y(!!rejectResultMsg, () => setRejectResultMsg(null));
  const [confirmCancel, setConfirmCancel] = useState<FriendSearchResult | null>(null);
  const [cancelResultMsg, setCancelResultMsg] = useState<string | null>(null);
  const confirmCancelRef = useModalA11y(!!confirmCancel, () => setConfirmCancel(null));
  const cancelResultRef = useModalA11y(!!cancelResultMsg, () => setCancelResultMsg(null));

  const reloadFriends = () => void fetchFriends().then(setFriends);
  const reloadRequests = () => void fetchIncomingFriendRequests().then(setRequests);

  useEffect(() => {
    reloadFriends();
    reloadRequests();
  }, []);

  // Arama girdisini hafifçe geciktir (her tuş vuruşunda RPC çağırmamak için).
  useEffect(() => {
    if (query.trim().length < 2) {
      setResults([]);
      setSearching(false);
      return;
    }
    setSearching(true);
    const t = setTimeout(() => {
      void searchUsersForFriend(query.trim()).then((r) => {
        setResults(r);
        setSearching(false);
      });
    }, 350);
    return () => clearTimeout(t);
  }, [query]);

  const handleSend = async (id: string) => {
    setBusyId(id);
    try {
      await sendFriendRequest(id);
      setResults((r) => r.map((u) => (u.id === id ? { ...u, relation: 'pending_outgoing' } : u)));
    } catch (err) {
      console.error('[Kelimeki] arkadaşlık isteği hatası:', err);
    } finally {
      setBusyId(null);
    }
  };

  const handleRespond = async (requesterId: string, accept: boolean) => {
    setBusyId(requesterId);
    try {
      await respondFriendRequest(requesterId, accept);
      reloadRequests();
      if (accept) reloadFriends();
    } catch (err) {
      console.error('[Kelimeki] istek yanıtlama hatası:', err);
    } finally {
      setBusyId(null);
    }
  };

  const handleConfirmRemove = async () => {
    if (!confirmRemove) return;
    const friendId = confirmRemove.friend_id;
    setBusyId(friendId);
    try {
      await removeFriend(friendId);
      reloadFriends();
      setRemoveResultMsg('Arkadaşlıktan çıkarıldı.');
    } catch (err) {
      console.error('[Kelimeki] arkadaş çıkarma hatası:', err);
    } finally {
      setBusyId(null);
      setConfirmRemove(null);
    }
  };

  const handleConfirmReject = async () => {
    if (!confirmReject) return;
    const requesterId = confirmReject.requester_id;
    setBusyId(requesterId);
    try {
      await respondFriendRequest(requesterId, false);
      reloadRequests();
      setRejectResultMsg('İstek reddedildi.');
    } catch (err) {
      console.error('[Kelimeki] istek reddetme hatası:', err);
    } finally {
      setBusyId(null);
      setConfirmReject(null);
    }
  };

  const handleConfirmCancel = async () => {
    if (!confirmCancel) return;
    const id = confirmCancel.id;
    setBusyId(id);
    try {
      await removeFriend(id); // gönderilen isteği iptal et
      setResults((r) => r.map((u) => (u.id === id ? { ...u, relation: null } : u)));
      setCancelResultMsg('Arkadaşlık isteği iptal edildi.');
    } catch (err) {
      console.error('[Kelimeki] istek iptal hatası:', err);
    } finally {
      setBusyId(null);
      setConfirmCancel(null);
    }
  };

  const handleInvite = async () => {
    setInviteStatus('busy');
    const token = await createFriendInviteLink();
    if (!token) {
      setInviteStatus('idle');
      return;
    }
    const url = buildInviteUrl(token);

    if (navigator.share) {
      try {
        await navigator.share({ title: 'Kelimeki', text: INVITE_SHARE_TEXT, url });
      } catch {
        // Kullanıcı paylaşım sayfasını iptal etti — sessizce geç.
      }
      setInviteStatus('idle');
      return;
    }
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(`${INVITE_SHARE_TEXT}\n${url}`);
      setInviteStatus('copied');
      setTimeout(() => setInviteStatus('idle'), 1800);
      return;
    }
    setInviteStatus('idle');
  };

  const tabBtn = (t: Tab, label: string, badge?: number) => (
    <button
      onClick={() => setTab(t)}
      className={`flex-1 py-2 text-[11px] font-mono font-bold uppercase tracking-[0.5px] rounded-md transition-colors flex items-center justify-center gap-1.5 ${
        tab === t ? 'bg-accent text-white' : 'text-muted hover:text-text'
      }`}
    >
      {label}
      {!!badge && (
        <span className="min-w-[16px] h-4 px-1 rounded-full bg-red text-white text-[9px] font-bold flex items-center justify-center leading-none">
          {badge}
        </span>
      )}
    </button>
  );

  return (
    <Modal title="Arkadaşlar" onClose={onClose}>
      <div className="flex flex-col gap-3">
        <button
          onClick={handleInvite}
          disabled={inviteStatus === 'busy'}
          className="btn-raised bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50 flex items-center justify-center gap-2"
        >
          <span aria-hidden>🔗</span>
          {inviteStatus === 'copied' ? 'Link Kopyalandı!' : 'Arkadaşını Davet Et'}
        </button>
        <p className="text-[10px] text-muted font-mono text-center -mt-1">
          Kelimeki'de henüz üye olmayan arkadaşların için de çalışır.
        </p>

        <div className="flex gap-1 bg-bg border border-border rounded-md p-1">
          {tabBtn('friends', 'Arkadaşlarım', 0)}
          {tabBtn('requests', 'İstekler', requests?.length ?? 0)}
          {tabBtn('search', 'Ara & Ekle')}
        </div>

        {tab === 'friends' && (
          <div className={listCls}>
            {friends === null ? (
              <p className="text-muted text-xs font-mono py-4 text-center">Yükleniyor…</p>
            ) : friends.length === 0 ? (
              <p className="text-muted text-xs font-mono py-4 text-center">
                Henüz arkadaşın yok — "Ara & Ekle" sekmesinden ya da yukarıdaki davet linkiyle ekleyebilirsin.
              </p>
            ) : (
              friends.map((f) => (
                <div key={f.friend_id} className={rowCls}>
                  <button
                    type="button"
                    onClick={() => setSelectedFriend(friendToPlayerSummary(f))}
                    className="flex-1 min-w-0 flex items-center gap-2.5 text-left active:opacity-70 transition-opacity"
                  >
                    <Avatar url={f.avatar_url} name={f.name} size={32} />
                    <span className={nameCls}>{f.name}</span>
                  </button>
                  <button
                    className={`${smallBtn} btn-raised-neutral bg-panel border border-border text-muted hover:text-red`}
                    disabled={busyId === f.friend_id}
                    onClick={() => setConfirmRemove(f)}
                  >
                    Çıkar
                  </button>
                </div>
              ))
            )}
          </div>
        )}

        {tab === 'requests' && (
          <div className={listCls}>
            {requests === null ? (
              <p className="text-muted text-xs font-mono py-4 text-center">Yükleniyor…</p>
            ) : requests.length === 0 ? (
              <p className="text-muted text-xs font-mono py-4 text-center">Bekleyen istek yok.</p>
            ) : (
              requests.map((r) => (
                <div key={r.requester_id} className={rowCls}>
                  <Avatar url={r.avatar_url} name={r.name} size={32} />
                  <span className={nameCls}>{r.name}</span>
                  <div className="flex gap-1.5 shrink-0">
                    <button
                      className={`${smallBtn} bg-accent text-white`}
                      disabled={busyId === r.requester_id}
                      onClick={() => handleRespond(r.requester_id, true)}
                    >
                      Kabul Et
                    </button>
                    <button
                      className={`${smallBtn} btn-raised-neutral bg-panel border border-border text-muted`}
                      disabled={busyId === r.requester_id}
                      onClick={() => setConfirmReject(r)}
                    >
                      Reddet
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {tab === 'search' && (
          <div className="flex flex-col gap-2">
            <input
              className="w-full bg-bg border border-border rounded-md px-3 py-2 text-sm text-text outline-none focus:border-accent transition-colors"
              type="text"
              placeholder="İsim ya da takma ad ara…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              autoFocus
            />
            <div className={`${listCls} min-h-[40px]`}>
              {searching ? (
                <p className="text-muted text-xs font-mono py-4 text-center">Aranıyor…</p>
              ) : query.trim().length >= 2 && results.length === 0 ? (
                <p className="text-muted text-xs font-mono py-4 text-center">
                  Kimse bulunamadı — Kelimeki'de değilse yukarıdaki davet linkini gönderebilirsin.
                </p>
              ) : (
                results.map((u) => (
                  <div key={u.id} className={rowCls}>
                    <Avatar url={u.avatar_url} name={u.name} size={32} />
                    <span className={nameCls}>{u.name}</span>
                    {u.relation === 'accepted' ? (
                      <span className="shrink-0 text-[10px] font-mono text-muted uppercase tracking-[0.5px]">
                        Arkadaşsınız
                      </span>
                    ) : u.relation === 'pending_outgoing' ? (
                      <button
                        type="button"
                        className="shrink-0 text-[10px] font-mono text-muted uppercase tracking-[0.5px] underline underline-offset-2 active:opacity-70 transition-opacity"
                        disabled={busyId === u.id}
                        onClick={() => setConfirmCancel(u)}
                      >
                        İstek Gönderildi
                      </button>
                    ) : u.relation === 'pending_incoming' ? (
                      <button
                        className={`${smallBtn} bg-accent text-white`}
                        disabled={busyId === u.id}
                        onClick={() => handleRespond(u.id, true)}
                      >
                        Kabul Et
                      </button>
                    ) : (
                      <button
                        className={`${smallBtn} bg-accent text-white`}
                        disabled={busyId === u.id}
                        onClick={() => handleSend(u.id)}
                      >
                        Ekle
                      </button>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>
      {selectedFriend && (
        <PlayerScoreCard member={selectedFriend} onClose={() => setSelectedFriend(null)} />
      )}

      {confirmRemove &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={confirmRemoveRef}
              role="dialog"
              aria-modal="true"
              aria-label="Arkadaşlıktan Çıkar"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
            >
              <p className="text-base font-bold text-text font-sans">Arkadaşlıktan Çıkar</p>
              <p className="text-sm text-text font-sans leading-relaxed">
                {confirmRemove.name} ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?
              </p>
              <div className="flex gap-2 mt-1">
                <button
                  onClick={handleConfirmRemove}
                  disabled={busyId === confirmRemove.friend_id}
                  className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                >
                  {busyId === confirmRemove.friend_id ? '...' : 'Çıkar'}
                </button>
                <button
                  onClick={() => setConfirmRemove(null)}
                  disabled={busyId === confirmRemove.friend_id}
                  className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                >
                  Vazgeç
                </button>
              </div>
            </div>
          </div>,
          document.body,
        )}

      {removeResultMsg &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={removeResultRef}
              role="dialog"
              aria-modal="true"
              aria-label="Arkadaşlık durumu"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative"
            >
              <button
                onClick={() => setRemoveResultMsg(null)}
                aria-label="Kapat"
                className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
              >
                ✕
              </button>
              <p className="text-sm text-text font-sans leading-relaxed pr-6">{removeResultMsg}</p>
              <button
                onClick={() => setRemoveResultMsg(null)}
                className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Tamam
              </button>
            </div>
          </div>,
          document.body,
        )}

      {confirmReject &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={confirmRejectRef}
              role="dialog"
              aria-modal="true"
              aria-label="İsteği Reddet"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
            >
              <p className="text-base font-bold text-text font-sans">İsteği Reddet</p>
              <p className="text-sm text-text font-sans leading-relaxed">
                {confirmReject.name} oyuncusunun arkadaşlık isteğini reddetmek mi istiyorsunuz?
              </p>
              <div className="flex gap-2 mt-1">
                <button
                  onClick={handleConfirmReject}
                  disabled={busyId === confirmReject.requester_id}
                  className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                >
                  {busyId === confirmReject.requester_id ? '...' : 'Reddet'}
                </button>
                <button
                  onClick={() => setConfirmReject(null)}
                  disabled={busyId === confirmReject.requester_id}
                  className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                >
                  Vazgeç
                </button>
              </div>
            </div>
          </div>,
          document.body,
        )}

      {rejectResultMsg &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={rejectResultRef}
              role="dialog"
              aria-modal="true"
              aria-label="Arkadaşlık durumu"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative"
            >
              <button
                onClick={() => setRejectResultMsg(null)}
                aria-label="Kapat"
                className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
              >
                ✕
              </button>
              <p className="text-sm text-text font-sans leading-relaxed pr-6">{rejectResultMsg}</p>
              <button
                onClick={() => setRejectResultMsg(null)}
                className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
              >
                Tamam
              </button>
            </div>
          </div>,
          document.body,
        )}

      {confirmCancel &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={confirmCancelRef}
              role="dialog"
              aria-modal="true"
              aria-label="İsteği İptal Et"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
            >
              <p className="text-base font-bold text-text font-sans">İsteği İptal Et</p>
              <p className="text-sm text-text font-sans leading-relaxed">
                {confirmCancel.name} oyuncusuna gönderdiğin arkadaşlık isteğini iptal etmek istiyor musun?
              </p>
              <div className="flex gap-2 mt-1">
                <button
                  onClick={handleConfirmCancel}
                  disabled={busyId === confirmCancel.id}
                  className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                >
                  {busyId === confirmCancel.id ? '...' : 'İptal Et'}
                </button>
                <button
                  onClick={() => setConfirmCancel(null)}
                  disabled={busyId === confirmCancel.id}
                  className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
                >
                  Vazgeç
                </button>
              </div>
            </div>
          </div>,
          document.body,
        )}

      {cancelResultMsg &&
        createPortal(
          <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
            <div
              ref={cancelResultRef}
              role="dialog"
              aria-modal="true"
              aria-label="Arkadaşlık durumu"
              tabIndex={-1}
              className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative"
            >
              <button
                onClick={() => setCancelResultMsg(null)}
                aria-label="Kapat"
                className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
              >
                ✕
              </button>
              <p className="text-sm text-text font-sans leading-relaxed pr-6">{cancelResultMsg}</p>
              <button
                onClick={() => setCancelResultMsg(null)}
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
