/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Workspace claro
        canvas: '#F6F7F9',
        card: '#FFFFFF',
        // Sidebar azul-marinho muito escuro
        sidebar: {
          DEFAULT: '#0B1524',
          soft: '#111E33',
          line: '#1E2E47',
          text: '#9FB0C7',
          muted: '#64789A',
        },
        // Tinta / hierarquia de texto
        ink: {
          DEFAULT: '#0E1726',
          soft: '#334155',
          muted: '#64748B',
          faint: '#94A3B8',
        },
        line: '#E6E9EF',
        line2: '#EEF1F5',
        // Marca — verde esmeralda / teal (ação e sucesso)
        brand: {
          50: '#E7FBF3',
          100: '#C6F4E3',
          200: '#9CE9CD',
          300: '#5FDCB0',
          400: '#1FD69B',
          500: '#0BB884',
          600: '#059669',
          700: '#047857',
          ink: '#043D2D',
        },
        // Azul informacional
        info: {
          50: '#E8F2FE',
          100: '#CFE4FD',
          500: '#2E8FE6',
          600: '#1D6FD0',
          700: '#1857A6',
        },
        // Âmbar atenção
        warn: {
          50: '#FEF4E2',
          100: '#FCE7BF',
          500: '#EA9A0B',
          600: '#C97C05',
          700: '#8A5602',
        },
        // Vermelho falha / risco
        danger: {
          50: '#FDECEC',
          100: '#FBD5D5',
          500: '#E5484D',
          600: '#CE2C31',
          700: '#A31419',
        },
        // Índigo (NF emitida) / laranja (aguardando pgto)
        indigo: { 500: '#6366F1', 600: '#4F46E5' },
        orange: { 500: '#F97316', 600: '#EA6A0A' },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'Segoe UI', 'sans-serif'],
        brand: ['Outfit', 'Inter', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      borderRadius: {
        xl: '0.875rem',
        '2xl': '1.125rem',
      },
      boxShadow: {
        card: '0 1px 2px rgba(16,23,38,0.04), 0 1px 3px rgba(16,23,38,0.06)',
        raised: '0 4px 12px rgba(16,23,38,0.06), 0 2px 4px rgba(16,23,38,0.04)',
        pop: '0 12px 40px rgba(16,23,38,0.14), 0 4px 12px rgba(16,23,38,0.08)',
        ring: '0 0 0 4px rgba(11,184,132,0.12)',
      },
      keyframes: {
        'fade-in': { from: { opacity: '0' }, to: { opacity: '1' } },
        'slide-up': {
          from: { opacity: '0', transform: 'translateY(8px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        'slide-in-right': {
          from: { transform: 'translateX(100%)' },
          to: { transform: 'translateX(0)' },
        },
        shimmer: {
          '100%': { transform: 'translateX(100%)' },
        },
      },
      animation: {
        'fade-in': 'fade-in 0.2s ease-out',
        'slide-up': 'slide-up 0.28s cubic-bezier(0.22,1,0.36,1)',
        'slide-in-right': 'slide-in-right 0.32s cubic-bezier(0.22,1,0.36,1)',
      },
    },
  },
  plugins: [],
};
