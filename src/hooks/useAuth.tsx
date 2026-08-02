// Kelimeki — kimlik doğrulama bağlamı (Supabase Auth)
import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import type { User } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from '../lib/supabase';
import { fetchMyProfile } from '../lib/api';
import type { Profile } from '../lib/database.types';

interface AuthContextValue {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  /** user set ama profili henüz (ilk kez) çekilmedi — display_name/first_name
   *  henüz güvenilir değil, bu sırada e-posta gibi geçici yer tutuculara
   *  düşülmemeli (aksi halde profil gelene kadar bir anlık yanlış isim
   *  görünür). */
  profileLoading: boolean;
  /** Supabase anahtarları ayarlı mı? */
  configured: boolean;
  /** Şifre sıfırlama bağlantısı tıklanıp bu sekmede recovery oturumu açıldı mı? */
  passwordRecovery: boolean;
  /** "Yeni şifre belirle" akışı tamamlanınca/kapatılınca çağrılır. */
  clearPasswordRecovery: () => void;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  profile: null,
  loading: true,
  profileLoading: true,
  configured: false,
  passwordRecovery: false,
  clearPasswordRecovery: () => {},
  refreshProfile: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileLoading, setProfileLoading] = useState(true);
  const [passwordRecovery, setPasswordRecovery] = useState(false);

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      setProfileLoading(false);
      return;
    }

    // `user` state'ini set eden yer ile profil çekimini başlatan yer ayrı
    // efektler olursa, arada `user` dolu ama `profileLoading` henüz eski
    // (false) değerinde olan bir render anı oluşur — tam o anda Setup vb.
    // ekranlar profil yokmuş gibi e-posta öneki gibi geçici bir isme düşer.
    // Bunu önlemek için ikisini burada, aynı callback içinde (aynı state
    // batch'inde) birlikte güncelliyoruz.
    let currentUserId: string | null = null;
    const applyUser = (u: User | null) => {
      setUser(u);
      if (u?.id === currentUserId) return;
      currentUserId = u?.id ?? null;
      if (u) {
        setProfileLoading(true);
        fetchMyProfile()
          .then((p) => {
            if (currentUserId === u.id) {
              setProfile(p);
              setProfileLoading(false);
            }
          })
          .catch((err) => {
            // fetchMyProfile kendi Supabase sorgu hatasını yakalayıp `null`
            // döner, ama içindeki `supabase.auth.getUser()` çağrısı
            // beklenmedik şekilde reddederse bu `.catch` olmadan
            // `profileLoading` sonsuza dek `true` kalır — isim hiçbir zaman
            // belirmez (bkz. kod incelemesi).
            console.error('[Kelimeki] fetchMyProfile beklenmedik hata:', err);
            if (currentUserId === u.id) setProfileLoading(false);
          });
      } else {
        setProfile(null);
        setProfileLoading(false);
      }
    };

    supabase.auth
      .getSession()
      .then(({ data }) => {
        applyUser(data.session?.user ?? null);
        setLoading(false);
      })
      .catch((err) => {
        // Sandboxed sekme/depolama erişimi engelli gibi nadir durumlarda
        // reddedebilir — bu olmadan `loading` sonsuza dek `true` kalır ve
        // "Giriş" butonu dahil oturum durumuna bağlı hiçbir UI hiç belirmez.
        console.error('[Kelimeki] getSession beklenmedik hata:', err);
        setLoading(false);
      });
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      applyUser(session?.user ?? null);
      if (event === 'PASSWORD_RECOVERY') setPasswordRecovery(true);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const refreshProfile = async () => {
    if (user) setProfile(await fetchMyProfile());
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        profile,
        loading,
        profileLoading,
        configured: isSupabaseConfigured,
        passwordRecovery,
        clearPasswordRecovery: () => setPasswordRecovery(false),
        refreshProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  return useContext(AuthContext);
}
