// src/components/onboarding/steps/StepEspecialidade.tsx
// Passo 1c — Especialidade. Busca + lista filtrável selecionável. A lista vem de
// `especialidades` (data/domain.ts). Só avança com uma especialidade escolhida.

import { useMemo, useState } from 'react';
import { Search, Check, X } from 'lucide-react';
import { StepHeader, StepFooter, type StepProps } from '@/components/onboarding/StepShell';
import { especialidades } from '@/data/domain';
import { cn } from '@/lib/cn';

export function StepEspecialidade({ data, setData, avancar, voltar, podeVoltar }: StepProps) {
  const [busca, setBusca] = useState('');
  const selecionada = data.especialidade;

  const filtradas = useMemo(() => {
    const q = busca.trim().toLowerCase();
    return q ? especialidades.filter((e) => e.toLowerCase().includes(q)) : especialidades;
  }, [busca]);

  function selecionar(esp: string) {
    setData((prev) => ({ ...prev, especialidade: esp }));
  }

  return (
    <div
      onKeyDownCapture={(e) => {
        if (e.key !== 'Enter') return;
        const alvo = e.target as HTMLElement;
        if (selecionada && (alvo instanceof HTMLInputElement || alvo.getAttribute('aria-pressed') === 'true')) {
          e.preventDefault();
          avancar();
        }
      }}
    >
      <StepHeader titulo="Especialidade" subtitulo="Selecione sua área de atuação principal." />

      <div className="relative">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
        <input
          autoFocus
          value={busca}
          onChange={(e) => setBusca(e.target.value)}
          placeholder="Buscar especialidade…"
          className="field pl-10 pr-10"
        />
        {busca && (
          <button
            type="button"
            onClick={() => setBusca('')}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-faint hover:text-ink-soft"
            aria-label="Limpar busca"
          >
            <X size={16} />
          </button>
        )}
      </div>

      <div className="mt-3 max-h-[320px] overflow-y-auto rounded-2xl border border-line">
        {filtradas.length === 0 ? (
          <p className="px-4 py-8 text-center text-[13.5px] text-ink-muted">
            Nenhuma especialidade encontrada.
          </p>
        ) : (
          <ul className="divide-y divide-line2">
            {filtradas.map((esp) => {
              const ativo = selecionada === esp;
              return (
                <li key={esp}>
                  <button
                    type="button"
                    aria-pressed={ativo}
                    onClick={() => selecionar(esp)}
                    className={cn(
                      'flex w-full items-center justify-between gap-3 px-4 py-3 text-left text-[14px] transition-colors',
                      ativo ? 'bg-brand-50/60 font-semibold text-ink' : 'text-ink-soft hover:bg-line2/50',
                    )}
                  >
                    {esp}
                    {ativo && <Check size={17} className="shrink-0 text-brand-600" />}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <StepFooter
        podeVoltar={podeVoltar}
        onVoltar={voltar}
        onAvancar={avancar}
        avancarDisabled={selecionada === null}
      />
    </div>
  );
}
