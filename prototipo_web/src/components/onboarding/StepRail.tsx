// src/components/onboarding/StepRail.tsx
// Rail do onboarding (desktop) — stepper vertical persistente sobre o sidebar
// dark. Orientação espacial: passo atual destacado, concluídos com check, linha
// conectora com progresso. Some em telas < lg (mobile usa a barra no topo do
// painel). Reaproveita a assinatura visual do Login.

import { Check } from 'lucide-react';
import { Logo, LogoMark } from '@/components/Logo';
import { cn } from '@/lib/cn';

export interface RailPasso {
  id: string;
  titulo: string;
  railCopy: string;
}

interface StepRailProps {
  passos: RailPasso[];
  /** Índice do passo atual. Se >= passos.length, tudo concluído (tela de sucesso). */
  indiceAtual: number;
}

export function StepRail({ passos, indiceAtual }: StepRailProps) {
  const total = passos.length;
  const tudoConcluido = indiceAtual >= total;
  const passoNum = Math.min(indiceAtual + 1, total);

  return (
    <aside
      className="relative hidden overflow-hidden bg-sidebar lg:sticky lg:top-0 lg:flex lg:h-screen lg:flex-col"
      aria-label="Progresso do onboarding"
    >
      {/* Glow decorativo — mesmo tratamento do Login. */}
      <div
        className="absolute inset-0 opacity-[0.14]"
        style={{
          backgroundImage:
            'radial-gradient(circle at 20% 12%, #12CE97 0, transparent 42%), radial-gradient(circle at 88% 82%, #2E8FE6 0, transparent 46%)',
        }}
      />

      <div className="relative flex h-full flex-col p-10 xl:p-12">
        <Logo onDark markSize={30} />
        <p className="mt-2 text-[12.5px] font-medium text-sidebar-muted" aria-live="polite">
          {tudoConcluido ? 'Configuração concluída' : `Passo ${passoNum} de ${total}`}
        </p>

        <ol className="mt-12 flex flex-col" aria-label="Etapas">
          {passos.map((s, i) => {
            const concluido = tudoConcluido || i < indiceAtual;
            const ativo = !tudoConcluido && i === indiceAtual;
            const ultimo = i === total - 1;

            return (
              <li
                key={s.id}
                className="relative flex gap-4 pb-7 last:pb-0"
                aria-current={ativo ? 'step' : undefined}
              >
                {/* Conector até o próximo passo */}
                {!ultimo && (
                  <span
                    aria-hidden
                    className={cn(
                      'absolute left-[13px] top-8 bottom-1 w-0.5 rounded-full transition-colors duration-300',
                      concluido ? 'bg-brand-500' : 'bg-white/10',
                    )}
                  />
                )}

                {/* Marcador */}
                <span
                  aria-hidden
                  className={cn(
                    'relative z-10 grid h-7 w-7 shrink-0 place-items-center rounded-full text-[12px] font-semibold transition-colors duration-300',
                    concluido
                      ? 'bg-brand-500 text-white'
                      : ativo
                        ? 'bg-white text-sidebar ring-4 ring-white/10'
                        : 'bg-white/10 text-sidebar-muted',
                  )}
                >
                  {concluido ? <Check size={15} strokeWidth={3} /> : i + 1}
                </span>

                {/* Rótulo + reforço no passo ativo */}
                <div className="pt-0.5">
                  <p
                    className={cn(
                      'text-[14.5px] font-semibold leading-tight transition-colors',
                      ativo ? 'text-white' : concluido ? 'text-sidebar-text' : 'text-sidebar-muted',
                    )}
                  >
                    {s.titulo}
                  </p>
                  {ativo && (
                    <p className="mt-1 text-[12.5px] leading-snug text-sidebar-text">{s.railCopy}</p>
                  )}
                </div>
              </li>
            );
          })}
        </ol>

        <div className="mt-auto flex items-center gap-2.5 text-[12.5px] text-sidebar-text">
          <LogoMark size={22} />
          Configuração única. Leva poucos minutos.
        </div>
      </div>
    </aside>
  );
}
