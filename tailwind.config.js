/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#080C10',
        panel: '#0D1318',
        border: '#1E2D3D',
        text: '#C8D8E8',
        muted: '#3A5068',
        accent: '#00C8FF',
        ai: '#FF4060',
        player: '#00C8FF',
        gold: '#FFD040',
        green: '#00C870',
        red: '#FF4060',
        'tile-bg': '#0F1C26',
        'tile-border': '#1E3A52',
        'tile-letter': '#C8E8FF',
        'tile-pts': '#3A6888',
        void: '#050708',
      },
      fontFamily: {
        sans: ['"Space Grotesk"', 'sans-serif'],
        mono: ['"Space Mono"', 'monospace'],
      },
      keyframes: {
        pulse: {
          from: { boxShadow: '0 0 4px rgba(0,200,255,0.3)' },
          to: { boxShadow: '0 0 10px rgba(0,200,255,0.7)' },
        },
      },
      animation: {
        'tile-pulse': 'pulse 1s infinite alternate',
      },
    },
  },
  plugins: [],
};
