// src/components/onboarding/CnpjResultCard.tsx
// Card do resultado da consulta de CNPJ. Três variantes: sucesso (ativo, verde),
// alerta (situação ≠ ATIVA, âmbar) e erro (danger). Entrada animada.

import { CheckCircle2, AlertTriangle, XCircle } from 'lucide-react';
import { dataBR } from '@/lib/format';
import type { CnpjLookup } from '@/data/onboardingMock';

export function CnpjResultCard({ lookup, erro }: { lookup?: CnpjLookup; erro?: string }) {
  if (erro) {
    return (
      <div className="animate-slide-up flex items-start gap-3 rounded-2xl border border-danger-100 bg-danger-50/60 p-4">
        <XCircle size={18} className="mt-0.5 shrink-0 text-danger-600" />
        <p className="text-[13.5px] font-medium text-danger-700">{erro}</p>
      </div>
    );
  }

  if (!lookup) return null;

  const ativa = lookup.situacao.toUpperCase() === 'ATIVA';
  const mostrarFantasia =
    lookup.nomeFantasia && lookup.nomeFantasia.toUpperCase() !== lookup.razaoSocial.toUpperCase();

  return (
    <div className="animate-slide-up space-y-3">
      <div className="rounded-2xl border border-brand-200 bg-brand-50/50 p-4">
        <div className="flex items-center gap-2.5">
          <CheckCircle2 size={18} className="shrink-0 text-brand-600" />
          <p className="text-[14px] font-bold uppercase leading-tight text-brand-700">
            {lookup.razaoSocial}
          </p>
        </div>

        <div className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 border-t border-brand-200/70 pt-3">
          {mostrarFantasia && <Linha label="Fantasia" valor={lookup.nomeFantasia} />}
          <Linha
            label="Situação"
            valor={lookup.situacao.toUpperCase()}
            tom={ativa ? 'text-brand-700' : 'text-warn-700'}
          />
          <Linha label="Porte" valor={lookup.porte} />
          <Linha label="Município" valor={`${lookup.municipio}/${lookup.uf}`} />
          <Linha label="Abertura" valor={dataBR(lookup.abertura)} />
        </div>
      </div>

      {!ativa && (
        <div className="flex items-start gap-3 rounded-xl border border-warn-100 bg-warn-50/60 p-3.5">
          <AlertTriangle size={16} className="mt-0.5 shrink-0 text-warn-600" />
          <p className="text-[12.5px] leading-snug text-warn-700">
            Este CNPJ não está ativo na Receita Federal. Verifique antes de continuar.
          </p>
        </div>
      )}
    </div>
  );
}

function Linha({ label, valor, tom = 'text-ink' }: { label: string; valor: string; tom?: string }) {
  return (
    <div className="min-w-0">
      <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">{label}</p>
      <p className={`mt-0.5 truncate text-[13px] font-medium ${tom}`}>{valor}</p>
    </div>
  );
}
