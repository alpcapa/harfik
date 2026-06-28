// Harfik — Supabase şema tipleri (elle yazıldı; MCP erişimi açılınca
// `generate_typescript_types` ile otomatik üretilebilir).

export type GameResult = 'win' | 'lose' | 'tie';

export interface Profile {
  id: string;
  username: string | null;
  display_name: string | null;
  avatar_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface Game {
  id: string;
  user_id: string | null;
  player_score: number;
  ai_score: number;
  result: GameResult;
  turn_count: number;
  best_word: string | null;
  created_at: string;
}

/** games tablosuna eklenecek yeni kayıt. */
export type NewGame = Pick<
  Game,
  'player_score' | 'ai_score' | 'result' | 'turn_count'
> & {
  user_id?: string | null;
  best_word?: string | null;
};

/** Bir kelimenin sözlük kaydı (word_meaning RPC çıktısı). */
export interface WordMeaning {
  word: string;
  pos: string | null;
  meanings: string[];
}

export interface LeaderboardRow {
  user_id: string;
  username: string | null;
  display_name: string | null;
  avatar_url: string | null;
  best_score: number;
  games_played: number;
  wins: number;
}

export interface PlayerStats {
  user_id: string;
  games_played: number;
  wins: number;
  losses: number;
  ties: number;
  best_score: number;
  avg_score: number;
}
