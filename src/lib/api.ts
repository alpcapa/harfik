// Harfik — Supabase veri erişim katmanı
//
// Tüm fonksiyonlar Supabase yapılandırılmamışsa güvenli biçimde boş/no-op
// döner, böylece oyun çevrimdışı da çalışır.
import { supabase, isSupabaseConfigured } from './supabase';
import type {
  LeaderboardRow,
  NewGame,
  PlayerStats,
  Profile,
} from './database.types';

/** Tamamlanan bir oyunu kaydeder (oturum açıksa). Eklenen kaydın id'sini döner. */
export async function saveGame(game: NewGame): Promise<string | null> {
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null; // yalnızca oturum açanların skoru kaydedilir

  const { data, error } = await supabase
    .from('games')
    .insert({ ...game, user_id: user.id })
    .select('id')
    .single();
  if (error) {
    console.error('[Harfik] saveGame hatası:', error.message);
    return null;
  }
  return data?.id ?? null;
}

/** Liderlik tablosunu döner (en yüksek skorlar). */
export async function fetchLeaderboard(limit = 20): Promise<LeaderboardRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('leaderboard')
    .select('*')
    .order('best_score', { ascending: false })
    .limit(limit);
  if (error) {
    console.error('[Harfik] fetchLeaderboard hatası:', error.message);
    return [];
  }
  return (data as LeaderboardRow[]) ?? [];
}

/** Oturum açan oyuncunun istatistik özetini döner. */
export async function fetchPlayerStats(): Promise<PlayerStats | null> {
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data, error } = await supabase
    .from('player_stats')
    .select('*')
    .eq('user_id', user.id)
    .maybeSingle();
  if (error) {
    console.error('[Harfik] fetchPlayerStats hatası:', error.message);
    return null;
  }
  return (data as PlayerStats) ?? null;
}

/** Oturum açan oyuncunun profilini döner. */
export async function fetchMyProfile(): Promise<Profile | null> {
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();
  if (error) {
    console.error('[Harfik] fetchMyProfile hatası:', error.message);
    return null;
  }
  return (data as Profile) ?? null;
}

/**
 * Kelimeyi sunucu tarafında doğrular (is_valid_word RPC). Supabase
 * yapılandırılmamışsa null döner; çağıran yerel sözlüğe düşmelidir.
 */
export async function isValidWordRemote(word: string): Promise<boolean | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('is_valid_word', {
    p_word: word,
  });
  if (error) {
    console.error('[Harfik] isValidWordRemote hatası:', error.message);
    return null;
  }
  return Boolean(data);
}

// ── Auth yardımcıları ───────────────────────────────────────────────────────

export async function signUp(email: string, password: string, username?: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.signUp({
    email,
    password,
    options: { data: username ? { username, display_name: username } : undefined },
  });
}

export async function signIn(email: string, password: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.signInWithPassword({ email, password });
}

export async function signOut() {
  if (!supabase) return;
  await supabase.auth.signOut();
}

export { isSupabaseConfigured };
