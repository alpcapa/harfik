/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#FFFFFF',
        panel: '#F5F7FA',
        border: '#DCE2EA',
        text: '#1B2430',
        muted: '#8A93A2',
        accent: '#2563EB',
        gold: '#B7791F',
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
