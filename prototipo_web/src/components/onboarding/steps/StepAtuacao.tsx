// src/components/onboarding/steps/StepAtuacao.tsx
// Passo 1b — Perfil de atuação. Define como o Medvie organiza notas/cálculos e
// se o passo Tomadores aparece (só Plantonista). Radiogroup de SelectionCard.

import { SelectionCard } from '@/components/onboarding/SelectionCard';
import { StepHeader, StepFooter, type StepProps } from '@/components/onboarding/StepShell';
import { perfisAtuacao } from '@/data/onboardingMock';

export function StepAtuacao({ data, setData, avancar, voltar, podeVoltar }: StepProps) {
  const selecionado = data.perfil;

  return (
    <div
      onKeyDownCapture={(e) => {
        if (e.key === 'Enter' && selecionado && (e.target as HTMLElement).getAttribute('aria-checked') === 'true') {
          e.preventDefault();
          avancar();
        }
      }}
    >
      <StepHeader
        titulo="Como você atua?"
        subtitulo="Isso define como organizamos suas notas e cálculos."
      />

      <div role="radiogroup" aria-label="Perfil de atuação" className="space-y-3">
        {perfisAtuacao.map((p) => (
          <SelectionCard
            key={p.id}
            icon={p.icon}
            titulo={p.titulo}
            subtitulo={p.subtitulo}
            selecionado={selecionado === p.id}
            onSelect={() => setData((prev) => ({ ...prev, perfil: p.id }))}
          />
        ))}
      </div>

      <StepFooter
        podeVoltar={podeVoltar}
        onVoltar={voltar}
        onAvancar={avancar}
        avancarDisabled={selecionado === null}
      />
    </div>
  );
}
