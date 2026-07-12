// src/components/onboarding/steps/StepTomadores.tsx
// Passo 3 — hospitais/clínicas do plantonista, com retenções e consulta simulada.

import { useState } from 'react';
import { Building2, Loader2, Plus, Trash2 } from 'lucide-react';
import { StepFooter, StepHeader, type StepProps } from '@/components/onboarding/StepShell';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';
import { StatusChip } from '@/components/ui/StatusChip';
import { useAppState } from '@/context/AppState';
import { consultarCnpjFake, limparCnpj, mascararCnpj } from '@/data/onboardingMock';
import { money } from '@/lib/format';
import { cn } from '@/lib/cn';

interface FormTomador {
  cnpj: string;
  valor: string;
  email: string;
  retemIss: boolean;
  aliquotaIss: string;
  retemIrrf: boolean;
  aliquotaIrrf: string;
}

const FORM_INICIAL: FormTomador = {
  cnpj: '',
  valor: '',
  email: '',
  retemIss: false,
  aliquotaIss: '2,0',
  retemIrrf: false,
  aliquotaIrrf: '1,5',
};

function decimal(valor: string): number {
  return Number(valor.replace(/\./g, '').replace(',', '.'));
}

export function StepTomadores({ data, setData, avancar, voltar, podeVoltar }: StepProps) {
  const { pushToast } = useAppState();
  const cnpjEdicao = data.cnpjEmEdicao;
  const tomadores = cnpjEdicao?.tomadores ?? [];
  const [form, setForm] = useState<FormTomador>(FORM_INICIAL);
  const [erro, setErro] = useState<string>();
  const [buscando, setBuscando] = useState(false);

  function patch<K extends keyof FormTomador>(campo: K, valor: FormTomador[K]) {
    setForm((prev) => ({ ...prev, [campo]: valor }));
    setErro(undefined);
  }

  async function adicionar() {
    const digitos = limparCnpj(form.cnpj);
    const valor = form.valor.trim() ? decimal(form.valor) : undefined;
    const iss = decimal(form.aliquotaIss);
    const irrf = decimal(form.aliquotaIrrf);

    if (digitos.length !== 14) return setErro('Informe um CNPJ com 14 dígitos.');
    if (tomadores.some((t) => limparCnpj(t.cnpj) === digitos)) return setErro('Este tomador já foi adicionado.');
    if (valor !== undefined && (!Number.isFinite(valor) || valor <= 0)) return setErro('Informe um valor padrão válido.');
    if (form.email && !form.email.includes('@')) return setErro('Informe um e-mail financeiro válido.');
    if (form.retemIss && (!Number.isFinite(iss) || iss < 0 || iss > 10)) return setErro('Alíquota de ISS deve ficar entre 0% e 10%.');
    if (form.retemIrrf && (!Number.isFinite(irrf) || irrf < 0.1 || irrf > 5)) return setErro('Alíquota de IRRF deve ficar entre 0,1% e 5%.');

    setBuscando(true);
    try {
      const lookup = await consultarCnpjFake(form.cnpj);
      setData((prev) =>
        prev.cnpjEmEdicao
          ? {
              ...prev,
              cnpjEmEdicao: {
                ...prev.cnpjEmEdicao,
                tomadores: [
                  ...prev.cnpjEmEdicao.tomadores,
                  {
                    cnpj: lookup.cnpj,
                    razaoSocial: lookup.razaoSocial,
                    municipio: lookup.municipio,
                    uf: lookup.uf,
                    valorPadrao: valor,
                    emailFinanceiro: form.email.trim() || undefined,
                    retemIss: form.retemIss,
                    aliquotaIss: form.retemIss ? iss : 0,
                    retemIrrf: form.retemIrrf,
                    aliquotaIrrf: form.retemIrrf ? irrf : 0,
                  },
                ],
              },
            }
          : prev,
      );
      setForm(FORM_INICIAL);
      pushToast({ tipo: 'sucesso', titulo: 'Tomador adicionado', descricao: lookup.razaoSocial });
    } catch (e) {
      setErro(e instanceof Error ? e.message : 'Não foi possível consultar o CNPJ.');
    } finally {
      setBuscando(false);
    }
  }

  function remover(cnpj: string) {
    setData((prev) =>
      prev.cnpjEmEdicao
        ? {
            ...prev,
            cnpjEmEdicao: {
              ...prev.cnpjEmEdicao,
              tomadores: prev.cnpjEmEdicao.tomadores.filter((t) => t.cnpj !== cnpj),
            },
          }
        : prev,
    );
  }

  return (
    <div>
      <StepHeader
        titulo="Tomadores"
        subtitulo="Cadastre hospitais e clínicas que contratam seus plantões. Você pode pular agora."
      />

      <div className="rounded-2xl border border-line bg-card p-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="CNPJ do tomador" required error={erro} className="sm:col-span-2">
            <Input
              autoFocus
              value={form.cnpj}
              onChange={(e) => patch('cnpj', mascararCnpj(e.target.value))}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !buscando) {
                  e.preventDefault();
                  adicionar();
                }
              }}
              placeholder="00.000.000/0001-00"
              inputMode="numeric"
              className="num"
            />
          </Field>
          <Field label="Valor padrão" hint="Opcional">
            <div className="relative">
              <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[13px] text-ink-muted">R$</span>
              <Input
                value={form.valor}
                onChange={(e) => patch('valor', e.target.value.replace(/[^\d.,]/g, ''))}
                placeholder="0,00"
                inputMode="decimal"
                className="num pl-10"
              />
            </div>
          </Field>
          <Field label="E-mail financeiro" hint="Opcional">
            <Input
              type="email"
              value={form.email}
              onChange={(e) => patch('email', e.target.value)}
              placeholder="financeiro@hospital.com.br"
            />
          </Field>
        </div>

        <div className="mt-4 space-y-3 border-t border-line pt-4">
          <Retencao
            label="Retém ISS?"
            checked={form.retemIss}
            onChange={(v) => patch('retemIss', v)}
            aliquota={form.aliquotaIss}
            onAliquota={(v) => patch('aliquotaIss', v)}
            min="0"
            max="10"
          />
          <Retencao
            label="Retém IRRF?"
            checked={form.retemIrrf}
            onChange={(v) => patch('retemIrrf', v)}
            aliquota={form.aliquotaIrrf}
            onAliquota={(v) => patch('aliquotaIrrf', v)}
            min="0.1"
            max="5"
          />
        </div>

        <Button
          className="mt-4 w-full"
          variant="outline"
          onClick={adicionar}
          disabled={buscando || !cnpjEdicao}
          aria-busy={buscando}
        >
          {buscando ? (
            <><Loader2 size={16} className="animate-spin" /> Buscando na Receita Federal…</>
          ) : (
            <><Plus size={16} /> Adicionar tomador</>
          )}
        </Button>
        <span className="sr-only" aria-live={erro ? 'assertive' : 'polite'}>
          {erro ?? (buscando ? 'Buscando tomador na Receita Federal' : '')}
        </span>
      </div>

      {tomadores.length > 0 && (
        <div className="mt-5 space-y-2.5">
          <p className="text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
            {tomadores.length} {tomadores.length === 1 ? 'tomador adicionado' : 'tomadores adicionados'}
          </p>
          {tomadores.map((tomador) => (
            <div key={tomador.cnpj} className="rounded-2xl border border-line bg-card p-4">
              <div className="flex items-start gap-3">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-canvas text-ink-muted">
                  <Building2 size={18} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13.5px] font-semibold text-ink">{tomador.razaoSocial}</p>
                  <p className="num mt-0.5 text-[11.5px] text-ink-muted">{tomador.cnpj} · {tomador.municipio}/{tomador.uf}</p>
                </div>
                <button
                  type="button"
                  onClick={() => remover(tomador.cnpj)}
                  aria-label={`Remover ${tomador.razaoSocial}`}
                  className="rounded-lg p-1.5 text-ink-faint hover:bg-danger-50 hover:text-danger-600 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-danger-500/15"
                >
                  <Trash2 size={16} />
                </button>
              </div>
              <div className="mt-3 flex flex-wrap items-center gap-2">
                {tomador.valorPadrao && <StatusChip label={money(tomador.valorPadrao)} tone="neutral" dot={false} />}
                {tomador.retemIss && <StatusChip label={`ISS ${tomador.aliquotaIss.toLocaleString('pt-BR')}%`} tone="info" />}
                {tomador.retemIrrf && <StatusChip label={`IRRF ${tomador.aliquotaIrrf.toLocaleString('pt-BR')}%`} tone="warn" />}
                {!tomador.retemIss && !tomador.retemIrrf && <StatusChip label="Sem retenções" tone="brand" />}
              </div>
            </div>
          ))}
        </div>
      )}

      <StepFooter
        podeVoltar={podeVoltar}
        onVoltar={voltar}
        onAvancar={avancar}
        avancarDisabled={buscando}
        labelAvancar={tomadores.length === 0 ? 'Pular por agora' : 'Continuar'}
      />
    </div>
  );
}

function Retencao({
  label,
  checked,
  onChange,
  aliquota,
  onAliquota,
  min,
  max,
}: {
  label: string;
  checked: boolean;
  onChange: (valor: boolean) => void;
  aliquota: string;
  onAliquota: (valor: string) => void;
  min: string;
  max: string;
}) {
  return (
    <div className="flex min-h-11 flex-col items-stretch justify-between gap-3 rounded-xl bg-canvas px-3.5 py-2.5 sm:flex-row sm:items-center sm:gap-4">
      <div className="flex items-center gap-3">
        <button
          type="button"
          role="switch"
          aria-checked={checked}
          aria-label={label}
          onClick={() => onChange(!checked)}
          className={cn('relative h-6 w-11 shrink-0 rounded-full transition-colors', checked ? 'bg-brand-500' : 'bg-line')}
        >
          <span className={cn('absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform', checked && 'translate-x-5')} />
        </button>
        <span className="text-[13px] font-medium text-ink-soft">{label}</span>
      </div>
      {checked && (
        <div className="flex items-center justify-end gap-1.5">
          <Input
            value={aliquota}
            onChange={(e) => onAliquota(e.target.value.replace(/[^\d,.]/g, ''))}
            inputMode="decimal"
            aria-label={`Alíquota — ${label}`}
            className="num h-9 w-20 text-right"
          />
          <span className="text-[12px] text-ink-muted">% · {min}–{max}</span>
        </div>
      )}
    </div>
  );
}
