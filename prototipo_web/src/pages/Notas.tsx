import { useMemo, useState } from 'react';
import {
  Search,
  FileText,
  Download,
  RefreshCw,
  Eye,
  AlertOctagon,
  CheckCircle2,
  Clock,
  Send,
  XCircle,
  User,
  Building2,
} from 'lucide-react';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Field';
import { StatusChip } from '@/components/ui/StatusChip';
import { Drawer } from '@/components/ui/Drawer';
import { Tabs } from '@/components/ui/Tabs';
import { EmptyState } from '@/components/ui/EmptyState';
import { useAppState } from '@/context/AppState';
import { notas } from '@/data/mock';
import { money, dataBR, dataCurta } from '@/lib/format';
import { statusNotaMeta, tipoServicoMeta } from '@/data/domain';
import type { NotaFiscal, StatusNota } from '@/types';

const tabs: { id: StatusNota | 'todos'; label: string }[] = [
  { id: 'todos', label: 'Todas' },
  { id: 'autorizada', label: 'Autorizadas' },
  { id: 'emProcessamento', label: 'Processando' },
  { id: 'rejeitada', label: 'Rejeitadas' },
  { id: 'cancelada', label: 'Canceladas' },
];

export default function Notas() {
  const { setNovoAtendimentoOpen, pushToast } = useAppState();
  const [status, setStatus] = useState<StatusNota | 'todos'>('todos');
  const [busca, setBusca] = useState('');
  const [sel, setSel] = useState<NotaFiscal | null>(null);

  const contagem = useMemo(() => {
    const c: Record<string, number> = { todos: notas.length };
    notas.forEach((n) => (c[n.status] = (c[n.status] ?? 0) + 1));
    return c;
  }, []);

  const rejeitadas = notas.filter((n) => n.status === 'rejeitada');

  const filtradas = useMemo(
    () =>
      notas
        .filter((n) => (status === 'todos' ? true : n.status === status))
        .filter((n) => (busca ? n.tomadorNome.toLowerCase().includes(busca.toLowerCase()) : true))
        .sort((a, b) => b.dataServico.localeCompare(a.dataServico)),
    [status, busca],
  );

  function reenviar(n: NotaFiscal) {
    pushToast({
      tipo: 'info',
      titulo: 'Nota reenviada',
      descricao: `${n.tomadorNome} — nova tentativa de autorização em andamento.`,
    });
    setSel(null);
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-brand text-[24px] font-bold text-ink">Notas fiscais</h1>
          <p className="mt-0.5 text-[14px] text-ink-muted">
            {notas.length} NFS-e no período · {money(notas.reduce((s, n) => s + n.valorBruto, 0))}
          </p>
        </div>
        <Button size="sm" className="h-10" onClick={() => setNovoAtendimentoOpen(true)}>
          <Send size={16} /> Emitir nota
        </Button>
      </div>

      {/* Pendência prioritária */}
      {rejeitadas.length > 0 && (
        <div className="flex flex-col gap-3 rounded-2xl border border-danger-100 bg-danger-50/50 p-4 sm:flex-row sm:items-center">
          <div className="flex items-start gap-3">
            <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-danger-100 text-danger-600">
              <AlertOctagon size={20} />
            </span>
            <div>
              <p className="text-[14px] font-semibold text-ink">
                {rejeitadas.length} nota rejeitada precisa de ação
              </p>
              <p className="text-[13px] text-ink-muted">
                {rejeitadas[0].tomadorNome} — {rejeitadas[0].motivoRejeicao}
              </p>
            </div>
          </div>
          <div className="sm:ml-auto">
            <Button size="sm" variant="danger" onClick={() => setSel(rejeitadas[0])}>
              Resolver agora
            </Button>
          </div>
        </div>
      )}

      <Card>
        <div className="flex flex-col gap-3 border-b border-line p-4 sm:flex-row sm:items-center">
          <Tabs
            items={tabs.map((t) => ({ id: t.id, label: t.label, count: contagem[t.id] ?? 0 }))}
            value={status}
            onChange={(id) => setStatus(id as StatusNota | 'todos')}
            className="flex-1 border-0"
          />
          <div className="relative">
            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint" />
            <Input
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
              placeholder="Buscar tomador ou nº…"
              className="h-9 w-56 pl-9 text-[13px]"
            />
          </div>
        </div>

        {filtradas.length === 0 ? (
          <EmptyState
            icon={FileText}
            titulo="Nenhuma nota neste filtro"
            descricao="Assim que emitir atendimentos, as NFS-e aparecem aqui."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[780px] text-[13.5px]">
              <thead>
                <tr className="border-b border-line text-left text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="px-5 py-3">Nº / Tomador</th>
                  <th className="px-3 py-3">Serviço</th>
                  <th className="px-3 py-3">Emissão</th>
                  <th className="px-3 py-3 text-right">Valor</th>
                  <th className="px-3 py-3">Status</th>
                  <th className="px-5 py-3 text-right">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line2">
                {filtradas.map((n) => (
                  <tr
                    key={n.id}
                    onClick={() => setSel(n)}
                    className="cursor-pointer transition-colors hover:bg-line2/40"
                  >
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-2.5">
                        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-canvas text-ink-muted">
                          {n.tomadorTipo === 'cpf' ? <User size={15} /> : <Building2 size={15} />}
                        </span>
                        <div className="min-w-0">
                          <p className="truncate font-medium text-ink">{n.tomadorNome}</p>
                          <p className="num truncate text-[11.5px] text-ink-muted">
                            {n.numero ? `NFS-e ${n.numero}` : 'Sem número'}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-3 py-3 text-ink-soft">{tipoServicoMeta[n.tipoServico].label}</td>
                    <td className="px-3 py-3 text-ink-muted">
                      {n.dataEmissao ? dataCurta(n.dataEmissao) : '—'}
                    </td>
                    <td className="num px-3 py-3 text-right font-semibold text-ink">
                      {money(n.valorBruto)}
                    </td>
                    <td className="px-3 py-3">
                      <StatusChip {...statusNotaMeta[n.status]} />
                    </td>
                    <td className="px-5 py-3">
                      <div className="flex items-center justify-end gap-1">
                        {n.status === 'autorizada' && (
                          <>
                            <IconBtn title="Visualizar PDF" onClick={(e) => { e.stopPropagation(); setSel(n); }}>
                              <Eye size={15} />
                            </IconBtn>
                            <IconBtn
                              title="Baixar DANFSe"
                              onClick={(e) => {
                                e.stopPropagation();
                                pushToast({ tipo: 'sucesso', titulo: 'Download iniciado', descricao: `NFS-e ${n.numero}.pdf` });
                              }}
                            >
                              <Download size={15} />
                            </IconBtn>
                          </>
                        )}
                        {n.status === 'rejeitada' && (
                          <IconBtn
                            title="Reenviar"
                            onClick={(e) => {
                              e.stopPropagation();
                              reenviar(n);
                            }}
                          >
                            <RefreshCw size={15} />
                          </IconBtn>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <DetalheNota nota={sel} onClose={() => setSel(null)} onReenviar={reenviar} onDownload={(n) => pushToast({ tipo: 'sucesso', titulo: 'Download iniciado', descricao: `NFS-e ${n.numero}.pdf` })} />
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

interface TimelineStep {
  label: string;
  quando: string;
  estado: 'ok' | 'erro' | 'atual' | 'espera';
}

function DetalheNota({
  nota,
  onClose,
  onReenviar,
  onDownload,
}: {
  nota: NotaFiscal | null;
  onClose: () => void;
  onReenviar: (n: NotaFiscal) => void;
  onDownload: (n: NotaFiscal) => void;
}) {
  const n = nota;
  const timeline = n ? buildTimeline(n) : [];
  return (
    <Drawer
      open={!!n}
      onClose={onClose}
      width={480}
      title={n ? (n.numero ? `NFS-e ${n.numero}` : 'NFS-e em processamento') : undefined}
      subtitle={n?.tomadorNome}
      footer={
        n && (
          <>
            {n.status === 'rejeitada' ? (
              <Button size="md" className="flex-1" onClick={() => onReenviar(n)}>
                <RefreshCw size={16} /> Reenviar nota
              </Button>
            ) : n.status === 'autorizada' ? (
              <>
                <Button variant="outline" size="md" className="flex-1">
                  <Eye size={16} /> Ver PDF
                </Button>
                <Button size="md" className="flex-1" onClick={() => onDownload(n)}>
                  <Download size={16} /> Baixar
                </Button>
              </>
            ) : (
              <Button variant="outline" size="md" className="flex-1" disabled>
                <Clock size={16} /> Aguardando autorização
              </Button>
            )}
          </>
        )
      }
    >
      {n && (
        <div className="space-y-5">
          {n.status === 'rejeitada' && (
            <div className="rounded-xl border border-danger-100 bg-danger-50/60 p-3.5">
              <p className="flex items-center gap-2 text-[13px] font-semibold text-danger-700">
                <AlertOctagon size={16} /> Motivo da rejeição
              </p>
              <p className="mt-1 text-[13px] text-ink-soft">{n.motivoRejeicao}</p>
            </div>
          )}

          <div className="rounded-2xl border border-line bg-canvas p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[12px] text-ink-muted">Valor bruto</p>
                <p className="num mt-0.5 text-[24px] font-bold text-ink">{money(n.valorBruto)}</p>
              </div>
              <StatusChip {...statusNotaMeta[n.status]} />
            </div>
            <div className="mt-3 flex items-center justify-between border-t border-line pt-3 text-[13px]">
              <span className="text-ink-muted">Líquido</span>
              <span className="num font-semibold text-brand-700">{money(n.valorLiquido)}</span>
            </div>
          </div>

          {/* Timeline */}
          <div>
            <p className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
              Processamento
            </p>
            <ol className="relative space-y-4 pl-1">
              {timeline.map((s, i) => (
                <li key={i} className="flex gap-3">
                  <div className="flex flex-col items-center">
                    <TimelineIcon estado={s.estado} />
                    {i < timeline.length - 1 && <span className="my-1 w-px flex-1 bg-line" />}
                  </div>
                  <div className="pb-1">
                    <p
                      className={`text-[13.5px] font-medium ${
                        s.estado === 'espera' ? 'text-ink-faint' : 'text-ink'
                      }`}
                    >
                      {s.label}
                    </p>
                    <p className="text-[12px] text-ink-muted">{s.quando}</p>
                  </div>
                </li>
              ))}
            </ol>
          </div>

          <dl className="space-y-3 border-t border-line pt-4 text-[13.5px]">
            <Linha rotulo="Serviço" valor={tipoServicoMeta[n.tipoServico].label} />
            <Linha rotulo="Código NBS" valor={n.codigoNbs} mono />
            <Linha rotulo="Data do serviço" valor={dataBR(n.dataServico)} />
            {n.numero && <Linha rotulo="Número NFS-e" valor={n.numero} mono />}
          </dl>
        </div>
      )}
    </Drawer>
  );
}

function TimelineIcon({ estado }: { estado: TimelineStep['estado'] }) {
  if (estado === 'ok')
    return (
      <span className="grid h-6 w-6 place-items-center rounded-full bg-brand-50 text-brand-600">
        <CheckCircle2 size={15} />
      </span>
    );
  if (estado === 'erro')
    return (
      <span className="grid h-6 w-6 place-items-center rounded-full bg-danger-50 text-danger-600">
        <XCircle size={15} />
      </span>
    );
  if (estado === 'atual')
    return (
      <span className="grid h-6 w-6 place-items-center rounded-full bg-info-50 text-info-600">
        <Clock size={14} className="animate-pulse" />
      </span>
    );
  return <span className="mt-0.5 grid h-6 w-6 place-items-center rounded-full bg-line2 text-ink-faint">•</span>;
}

function buildTimeline(n: NotaFiscal): TimelineStep[] {
  const base: TimelineStep[] = [
    { label: 'Atendimento registrado', quando: dataBR(n.dataServico), estado: 'ok' },
    { label: 'NFS-e enviada ao provedor', quando: dataBR(n.dataServico), estado: 'ok' },
  ];
  if (n.status === 'rejeitada') {
    base.push({ label: 'Rejeitada pela prefeitura', quando: dataBR(n.dataServico), estado: 'erro' });
    base.push({ label: 'Aguardando correção', quando: 'pendente', estado: 'espera' });
  } else if (n.status === 'emProcessamento') {
    base.push({ label: 'Em análise na prefeitura', quando: 'agora', estado: 'atual' });
    base.push({ label: 'Autorização', quando: 'em breve', estado: 'espera' });
  } else if (n.status === 'autorizada') {
    base.push({ label: 'Autorizada pela prefeitura', quando: dataBR(n.dataEmissao ?? n.dataServico), estado: 'ok' });
    base.push({ label: 'DANFSe disponível', quando: dataBR(n.dataEmissao ?? n.dataServico), estado: 'ok' });
  }
  return base;
}

function Linha({ rotulo, valor, mono }: { rotulo: string; valor: string; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-4">
      <dt className="shrink-0 text-ink-muted">{rotulo}</dt>
      <dd className={`text-right font-medium text-ink ${mono ? 'num' : ''}`}>{valor}</dd>
    </div>
  );
}
