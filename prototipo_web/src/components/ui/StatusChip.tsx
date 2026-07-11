import { cn } from '@/lib/cn';
import { toneClasses, type Tone } from '@/data/domain';

interface StatusChipProps {
  label: string;
  tone: Tone;
  className?: string;
  dot?: boolean;
}

export function StatusChip({ label, tone, className, dot = true }: StatusChipProps) {
  const c = toneClasses[tone];
  return (
    <span className={cn('chip', c.chip, className)}>
      {dot && <span className={cn('h-1.5 w-1.5 rounded-full', c.dot)} aria-hidden />}
      {label}
    </span>
  );
}
