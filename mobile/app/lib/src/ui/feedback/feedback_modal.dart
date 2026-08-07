// "Görüş Bildir" formu — src/components/FeedbackModal.tsx portu.
//
// Web'in üç bot önleminden İKİSİ taşındı, biri bilinçli taşınmadı:
// - Rate limit (3 mesaj/10dk) — FeedbackRepo'da (karar orada, geçmiş
//   FlagsStore'da).
// - MIN_SUBMIT_MS (1.5sn'den hızlı gönderim → hiçbir şey kaydetmeden sahte
//   "gönderildi" — botu bilgilendirme) — burada, web'deki yer.
// - Honeypot YOK: gizli form alanı web crawler'ları için var, native
//   uygulamada o vektör yok (mobile/CLAUDE.md parça günlüğü).
//
// Gönderim sonrası "üyeliğine devam" teklifi web'le birebir: misafir +
// e-posta girmiş → Evet, AuthModal'ı KAYIT modunda, e-posta dolu ve
// signup_channel='form' ile açar. Web'in `fromEmailLink` prop'u BİLİNÇLİ
// yok — o bağlam yalnızca web'in ?contact=1 e-posta linkinden geliyor,
// mobilde öyle bir giriş yolu yok.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../data/auth_service.dart';
import '../../data/feedback_api.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import '../auth/auth_modal.dart';

const Color _text = Color(0xFF1B2430);
const Color _muted = Color(0xFF5A6673);
const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFDCE2EA);
const Color _red = Color(0xFFE0483A);

/// Web MIN_SUBMIT_MS.
const int kFeedbackMinSubmitMs = 1500;

Future<void> showFeedbackModal(
  BuildContext context, {
  required AuthService auth,
  required FeedbackRepo? feedback,
  required FeedbackSource source,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        FeedbackModal(auth: auth, feedback: feedback, source: source),
  );
}

class FeedbackModal extends StatefulWidget {
  final AuthService auth;

  /// Depolamasız test ortamında null olabilir — form yine çalışır, gönderim
  /// hatayla sonuçlanır (pratikte bootstrap her zaman doldurur).
  final FeedbackRepo? feedback;
  final FeedbackSource source;

  /// Test kancası: fake-async bölgesinde modal açılışı ile dokunuş aynı
  /// "an"da olduğundan MIN_SUBMIT_MS kontrolü gerçek gönderimi hep bot
  /// sanırdı — testler kontrollü bir saat enjekte eder.
  final int Function()? nowMs;

  const FeedbackModal({
    super.key,
    required this.auth,
    required this.feedback,
    required this.source,
    this.nowMs,
  });

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  final _message = TextEditingController();
  late final TextEditingController _email =
      TextEditingController(text: widget.auth.user?.email ?? '');
  bool _busy = false;
  String? _error;
  bool _sent = false;

  // DİKKAT: `late final _openedAt = _now()` OLMAZ — late tembel
  // değerlendirilir, ilk erişim _submit içinde olurdu ve açılış zamanı
  // gönderim anına eşitlenip HER ilk gönderim bot sanılırdı (test yakaladı).
  late final int _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = _now();
  }

  int _now() =>
      (widget.nowMs ?? (() => DateTime.now().millisecondsSinceEpoch))();

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Mesaj boş olamaz.');
      return;
    }
    // 1.5sn'den hızlı gönderim: hiçbir şey kaydetmeden "gönderildi" göster
    // (web'in bot dalı — botu bilgilendirme).
    if (_now() - _openedAt < kFeedbackMinSubmitMs) {
      setState(() => _sent = true);
      return;
    }
    final repo = widget.feedback;
    if (repo == null) {
      setState(() => _error = 'Bir hata oluştu.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await repo.submitDurable(
        message: _message.text,
        email: _email.text,
        source: widget.source,
      );
      if (!mounted) return;
      if (result == FeedbackSubmitResult.rateLimited) {
        setState(() =>
            _error = 'Çok fazla mesaj gönderdin, birkaç dakika sonra tekrar dene.');
      } else {
        setState(() => _sent = true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        setState(() => _error = msg.trim().isEmpty ? 'Bir hata oluştu.' : msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSignup() {
    // Web: AuthModal feedback modalının ÜSTÜNE açılır, kapanışı ikisini de
    // kapatır (onClose=FeedbackModal.onClose). Mobil eşleniği: önce bu
    // dialogu kapat, sonra kayıt modalını aç — kayıt kapanınca kullanıcı
    // geldiği ekrana (GameOver/Terms) döner.
    final email = _email.text.trim();
    final nav = Navigator.of(context);
    nav.pop();
    showDialog<void>(
      context: nav.context,
      builder: (context) => AuthModal(
        auth: widget.auth,
        startInSignup: true,
        initialEmail: email,
        signupChannel: 'form',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    return KModal(
      title: 'Görüşleriniz Bizim İçin Önemli',
      child: _sent ? _buildSent(user != null) : _buildForm(user),
    );
  }

  Widget _buildSent(bool loggedIn) {
    final offerSignup = !loggedIn && _email.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text('Teşekkürler, mesajın bize ulaştı.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _text)),
        const SizedBox(height: 12),
        if (offerSignup) ...[
          Text('${_email.text.trim()} ile üyeliğine devam etmek ister misin?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeoButton(
                label: 'EVET',
                variant: NeoButtonVariant.accent,
                fontSize: 12,
                letterSpacing: 1.5,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                onPressed: _openSignup,
              ),
              const SizedBox(width: 8),
              NeoButton(
                label: 'HAYIR',
                variant: NeoButtonVariant.neutral,
                fontSize: 12,
                letterSpacing: 1.5,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ] else
          NeoButton(
            label: 'KAPAT',
            variant: NeoButtonVariant.accent,
            fontSize: 12,
            letterSpacing: 1.5,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            onPressed: () => Navigator.of(context).pop(),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildForm(User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Öneri, hata bildirimi ya da her türlü görüşünü bize iletebilirsin.',
          style:
              TextStyle(fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          enabled: !_busy,
          maxLines: 4,
          maxLength: 2000,
          autofocus: true,
          decoration: _decoration(hint: 'Mesajın'),
        ),
        const SizedBox(height: 12),
        if (user != null)
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Yanıt e-postan: '),
              TextSpan(
                  text: '${user.email}',
                  style: const TextStyle(color: _text)),
            ]),
            style: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 10, color: _muted),
          )
        else
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _decoration(
                hint: 'E-posta (yanıt alabilmen için, isteğe bağlı)'),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 11, color: _red)),
        ],
        const SizedBox(height: 16),
        NeoButton(
          label: _busy ? '…' : 'GÖNDER',
          variant: NeoButtonVariant.accent,
          fontSize: 12,
          letterSpacing: 1.5,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }

  InputDecoration _decoration({String? hint}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8A93A2)),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: border(_border),
      focusedBorder: border(_accent),
      disabledBorder: border(_border),
    );
  }
}
