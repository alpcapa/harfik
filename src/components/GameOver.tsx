// Kelimeki — oyun sonu ekranı (çok oyunculu)
import { Fragment } from 'react';
import { Modal } from './Modal';
import { PLAYER_COLORS } from '../game/constants';
import type { AiLevel, Player } from '../game/types';
import { trUpper } from '../utils/turkish';
import { rankPlayers } from '../utils/ranking';
import { leaguePoints, formatLeaguePoints } from '../utils/leaguePoints';
import { PlayerBadge } from './PlayerBadge';
import { AiLevelBadge } from './AiLevelBadge';

interface GameOverProps {
  show: boolean;
  players: Player[];
  turnCount: number;
  /** YZ oyununda `aiLevelOf(state.aiLevel)` (App.tsx); Canlı ekran GEÇİRMEZ → rozet yok, puan Normal formülü. */
  aiLevel?: AiLevel;
  onOpenHistory: () => void;
  onOpenFeedback: () => void;
  onClose: () => void;
}

export function GameOver({ show, players, turnCount, aiLevel, onOpenHistory, onOpenFeedback, onClose }: GameOverProps) {
  if (!show) return null;

  const ranked = rankPlayers(players);
  const top = ranked[0];
  const tie = ranked.length > 1 && ranked[1].rank === top.rank;
  const winColor = PLAYER_COLORS[top.player.colorIndex];

  return (
    <Modal title="" onClose={onClose}>
      <div className="flex flex-col items-center gap-[18px]">
        <div
          className="font-mono text-[26px] font-bold tracking-[2px] text-center"
          style={{ color: tie ? '#B7791F' : winColor.base }}
        >
          {tie ? 'BERABERE' : `${trUpper(top.player.name)} KAZANDI`}
        </div>
        {/* Zorluk rozeti — YZ oyununda her seviyede (Kolay yeşil · Normal
            turuncu · Zor kırmızı) başlığın hemen altında; Canlı'da prop yok →
            `null`, `gap` de açılmaz. */}
        <AiLevelBadge level={aiLevel} size="sm" />

        {/* ÜÇ sabit sayı kolonu + esneyen ad. Ad `flex-1 min-w-0 truncate`:
            önceden kırpılmıyordu, uzun bir ad (en sık "Yapay Zeka 1"; ayrıca
            ad alanının uzunluk sınırı YOK, yalnız takma ad 10 karakterle
            sınırlı) satırı ikiye sarıyor, dar ekranda da kartı TAŞIRIYORDU
            (320px'te ölçüldü: skor kartın sağ kenarından kesiliyordu).
            Kolon genişlikleri ölçüyle seçildi — 390px'te 16 karakterlik bir
            ad bile kırpılmıyor, 360px'te yalnız 13+ karakterliler kırpılıyor.
            Başlık 10→9px ve skor 22→20px: bu iki küçülme adın alanına ~8px
            kazandırıyor ve "Abdurrahman"ı 360px'te sığdıran şey tam olarak
            bu (20 Ağustos 2026, kullanıcı isteğiyle simüle edilip seçildi).
            Kolon genişlikleri TAHMİN DEĞİL, mürekkep ölçüsü — her kutu KENDİ
            EN GENİŞ içeriğine eşit: "KALAN" başlığı 28.86px → w-[29px]; skor
            "271" 20px mono'da 36.72px → w-[37px] (36 iken sayı kutuyu birebir
            doldurup soldaki kalan-taş eksisine yapışıyor, "-2208" gibi
            okunuyordu); "k-lig" başlığı 19.98px → w-5.

            BOŞLUKLAR ASİMETRİK ve bu bilinçli (21 Ağustos 2026, kullanıcı:
            "3 kolonun da sayıları kolonun sağına yapışık olmalı. Sanki toplam
            kolonu ortalı gibi duruyor"). Kolonlar ZATEN sağa yaslıydı —
            ölçüldü, 16 satırın 16'sında metnin sağ kenarı kutunun sağ
            kenarıyla birebir aynı. Yanılsama kutuların içeriğinden geniş
            olmasındandı: k-lig'in "-" gösterdiği ve skorun 2 haneli olduğu
            satırlarda skorun SOLUNDA 19.5px, SAĞINDA 20.0px boşluk kalıyordu,
            yani skor komşularının mürekkebi arasında tam ortalanıyordu. Ölçü
            şunu söylüyor: sol boşluğu Toplam'ın genişliği, sağ boşluğu k-lig'in
            genişliği belirler (blok sağa çapalı olduğundan Kalan'ın genişliği
            İKİSİNİ DE etkilemez). Bu yüzden kutular içeriğe indirildi ve
            Toplam'ın SOL boşluğu (ml-2 = 8px) sağdakinden (ml-1 = 4px) büyük
            tutuldu: aynı satırda artık 20.5px sola / 16.0px sağa, yani skor
            görünür biçimde sağa yaslanıyor. Sağ blok 104 → 100px; yan fayda:
            390px'te "Konstantinopolis" artık kırpılmıyor. */}
        {/* 2 Eylül 2026 — SABİT px KUTULAR IZGARAYA ÇEVRİLDİ (sınıf 1+3).
            Yukarıdaki mürekkep ölçüleri (29/37/20 px) hâlâ geçerli, ama
            ARTIK ELLE YAZILMIYORLAR: her sütun `auto`, yani genişliğini
            kendi en geniş içeriğinden alıyor — tam olarak o ölçülerin
            türetildiği kuralın kendisi. Fark, metin BÜYÜDÜĞÜNDE ortaya
            çıkıyor: tarayıcının "asgari yazı boyutu" erişilebilirlik ayarı
            (Ayarlar → Görünüm → Yazı tipi boyutu) eşiğin altındaki puntoları
            yukarı çekiyor, kutular ise px'te kalıyordu.

            ÖLÇÜLDÜ (390 px, `--blink-settings=minimumFontSize=16`,
            `tests/text-scale.spec.ts`):
              Kalan  başlığı  50,4 px metin / 29 px kutu  → %74 TAŞMA
              Toplam başlığı  63,3 px metin / 37 px kutu  → %71 TAŞMA
              k-lig  başlığı  20 px kutuda İKİ SATIRA sarıyor
              -17 / 254         kıl payı sığıyor (29,4/29 ve 36,7/37)
            Yani mobilde kullanıcının bildirdiği "puanları bölüyor"un web
            eşleniği: başlıklar isim alanının üstüne biniyordu.

            Izgara satırlar ARASINDA hizayı da korur (üç `min-w` kutu bunu
            yapamazdı: her satır kendi genişliğini seçip sütunlar kayardı).
            `auto` büyürken payı isim sütunu (`minmax(0,1fr)`) veriyor — o
            zaten `truncate`, yani zarar "…" ile sınırlı; sınıf 2'nin bilinçli
            kabulü, portun `ScaledCell`'inde ödenen bedelin aynısı. */}
        <div className="shadow-raised bg-bg border border-border rounded-[10px] px-5 py-4 text-center grid grid-cols-[minmax(0,1fr)_auto_auto_auto] items-center gap-y-2.5 w-full">
          <span />
          {/* Başlıklar ve sayılar AYNI ızgaranın hücreleri — satır sarmalayıcı
              yok, yoksa sütunlar satırlar arasında hizalanmazdı. */}
          {/* ⚠ `min-w-*` TABANLARI SİLME — ikisi birden gerekiyor:
              (a) davranış: `auto` sütun zaten içeriğe göre büyüyor, taban
                  yalnızca normal ölçekteki eski görünümü birebir sabitliyor;
              (b) PARİTE: `layout_parity_test.dart` (bir MOBİL test) bu
                  dosyayı OKUYUP `w-\[(\d+)px\][^"]*">Kalan<` ile sayıyı
                  çekiyor ve portun `_ColHeader('KALAN', width: 29)`'uyla
                  karşılaştırıyor. Yani sınıf adı DA, etiketin `className`den
                  hemen sonra TEK SATIRDA gelmesi DE sözleşmenin parçası.
              Bu ikisi 2 Eylül 2026'da ızgaraya geçerken kaldırılmış ve
              `main` KIRMIZI olmuştu — web değişikliği bir mobil testi
              düşürdü. */}
          <span data-metin-kutusu="kalan-baslik" className="min-w-[29px] ml-1 text-right whitespace-nowrap text-[9px] uppercase tracking-wide text-muted">Kalan</span>
          <span data-metin-kutusu="toplam-baslik" className="min-w-[37px] ml-2 text-right whitespace-nowrap text-[9px] uppercase tracking-wide text-muted">Toplam</span>
          {/* Satır `uppercase` olduğundan `normal-case` ŞART — marka küçük
              harf ("SL" sütununda öğrenilen aynı ders). Oyun kartlarındaki
              (GameHistoryModal/SharedGamePage) k-lig sütununun eşi. */}
          <span data-metin-kutusu="klig-baslik" className="min-w-5 ml-1 text-right whitespace-nowrap text-[9px] tracking-wide text-muted">k-lig</span>
          {ranked.map(({ player: p, index: i, rank }) => {
            const col = PLAYER_COLORS[p.colorIndex];
            const remaining = p.rack.reduce((s, t) => s + t.pts, 0);
            const points = leaguePoints(rank, players.length, p.surrendered, aiLevel);
            return (
              <Fragment key={i}>
                <span className="flex items-center gap-1.5 min-w-0 text-[15px]">
                  <PlayerBadge index={i} colorIndex={p.colorIndex} size={14} />
                  <span className="text-text truncate">
                    {rank}. {p.name}
                  </span>
                  {p.surrendered && (
                    <span className="shrink-0 text-[9px] font-mono uppercase tracking-[0.5px] text-red">
                      (Teslim)
                    </span>
                  )}
                </span>
                <span
                  data-metin-kutusu="kalan-skor"
                  className="ml-1 text-right whitespace-nowrap font-mono text-[13px] text-muted"
                >
                  {remaining > 0 ? `-${remaining}` : ''}
                </span>
                <span
                  data-metin-kutusu="toplam-skor"
                  className="ml-2 text-right whitespace-nowrap font-mono text-[20px] font-bold"
                  style={{ color: col.base }}
                >
                  {p.score}
                </span>
                {/* k-lig katkısı — oyun kartlarıyla AYNI fonksiyondan
                    (`leaguePoints`), yani kart ile Skor Kartı/k-lig listesi
                    sessizce ayrışamaz. "-2" burada TESLİM cezasıdır; soldaki
                    "Kalan" sütunundaki eksi ise raf taşı düşümü — iki farklı
                    şey, bu yüzden ikisi ayrı sütun ve ayrı başlık. */}
                <span
                  data-metin-kutusu="klig-skor"
                  className={`ml-1 text-right whitespace-nowrap font-mono text-[13px] font-bold ${
                    points > 0 ? 'text-green' : points < 0 ? 'text-red' : 'text-muted'
                  }`}
                >
                  {formatLeaguePoints(points)}
                </span>
              </Fragment>
            );
          })}
          {/* Sayı etiketin YANINDA (önceden `justify-between` ile satırın iki
              ucundaydı) — kullanıcı isteği, 20 Ağustos 2026. */}
          {/* Izgaranın DÖRT sütununu birden kaplar — kendi satırında ortalı. */}
          <div className="col-span-4 flex justify-center items-center gap-2 text-[12px] border-t border-border pt-2 mt-1">
            <span className="text-muted">Toplam hamle</span>
            <span className="font-mono font-bold text-muted">{turnCount}</span>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <button
            onClick={onOpenHistory}
            className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity"
          >
            Oyun Geçmişi
          </button>
          <button
            onClick={onOpenFeedback}
            className="text-[11px] font-mono font-bold uppercase tracking-[1px] text-muted underline underline-offset-2 active:opacity-70 transition-opacity"
          >
            Görüş Bildir
          </button>
        </div>
      </div>
    </Modal>
  );
}
