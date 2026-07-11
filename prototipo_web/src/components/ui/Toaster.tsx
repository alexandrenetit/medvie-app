import { createPortal } from 'react-dom';
import { motion } from 'framer-motion';
import { CheckCircle2, AlertTriangle, XCircle, Info, X } from 'lucide-react';
import { useAppState, type ToastTipo } from '@/context/AppState';

const iconByTipo = {
  sucesso: CheckCircle2,
  erro: XCircle,
  atencao: AlertTriangle,
  info: Info,
};

const colorByTipo: Record<ToastTipo, string> = {
  sucesso: 'text-brand-600',
  erro: 'text-danger-600',
  atencao: 'text-warn-600',
  info: 'text-info-600',
};

export function Toaster() {
  const { toasts, dismissToast } = useAppState();

  return createPortal(
    <div className="pointer-events-none fixed bottom-5 right-5 z-[60] flex w-full max-w-sm flex-col gap-2.5">
      {toasts.map((t) => {
          const Icon = iconByTipo[t.tipo];
          return (
            <motion.div
              key={t.id}
              layout
              initial={{ opacity: 0, y: 16, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              transition={{ duration: 0.24, ease: [0.22, 1, 0.36, 1] }}
              className="pointer-events-auto flex items-start gap-3 rounded-xl border border-line bg-card px-4 py-3 shadow-pop"
            >
              <Icon size={20} className={`mt-0.5 shrink-0 ${colorByTipo[t.tipo]}`} />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-ink">{t.titulo}</p>
                {t.descricao && <p className="mt-0.5 text-[13px] text-ink-muted">{t.descricao}</p>}
              </div>
              <button
                onClick={() => dismissToast(t.id)}
                aria-label="Fechar aviso"
                className="grid h-6 w-6 shrink-0 place-items-center rounded-md text-ink-faint hover:bg-line2 hover:text-ink"
              >
                <X size={14} />
              </button>
            </motion.div>
          );
        })}
    </div>,
    document.body,
  );
}
