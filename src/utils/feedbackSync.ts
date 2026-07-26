// Kelimeki — "Görüş Bildir" formu için offline kuyruk (gameSync.ts ile aynı
// desen). `submitFeedback` (lib/api.ts) hemen gönderilemezse — çevrimdışıyken,
// ağ hatasıyla ya da Supabase hiç yapılandırılmamışken — mesaj burada
// localStorage'a kuyruklanır ve bağlantı geri gelince tekrar denenir. Oyun
// kayıtlarının aksine (bkz. gameSync.ts) bir oturum beklemez: anonim geri
// bildirim RLS tarafından zaten serbest (`feedback_insert_any`).
import { submitFeedback } from '../lib/api';
import type { FeedbackSource } from '../lib/database.types';

interface PendingFeedback {
  message: string;
  email: string | null;
  source: FeedbackSource;
  relatedTo: string | null;
  created_at: string;
}

const PENDING_KEY = 'kelimeki:pending-feedback';
// Uzun süre çevrimdışı kalan biri sürekli mesaj gönderirse kuyruk sınırsız
// büyümesin diye üst sınır — aşılırsa en eski mesajlar düşürülür.
const MAX_PENDING_FEEDBACK = 50;
// gameStorage.ts'teki ABANDON_TIMEOUT_MS ile aynı süre/gerekçe: bir mesaj bu
// süre içinde gönderilemezse artık talep edilmeyecek sayılır ve düşürülür.
const PENDING_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

function readQueue(): PendingFeedback[] {
  try {
    const raw = localStorage.getItem(PENDING_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    const now = Date.now();
    const fresh = parsed.filter((f) => {
      const createdAt = Date.parse(f?.created_at);
      return !Number.isFinite(createdAt) || now - createdAt <= PENDING_EXPIRY_MS;
    });
    if (fresh.length !== parsed.length) writeQueue(fresh);
    // Rebrand öncesi kuyruklanmış eski kayıtlarda `source` yoktu — o zaman
    // tek form (oyun sonu) vardı, bu yüzden geriye dönük varsayılan 'game_end'.
    // relatedTo da sonradan eklendi — eski kayıtlarda yok, varsayılan null.
    return fresh.map((f) => ({ ...f, source: f.source ?? 'game_end', relatedTo: f.relatedTo ?? null }));
  } catch {
    return [];
  }
}

function writeQueue(queue: PendingFeedback[]): void {
  try {
    if (queue.length === 0) localStorage.removeItem(PENDING_KEY);
    else localStorage.setItem(PENDING_KEY, JSON.stringify(queue));
  } catch {
    // localStorage dolu/erişilemez olabilir — bir sonraki flush'ta tekrar denenir.
  }
}

function enqueue(item: PendingFeedback): void {
  const queue = readQueue();
  queue.push(item);
  if (queue.length > MAX_PENDING_FEEDBACK) queue.splice(0, queue.length - MAX_PENDING_FEEDBACK);
  writeQueue(queue);
}

async function trySubmit(item: PendingFeedback): Promise<boolean> {
  if (!navigator.onLine) return false;
  try {
    await submitFeedback(item.message, item.email ?? undefined, item.source, item.relatedTo);
    return true;
  } catch {
    return false;
  }
}

/**
 * Bir geri bildirim mesajını hemen göndermeyi dener; başarısız olursa
 * (offline, ağ hatası, Supabase yapılandırılmamış) bağlantı geri gelince
 * tekrar denenmek üzere kuyruğa eklenir — kullanıcı mesajını asla kaybetmez.
 */
export async function submitFeedbackDurable(
  message: string,
  email: string | undefined,
  source: FeedbackSource,
  relatedTo?: string | null,
): Promise<void> {
  const item: PendingFeedback = {
    message,
    email: email?.trim() || null,
    source,
    relatedTo: relatedTo ?? null,
    created_at: new Date().toISOString(),
  };
  const ok = await trySubmit(item);
  if (!ok) enqueue(item);
}

let flushing = false;

/** Kuyruktaki bekleyen geri bildirimleri tekrar göndermeyi dener. */
export async function flushPendingFeedback(): Promise<void> {
  if (flushing) return;
  const queue = readQueue();
  if (queue.length === 0) return;

  flushing = true;
  try {
    const remaining: PendingFeedback[] = [];
    for (const item of queue) {
      const ok = await trySubmit(item);
      if (!ok) remaining.push(item);
    }
    writeQueue(remaining);
  } finally {
    flushing = false;
  }
}
