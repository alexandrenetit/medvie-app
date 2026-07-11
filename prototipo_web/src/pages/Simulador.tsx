import { useMemo, useState } from 'react';
import { Calculator, ArrowRight, Sparkles, Check, TrendingDown } from 'lucide-react';
import { Card, CardHeader } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Field } from '@/components/ui/Field';
import { Segmented } from '@/components/ui/Segmented';
import { useAppState } from '@/context/AppState';
import { simular, aliquotasRegime } from '@/data/mock';
import { money, moneyPlain } from '@/lib/format';
import { tipoServicoMeta, regimeMeta } from '@/data/domain';
import { cn } from '@/lib/cn';
import type { RegimeTributario, TipoServico } from '@/types';

const tipos: TipoServico[] = ['consulta', 'plantao', 'atoAnestesico', 'procedimentoCirurgico', 'laudo'];
const regimes: RegimeTributario[] = ['simplesNacional', 'lucroPresumido', 'lucroReal'];

export default function Simulador() {
  const { setNovoAtendimentoOpen } = useAppState();
  const [valor, setValor] = useState(3200);
  const [tipo, setTipo] = useState<TipoServico>('atoAnestesico');
  const [regime, setRegime] = useState<RegimeTributario>('lucroPresumido');

  const resultado = useMemo(() => simular(valor, tipo, regime), [valor, tipo, regime]);
  const cenarios = useMemo(
    () => regimes.map((r) => ({ regime: r, ...simular(valor, tipo, r) })),
    [valor, tipo],
  );
  const melhor = cenarios.reduce((a, b) => (b.valorLiquido > a.valorLiquido ? b : a));

  const deducoes = valor - resultado.valorLiquido;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-brand text-[24px] font-bold text-ink">Simulador de honorários</h1>
        <p className="mt-0.5 text-[14px] text-ink-muted">
          Descubra o líquido de um atendimento antes de fechar o valor. Cálculo estimado.
        </p>
      </div>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
        {/* Entradas */}
        <Card className="p-5 sm:p-6">
          <div className="space-y-6">
            <Field label="Valor bruto do atendimento">
              <div className="relative">
                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-[18px] font-semibold text-ink-muted">
                  R$
                </span>
                <input
                  inputMode="decimal"
                  value={moneyPlain(valor)}
                  onChange={(e) => {
                    const n = Number(e.target.value.replace(/\./g, '').replace(',', '.').replace(/[^\d.]/g, ''));
                    setValor(Number.isFinite(n) ? n : 0);
                  }}
                  className="field num h-14 pl-12 text-[22px] font-bold"
                />
              </div>
              <input
                type="range"
                min={200}
                max={15000}
                step={100}
                value={valor}
                onChange={(e) => setValor(Number(e.target.value))}
                className="mt-4 w-full accent-brand-600"
              />
              <div className="mt-1 flex justify-between text-[11.5px] text-ink-faint">
                <span>R$ 200</span>
                <span>R$ 15.000</span>
              </div>
            </Field>

            <div>
              <p className="mb-2 text-[13px] font-medium text-ink-soft">Tipo de serviço</p>
              <div className="flex flex-wrap gap-2">
                {tipos.map((t) => (
                  <button
                    key={t}
                    onClick={() => setTipo(t)}
                    className={cn(
                      'rounded-xl border px-3.5 py-2 text-[13px] font-medium transition-all',
                      t === tipo
                        ? 'border-brand-500 bg-brand-50/60 text-brand-700 shadow-ring'
                        : 'border-line text-ink-soft hover:border-ink-faint',
                    )}
                  >
                    {tipoServicoMeta[t].label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <p className="mb-2 text-[13px] font-medium text-ink-soft">Regime tributário</p>
              <Segmented<RegimeTributario>
                value={regime}
                onChange={setRegime}
                className="w-full"
                options={[
                  { value: 'simplesNacional', label: 'Simples' },
                  { value: 'lucroPresumido', label: 'Presumido' },
                  { value: 'lucroReal', label: 'Real' },
                ]}
              />
              <p className="mt-2 text-[12.5px] text-ink-muted">{regimeMeta[regime].descricao}</p>
            </div>
          </div>
        </Card>

        {/* Resultado */}
        <Card className="overflow-hidden">
          <div className="relative bg-gradient-to-br from-brand-600 to-brand-700 p-6 text-white">
            <div
              className="pointer-events-none absolute inset-0 opacity-20"
              style={{ backgroundImage: 'radial-gradient(circle at 85% 15%, #fff, transparent 40%)' }}
            />
            <div className="relative">
              <p className="flex items-center gap-1.5 text-[13px] font-medium text-white/80">
                <Sparkles size={14} /> Líquido estimado
              </p>
              <p className="num mt-2 text-[42px] font-bold leading-none">
                {money(resultado.valorLiquido)}
              </p>
              <p className="mt-2 text-[13px] text-white/80">
                de {money(valor)} brutos · você fica com{' '}
                {((resultado.valorLiquido / valor) * 100 || 0).toFixed(1)}%
              </p>
            </div>
          </div>

          <div className="space-y-2.5 p-5">
            <LinhaResultado label="Valor bruto" valor={valor} />
            <LinhaResultado label={`ISS (${(resultado.aliquotaIss * 100).toFixed(0)}%)`} valor={-resultado.descontoIss} />
            {resultado.descontoIrrf > 0 && (
              <LinhaResultado label="IRRF retido (1,5%)" valor={-resultado.descontoIrrf} />
            )}
            <LinhaResultado
              label={`Impostos do regime (${(aliquotasRegime[regime] * 100).toFixed(1)}%)`}
              valor={-resultado.cargaRegime}
            />
            <div className="flex items-center justify-between border-t border-line pt-3">
              <span className="flex items-center gap-1.5 text-[13px] font-medium text-ink-soft">
                <TrendingDown size={14} className="text-danger-500" /> Total de deduções
              </span>
              <span className="num font-bold text-danger-600">− {money(deducoes)}</span>
            </div>
          </div>

          <div className="border-t border-line px-5 py-4">
            <Button size="md" className="w-full" onClick={() => setNovoAtendimentoOpen(true)}>
              Usar em novo atendimento <ArrowRight size={16} />
            </Button>
          </div>
        </Card>
      </div>

      {/* Comparação de regimes */}
      <Card>
        <CardHeader
          title="Comparação entre regimes"
          subtitle="Para o mesmo atendimento, qual regime rende mais líquido"
          icon={<Calculator size={18} />}
        />
        <div className="grid gap-4 p-5 sm:grid-cols-3">
          {cenarios.map((c) => {
            const isMelhor = c.regime === melhor.regime;
            const isSelecionado = c.regime === regime;
            return (
              <button
                key={c.regime}
                onClick={() => setRegime(c.regime)}
                className={cn(
                  'rounded-2xl border p-4 text-left transition-all',
                  isSelecionado
                    ? 'border-brand-500 bg-brand-50/40 shadow-ring'
                    : 'border-line hover:border-ink-faint',
                )}
              >
                <div className="flex items-center justify-between">
                  <p className="text-[13.5px] font-semibold text-ink">{regimeMeta[c.regime].label}</p>
                  {isMelhor && (
                    <span className="chip bg-brand-100 text-brand-700">
                      <Check size={12} /> Melhor
                    </span>
                  )}
                </div>
                <p className="num mt-3 text-[24px] font-bold text-ink">{money(c.valorLiquido)}</p>
                <p className="text-[12px] text-ink-muted">líquido estimado</p>
                <div className="mt-3 flex items-center justify-between border-t border-line pt-3 text-[12.5px]">
                  <span className="text-ink-muted">Alíquota efetiva</span>
                  <span className="num font-semibold text-ink">
                    {(c.aliquotaEfetiva * 100).toFixed(1)}%
                  </span>
                </div>
              </button>
            );
          })}
        </div>
        <p className="px-5 pb-5 text-[11.5px] leading-snug text-ink-faint">
          Simulação de referência para planejamento. No produto, os valores oficiais vêm do backend
          Medvie, considerando retenções específicas de cada tomador e a reforma tributária (IBS/CBS).
        </p>
      </Card>
    </div>
  );
}

function LinhaResultado({ label, valor }: { label: string; valor: number }) {
  const neg = valor < 0;
  return (
    <div className="flex items-center justify-between text-[13.5px]">
      <span className="text-ink-muted">{label}</span>
      <span className={cn('num font-semibold', neg ? 'text-danger-600' : 'text-ink')}>
        {neg ? '− ' : ''}
        {money(Math.abs(valor))}
      </span>
    </div>
  );
}
