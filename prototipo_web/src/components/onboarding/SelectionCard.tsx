// src/components/onboarding/SelectionCard.tsx
// Card de seleção acessível (radio) — reusável em Atuação (perfil) e Assinatura
// (método). Navegação por teclado nativa (Tab + Enter/Espaço). Selecionado =
// borda + fundo de marca. Ícone lucide à esquerda, indicador radio à direita.

import type { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/cn';

interface SelectionCardProps {
  icon: LucideIcon;
  titulo: string;
  subtitulo: string;
  selecionado: boolean;
  onSelect: () => void;
}

export function SelectionCard({ icon: Icon, titulo, subtitulo, selecionado, onSelect }: SelectionCardProps) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={selecionado}
      onClick={onSelect}
      className={cn(
        'group flex w-full items-center gap-3.5 rounded-2xl border p-4 text-left transition-all',
        'focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand-500/15',
        selecionado
          ? 'border-brand-500 bg-brand-50/60 shadow-ring'
          : 'border-line bg-card hover:border-ink-faint',
      )}
    >
      <span
        className={cn(
          'grid h-11 w-11 shrink-0 place-items-center rounded-xl transition-colors',
          selecionado ? 'bg-brand-100 text-brand-600' : 'bg-canvas text-ink-muted group-hover:text-ink-soft',
        )}
      >
        <Icon size={21} />
      </span>

      <span className="min-w-0 flex-1">
        <span className={cn('block text-[14.5px] font-semibold', selecionado ? 'text-ink' : 'text-ink-soft')}>
          {titulo}
        </span>
        <span className="mt-0.5 block text-[12.5px] leading-snug text-ink-muted">{subtitulo}</span>
      </span>

      <span
        className={cn(
          'grid h-5 w-5 shrink-0 place-items-center rounded-full border-2 transition-colors',
          selecionado ? 'border-brand-500' : 'border-ink-faint/60',
        )}
      >
        {selecionado && <span className="h-2.5 w-2.5 rounded-full bg-brand-500" />}
      </span>
    </button>
  );
}
