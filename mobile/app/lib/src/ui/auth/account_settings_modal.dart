// Hesap Ayarları — src/components/AccountSettingsModal.tsx portu.
//
// Web'den taşınan sözleşmeler:
// - Doğrulama sırası `save()`'in kendisiyle birebir: Ad → Soyad → Takma
//   isim → (değiştiyse) takma isim kontrolü → doğum tarihi → gönderim.
// - `profilePatch` yalnızca GERÇEKTEN değişen alanları taşır — `updateProfile`
//   hiçbir şeyi koşulsuz üzerine yazmaz.
// - E-posta değişikliği AYRI bir adım (`updateEmail`, doğrulama gerektirir)
//   ve profil güncellemesi zaten başarılıysa e-posta adımı hata verse bile
//   "Profil güncellendi." notu kaybolmaz (web'in aynı davranışı).
// - `marketing_consent_at` İSTEMCİDEN HİÇ GÖNDERİLMEZ — sunucudaki bir
//   trigger `marketing_consent` geçişine göre kendisi yazar (bkz.
//   `AuthService.updateProfile` yorumu).
// - Takma isim boşluk kabul etmez, 400ms debounce'la canlı kontrol edilir
//   (`AuthModal`'daki `useNicknameAvailability` portuyla AYNI desen — burada
//   bilinçli olarak KÜÇÜK bir kopya: iki widget'ın private state'i arasında
//   paylaşılamayan bir yardımcı, web'de de iki ayrı bileşenin AYNI hook'u
//   ayrı ayrı çağırmasıyla aynı sonucu veriyor).
//
// Profil fotoğrafı değiştirme (7 Ağustos 2026, Parça 14) — web'in dosya
// seçici + `uploadAvatar`'ı: `pickAvatarImage` (galeriden seçim) →
// `AuthService.uploadAvatar` (doğrulama + `avatars` kovasına yükleme +
// `profiles.avatar_url` güncellemesi) → `refreshProfile`. Seçim
// `PickAvatarFn` olarak enjekte edilebilir (widget testleri gerçek galeriye
// dokunmadan akışı doğruluyor — `share_board.dart`'taki aynı desen).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../data/auth_service.dart';
import '../../data/profile_fields.dart';
import '../../util/avatar_image.dart';
import '../../util/avatar_picker.dart';
import '../game/modal_shell.dart';
import 'delete_account_modal.dart';
import '../game/neo_button.dart';
import 'k_avatar.dart';
import '../tokens.dart';
import '../form_input.dart';
import '../tap_target.dart';
const Color _muted = kMuted;
const Color _accent = kAccent;
const Color _red = kRed;
const Color _green = kGreen;

Future<void> showAccountSettingsModal(
  BuildContext context,
  AuthService auth, {
  Future<bool> Function(String nickname)? nicknameChecker,
  PickAvatarFn? pickAvatar,
  ShrinkAvatarFn? shrinkAvatar,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AccountSettingsModal(
      auth: auth,
      nicknameChecker: nicknameChecker,
      pickAvatar: pickAvatar,
      shrinkAvatar: shrinkAvatar,
    ),
  );
}

enum _NickStatus { idle, checking, available, taken, error }

class AccountSettingsModal extends StatefulWidget {
  final AuthService auth;

  /// Test injection'ı — `AuthModal.nicknameChecker` ile aynı desen;
  /// üretimde `auth.checkNicknameAvailable`.
  final Future<bool> Function(String nickname)? nicknameChecker;

  /// Test injection'ı — verilmezse gerçek `pickAvatarImage` (galeri).
  final PickAvatarFn? pickAvatar;

  /// Test injection'ı — verilmezse gerçek `shrinkAvatarIfNeeded`. Ayrı
  /// olmasının sebebi `pickAvatar` ile aynı: `dart:ui` kodeki widget
  /// testlerinde gerçek görsel baytları istiyor.
  final ShrinkAvatarFn? shrinkAvatar;

  const AccountSettingsModal(
      {super.key,
      required this.auth,
      this.nicknameChecker,
      this.pickAvatar,
      this.shrinkAvatar});

  @override
  State<AccountSettingsModal> createState() => _AccountSettingsModalState();
}

class _AccountSettingsModalState extends State<AccountSettingsModal> {
  late final _firstName =
      TextEditingController(text: widget.auth.profile?.firstName ?? '');
  late final _lastName =
      TextEditingController(text: widget.auth.profile?.lastName ?? '');
  late final _nickname =
      TextEditingController(text: widget.auth.profile?.displayName ?? '');
  late final _email =
      TextEditingController(text: widget.auth.user?.email ?? '');
  late final _birthDate =
      TextEditingController(text: isoToTrDate(widget.auth.profile?.birthDate));
  late String _gender = widget.auth.profile?.gender ?? '';
  late bool _marketingConsent = widget.auth.profile?.marketingConsent ?? false;
  late bool _emailNotifications =
      widget.auth.profile?.emailNotificationsEnabled ?? true;

  // Web `profileHydratedRef`/`emailHydratedRef`: modal profil/e-posta
  // ağdan gelmeden AÇILIRSA (avatar menüsü teoride identityLoading bitmeden
  // erişilemez ama güvenlik ağı olarak taşındı) alanlar geldiğinde BİR KEZ
  // doldurulur — kullanıcının o ana kadar yazdıklarının üzerine yazılmaz.
  bool _profileHydrated = false;
  bool _emailHydrated = false;

  _NickStatus _nickStatus = _NickStatus.idle;
  Timer? _nickTimer;
  int _nickSeq = 0;

  bool _busy = false;
  String? _error;
  String? _info;

  bool _uploadingAvatar = false;
  // Yükleme sonrası `auth.profile?.avatarUrl` bir sonraki `refreshProfile`e
  // kadar eski kalabilir (ağ gecikmesi) — o ana kadar yeni fotoğrafı hemen
  // göstermek için yerel bir önizleme.
  String? _avatarUrlOverride;

  @override
  void initState() {
    super.initState();
    _profileHydrated = widget.auth.profile != null;
    _emailHydrated = widget.auth.user != null;
    widget.auth.addListener(_onAuthEvent);
  }

  void _onAuthEvent() {
    final p = widget.auth.profile;
    if (!_profileHydrated && p != null) {
      _profileHydrated = true;
      setState(() {
        _firstName.text = p.firstName ?? '';
        _lastName.text = p.lastName ?? '';
        _nickname.text = p.displayName ?? '';
        _gender = p.gender ?? '';
        _birthDate.text = isoToTrDate(p.birthDate);
        _marketingConsent = p.marketingConsent;
        _emailNotifications = p.emailNotificationsEnabled;
      });
    }
    final u = widget.auth.user;
    if (!_emailHydrated && u != null) {
      _emailHydrated = true;
      setState(() => _email.text = u.email ?? '');
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthEvent);
    _nickTimer?.cancel();
    for (final c in [_firstName, _lastName, _nickname, _email, _birthDate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onNicknameChanged(String raw) {
    final stripped = raw.replaceAll(RegExp(r'\s+'), '');
    if (stripped != raw) {
      _nickname.value = TextEditingValue(
        text: stripped,
        selection: TextSelection.collapsed(offset: stripped.length),
      );
    }
    _nickTimer?.cancel();
    final trimmed = stripped.trim();
    // Web `useNicknameAvailability`'nin ikinci parametresi (`enabled`) her
    // zaman `true` — ama mevcut isimle aynıysa (kişi kendi ismini yazdı)
    // kontrolü atlar (`currentValue` parametresi). Aynı sonucu burada:
    // mevcut isimle eşitse idle'da bırak, sunucuya sorma.
    if (trimmed.isEmpty || trimmed == (widget.auth.profile?.displayName ?? '')) {
      setState(() => _nickStatus = _NickStatus.idle);
      return;
    }
    setState(() => _nickStatus = _NickStatus.checking);
    final mySeq = ++_nickSeq;
    _nickTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final checker =
            widget.nicknameChecker ?? widget.auth.checkNicknameAvailable;
        final available = await checker(trimmed);
        if (mounted && _nickSeq == mySeq) {
          setState(() => _nickStatus =
              available ? _NickStatus.available : _NickStatus.taken);
        }
      } catch (_) {
        if (mounted && _nickSeq == mySeq) {
          setState(() => _nickStatus = _NickStatus.error);
        }
      }
    });
  }

  String _describe(Object e) {
    final friendly = friendlyAuthMessage(e);
    if (friendly != null) return friendly;
    if (e is FormatException) return e.message; // trDateToIso Türkçe mesajları
    if (e is AuthException) return e.message;
    return e.toString();
  }

  /// Web `onPickFile` portu: seç → doğrula (AuthService.uploadAvatar zaten
  /// tip/boyut kontrolü yapıyor, burada yalnızca "iptal edildi" no-op'u) →
  /// yükle → `refreshProfile`. Kullanıcı galeriyi iptal ederse (`null`)
  /// sessizce hiçbir şey olmaz — web'de dosya seçmeden kapatmakla aynı.
  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _error = null;
      _info = null;
    });
    // SEÇİM ve KÜÇÜLTME de `try` İÇİNDE olmak ZORUNDA (13 Ağustos 2026,
    // bkz. Parça 87): `image_picker` galeri izni reddedilirse ya da
    // platform kanalı patlarsa `PlatformException` FIRLATIYOR. Bu iki
    // satır `try`ın dışındayken hata hiçbir yerde yakalanmıyor, kullanıcı
    // FOTOĞRAF DEĞİŞTİR'e basıyor ve HİÇBİR ŞEY olmuyordu — Parça 35'te
    // paylaş butonunda düzeltilen "sessizce yutulan aksiyon" sınıfının
    // aynısı, ve orada olduğu gibi asıl bedeli teşhis edilemez olması.
    final PickedImage? raw;
    final PickedImage picked;
    try {
      raw = await (widget.pickAvatar ?? pickAvatarImage)();
      if (raw == null || !mounted) return;
      // Yüklemeden ÖNCE küçült — 10 MB'lık giriş sınırı yalnızca "ne
      // seçebilirsin"i belirliyor, SAKLANAN her zaman küçük hâli
      // (bkz. util/avatar_image.dart). Native'de picker zaten küçülttüğü
      // için bu çağrı no-op; Flutter web'de asıl işi burası yapıyor.
      picked = await (widget.shrinkAvatar ?? shrinkAvatarIfNeeded)(raw);
    } catch (e) {
      debugPrint('[Kelimeki] avatar seçilemedi: $e');
      if (mounted) {
        setState(() => _error =
            'Fotoğraf seçilemedi. Galeri izni verildiğinden emin ol.');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await widget.auth
          .uploadAvatar(bytes: picked.bytes, mimeType: picked.mimeType);
      await widget.auth.refreshProfile();
      if (mounted) {
        setState(() {
          _avatarUrlOverride = url;
          _info = 'Profil fotoğrafı güncellendi.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _info = null;
    });
    final auth = widget.auth;
    final profile = auth.profile;

    if (_firstName.text.trim().isEmpty) {
      setState(() => _error = 'Ad zorunludur.');
      return;
    }
    if (_lastName.text.trim().isEmpty) {
      setState(() => _error = 'Soyad zorunludur.');
      return;
    }
    if (_nickname.text.trim().isEmpty) {
      setState(() => _error = 'Takma isim zorunludur.');
      return;
    }
    final nicknameChanged =
        _nickname.text.trim() != (profile?.displayName ?? '');
    if (nicknameChanged) {
      if (_nickStatus == _NickStatus.checking) {
        setState(() =>
            _error = 'Takma isim kontrol ediliyor, birazdan tekrar dene.');
        return;
      }
      if (_nickStatus == _NickStatus.taken) {
        setState(() => _error = 'Bu takma isim zaten kullanılıyor.');
        return;
      }
    }
    String? birthDateIso;
    try {
      birthDateIso = trDateToIso(_birthDate.text);
    } catch (e) {
      setState(() => _error = _describe(e));
      return;
    }

    setState(() => _busy = true);
    final notes = <String>[];
    try {
      final patch = <String, Object?>{};
      if (_firstName.text.trim() != (profile?.firstName ?? '')) {
        patch['first_name'] = _firstName.text.trim();
      }
      if (_lastName.text.trim() != (profile?.lastName ?? '')) {
        patch['last_name'] = _lastName.text.trim();
      }
      if (nicknameChanged) patch['display_name'] = _nickname.text.trim();
      if (_gender != (profile?.gender ?? '')) {
        patch['gender'] = _gender.isEmpty ? null : _gender;
      }
      if (birthDateIso != profile?.birthDate) patch['birth_date'] = birthDateIso;
      if (_marketingConsent != (profile?.marketingConsent ?? false)) {
        patch['marketing_consent'] = _marketingConsent;
      }
      if (_emailNotifications != (profile?.emailNotificationsEnabled ?? true)) {
        patch['email_notifications_enabled'] = _emailNotifications;
      }
      if (patch.isNotEmpty) {
        await auth.updateProfile(patch);
        await auth.refreshProfile();
        notes.add('Profil güncellendi.');
      }

      final emailTrim = _email.text.trim();
      if (emailTrim.isNotEmpty && emailTrim != (auth.user?.email ?? '')) {
        await auth.updateEmail(emailTrim);
        notes.add('E-posta değişikliği için onay bağlantısı gönderildi.');
      }

      if (mounted) {
        setState(
            () => _info = notes.isEmpty ? 'Değişiklik yok.' : notes.join(' '));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _describe(e);
          // Profil kısmı e-posta adımından ÖNCE zaten başarıyla
          // tamamlanmış olabilir — kullanıcı o değişikliklerin de
          // kaybolduğunu sanmasın diye notu ayrıca göster (web parity).
          if (notes.isNotEmpty) _info = notes.join(' ');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller, {
    Key? key,
    String? hint,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      maxLength: maxLength,
      onChanged: onChanged,
      enabled: !_busy,
      style: kInputTextStyle,
      decoration: kInputDecoration(hint: hint),
    );
  }

  Widget _labeled(String label, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                letterSpacing: 1.5,
                color: _muted,
              )),
        ),
        child,
      ],
    );
  }

  Widget _checkboxRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: _busy ? null : () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: _busy ? null : (v) => onChanged(v ?? false),
              activeColor: _accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, height: 1.4, color: _muted)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: _muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    // Web'in isim önceliği (Skor Kartı/Setup ile aynı kural) — Avatar'daki
    // baş harfler için.
    final name = _nickname.text.isNotEmpty
        ? _nickname.text
        : (_firstName.text.isNotEmpty ? _firstName.text : (auth.user?.email ?? 'Oyuncu'));

    return KModal(
      title: 'HESAP AYARLARI',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              KAvatar(
                  url: _avatarUrlOverride ?? auth.profile?.avatarUrl,
                  name: name,
                  size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NeoButton(
                      label:
                          _uploadingAvatar ? 'YÜKLENİYOR…' : 'FOTOĞRAF DEĞİŞTİR',
                      variant: NeoButtonVariant.neutral,
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      onPressed: _uploadingAvatar || _busy
                          ? null
                          : _pickAndUploadAvatar,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('JPG/PNG, en fazla 10 MB',
                          style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 9,
                              color: _muted)),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _labeled('AD',
                        child: _field(_firstName,
                            key: const ValueKey('field-first-name'),
                            hint: 'Adın', autofillHints: const ['given-name']))),
                const SizedBox(width: 8),
                Expanded(
                    child: _labeled('SOYAD',
                        child: _field(_lastName,
                            key: const ValueKey('field-last-name'),
                            hint: 'Soyadın',
                            autofillHints: const ['family-name']))),
              ],
            ),
            const SizedBox(height: 12),
            _labeled('TAKMA İSİM',
                child: _field(_nickname,
                    key: const ValueKey('field-nickname'),
                    hint: 'Herkese görünen ismin (boşluksuz)',
                    autofillHints: const ['nickname'],
                    onChanged: _onNicknameChanged)),
            if (_nickStatus == _NickStatus.checking)
              const _StatusLine('Kontrol ediliyor…', _muted),
            if (_nickStatus == _NickStatus.available)
              const _StatusLine('Kullanılabilir', _green, icon: Icons.check),
            if (_nickStatus == _NickStatus.taken)
              const _StatusLine('Bu takma isim kullanımda.', _red),
            if (_nickStatus == _NickStatus.error)
              const _StatusLine(
                  'Kullanılabilirlik kontrol edilemedi, kaydederken tekrar denenecek.',
                  _muted),
            const SizedBox(height: 12),
            _labeled('E-POSTA',
                child: _field(_email,
                    key: const ValueKey('field-email'),
                    hint: 'E-posta',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const ['email'])),
            const SizedBox(height: 12),
            _labeled('CİNSİYET',
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  onChanged:
                      _busy ? null : (v) => setState(() => _gender = v ?? ''),
                  decoration: kInputDecoration(),
                  style: kInputTextStyle,
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Belirtilmedi')),
                    for (final (value, label) in genderOptions)
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                )),
            const SizedBox(height: 12),
            _labeled('DOĞUM TARİHİ (GG/AA/YYYY)',
                child: _field(_birthDate,
                    key: const ValueKey('field-birth-date'),
                    hint: 'GG/AA/YYYY',
                    keyboardType: TextInputType.number,
                    maxLength: 10, onChanged: (v) {
                  final f = formatTrDateInput(v);
                  if (f != v) {
                    _birthDate.value = TextEditingValue(
                      text: f,
                      selection: TextSelection.collapsed(offset: f.length),
                    );
                  }
                })),
            const SizedBox(height: 12),
            _checkboxRow(
              value: _marketingConsent,
              onChanged: (v) => setState(() => _marketingConsent = v),
              label: 'Pazarlama iletişimi almayı kabul ediyorum.',
              subtitle: (auth.profile?.marketingConsent ?? false) &&
                      auth.profile?.marketingConsentAt != null
                  ? 'Kabul tarihi: ${_formatConsentDate(auth.profile!.marketingConsentAt!)}'
                  : null,
            ),
            const SizedBox(height: 8),
            _checkboxRow(
              value: _emailNotifications,
              onChanged: (v) => setState(() => _emailNotifications = v),
              label:
                  'Arkadaşlık isteği, oyun daveti ve süre uyarısı gibi e-posta bildirimlerini almak istiyorum.',
              subtitle:
                  'Bunu kapatsan da hesap güvenliğiyle ilgili mailleri (şifre sıfırlama, hesap durumu vb.) almaya devam edersin.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono', fontSize: 11, color: _red)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 10),
              Text(_info!,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono', fontSize: 11, color: _green)),
            ],
            const SizedBox(height: 16),
            NeoButton(
              label: _busy ? '…' : 'KAYDET',
              variant: NeoButtonVariant.accent,
              fontSize: 12,
              letterSpacing: 1.5,
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: (_busy ||
                      _nickStatus == _NickStatus.checking ||
                      _nickStatus == _NickStatus.taken)
                  ? null
                  : _save,
            ),

            // Hesap silme — ROADMAP madde 2 (MAĞAZA BLOKERİ). Apple 5.1.1(v)
            // ve Google'ın veri silme şartı, hesap açtıran uygulamalarda
            // uygulama İÇİNDEN başlatılabilen bir yol istiyor.
            // Yerleşim web'le birebir (`AccountSettingsModal.tsx`): KAYDET'in
            // ALTINDA, bir ayracın arkasında ve formun akışının DIŞINDA —
            // "ayarlarımı kaydediyorum" akışının parçası gibi görünmesin.
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dokunma hedefi 48px — projenin `TapTarget` kuralı
                  // (metin 11px olduğundan çıplak bir GestureDetector
                  // erişilebilirlik denetiminden geçmezdi).
                  TapTarget(
                    // Sola HİZALI bir link — ortalamak hizayı bozardı
                    // (bkz. TapTarget'ın `alignment` notu, "← Geri" vakası).
                    alignment: Alignment.centerLeft,
                    onTap: _busy ? null : _hesabiSil,
                    child: const Text(
                      'HESABIMI SİL',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: _red,
                        decoration: TextDecoration.underline,
                        decorationColor: _red,
                      ),
                    ),
                  ),
                  const Text('Kalıcıdır, geri alınamaz.',
                      style: TextStyle(
                          fontFamily: 'SpaceMono', fontSize: 9, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hesabiSil() async {
    final silindi = await showDeleteAccountModal(context, widget.auth);
    if (!silindi || !mounted) return;
    // Hesap gitti — Hesap Ayarları penceresi de kapanmalı, yoksa artık var
    // olmayan bir profilin formu ekranda kalır. `AuthService.deleteMyAccount`
    // oturumu zaten kapattığından altta Setup'ın girişsiz hâli belirir.
    Navigator.of(context).pop();
  }
}

/// Web `toLocaleDateString('tr-TR')` + `toLocaleTimeString('tr-TR', {hour:
/// '2-digit', minute:'2-digit'})` — "GG.AA.YYYY SS:DD".
String _formatConsentDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _StatusLine extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _StatusLine(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 10, color: color)),
        ),
      ]),
    );
  }
}
