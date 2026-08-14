// Oyun İçi Mesajlaşma — Faz 1 (sohbet) + Faz 2 (sessize alma/raporlama).
// Web `src/lib/api.ts`'in ilgili bölümünün portu: `fetchOnlineGameMessages`/
// `sendOnlineGameMessage`/`subscribeOnlineGameMessages` + `fetchMyChatMutes`/
// `fetchMyActiveChatReports`/`setChatMute`/`reportChatParticipant`/
// `withdrawChatReports`. Yalnızca Canlı (online multiplayer) oyunlarda
// kullanılır — yerel/YZ oyunlarında bu dosyaya hiç dokunulmaz.
//
// Web'den taşınan sözleşmeler:
// - Mesaj göndermek RPC değil doğrudan RLS ile (`online_game_messages_insert_self`)
//   — 1-200 karakter kısıtı burada da (sunucuya gitmeden) tekrarlanır.
// - Realtime aboneliği yalnızca INSERT dinler (mesajlar düzenlenmiyor/silinmiyor).
// - Mute/rapor 3 Ağustos 2026'dan beri OYUNA değil KİŞİYE bağlı — bu yüzden
//   `myMutes`/`myActiveReports` gameId almaz (bir kişiyi sessize alman/rapor
//   etmen onunla oynadığın HER oyunda geçerli).
// - Rapor otomatik olarak hedefi de sessize alır (sunucu tarafında, RPC
//   gövdesi) — istemci ayrıca bir setMute çağırmaz.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineGameMessageRow {
  final String id;
  final String senderUserId;
  final String message;
  final String createdAt;

  const OnlineGameMessageRow({
    required this.id,
    required this.senderUserId,
    required this.message,
    required this.createdAt,
  });

  factory OnlineGameMessageRow.fromJson(Map<String, Object?> j) =>
      OnlineGameMessageRow(
        id: j['id'] as String,
        senderUserId: j['sender_user_id'] as String,
        message: j['message'] as String,
        createdAt: j['created_at'] as String,
      );
}

abstract class ChatGateway {
  Future<List<Map<String, Object?>>> messages(String gameId);
  Future<void> send(String gameId, String message);

  /// Yalnızca INSERT dinler; dönüş aboneliği kapatır.
  void Function() subscribe(
      String gameId, void Function(Map<String, Object?> row) onInsert);

  Future<List<String>> myMutes();
  Future<List<String>> myActiveReports();

  /// Sessize alınan/şikayet edilen kişi → KAYNAK oyun id'si.
  ///
  /// Arkadaş listesinden moderasyon durumunu yönetebilmek için (bkz.
  /// `FriendModerationSheet`). Oyun id'si şart, çünkü
  /// `mute_online_game_participant` katılımcılık kontrolünü `p_muted`
  /// dalından ÖNCE yapıyor — sessizden ÇIKARMA bile geçerli bir ortak oyun
  /// istiyor. Mute/rapor satırının kendisi `online_game_id` taşıyor ve o
  /// satır ancak ikisi de o oyunun katılımcısıyken yazılabildiğinden
  /// provenance olarak kullanılabiliyor; sunucuda değişiklik gerekmiyor.
  /// (Canlıda doğrulandı: BİTMİŞ bir oyunun id'siyle de geçiyor —
  /// `is_online_game_participant` oyunun status'üne bakmıyor.)
  Future<({Map<String, String> muted, Map<String, String> reported})>
      myModeration();
  Future<void> setMute(String gameId, String targetUserId, bool muted);
  Future<void> report(String gameId, String targetUserId, String reason);
  Future<void> withdrawReports(String targetUserId);
}

class SupabaseChatGateway implements ChatGateway {
  final SupabaseClient client;
  SupabaseChatGateway(this.client);

  @override
  Future<List<Map<String, Object?>>> messages(String gameId) async {
    final rows = await client
        .from('online_game_messages')
        .select()
        .eq('online_game_id', gameId)
        .order('created_at', ascending: true);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<void> send(String gameId, String message) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum açık değil.');
    await client.from('online_game_messages').insert({
      'online_game_id': gameId,
      'sender_user_id': user.id,
      'message': message,
    });
  }

  @override
  void Function() subscribe(
      String gameId, void Function(Map<String, Object?> row) onInsert) {
    final channel = client.channel('online_game_messages_$gameId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'online_game_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'online_game_id',
        value: gameId,
      ),
      callback: (payload) =>
          onInsert(payload.newRecord.cast<String, Object?>()),
    );
    channel.subscribe();
    return () => client.removeChannel(channel);
  }

  @override
  Future<List<String>> myMutes() async {
    final rows = await client
        .from('online_game_message_mutes')
        .select('muted_user_id');
    return [for (final r in rows) r['muted_user_id'] as String];
  }

  @override
  Future<List<String>> myActiveReports() async {
    final rows = await client
        .from('online_game_chat_reports')
        .select('reported_user_id')
        .filter('withdrawn_at', 'is', null);
    return [for (final r in rows) r['reported_user_id'] as String];
  }

  @override
  Future<({Map<String, String> muted, Map<String, String> reported})>
      myModeration() async {
    final mutes = await client
        .from('online_game_message_mutes')
        .select('muted_user_id, online_game_id');
    final reports = await client
        .from('online_game_chat_reports')
        .select('reported_user_id, online_game_id')
        .filter('withdrawn_at', 'is', null);
    final muted = <String, String>{};
    for (final r in mutes) {
      muted.putIfAbsent(
          r['muted_user_id'] as String, () => r['online_game_id'] as String);
    }
    final reported = <String, String>{};
    for (final r in reports) {
      reported.putIfAbsent(
          r['reported_user_id'] as String, () => r['online_game_id'] as String);
    }
    return (muted: muted, reported: reported);
  }

  @override
  Future<void> setMute(String gameId, String targetUserId, bool muted) async {
    await client.rpc('mute_online_game_participant', params: {
      'p_game_id': gameId,
      'p_target_user_id': targetUserId,
      'p_muted': muted,
    });
  }

  @override
  Future<void> report(
      String gameId, String targetUserId, String reason) async {
    await client.rpc('report_online_game_participant', params: {
      'p_game_id': gameId,
      'p_target_user_id': targetUserId,
      'p_reason': reason,
    });
  }

  @override
  Future<void> withdrawReports(String targetUserId) async {
    await client.rpc('withdraw_online_game_chat_reports', params: {
      'p_target_user_id': targetUserId,
    });
  }
}

/// Bir Canlı oyunun devam eden sohbeti + Faz 2 durumu için politika katmanı.
class ChatRepo {
  final ChatGateway gateway;
  ChatRepo(this.gateway);

  static const maxMessageLength = 200;
  static const maxReasonLength = 500;

  /// Ağ hatasında null (UI eski listeyi korur — diğer repoların sözleşmesi).
  Future<List<OnlineGameMessageRow>?> messages(String gameId) async {
    try {
      final rows = await gateway.messages(gameId);
      return [for (final r in rows) OnlineGameMessageRow.fromJson(r)];
    } catch (_) {
      return null;
    }
  }

  /// Hata FIRLATILIR (ChatModal formda gösterir) — web `sendOnlineGameMessage`
  /// istemci tarafı doğrulamasıyla aynı sınır. `async` OLMAK ZORUNDA: aksi
  /// halde doğrulama hatası senkron olarak çağıranın stack'inde fırlar
  /// (Future.error'a sarılmaz) — `expectLater(repo.send(...), throwsX)` gibi
  /// bir Future bekleyen kod, Future hiç oluşmadan test anında çöker.
  Future<void> send(String gameId, String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) {
      throw Exception(
          'Mesaj 1-$maxMessageLength karakter arasında olmalı.');
    }
    return gateway.send(gameId, trimmed);
  }

  void Function() subscribe(
          String gameId, void Function(OnlineGameMessageRow row) onInsert) =>
      gateway.subscribe(
          gameId, (row) => onInsert(OnlineGameMessageRow.fromJson(row)));

  /// Ağ hatasında boş set (web `fetchMyChatMutes`'un `[]` dönüşüyle aynı —
  /// bu iki liste yalnızca rozet/bildirim bastırma için, eksik veri en fazla
  /// bir rozeti geçici olarak gizler, veri kaybı yaratmaz).
  Future<Set<String>> myMutes() async {
    try {
      return (await gateway.myMutes()).toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<Set<String>> myActiveReports() async {
    try {
      return (await gateway.myActiveReports()).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Ağ hatasında boş haritalar — `myMutes` ile aynı gerekçe: eksik veri
  /// en fazla ikonu geçici gizler.
  Future<({Map<String, String> muted, Map<String, String> reported})>
      myModeration() async {
    try {
      return await gateway.myModeration();
    } catch (_) {
      return (muted: const <String, String>{}, reported: const <String, String>{});
    }
  }

  Future<void> setMute(String gameId, String targetUserId, bool muted) =>
      gateway.setMute(gameId, targetUserId, muted);

  /// `async` gerekliliği `send`'deki aynı ders — bkz. oradaki yorum.
  Future<void> report(String gameId, String targetUserId, String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty || trimmed.length > maxReasonLength) {
      throw Exception(
          'Rapor nedeni 1-$maxReasonLength karakter arasında olmalı.');
    }
    return gateway.report(gameId, targetUserId, trimmed);
  }

  Future<void> withdrawReports(String targetUserId) =>
      gateway.withdrawReports(targetUserId);
}
