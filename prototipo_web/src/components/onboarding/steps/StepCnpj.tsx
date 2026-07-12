// src/components/onboarding/steps/StepCnpj.tsx
// Passo 2a — CNPJ da PJ. Consulta simulada à Receita Federal → card de resultado,
// Inscrição Municipal e Regime Tributário (com explicador dinâmico). Grava o CNPJ
// em `cnpjEmEdicao`, que os passos seguintes (assinatura, tomadores) completam.

import { useState } from 'react';
import { Loader2, CheckCircle2, Info } from 'lucide-react';
import { Field, Input } from '@/components/ui/Field';
import { Button } from '@/components/ui/Button';
import { Segmented } from '@/components/ui/Segmented';
import { CnpjResultCard } from '@/components/onboarding/CnpjResultCard';
import { StepHeader, StepFooter, type StepProps } from '@/components/onboarding/StepShell';
import {
  consultarCnpjFake,
  limparCnpj,
  mascararCnpj,
  novoCnpjOnb,
  regimesOnboarding,
} from '@/data/onboardingMock';
import type { RegimeTributario } from '@/types';
import { regimeMeta } from '@/data/domain';
import { cn } from '@/lib/cn';

export function StepCnpj({ data, setData, avancar, voltar, podeVoltar }: StepProps) {
  const cnpjEdicao = data.cnpjEmEdicao;
  const [cnpjInput, setCnpjInput] = useState(cnpjEdicao?.lookup.cnpj ?? '');
  const [buscando, setBuscando] = useState(false);
  const [erroConsulta, setErroConsulta] = useState<string | undefined>();

  const lookup = cnpjEdicao?.lookup;
  const consultaAtual =
    !!lookup && limparCnpj(lookup.cnpj) === limparCnpj(cnpjInput);
  const podeAvancar = consultaAtual && (cnpjEdicao?.inscricaoMunicipal.trim() ?? '') !== '';

  async function consultar() {
    setErroConsulta(undefined);
    if (limparCnpj(cnpjInput).length !== 14) {
      setErroConsulta('CNPJ deve ter 14 dígitos');
      return;
    }
    setBuscando(true);
    try {
      const res = await consultarCnpjFake(cnpjInput);
      setData((prev) => {
        const mesmo =
          prev.cnpjEmEdicao && limparCnpj(prev.cnpjEmEdicao.lookup.cnpj) === limparCnpj(res.cnpj);
        return {
          ...prev,
          cnpjEmEdicao: mesmo
            ? { ...prev.cnpjEmEdicao!, lookup: res }
            : novoCnpjOnb(res),
        };
      });
    } catch (e) {
      setErroConsulta(e instanceof Error ? e.message : 'Falha na consulta');
    } finally {
      setBuscando(false);
    }
  }

  function patch<K extends 'inscricaoMunicipal' | 'regime'>(campo: K, valor: string) {
    setData((prev) =>
      prev.cnpjEmEdicao
        ? { ...prev, cnpjEmEdicao: { ...prev.cnpjEmEdicao, [campo]: valor } }
        : prev,
    );
  }

  return (
    <div>
      <StepHeader titulo="Seu CNPJ" subtitulo="O CNPJ da sua PJ — de onde você emite as NFS-e." />

      <Field label="CNPJ">
        <div className="flex gap-2.5">
          <Input
            autoFocus
            value={cnpjInput}
            onChange={(e) => setCnpjInput(mascararCnpj(e.target.value))}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                consultar();
              }
            }}
            placeholder="00.000.000/0001-00"
            inputMode="numeric"
            className="num"
          />
          <Button variant="outline" onClick={consultar} disabled={buscando} className="shrink-0">
            {buscando ? <Loader2 size={16} className="animate-spin" /> : 'Consultar'}
          </Button>
        </div>
      </Field>

      {(consultaAtual || erroConsulta) && (
        <div className="mt-4" aria-live="polite">
          <CnpjResultCard lookup={consultaAtual ? lookup : undefined} erro={erroConsulta} />
        </div>
      )}

      {consultaAtual && cnpjEdicao && (
        <div className="mt-5 space-y-5">
          <Field label="Inscrição Municipal" required>
            <Input
              value={cnpjEdicao.inscricaoMunicipal}
              onChange={(e) => patch('inscricaoMunicipal', limparCnpj(e.target.value))}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && podeAvancar) {
                  e.preventDefault();
                  avancar();
                }
              }}
              placeholder="Número da inscrição municipal da sua PJ"
              inputMode="numeric"
              className="num"
            />
          </Field>

          <div>
            <p className="mb-2 flex items-center gap-1 text-[13px] font-medium text-ink-soft">
              Regime Tributário
            </p>
            <Segmented
              value={cnpjEdicao.regime}
              onChange={(v) => patch('regime', v)}
              options={regimesOnboarding.map((r) => ({ value: r, label: regimeMeta[r].label }))}
              className="w-full [&>button]:flex-1"
            />
            <RegimeInfo regime={cnpjEdicao.regime} />
          </div>
        </div>
      )}

      <StepFooter podeVoltar={podeVoltar} onVoltar={voltar} onAvancar={avancar} avancarDisabled={!podeAvancar} />
    </div>
  );
}

// ── Explicador dinâmico do regime (copy alinhada ao medvie-app) ────────────────
function RegimeInfo({ regime }: { regime: RegimeTributario }) {
  const info =
    regime === 'simplesNacional'
      ? {
          tom: 'brand' as const,
          titulo: 'Simples Nacional',
          texto:
            'Alíquota efetiva sobre a receita bruta (Anexo III ou V). ISS incluso no DAS. ' +
            'Carga real de 6% a 19,5% conforme o Fator R.',
        }
      : {
          tom: 'info' as const,
          titulo: 'Lucro Presumido',
          texto:
            'Presunção de 32% da receita para serviços médicos. IRPJ 15% + CSLL 9% + PIS 0,65% + ' +
            'COFINS 3% + ISS municipal. IBS 0,1% e CBS 0,9% destacados na NFS-e desde 01/01/2026.',
        };

  const cor =
    info.tom === 'brand'
      ? 'border-brand-100 bg-brand-50/50 text-brand-700'
      : 'border-info-100 bg-info-50/60 text-info-700';

  return (
    <div className={cn('mt-3 rounded-xl border p-3.5', cor)}>
      <div className="flex items-center gap-1.5">
        {info.tom === 'brand' ? <CheckCircle2 size={15} /> : <Info size={15} />}
        <p className="text-[13px] font-bold">{info.titulo}</p>
      </div>
      <p className="mt-1 text-[12.5px] leading-relaxed text-ink-soft">{info.texto}</p>
    </div>
  );
}
