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
