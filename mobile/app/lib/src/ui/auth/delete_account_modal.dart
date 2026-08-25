// Hesabı uygulama İÇİNDEN silme onayı — src/components/DeleteAccountModal.tsx
// portu (ROADMAP madde 2, MAĞAZA BLOKERİ).
//
// NEDEN VAR: Apple 5.1.1(v) ve Google'ın veri silme şartı, hesap açtıran
// uygulamalarda uygulama içinden başlatılabilen bir silme yolu istiyor.
// `kelimeki.com/hesap-silme/` sayfası yalnızca Play'in Data safety formuna
// verilen TALEP adresidir; gerçek işi yapan yol burasıdır.
//
// Web'den taşınan sözleşmeler:
// - AÇILIŞTA KURU ÇALIŞTIRMA: pencere açılır açılmaz `previewAccountDeletion`
//   çağrılır ve silinecekler GERÇEK sayılarla listelenir. Geri dönüşü olmayan
//   bir işlemde "ne kaybedeceğim" sorusunun cevabı tahmin değil ölçüm olmalı;
//   aynı rapor sunucunun uygulayacağı planın ta kendisi (aynı fonksiyon,
//   `dryRun` bayrağı).
// - Kuru çalıştırma başarısızsa silme butonu ETKİNLEŞMEZ (sunucuya
//   ulaşılamıyorsa ya da hesap silinemez bir hesapsa butonu açmak yanlış bir
//   söz verir).
// - Onay kelimesi `SİL`, karşılaştırma `trUpper` ile — native `toUpperCase()`
//   "sil"i "SIL" (noktasız I) yapar ve eşleşme sessizce tutmazdı.
// - Etiket listesi ve sıralaması web'deki `SILINECEK_ETIKET` ile birebir;
//   sıfır olan satırlar iki tarafta da gizleniyor.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../data/auth_service.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import '../form_input.dart';
import '../tokens.dart';

const String _onayKelimesi = 'SİL';

/// Web `SILINECEK_ETIKET` — anahtar sırası da dahil birebir.
const List<(String, String)> _silinecekEtiket = [
  ('games_kendi', 'Bitmiş oyun kaydın'),
  ('yarim_online_oyun', 'Devam eden Canlı oyunun'),
  ('local_game_saves', 'Devam eden Yapay Zeka oyunun'),
  ('online_game_messages', 'Gönderdiğin oyun içi mesaj'),
  ('friend_requests', 'Arkadaşlık bağın ve isteğin'),
  ('game_invites', 'Aldığın oyun daveti'),
  ('league_rewards', 'k-lig ödülün'),
  ('game_likes', 'Beğendiğin oyun'),
  ('feedback', 'Görüş bildirimin'),
  ('friend_invite_links', 'Davet bağlantın'),
  ('online_game_chat_reports', 'Şikayet kaydın'),
  ('avatar_dosyalari', 'Profil fotoğrafın'),
];

/// `true` döner = hesap SİLİNDİ (çağıran ekranı Setup'a döndürmeli).
Future<bool> showDeleteAccountModal(BuildContext context, AuthService auth) async {
  final silindi = await showDialog<bool>(
    context: context,
    builder: (context) => DeleteAccountModal(auth: auth),
  );
  return silindi ?? false;
}

class DeleteAccountModal extends StatefulWidget {
  final AuthService auth;
  const DeleteAccountModal({super.key, required this.auth});

  @override
  State<DeleteAccountModal> createState() => _DeleteAccountModalState();
}

class _DeleteAccountModalState extends State<DeleteAccountModal> {
  final _onay = TextEditingController();
  AccountDeletionReport? _rapor;
  bool _yukleniyor = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _onay.addListener(() => setState(() {}));
    _onIzle();
  }

  Future<void> _onIzle() async {
    try {
      final r = await widget.auth.previewAccountDeletion();
      if (!mounted) return;
      setState(() {
        _rapor = r;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AuthException ? e.message : 'Hesap bilgileri okunamadı.';
        _yukleniyor = false;
      });
    }
  }

  @override
  void dispose() {
    _onay.dispose();
    super.dispose();
  }

  Future<void> _sil() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await widget.auth.deleteMyAccount();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AuthException ? e.message : 'Hesap silinemedi.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rapor = _rapor;
    final satirlar = rapor == null
        ? const <(String, int)>[]
        : [
            for (final (anahtar, etiket) in _silinecekEtiket)
              if ((rapor.silinecek[anahtar] ?? 0) > 0)
                (etiket, rapor.silinecek[anahtar]!)
          ];
    final korunacak = rapor?.digerOyuncuKaydi ?? 0;
    final onayVerildi = trUpper(_onay.text.trim()) == _onayKelimesi;

    return KModal(
      title: 'HESABI SİL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hesabın ve hesabına bağlı kişisel verilerin kalıcı olarak silinir. '
            'Bu işlemin geri dönüşü yoktur.',
            style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontSize: 12, height: 1.6, color: kText),
          ),
          if (_yukleniyor) ...[
            const SizedBox(height: 12),
            const Text('Hesabın okunuyor…',
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 10, color: kMuted)),
          ],
          if (rapor != null) ...[
            const SizedBox(height: 16),
            const _BolumBasligi('SİLİNECEKLER'),
            const SizedBox(height: 8),
            if (satirlar.isEmpty)
              const Text(
                'Hesabına bağlı bir oyun/mesaj kaydı yok — yalnızca profilin silinecek.',
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk', fontSize: 12, height: 1.6, color: kMuted),
              )
            else
              for (final (etiket, n) in satirlar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(etiket,
                            style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 12,
                                color: kText)),
                      ),
                      const SizedBox(width: 12),
                      Text('$n',
                          style: const TextStyle(
                              fontFamily: 'SpaceMono', fontSize: 11, color: kMuted)),
                    ],
                  ),
                ),
            if (korunacak > 0) ...[
              const SizedBox(height: 16),
              const _BolumBasligi('KALACAKLAR'),
              const SizedBox(height: 8),
              Text(
                'Birlikte oynadığın kişilerin $korunacak bitmiş oyun kaydı onların '
                'kendi verisidir, silinmez — ama o kayıtlarda adın “Silinmiş oyuncu” '
                'olarak değiştirilir.',
                style: const TextStyle(
                    fontFamily: 'SpaceGrotesk', fontSize: 12, height: 1.6, color: kText),
              ),
            ],
            const SizedBox(height: 16),
            const Text('ONAYLAMAK İÇİN $_onayKelimesi YAZ',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    letterSpacing: 1,
                    color: kMuted)),
            const SizedBox(height: 4),
            SizedBox(
              height: kInputHeight,
              child: TextField(
                key: const ValueKey('field-delete-confirm'),
                controller: _onay,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: kInputDecoration(hint: _onayKelimesi),
                style: kInputTextStyle,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 11, color: kRed)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: NeoButton(
                label: 'VAZGEÇ',
                fontSize: 12,
                letterSpacing: 1.5,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NeoButton(
                label: _busy ? '…' : 'KALICI OLARAK SİL',
                variant: NeoButtonVariant.red,
                fontSize: 12,
                letterSpacing: 1.5,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: (_busy || rapor == null || !onayVerildi) ? null : _sil,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _BolumBasligi extends StatelessWidget {
  final String text;
  const _BolumBasligi(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              letterSpacing: 1.5,
              color: kAccent)),
    );
  }
}
