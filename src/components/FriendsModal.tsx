// Kelimeki — Arkadaşlar modalı: mevcut kullanıcıyı arayıp ekleme (e-postasız,
// uygulama içi istek/kabul) + kalıcı davet linkini WhatsApp/SMS/DM gibi
// kanallardan paylaşarak henüz üye olmayanları da davet etme (asıl büyüme
// mekanizması — bkz. `docs/decisions/friends.md`).
import { useCallback, useEffect, useRef, useState } from 'react';
import { LoadingNote } from './LoadingNote';
import { createPortal } from 'react-dom';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { CountBadge } from './CountBadge';
import { PlayerScoreCard, type PlayerSummary } from './PlayerScoreCard';
import { useModalA11y } from '../hooks/useModalA11y';
import {
  createFriendInviteLink,
  fetchFriendRelation,
  fetchFriends,
  fetchMyChatModeration,
  fetchIncomingFriendRequests,
  listUsersForFriend,
  removeFriend,
  respondFriendRequest,
  searchUsersForFriend,
  sendFriendRequest,
} from '../lib/api';
import type { FriendRow, FriendSearchResult, IncomingFriendRequest } from '../lib/database.types';
import { PersonAddIcon, PersonRemoveIcon, HourglassIcon, HowToRegIcon } from './RelationIcons';
import { FriendModerationModal, type FriendModerationTarget } from './FriendModerationModal';
import { trCompare } from '../utils/turkish';
import { RankSeal } from './RankSeal';
import { useRankScores } from '../hooks/useRankScores';

/** Bir arkadaşı `PlayerScoreCard` açabilecek şekle çevirir — henüz canlı oyun
 * olmadığından arkadaş eklemenin somut faydası şu an bu: kişinin skor
 * kartına bakabilmek. */
/** Bu modaldeki ÜÇ listenin de (Arkadaşlarım / İstekler / Ara & Ekle) satırı
 * aynı üç alanı taşıyor; `PlayerScoreCard` yalnızca bunları istiyor. Kısa
 * kimlik kuralı gereği ad/soyad hiç doldurulmuyor (`display_name` zaten
 * sunucuda o kuralla hesaplanmış görünen ad). */
function toPlayerSummary(
  id: string,
  name: string,
  avatarUrl: string | null,
): PlayerSummary {
  return {
    id,
    username: null,
    first_name: null,
    last_name: null,
    display_name: name,
    avatar_url: avatarUrl,
  };
}

// Aşağıdaki iki bileşen, bu dosyadaki dört neredeyse birebir aynı onay/sonuç
// modalını (Arkadaşlıktan Çıkar/İsteği Reddet/İsteği İptal Et + üçünün
// "Tamam" sonuç modalı) tek bir yerde toplar (kod incelemesi, dead-code/
// tekrar bulgusu). `dialogRef`, çağıranın kendi `useModalA11y` çağrısından
// (odak hapsi/Escape/dialog-yığını için, koşullu render edilen bir dialog
// içinde çağrılamaz — hep üst bileşende kalmalı) geldiğinden prop olarak alınır.
function ConfirmDialog({
  dialogRef,
  ariaLabel,
  title,
  message,
  confirmLabel,
  busy,
  onConfirm,
  onCancel,
}: {
  dialogRef: React.RefObject<HTMLDivElement>;
  ariaLabel: string;
  title: string;
  message: string;
  confirmLabel: string;
  busy: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return createPortal(
    <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label={ariaLabel}
        tabIndex={-1}
        className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none"
      >
        <p className="text-base font-bold text-text font-sans">{title}</p>
        <p className="text-sm text-text font-sans leading-relaxed">{message}</p>
        <div className="flex gap-2 mt-1">
          <button
            onClick={onConfirm}
            disabled={busy}
            className="btn-raised flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            {busy ? '...' : confirmLabel}
          </button>
          <button
            onClick={onCancel}
            disabled={busy}
            className="btn-raised-neutral flex-1 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            Vazgeç
          </button>
        </div>
      </div>
    </div>,
    document.body,
  );
}

function InfoDialog({
  dialogRef,
  message,
  onClose,
}: {
  dialogRef: React.RefObject<HTMLDivElement>;
  message: string;
  onClose: () => void;
}) {
  return createPortal(
    <div className="fixed inset-0 z-[200] flex items-center justify-center px-4">
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label="Arkadaşlık durumu"
        tabIndex={-1}
        className="w-full max-w-sm bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col gap-4 outline-none relative"
      >
        <button
          onClick={onClose}
          aria-label="Kapat"
          className="absolute top-3 right-3 text-muted hover:text-text text-lg leading-none tap-expand w-7 h-7 flex items-center justify-center rounded active:scale-90 transition-transform"
        >
          ✕
        </button>
        <p className="text-sm text-text font-sans leading-relaxed pr-6">{message}</p>
        <button
          onClick={onClose}
          className="btn-raised py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
        >
          Tamam
        </button>
      </div>
    </div>,
    document.body,
  );
}

interface FriendsModalProps {
  onClose: () => void;
  /** İlk açılışta hangi sekmenin görüneceği — `UserMenu`'den bir bekleyen istek rozetine tıklanınca "requests" ile açılır. */
  initialTab?: Tab;
}

type Tab = 'friends' | 'requests' | 'search';

/**
 * Davet linki `?ref=arkadas` TAŞIMAK ZORUNDA (21 Ağustos 2026, ROADMAP #7) —
 * Setup'taki "Paylaş" linkiyle (`shareLink.ts`) AYNI etiket, çünkü ikisi de
 * aynı kanal: arkadaş daveti.
 *
 * NEDEN: admin panelindeki Kaynak Hunisi'nin iki ucu bu etiket olmadan AYNI
 * popülasyonu ölçmüyordu. Ziyaretçi ucu yalnızca Setup'ın paylaş linkiyle
 * gelenleri sayıyor, üye ucu ise ağırlıkla BU path'ten (`/davet/:token`)
 * gelenleri — o link etiketsiz olduğundan davetle gelip üye olan herkes
 * `direkt` satırına düşüyor, yani gerçek doğrudan trafiği şişiriyordu ve
 * `arkadas` satırının "%100 dönüşümü" bir ölçüm değil tesadüftü.
 *
 * ⚠ Tek başına yetmez: etiketi YAKALAYAN kod `boot.tsx`te, route'tan ÖNCE
 * olmak zorunda — bu route `App`'i hiç mount etmiyor (bkz. oradaki not).
 * Etiket first-touch olduğundan zaten `instagram` gibi bir kaynakla gelmiş
 * bir cihazın kaydını EZMEZ.
 */
function buildInviteUrl(token: string): string {
  return `${window.location.origin}/davet/${token}?ref=arkadas`;
}

const INVITE_SHARE_TEXT = "Kelimeki'de birlikte kelime oyunu oynayalım!";

// Arama kutusu boşken gösterilen tüm-üyeler listesinin sayfa boyutu —
// `Leaderboard`'daki PAGE_SIZE ile aynı lazy-load deseni.
const ALL_USERS_PAGE_SIZE = 20;

const rowCls = 'flex items-center gap-2.5 bg-bg rounded-md px-2.5 py-2';
const listCls = 'flex flex-col gap-1.5';
const nameCls = 'min-w-0 text-sm text-text font-bold truncate';
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
  // Hem "Arkadaşlarım" satırı (FriendRow) hem "Ara & Ekle"deki `accepted`
  // satırı (FriendSearchResult) aynı onayı kullansın diye yapısal tip —
  // ikinci bir onay diyaloğu açmaya gerek yok.
  const [confirmRemove, setConfirmRemove] =
    useState<{ friend_id: string; name: string } | null>(null);
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
  // "Ekle" ve "Kabul Et" de onaydan geçer — metin butonları ikonlara indiği
  // için (11 Ağustos 2026) etiketsiz bir ikona kazara dokunmak artık çok daha
  // kolay; `PlayerScoreCard` zaten dört ilişki dalının HEPSİNDE onay soruyordu,
  // iki ekran arasındaki bu asimetri kapatıldı. Tek state: metin `relation`dan
  // türetiliyor (gelen isteği kabul mü, yeni istek mi).
  const [confirmAdd, setConfirmAdd] = useState<FriendSearchResult | null>(null);
  const [addResultMsg, setAddResultMsg] = useState<string | null>(null);
  const confirmAddRef = useModalA11y(!!confirmAdd, () => setConfirmAdd(null));
  const addResultRef = useModalA11y(!!addResultMsg, () => setAddResultMsg(null));

  // Arama kutusu boşken gösterilen, tüm üyelerin alfabetik/sayfalı listesi —
  // `Leaderboard`'daki IntersectionObserver tabanlı lazy-load deseniyle aynı.
  const [allUsers, setAllUsers] = useState<FriendSearchResult[] | null>(null);
  const [allUsersHasMore, setAllUsersHasMore] = useState(true);
  const [allUsersLoadingMore, setAllUsersLoadingMore] = useState(false);
  // Üç sekmedeki TÜM isimlerin rütbe mührü için tek toplu çekim
  // (`personButton` hepsini bu tek yardımcıdan okuyor). Liste büyüdükçe
  // (sonsuz kaydırma) anahtar değişip eksikler ekleniyor.
  const rankTierOf = useRankScores([
    ...(friends ?? []).map((f) => f.friend_id),
    ...(requests ?? []).map((r) => r.requester_id),
    ...results.map((u) => u.id),
    ...(allUsers ?? []).map((u) => u.id),
  ]);
  const allUsersScrollRef = useRef<HTMLDivElement | null>(null);
  const allUsersSentinelRef = useRef<HTMLDivElement | null>(null);

  const reloadFriends = () => void fetchFriends().then(setFriends);
  const reloadRequests = () => void fetchIncomingFriendRequests().then(setRequests);

  // Sessize aldığım/şikayet ettiğim kişiler — "Arkadaşlarım" satırındaki
  // 🚫/🚩 ikonunu ve `FriendModerationModal`ı besliyor. Değerler kaynak
  // oyun id'si: `mute_online_game_participant` sessizden ÇIKARIRKEN bile
  // geçerli bir ortak oyun istiyor (bkz. `fetchMyChatModeration`).
  const [moderation, setModeration] = useState<{
    muted: Map<string, string>;
    reported: Map<string, string>;
  }>({ muted: new Map(), reported: new Map() });
  const [moderationTarget, setModerationTarget] = useState<FriendModerationTarget | null>(null);
  const reloadModeration = () => void fetchMyChatModeration().then(setModeration);

  useEffect(() => {
    reloadFriends();
    reloadRequests();
    reloadModeration();
  }, []);

  // Varsayılan tab: bekleyen bir arkadaşlık isteği varsa "İstekler" açık
  // gelsin — `LiveGamesTab`'daki (bekleyen davet varsa "Oyun Davetleri")
  // BİREBİR aynı desen ve gerekçe: bekleyen iş her zaman ön plana çıkmalı,
  // kullanıcı onu bulmak için sekme aramak zorunda kalmamalı (kullanıcı
  // isteği, 4 Ağustos 2026 — rozet zinciri doğru çalışıyordu ama modal yine
  // de "Arkadaşlarım"da açılıyordu).
  //
  // Çağıran AÇIKÇA bir tab belirtmişse (`LiveGameCreateForm`'un
  // `initialTab="search"`'ü — "arkadaş eklemek için tıkla" akışı) o niyet
  // ezilmemeli: ref o durumda baştan "uygulanmış" sayılır.
  const appliedDefaultTabRef = useRef(initialTab !== 'friends');
  useEffect(() => {
    if (requests === null || appliedDefaultTabRef.current) return;
    appliedDefaultTabRef.current = true;
    if (requests.length > 0) setTab('requests');
  }, [requests]);

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

  // "Ara & Ekle" sekmesi ilk açıldığında (arama kutusu henüz boşken) tüm
  // üyeler listesinin ilk sayfasını çek.
  useEffect(() => {
    if (tab !== 'search' || allUsers !== null) return;
    void listUsersForFriend(0, ALL_USERS_PAGE_SIZE).then((page) => {
      setAllUsers([...page].sort((a, b) => trCompare(a.name, b.name)));
      setAllUsersHasMore(page.length === ALL_USERS_PAGE_SIZE);
    });
  }, [tab, allUsers]);

  const loadMoreAllUsers = useCallback(() => {
    if (allUsers === null) return;
    setAllUsersLoadingMore((already) => {
      if (already) return already;
      void listUsersForFriend(allUsers.length, ALL_USERS_PAGE_SIZE).then((page) => {
        // Sayfalar backend'in kendi sırasına göre çekiliyor ama Türkçe
        // harflerin (ç/ğ/ı/ö/ş/ü) sayfa sınırlarında yanlış collation'a göre
        // dağılmış olma ihtimaline karşı, her yeni sayfadan sonra TÜM birikmiş
        // listeyi (yalnızca son sayfayı değil) yeniden alfabetik sıralıyoruz.
        setAllUsers((cur) => [...(cur ?? []), ...page].sort((a, b) => trCompare(a.name, b.name)));
        setAllUsersHasMore(page.length === ALL_USERS_PAGE_SIZE);
        setAllUsersLoadingMore(false);
      });
      return true;
    });
  }, [allUsers]);

  useEffect(() => {
    if (tab !== 'search' || query.trim().length >= 2 || !allUsersHasMore || allUsers === null) return;
    const sentinel = allUsersSentinelRef.current;
    const root = allUsersScrollRef.current;
    if (!sentinel || !root) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) loadMoreAllUsers();
      },
      { root, rootMargin: '80px' },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [tab, query, allUsersHasMore, allUsers, loadMoreAllUsers]);

  // Bir kullanıcının ilişki durumu değiştiğinde (istek gönderildi/iptal
  // edildi/kabul edildi) hem arama sonuçları hem tüm-üyeler listesi güncel
  // kalsın — hangisi o an ekranda görünüyorsa görünsün.
  const patchRelation = (id: string, relation: FriendSearchResult['relation']) => {
    setResults((r) => r.map((u) => (u.id === id ? { ...u, relation } : u)));
    setAllUsers((r) => (r ? r.map((u) => (u.id === id ? { ...u, relation } : u)) : r));
  };

  const handleSend = async (id: string) => {
    setBusyId(id);
    try {
      const status = await sendFriendRequest(id);
      // Karşı taraftan zaten bekleyen bir istek varsa sunucu insert'i
      // doğrudan 'accepted'a çeviriyor — bu durumda UI da "İstek
      // Gönderildi" yerine gerçek durumu (arkadaş oldunuz) göstermeli.
      patchRelation(id, status === 'accepted' ? 'accepted' : 'pending_outgoing');
      if (status === 'accepted') reloadFriends();
      return status;
    } catch (err) {
      console.error('[Kelimeki] arkadaşlık isteği hatası:', err);
      return null;
    } finally {
      setBusyId(null);
    }
  };

  const handleRespond = async (requesterId: string, accept: boolean) => {
    setBusyId(requesterId);
    try {
      await respondFriendRequest(requesterId, accept);
      patchRelation(requesterId, accept ? 'accepted' : null);
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
      // Arama/tüm-üyeler listesinde de ikon anında person_add'e dönsün.
      patchRelation(friendId, null);
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

  const handleConfirmAdd = async () => {
    if (!confirmAdd) return;
    const { id, relation } = confirmAdd;
    if (relation === 'pending_incoming') {
      await handleRespond(id, true);
      setAddResultMsg('Arkadaş oldunuz.');
    } else {
      const status = await handleSend(id);
      // Karşı taraftan zaten bekleyen bir istek varsa sunucu trigger'ı
      // ilişkiyi anında 'accepted' yapar — mesaj bunu yansıtmalı.
      setAddResultMsg(
        status === 'accepted' ? 'Arkadaş oldunuz.' : 'Arkadaşlık isteğiniz iletilmiştir.',
      );
    }
    setConfirmAdd(null);
  };

  const handleConfirmCancel = async () => {
    if (!confirmCancel) return;
    const id = confirmCancel.id;
    setBusyId(id);
    try {
      await removeFriend(id); // gönderilen isteği iptal et
      patchRelation(id, null);
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

  // Arama sonuçlarında ve tüm-üyeler listesinde birebir aynı satır. Metin
  // butonları 11 Ağustos 2026'da ikonlara indirildi (bkz. RelationIcons.tsx):
  // ikon, dokunuşun NE YAPACAĞINI söyler. Dokunma hedefi 44px — ikon 20px,
  // etrafındaki görünmez alan iOS kılavuzunun asgarisini karşılıyor. Metin
  // kalktığı için `aria-label` artık tek bilgi kaynağı, boş bırakma.
  //
  // Dört dalın DÖRDÜ de önce bir onay diyaloğu açar, hiçbiri anında iş
  // yapmaz — `PlayerScoreCard`'daki `friendDialogCopy` ile aynı sözleşme.
  // `accepted` dalı pratikte ULAŞILAMAZ (bu satır yalnızca "Ara & Ekle"
  // listelerinde çiziliyor ve orası arkadaşları eliyor, bkz. `notFriend`) —
  // savunma amaçlı duruyor: silinirse bir gün eleme atlanınca arkadaşa
  // "ekle" ikonu gösterilirdi. "Arkadaşlarım" sekmesi bu satırı kullanmaz,
  // kendi çıkarma butonu var.
  const relationAction = (u: FriendSearchResult) => {
    const props =
      u.relation === 'accepted'
        ? { label: 'Arkadaşlıktan çıkar', color: 'text-red', icon: <PersonRemoveIcon />, act: () => setConfirmRemove({ friend_id: u.id, name: u.name }) }
        : u.relation === 'pending_outgoing'
          ? { label: 'İstek gönderildi — iptal et', color: 'text-muted', icon: <HourglassIcon />, act: () => setConfirmCancel(u) }
          : u.relation === 'pending_incoming'
            ? { label: 'Arkadaşlık isteğini kabul et', color: 'text-accent', icon: <HowToRegIcon />, act: () => setConfirmAdd(u) }
            : { label: 'Arkadaş ekle', color: 'text-accent', icon: <PersonAddIcon />, act: () => setConfirmAdd(u) };
    return (
      <button
        type="button"
        aria-label={`${u.name} — ${props.label}`}
        title={props.label}
        disabled={busyId === u.id}
        onClick={props.act}
        className={`shrink-0 w-11 h-11 -my-2 -mr-2 flex items-center justify-center leading-none active:scale-90 transition-transform disabled:opacity-40 ${props.color}`}
      >
        {props.icon}
      </button>
    );
  };

  // "Ara & Ekle" zaten arkadaş olunanları GÖSTERMEZ (kullanıcı isteği,
  // 11 Ağustos 2026) — onlar "Arkadaşlarım" sekmesinde. Eleme fetch'te değil
  // RENDER'da yapılıyor; iki sebep: (1) `allUsers.length` sayfalama offset'i
  // olduğundan diziden atmak sayfaları kaydırıp üye atlatırdı; (2) satır
  // ekrandayken arkadaş olunursa (kabul/karşılıklı istek) `patchRelation`
  // ilişkiyi 'accepted' yapar ve satır kendiliğinden listeden düşer.
  const notFriend = (u: FriendSearchResult) => u.relation !== 'accepted';
  const visibleResults = results.filter(notFriend);
  const visibleAllUsers = allUsers?.filter(notFriend) ?? null;

  const renderFriendRow = (u: FriendSearchResult) => (
    <div key={u.id} className={rowCls}>
      {personButton(u.id, u.name, u.avatar_url)}
      {relationAction(u)}
    </div>
  );

  /** Avatar+isim: dokununca o kişinin skor kartı. "Arkadaşlarım"da baştan
   * beri vardı, ÜÇ listede de olmalı (kullanıcı isteği, 11 Ağustos 2026) —
   * hele "İstekler"de, isteği yanıtlamadan önce kimin gönderdiğine bakmak
   * tam da orada gerekiyor. Kart kapanınca ilişki yeniden okunuyor: kullanıcı
   * kartın İÇİNDEN arkadaş ekleyip çıkabildiğinden (`PlayerScoreCard`'ın
   * kendi simgesi) arkadaki satırın ikonu yoksa bayat kalırdı. */
  const personButton = (id: string, name: string, avatarUrl: string | null) => {
    const tier = rankTierOf(id);
    return (
      <button
        type="button"
        onClick={() => setSelectedFriend(toPlayerSummary(id, name, avatarUrl))}
        className="flex-1 min-w-0 flex items-center gap-2.5 text-left active:opacity-70 transition-opacity"
      >
        <Avatar url={avatarUrl} name={name} size={32} />
        <span className="flex-1 min-w-0 flex items-center gap-1">
          <span className={nameCls}>{name}</span>
          {/* Rütbe mührü — üç sekme de bu tek yardımcıyı kullandığından
              (Arkadaşlarım / İstekler / Ara & Ekle) tek yerde eklemek
              üçünü birden kapsıyor. */}
          {tier && <RankSeal tier={tier} size={18} className="shrink-0" />}
        </span>
      </button>
    );
  };

  const closeSelectedFriend = () => {
    const id = selectedFriend?.id;
    setSelectedFriend(null);
    if (!id) return;
    // Kart içinden ilişki değişmiş olabilir — listeyi gerçeğe eşitle.
    void fetchFriendRelation(id).then((r) => patchRelation(id, r));
    reloadFriends();
    reloadRequests();
  };

  const tabBtn = (t: Tab, label: string, badge?: number) => (
    <button
      onClick={() => {
        // Elle bir sekme seçilir seçilmez varsayılan-sekme effect'i devre
        // dışı kalır — istekler henüz yüklenmemişken (null) dokunulursa,
        // liste gelince effect seçimi ezerdi (`LiveGamesTab`'daki aynı guard).
        appliedDefaultTabRef.current = true;
        setTab(t);
      }}
      className={`relative flex-1 py-2 text-[11px] font-mono font-bold uppercase tracking-[0.5px] rounded-md transition-colors flex items-center justify-center ${
        tab === t ? 'bg-accent text-white' : 'text-muted hover:text-text'
      }`}
    >
      {label}
      {!!badge && <CountBadge count={badge} className="absolute -top-1 -right-1" />}
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
          Kelimeki'de henüz olmayan arkadaşlarını davet et
        </p>

        <div className="flex gap-1 bg-bg border border-border rounded-md p-1">
          {tabBtn('friends', 'Arkadaşlarım', 0)}
          {tabBtn('requests', 'İstekler', requests?.length ?? 0)}
          {tabBtn('search', 'Ara & Ekle')}
        </div>

        {tab === 'friends' && (
          <div className={listCls}>
            {friends === null ? (
              <LoadingNote py="py-4" />
            ) : friends.length === 0 ? (
              <p className="text-muted text-xs font-mono py-4 text-center">
                Henüz arkadaşın yok — "Ara & Ekle" sekmesinden ya da yukarıdaki davet linkiyle ekleyebilirsin.
              </p>
            ) : (
              friends.map((f) => (
                <div key={f.friend_id} className={rowCls}>
                  {personButton(f.friend_id, f.name, f.avatar_url)}
                  {/* Moderasyon durumu VARSA yönetim ikonu — arkadaşlıktan
                      çıkar ikonunun SOLUNDA (kullanıcı isteği, 14 Ağustos
                      2026). Durum yoksa hiç çizilmez: bu bir "geri al"
                      kısayolu, moderasyon menüsü değil (yeni şikayet
                      sohbette açılır, bkz. FriendModerationModal). */}
                  {(moderation.reported.has(f.friend_id) || moderation.muted.has(f.friend_id)) && (
                    <button
                      type="button"
                      aria-label={`${f.name} — ${
                        moderation.reported.has(f.friend_id) ? 'şikayet edildi' : 'sessize alındı'
                      }, ayarları aç`}
                      title={moderation.reported.has(f.friend_id) ? 'Şikayet edildi' : 'Sessize alındı'}
                      className="shrink-0 w-11 h-11 -my-2 flex items-center justify-center text-sm leading-none active:scale-90 transition-transform"
                      onClick={() =>
                        setModerationTarget({
                          userId: f.friend_id,
                          name: f.name,
                          avatarUrl: f.avatar_url,
                          mutedGameId: moderation.muted.get(f.friend_id),
                          reported: moderation.reported.has(f.friend_id),
                        })
                      }
                    >
                      {/* Bayrak, yasak işaretini EZER — sohbetteki rozet
                          mantığının aynısı (şikayet otomatik sessize de
                          alıyor, iki ikon birden göstermek gürültü). */}
                      {moderation.reported.has(f.friend_id) ? '🚩' : '🚫'}
                    </button>
                  )}
                  <button
                    type="button"
                    aria-label={`${f.name} — arkadaşlıktan çıkar`}
                    title="Arkadaşlıktan çıkar"
                    className="shrink-0 w-11 h-11 -my-2 -mr-2 flex items-center justify-center leading-none text-red active:scale-90 transition-transform disabled:opacity-40"
                    disabled={busyId === f.friend_id}
                    onClick={() => setConfirmRemove(f)}
                  >
                    <PersonRemoveIcon />
                  </button>
                </div>
              ))
            )}
          </div>
        )}

        {tab === 'requests' && (
          <div className={listCls}>
            {requests === null ? (
              <LoadingNote py="py-4" />
            ) : requests.length === 0 ? (
              <p className="text-muted text-xs font-mono py-4 text-center">Bekleyen istek yok.</p>
            ) : (
              requests.map((r) => (
                <div key={r.requester_id} className={rowCls}>
                  {personButton(r.requester_id, r.name, r.avatar_url)}
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
            {query.trim().length >= 2 ? (
              <div className={`${listCls} min-h-[40px]`}>
                {searching ? (
                  <p className="text-muted text-xs font-mono py-4 text-center">Aranıyor…</p>
                ) : visibleResults.length === 0 ? (
                  <p className="text-muted text-xs font-mono py-4 text-center">
                    {results.length > 0
                      ? 'Bulunanların hepsi zaten arkadaşın — "Arkadaşlarım" sekmesine bak.'
                      : "Kimse bulunamadı — Kelimeki'de değilse yukarıdaki davet linkini gönderebilirsin."}
                  </p>
                ) : (
                  visibleResults.map((u) => renderFriendRow(u))
                )}
              </div>
            ) : (
              <>
                <p className="text-[9px] uppercase tracking-[1px] text-muted font-mono px-0.5">
                  Tüm Üyeler
                </p>
                {visibleAllUsers === null ? (
                  <LoadingNote py="py-4" />
                ) : (
                  <div
                    ref={allUsersScrollRef}
                    className={`${listCls} max-h-[50vh] overflow-y-auto pr-1`}
                  >
                    {visibleAllUsers.map((u) => renderFriendRow(u))}
                    {/* Boş mesajı yalnızca liste GERÇEKTEN tükendiyse göster —
                        bir sayfanın tamamı arkadaş çıkarsa sentinel görünür
                        kalıp bir sonraki sayfayı çekmeye devam etmeli. */}
                    {visibleAllUsers.length === 0 && !allUsersHasMore && (
                      <p className="text-muted text-xs font-mono py-4 text-center">
                        Eklenecek başka üye yok.
                      </p>
                    )}
                    {allUsersHasMore && (
                      <div ref={allUsersSentinelRef} className="py-2 text-center">
                        <span className="text-muted text-[10px] font-mono">
                          {allUsersLoadingMore ? 'Yükleniyor…' : ''}
                        </span>
                      </div>
                    )}
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </div>
      {selectedFriend && (
        <PlayerScoreCard member={selectedFriend} onClose={closeSelectedFriend} />
      )}

      {moderationTarget && (
        <FriendModerationModal
          target={moderationTarget}
          onClose={(changed) => {
            setModerationTarget(null);
            // Durum değiştiyse ikon hemen kaybolmalı — aksi halde
            // kullanıcı "geri çektim ama bayrak duruyor" görürdü.
            if (changed) reloadModeration();
          }}
        />
      )}

      {confirmRemove && (
        <ConfirmDialog
          dialogRef={confirmRemoveRef}
          ariaLabel="Arkadaşlıktan Çıkar"
          title="Arkadaşlıktan Çıkar"
          message={`${confirmRemove.name} ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?`}
          confirmLabel="Çıkar"
          busy={busyId === confirmRemove.friend_id}
          onConfirm={handleConfirmRemove}
          onCancel={() => setConfirmRemove(null)}
        />
      )}
      {removeResultMsg && (
        <InfoDialog dialogRef={removeResultRef} message={removeResultMsg} onClose={() => setRemoveResultMsg(null)} />
      )}

      {confirmReject && (
        <ConfirmDialog
          dialogRef={confirmRejectRef}
          ariaLabel="İsteği Reddet"
          title="İsteği Reddet"
          message={`${confirmReject.name} oyuncusunun arkadaşlık isteğini reddetmek mi istiyorsunuz?`}
          confirmLabel="Reddet"
          busy={busyId === confirmReject.requester_id}
          onConfirm={handleConfirmReject}
          onCancel={() => setConfirmReject(null)}
        />
      )}
      {rejectResultMsg && (
        <InfoDialog dialogRef={rejectResultRef} message={rejectResultMsg} onClose={() => setRejectResultMsg(null)} />
      )}

      {confirmAdd && (
        <ConfirmDialog
          dialogRef={confirmAddRef}
          ariaLabel={confirmAdd.relation === 'pending_incoming' ? 'Arkadaşlık İsteği' : 'Arkadaş Ekle'}
          title={confirmAdd.relation === 'pending_incoming' ? 'Arkadaşlık İsteği' : 'Arkadaş Ekle'}
          message={
            confirmAdd.relation === 'pending_incoming'
              ? `${confirmAdd.name} oyuncusu sana arkadaşlık isteği gönderdi. Kabul etmek istiyor musun?`
              : `${confirmAdd.name} oyuncusunu arkadaş olarak eklemek istiyor musun?`
          }
          confirmLabel={confirmAdd.relation === 'pending_incoming' ? 'Kabul Et' : 'Ekle'}
          busy={busyId === confirmAdd.id}
          onConfirm={handleConfirmAdd}
          onCancel={() => setConfirmAdd(null)}
        />
      )}
      {addResultMsg && (
        <InfoDialog dialogRef={addResultRef} message={addResultMsg} onClose={() => setAddResultMsg(null)} />
      )}

      {confirmCancel && (
        <ConfirmDialog
          dialogRef={confirmCancelRef}
          ariaLabel="İsteği İptal Et"
          title="İsteği İptal Et"
          message={`${confirmCancel.name} oyuncusuna gönderdiğin arkadaşlık isteğini iptal etmek istiyor musun?`}
          confirmLabel="İptal Et"
          busy={busyId === confirmCancel.id}
          onConfirm={handleConfirmCancel}
          onCancel={() => setConfirmCancel(null)}
        />
      )}
      {cancelResultMsg && (
        <InfoDialog dialogRef={cancelResultRef} message={cancelResultMsg} onClose={() => setCancelResultMsg(null)} />
      )}
    </Modal>
  );
}
