// src/components/onboarding/steps/StepConfirmacao.tsx
// Passo 4 — revisão consolidada do médico, CNPJs, assinatura e tomadores.

import { Building2, Hospital, Plus, Stethoscope } from 'lucide-react';
import { StepFooter, StepHeader } from '@/components/onboarding/StepShell';
import { Button } from '@/components/ui/Button';
import { Card, CardHeader } from '@/components/ui/Card';
import { StatusChip } from '@/components/ui/StatusChip';
import { regimeMeta } from '@/data/domain';
import { limparCnpj, type CnpjOnb, type OnboardingData } from '@/data/onboardingMock';
import { maskCPF, money } from '@/lib/format';

interface StepConfirmacaoProps {
  data: OnboardingData;
  voltar: () => void;
  podeVoltar: boolean;
  onAdicionarCnpj: () => void;
  onConcluir: () => void;
}

function cnpjsParaRevisao(data: OnboardingData): CnpjOnb[] {
  if (!data.cnpjEmEdicao) return data.cnpjs;
  const atual = limparCnpj(data.cnpjEmEdicao.lookup.cnpj);
  return [...data.cnpjs.filter((c) => limparCnpj(c.lookup.cnpj) !== atual), data.cnpjEmEdicao];
}

export function StepConfirmacao({
  data,
  voltar,
  podeVoltar,
  onAdicionarCnpj,
  onConcluir,
}: StepConfirmacaoProps) {
  const cnpjs = cnpjsParaRevisao(data);

  return (
    <div>
      <StepHeader titulo="Tudo certo!" subtitulo="Confira os dados antes de concluir sua configuração." />

      <div className="space-y-3">
        <Card>
          <CardHeader title="Médico" subtitle="Dados pessoais e profissionais" icon={<Stethoscope size={18} />} />
          <div className="grid gap-x-5 gap-y-3 p-5 sm:grid-cols-2">
            <Info label="Nome" valor={data.dados.nome} />
            <Info label="CPF" valor={maskCPF(data.dados.cpf)} mono />
            <Info label="CRM" valor={`${data.dados.crm}-${data.dados.ufCrm}`} mono />
            <Info label="Especialidade" valor={data.especialidade ?? '—'} />
          </div>
        </Card>

        {cnpjs.map((cnpj, index) => {
          const assinaturaA1 = cnpj.metodoAssinatura === 'certificadoA1';
          const assinaturaPronta = assinaturaA1 && cnpj.certificadoAnexado;
          return (
            <Card key={cnpj.lookup.cnpj}>
              <CardHeader
                title={cnpj.lookup.razaoSocial}
                subtitle={<span className="num">{cnpj.lookup.cnpj}</span>}
                icon={<Building2 size={18} />}
                action={<StatusChip label={`CNPJ ${index + 1}`} tone="neutral" dot={false} />}
              />
              <div className="grid gap-x-5 gap-y-3 p-5 sm:grid-cols-2">
                <Info label="Município" valor={`${cnpj.lookup.municipio}/${cnpj.lookup.uf}`} />
                <Info label="Inscrição municipal" valor={cnpj.inscricaoMunicipal} mono />
                <Info label="Regime tributário" valor={regimeMeta[cnpj.regime].label} />
                <div>
                  <p className="text-[11.5px] font-semibold uppercase tracking-wide text-ink-faint">Assinatura</p>
                  <div className="mt-1 flex flex-wrap gap-1.5">
                    <StatusChip label={assinaturaA1 ? 'Certificado A1' : 'Procuração gov.br'} tone="info" dot={false} />
                    <StatusChip
                      label={assinaturaPronta ? 'Pronto' : 'Pendente'}
                      tone={assinaturaPronta ? 'brand' : 'warn'}
                    />
                  </div>
                </div>
              </div>

              {cnpj.tomadores.length > 0 && (
                <div className="border-t border-line px-5 py-4">
                  <p className="mb-2.5 text-[11.5px] font-semibold uppercase tracking-wide text-ink-faint">
                    {cnpj.tomadores.length} {cnpj.tomadores.length === 1 ? 'tomador' : 'tomadores'}
                  </p>
                  <div className="space-y-2">
                    {cnpj.tomadores.map((tomador) => (
                      <div key={tomador.cnpj} className="flex items-center gap-2.5 text-[12.5px]">
                        <Hospital size={14} className="shrink-0 text-info-600" />
                        <span className="min-w-0 flex-1 truncate text-ink-soft">{tomador.razaoSocial}</span>
                        {tomador.valorPadrao && (
                          <span className="num shrink-0 font-medium text-brand-700">{money(tomador.valorPadrao)}</span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </Card>
          );
        })}
      </div>

      <Button variant="outline" className="mt-4 w-full" onClick={onAdicionarCnpj}>
        <Plus size={16} /> Adicionar outro CNPJ
      </Button>
      <StepFooter
        podeVoltar={podeVoltar}
        onVoltar={voltar}
        onAvancar={onConcluir}
        labelAvancar="Concluir"
        avancarDisabled={cnpjs.length === 0}
      />
    </div>
  );
}

function Info({ label, valor, mono = false }: { label: string; valor: string; mono?: boolean }) {
  return (
    <div className="min-w-0">
      <p className="text-[11.5px] font-semibold uppercase tracking-wide text-ink-faint">{label}</p>
      <p className={`mt-1 truncate text-[13.5px] font-medium text-ink ${mono ? 'num' : ''}`}>{valor}</p>
    </div>
  );
}
