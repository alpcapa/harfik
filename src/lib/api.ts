// Harfik — Supabase veri erişim katmanı
//
// Tüm fonksiyonlar Supabase yapılandırılmamışsa güvenli biçimde boş/no-op
// döner, böylece oyun çevrimdışı da çalışır.
import { supabase, isSupabaseConfigured } from './supabase';
import type {
  LeaderboardRow,
  MyLeaderboardRank,
  NewGame,
  PlayerStats,
  Profile,
  WordMeaning,
} from './database.types';
import { getLocalMeaning } from '../data/meanings';

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

/** Liderlik tablosunu döner (toplam puana göre ilk 10). */
export async function fetchLeaderboard(limit = 10): Promise<LeaderboardRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('leaderboard')
    .select('*')
    .order('total_score', { ascending: false })
    .limit(limit);
  if (error) {
    console.error('[Harfik] fetchLeaderboard hatası:', error.message);
    return [];
  }
  return (data as LeaderboardRow[]) ?? [];
}

/** Oturum açan kullanıcının toplam puana göre sırasını döner. */
export async function fetchMyLeaderboardRank(userId: string): Promise<MyLeaderboardRank | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('my_leaderboard_rank', { p_user_id: userId });
  if (error) {
    console.error('[Harfik] fetchMyLeaderboardRank hatası:', error.message);
    return null;
  }
  const row = Array.isArray(data) ? data[0] : null;
  return row ? { rank: Number(row.rank), total_score: Number(row.total_score) } : null;
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

/**
 * Bir kelimenin sözlük anlamlarını döner. Önce Supabase'i (word_meaning RPC)
 * dener; yapılandırılmamışsa ya da kayıt yoksa yerel sözlüğe (meanings.json)
 * düşer. Hiçbir yerde bulunamazsa null döner.
 */
export async function fetchMeaning(word: string): Promise<WordMeaning | null> {
  // Tahtadaki harfler büyük olabilir; Türkçe kurallarıyla küçült (İ→i, I→ı).
  const norm = word.toLocaleLowerCase('tr');
  if (supabase) {
    const { data, error } = await supabase.rpc('word_meaning', {
      p_word: norm,
    });
    if (error) {
      console.error('[Harfik] fetchMeaning hatası:', error.message);
    } else if (Array.isArray(data) && data.length > 0) {
      const row = data[0] as WordMeaning;
      return {
        word: row.word,
        pos: row.pos,
        meanings: row.meanings ?? [],
      };
    }
  }
  // Yerel yedek.
  const local = await getLocalMeaning(norm);
  if (local) {
    return { word: norm, pos: local.pos, meanings: local.meanings };
  }
  return null;
}

// ── Auth yardımcıları ───────────────────────────────────────────────────────

export async function signUp(
  email: string,
  password: string,
  firstName: string,
  lastName: string,
  nickname?: string,
) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  // sharedxp_pending_profile formatı trigger tarafından okunur (camelCase).
  const result = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        sharedxp_pending_profile: {
          firstName,
          lastName,
        },
      },
    },
  });
  // Oturum hemen açıldıysa (e-posta doğrulaması kapalı) takma ismi kaydet.
  if (!result.error && result.data.session && nickname) {
    await supabase
      .from('profiles')
      .update({ display_name: nickname })
      .eq('id', result.data.session.user.id);
  }
  return result;
}

export async function signIn(email: string, password: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.signInWithPassword({ email, password });
}

export async function signOut() {
  if (!supabase) return;
  await supabase.auth.signOut();
}

// ── Profil güncelleme ────────────────────────────────────────────────────────

/** Oturum açan oyuncunun profilini günceller. Profil yoksa oluşturur. */
export async function updateProfile(
  patch: { first_name?: string; last_name?: string; display_name?: string | null; avatar_url?: string },
): Promise<Profile | null> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');

  const { data, error } = await supabase
    .from('profiles')
    .update(patch)
    .eq('id', user.id)
    .select('id');
  if (error) throw new Error(error.message);

  // Profil satırı henüz oluşturulmamışsa kayıt aç.
  if (!data || data.length === 0) {
    const firstName = patch.first_name ?? '';
    const lastName = patch.last_name ?? '';
    const { error: createErr } = await supabase.from('profiles').insert({
      id: user.id,
      username: user.email ? user.email.split('@')[0] : user.id,
      first_name: firstName,
      last_name: lastName,
      display_name: patch.display_name ?? null,
      avatar_url: patch.avatar_url ?? null,
    });
    if (createErr) throw new Error(createErr.message);
  }

  return null;
}

/** Oturum açan kullanıcının e-postasını değiştirir (doğrulama gerekebilir). */
export async function updateEmail(email: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.updateUser({ email });
}

/**
 * Oturum açan kullanıcının şifresini değiştirir.
 * Eski şifreyi doğrulamak için önce yeniden giriş yapılır.
 */
export async function updatePassword(oldPassword: string, newPassword: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user?.email) throw new Error('Oturum açık değil.');
  // Eski şifreyi doğrula.
  const { error: authErr } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: oldPassword,
  });
  if (authErr) throw new Error('Mevcut şifre hatalı.');
  return supabase.auth.updateUser({ password: newPassword });
}

/** Şifre sıfırlama e-postası gönderir. */
export async function sendPasswordReset(email: string) {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  return supabase.auth.resetPasswordForEmail(email);
}

/**
 * Profil fotoğrafını `avatars` depolama kovasına yükler, profildeki
 * avatar_url'i günceller ve genel (public) URL'i döner.
 */
export async function uploadAvatar(file: File): Promise<string> {
  if (!supabase) throw new Error('Supabase yapılandırılmadı.');
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error('Oturum açık değil.');

  const ext = (file.name.split('.').pop() || 'png').toLowerCase();
  const path = `${user.id}/avatar.${ext}`;

  const { error: upErr } = await supabase.storage
    .from('avatars')
    .upload(path, file, { upsert: true, contentType: file.type });
  if (upErr) throw new Error(upErr.message);

  const { data } = supabase.storage.from('avatars').getPublicUrl(path);
  // Önbelleği atlamak için sürüm parametresi ekle (aynı yol üzerine yazılır).
  const url = `${data.publicUrl}?v=${Date.now()}`;
  await updateProfile({ avatar_url: url });
  return url;
}

export { isSupabaseConfigured };
