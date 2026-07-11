import { useEffect, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import { cn } from '@/lib/cn';

interface ModalProps {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  title?: ReactNode;
  subtitle?: ReactNode;
  size?: 'md' | 'lg' | 'xl';
  footer?: ReactNode;
}

const sizeClass = {
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
};

export function Modal({ open, onClose, children, title, subtitle, size = 'lg', footer }: ModalProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose]);

  if (!open) return null;

  return createPortal(
    <>
      {(
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-4 sm:p-6 md:items-center">
          <motion.div
            className="fixed inset-0 bg-ink/40 backdrop-blur-[2px]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            onClick={onClose}
          />
          <motion.div
            role="dialog"
            aria-modal="true"
            className={cn(
              'relative z-10 w-full rounded-2xl bg-card shadow-pop border border-line my-auto',
              sizeClass[size],
            )}
            initial={{ opacity: 0, y: 12, scale: 0.985 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 8, scale: 0.99 }}
            transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
          >
            {(title || subtitle) && (
              <div className="flex items-start justify-between gap-4 border-b border-line px-6 py-4">
                <div className="min-w-0">
                  {title && (
                    <h2 className="font-brand text-lg font-semibold text-ink">{title}</h2>
                  )}
                  {subtitle && <p className="mt-0.5 text-sm text-ink-muted">{subtitle}</p>}
                </div>
                <button
                  onClick={onClose}
                  aria-label="Fechar"
                  className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-ink-muted hover:bg-line2 hover:text-ink"
                >
                  <X size={18} />
                </button>
              </div>
            )}
            <div className="px-6 py-5">{children}</div>
            {footer && (
              <div className="flex items-center justify-end gap-3 border-t border-line bg-canvas/50 px-6 py-4 rounded-b-2xl">
                {footer}
              </div>
            )}
          </motion.div>
        </div>
      )}
    </>,
    document.body,
  );
}
