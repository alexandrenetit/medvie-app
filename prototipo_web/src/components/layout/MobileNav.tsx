import { NavLink } from 'react-router-dom';
import { createPortal } from 'react-dom';
import { motion } from 'framer-motion';
import {
  LayoutDashboard,
  CalendarDays,
  Stethoscope,
  FileText,
  BarChart3,
  Calculator,
  Building2,
  Settings,
  X,
} from 'lucide-react';
import { cn } from '@/lib/cn';
import { Logo } from '@/components/Logo';

const nav = [
  { to: '/', label: 'Visão geral', icon: LayoutDashboard, end: true },
  { to: '/agenda', label: 'Agenda', icon: CalendarDays },
  { to: '/atendimentos', label: 'Atendimentos', icon: Stethoscope },
  { to: '/notas', label: 'Notas fiscais', icon: FileText },
  { to: '/relatorios', label: 'Relatórios', icon: BarChart3 },
  { to: '/simulador', label: 'Simulador', icon: Calculator },
  { to: '/perfil', label: 'Perfil e empresa', icon: Building2 },
  { to: '/config', label: 'Configurações', icon: Settings },
];

export function MobileNav({ open, onClose }: { open: boolean; onClose: () => void }) {
  if (!open) return null;

  return createPortal(
    <>
      {(
        <div className="fixed inset-0 z-50 lg:hidden">
          <motion.div
            className="absolute inset-0 bg-ink/40 backdrop-blur-[2px]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            initial={{ x: '-100%' }}
            animate={{ x: 0 }}
            exit={{ x: '-100%' }}
            transition={{ duration: 0.28, ease: [0.22, 1, 0.36, 1] }}
            className="absolute left-0 top-0 flex h-full w-[270px] flex-col bg-sidebar"
          >
            <div className="flex h-16 items-center justify-between px-4">
              <Logo onDark markSize={30} />
              <button
                onClick={onClose}
                aria-label="Fechar menu"
                className="grid h-9 w-9 place-items-center rounded-lg text-sidebar-muted hover:bg-white/5 hover:text-white"
              >
                <X size={18} />
              </button>
            </div>
            <nav className="flex-1 space-y-0.5 px-3 py-3">
              {nav.map(({ to, label, icon: Icon, end }) => (
                <NavLink
                  key={to}
                  to={to}
                  end={end}
                  onClick={onClose}
                  className={({ isActive }) =>
                    cn(
                      'flex items-center gap-3 rounded-xl px-3 py-2.5 text-[14px] font-medium transition-colors',
                      isActive
                        ? 'bg-brand-500/14 text-white'
                        : 'text-sidebar-text hover:bg-white/5 hover:text-white',
                    )
                  }
                >
                  <Icon size={19} />
                  {label}
                </NavLink>
              ))}
            </nav>
          </motion.div>
        </div>
      )}
    </>,
    document.body,
  );
}
