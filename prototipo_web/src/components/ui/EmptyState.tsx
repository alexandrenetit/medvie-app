import type { LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';

interface EmptyStateProps {
  icon: LucideIcon;
  titulo: string;
  descricao?: string;
  action?: ReactNode;
  compact?: boolean;
}

export function EmptyState({ icon: Icon, titulo, descricao, action, compact }: EmptyStateProps) {
  return (
    <div
      className={`flex flex-col items-center justify-center text-center ${
        compact ? 'py-10' : 'py-16'
      } px-6`}
    >
      <div className="grid h-12 w-12 place-items-center rounded-2xl bg-line2 text-ink-muted">
        <Icon size={22} strokeWidth={1.75} />
      </div>
      <p className="mt-4 font-brand text-[15px] font-semibold text-ink">{titulo}</p>
      {descricao && <p className="mt-1 max-w-sm text-sm text-ink-muted">{descricao}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}
