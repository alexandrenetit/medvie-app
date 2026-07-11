import { useRef, useState, type ReactNode } from 'react';
import { motion } from 'framer-motion';
import { cn } from '@/lib/cn';
import { useClickOutside } from '@/lib/useClickOutside';

interface PopoverProps {
  trigger: (open: boolean) => ReactNode;
  children: (close: () => void) => ReactNode;
  align?: 'start' | 'end';
  width?: number | string;
  className?: string;
}

export function Popover({ trigger, children, align = 'end', width = 280, className }: PopoverProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useClickOutside(ref, () => setOpen(false), open);

  return (
    <div className="relative" ref={ref}>
      <button type="button" onClick={() => setOpen((v) => !v)} className="block">
        {trigger(open)}
      </button>
      {open && (
          <motion.div
            initial={{ opacity: 0, y: -6, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ duration: 0.15, ease: [0.22, 1, 0.36, 1] }}
            style={{ width }}
            className={cn(
              'absolute z-40 mt-2 overflow-hidden rounded-xl border border-line bg-card shadow-pop',
              align === 'end' ? 'right-0' : 'left-0',
              className,
            )}
          >
            {children(() => setOpen(false))}
          </motion.div>
        )}
    </div>
  );
}
