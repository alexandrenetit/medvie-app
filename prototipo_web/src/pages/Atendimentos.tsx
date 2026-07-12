import { useMemo, useState } from 'react';
import {
  Search,
  Plus,
  Filter,
  Repeat,
  Send,
  FileText,
  Stethoscope,
  User,
  Building2,
  ArrowUpDown,
} from 'lucide-react';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Input, Select } from '@/components/ui/Field';
import { StatusChip } from '@/components/ui/StatusChip';
import { Drawer } from '@/components/ui/Drawer';
import { Tabs } from '@/components/ui/Tabs';
import { EmptyState } from '@/components/ui/EmptyState';
import { useAppState } from '@/context/AppState';
import { atendimentos } from '@/data/mock';
import { money, dataBR, dataCurta } from '@/lib/format';
import { statusServicoMeta, tipoServicoMeta } from '@/data/domain';
import type { Atendimento, StatusServico, TipoServico } from '@/types';

const statusTabs: { id: StatusServico | 'todos'; label: string }[] = [
  { id: 'todos', label: 'Todos' },
  { id: 'pendente', label: 'Pendentes' },
  { id: 'nfEmProcessamento', label: 'Processando' },
  { id: 'nfEmitida', label: 'NF emitida' },
  { id: 'aguardandoPagamento', label: 'A receber' },
  { id: 'pago', label: 'Pagos' },
];

export default function Atendimentos() {
  const { setNovoAtendimentoOpen, pushToast } = useAppState();
  const [busca, setBusca] = useState('');
  const [status, setStatus] = useState<StatusServico | 'todos'>('todos');
  const [tipo, setTipo] = useState<TipoServico | 'todos'>('todos');
  const [selecionado, setSelecionado] = useState<Atendimento | null>(null);

  const doMes = useMemo(
    () => atendimentos.filter((a) => a.data.startsWith('2026-07')),
    [],
  );

  const contagem = useMemo(() => {
    const c: Record<string, number> = { todos: doMes.length };
    doMes.forEach((a) => (c[a.status] = (c[a.status] ?? 0) + 1));
    return c;
  }, [doMes]);

  const filtrados = useMemo(() => {
    return doMes
      .filter((a) => (status === 'todos' ? true : a.status === status))
      .filter((a) => (tipo === 'todos' ? true : a.tipo === tipo))
      .filter((a) => (busca ? a.tomadorNome.toLowerCase().includes(busca.toLowerCase()) : true))
      .sort((a, b) => b.data.localeCompare(a.data));
  }, [doMes, status, tipo, busca]);

  const totalFiltrado = filtrados.reduce((s, a) => s + a.valor, 0);

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-brand text-[24px] font-bold text-ink">Atendimentos</h1>
          <p className="mt-0.5 text-[14px] text-ink-muted">
            {doMes.length} registros em julho · {money(doMes.reduce((s, a) => s + a.valor, 0))} produzidos
          </p>
        </div>
        <Button size="sm" className="h-10" onClick={() => setNovoAtendimentoOpen(true)}>
          <Plus size={16} /> Novo atendimento
        </Button>
      </div>

      <Card>
        <div className="flex flex-col gap-3 border-b border-line p-4 sm:flex-row sm:items-center">
          <Tabs
            items={statusTabs.map((t) => ({ id: t.id, label: t.label, count: contagem[t.id] ?? 0 }))}
            value={status}
            onChange={(id) => setStatus(id as StatusServico | 'todos')}
            className="flex-1 border-0"
          />
          <div className="flex items-center gap-2">
            <div className="relative">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint" />
              <Input
                value={busca}
                onChange={(e) => setBusca(e.target.value)}
                placeholder="Buscar tomador…"
                className="h-9 w-44 pl-9 text-[13px]"
              />
            </div>
            <div className="relative">
              <Filter size={14} className="pointer-events-none absolute left-3 top-1/2 z-10 -translate-y-1/2 text-ink-faint" />
              <Select
                value={tipo}
                onChange={(e) => setTipo(e.target.value as TipoServico | 'todos')}
                className="h-9 w-auto min-w-[150px] pl-8 text-[13px]"
              >
                <option value="todos">Todos os serviços</option>
                {(Object.keys(tipoServicoMeta) as TipoServico[]).map((t) => (
                  <option key={t} value={t}>
                    {tipoServicoMeta[t].label}
                  </option>
                ))}
              </Select>
            </div>
          </div>
        </div>

        {filtrados.length === 0 ? (
          <EmptyState
            icon={Stethoscope}
            titulo="Nenhum atendimento encontrado"
            descricao="Ajuste os filtros ou registre um novo atendimento."
            action={
              <Button size="sm" onClick={() => setNovoAtendimentoOpen(true)}>
                <Plus size={15} /> Novo atendimento
              </Button>
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[760px] text-[13.5px]">
              <thead>
                <tr className="border-b border-line text-left text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="px-5 py-3">Tomador</th>
                  <th className="px-3 py-3">Serviço</th>
                  <th className="px-3 py-3">
                    <span className="inline-flex items-center gap-1">
                      Data <ArrowUpDown size={12} />
                    </span>
                  </th>
                  <th className="px-3 py-3 text-right">Valor</th>
                  <th className="px-3 py-3">Situação</th>
                  <th className="px-5 py-3 text-right">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line2">
                {filtrados.map((a) => (
                  <tr
                    key={a.id}
                    onClick={() => setSelecionado(a)}
                    className="cursor-pointer transition-colors hover:bg-line2/40"
                  >
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-2.5">
                        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-canvas text-ink-muted">
                          {a.tomadorTipo === 'cpf' ? <User size={15} /> : <Building2 size={15} />}
                        </span>
                        <div className="min-w-0">
                          <p className="truncate font-medium text-ink">{a.tomadorNome}</p>
                          <p className="num truncate text-[11.5px] text-ink-muted">
                            {a.tomadorDocumento}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-3 py-3 text-ink-soft">{tipoServicoMeta[a.tipo].label}</td>
                    <td className="px-3 py-3 text-ink-muted">{dataCurta(a.data)}</td>
                    <td className="num px-3 py-3 text-right font-semibold text-ink">
                      {money(a.valor)}
                    </td>
                    <td className="px-3 py-3">
                      <StatusChip {...statusServicoMeta[a.status]} />
                    </td>
                    <td className="px-5 py-3">
                      <div className="flex items-center justify-end gap-1">
                        <IconBtn
                          title="Repetir atendimento"
                          onClick={(e) => {
                            e.stopPropagation();
                            pushToast({
                              tipo: 'info',
                              titulo: 'Atendimento duplicado',
                              descricao: `${a.tomadorNome} — ajuste a data e confirme.`,
                            });
                            setNovoAtendimentoOpen(true);
                          }}
                        >
                          <Repeat size={15} />
                        </IconBtn>
                        {a.status === 'pendente' && (
                          <IconBtn
                            title="Emitir NFS-e"
                            onClick={(e) => {
                              e.stopPropagation();
                              pushToast({
                                tipo: 'sucesso',
                                titulo: 'NFS-e em processamento',
                                descricao: `${a.tomadorNome} · ${money(a.valor)}`,
                              });
                            }}
                          >
                            <Send size={15} />
                          </IconBtn>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t border-line bg-canvas/50 text-[13px]">
                  <td className="px-5 py-3 font-semibold text-ink" colSpan={3}>
                    {filtrados.length} atendimento{filtrados.length === 1 ? '' : 's'}
                  </td>
                  <td className="num px-3 py-3 text-right font-bold text-ink">
                    {money(totalFiltrado)}
                  </td>
                  <td colSpan={2} />
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </Card>

      <DetalheAtendimento
        atendimento={selecionado}
        onClose={() => setSelecionado(null)}
        onRepetir={() => {
          setSelecionado(null);
          setNovoAtendimentoOpen(true);
        }}
        onEmitir={(a) => {
          pushToast({
            tipo: 'sucesso',
            titulo: 'NFS-e em processamento',
            descricao: `${a.tomadorNome} · ${money(a.valor)}`,
          });
          setSelecionado(null);
        }}
      />
    </div>
  );
}

function IconBtn({
  children,
  title,
  onClick,
}: {
  children: React.ReactNode;
  title: string;
  onClick: (e: React.MouseEvent) => void;
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      className="grid h-8 w-8 place-items-center rounded-lg text-ink-muted transition-colors hover:bg-line2 hover:text-ink"
    >
      {children}
    </button>
  );
}

function DetalheAtendimento({
  atendimento,
  onClose,
  onRepetir,
  onEmitir,
}: {
  atendimento: Atendimento | null;
  onClose: () => void;
  onRepetir: () => void;
  onEmitir: (a: Atendimento) => void;
}) {
  const a = atendimento;
  return (
    <Drawer
      open={!!a}
      onClose={onClose}
      title={a?.tomadorNome}
      subtitle={a ? tipoServicoMeta[a.tipo].label : undefined}
      footer={
        a && (
          <>
            <Button variant="outline" size="md" className="flex-1" onClick={onRepetir}>
              <Repeat size={16} /> Repetir
            </Button>
            {a.status === 'pendente' ? (
              <Button size="md" className="flex-1" onClick={() => onEmitir(a)}>
                <Send size={16} /> Emitir NFS-e
              </Button>
            ) : (
              <Button variant="outline" size="md" className="flex-1">
                <FileText size={16} /> Ver nota
              </Button>
            )}
          </>
        )
      }
    >
      {a && (
        <div className="space-y-5">
          <div className="rounded-2xl border border-line bg-canvas p-4">
            <p className="text-[12px] text-ink-muted">Valor bruto</p>
            <p className="num mt-1 text-[28px] font-bold text-ink">{money(a.valor)}</p>
            <div className="mt-3 flex items-center justify-between border-t border-line pt-3 text-[13px]">
              <span className="text-ink-muted">Líquido após retenções</span>
              <span className="num font-semibold text-brand-700">{money(a.valorLiquido)}</span>
            </div>
          </div>

          <div>
            <p className="mb-2 text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
              Situação
            </p>
            <StatusChip {...statusServicoMeta[a.status]} />
          </div>

          <dl className="space-y-3 text-[13.5px]">
            <Linha rotulo="Tomador" valor={`${a.tomadorNome} (${a.tomadorTipo === 'cpf' ? 'Paciente' : 'Empresa'})`} />
            <Linha rotulo="Documento" valor={a.tomadorDocumento} mono />
            <Linha rotulo="Data do serviço" valor={dataBR(a.data)} />
            {a.horaInicio && (
              <Linha rotulo="Horário" valor={`${a.horaInicio}${a.horaFim ? `–${a.horaFim}` : ''}`} />
            )}
            <Linha rotulo="Código NBS" valor={tipoServicoMeta[a.tipo].codigoNbs} mono />
            {a.observacao && <Linha rotulo="Observação" valor={a.observacao} />}
          </dl>
        </div>
      )}
    </Drawer>
  );
}

function Linha({ rotulo, valor, mono }: { rotulo: string; valor: string; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <dt className="shrink-0 text-ink-muted">{rotulo}</dt>
      <dd className={`text-right font-medium text-ink ${mono ? 'num' : ''}`}>{valor}</dd>
    </div>
  );
}
