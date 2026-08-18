// Kelimeki — ilk açılışta Hızlı Başlangıç popup'ının yalnızca bir kez gösterilmesi için.
const STORAGE_KEY = 'kelimeki:seen-quickstart';

/** localStorage kapalı/erişilemez olabilir — bu durumda tekrar tekrar açılmasın diye "görüldü" varsayılır. */
export function hasSeenQuickStart(): boolean {
  try {
    return localStorage.getItem(STORAGE_KEY) === '1';
  } catch {
    return true;
  }
}

export function markQuickStartSeen(): void {
  try {
    localStorage.setItem(STORAGE_KEY, '1');
  } catch {
    // yoksay
  }
}

// Oyun İçi Mesajlaşma — Faz 1: Canlı oyun ekranındaki "Mesajlaşma" butonuna
// ilk kez basıldığında gösterilen hoşgeldin popup'ı, aynı bire bir desen.
const CHAT_INTRO_KEY = 'kelimeki:seen-chat-intro';

export function hasSeenChatIntro(): boolean {
  try {
    return localStorage.getItem(CHAT_INTRO_KEY) === '1';
  } catch {
    return true;
  }
}

export function markChatIntroSeen(): void {
  try {
    localStorage.setItem(CHAT_INTRO_KEY, '1');
  } catch {
    // yoksay
  }
}

// Oyun İçi Mesajlaşma — okunmamış mesaj göstergesi (rozet/sayı değil,
// yalnızca "Mesajlaşma" butonunun üstünde küçük bir kırmızı nokta). Oyuncu
// sohbeti bu oyun için en son ne zaman açtığını (son görülen mesajın
// created_at'i) cihaza yazar; bir sonraki girişte (ör. 1 gün sonra) bundan
// SONRA gelen ve kendisinin göndermediği bir mesaj varsa nokta çıkar —
// `OnlineGameScreen.tsx`'teki mesaj listesi ilk yüklendiğinde bununla
// karşılaştırılır. Cihaza özel (localStorage) — sunucuda okundu bilgisi
// tutulmuyor, bilinçli olarak kapsam dışı (bkz. CLAUDE.md).
function chatLastReadKey(gameId: string): string {
  return `kelimeki:chat-last-read:${gameId}`;
}

export function getChatLastReadAt(gameId: string): string | null {
  try {
    return localStorage.getItem(chatLastReadKey(gameId));
  } catch {
    return null;
  }
}

export function markChatRead(gameId: string, lastMessageAt: string): void {
  try {
    localStorage.setItem(chatLastReadKey(gameId), lastMessageAt);
  } catch {
    // yoksay
  }
}

// Karşılama katmanı (18 Ağustos 2026) — ilk gelen ziyaretçiye gösterilen
// tanıtım/karşılama sayfasını geçen kullanıcı bir daha görmez. Anahtar adı
// yukarıdaki iki kardeşinin kalıbını izliyor.
//
// Bu değer `src/main.tsx`'in geçiş fonksiyonu (`gec`) ve `<head>`'deki
// senkron kapı script'i (bkz. scripts/landing-plugin.js) tarafından
// PAYLAŞILIYOR — kapı script'i HTML'e gömülü düz JS olduğundan bu modülü
// import EDEMEZ; adı orada elle tekrarlanıyor ve bu sabitle senkron
// tutulmak zorunda (eklentinin kendi yorumunda da yazılı).
export const SEEN_INTRO_KEY = 'kelimeki:seen-intro';
