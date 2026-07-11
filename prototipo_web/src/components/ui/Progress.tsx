import { cn } from '@/lib/cn';

export function ProgressBar({
  value,
  max = 100,
  className,
  barClassName,
}: {
  value: number;
  max?: number;
  className?: string;
  barClassName?: string;
}) {
  const pct = Math.max(0, Math.min(100, (value / max) * 100));
  return (
    <div className={cn('h-2 w-full overflow-hidden rounded-full bg-line2', className)}>
      <div
        className={cn('h-full rounded-full bg-brand-500 transition-all duration-500', barClassName)}
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

export function Delta({ fraction, className }: { fraction: number; className?: string }) {
  const up = fraction >= 0;
  return (
    <span
      className={cn(
        'inline-flex items-center gap-0.5 rounded-full px-1.5 py-0.5 text-[12px] font-semibold tabular-nums',
        up ? 'bg-brand-50 text-brand-700' : 'bg-danger-50 text-danger-700',
        className,
      )}
    >
      {up ? '▲' : '▼'} {Math.abs(fraction * 100).toFixed(1)}%
    </span>
  );
}
