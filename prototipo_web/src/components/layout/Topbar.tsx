import { useNavigate } from 'react-router-dom';
import {
  Search,
  Bell,
  Plus,
  ChevronDown,
  Building2,
  CalendarRange,
  Check,
  ShieldCheck,
  ShieldAlert,
  Menu,
  LogOut,
  User,
  Settings,
} from 'lucide-react';
import { cn } from '@/lib/cn';
import { Button } from '@/components/ui/Button';
import { Popover } from '@/components/ui/Popover';
import { useAppState } from '@/context/AppState';
import { medico, notificacoes } from '@/data/mock';
import { nomeMes } from '@/lib/format';
import { statusCertificadoMeta } from '@/data/domain';

function competenciaLabel(c: string): string {
  const [ano, mes] = c.split('-').map(Number);
  const nome = nomeMes(mes - 1);
  return `${nome.charAt(0).toUpperCase()}${nome.slice(1)} ${ano}`;
}

const competencias = ['2026-07', '2026-06', '2026-05', '2026-04', '2026-03', '2026-02', '2026-01'];

const tipoIcon = {
  sucesso: 'bg-brand-500',
  erro: 'bg-danger-500',
  atencao: 'bg-warn-500',
  info: 'bg-info-500',
} as const;

export function Topbar({ onOpenMobileNav }: { onOpenMobileNav: () => void }) {
  const navigate = useNavigate();
  const {
    cnpjAtivoId,
    setCnpjAtivoId,
    competencia,
    setCompetencia,
    setCommandOpen,
    setNovoAtendimentoOpen,
  } = useAppState();

  const cnpj = medico.cnpjs.find((c) => c.id === cnpjAtivoId) ?? medico.cnpjs[0];
  const naoLidas = notificacoes.filter((n) => !n.lida).length;
  const certMeta = statusCertificadoMeta[cnpj.certificado.status];
  const certAlerta = cnpj.certificado.diasParaVencer <= 30;

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-line bg-card/80 px-4 backdrop-blur-md md:px-6">
      <button
        onClick={onOpenMobileNav}
        className="grid h-10 w-10 place-items-center rounded-xl text-ink-muted hover:bg-line2 lg:hidden"
        aria-label="Abrir menu"
      >
        <Menu size={20} />
      </button>

      {/* Command / busca global */}
      <button
        onClick={() => setCommandOpen(true)}
        className="group flex h-10 flex-1 items-center gap-2.5 rounded-xl border border-line bg-canvas px-3.5 text-left text-ink-muted transition-colors hover:border-ink-faint md:max-w-md"
      >
        <Search size={17} className="shrink-0" />
        <span className="flex-1 truncate text-[14px]">Buscar paciente, nota, atendimento…</span>
        <kbd className="hidden items-center gap-0.5 rounded-md border border-line bg-card px-1.5 py-0.5 text-[11px] font-semibold text-ink-muted sm:flex">
          Ctrl K
        </kbd>
      </button>

      <div className="flex items-center gap-2 md:gap-2.5">
        {/* Seletor de CNPJ */}
        <Popover
          width={320}
          trigger={(open) => (
            <span
              className={cn(
                'hidden h-10 items-center gap-2 rounded-xl border px-3 text-left transition-colors md:flex',
                open ? 'border-brand-500 shadow-ring' : 'border-line hover:border-ink-faint',
              )}
            >
              <Building2 size={16} className="text-ink-muted" />
              <span className="max-w-[150px] truncate text-[13px] font-semibold text-ink">
                {cnpj.nomeFantasia}
              </span>
              <ChevronDown size={15} className="text-ink-muted" />
            </span>
          )}
        >
          {(close) => (
            <div className="p-1.5">
              <p className="px-3 py-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
                Empresa ativa
              </p>
              {medico.cnpjs.map((c) => {
                const ativo = c.id === cnpjAtivoId;
                return (
                  <button
                    key={c.id}
                    onClick={() => {
                      setCnpjAtivoId(c.id);
                      close();
                    }}
                    className={cn(
                      'flex w-full items-start gap-3 rounded-lg px-3 py-2.5 text-left transition-colors hover:bg-line2',
                      ativo && 'bg-brand-50/60',
                    )}
                  >
                    <div className="mt-0.5">
                      {c.certificado.diasParaVencer <= 30 ? (
                        <ShieldAlert size={17} className="text-warn-500" />
                      ) : (
                        <ShieldCheck size={17} className="text-brand-500" />
                      )}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-[13.5px] font-semibold text-ink">
                        {c.razaoSocial}
                      </p>
                      <p className="num truncate text-[12px] text-ink-muted">{c.cnpj}</p>
                    </div>
                    {ativo && <Check size={16} className="mt-0.5 shrink-0 text-brand-600" />}
                  </button>
                );
              })}
            </div>
          )}
        </Popover>

        {/* Seletor de competência */}
        <Popover
          width={220}
          trigger={(open) => (
            <span
              className={cn(
                'flex h-10 items-center gap-2 rounded-xl border px-3 transition-colors',
                open ? 'border-brand-500 shadow-ring' : 'border-line hover:border-ink-faint',
              )}
            >
              <CalendarRange size={16} className="text-ink-muted" />
              <span className="text-[13px] font-semibold text-ink">
                {competenciaLabel(competencia)}
              </span>
              <ChevronDown size={15} className="text-ink-muted" />
            </span>
          )}
        >
          {(close) => (
            <div className="max-h-72 overflow-y-auto p-1.5">
              {competencias.map((c) => (
                <button
                  key={c}
                  onClick={() => {
                    setCompetencia(c);
                    close();
                  }}
                  className={cn(
                    'flex w-full items-center justify-between rounded-lg px-3 py-2 text-left text-[13.5px] transition-colors hover:bg-line2',
                    c === competencia ? 'font-semibold text-ink' : 'text-ink-soft',
                  )}
                >
                  {competenciaLabel(c)}
                  {c === competencia && <Check size={15} className="text-brand-600" />}
                </button>
              ))}
            </div>
          )}
        </Popover>

        {/* Notificações */}
        <Popover
          width={380}
          trigger={() => (
            <span className="relative grid h-10 w-10 place-items-center rounded-xl border border-line text-ink-soft transition-colors hover:border-ink-faint hover:text-ink">
              <Bell size={18} />
              {naoLidas > 0 && (
                <span className="absolute right-1.5 top-1.5 grid h-4 min-w-4 place-items-center rounded-full bg-danger-500 px-1 text-[10px] font-bold text-white">
                  {naoLidas}
                </span>
              )}
            </span>
          )}
        >
          {() => (
            <div>
              <div className="flex items-center justify-between border-b border-line px-4 py-3">
                <p className="font-brand text-[15px] font-semibold text-ink">Notificações</p>
                <span className="chip bg-line2 text-ink-muted">{naoLidas} novas</span>
              </div>
              <div className="max-h-[380px] overflow-y-auto">
                {notificacoes.map((n) => (
                  <div
                    key={n.id}
                    className={cn(
                      'flex gap-3 border-b border-line2 px-4 py-3 last:border-0',
                      !n.lida && 'bg-brand-50/30',
                    )}
                  >
                    <span className={cn('mt-1.5 h-2 w-2 shrink-0 rounded-full', tipoIcon[n.tipo])} />
                    <div className="min-w-0">
                      <p className="text-[13.5px] font-semibold text-ink">{n.titulo}</p>
                      <p className="mt-0.5 text-[12.5px] leading-snug text-ink-muted">
                        {n.descricao}
                      </p>
                      <p className="mt-1 text-[11px] text-ink-faint">{n.quando}</p>
                    </div>
                  </div>
                ))}
              </div>
              <button
                onClick={() => navigate('/notas')}
                className="block w-full border-t border-line px-4 py-2.5 text-center text-[13px] font-semibold text-brand-600 hover:bg-brand-50/50"
              >
                Ver todas as pendências
              </button>
            </div>
          )}
        </Popover>

        {/* Novo atendimento */}
        <Button size="sm" className="h-10 shrink-0" onClick={() => setNovoAtendimentoOpen(true)}>
          <Plus size={17} />
          <span className="hidden sm:inline">Novo atendimento</span>
        </Button>

        {/* Perfil */}
        <Popover
          width={260}
          trigger={() => (
            <span className="flex items-center gap-2 rounded-xl p-0.5 pr-1 transition-colors hover:bg-line2">
              <span className="grid h-9 w-9 place-items-center rounded-full bg-gradient-to-br from-brand-400 to-brand-600 text-[13px] font-bold text-white">
                {medico.avatarIniciais}
              </span>
            </span>
          )}
        >
          {(close) => (
            <div className="p-1.5">
              <div className="flex items-center gap-3 px-3 py-2.5">
                <span className="grid h-10 w-10 place-items-center rounded-full bg-gradient-to-br from-brand-400 to-brand-600 text-[13px] font-bold text-white">
                  {medico.avatarIniciais}
                </span>
                <div className="min-w-0">
                  <p className="truncate text-[14px] font-semibold text-ink">{medico.nome}</p>
                  <p className="truncate text-[12px] text-ink-muted">
                    CRM {medico.crm}/{medico.ufCrm} · {medico.especialidade}
                  </p>
                </div>
              </div>
              <div className="my-1.5 border-t border-line2" />
              <button
                onClick={() => {
                  navigate('/perfil');
                  close();
                }}
                className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-[13.5px] text-ink-soft hover:bg-line2"
              >
                <User size={16} /> Perfil e empresa
              </button>
              <button
                onClick={() => {
                  navigate('/config');
                  close();
                }}
                className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-[13.5px] text-ink-soft hover:bg-line2"
              >
                <Settings size={16} /> Configurações
              </button>
              <div className="my-1.5 border-t border-line2" />
              <div className="flex items-center gap-2.5 px-3 py-1.5 text-[12px]">
                {certAlerta ? (
                  <ShieldAlert size={15} className="text-warn-500" />
                ) : (
                  <ShieldCheck size={15} className="text-brand-500" />
                )}
                <span className="text-ink-muted">
                  Certificado <span className="font-medium text-ink-soft">{certMeta.label}</span>
                </span>
              </div>
              <div className="my-1.5 border-t border-line2" />
              <button
                onClick={() => {
                  navigate('/login');
                  close();
                }}
                className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-[13.5px] text-danger-600 hover:bg-danger-50"
              >
                <LogOut size={16} /> Sair
              </button>
            </div>
          )}
        </Popover>
      </div>
    </header>
  );
}
