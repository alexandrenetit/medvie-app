import { useMemo, useState } from 'react';
import { ArrowRight, Building2, Landmark, Sparkles } from 'lucide-react';
import { Card, CardHeader } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Field, Select } from '@/components/ui/Field';
import { useAppState } from '@/context/AppState';
import { medico, previewFiscalAtendimento, tomadores } from '@/data/mock';
import { money, moneyPlain } from '@/lib/format';
import { regimeMeta } from '@/data/domain';
import { cn } from '@/lib/cn';

// Espelha o simulador do app (simulador_bottom_sheet + preview_fiscal_cnpj_card):
// valor + tomador → preview fiscal oficial da reforma (IBS/CBS) calculado pelo
// backend. A UI NÃO infere alíquota nem carga de regime — ISS/IRRF dependem do
// cadastro do tomador e só são definidos no envio.
export default function Simulador() {
  const { setNovoAtendimentoOpen, cnpjAtivoId } = useAppState();
  const cnpj = medico.cnpjs.find((c) => c.id === cnpjAtivoId) ?? medico.cnpjs[0];
  const [valor, setValor] = useState(3200);
  const [tomadorId, setTomadorId] = useState('');

  const hospitais = useMemo(() => tomadores.filter((t) => t.tipo === 'cnpj'), []);
  const tomador = hospitais.find((t) => t.id === tomadorId) ?? null;

  const preview = useMemo(
    () => previewFiscalAtendimento(valor, cnpj.regime, tomador),
    [valor, cnpj.regime, tomador],
  );
  const simples = cnpj.regime === 'simplesNacional';

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-brand text-[24px] font-bold text-ink">Simulador de honorários</h1>
        <p className="mt-0.5 text-[14px] text-ink-muted">
          Prévia fiscal da reforma (IBS/CBS) com os valores oficiais calculados pelo Medvie.
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

            <Field
              label="Hospital / Clínica"
              hint="Define as retenções de ISS/IRRF (cadastro do tomador). Opcional."
            >
              <div className="relative">
                <Building2 size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
                <Select
                  value={tomadorId}
                  onChange={(e) => setTomadorId(e.target.value)}
                  className="pl-10"
                >
                  <option value="">Sem tomador — retenções definidas na emissão</option>
                  {hospitais.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.nome}
                    </option>
                  ))}
                </Select>
              </div>
            </Field>

            <div className="rounded-xl bg-canvas p-4">
              <p className="flex items-center gap-2 text-[13px] font-semibold text-ink">
                <Landmark size={15} className="text-ink-muted" /> Empresa emissora
              </p>
              <p className="mt-1 text-[13px] text-ink-soft">{cnpj.nomeFantasia}</p>
              <p className="text-[12px] text-ink-muted">
                {regimeMeta[cnpj.regime].label} · {cnpj.municipio}/{cnpj.uf}
              </p>
            </div>
          </div>
        </Card>

        {/* Preview fiscal — mesmo card do fluxo de atendimento */}
        <Card className="overflow-hidden">
          <div className="relative bg-gradient-to-br from-brand-600 to-brand-700 p-6 text-white">
            <div
              className="pointer-events-none absolute inset-0 opacity-20"
              style={{ backgroundImage: 'radial-gradient(circle at 85% 15%, #fff, transparent 40%)' }}
            />
            <div className="relative">
              <p className="flex items-center gap-1.5 text-[13px] font-medium text-white/80">
                <Sparkles size={14} /> Valor da NFS-e · líquido estimado
              </p>
              <p className="num mt-2 text-[42px] font-bold leading-none">
                {money(preview.liquidoEstimado)}
              </p>
              <p className="mt-2 text-[13px] text-white/80">
                de {money(preview.bruto)} brutos
                {preview.issRetido + preview.irrfRetido > 0 &&
                  ` · ${money(preview.issRetido + preview.irrfRetido)} retidos na fonte`}
              </p>
            </div>
          </div>

          <div className="space-y-2.5 p-5">
            <LinhaPreview label="Valor do serviço" valor={money(preview.bruto)} />
            <LinhaPreview
              label="ISS retido"
              valor={
                !tomador
                  ? 'a definir na emissão'
                  : tomador.retemIss
                    ? `− ${money(preview.issRetido)}`
                    : 'Não retém'
              }
              muted={!tomador?.retemIss}
            />
            <LinhaPreview
              label="IRRF retido"
              valor={
                !tomador
                  ? 'a definir na emissão'
                  : tomador.retemIrrf
                    ? `− ${money(preview.irrfRetido)}`
                    : 'Não retém'
              }
              muted={!tomador?.retemIrrf}
            />
            <LinhaPreview
              label="IBS"
              tag="REFORMA"
              valor={simples ? 'destaque a partir de 2027' : money(preview.ibs)}
              muted={simples}
            />
            <LinhaPreview
              label="CBS"
              tag="REFORMA"
              valor={simples ? 'destaque a partir de 2027' : money(preview.cbs)}
              muted={simples}
            />
            <div className="mt-2 rounded-xl bg-line2/50 p-3">
              <span className="chip bg-brand-100 text-brand-700">Cálculo oficial Medvie</span>
              <p className="mt-2 text-[11.5px] leading-snug text-ink-muted">
                Retenções e IBS/CBS são definidos na emissão da nota — os valores oficiais são
                calculados pelo Medvie. IBS/CBS (fase de teste 2026) são informativos e não
                reduzem o seu líquido.
              </p>
            </div>
          </div>

          <div className="border-t border-line px-5 py-4">
            <Button size="md" className="w-full" onClick={() => setNovoAtendimentoOpen(true)}>
              Usar em novo atendimento <ArrowRight size={16} />
            </Button>
          </div>
        </Card>
      </div>

      {/* Contexto da reforma — informativo */}
      <Card>
        <CardHeader
          title="Reforma tributária em 2026"
          subtitle="Fase de teste do IBS e da CBS (LC 214/2025)"
          icon={<Landmark size={18} />}
        />
        <div className="grid gap-4 p-5 sm:grid-cols-3">
          <ReformaItem
            titulo="2026 · fase de teste"
            texto="IBS 0,1% + CBS 0,9% destacados na NFS-e apenas a título informativo — sem recolhimento quando as obrigações acessórias são cumpridas."
          />
          <ReformaItem
            titulo="2027 · CBS efetiva"
            texto="PIS e COFINS são extintos e a CBS assume. O Simples Nacional passa a destacar IBS/CBS."
          />
          <ReformaItem
            titulo="2029–2033 · transição do ISS"
            texto="ISS é reduzido gradualmente a partir de 2029 e extinto em 2033, quando o IBS assume integralmente."
          />
        </div>
        <p className="px-5 pb-5 text-[11.5px] leading-snug text-ink-faint">
          Simulação de referência — não é apuração fiscal nem autorização de emissão. Cronograma:
          EC 132/2023 e LC 214/2025.
        </p>
      </Card>
    </div>
  );
}

function LinhaPreview({
  label,
  valor,
  tag,
  muted,
}: {
  label: string;
  valor: string;
  tag?: string;
  muted?: boolean;
}) {
  return (
    <div className="flex items-center justify-between text-[13.5px]">
      <span className="flex items-center gap-2 text-ink-muted">
        {label}
        {tag && (
          <span className="rounded bg-info-50 px-1.5 py-0.5 text-[9.5px] font-bold tracking-wide text-info-700">
            {tag}
          </span>
        )}
      </span>
      <span className={cn('num font-semibold', muted ? 'text-ink-faint' : 'text-ink')}>{valor}</span>
    </div>
  );
}

function ReformaItem({ titulo, texto }: { titulo: string; texto: string }) {
  return (
    <div className="rounded-xl border border-line p-4">
      <p className="text-[13px] font-semibold text-ink">{titulo}</p>
      <p className="mt-1 text-[12.5px] leading-snug text-ink-muted">{texto}</p>
    </div>
  );
}
