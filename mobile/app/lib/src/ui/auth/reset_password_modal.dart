// "Yeni Şifre Belirle" — src/components/ResetPasswordModal.tsx portu.
//
// Sıfırlama e-postasındaki bağlantı tıklanınca supabase_flutter deep link'i
// yakalayıp bir RECOVERY oturumu açar (kullanıcı fiilen giriş yapmış olur)
// ve AuthService.passwordRecovery true olur; KelimekiApp'in builder kapısı
// (app.dart) bu modalı TÜM rotaların önüne çıkarır — web App.tsx'in erken
// dönüşünün eşleniği. "Kapat"/✕ yeni şifre belirlemeden de çıkabilir; oturum
// (web'deki gibi) açık kalır.
//
// Bir Navigator route'u OLMADAN inline render edildiğinden KModal'a `onClose`
// geçilir (pop edilecek dialog route'u yok — modal_shell.dart'taki not).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../data/auth_service.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import '../tokens.dart';
import '../form_input.dart';

const Color _muted = kMuted;
const Color _red = kRed;
const Color _green = kGreen;

class ResetPasswordModal extends StatefulWidget {
  final AuthService auth;

  /// Web `onDone` — hem başarı sonrası "Kapat" hem ✕ bunu çağırır
  /// (clearPasswordRecovery).
  final VoidCallback onDone;

  /// Şifre yazma ucu — testler ağsız sahte geçer; üretimde
  /// `auth.setNewPassword` (AuthModal.nicknameChecker ile aynı desen).
  final Future<void> Function(String password)? passwordSetter;

  const ResetPasswordModal({
    super.key,
    required this.auth,
    required this.onDone,
    this.passwordSetter,
  });

  @override
  State<ResetPasswordModal> createState() => _ResetPasswordModalState();
}

class _ResetPasswordModalState extends State<ResetPasswordModal> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    // Web submit doğrulama sırası/metinleri birebir.
    if (_password.text.length < 6) {
      setState(() => _error = 'Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Şifreler eşleşmiyor.');
      return;
    }
    setState(() => _busy = true);
    try {
      final setter = widget.passwordSetter ?? widget.auth.setNewPassword;
      await setter(_password.text);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      // Web: friendlyAuthMessage ?? err.message ?? 'Bir hata oluştu.'
      final friendly = friendlyAuthMessage(e);
      final raw = e is AuthException ? e.message : e.toString();
      if (mounted) {
        setState(() => _error =
            friendly ?? (raw.trim().isEmpty ? 'Bir hata oluştu.' : raw));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return KModal(
        title: 'Yeni Şifre Belirle',
        onClose: widget.onDone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Şifren başarıyla değiştirildi.',
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 12, color: _green)),
            const SizedBox(height: 12),
            NeoButton(
              label: 'KAPAT',
              variant: NeoButtonVariant.accent,
              fontSize: 12,
              letterSpacing: 1.5,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              onPressed: widget.onDone,
            ),
          ],
        ),
      );
    }

    return KModal(
      title: 'Yeni Şifre Belirle',
      onClose: widget.onDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Hesabın için yeni bir şifre belirle.',
              style: TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
          const SizedBox(height: 12),
          _field(_password, hint: 'Yeni şifre', autofocus: true),
          const SizedBox(height: 12),
          _field(_confirm, hint: 'Yeni şifre (tekrar)',
              onSubmitted: (_) => _submit()),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 11, color: _red)),
          ],
          const SizedBox(height: 16),
          NeoButton(
            label: _busy ? '…' : 'ŞİFREYİ KAYDET',
            variant: NeoButtonVariant.accent,
            fontSize: 12,
            letterSpacing: 1.5,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String hint,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: true, // web'de bu formda göster/gizle yok
      autofocus: autofocus,
      enabled: !_busy,
      onSubmitted: onSubmitted,
      autofillHints: const [AutofillHints.newPassword],
      style: kInputTextStyle,
      decoration: kInputDecoration(hint: hint),
    );
  }
}
