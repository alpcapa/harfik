// Kelimeki — kök seviye crash yakalayıcı.
// React render hataları yalnızca class component'lerdeki
// getDerivedStateFromError/componentDidCatch ile yakalanabilir, hook karşılığı yok.
import { Component, type ErrorInfo, type ReactNode } from 'react';
import { clearGameState } from '../utils/gameStorage';
import { reportClientError } from '../utils/errorReporting';

interface Props {
  children: ReactNode;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Kelimeki çöktü:', error, info.componentStack);
    // React render hataları global `error` olayına DÜŞMEZ — React onları
    // burada tüketiyor. Bu yüzden ayrıca bildirilmek zorunda (ROADMAP #3).
    // Bu, telemetrinin en değerli tek kaydı: kullanıcı ekranında "Bir şeyler
    // ters gitti" gördüyse mutlaka birinin bakması gerekiyor.
    reportClientError(error, 'boundary');
  }

  private reload = () => window.location.reload();

  // Kaydedilmiş oyun state'i (localStorage, bkz. utils/gameStorage.ts) bozuksa
  // her reload App açılışında aynı hatayı tekrar fırlatıp bir crash loop'a
  // dönüşebilir — bu yüzden ayrı bir "kaydı temizle" çıkışı sağlanıyor.
  private resetAndReload = () => {
    clearGameState();
    window.location.reload();
  };

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div className="fixed inset-0 z-[300] flex items-center justify-center bg-bg p-4">
        <div className="w-full max-w-[360px] bg-panel border border-[#B8C2D1] rounded-xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] p-6 flex flex-col items-center gap-4 text-center">
          <h2 className="font-mono text-sm font-bold tracking-[1.5px] uppercase text-red">
            Bir şeyler ters gitti
          </h2>
          <p className="text-sm text-muted leading-relaxed">
            Kelimeki beklenmedik bir hatayla karşılaştı. Yeniden yüklemek genelde sorunu çözer.
          </p>
          <button
            onClick={this.reload}
            className="btn-raised bg-accent text-white rounded-md py-2.5 px-6 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform w-full"
          >
            Yeniden Yükle
          </button>
          <button
            onClick={this.resetAndReload}
            className="text-xs text-muted underline underline-offset-2"
          >
            Sorun devam ediyorsa: kayıtlı oyunu temizle
          </button>
        </div>
      </div>
    );
  }
}
