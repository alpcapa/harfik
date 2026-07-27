// Kelimeki — bekleyen arkadaşlık davet token'ı için tek seferlik kuyruk.
// /davet/:token sayfası kayıt/giriş öncesi bu token'ı burada saklar; e-posta
// doğrulaması açıkken bir kayıt, doğrulama linkine tıklanana kadar oturum
// açmadığından (ve o link genelde uygulamanın köküne döner, /davet/:token'a
// değil) token'ı burada tutmak, App.tsx'in oturum açılınca (hangi sayfadan
// olursa olsun) daveti yine de işleyebilmesini sağlar — tıpkı
// gameStorage.ts'teki terk edilmiş oyun kuyruğu gibi read-then-clear.
const PENDING_INVITE_KEY = 'kelimeki:pending-friend-invite-token';

export function storePendingInviteToken(token: string): void {
  try {
    localStorage.setItem(PENDING_INVITE_KEY, token);
  } catch {
    // yoksay
  }
}

/** Bekleyen token'ı okur ve kuyruğu temizler (bir daha işlenmesin diye). */
export function takePendingInviteToken(): string | null {
  try {
    const token = localStorage.getItem(PENDING_INVITE_KEY);
    if (token) localStorage.removeItem(PENDING_INVITE_KEY);
    return token;
  } catch {
    return null;
  }
}
