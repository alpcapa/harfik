// Kelimeki — Canlı oyunda YZ koltuğunun turunu sunucuda oynar (Faz 3,
// Adım 5). Herhangi bir katılımcının tarayıcısı (src/utils/onlineAiTurn.ts)
// bu fonksiyonu tetikler; YZ'nin gerçek rafı ASLA tarayıcıya gönderilmez —
// yalnızca bu fonksiyon içinde, service role ile `online_game_secrets`'tan
// okunup hemen kullanılır ve atılır. Tarayıcıya dönen yanıt yalnızca
// başarı/başarısızlık bilgisi taşır (bkz. jsonResponse çağrıları).
//
// Auth: çağıranın kendi JWT'siyle bir client oluşturulur (feedback-reply
// ile aynı desen) — hem katılımcı olduğunu doğrulamak hem de (rafı OKUMAK
// için değil, yalnızca) hamleyi submit_move'a GÖNDERMEK için kullanılır;
// submit_move'un kendi 'ai' dalı (bkz. 20260728170000 migration'ı) böylece
// herhangi bir katılımcının YZ adına gönderebilmesine izin verir. Rafı
// okumak için AYRI bir service-role client kullanılır (online_game_secrets
// hiçbir client rolüne grant edilmemiştir, yalnızca service role erişebilir).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS } from '../_shared/email.ts';
import { cornersFor } from './_game/constants.ts';
import { findAIMove } from './_game/ai.ts';
import { calcWordRawScores, computeInvasionSplit } from './_game/validator.ts';
import { getFormedWords, key } from './_game/board.ts';
import type { Board, Player, Tile } from './_game/types.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

/** Verilen oyuncunun tahtada hiç taşı yoksa true (ilk hamlesi) — gameReducer.ts'teki isFirstMove'un aynısı. */
function isFirstMoveFor(board: Board, current: number): boolean {
  for (const row of board) {
    for (const t of row) {
      if (t && t.owner === current) return false;
    }
  }
  return true;
}

interface OnlineSlot {
  type: 'human' | 'ai';
  user_id?: string;
}

interface PublicPlayer {
  corners: number[];
  surrendered: boolean;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Yetkisiz.' }, 401);
  }
  const jwt = authHeader.replace('Bearer ', '');

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return jsonResponse({ error: 'Yetkisiz.' }, 401);
  }

  let body: { game_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }
  const gameId = body.game_id;
  if (!gameId) {
    return jsonResponse({ error: 'game_id gerekli.' }, 400);
  }

  const { data: isParticipant } = await supabase.rpc('is_online_game_participant', {
    p_game_id: gameId,
    p_uid: userData.user.id,
  });
  if (!isParticipant) {
    return jsonResponse({ error: 'Bu oyunun katılımcısı değilsin.' }, 403);
  }

  const { data: game, error: gameError } = await supabase
    .from('online_games')
    .select('player_count, slots')
    .eq('id', gameId)
    .single();
  if (gameError || !game) {
    return jsonResponse({ error: 'Oyun bulunamadı.' }, 404);
  }

  const { data: publicState, error: stateError } = await supabase
    .from('online_game_states')
    .select('*')
    .eq('online_game_id', gameId)
    .maybeSingle();
  if (stateError || !publicState) {
    return jsonResponse({ error: "Oyun state'i bulunamadı." }, 404);
  }
  if (publicState.is_game_over) {
    return jsonResponse({ ok: true, played: false, reason: 'game_over' });
  }

  const current = publicState.current as number;
  const slots = game.slots as OnlineSlot[];
  const slot = slots[current];
  if (!slot || slot.type !== 'ai') {
    return jsonResponse({ ok: true, played: false, reason: 'not_ai_turn' });
  }

  // Rafı yalnızca burada, service role ile okuyoruz — bu response'a hiçbir
  // zaman dahil edilmez, yalnızca aşağıdaki findAIMove'a girdi olarak kullanılır.
  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: secrets, error: secretsError } = await serviceClient
    .from('online_game_secrets')
    .select('racks')
    .eq('online_game_id', gameId)
    .single();
  if (secretsError || !secrets) {
    console.error('[play-ai-turn] secrets okunamadı:', secretsError?.message);
    return jsonResponse({ error: 'Oyun verisi okunamadı.' }, 500);
  }

  const racks = secrets.racks as Tile[][];
  const rack = racks[current] ?? [];
  if (rack.length === 0) {
    return jsonResponse({ ok: true, played: false, reason: 'empty_rack' });
  }

  const board = publicState.board as Board;
  const bonuses = publicState.bonuses as Record<string, 'tw'>;
  const publicPlayers = publicState.players as PublicPlayer[];
  // findAIMove yalnızca corners/surrendered okuyor (computeAllTerritories
  // üzerinden) — rack/isim/skor gibi diğer alanlara hiç bakmıyor, bu yüzden
  // burada dolgu değerlerle bırakılabilir.
  const players: Player[] = publicPlayers.map((p) => ({
    name: '',
    corners: p.corners,
    colorIndex: 0,
    isAI: false,
    surrendered: p.surrendered,
    rack: [],
    score: 0,
    bestMoveScore: 0,
    longestWord: '',
    moveCount: 0,
    moveScoreSum: 0,
  }));

  const corners = cornersFor(game.player_count as number)[current];
  const firstMove = isFirstMoveFor(board, current);

  const move = findAIMove(board, rack, bonuses, current, corners, firstMove, players);

  if (!move) {
    // Oynanamaz durumda: torba doluysa tüm rafı değiştir, boşsa pas geç —
    // yerel AI_PLAY case'iyle (gameReducer.ts) aynı mantık.
    if ((publicState.bag_count as number) > 0) {
      const { error: submitError } = await supabase.rpc('submit_move', {
        p_game_id: gameId,
        p_action: 'exchange',
        p_placements: null,
        p_exchange_letters: rack.map((t) => t.letter),
        p_words: [],
        p_word_scores: null,
        p_base_points: 0,
        p_lost_shares: [],
      });
      if (submitError) return jsonResponse({ error: submitError.message }, 400);
      return jsonResponse({ ok: true, played: true, action: 'exchange' });
    }
    const { error: submitError } = await supabase.rpc('submit_move', {
      p_game_id: gameId,
      p_action: 'pass',
      p_placements: null,
      p_exchange_letters: null,
      p_words: [],
      p_word_scores: null,
      p_base_points: 0,
      p_lost_shares: [],
    });
    if (submitError) return jsonResponse({ error: submitError.message }, 400);
    return jsonResponse({ ok: true, played: true, action: 'pass' });
  }

  const placedMap: Record<string, Tile> = {};
  for (const p of move.placements) placedMap[key(p.r, p.c)] = p.tile;
  const formed = getFormedWords(board, placedMap);
  const wordScores = calcWordRawScores(board, placedMap, bonuses);
  const coords = move.placements.map((p) => [p.r, p.c] as [number, number]);
  const { shares } = computeInvasionSplit(coords, current, players, move.score, board);

  const placements = move.placements.map((p) => ({
    r: p.r,
    c: p.c,
    letter: p.tile.letter,
    wild: p.tile.wild,
    wildLetter: p.tile.wildLetter,
  }));

  const { error: submitError } = await supabase.rpc('submit_move', {
    p_game_id: gameId,
    p_action: 'play',
    p_placements: placements,
    p_exchange_letters: null,
    p_words: formed.map((f) => f.word),
    p_word_scores: wordScores,
    p_base_points: move.score,
    p_lost_shares: shares.map((s) => ({ to: s.index, amount: s.amount })),
  });
  if (submitError) {
    console.error('[play-ai-turn] submit_move hatası:', submitError.message);
    return jsonResponse({ error: submitError.message }, 400);
  }

  return jsonResponse({ ok: true, played: true, action: 'play', word: move.word, score: move.score });
});
