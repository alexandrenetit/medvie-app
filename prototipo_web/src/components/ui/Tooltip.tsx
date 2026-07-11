import type { ReactNode } from 'react';

/** Tooltip leve baseado em CSS (group-hover). Sem dependência externa. */
export function Tooltip({
  label,
  children,
  side = 'top',
}: {
  label: string;
  children: ReactNode;
  side?: 'top' | 'bottom';
}) {
  const pos =
    side === 'top'
      ? 'bottom-full mb-2 left-1/2 -translate-x-1/2'
      : 'top-full mt-2 left-1/2 -translate-x-1/2';
  return (
    <span className="group relative inline-flex">
      {children}
      <span
        role="tooltip"
        className={`pointer-events-none absolute ${pos} z-50 whitespace-nowrap rounded-lg bg-ink px-2.5 py-1.5 text-[12px] font-medium text-white opacity-0 shadow-pop transition-opacity duration-150 group-hover:opacity-100`}
      >
        {label}
      </span>
    </span>
  );
}
