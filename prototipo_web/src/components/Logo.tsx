import { cn } from '@/lib/cn';

/** Marca Medvie — mark geométrico (pulso → sincronia) + wordmark Outfit.
 *  Sem clichês clínicos (cruz/estetoscópio). O mark sugere batimento que vira
 *  linha estável: precisão + tranquilidade. */
export function LogoMark({ size = 34 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" fill="none" aria-hidden>
      <rect width="40" height="40" rx="11" fill="url(#mv-g)" />
      <path
        d="M8 22.5h5.2l2.4-6.8a1 1 0 0 1 1.9.05l3.4 11.2 2.5-8.1a1 1 0 0 1 1.9-.02l1.6 3.9H32"
        stroke="#fff"
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <defs>
        <linearGradient id="mv-g" x1="4" y1="2" x2="36" y2="40" gradientUnits="userSpaceOnUse">
          <stop stopColor="#12CE97" />
          <stop offset="1" stopColor="#059669" />
        </linearGradient>
      </defs>
    </svg>
  );
}

export function Logo({
  className,
  onDark = false,
  markSize = 34,
}: {
  className?: string;
  onDark?: boolean;
  markSize?: number;
}) {
  return (
    <div className={cn('flex items-center gap-2.5', className)}>
      <LogoMark size={markSize} />
      <span
        className={cn(
          'font-brand text-[20px] font-bold tracking-tight',
          onDark ? 'text-white' : 'text-ink',
        )}
      >
        Medvie
      </span>
    </div>
  );
}
