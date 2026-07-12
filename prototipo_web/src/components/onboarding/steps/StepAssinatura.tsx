// src/components/onboarding/steps/StepAssinatura.tsx
// Passo 2b — método de assinatura da PJ, com orientação contextual e upload A1 simulado.

import { BadgeCheck, FileKey2, Landmark, ShieldCheck, UploadCloud } from 'lucide-react';
import { SelectionCard } from '@/components/onboarding/SelectionCard';
import { StepFooter, StepHeader, type StepProps } from '@/components/onboarding/StepShell';
import { Button } from '@/components/ui/Button';
import { useAppState } from '@/context/AppState';
import type { MetodoAssinatura } from '@/data/onboardingMock';

export function StepAssinatura({ data, setData, avancar, voltar, podeVoltar }: StepProps) {
  const { pushToast } = useAppState();
  const cnpj = data.cnpjEmEdicao;
  const metodo = cnpj?.metodoAssinatura;

  function selecionar(valor: MetodoAssinatura) {
    setData((prev) =>
      prev.cnpjEmEdicao
        ? {
            ...prev,
            cnpjEmEdicao: {
              ...prev.cnpjEmEdicao,
              metodoAssinatura: valor,
              certificadoAnexado:
                valor === 'certificadoA1' && prev.cnpjEmEdicao.certificadoAnexado,
            },
          }
        : prev,
    );
  }

  function anexarCertificado() {
    setData((prev) =>
      prev.cnpjEmEdicao
        ? {
            ...prev,
            cnpjEmEdicao: { ...prev.cnpjEmEdicao, certificadoAnexado: true },
          }
        : prev,
    );
    pushToast({
      tipo: 'sucesso',
      titulo: 'Certificado anexado',
      descricao: 'Upload simulado — nenhum arquivo foi enviado.',
    });
  }

  return (
    <div
      onKeyDownCapture={(e) => {
        if (e.key === 'Enter' && metodo && (e.target as HTMLElement).getAttribute('aria-checked') === 'true') {
          e.preventDefault();
          avancar();
        }
      }}
    >
      <StepHeader
        titulo="Assinatura digital"
        subtitulo="Escolha como sua empresa autoriza a emissão das NFS-e."
      />

      <div className="space-y-3" role="radiogroup" aria-label="Método de assinatura digital">
        <SelectionCard
          icon={FileKey2}
          titulo="Certificado digital A1"
          subtitulo="Automático e recomendado para emitir sem interrupções."
          selecionado={metodo === 'certificadoA1'}
          onSelect={() => selecionar('certificadoA1')}
        />
        <SelectionCard
          icon={Landmark}
          titulo="Procuração gov.br"
          subtitulo="Autorize o Medvie pelo e-CAC, sem compartilhar sua senha."
          selecionado={metodo === 'govBr'}
          onSelect={() => selecionar('govBr')}
        />
      </div>

      {metodo && (
        <div className="mt-4 rounded-2xl border border-info-100 bg-info-50/50 p-4">
          <div className="flex items-start gap-3">
            <ShieldCheck size={18} className="mt-0.5 shrink-0 text-info-600" />
            <div>
              <p className="text-[13.5px] font-semibold text-ink">
                {metodo === 'certificadoA1' ? 'Emissão automática' : 'Autorização sem certificado'}
              </p>
              <p className="mt-1 text-[12.5px] leading-relaxed text-ink-muted">
                {metodo === 'certificadoA1'
                  ? 'O arquivo A1 fica protegido e assina cada nota automaticamente. Aceitamos .pfx e .p12; neste protótipo, o upload é apenas demonstrativo.'
                  : 'Você cria uma procuração eletrônica no e-CAC para o Medvie emitir em nome da sua empresa. Sua senha gov.br nunca é solicitada.'}
              </p>
            </div>
          </div>
        </div>
      )}

      {metodo === 'certificadoA1' && (
        <div className="mt-4 rounded-2xl border border-dashed border-line bg-canvas p-4 text-center">
          {cnpj?.certificadoAnexado ? (
            <>
              <BadgeCheck size={24} className="mx-auto text-brand-600" />
              <p className="mt-2 text-[13.5px] font-semibold text-ink">Certificado pronto</p>
              <p className="mt-0.5 text-[12px] text-ink-muted">certificado-medvie.pfx · arquivo simulado</p>
              <Button variant="ghost" size="sm" className="mt-2" onClick={anexarCertificado}>
                Substituir arquivo
              </Button>
            </>
          ) : (
            <>
              <UploadCloud size={23} className="mx-auto text-ink-faint" />
              <p className="mt-2 text-[13.5px] font-medium text-ink">Anexe seu e-CNPJ A1</p>
              <p className="mt-0.5 text-[12px] text-ink-muted">.pfx ou .p12 · upload simulado</p>
              <Button variant="outline" size="sm" className="mt-3" onClick={anexarCertificado}>
                <UploadCloud size={15} /> Selecionar arquivo
              </Button>
            </>
          )}
        </div>
      )}

      <StepFooter
        podeVoltar={podeVoltar}
        onVoltar={voltar}
        onAvancar={avancar}
        avancarDisabled={!cnpj || !metodo}
      />
    </div>
  );
}
