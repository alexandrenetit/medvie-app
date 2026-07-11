import { useMemo, useState } from 'react';
import {
  Bar,
  BarChart,
  Cell,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  FileDown,
  TrendingUp,
  Wallet,
  Receipt,
  PiggyBank,
  Award,
  FileText,
  Eye,
  CheckCircle2,
} from 'lucide-react';
import { Card, CardHeader } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Tabs } from '@/components/ui/Tabs';
import { Select } from '@/components/ui/Field';
import { StatusChip } from '@/components/ui/StatusChip';
import { useAppState } from '@/context/AppState';
import { dashboard, serieAnual, atendimentos, informeRendimentos, medico } from '@/data/mock';
import { money, moneyCompact, nomeMes, nomeMesCurto, dataBR } from '@/lib/format';
import { tipoServicoMeta } from '@/data/domain';

export default function Relatorios() {
  const { cnpjAtivoId, pushToast } = useAppState();
  const cnpj = medico.cnpjs.find((c) => c.id === cnpjAtivoId) ?? medico.cnpjs[0];
  const [aba, setAba] = useState('mensal');

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-brand text-[24px] font-bold text-ink">Relatórios</h1>
          <p className="mt-0.5 text-[14px] text-ink-muted">
            Fechamentos, evolução anual e informe de rendimentos — prontos para o contador.
          </p>
        </div>
        <Button
          size="sm"
          className="h-10"
          onClick={() =>
            pushToast({ tipo: 'sucesso', titulo: 'Relatório gerado', descricao: 'PDF pronto para download.' })
          }
        >
          <FileDown size={16} /> Exportar PDF
        </Button>
      </div>

      <Tabs
        items={[
          { id: 'mensal', label: 'Fechamento mensal' },
          { id: 'anual', label: 'Resumo anual' },
          { id: 'informe', label: 'Informe de rendimentos' },
        ]}
        value={aba}
        onChange={setAba}
      />

      {aba === 'mensal' && <FechamentoMensal regime={cnpj.regime} />}
      {aba === 'anual' && <ResumoAnual />}
      {aba === 'informe' && <Informe onDownload={() => pushToast({ tipo: 'sucesso', titulo: 'Download iniciado', descricao: 'informe-2025.pdf' })} />}
    </div>
  );
}

// ── Fechamento mensal ────────────────────────────────────────────────────────
function FechamentoMensal({ regime }: { regime: string }) {
  const { carga } = dashboard;
  const breakdown = [
    { label: 'IRPJ', valor: carga.irpj },
    { label: 'CSLL', valor: carga.csll },
    { label: 'COFINS', valor: carga.cofins },
    { label: 'ISS', valor: carga.iss },
    { label: 'IBS', valor: carga.ibs },
    { label: 'CBS', valor: carga.cbs },
    { label: 'PIS', valor: carga.pis },
  ].sort((a, b) => b.valor - a.valor);
  const maxImposto = breakdown[0].valor;

  const servicos = atendimentos.filter((a) => a.data.startsWith('2026-07') && a.status !== 'cancelado');

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
      <div className="space-y-5">
        <div className="grid gap-4 sm:grid-cols-3">
          <ResumoCard icon={Wallet} label="Total bruto" valor={money(dashboard.totalBruto)} tone="ink" />
          <ResumoCard icon={Receipt} label="Impostos" valor={money(dashboard.totalImpostos)} tone="warn" />
          <ResumoCard icon={PiggyBank} label="Líquido" valor={money(dashboard.totalLiquidoEstimado)} tone="brand" />
        </div>

        <Card>
          <CardHeader title="Serviços do mês" subtitle={`${servicos.length} atendimentos · julho 2026`} />
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-[13.5px]">
              <thead>
                <tr className="border-y border-line text-left text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="px-5 py-2.5">Tomador</th>
                  <th className="px-3 py-2.5">Serviço</th>
                  <th className="px-3 py-2.5 text-right">Bruto</th>
                  <th className="px-5 py-2.5 text-right">Líquido</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line2">
                {servicos.map((s) => (
                  <tr key={s.id} className="hover:bg-line2/40">
                    <td className="px-5 py-2.5 font-medium text-ink">{s.tomadorNome}</td>
                    <td className="px-3 py-2.5 text-ink-soft">{tipoServicoMeta[s.tipo].label}</td>
                    <td className="num px-3 py-2.5 text-right text-ink">{money(s.valor)}</td>
                    <td className="num px-5 py-2.5 text-right font-semibold text-brand-700">
                      {money(s.valorLiquido)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>

      <Card className="h-fit">
        <CardHeader title="Composição tributária" subtitle={carga.regimeDescricao} icon={<Receipt size={18} />} />
        <div className="space-y-3 p-5">
          {breakdown.map((b) => (
            <div key={b.label}>
              <div className="mb-1 flex items-center justify-between text-[13px]">
                <span className="font-medium text-ink-soft">{b.label}</span>
                <span className="num font-semibold text-ink">{money(b.valor)}</span>
              </div>
              <div className="h-1.5 w-full overflow-hidden rounded-full bg-line2">
                <div
                  className="h-full rounded-full bg-warn-500"
                  style={{ width: `${(b.valor / maxImposto) * 100}%` }}
                />
              </div>
            </div>
          ))}
          <div className="mt-4 flex items-center justify-between border-t border-line pt-4">
            <div>
              <p className="text-[12px] text-ink-muted">Total de impostos</p>
              <p className="num text-[20px] font-bold text-ink">{money(carga.totalImpostos)}</p>
            </div>
            <div className="text-right">
              <p className="text-[12px] text-ink-muted">Alíquota efetiva</p>
              <p className="num text-[20px] font-bold text-warn-600">
                {(carga.aliquotaEfetiva * 100).toFixed(1)}%
              </p>
            </div>
          </div>
          <p className="text-[11.5px] leading-snug text-ink-faint">
            Regime {regime === 'lucroPresumido' ? 'Lucro Presumido' : 'Simples Nacional'}. Cálculo de
            referência do backend Medvie (IBS/CBS já na reforma tributária).
          </p>
        </div>
      </Card>
    </div>
  );
}

// ── Resumo anual ─────────────────────────────────────────────────────────────
function ResumoAnual() {
  const dados = useMemo(
    () =>
      serieAnual.map((s) => ({
        mes: nomeMesCurto(s.mesIndex),
        bruto: s.bruto,
        ativo: s.bruto > 0,
      })),
    [],
  );
  const comMovimento = serieAnual.filter((s) => s.bruto > 0);
  const totalBruto = comMovimento.reduce((s, m) => s + m.bruto, 0);
  const totalLiquido = comMovimento.reduce((s, m) => s + m.liquido, 0);
  const totalImpostos = comMovimento.reduce((s, m) => s + m.impostos, 0);
  const media = totalBruto / comMovimento.length;
  const melhor = comMovimento.reduce((a, b) => (b.bruto > a.bruto ? b : a));

  return (
    <div className="space-y-5">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <ResumoCard icon={Wallet} label="Bruto acumulado" valor={money(totalBruto)} tone="ink" />
        <ResumoCard icon={TrendingUp} label="Média mensal" valor={money(media)} tone="info" />
        <ResumoCard
          icon={Award}
          label={`Melhor mês · ${nomeMes(melhor.mesIndex)}`}
          valor={money(melhor.bruto)}
          tone="brand"
        />
        <ResumoCard icon={Receipt} label="Impostos acumulados" valor={money(totalImpostos)} tone="warn" />
      </div>

      <Card>
        <CardHeader
          title="Faturamento mês a mês"
          subtitle={`2026 · líquido acumulado ${money(totalLiquido)}`}
          icon={<TrendingUp size={18} />}
        />
        <div className="h-72 px-3 pb-4 pt-4">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={dados} margin={{ top: 8, right: 12, left: 6, bottom: 0 }}>
              <CartesianGrid vertical={false} stroke="#EEF1F5" />
              <XAxis dataKey="mes" axisLine={false} tickLine={false} tick={{ fill: '#64748B', fontSize: 12 }} />
              <YAxis
                axisLine={false}
                tickLine={false}
                width={56}
                tick={{ fill: '#94A3B8', fontSize: 11 }}
                tickFormatter={(v) => moneyCompact(Number(v))}
              />
              <Tooltip
                cursor={{ fill: 'rgba(11,184,132,0.06)' }}
                content={({ active, payload, label }) =>
                  active && payload?.length ? (
                    <div className="rounded-xl border border-line bg-card px-3 py-2 shadow-pop">
                      <p className="text-[12px] font-semibold text-ink">{label}</p>
                      <p className="num text-[13px] font-bold text-brand-700">
                        {money(Number(payload[0].value))}
                      </p>
                    </div>
                  ) : null
                }
              />
              <Bar dataKey="bruto" radius={[6, 6, 0, 0]} maxBarSize={44}>
                {dados.map((d, i) => (
                  <Cell key={i} fill={d.ativo ? '#0BB884' : '#E6E9EF'} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </Card>
    </div>
  );
}

// ── Informe de rendimentos ───────────────────────────────────────────────────
function Informe({ onDownload }: { onDownload: () => void }) {
  const [ano, setAno] = useState('2025');
  const info = informeRendimentos;

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px]">
      <Card>
        <CardHeader
          title="Informe de rendimentos"
          subtitle="Documento anual para a declaração de imposto de renda"
          icon={<FileText size={18} />}
          action={
            <Select value={ano} onChange={(e) => setAno(e.target.value)} className="h-9 w-28 text-[13px]">
              <option value="2025">2025</option>
              <option value="2024">2024</option>
              <option value="2023">2023</option>
            </Select>
          }
        />
        <div className="grid gap-4 p-5 sm:grid-cols-2">
          <ResumoCard icon={Wallet} label="Total recebido" valor={money(info.totalRecebido)} tone="brand" />
          <ResumoCard icon={Receipt} label="Impostos retidos" valor={money(info.impostosRetidos)} tone="warn" />
        </div>
        <div className="border-t border-line px-5 py-4">
          <p className="text-[13px] text-ink-muted">
            Ano-base <span className="font-semibold text-ink">{ano}</span> · emitido em{' '}
            {dataBR(info.emitidoEm)}. Contém todos os rendimentos e retenções declarados pelas suas
            empresas no período.
          </p>
        </div>
      </Card>

      <Card className="flex flex-col p-5">
        <div className="flex items-center gap-2 text-brand-700">
          <CheckCircle2 size={18} />
          <StatusChip label="Disponível" tone="brand" />
        </div>
        <p className="mt-4 font-brand text-[18px] font-semibold text-ink">
          Informe {ano} pronto
        </p>
        <p className="mt-1 text-[13.5px] text-ink-muted">
          Baixe o PDF assinado ou visualize antes de enviar ao seu contador.
        </p>
        <div className="mt-auto space-y-2 pt-6">
          <Button variant="outline" size="md" className="w-full">
            <Eye size={16} /> Visualizar
          </Button>
          <Button size="md" className="w-full" onClick={onDownload}>
            <FileDown size={16} /> Baixar informe {ano}
          </Button>
        </div>
      </Card>
    </div>
  );
}

// ── auxiliar ─────────────────────────────────────────────────────────────────
function ResumoCard({
  icon: Icon,
  label,
  valor,
  tone,
}: {
  icon: typeof Wallet;
  label: string;
  valor: string;
  tone: 'ink' | 'brand' | 'warn' | 'info';
}) {
  const toneColor = {
    ink: 'text-ink-muted',
    brand: 'text-brand-600',
    warn: 'text-warn-500',
    info: 'text-info-500',
  }[tone];
  return (
    <Card className="p-4">
      <div className="flex items-center gap-2">
        <Icon size={15} className={toneColor} />
        <span className="text-[12.5px] font-medium text-ink-muted">{label}</span>
      </div>
      <p className="num mt-2 text-[22px] font-bold text-ink">{valor}</p>
    </Card>
  );
}
