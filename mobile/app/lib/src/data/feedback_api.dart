// "Görüş Bildir" veri katmanı — web `submitFeedback` (src/lib/api.ts) +
// `submitFeedbackDurable`/`flushPendingFeedback` (src/utils/feedbackSync.ts)
// portu, GamesRepo'daki aynı gateway/repo bölünmesiyle.
//
// Web'den taşınan üç sözleşme:
// - **Kuyruk oturum BEKLEMEZ** (gameSync'ten fark): anonim geri bildirim
//   RLS tarafından zaten serbest (`feedback_insert_any`) — flush girişsiz
//   de dener; Supabase hiç yapılandırılmamışsa (gateway null) kuyruk
//   sessizce bekler (web trySubmit'in throw→enqueue dalı).
// - **Rate limit 3 mesaj / 10 dk** (web FEEDBACK_MAX_PER_WINDOW) —
//   geçmiş FlagsStore'da, karar burada. Web'in diğer iki bot önleminden
//   MIN_SUBMIT_MS UI'nın işi (FeedbackModal), honeypot ise BİLİNÇLİ port
//   edilmedi: gizli form alanı web crawler'ları için var, native uygulamada
//   o vektör yok.
// - **Kayıt asla kaybolmaz:** gönderilemeyen mesaj `pending_queue`ya
//   (`kind='feedback'`, 7 gün TTL — depolama fazında açılan kanal) düşer,
//   Setup'a her dönüşte tekrar denenir.
//
// Repo SENKRON kurulur (storage Future'ını içeride bekler) — böylece
// AuthModal→Terms/Privacy zinciri gibi UI katmanları Future taşımadan
// referans alabilir (bootstrap'te AppServices.feedback her zaman dolu).
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../storage/app_storage.dart';
import '../storage/pending_queue_store.dart';
import '../util/uuid.dart';

/// Web `FeedbackSource` ('game_end' | 'general') — db değeri sözleşme,
/// enum adı değil.
enum FeedbackSource {
  gameEnd('game_end'),
  general('general');

  final String db;
  const FeedbackSource(this.db);

  static FeedbackSource fromDb(String? v) => v == FeedbackSource.general.db
      ? FeedbackSource.general
      : FeedbackSource.gameEnd; // web readQueue'nun geriye dönük varsayılanı
}

/// Web FEEDBACK_WINDOW_MS / FEEDBACK_MAX_PER_WINDOW.
const Duration kFeedbackWindow = Duration(minutes: 10);
const int kFeedbackMaxPerWindow = 3;

enum FeedbackSubmitResult {
  /// Gönderildi YA DA kuyruğa alındı — web'de ikisi de kullanıcıya aynı
  /// "Teşekkürler" ekranını gösterir, ayrım UI'a sızmaz.
  accepted,

  /// 10 dakikada 3 mesaj sınırı — web 'Çok fazla mesaj gönderdin…' hatası.
  rateLimited,
}

/// `feedback` tablosuna tek ağ çağrısının soyutlaması — gerçek uç
/// [SupabaseFeedbackGateway], testlerde bellek içi sahte.
abstract class FeedbackGateway {
  Future<void> insert({
    required String message,
    String? email,
    required String source,
  });
}

class SupabaseFeedbackGateway implements FeedbackGateway {
  final SupabaseClient client;
  SupabaseFeedbackGateway(this.client);

  @override
  Future<void> insert({
    required String message,
    String? email,
    required String source,
  }) async {
    // Web submitFeedback birebir: girişliyse user_id bağlanır; e-posta
    // alanı boşsa hesabın e-postasına düşülür (`email || user?.email`).
    final user = client.auth.currentUser;
    final trimmedEmail = email?.trim();
    await client.from('feedback').insert({
      'user_id': user?.id,
      'email': (trimmedEmail != null && trimmedEmail.isNotEmpty)
          ? trimmedEmail
          : user?.email,
      'message': message.trim(),
      'source': source,
      'related_to': null, // ?contact=1&re= yalnızca web'de var
    });
  }
}

class FeedbackRepo {
  /// null = Supabase yapılandırılmamış — gönderim hiç denenmez, her mesaj
  /// kuyruğa düşer (web'in aynı davranışı: trySubmit throw → enqueue).
  final FeedbackGateway? gateway;

  final Future<AppStorage> _storage;
  final int Function() _nowMs;
  final String Function() _newId;

  FeedbackRepo(
    this.gateway,
    Future<AppStorage> storage, {
    int Function()? nowMs,
    String Function()? newId,
  })  : _storage = storage,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _newId = newId ?? uuidV4;

  /// Web `submitFeedbackDurable` + modal'daki rate-limit kontrolü: önce
  /// pencere denetimi, sonra hemen gönderme denemesi, olmazsa kuyruk.
  Future<FeedbackSubmitResult> submitDurable({
    required String message,
    String? email,
    required FeedbackSource source,
  }) async {
    final storage = await _storage;
    final now = _nowMs();
    final cutoff = now - kFeedbackWindow.inMilliseconds;
    final recent =
        storage.flags.feedbackSubmissionTimes.where((t) => t > cutoff).toList();
    if (recent.length >= kFeedbackMaxPerWindow) {
      return FeedbackSubmitResult.rateLimited;
    }

    if (!await _trySend(message: message, email: email, source: source.db)) {
      await storage.queue.enqueue(
        kind: feedbackKind,
        id: _newId(),
        payload: {
          'message': message,
          'email': (email?.trim().isNotEmpty ?? false) ? email!.trim() : null,
          'source': source.db,
        },
      );
    }
    // Web recordSubmission: kuyruğa düşen de pencereye sayılır (gönderim
    // başarısı değil, KULLANICI eylemi sayılıyor — spam penceresi bu).
    await storage.flags.setFeedbackSubmissionTimes([...recent, now]);
    return FeedbackSubmitResult.accepted;
  }

  bool _flushing = false;

  /// Kuyruktaki bekleyen mesajları göndermeyi dener — web
  /// `flushPendingFeedback`. Oturum ŞARTI YOK (dosya başındaki not);
  /// yalnızca gateway (Supabase) yoksa ağa hiç dokunmaz. Dönüş: gönderilen.
  Future<int> flushPending() async {
    if (_flushing || gateway == null) return 0;
    final storage = await _storage;
    final entries = await storage.queue.readAll(feedbackKind); // TTL burada
    if (entries.isEmpty) return 0;
    _flushing = true;
    var sent = 0;
    try {
      for (final e in entries) {
        final message = e.payload['message'];
        if (message is! String || message.trim().isEmpty) {
          // Çözülemeyen kayıt kuyruğu sonsuza dek tıkamasın (GamesRepo
          // flush'ının aynı kararı).
          await storage.queue.remove(e.id);
          continue;
        }
        final ok = await _trySend(
          message: message,
          email: e.payload['email'] as String?,
          source: FeedbackSource.fromDb(e.payload['source'] as String?).db,
        );
        if (ok) {
          await storage.queue.remove(e.id);
          sent++;
        }
        // Başarısızsa kuyrukta kalır — sonraki flush'ta tekrar denenir.
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }

  Future<bool> _trySend({
    required String message,
    String? email,
    required String source,
  }) async {
    final g = gateway;
    if (g == null) return false;
    try {
      await g.insert(message: message, email: email, source: source);
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] geri bildirim gönderilemedi, kuyrukta: $e');
      return false;
    }
  }
}
