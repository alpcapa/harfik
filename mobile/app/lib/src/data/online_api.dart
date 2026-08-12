// Canlı oyun API sarmalayıcısı — şimdilik yalnızca submit_move; diğer
// RPC'ler (list_my_online_games, get_my_online_rack…) Canlı oyun UI fazında
// aynı sınıfa eklenecek.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/uuid.dart';

class OnlineApi {
  final SupabaseClient client;
  OnlineApi(this.client);

  /// Hamle gönderimi — HER çağrı bir `p_move_id` UUID'si taşır
  /// (20260805225619 migration'ı). Bu sayede ağ hatasında AYNI id ile
  /// yeniden denemek güvenlidir: hamle sunucuya ilk denemede ulaştıysa
  /// retry sessizce başarı döner (çifte hamle/sahte 'Sıra sende değil.'
  /// yapısal olarak imkânsız). Web istemcisi bu parametreyi göndermiyor —
  /// mobil ağların güvenilmezliği bu sarmalayıcının varlık sebebi.
  ///
  /// Retry YALNIZCA taşıma katmanı hatalarında (timeout, soket) yapılır;
  /// `PostgrestException` sunucunun kesin kararıdır (kural reddi, sıra
  /// kontrolü…) ve olduğu gibi fırlatılır.
  Future<void> submitMove({
    required String gameId,
    required String action, // 'play' | 'pass' | 'exchange'
    List<Map<String, Object?>>? placements,
    List<String>? exchangeLetters,
    List<String> words = const [],
    List<Map<String, Object?>>? wordScores,
    int basePoints = 0,
    List<Map<String, Object?>> lostShares = const [],
    String? moveId,
    int maxAttempts = 3,
  }) async {
    final id = moveId ?? uuidV4();
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        await client.rpc<void>('submit_move', params: {
          'p_game_id': gameId,
          'p_action': action,
          if (placements != null) 'p_placements': placements,
          if (exchangeLetters != null) 'p_exchange_letters': exchangeLetters,
          'p_words': words,
          if (wordScores != null) 'p_word_scores': wordScores,
          'p_base_points': basePoints,
          'p_lost_shares': lostShares,
          'p_move_id': id,
        }).timeout(const Duration(seconds: 15));
        return;
      } on PostgrestException {
        rethrow; // sunucu kararı — yeniden deneme anlamsız/yanlış
      } catch (_) {
        if (attempt >= maxAttempts) rethrow;
        // 400ms, 800ms — kısa üstel bekleme; id aynı kaldığından güvenli.
        await Future<void>.delayed(
            Duration(milliseconds: 400 * (1 << (attempt - 1))));
      }
    }
  }
}
