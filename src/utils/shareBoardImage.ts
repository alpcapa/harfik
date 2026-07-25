// Kelimeki — bir DOM düğümünü (tahta önizlemesi) paylaşılabilir bir PNG'ye çevirir
import { toBlob } from 'html-to-image';

/** Verilen düğümü PNG blob'a çevirir; başarısız olursa (ör. CORS, tarayıcı desteği) null döner. */
export async function captureNodeAsPng(node: HTMLElement): Promise<Blob | null> {
  try {
    return await toBlob(node, { pixelRatio: 2, backgroundColor: '#ffffff' });
  } catch (err) {
    console.error('[Kelimeki] captureNodeAsPng hatası:', err);
    return null;
  }
}
