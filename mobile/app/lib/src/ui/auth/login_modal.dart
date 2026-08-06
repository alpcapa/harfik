// Giriş penceresi — src/components/AuthModal.tsx'in LOGIN dalının portu.
// Bu fazda yalnızca e-posta+şifre girişi var; "Şifremi unuttum" (recovery
// deep-link'i gerektirir) ve "Kayıt ol" (nickname benzersizliği/koşullar
// akışı) SONRAKİ parçaların işi — ikisi de dürüst "sonraki sürümde"
// diyaloğu gösterir (ARKADAŞINLA sekmesindeki aynı desen), sahte bir form
// YOK.
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';

const Color _text = Color(0xFF1B2430);
const Color _muted = Color(0xFF5A6673);
const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFDCE2EA);
const Color _red = Color(0xFFE0483A);

Future<void> showLoginModal(BuildContext context, AuthService auth) {
  return showDialog<void>(
    context: context,
    builder: (context) => LoginModal(auth: auth),
  );
}

class LoginModal extends StatefulWidget {
  final AuthService auth;
  const LoginModal({super.key, required this.auth});

  @override
  State<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<LoginModal> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'E-posta ve şifre zorunludur.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.auth.signIn(email, password);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // Web deseni: eşleşen Türkçe mesaj; eşleşmeyen hata OLDUĞU GİBİ
      // gösterilir (gizlemek hata ayıklamayı imkânsız kılar).
      setState(() {
        _error = friendlyAuthMessage(e) ?? e.toString();
        _submitting = false;
      });
    }
  }

  void _comingSoon(String what) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(what),
        content: const Text(
            'Bu akış uygulamanın sonraki sürümünde gelecek. Şimdilik '
            'kelimeki.com üzerinden yapabilirsin.'),
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
    return KModal(
      title: 'Giriş',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _FieldLabel('E-POSTA'),
          _field(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 12),
          const _FieldLabel('ŞİFRE'),
          _field(
            controller: _password,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 11, color: _red),
            ),
          ],
          const SizedBox(height: 16),
          NeoButton(
            label: _submitting ? 'GİRİŞ YAPILIYOR…' : 'GİRİŞ YAP',
            variant: NeoButtonVariant.accent,
            fontSize: 13,
            letterSpacing: 1.2,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 12),
          _footerLink('Şifremi unuttum',
              onTap: () => _comingSoon('Şifremi Unuttum'), underlineAll: true),
          const SizedBox(height: 6),
          _footerLink('Hesabın yok mu? Kayıt ol',
              onTap: () => _comingSoon('Kayıt'), accentSuffix: 'Kayıt ol'),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      enabled: !_submitting,
      style: const TextStyle(fontSize: 16, color: _text), // iOS zoom dersi
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white, // web bg-bg
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _accent),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _border),
        ),
      ),
    );
  }

  Widget _footerLink(String label,
      {required VoidCallback onTap,
      bool underlineAll = false,
      String? accentSuffix}) {
    const base = TextStyle(
        fontFamily: 'SpaceMono', fontSize: 12, color: _muted, height: 1.2);
    Widget child;
    if (accentSuffix != null && label.endsWith(accentSuffix)) {
      final head = label.substring(0, label.length - accentSuffix.length);
      child = Text.rich(
        TextSpan(children: [
          TextSpan(text: head, style: base),
          TextSpan(
            text: accentSuffix,
            style: base.copyWith(
                color: _accent, decoration: TextDecoration.underline),
          ),
        ]),
        textAlign: TextAlign.center,
      );
    } else {
      child = Text(
        label,
        textAlign: TextAlign.center,
        style: underlineAll
            ? base.copyWith(decoration: TextDecoration.underline)
            : base,
      );
    }
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: child);
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 9,
          letterSpacing: 1.5,
          color: _muted,
        ),
      ),
    );
  }
}
