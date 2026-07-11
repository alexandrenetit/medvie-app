import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  CalendarDays,
  Stethoscope,
  FileText,
  BarChart3,
  Calculator,
  Building2,
  Settings,
  ShieldCheck,
  ShieldAlert,
  PanelLeftClose,
  PanelLeftOpen,
} from 'lucide-react';
import { cn } from '@/lib/cn';
import { LogoMark } from '@/components/Logo';
import { useAppState } from '@/context/AppState';
import { medico } from '@/data/mock';
import { Tooltip } from '@/components/ui/Tooltip';

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

export function Sidebar() {
  const { sidebarCollapsed, toggleSidebar, cnpjAtivoId } = useAppState();
  const cnpj = medico.cnpjs.find((c) => c.id === cnpjAtivoId) ?? medico.cnpjs[0];
  const certOk = cnpj.certificado.status === 'ativo' && cnpj.certificado.diasParaVencer > 30;
  const collapsed = sidebarCollapsed;

  return (
    <aside
      className={cn(
        'sticky top-0 hidden h-screen shrink-0 flex-col bg-sidebar text-sidebar-text transition-[width] duration-300 lg:flex',
        collapsed ? 'w-[76px]' : 'w-[248px]',
      )}
    >
      {/* Brand */}
      <div className={cn('flex h-16 items-center px-5', collapsed && 'justify-center px-0')}>
        <div className="flex items-center gap-2.5">
          <LogoMark size={32} />
          {!collapsed && (
            <span className="font-brand text-[19px] font-bold tracking-tight text-white">
              Medvie
            </span>
          )}
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-0.5 px-3 py-3">
        {nav.map(({ to, label, icon: Icon, end }) => {
          const item = (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-[14px] font-medium transition-colors',
                  collapsed && 'justify-center px-0',
                  isActive
                    ? 'bg-brand-500/14 text-white'
                    : 'text-sidebar-text hover:bg-white/5 hover:text-white',
                )
              }
            >
              {({ isActive }) => (
                <>
                  <Icon
                    size={19}
                    strokeWidth={2}
                    className={cn(isActive ? 'text-brand-400' : 'text-sidebar-muted group-hover:text-sidebar-text')}
                  />
                  {!collapsed && <span className="truncate">{label}</span>}
                </>
              )}
            </NavLink>
          );
          return collapsed ? (
            <Tooltip key={to} label={label} side="bottom">
              {item}
            </Tooltip>
          ) : (
            item
          );
        })}
      </nav>

      {/* Certificado + collapse */}
      <div className="border-t border-sidebar-line px-3 py-3">
        <NavLink
          to="/perfil?secao=certificado"
          className={cn(
            'mb-2 flex items-center gap-2.5 rounded-xl px-3 py-2.5 transition-colors hover:bg-white/5',
            collapsed && 'justify-center px-0',
          )}
        >
          {certOk ? (
            <ShieldCheck size={19} className="text-brand-400" />
          ) : (
            <ShieldAlert size={19} className="text-warn-500" />
          )}
          {!collapsed && (
            <div className="min-w-0">
              <p className="text-[12px] font-semibold text-white leading-tight">
                Certificado {certOk ? 'ativo' : 'atenção'}
              </p>
              <p className="truncate text-[11px] text-sidebar-muted">
                {certOk
                  ? `válido · ${cnpj.certificado.diasParaVencer} dias`
                  : `vence em ${cnpj.certificado.diasParaVencer} dias`}
              </p>
            </div>
          )}
        </NavLink>

        <button
          onClick={toggleSidebar}
          className={cn(
            'flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-[13px] font-medium text-sidebar-muted transition-colors hover:bg-white/5 hover:text-white',
            collapsed && 'justify-center px-0',
          )}
        >
          {collapsed ? <PanelLeftOpen size={18} /> : <PanelLeftClose size={18} />}
          {!collapsed && <span>Recolher</span>}
        </button>
      </div>
    </aside>
  );
}
