// Arkadaş listesinden moderasyon durumunu YÖNETME paneli.
//
// NEDEN VAR (14 Ağustos 2026, kullanıcı isteği): sessize alma/şikayet 3
// Ağustos'tan beri KİŞİ bazlı — kişiyle birlikte oyunlar arası taşınıyor.
// Ama geri almanın TEK giriş noktası, o kişiyle AKTİF bir oyunun sohbet
// ayarlarıydı (`ChatSettingsModal`, dişli ikonu). Oyun bitince
// `LiveGamesTab` onu artık listelemediğinden sohbet penceresi hiç
// açılamıyor; arşiv (`GameChatHistoryModal`) ise bilerek salt-görsel
// (rozet var, dişli/tıklama yok). Sonuç: bir oyun bittikten sonra
// şikayeti geri çekmek için raporladığın kişiyle YENİ BİR OYUN AÇMAK
// gerekiyordu — raporladığın biriyle yeniden oynamak tuhaf bir varsayım.
// Kullanıcı testi sırasında bizzat bu duvara çarpıldı.
//
// KAPSAM — bilinçli olarak yalnızca GERİ ALMA:
//  * "Sessizden Çıkar" ve "Şikayeti Geri Çek" burada var.
//  * YENİ bir şikayet açma burada YOK. Bir şikayet, hakkında olduğu
//    KONUŞMAYA bağlıdır (`online_game_chat_reports.online_game_id`) ve
//    admin panelindeki "Sohbeti Görüntüle" o dökümü açar. Arkadaş
//    listesinden açılan bir şikayet zorunlu olarak ESKİ bir oyuna
//    iliştirilirdi ve admin, şikayetle ilgisi olmayan bir yazışma okurdu —
//    yani yanlış bilgi. Şikayet etmek sohbetin kendisinde kalıyor.
//  * Sessize ALMA da yok (aynı gerekçenin daha zayıfı: mute zaten kişi
//    bazlı, ama onu da konuşma bağlamında vermek tutarlı).
//
// Bu yüzden ikon YALNIZCA durum VARKEN çizilir (bkz. FriendsModal) —
// panel bir "yönet/geri al" aracı, bir moderasyon menüsü değil.
import { useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { setChatMute, withdrawChatReports } from '../lib/api';

export interface FriendModerationTarget {
  userId: string;
  name: string;
  avatarUrl?: string | null;
  /** Sessize alınmışsa, kaydın geldiği oyun id'si (RPC'nin katılımcılık
   *  kontrolü için — bkz. `fetchMyChatModeration`). */
  mutedGameId?: string;
  /** Aktif şikayet varsa true (geri çekme oyun id'si İSTEMİYOR). */
  reported: boolean;
}

type View = 'menu' | 'unmute-confirm' | 'withdraw-confirm' | 'done';

export function FriendModerationModal({
  target,
  onClose,
}: {
  target: FriendModerationTarget;
  onClose: (changed: boolean) => void;
}) {
  const [view, setView] = useState<View>('menu');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [doneMsg, setDoneMsg] = useState('');
  const [changed, setChanged] = useState(false);

  const muted = !!target.mutedGameId;

  async function run(action: () => Promise<void>, msg: string) {
    setBusy(true);
    setError(null);
    try {
      await action();
      setChanged(true);
      setDoneMsg(msg);
      setView('done');
    } catch (e) {
      // Sessizce yutma YOK — kullanıcı gerçekleşmemiş bir sonucu
      // "olmuş" sanmamalı (bkz. FriendsModal'ın aynı dersi).
      setError(e instanceof Error ? e.message : 'İşlem başarısız oldu.');
    } finally {
      setBusy(false);
    }
  }

  const btnNeutral =
    'btn-raised-neutral rounded-md py-2 text-xs font-bold uppercase tracking-[1px] bg-void border border-border text-text active:scale-[0.97] transition-transform disabled:opacity-50';

  return (
    <Modal title="Kişi Ayarları" onClose={() => onClose(changed)}>
      <div className="flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <Avatar url={target.avatarUrl} name={target.name} size={28} />
          <p className="text-sm font-bold text-text">{target.name}</p>
        </div>

        {view === 'menu' && (
          <>
            <p className="text-xs text-muted leading-relaxed">
              {target.reported && muted
                ? 'Bu kişiyi şikayet ettiniz ve sessize aldınız.'
                : target.reported
                  ? 'Bu kişiyi şikayet ettiniz.'
                  : 'Bu kişiyi sessize aldınız.'}
            </p>

            {target.reported && (
              <button type="button" disabled={busy} className={btnNeutral} onClick={() => setView('withdraw-confirm')}>
                Şikayeti Geri Çek
              </button>
            )}
            {muted && (
              <button type="button" disabled={busy} className={btnNeutral} onClick={() => setView('unmute-confirm')}>
                Sessizden Çıkar
              </button>
            )}

            <p className="text-[10px] font-mono text-muted leading-relaxed">
              Şikayet etmek ve sessize almak, o kişiyle oynadığın Canlı oyunun
              mesajlaşma ayarlarından yapılır.
            </p>
          </>
        )}

        {(view === 'unmute-confirm' || view === 'withdraw-confirm') && (
          <>
            <p className="text-sm text-text font-bold">Emin misiniz?</p>
            <p className="text-sm text-text leading-relaxed">
              {view === 'unmute-confirm'
                ? `${target.name} artık sessize alınmayacak; mesajları için bildirim almaya devam edeceksiniz.`
                : `${target.name} hakkındaki şikayetiniz geri çekilecek. Dilerseniz daha sonra tekrar şikayet edebilirsiniz.`}
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                disabled={busy}
                className="btn-raised flex-1 rounded-md py-2 text-xs font-bold uppercase tracking-[1px] bg-accent text-white active:scale-[0.97] transition-transform disabled:opacity-50"
                onClick={() =>
                  view === 'unmute-confirm'
                    ? run(
                        () => setChatMute(target.mutedGameId!, target.userId, false),
                        'Kişi sessizden çıkarıldı.',
                      )
                    : run(() => withdrawChatReports(target.userId), 'Şikayetiniz geri çekildi.')
                }
              >
                {busy ? '...' : view === 'unmute-confirm' ? 'Sessizden Çıkar' : 'Geri Çek'}
              </button>
              <button type="button" disabled={busy} className={btnNeutral + ' flex-1'} onClick={() => setView('menu')}>
                Vazgeç
              </button>
            </div>
          </>
        )}

        {view === 'done' && (
          <>
            <p className="text-sm text-text leading-relaxed">{doneMsg}</p>
            <button type="button" className={btnNeutral} onClick={() => onClose(true)}>
              Tamam
            </button>
          </>
        )}

        {error && <p className="text-red text-[10px] font-mono">{error}</p>}
      </div>
    </Modal>
  );
}
