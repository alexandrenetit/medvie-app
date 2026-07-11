import { useNavigate } from 'react-router-dom';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  Wallet,
  Receipt,
  TrendingUp,
  AlertTriangle,
  FileWarning,
  ShieldAlert,
  Send,
  Plus,
  Calculator,
  FileDown,
  ChevronRight,
  CircleDollarSign,
  Clock3,
} from 'lucide-react';
import { Card, CardHeader } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { ProgressBar, Delta } from '@/components/ui/Progress';
import { StatusChip } from '@/components/ui/StatusChip';
import { useAppState } from '@/context/AppState';
import {
  dashboard,
  serieAnual,
  medico,
  notas,
  atendimentos,
} from '@/data/mock';
import { money, moneyCompact, nomeMesCurto, nomeMes, saudacao, dataCurta } from '@/lib/format';
import { statusNotaMeta, tipoServicoMeta } from '@/data/domain';

export default function Overview() {
  const navigate = useNavigate();
  const { cnpjAtivoId, competencia, setNovoAtendimentoOpen, pushToast } = useAppState();
  const cnpj = medico.cnpjs.find((c) => c.id === cnpjAtivoId) ?? medico.cnpjs[0];
  const primeiroNome = medico.nome.replace('Dr. ', '').split(' ')[0];
  const [, mes] = competencia.split('-').map(Number);

  const chartData = serieAnual
    .filter((s) => s.bruto > 0)
    .map((s) => ({ mes: nomeMesCurto(s.mesIndex), bruto: s.bruto, liquido: s.liquido }));

  const metaPct = (dashboard.totalBruto / dashboard.metaMensal) * 100;
  const notasRecentes = notas.slice(0, 5);
  const proximos = atendimentos
    .filter((a) => a.status === 'pendente')
    .slice(0, 3);

  const pendencias = [
    {
      icon: FileWarning,
      tone: 'danger' as const,
      titulo: '1 nota rejeitada',
      texto: 'Ato anestésico · Unimed Campinas — endereço fiscal incompleto.',
      cta: 'Resolver',
      onClick: () => navigate('/notas'),
    },
    {
      icon: ShieldAlert,
      tone: 'warn' as const,
      titulo: 'Certificado vence em 18 dias',
      texto: 'RAL Anestesia e Dor (Simples Nacional) — renove para não travar emissões.',
      cta: 'Renovar',
      onClick: () => navigate('/perfil'),
    },
    {
      icon: Send,
      tone: 'info' as const,
      titulo: '3 atendimentos prontos para emitir',
      texto: `${money(dashboard.aguardandoEmissao)} aguardando emissão de NFS-e.`,
      cta: 'Emitir',
      onClick: () =>
        pushToast({
          tipo: 'info',
          titulo: 'Emissão em lote',
          descricao: '3 NFS-e enviadas para processamento automático.',
        }),
    },
  ];

  return (
    <div className="space-y-6">
      {/* Cabeçalho */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="font-brand text-[26px] font-bold leading-tight text-ink">
            {saudacao()}, Dr. {primeiroNome}.
          </h1>
          <p className="mt-1 text-[14.5px] text-ink-muted">
            Aqui está o resumo de{' '}
            <span className="font-medium text-ink-soft">{nomeMes(mes - 1)}</span> em{' '}
            <span className="font-medium text-ink-soft">{cnpj.nomeFantasia}</span>.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => navigate('/relatorios')}>
            <FileDown size={16} /> Fechamento
          </Button>
          <Button size="sm" onClick={() => setNovoAtendimentoOpen(true)}>
            <Plus size={16} /> Novo atendimento
          </Button>
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,2.15fr)_minmax(0,1fr)]">
        {/* Coluna principal */}
        <div className="space-y-6">
          {/* Hero financeiro */}
          <Card className="overflow-hidden">
            <div className="grid gap-px bg-line md:grid-cols-[1.25fr_1fr]">
              {/* Líquido — número herói */}
              <div className="relative bg-card p-6">
                <div
                  className="pointer-events-none absolute -right-8 -top-10 h-40 w-40 rounded-full opacity-[0.07]"
                  style={{ background: 'radial-gradient(circle, #0BB884, transparent 70%)' }}
                />
                <div className="flex items-center gap-2 text-ink-muted">
                  <TrendingUp size={16} className="text-brand-600" />
                  <span className="text-[13px] font-medium">Líquido estimado no mês</span>
                </div>
                <div className="mt-3 flex items-end gap-3">
                  <p className="num text-[40px] font-bold leading-none text-ink">
                    {money(dashboard.totalLiquidoEstimado)}
                  </p>
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <Delta fraction={dashboard.variacaoLiquido} />
                  <span className="text-[13px] text-ink-muted">
                    vs {money(dashboard.liquidoMesAnterior)} em junho
                  </span>
                </div>

                <div className="mt-6">
                  <div className="mb-1.5 flex items-center justify-between text-[12.5px]">
                    <span className="text-ink-muted">Meta mensal</span>
                    <span className="num font-semibold text-ink">
                      {money(dashboard.totalBruto)}{' '}
                      <span className="font-normal text-ink-muted">
                        / {moneyCompact(dashboard.metaMensal)}
                      </span>
                    </span>
                  </div>
                  <ProgressBar value={dashboard.totalBruto} max={dashboard.metaMensal} />
                  <p className="mt-1.5 text-[12px] text-ink-muted">
                    {metaPct.toFixed(0)}% da meta — faltam{' '}
                    {money(dashboard.metaMensal - dashboard.totalBruto)}.
                  </p>
                </div>
              </div>

              {/* Bruto / impostos */}
              <div className="grid grid-rows-2 bg-card">
                <MiniMetric
                  icon={Wallet}
                  label="Total bruto produzido"
                  valor={money(dashboard.totalBruto)}
                  sub={`${dashboard.pipeline.recebido.quantidade + dashboard.pipeline.aReceber.quantidade + dashboard.pipeline.aguardandoEmissao.quantidade} atendimentos`}
                  border
                />
                <MiniMetric
                  icon={Receipt}
                  label="Impostos estimados"
                  valor={money(dashboard.totalImpostos)}
                  sub={`Alíquota efetiva ${(dashboard.carga.aliquotaEfetiva * 100).toFixed(1)}% · ${cnpj.regime === 'lucroPresumido' ? 'Lucro Presumido' : 'Simples Nacional'}`}
                  tone="warn"
                />
              </div>
            </div>
          </Card>

          {/* Pipeline financeiro */}
          <Card>
            <CardHeader
              title="Pipeline do dinheiro"
              subtitle="Como o faturamento do mês está distribuído"
              icon={<CircleDollarSign size={18} />}
              action={
                <span className="text-[12px] text-ink-muted">
                  Previsão de recebimento · {dataCurta(dashboard.pipeline.dataPrevista)}
                </span>
              }
            />
            <div className="px-5 pb-5 pt-4">
              <PipelineBar />
              <div className="mt-5 grid grid-cols-3 gap-3">
                <PipelineLegenda
                  cor="bg-brand-500"
                  label="Recebido"
                  valor={dashboard.recebido}
                  qtd={dashboard.pipeline.recebido.quantidade}
                />
                <PipelineLegenda
                  cor="bg-orange-500"
                  label="A receber"
                  valor={dashboard.aReceber}
                  qtd={dashboard.pipeline.aReceber.quantidade}
                />
                <PipelineLegenda
                  cor="bg-warn-500"
                  label="Aguardando emissão"
                  valor={dashboard.aguardandoEmissao}
                  qtd={dashboard.pipeline.aguardandoEmissao.quantidade}
                />
              </div>
            </div>
          </Card>

          {/* Evolução mensal */}
          <Card>
            <CardHeader
              title="Evolução mensal"
              subtitle="Bruto e líquido nos últimos meses"
              icon={<TrendingUp size={18} />}
              action={
                <Button variant="ghost" size="sm" onClick={() => navigate('/relatorios')}>
                  Ver anual <ChevronRight size={15} />
                </Button>
              }
            />
            <div className="h-64 px-2 pb-3 pt-4">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData} margin={{ top: 6, right: 16, left: 6, bottom: 0 }}>
                  <defs>
                    <linearGradient id="gBruto" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#0BB884" stopOpacity={0.22} />
                      <stop offset="100%" stopColor="#0BB884" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="gLiq" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#2E8FE6" stopOpacity={0.16} />
                      <stop offset="100%" stopColor="#2E8FE6" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid vertical={false} stroke="#EEF1F5" />
                  <XAxis
                    dataKey="mes"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: '#64748B', fontSize: 12 }}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    width={54}
                    tick={{ fill: '#94A3B8', fontSize: 11 }}
                    tickFormatter={(v) => moneyCompact(Number(v))}
                  />
                  <Tooltip content={<ChartTooltip />} />
                  <Area
                    type="monotone"
                    dataKey="bruto"
                    name="Bruto"
                    stroke="#0BB884"
                    strokeWidth={2.5}
                    fill="url(#gBruto)"
                  />
                  <Area
                    type="monotone"
                    dataKey="liquido"
                    name="Líquido"
                    stroke="#2E8FE6"
                    strokeWidth={2.5}
                    fill="url(#gLiq)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </Card>
        </div>

        {/* Coluna lateral */}
        <div className="space-y-6">
          {/* Atenção */}
          <Card>
            <CardHeader
              title="Precisa da sua atenção"
              icon={<AlertTriangle size={18} className="text-warn-500" />}
            />
            <div className="space-y-2 p-3">
              {pendencias.map((p) => (
                <button
                  key={p.titulo}
                  onClick={p.onClick}
                  className="flex w-full items-start gap-3 rounded-xl border border-line p-3 text-left transition-colors hover:bg-line2/50"
                >
                  <span
                    className={`mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-lg ${
                      p.tone === 'danger'
                        ? 'bg-danger-50 text-danger-600'
                        : p.tone === 'warn'
                          ? 'bg-warn-50 text-warn-600'
                          : 'bg-info-50 text-info-600'
                    }`}
                  >
                    <p.icon size={16} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-[13.5px] font-semibold text-ink">{p.titulo}</span>
                    <span className="mt-0.5 block text-[12.5px] leading-snug text-ink-muted">
                      {p.texto}
                    </span>
                  </span>
                  <span className="mt-0.5 shrink-0 text-[12.5px] font-semibold text-brand-600">
                    {p.cta}
                  </span>
                </button>
              ))}
            </div>
          </Card>

          {/* Próximos atendimentos */}
          <Card>
            <CardHeader
              title="Próximos atendimentos"
              icon={<Clock3 size={18} />}
              action={
                <Button variant="ghost" size="sm" onClick={() => navigate('/agenda')}>
                  Agenda
                </Button>
              }
            />
            <div className="divide-y divide-line2">
              {proximos.map((a) => (
                <div key={a.id} className="flex items-center gap-3 px-5 py-3">
                  <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-canvas text-center">
                    <span className="text-[15px] font-bold leading-none text-ink">
                      {new Date(a.data).getUTCDate()}
                    </span>
                    <span className="text-[9px] uppercase text-ink-muted">
                      {nomeMesCurto(new Date(a.data).getUTCMonth())}
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13.5px] font-semibold text-ink">{a.tomadorNome}</p>
                    <p className="truncate text-[12px] text-ink-muted">
                      {tipoServicoMeta[a.tipo].label}
                      {a.horaInicio && ` · ${a.horaInicio}`}
                    </p>
                  </div>
                  <span className="num text-[13.5px] font-semibold text-ink">{money(a.valor)}</span>
                </div>
              ))}
            </div>
          </Card>

          {/* Ações rápidas */}
          <Card>
            <CardHeader title="Ações rápidas" />
            <div className="grid grid-cols-2 gap-2 p-3">
              <AcaoRapida icon={Plus} label="Novo atendimento" onClick={() => setNovoAtendimentoOpen(true)} />
              <AcaoRapida icon={Calculator} label="Simular honorário" onClick={() => navigate('/simulador')} />
              <AcaoRapida icon={FileDown} label="Fechamento mensal" onClick={() => navigate('/relatorios')} />
              <AcaoRapida icon={Send} label="Emitir pendentes" onClick={() => navigate('/atendimentos')} />
            </div>
          </Card>
        </div>
      </div>

      {/* Notas recentes */}
      <Card>
        <CardHeader
          title="Notas recentes"
          subtitle="Últimas emissões e processamentos"
          icon={<Receipt size={18} />}
          action={
            <Button variant="ghost" size="sm" onClick={() => navigate('/notas')}>
              Ver todas <ChevronRight size={15} />
            </Button>
          }
        />
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] text-[13.5px]">
            <thead>
              <tr className="border-y border-line text-left text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
                <th className="px-5 py-2.5 font-semibold">Tomador</th>
                <th className="px-3 py-2.5 font-semibold">Serviço</th>
                <th className="px-3 py-2.5 font-semibold">Data</th>
                <th className="px-3 py-2.5 text-right font-semibold">Valor</th>
                <th className="px-5 py-2.5 font-semibold">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line2">
              {notasRecentes.map((n) => (
                <tr key={n.id} className="transition-colors hover:bg-line2/40">
                  <td className="px-5 py-3 font-medium text-ink">{n.tomadorNome}</td>
                  <td className="px-3 py-3 text-ink-soft">{tipoServicoMeta[n.tipoServico].label}</td>
                  <td className="px-3 py-3 text-ink-muted">{dataCurta(n.dataServico)}</td>
                  <td className="num px-3 py-3 text-right font-semibold text-ink">
                    {money(n.valorBruto)}
                  </td>
                  <td className="px-5 py-3">
                    <StatusChip {...statusNotaMeta[n.status]} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}

// ── auxiliares ────────────────────────────────────────────────────────────────
function MiniMetric({
  icon: Icon,
  label,
  valor,
  sub,
  border,
  tone,
}: {
  icon: typeof Wallet;
  label: string;
  valor: string;
  sub: string;
  border?: boolean;
  tone?: 'warn';
}) {
  return (
    <div className={`p-5 ${border ? 'border-b border-line' : ''}`}>
      <div className="flex items-center gap-2 text-ink-muted">
        <Icon size={15} className={tone === 'warn' ? 'text-warn-500' : 'text-ink-muted'} />
        <span className="text-[12.5px] font-medium">{label}</span>
      </div>
      <p className="num mt-2 text-[24px] font-bold leading-none text-ink">{valor}</p>
      <p className="mt-1.5 text-[12px] text-ink-muted">{sub}</p>
    </div>
  );
}

function PipelineBar() {
  const { recebido, aReceber, aguardandoEmissao } = dashboard;
  const total = recebido + aReceber + aguardandoEmissao;
  const seg = (v: number) => `${(v / total) * 100}%`;
  return (
    <div className="flex h-3.5 w-full overflow-hidden rounded-full">
      <div className="bg-brand-500" style={{ width: seg(recebido) }} />
      <div className="bg-orange-500" style={{ width: seg(aReceber) }} />
      <div className="bg-warn-500" style={{ width: seg(aguardandoEmissao) }} />
    </div>
  );
}

function PipelineLegenda({
  cor,
  label,
  valor,
  qtd,
}: {
  cor: string;
  label: string;
  valor: number;
  qtd: number;
}) {
  return (
    <div>
      <div className="flex items-center gap-1.5">
        <span className={`h-2.5 w-2.5 rounded-full ${cor}`} />
        <span className="text-[12.5px] font-medium text-ink-soft">{label}</span>
      </div>
      <p className="num mt-1 text-[16px] font-bold text-ink">{money(valor)}</p>
      <p className="text-[11.5px] text-ink-muted">{qtd} atendimentos</p>
    </div>
  );
}

function AcaoRapida({
  icon: Icon,
  label,
  onClick,
}: {
  icon: typeof Plus;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="group flex flex-col items-start gap-2 rounded-xl border border-line p-3.5 text-left transition-all hover:border-brand-300 hover:bg-brand-50/40"
    >
      <span className="grid h-9 w-9 place-items-center rounded-lg bg-canvas text-ink-soft transition-colors group-hover:bg-brand-100 group-hover:text-brand-700">
        <Icon size={17} />
      </span>
      <span className="text-[13px] font-semibold text-ink">{label}</span>
    </button>
  );
}

interface TipPayload {
  name: string;
  value: number;
  color: string;
}
function ChartTooltip({ active, payload, label }: { active?: boolean; payload?: TipPayload[]; label?: string }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-line bg-card px-3 py-2 shadow-pop">
      <p className="mb-1 text-[12px] font-semibold text-ink">{label}</p>
      {payload.map((p) => (
        <div key={p.name} className="flex items-center gap-2 text-[12.5px]">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          <span className="text-ink-muted">{p.name}</span>
          <span className="num ml-auto font-semibold text-ink">{money(p.value)}</span>
        </div>
      ))}
    </div>
  );
}
