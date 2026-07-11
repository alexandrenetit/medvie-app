import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  Search,
  LayoutDashboard,
  CalendarDays,
  Stethoscope,
  FileText,
  BarChart3,
  Calculator,
  Building2,
  Plus,
  CornerDownLeft,
  User,
  type LucideIcon,
} from 'lucide-react';
import { cn } from '@/lib/cn';
import { useAppState } from '@/context/AppState';
import { tomadores } from '@/data/mock';

interface Cmd {
  id: string;
  label: string;
  hint?: string;
  icon: LucideIcon;
  grupo: string;
  run: () => void;
}

export function CommandPalette() {
  const { commandOpen, setCommandOpen, setNovoAtendimentoOpen } = useAppState();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  // Atalho global Ctrl/Cmd + K
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setCommandOpen(true);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [setCommandOpen]);

  useEffect(() => {
    if (commandOpen) {
      setQuery('');
      setActive(0);
      setTimeout(() => inputRef.current?.focus(), 40);
    }
  }, [commandOpen]);

  // Fechar no Escape via listener de documento (robusto para conteúdo em portal,
  // que não propaga onKeyDown do React até o container raiz).
  useEffect(() => {
    if (!commandOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setCommandOpen(false);
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [commandOpen, setCommandOpen]);

  const close = () => setCommandOpen(false);
  const go = (to: string) => {
    navigate(to);
    close();
  };

  const comandos: Cmd[] = useMemo(() => {
    const nav: Cmd[] = [
      { id: 'n1', label: 'Visão geral', icon: LayoutDashboard, grupo: 'Ir para', run: () => go('/') },
      { id: 'n2', label: 'Agenda', icon: CalendarDays, grupo: 'Ir para', run: () => go('/agenda') },
      { id: 'n3', label: 'Atendimentos', icon: Stethoscope, grupo: 'Ir para', run: () => go('/atendimentos') },
      { id: 'n4', label: 'Notas fiscais', icon: FileText, grupo: 'Ir para', run: () => go('/notas') },
      { id: 'n5', label: 'Relatórios', icon: BarChart3, grupo: 'Ir para', run: () => go('/relatorios') },
      { id: 'n6', label: 'Simulador de honorários', icon: Calculator, grupo: 'Ir para', run: () => go('/simulador') },
      { id: 'n7', label: 'Perfil e empresa', icon: Building2, grupo: 'Ir para', run: () => go('/perfil') },
    ];
    const acoes: Cmd[] = [
      {
        id: 'a1',
        label: 'Novo atendimento',
        hint: 'Registrar PF ou empresa',
        icon: Plus,
        grupo: 'Ações',
        run: () => {
          close();
          setNovoAtendimentoOpen(true);
        },
      },
    ];
    const pacientes: Cmd[] = tomadores.map((t) => ({
      id: `t-${t.id}`,
      label: t.nome,
      hint: t.tipo === 'cpf' ? 'Paciente' : 'Empresa / Convênio',
      icon: t.tipo === 'cpf' ? User : Building2,
      grupo: 'Tomadores',
      run: () => go('/atendimentos'),
    }));
    return [...acoes, ...nav, ...pacientes];
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const filtrados = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return comandos;
    return comandos.filter((c) => c.label.toLowerCase().includes(q));
  }, [query, comandos]);

  const grupos = useMemo(() => {
    const map = new Map<string, Cmd[]>();
    filtrados.forEach((c) => {
      if (!map.has(c.grupo)) map.set(c.grupo, []);
      map.get(c.grupo)!.push(c);
    });
    return [...map.entries()];
  }, [filtrados]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      close();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((a) => Math.min(a + 1, filtrados.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((a) => Math.max(a - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      filtrados[active]?.run();
    }
  };

  let runningIndex = -1;

  if (!commandOpen) return null;

  return createPortal(
    <>
      {(
        <motion.div
          key="cmdk"
          className="fixed inset-0 z-[70] flex items-start justify-center p-4 pt-[12vh]"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.15 }}
        >
          <div
            className="fixed inset-0 bg-ink/40 backdrop-blur-[2px]"
            onClick={close}
          />
          <motion.div
            initial={{ opacity: 0, y: -10, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.98 }}
            transition={{ duration: 0.18, ease: [0.22, 1, 0.36, 1] }}
            className="relative z-10 w-full max-w-xl overflow-hidden rounded-2xl border border-line bg-card shadow-pop"
          >
            <div className="flex items-center gap-3 border-b border-line px-4">
              <Search size={18} className="text-ink-muted" />
              <input
                ref={inputRef}
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  setActive(0);
                }}
                onKeyDown={onKeyDown}
                placeholder="Buscar comando, tela ou tomador…"
                className="h-14 flex-1 bg-transparent text-[15px] text-ink placeholder:text-ink-faint focus:outline-none"
              />
              <kbd className="rounded-md border border-line bg-canvas px-1.5 py-0.5 text-[11px] font-semibold text-ink-muted">
                Esc
              </kbd>
            </div>
            <div className="max-h-[52vh] overflow-y-auto p-2">
              {filtrados.length === 0 && (
                <p className="px-3 py-8 text-center text-sm text-ink-muted">
                  Nenhum resultado para “{query}”.
                </p>
              )}
              {grupos.map(([grupo, itens]) => (
                <div key={grupo} className="mb-1">
                  <p className="px-3 py-1.5 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
                    {grupo}
                  </p>
                  {itens.map((c) => {
                    runningIndex++;
                    const idx = runningIndex;
                    const isActive = idx === active;
                    return (
                      <button
                        key={c.id}
                        onMouseEnter={() => setActive(idx)}
                        onClick={c.run}
                        className={cn(
                          'flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left transition-colors',
                          isActive ? 'bg-brand-50' : 'hover:bg-line2',
                        )}
                      >
                        <c.icon size={17} className={isActive ? 'text-brand-600' : 'text-ink-muted'} />
                        <span className="flex-1 text-[14px] font-medium text-ink">{c.label}</span>
                        {c.hint && <span className="text-[12px] text-ink-muted">{c.hint}</span>}
                        {isActive && <CornerDownLeft size={15} className="text-brand-500" />}
                      </button>
                    );
                  })}
                </div>
              ))}
            </div>
          </motion.div>
        </motion.div>
      )}
    </>,
    document.body,
  );
}
