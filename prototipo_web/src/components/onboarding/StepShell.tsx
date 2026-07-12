// src/components/onboarding/StepShell.tsx
// Contrato e peças compartilhadas dos passos do onboarding. Cada passo é dono do
// próprio cabeçalho e rodapé (valida internamente antes de chamar `avancar`),
// espelhando o padrão do medvie-app onde cada tela tem seu botão.

import type { Dispatch, SetStateAction } from 'react';
import { ArrowLeft, ArrowRight, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import type { OnboardingData } from '@/data/onboardingMock';

export interface StepProps {
  data: OnboardingData;
  setData: Dispatch<SetStateAction<OnboardingData>>;
  avancar: () => void;
  voltar: () => void;
  podeVoltar: boolean;
}

export function StepHeader({ titulo, subtitulo }: { titulo: string; subtitulo: string }) {
  return (
    <header className="mb-7">
      <h1 className="font-brand text-[26px] font-bold leading-tight text-ink">{titulo}</h1>
      <p className="mt-2 text-[15px] leading-snug text-ink-muted">{subtitulo}</p>
    </header>
  );
}

interface StepFooterProps {
  podeVoltar: boolean;
  onVoltar: () => void;
  onAvancar: () => void;
  labelAvancar?: string;
  avancarDisabled?: boolean;
  loading?: boolean;
}

export function StepFooter({
  podeVoltar,
  onVoltar,
  onAvancar,
  labelAvancar = 'Continuar',
  avancarDisabled = false,
  loading = false,
}: StepFooterProps) {
  return (
    <div className="mt-8 flex flex-col-reverse gap-3 sm:flex-row sm:items-center" aria-busy={loading}>
      {podeVoltar && (
        <Button type="button" variant="ghost" onClick={onVoltar} disabled={loading} className="w-full sm:w-auto">
          <ArrowLeft size={17} /> Voltar
        </Button>
      )}
      <div className="hidden flex-1 sm:block" />
      <Button type="button" onClick={onAvancar} disabled={avancarDisabled || loading} className="w-full sm:w-auto">
        {loading ? (
          <>
            <Loader2 size={17} className="animate-spin" /> Salvando…
          </>
        ) : (
          <>
            {labelAvancar} <ArrowRight size={17} />
          </>
        )}
      </Button>
    </div>
  );
}
