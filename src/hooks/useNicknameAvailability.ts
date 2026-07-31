import { useEffect, useRef, useState } from 'react';
import { checkNicknameAvailable } from '../lib/api';

export type NicknameAvailabilityStatus = 'idle' | 'checking' | 'available' | 'taken' | 'error';

/**
 * Girilen takma ismin (debounce'lu) uygunluğunu kontrol eder — RPC oturum
 * açıksa çağıranın kendi mevcut ismini otomatik hariç tuttuğundan
 * (`check_nickname_available`, `auth.uid()`), hem kayıt formu (AuthModal,
 * oturum yok) hem hesap ayarları (AccountSettingsModal, oturum var) aynı
 * hook'u kullanabilir. `currentValue` verilirse (hesap ayarlarında kişinin
 * hâlihazırda sahip olduğu isim) o değere eşitken kontrol atlanır.
 */
export function useNicknameAvailability(
  nickname: string,
  enabled: boolean,
  currentValue?: string,
): NicknameAvailabilityStatus {
  const [status, setStatus] = useState<NicknameAvailabilityStatus>('idle');
  const seqRef = useRef(0);

  useEffect(() => {
    const trimmed = nickname.trim();
    if (!enabled || !trimmed || trimmed === currentValue) {
      setStatus('idle');
      return;
    }
    setStatus('checking');
    const mySeq = ++seqRef.current;
    const timer = setTimeout(async () => {
      try {
        const available = await checkNicknameAvailable(trimmed);
        if (seqRef.current === mySeq) setStatus(available ? 'available' : 'taken');
      } catch {
        if (seqRef.current === mySeq) setStatus('error');
      }
    }, 400);
    return () => clearTimeout(timer);
  }, [nickname, enabled, currentValue]);

  return status;
}
