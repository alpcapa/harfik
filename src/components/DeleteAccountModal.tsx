// Kelimeki — hesabı uygulama İÇİNDEN silme onayı (ROADMAP madde 2).
//
// NEDEN VAR: Apple 5.1.1(v) ve Google'ın veri silme şartı, hesap açtıran
// uygulamalarda uygulama içinden başlatılabilen bir silme yolu istiyor.
// `/hesap-silme/` statik sayfası yalnızca Play'in Data safety formuna verilen
// TALEP adresidir; gerçek işi yapan yol burasıdır.
//
// AÇILIŞTA KURU ÇALIŞTIRMA: pencere açılır açılmaz `previewAccountDeletion()`
// çağrılıyor ve kullanıcıya kaç oyun/mesaj/arkadaşlık kaydının gideceği
// GERÇEK sayılarla gösteriliyor. Geri dönüşü olmayan bir işlemde "ne
// kaybedeceğim" sorusunun cevabı tahmin değil ölçüm olmalı; aynı rapor
// sunucunun uygulayacağı planın ta kendisi (aynı fonksiyon, `dryRun` bayrağı).
//
// Onay: kullanıcı `SİL` yazmadan buton etkinleşmiyor. Karşılaştırma `trUpper`
// ile — mobil klavyede "sil" yazan biri native `toUpperCase()` ile "SIL"
// (noktasız I) üretir ve eşleşme sessizce tutmazdı.
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { deleteMyAccount, previewAccountDeletion, signOut, type AccountDeletionReport } from '../lib/api';
import { trUpper } from '../utils/turkish';

interface DeleteAccountModalProps {
  onClose: () => void;
}

const ONAY_KELIMESI = 'SİL';

/** Rapordaki ham anahtarları kullanıcıya gösterilecek satırlara çevirir.
 *  Listede OLMAYAN bir anahtar bilerek gösterilmiyor (ör. `profil`, her zaman
 *  1) — sıfır olan satırlar da gizleniyor, boş bir döküm kimseye yardımcı
 *  olmuyor. */
const SILINECEK_ETIKET: Array<[string, string]> = [
  ['games_kendi', 'Bitmiş oyun kaydın'],
  ['yarim_online_oyun', 'Devam eden Canlı oyunun'],
  ['local_game_saves', 'Devam eden Yapay Zeka oyunun'],
  ['online_game_messages', 'Gönderdiğin oyun içi mesaj'],
  ['friend_requests', 'Arkadaşlık bağın ve isteğin'],
  ['game_invites', 'Aldığın oyun daveti'],
  ['league_rewards', 'k-lig ödülün'],
  ['game_likes', 'Beğendiğin oyun'],
  ['feedback', 'Görüş bildirimin'],
  ['friend_invite_links', 'Davet bağlantın'],
  ['online_game_chat_reports', 'Şikayet kaydın'],
  ['avatar_dosyalari', 'Profil fotoğrafın'],
];

export function DeleteAccountModal({ onClose }: DeleteAccountModalProps) {
  const [rapor, setRapor] = useState<AccountDeletionReport | null>(null);
  const [onay, setOnay] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [yukleniyor, setYukleniyor] = useState(true);

  useEffect(() => {
    let iptal = false;
    previewAccountDeletion()
      .then((r) => {
        if (!iptal) setRapor(r);
      })
      .catch((e) => {
        // Kuru çalıştırma başarısızsa silmeyi de ENGELLE: sunucuya
        // ulaşılamıyorsa (ya da hesap silinemez bir hesapsa — ör. yönetici)
        // butonu etkinleştirmek yanlış bir söz verir.
        if (!iptal) setError(e instanceof Error ? e.message : 'Hesap bilgileri okunamadı.');
      })
      .finally(() => {
        if (!iptal) setYukleniyor(false);
      });
    return () => {
      iptal = true;
    };
  }, []);

  const sil = async () => {
    setError(null);
    setBusy(true);
    try {
      await deleteMyAccount();
      await signOut();
      // Tam yeniden yükleme: bellekteki profil/oyun state'i ve localStorage'a
      // yazılmış her şey bu noktadan sonra artık var olmayan bir hesaba ait.
      window.location.replace('/');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Hesap silinemedi.');
      setBusy(false);
    }
  };

  const satirlar = rapor
    ? SILINECEK_ETIKET.map(([anahtar, etiket]) => [etiket, rapor.silinecek?.[anahtar] ?? 0] as const)
        .filter(([, n]) => n > 0)
    : [];
  const korunacak = rapor?.anonimlestirilecek?.games_baskalarinin ?? 0;

  return (
    <Modal title="Hesabı Sil" onClose={onClose}>
      <div className="flex flex-col gap-4">
        <p className="text-xs font-sans text-text leading-relaxed">
          Hesabın ve hesabına bağlı kişisel verilerin <strong>kalıcı olarak</strong> silinir.
          Bu işlemin geri dönüşü yoktur.
        </p>

        {yukleniyor && <p className="text-[10px] font-mono text-muted">Hesabın okunuyor…</p>}

        {rapor && (
          <div className="flex flex-col gap-2">
            <h3 className="font-mono text-[11px] uppercase tracking-[1.5px] text-accent border-b border-border pb-1">
              Silinecekler
            </h3>
            {satirlar.length === 0 ? (
              <p className="text-xs font-sans text-muted">
                Hesabına bağlı bir oyun/mesaj kaydı yok — yalnızca profilin silinecek.
              </p>
            ) : (
              <ul className="flex flex-col gap-1">
                {satirlar.map(([etiket, n]) => (
                  <li key={etiket} className="flex items-baseline justify-between gap-3 text-xs font-sans text-text">
                    <span>{etiket}</span>
                    <span className="font-mono text-[11px] text-muted shrink-0">{n}</span>
                  </li>
                ))}
              </ul>
            )}
            {korunacak > 0 && (
              <>
                <h3 className="font-mono text-[11px] uppercase tracking-[1.5px] text-accent border-b border-border pb-1 mt-2">
                  Kalacaklar
                </h3>
                <p className="text-xs font-sans text-text leading-relaxed">
                  Birlikte oynadığın kişilerin <strong>{korunacak}</strong> bitmiş oyun kaydı onların
                  kendi verisidir, silinmez — ama o kayıtlarda adın{' '}
                  <span className="font-mono text-[11px]">“Silinmiş oyuncu”</span> olarak değiştirilir.
                </p>
              </>
            )}
          </div>
        )}

        {rapor && (
          <div>
            <label className="block font-mono text-[10px] uppercase tracking-[1px] text-muted mb-1">
              Onaylamak için <span className="text-red">{ONAY_KELIMESI}</span> yaz
            </label>
            <input
              className="w-full bg-bg border border-border rounded-md px-3 py-2 text-sm font-mono text-text outline-none focus:border-accent"
              value={onay}
              onChange={(e) => setOnay(e.target.value)}
              placeholder={ONAY_KELIMESI}
              autoComplete="off"
              aria-label={`Onaylamak için ${ONAY_KELIMESI} yaz`}
            />
          </div>
        )}

        {error && <p className="text-red text-xs font-mono">{error}</p>}

        <div className="flex gap-2">
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            className="btn-raised-neutral flex-1 bg-panel border border-border text-text rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            Vazgeç
          </button>
          <button
            type="button"
            onClick={sil}
            disabled={busy || !rapor || trUpper(onay.trim()) !== ONAY_KELIMESI}
            className="btn-raised flex-1 bg-red text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform disabled:opacity-50"
          >
            {busy ? '...' : 'Kalıcı Olarak Sil'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
