/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  future: {
    // Dokunmatik cihazda "yapışkan hover": iOS Safari bir butona
    // dokunulduktan sonra :hover'ı ekranın başka bir yerine dokunulana
    // KADAR üzerinde bırakıyor. Setup'ın altındaki "Kullanım Koşulları"
    // linkinde bu, modal kapandıktan sonra da duran bir alt çizgi olarak
    // görünüyordu (kullanıcı bildirdi, 11 Ağustos 2026) — Chromium'da
    // hasTouch ile birebir üretildi. Bu bayrak her `hover:` yardımcısını
    // `@media (hover:hover) and (pointer:fine)` içine alır: fareli
    // cihazlarda davranış aynı, dokunmatikte hover stili HİÇ uygulanmaz.
    // Tailwind v4'te varsayılan; tek tek linkleri yamamak yerine 38
    // kullanım yerini birden kapatıyor.
    hoverOnlyWhenSupported: true,
  },
  theme: {
    extend: {
      colors: {
        bg: '#FFFFFF',
        panel: '#F5F7FA',
        border: '#DCE2EA',
        text: '#1B2430',
        muted: '#5A6673',
        accent: '#2563EB',
        gold: '#B7791F',
        orange: '#F2650F',
        green: '#16A34A',
        red: '#DC2626',
        'tile-bg': '#FFFFFF',
        'tile-border': '#C7D0DC',
        'tile-letter': '#1B2430',
        'tile-pts': '#8A93A2',
        void: '#E8EBEF',
      },
      fontFamily: {
        sans: ['"Space Grotesk"', 'sans-serif'],
        mono: ['"Space Mono"', 'monospace'],
        tile: ['"Nunito"', 'sans-serif'],
      },
      keyframes: {
        pulse: {
          from: { boxShadow: '0 0 0 1px rgba(37,99,235,0.25)' },
          to: { boxShadow: '0 0 0 2px rgba(37,99,235,0.55)' },
        },
      },
      animation: {
        'tile-pulse': 'pulse 1s infinite alternate',
      },
    },
  },
  plugins: [],
};
