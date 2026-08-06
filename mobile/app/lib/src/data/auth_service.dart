// Kimlik doğrulama durumu — web `useAuth` (src/hooks/useAuth.tsx) +
// `signIn/signOut/fetchMyProfile` (src/lib/api.ts) eşleniği, projenin
// "ince ChangeNotifier kabuğu" kararıyla (mobile/CLAUDE.md, Üst Düzey
// Kararlar #5).
//
// Web'in iki sözleşmesi burada da AYNEN geçerli:
// 1. `user` ile profil çekiminin başlaması AYNI adımda olur — arada "user
//    dolu ama profileLoading hâlâ eski/false" bir an oluşursa UI e-posta
//    öneki gibi geçici bir isme düşüp hemen gerçek isimle değişir (web'de
//    yaşanmış ve düzeltilmiş hata).
// 2. Hiçbir hata `loading`/`profileLoading`'i sonsuza dek true bırakamaz —
//    aksi halde GİRİŞ butonu dahil oturuma bağlı hiçbir UI belirmez.
//
// Oturum kalıcılığı supabase_flutter'ın işi (SharedPreferences'a kendisi
// yazar); burada ayrıca bir şey saklanmaz.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `profiles` satırının bu fazda kullanılan alt kümesi (web `Profile`
/// tipinin eşleniği; skor/lig alanları sonraki parçaların işi).
class KProfile {
  final String id;
  final String? displayName;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final bool isAdmin;

  /// ISO `yyyy-mm-dd` (opsiyonel) — Skor Kartı'ndaki "Y:59/C:E" satırı.
  final String? birthDate;

  /// 'female' | 'male' | null (web `Gender`).
  final String? gender;

  const KProfile({
    required this.id,
    this.displayName,
    this.username,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.isAdmin = false,
    this.birthDate,
    this.gender,
  });

  factory KProfile.fromMap(Map<String, dynamic> m) => KProfile(
        id: m['id'] as String,
        displayName: m['display_name'] as String?,
        username: m['username'] as String?,
        firstName: m['first_name'] as String?,
        lastName: m['last_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        isAdmin: m['is_admin'] == true,
        birthDate: m['birth_date'] as String?,
        gender: m['gender'] as String?,
      );
}

class AuthService extends ChangeNotifier {
  final SupabaseClient? _client;

  User? _user;
  KProfile? _profile;
  bool _loading;
  bool _profileLoading;
  String? _currentUserId;
  StreamSubscription<AuthState>? _sub;

  AuthService(SupabaseClient? client)
      : _client = client,
        _loading = client != null,
        _profileLoading = client != null {
    final c = _client;
    if (c == null) return;
    // İlk oturum: supabase_flutter açılışta kalıcı oturumu zaten yüklemiş
    // olur — currentSession senkron okunabilir.
    _applyUser(c.auth.currentSession?.user);
    _loading = false;
    _sub = c.auth.onAuthStateChange.listen(
      (state) => _applyUser(state.session?.user),
      // Web getSession catch'inin eşleniği: akış hatası oturumu değiştirmez,
      // yalnızca loglanır — UI kilitlenmez.
      onError: (Object e) => debugPrint('[Kelimeki] auth akış hatası: $e'),
    );
  }

  /// Testler için: ağ olmadan istenen durumda başlar (configured sayılır).
  @visibleForTesting
  AuthService.fake({User? user, KProfile? profile, bool profileLoading = false})
      : _client = null,
        _user = user,
        _profile = profile,
        _loading = false,
        _profileLoading = profileLoading,
        _fakeConfigured = true;

  bool _fakeConfigured = false;

  /// Supabase anahtarları ayarlı mı — web `configured`. Değilse hesap/GİRİŞ
  /// UI'ı hiç çizilmez (web UserMenu `null` döner).
  bool get configured => _client != null || _fakeConfigured;

  User? get user => _user;
  KProfile? get profile => _profile;
  bool get loading => _loading;
  bool get profileLoading => _profileLoading;

  /// Web UserMenu `identityLoading` — avatar/isim henüz güvenilir değil.
  bool get identityLoading => _loading || (_user != null && _profileLoading);

  /// Web Setup `accountName` kuralı: display_name → first_name → (profil
  /// YÜKLENDİYSE) e-posta öneki. Profil beklenirken null kalır — UI bu ara
  /// durumu nötr "Yükleniyor…" olarak gösterir (accountPending).
  String? get accountName {
    final p = _profile;
    final byProfile = _firstNonEmpty([p?.displayName, p?.firstName]) ??
        (!_profileLoading ? _emailPrefix() : null);
    return byProfile;
  }

  /// Web Setup `accountPending`: oturum var ama isim henüz güvenilir değil.
  bool get accountPending => _user != null && accountName == null;

  /// Web UserMenu `name` kuralı (menü başlığındaki uzun kimlik).
  String get menuName =>
      _firstNonEmpty([
        _profile?.displayName,
        _profile?.username,
        [_profile?.firstName, _profile?.lastName]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ')
            .trim(),
        if (!_profileLoading) _user?.email,
      ]) ??
      'Hesabım';

  Future<void> signIn(String email, String password) async {
    final c = _client;
    if (c == null) throw const AuthException('Supabase yapılandırılmadı.');
    await c.auth.signInWithPassword(email: email, password: password);
    // Başarı/oturum güncellemesi onAuthStateChange üzerinden gelir.
  }

  /// Kayıt — web `signUp` (src/lib/api.ts) portu. `sharedxp_pending_profile`
  /// metadata'sını `handle_new_user` trigger'ı okur; display_name üst
  /// seviyede gider (e-posta doğrulaması açıkken session dönmez, sonraki
  /// bir update'e güvenilemez — web'deki aynı gerekçe). Dönen değer: oturum
  /// hemen açıldı mı (e-posta doğrulaması kapalıysa true).
  ///
  /// `signup_channel: 'direct'` web'le aynı — admin panelinin Üyeler
  /// tablosu yalnızca Direkt/Form ayrımını biliyor; mobile'a özel bir kanal
  /// eklemek panel/trigger tarafında ayrı bir karar, bu parçada değil.
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String nickname,
    required bool termsAccepted,
    String? gender,
    String? birthDate,
    bool marketingConsent = false,
  }) async {
    final c = _client;
    if (c == null) throw const AuthException('Supabase yapılandırılmadı.');
    try {
      final res = await c.auth.signUp(
        email: email,
        password: password,
        data: {
          'sharedxp_pending_profile': {
            'firstName': firstName,
            'lastName': lastName,
            'agreedToTerms': termsAccepted,
            'gender': gender,
            'birthDate': birthDate,
            'marketingConsent': marketingConsent,
          },
          'signup_channel': 'direct',
          'display_name': nickname,
        },
      );
      final session = res.session;
      if (session != null) {
        // E-posta doğrulaması kapalıysa kabul zamanını hemen yaz (web'le
        // aynı; doğrulama açıkken trigger'daki agreedToTerms yeterli).
        await c.from('profiles').update({'agreed_to_terms': termsAccepted}).eq(
            'id', session.user.id);
      }
      return session != null;
    } on AuthException catch (e) {
      // Yarış durumu güvenlik ağı (iki kişi aynı anda aynı ismi kaparsa) —
      // web friendlyNicknameError.
      throw friendlyNicknameError(e.message) ?? e;
    } on PostgrestException catch (e) {
      throw friendlyNicknameError(e.message) ?? e;
    }
  }

  /// `check_nickname_available` RPC'si — canlı UX geri bildirimi; asıl
  /// doğruluk kaynağı DB'deki unique index (web'deki aynı not).
  Future<bool> checkNicknameAvailable(String nickname) async {
    final c = _client;
    if (c == null) throw const AuthException('Supabase yapılandırılmadı.');
    final data = await c
        .rpc('check_nickname_available', params: {'p_nickname': nickname});
    return data == true;
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  void _applyUser(User? u) {
    _user = u;
    if (u?.id == _currentUserId) {
      notifyListeners();
      return;
    }
    _currentUserId = u?.id;
    if (u == null) {
      _profile = null;
      _profileLoading = false;
      notifyListeners();
      return;
    }
    _profileLoading = true;
    notifyListeners();
    _fetchProfile(u.id);
  }

  Future<void> _fetchProfile(String userId) async {
    final c = _client;
    if (c == null) return;
    try {
      final row =
          await c.from('profiles').select().eq('id', userId).maybeSingle();
      if (_currentUserId != userId) return; // bu arada hesap değişti
      _profile = row == null ? null : KProfile.fromMap(row);
    } catch (e) {
      // Web fetchMyProfile: hata profili null bırakır, yüklemeyi KİLİTLEMEZ.
      debugPrint('[Kelimeki] profil çekilemedi: $e');
      if (_currentUserId != userId) return;
    } finally {
      if (_currentUserId == userId) {
        _profileLoading = false;
        notifyListeners();
      }
    }
  }

  String? _emailPrefix() {
    final email = _user?.email;
    if (email == null || email.isEmpty) return null;
    return email.split('@').first;
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Postgres unique-violation hatasını takma isim için okunur bir mesaja
/// çevirir — web `friendlyNicknameError` birebir.
AuthException? friendlyNicknameError(String? message) {
  if (message != null &&
      RegExp('profiles_display_name_tr_lower_key|display_name',
              caseSensitive: false)
          .hasMatch(message) &&
      RegExp('duplicate key|unique', caseSensitive: false).hasMatch(message)) {
    return const AuthException(
        'Bu takma isim zaten kullanılıyor. Farklı bir tane dene.');
  }
  return null;
}

/// Web `friendlyAuthMessage` (src/lib/api.ts) portu — önce GoTrue hata
/// koduna, tutmazsa mesaj metnine bakar; ikisi de tutmazsa null döner ve
/// çağıran orijinal mesajı gösterir (bilinmeyen hatayı uydurma bir Türkçe
/// cümleyle gizlemek hata ayıklamayı imkânsız kılar — web'deki aynı ilke).
/// Kod eşlemesi web'le BİREBİR tutulmalı; yeni bir eşleme önce web'e girer.
String? friendlyAuthMessage(Object? err) {
  String? code;
  String msg = '';
  if (err is AuthException) {
    code = err.code;
    msg = err.message;
  } else if (err != null) {
    msg = err.toString();
  }

  const byCode = <String, String>{
    'invalid_credentials': 'E-posta ya da şifre hatalı.',
    // Bilgi sızıntısı kararı web'de ölçülüp verildi (bkz. src/lib/api.ts,
    // 4 Ağustos 2026) — mesaj aynı kalır.
    'user_banned':
        'Hesabınız donduruldu. Gerekçesi ve itiraz yolu e-posta adresinize gönderildi.',
    'email_not_confirmed':
        'E-posta adresini henüz doğrulamadın. Gelen kutunu (ve spam klasörünü) kontrol et.',
    'user_already_exists':
        'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı ya da şifreni sıfırlamayı dene.',
    'email_exists':
        'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı ya da şifreni sıfırlamayı dene.',
    'weak_password': 'Şifre çok zayıf. En az 6 karakter kullan.',
    'same_password': 'Yeni şifre eskisiyle aynı olamaz.',
    'otp_expired': 'Bağlantının süresi dolmuş. Yeni bir bağlantı iste.',
    'over_email_send_rate_limit':
        'Çok fazla e-posta isteği gönderildi. Birkaç dakika sonra tekrar dene.',
    'over_request_rate_limit':
        'Çok fazla deneme yapıldı. Birkaç dakika sonra tekrar dene.',
    'signup_disabled': 'Şu anda yeni kayıt alınmıyor.',
    'validation_failed': 'Girdiğin bilgilerde bir hata var, kontrol et.',
  };
  final byCodeHit = byCode[code];
  if (byCodeHit != null) return byCodeHit;

  final byMessage = <RegExp, String>{
    RegExp('user is banned', caseSensitive: false): byCode['user_banned']!,
    RegExp('invalid login credentials', caseSensitive: false):
        byCode['invalid_credentials']!,
    RegExp('email not confirmed', caseSensitive: false):
        byCode['email_not_confirmed']!,
    RegExp('user already registered|already been registered',
        caseSensitive: false): byCode['user_already_exists']!,
    RegExp('password should be at least', caseSensitive: false):
        byCode['weak_password']!,
    RegExp('new password should be different', caseSensitive: false):
        byCode['same_password']!,
    RegExp('token has expired or is invalid', caseSensitive: false):
        byCode['otp_expired']!,
    RegExp('for security purposes|rate limit', caseSensitive: false):
        byCode['over_request_rate_limit']!,
    RegExp('unable to validate email address|invalid format',
        caseSensitive: false): 'Geçerli bir e-posta adresi gir.',
  };
  for (final entry in byMessage.entries) {
    if (entry.key.hasMatch(msg)) return entry.value;
  }
  return null;
}
