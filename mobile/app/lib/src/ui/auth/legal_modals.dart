// Kullanım Koşulları + Gizlilik Politikası — src/components/TermsModal.tsx
// ve PrivacyModal.tsx portları.
//
// METİNLER WEB'DEN BİREBİR KOPYALANMIŞTIR — hukuki metin özetlenmez,
// yeniden yazılmaz (HelpModal'daki aynı kural). Web metni değişirse buraya
// da aynen taşınmalı. Web'de her iki modal da "Görüş Bildir formu" linkiyle
// FeedbackModal açar — o form henüz portlanmadı (Supabase'e yazıyor, auth
// fazının sonraki parçası); link burada dürüst "kelimeki.com üzerinden"
// diyaloğu gösterir, metnin kendisi değişmez.
import 'package:flutter/material.dart';

import '../game/modal_shell.dart';
import '../tokens.dart';

const Color _text = kText;
const Color _accent = kAccent;
const Color _border = kBorder;

Future<void> showTermsModal(BuildContext context,
        {VoidCallback? onFeedback}) =>
    showDialog<void>(
        context: context,
        builder: (context) => TermsModal(onFeedback: onFeedback));

Future<void> showPrivacyModal(BuildContext context,
        {VoidCallback? onFeedback}) =>
    showDialog<void>(
        context: context,
        builder: (context) => PrivacyModal(onFeedback: onFeedback));

// ── Ortak metin parçaları (web Section/P/liste) ───────────────────────────

const TextStyle _pStyle = TextStyle(fontSize: 12, height: 1.625, color: _text);

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              letterSpacing: 1.5,
              color: _accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: _pStyle);
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets(this.items);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: _pStyle),
              Expanded(child: Text(items[i], style: _pStyle)),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Sorularınız için: Görüş Bildir formu" satırı — link kısmı tıklanabilir.
class _FeedbackLinkLine extends StatelessWidget {
  final String prefix;
  final String suffix;
  /// "Görüş Bildir formu"nu açan callback — AuthModal kurar (kendisi
  /// FeedbackModal'ı auth+repo ile açar); null ise link ölü görünmesin
  /// diye satır DÜZ METİN olarak çizilir (yalnızca modalın doğrudan,
  /// callback'siz kurulduğu test/önizleme durumları).
  final VoidCallback? onTap;

  const _FeedbackLinkLine(
      {required this.prefix, this.suffix = '', this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      // Ölü (tıklanamaz) bir link göstermektense düz metin.
      return Text('${prefix}Görüş Bildir formu$suffix', style: _pStyle);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: prefix, style: _pStyle),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              'Görüş Bildir formu',
              style: _pStyle.copyWith(
                fontFamily: 'SpaceMono',
                color: _accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        TextSpan(text: suffix, style: _pStyle),
      ]),
    );
  }
}

class _StackedSections extends StatelessWidget {
  final List<Widget> children;
  const _StackedSections(this.children);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          children[i],
        ],
      ],
    );
  }
}

// ── Kullanım Koşulları ────────────────────────────────────────────────────

class TermsModal extends StatelessWidget {
  final VoidCallback? onFeedback;
  const TermsModal({super.key, this.onFeedback});

  @override
  Widget build(BuildContext context) {
    return KModal(
      title: 'Kullanım Koşulları',
      child: _StackedSections([
        const _P(
            "Kelimeki'ye kaydolarak aşağıdaki koşulları okuduğunuzu ve kabul "
            'ettiğinizi beyan edersiniz. Son güncelleme: 2 Ağustos 2026.'),
        const _Section('1. Hizmet Sağlayıcı ve Kapsam', [
          _P('Kelimeki, herhangi bir şirket ya da tüzel kişilik '
              'bulunmaksızın, bağımsız bir geliştirici tarafından bireysel '
              'olarak geliştirilmekte ve işletilmektedir; faaliyet merkezi '
              "Sarıyer, İstanbul'dur. Hizmet, Türkçe kelimelerle oynanan "
              'çevrimiçi bir kelime oyunudur ve oyun tahtası, lider tablosu, '
              'arkadaşlık ve kullanıcı hesabı özelliklerini kapsar. Hizmet '
              'ücretsizdir ve herhangi bir bildirimde bulunmaksızın '
              'değiştirilebilir ya da sonlandırılabilir.'),
        ]),
        const _Section('2. Hesap Sorumluluğu', [
          _P('Kayıt sırasında verdiğiniz bilgilerin doğru ve güncel olması '
              'zorunludur. Hesap güvenliğinizden yalnızca siz sorumlusunuz; '
              'şifrenizi kimseyle paylaşmayınız. Hesabınızı başkasına '
              'devredemezsiniz.'),
        ]),
        const _Section('3. Kabul Edilemez Kullanım', [
          _P('Aşağıdaki eylemler kesinlikle yasaktır:'),
          _Bullets([
            'Otomatik araçlar veya botlar aracılığıyla oyun oynamak',
            'Diğer kullanıcıları rahatsız edecek içerik paylaşmak',
            'Sistemi manipüle etmeye veya güvenlik açıklarını istismar '
                'etmeye çalışmak',
            'Başkasının hesabına yetkisiz erişim sağlamaya çalışmak',
            'Arkadaşlık isteklerini veya davet linkini spam, taciz ya da '
                'istenmeyen toplu davet amacıyla kullanmak',
            'Oyun içi mesajlaşmayı taciz, spam, hukuka aykırı ya da '
                'uygunsuz içerik paylaşmak amacıyla kullanmak',
          ]),
        ]),
        const _Section('4. Hesap Askıya Alma', [
          _P('Yukarıdaki kurallara aykırı davranış tespit edilmesi durumunda '
              'hesabınız önceden bildirim yapılmaksızın askıya alınabilir '
              'veya silinebilir.'),
        ]),
        const _Section('5. Sorumluluk Sınırlaması', [
          _P('Kelimeki, hizmet kesintileri, veri kayıpları veya üçüncü taraf '
              'hizmetlerinden kaynaklanan zararlardan sorumlu değildir. '
              'Hizmet "olduğu gibi" sunulmaktadır.'),
          _P('Oyun içi mesajlaşma özelliğiyle gönderilen mesajlar önceden '
              'denetlenmez (moderasyona tabi değildir); kullanıcılar arasında '
              'gönderilen mesajların içeriğinden Kelimeki hiçbir şekilde '
              'sorumlu tutulamaz, sorumluluk tamamen mesajı gönderen '
              'kullanıcıya aittir. Uygunsuz bir mesajla karşılaşan '
              'kullanıcılar, sohbet ekranındaki ayarlar üzerinden ilgili '
              'kişiyi sessize alabilir ve/veya yönetici ekibine şikayet '
              'edebilir.'),
        ]),
        const _Section('6. Değişiklikler', [
          _P('Bu koşullar zaman zaman güncellenebilir. Değişiklikler '
              'yayımlandıktan sonra hizmeti kullanmaya devam etmeniz, güncel '
              'koşulları kabul ettiğiniz anlamına gelir.'),
        ]),
        _Section('7. İletişim', [
          _FeedbackLinkLine(prefix: 'Sorularınız için: ', onTap: onFeedback),
        ]),
      ]),
    );
  }
}

// ── Gizlilik Politikası ───────────────────────────────────────────────────

class PrivacyModal extends StatelessWidget {
  final VoidCallback? onFeedback;
  const PrivacyModal({super.key, this.onFeedback});

  @override
  Widget build(BuildContext context) {
    return KModal(
      title: 'Gizlilik Politikası',
      child: _StackedSections([
        const _P('Kelimeki olarak gizliliğinize önem veriyoruz. Bu politika, '
            'hangi verileri topladığımızı, nasıl kullandığımızı ve '
            'haklarınızı açıklar. Son güncelleme: 2 Ağustos 2026.'),
        const _Section('1. Veri Sorumlusu', [
          _P('Kelimeki, herhangi bir şirket ya da tüzel kişilik '
              'bulunmaksızın, bağımsız bir geliştirici tarafından bireysel '
              'olarak geliştirilmekte ve işletilmektedir; faaliyet merkezi '
              "Sarıyer, İstanbul'dur. 6698 sayılı Kişisel Verilerin Korunması "
              'Kanunu ("KVKK") anlamında veri sorumlusu bu bireysel '
              'geliştiricidir ve işbu politikada "Kelimeki" bu kapsamda '
              'anılmaktadır. Talep ve başvurularınız için 8. bölümdeki '
              'iletişim kanalını kullanabilirsiniz.'),
        ]),
        const _Section('2. Toplanan Veriler', [
          _P('Hesap oluştururken şu bilgileri topluyoruz:'),
          _Bullets([
            'Ad ve soyad',
            'E-posta adresi',
            'Takma isim (isteğe bağlı)',
            'Cinsiyet (isteğe bağlı)',
            'Doğum tarihi (isteğe bağlı)',
            'Profil fotoğrafı (isteğe bağlı)',
            'Pazarlama iletişimi onayı ve onay tarihi (isteğe bağlı)',
            'Arkadaşlık isteği, oyun daveti ve süre uyarısı gibi işlemsel '
                'e-posta bildirimlerini alma tercihi',
            'Oyun istatistikleri (oynanan oyunlar, kazanma/kaybetme, puan '
                'geçmişi)',
            'Arkadaşlık bağlantıları (kiminle arkadaş olduğunuz, '
                'gönderdiğiniz/aldığınız arkadaşlık istekleri, davet '
                'linkinizin kullanım verisi)',
            'Canlı oyunlarda gönderdiğiniz oyun içi sohbet mesajları',
            'Bir Canlı oyunda kimleri sessize aldığınız ve gönderdiğiniz '
                'uygunsuz paylaşım şikayetleri (şikayetin nedeni dahil)',
          ]),
        ]),
        const _Section('3. Verilerin Kullanım Amacı ve Hukuki Sebebi', [
          _P('Verileriniz, hesap oluştururken verdiğiniz açık rızanıza '
              '(KVKK m.5/1) ve hizmetin sunulabilmesi için sözleşmenin '
              'kurulması/ifasına (KVKK m.5/2-c) dayanılarak, yalnızca şu '
              'amaçlarla işlenir:'),
          _Bullets([
            'Hesap oluşturma ve kimlik doğrulama',
            'Lider tablosu ve skor kartı gösterimi',
            'Oyun deneyiminin kişiselleştirilmesi',
            'Hesap güvenliği ve destek hizmetleri',
            'Bir arkadaşlık isteği ya da Canlı oyun daveti aldığınızda size '
                'e-posta ile bildirim gönderilmesi — bu, hizmetin işleyişine '
                'dair işlemsel bir bildirimdir, pazarlama onayı gerektirmez '
                've pazarlama onayınızdan bağımsız olarak gönderilir',
            'Yalnızca ayrıca onay verdiyseniz: pazarlama/tanıtım amaçlı '
                'iletişim',
          ]),
        ]),
        const _Section('4. Veri Paylaşımı ve Aktarım', [
          _P('Kişisel verileriniz üçüncü taraflara satış amacıyla '
              'kullanılmaz. Kayıt formundaki "Pazarlama iletişimi almayı '
              'kabul ediyorum" kutusunu işaretlerseniz, size pazarlama/'
              'tanıtım amaçlı iletişim gönderilebilir — bu kutu isteğe '
              'bağlıdır, işaretlemeseniz de hizmeti eksiksiz '
              'kullanabilirsiniz; bu onayı Hesap Ayarları\'ndaki aynı onay '
              'kutusundan istediğiniz zaman verebilir ya da geri '
              'çekebilirsiniz. Altyapı hizmeti olarak Supabase '
              'kullanılmaktadır; bu kapsamda veriler Supabase\'in '
              'sunucularında saklanır ve bu sunucular yurt dışında '
              'bulunabilir. Böyle bir durumda aktarım, KVKK m.9\'da aranan '
              '(yeterli korumanın bulunduğu ülke veya uygun güvencelerin '
              'sağlanması gibi) şartlara uygun şekilde yapılır. Yasal '
              'zorunluluk halinde yetkili makamlarla paylaşım yapılabilir.'),
          _P('Bunun yanında, adınız/takma isminiz, profil fotoğrafınız ve '
              'oyun istatistikleriniz k-lig (lider tablosu) ve arkadaşlık '
              'arama özelliği aracılığıyla diğer KAYITLI kullanıcılara '
              'görünür olur; e-posta adresiniz hiçbir zaman başka bir '
              'kullanıcıya gösterilmez. Bir oyunu paylaşmayı seçerseniz, o '
              'oyunun tahtası ve oyuncu isimleri/puanları giriş yapmamış '
              'ziyaretçiler dahil herkese açık bir bağlantı üzerinden '
              'görülebilir hale gelir; bu paylaşım geri alınamaz. Canlı '
              'oyunlarda gönderdiğiniz oyun içi sohbet mesajları o oyundaki '
              'diğer katılımcılara gerçek zamanlı olarak görünür ve oyun '
              'bittikten sonra oyun kaydının bir parçası olarak (mevcut '
              'skor/tahta görünürlüğüyle aynı şekilde, tüm kayıtlı '
              'kullanıcılara açık) saklanır.'),
          _P('Bir Canlı oyunda kimi sessize aldığınız yalnızca size '
              'görünür, diğer katılımcılar (sessize alınan kişi dahil) bunu '
              'hiçbir zaman göremez. Gönderdiğiniz uygunsuz paylaşım '
              'şikayetleri yalnızca inceleme amacıyla yönetici ekibiyle '
              'paylaşılır; şikayet edilen kullanıcıya şikayet edildiği, '
              'kimin şikayet ettiği ya da şikayetin içeriği hiçbir şekilde '
              'bildirilmez.'),
        ]),
        const _Section('5. Veri Saklama Süresi', [
          _P('Verileriniz hesabınız aktif olduğu sürece saklanır. '
              'Hesabınızı silmeniz durumunda tüm kişisel verileriniz 30 gün '
              'içinde kalıcı olarak silinir.'),
        ]),
        const _Section('6. Çerezler ve Yerel Depolama', [
          _P('Kelimeki, HTTP çerezi (cookie) kullanmaz. Bunun yerine '
              'oturumunuzu açık tutmak, oyun ilerlemenizi kaydetmek ve '
              'tercihlerinizi hatırlamak için tarayıcınızın yerel depolama '
              'alanı (localStorage/sessionStorage) kullanılır; bu veriler '
              'cihazınızda tutulur ve sunucularımıza otomatik gönderilmez. '
              'İstisna: misafir (girişsiz) oynadığınız bir oyunun sonucu, '
              'bağlantı yoksa ya da henüz hesabınız yoksa geçici olarak bu '
              'yerel depoda bekletilir; aynı cihazda daha sonra giriş yapar '
              'ya da kayıt olursanız bu bekleyen sonuçlar otomatik olarak '
              'hesabınıza aktarılıp sunucuya gönderilir. Reklam veya '
              'pazarlama amaçlı herhangi bir çerez ya da izleme teknolojisi '
              'kullanılmamaktadır. Girişsiz (misafir) ziyaretlerde, kaç '
              'benzersiz ziyaretçimiz olduğunu anlayabilmek için cihazınızda '
              'rastgele, kimliğinizle hiçbir şekilde ilişkilendirilmeyen '
              'anonim bir kod üretilir; bu kodla birlikte yalnızca kaba '
              'cihaz tipi (mobil/masaüstü) ve varsa bir paylaşım linkindeki '
              'kaynak etiketi sunucuya iletilir — bu veri hiçbir üçüncü '
              'tarafla paylaşılmaz ve hesabınızla asla eşleştirilmez. Yazı '
              'tipleri de dahil tüm statik içerikler kendi sunucularımızdan '
              'sağlanır; üçüncü taraf (ör. Google Fonts) çağrısı yapılmaz.'),
        ]),
        const _Section('7. KVKK Kapsamındaki Haklarınız', [
          _P('KVKK m.11 uyarınca aşağıdaki haklara sahipsiniz:'),
          _Bullets([
            'Kişisel verilerinizin işlenip işlenmediğini öğrenme',
            'İşlenmişse buna ilişkin bilgi talep etme',
            'İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını '
                'öğrenme',
            'Yurt içinde/yurt dışında aktarıldığı üçüncü kişileri bilme',
            'Eksik veya yanlış işlenmişse düzeltilmesini isteme',
            'Silinmesini veya yok edilmesini talep etme',
            'Düzeltme/silme işlemlerinin verilerin aktarıldığı üçüncü '
                'kişilere bildirilmesini isteme',
            'Otomatik sistemlerle analiz edilmesi sonucu aleyhinize çıkan '
                'bir sonuca itiraz etme',
            'Kanuna aykırı işleme nedeniyle uğradığınız zararın '
                'giderilmesini talep etme',
          ]),
        ]),
        _Section("8. Başvuru Usulü ve Kurul'a Şikayet Hakkı", [
          _FeedbackLinkLine(
            onTap: onFeedback,
            prefix: 'Yukarıdaki haklarınızı kullanmak için ',
            suffix: ' üzerinden başvurabilirsiniz. Başvurunuz niteliğine '
                'göre en geç 30 gün içinde ücretsiz olarak sonuçlandırılır. '
                'Başvurunuzun reddedilmesi, yetersiz bulunması veya '
                'süresinde cevap verilmemesi halinde Kişisel Verileri Koruma '
                "Kurulu'na şikayette bulunma hakkınız bulunmaktadır.",
          ),
        ]),
      ]),
    );
  }
}
