// Giriş + Kayıt penceresi — src/components/AuthModal.tsx portu (web'deki
// gibi TEK modal, içeride mod makinesi: login ↔ signup; 'forgot' modu
// recovery deep-link'i gerektirdiğinden SONRAKİ parça — dürüst
// "kelimeki.com üzerinden" diyaloğu).
//
// Kayıt akışının web'den taşınan incelikleri:
// - Takma isim boşluk kabul etmez (display_name_no_whitespace migration'ı)
//   — yazarken anında silinir.
// - Takma isim 400ms debounce'la canlı kontrol edilir
//   (check_nickname_available RPC'si; useNicknameAvailability portu).
//   Asıl doğruluk kaynağı DB'deki unique index — RPC yalnızca UX.
// - Doğrulama sırası web submit'iyle aynı; e-posta doğrulaması AÇIKSA kayıt
//   sonrası oturum açılmaz → login moduna dönülüp "E-postanı doğrula"
//   bilgisi gösterilir.
import 'dart:async';

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../data/auth_service.dart';
import '../../data/profile_fields.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import 'legal_modals.dart';

const Color _text = Color(0xFF1B2430);
const Color _muted = Color(0xFF5A6673);
const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFDCE2EA);
const Color _red = Color(0xFFE0483A);
const Color _green = Color(0xFF1FA05C);

Future<void> showLoginModal(BuildContext context, AuthService auth) {
  return showDialog<void>(
    context: context,
    builder: (context) => AuthModal(auth: auth),
  );
}

enum _Mode { login, signup }

enum _NickStatus { idle, checking, available, taken, error }

class AuthModal extends StatefulWidget {
  final AuthService auth;

  /// Takma isim kontrolü — testler ağsız sahte bir denetleyici enjekte eder;
  /// üretimde `auth.checkNicknameAvailable`.
  final Future<bool> Function(String nickname)? nicknameChecker;

  const AuthModal({super.key, required this.auth, this.nicknameChecker});

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  _Mode _mode = _Mode.login;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nickname = TextEditingController();
  final _birthDate = TextEditingController();
  String _gender = '';
  bool _termsAccepted = false;
  bool _marketingConsent = false;
  bool _showPassword = false;

  bool _busy = false;
  String? _error;
  String? _info; // login modunda "hesap oluşturuldu" bilgisi

  // ── useNicknameAvailability portu (400ms debounce + sıra sayacı) ────────
  _NickStatus _nickStatus = _NickStatus.idle;
  Timer? _nickTimer;
  int _nickSeq = 0;

  // Koşullar metnindeki iki link — TextSpan içinde dokunuş ancak
  // recognizer'la yakalanır; yaşam döngüsü state'te yönetilir.
  late final TapGestureRecognizer _termsRec = TapGestureRecognizer()
    ..onTap = () => showTermsModal(context);
  late final TapGestureRecognizer _privacyRec = TapGestureRecognizer()
    ..onTap = () => showPrivacyModal(context);

  @override
  void dispose() {
    _nickTimer?.cancel();
    _termsRec.dispose();
    _privacyRec.dispose();
    for (final c in [
      _email,
      _password,
      _firstName,
      _lastName,
      _nickname,
      _birthDate
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchMode(_Mode next) => setState(() {
        _mode = next;
        _error = null;
        _info = null;
      });

  void _onNicknameChanged(String raw) {
    // Boşluklar anında silinir (web onChange .replace(/\s+/g,'')).
    final stripped = raw.replaceAll(RegExp(r'\s+'), '');
    if (stripped != raw) {
      _nickname.value = TextEditingValue(
        text: stripped,
        selection: TextSelection.collapsed(offset: stripped.length),
      );
    }
    _nickTimer?.cancel();
    final trimmed = stripped.trim();
    if (trimmed.isEmpty) {
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
    if (e is _FormError) return e.message;
    return e.toString();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
      _busy = true;
    });
    try {
      if (_mode == _Mode.login) {
        final email = _email.text.trim();
        final password = _password.text;
        if (email.isEmpty || password.isEmpty) {
          throw const _FormError('E-posta ve şifre zorunludur.');
        }
        await widget.auth.signIn(email, password);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // ── Kayıt (web submit doğrulama sırası) ──────────────────────────
      if (_firstName.text.trim().isEmpty) {
        throw const _FormError('Ad zorunludur.');
      }
      if (_lastName.text.trim().isEmpty) {
        throw const _FormError('Soyad zorunludur.');
      }
      if (_nickname.text.trim().isEmpty) {
        throw const _FormError('Takma isim zorunludur.');
      }
      if (_nickStatus == _NickStatus.checking) {
        throw const _FormError(
            'Takma isim kontrol ediliyor, birazdan tekrar dene.');
      }
      if (_nickStatus == _NickStatus.taken) {
        throw const _FormError('Bu takma isim zaten kullanılıyor.');
      }
      if (_email.text.trim().isEmpty) {
        throw const _FormError('E-posta zorunludur.');
      }
      if (_password.text.isEmpty) throw const _FormError('Şifre zorunludur.');
      if (!_termsAccepted) {
        throw const _FormError(
            "Kullanım Koşulları ve Gizlilik Politikası'nı kabul etmelisiniz.");
      }
      final birthDateIso = trDateToIso(_birthDate.text); // bozuksa fırlatır
      final sessionOpened = await widget.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        nickname: _nickname.text.trim(),
        termsAccepted: _termsAccepted,
        gender: _gender.isEmpty ? null : _gender,
        birthDate: birthDateIso,
        marketingConsent: _marketingConsent,
      );
      if (!mounted) return;
      if (sessionOpened) {
        Navigator.of(context).pop();
      } else {
        // E-posta doğrulaması açık: web'deki gibi login moduna dön + bilgi.
        setState(() {
          _mode = _Mode.login;
          _info = 'Hesap oluşturuldu. E-postanı doğrulayıp giriş yap.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotComingSoon() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifremi Unuttum'),
        content: const Text(
            'Şifre sıfırlama akışı uygulamanın sonraki sürümünde gelecek. '
            'Şimdilik kelimeki.com üzerinden yapabilirsin.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('TAMAM'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signup = _mode == _Mode.signup;
    final submitDisabled = _busy ||
        (signup &&
            (_nickStatus == _NickStatus.checking ||
                _nickStatus == _NickStatus.taken));
    return KModal(
      title: signup ? 'Kayıt' : 'Giriş',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (signup) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _labeled('AD',
                        required: true,
                        child: _field(_firstName, hint: 'Adın')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _labeled('SOYAD',
                        required: true,
                        child: _field(_lastName, hint: 'Soyadın')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _labeled('TAKMA İSİM',
                  required: true,
                  child: _field(_nickname,
                      hint: 'Herkese görünen ismin',
                      onChanged: _onNicknameChanged)),
              if (_nickStatus == _NickStatus.checking)
                const _StatusLine('Kontrol ediliyor…', _muted),
              if (_nickStatus == _NickStatus.available)
                // Web '✓ Kullanılabilir' der; ✓ (U+2713) bundled fontların
                // hiçbirinde YOK (ölçüldü) — ★/► kararlarıyla aynı: ikon.
                const _StatusLine('Kullanılabilir', _green, icon: Icons.check),
              if (_nickStatus == _NickStatus.taken)
                const _StatusLine('Bu takma isim kullanımda.', _red),
              const SizedBox(height: 12),
            ],
            _labeled('E-POSTA',
                required: signup,
                child: _field(_email,
                    hint: signup ? 'Doğrulama linki gönderilir' : 'E-posta',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email])),
            if (signup) ...[
              const SizedBox(height: 12),
              _labeled('CİNSİYET',
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    onChanged:
                        _busy ? null : (v) => setState(() => _gender = v ?? ''),
                    decoration: _inputDecoration(),
                    // fontFamily şart: Dropdown'un `style`'ı tema fontunu
                    // MİRAS ALMAZ (ButtonStyle.textStyle dersiyle aynı) —
                    // verilmezse cihazda Roboto'ya, testte Ahem bloğuna düşer.
                    style: const TextStyle(
                        fontFamily: 'SpaceGrotesk', fontSize: 16, color: _text),
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
            ],
            const SizedBox(height: 12),
            _labeled('ŞİFRE',
                required: signup,
                child: _field(_password,
                    hint: 'Şifre',
                    obscure: !_showPassword,
                    autofillHints: [
                      signup
                          ? AutofillHints.newPassword
                          : AutofillHints.password
                    ],
                    onSubmitted: signup ? null : (_) => _submit(),
                    suffix: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip:
                          _showPassword ? 'Şifreyi gizle' : 'Şifreyi göster',
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: _muted,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ))),
            if (signup) ...[
              const SizedBox(height: 12),
              // Koşullar satırı: kutu işareti checkbox'tan, linkler kendi
              // modallerini açar (dokunuş linke gittiğinde kutu DEĞİŞMEZ —
              // web'de de link tıklaması checkbox'ı toggle etmiyor).
              _checkboxRow(
                value: _termsAccepted,
                onChanged: (v) => setState(() => _termsAccepted = v),
                toggleOnLabelTap: false,
                label: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'Kullanım Koşulları',
                        style: const TextStyle(
                            color: _accent,
                            decoration: TextDecoration.underline),
                        recognizer: _termsRec),
                    const TextSpan(text: ' ve '),
                    TextSpan(
                        text: 'Gizlilik Politikası',
                        style: const TextStyle(
                            color: _accent,
                            decoration: TextDecoration.underline),
                        recognizer: _privacyRec),
                    const TextSpan(text: "'nı okudum ve kabul ediyorum."),
                  ]),
                  style:
                      const TextStyle(fontSize: 12, height: 1.4, color: _muted),
                ),
              ),
              const SizedBox(height: 8),
              _checkboxRow(
                value: _marketingConsent,
                onChanged: (v) => setState(() => _marketingConsent = v),
                label: const Text(
                  'Pazarlama iletişimi almayı kabul ediyorum.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
                ),
              ),
              const SizedBox(height: 8),
              const Text('* Zorunlu alan',
                  style: TextStyle(
                      fontFamily: 'SpaceMono', fontSize: 9, color: _muted)),
            ],
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
                      fontFamily: 'SpaceMono', fontSize: 11, color: _red)),
            ],
            const SizedBox(height: 16),
            NeoButton(
              label: _busy
                  ? '…'
                  : signup
                      ? 'KAYIT OL'
                      : 'GİRİŞ YAP',
              variant: NeoButtonVariant.accent,
              fontSize: 13,
              letterSpacing: 1.2,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              onPressed: submitDisabled ? null : _submit,
            ),
            const SizedBox(height: 12),
            if (!signup) ...[
              _footerLink(
                child: const Text('Şifremi unuttum',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 12,
                        color: _muted,
                        decoration: TextDecoration.underline)),
                onTap: _forgotComingSoon,
              ),
              const SizedBox(height: 6),
              _footerLink(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Hesabın yok mu? '),
                    TextSpan(
                        text: 'Kayıt ol',
                        style: const TextStyle(
                            color: _accent,
                            decoration: TextDecoration.underline)),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
                ),
                onTap: () => _switchMode(_Mode.signup),
              ),
            ] else
              _footerLink(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Zaten hesabın var mı? '),
                    TextSpan(
                        text: 'Giriş yap',
                        style: const TextStyle(
                            color: _accent,
                            decoration: TextDecoration.underline)),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
                ),
                onTap: () => _switchMode(_Mode.login),
              ),
          ],
        ),
      ),
    );
  }

  // ── Küçük yapı taşları ──────────────────────────────────────────────────

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white, // web bg-bg
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8A93A2)),
      counterText: '',
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: border(_border),
      focusedBorder: border(_accent),
      disabledBorder: border(_border),
    );
  }

  Widget _field(
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    int? maxLength,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: !_busy,
      style: const TextStyle(fontSize: 16, color: _text), // iOS zoom dersi
      decoration: _inputDecoration(hint: hint, suffix: suffix),
    );
  }

  Widget _labeled(String label,
      {bool required = false, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: _red)),
            ]),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              letterSpacing: 1.5,
              color: _muted,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _checkboxRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Widget label,
    bool toggleOnLabelTap = true,
  }) {
    final row = Row(
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
        Expanded(child: label),
      ],
    );
    if (!toggleOnLabelTap) return row;
    return GestureDetector(
      onTap: _busy ? null : () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }

  Widget _footerLink({required Widget child, required VoidCallback onTap}) =>
      GestureDetector(
          onTap: _busy ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: child);
}

/// Form doğrulama hataları — web `throw new Error('Ad zorunludur.')`
/// eşleniği; friendlyAuthMessage eşleşmez, mesaj olduğu gibi gösterilir.
class _FormError implements Exception {
  final String message;
  const _FormError(this.message);
  @override
  String toString() => message;
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
        Text(text,
            style:
                TextStyle(fontFamily: 'SpaceMono', fontSize: 10, color: color)),
      ]),
    );
  }
}
