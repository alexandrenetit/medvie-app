import { useMemo, useState } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  Plus,
  CalendarDays,
  Search,
  Clock3,
} from 'lucide-react';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Segmented } from '@/components/ui/Segmented';
import { StatusChip } from '@/components/ui/StatusChip';
import { Input } from '@/components/ui/Field';
import { EmptyState } from '@/components/ui/EmptyState';
import { useAppState } from '@/context/AppState';
import { atendimentos } from '@/data/mock';
import { money, nomeMes } from '@/lib/format';
import { statusServicoMeta, tipoServicoMeta, toneClasses } from '@/data/domain';
import type { Atendimento } from '@/types';

const SEMANA = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

export default function Agenda() {
  const { setNovoAtendimentoOpen } = useAppState();
  const [ano, setAno] = useState(2026);
  const [mes, setMes] = useState(6); // 0-based → julho
  const [selecionado, setSelecionado] = useState('2026-07-09');
  const [modo, setModo] = useState<'mes' | 'semana'>('mes');
  const [busca, setBusca] = useState('');

  const porData = useMemo(() => {
    const map = new Map<string, Atendimento[]>();
    atendimentos.forEach((a) => {
      if (busca && !a.tomadorNome.toLowerCase().includes(busca.toLowerCase())) return;
      if (!map.has(a.data)) map.set(a.data, []);
      map.get(a.data)!.push(a);
    });
    return map;
  }, [busca]);

  const grid = useMemo(() => buildGrid(ano, mes), [ano, mes]);
  const visiveis = useMemo(() => {
    if (modo === 'mes') return grid;
    // Semana: só a linha (7 células) que contém o dia selecionado.
    for (let i = 0; i < grid.length; i += 7) {
      const semana = grid.slice(i, i + 7);
      if (semana.some((c) => c?.iso === selecionado)) return semana;
    }
    return grid.slice(0, 7);
  }, [grid, modo, selecionado]);
  const doDia = (porData.get(selecionado) ?? []).sort((a, b) =>
    (a.horaInicio ?? '99').localeCompare(b.horaInicio ?? '99'),
  );

  const totalDia = doDia.reduce((s, a) => s + a.valor, 0);

  function navegar(delta: number) {
    let m = mes + delta;
    let a = ano;
    if (m < 0) {
      m = 11;
      a--;
    } else if (m > 11) {
      m = 0;
      a++;
    }
    setMes(m);
    setAno(a);
  }

  function hoje() {
    setAno(2026);
    setMes(6);
    setSelecionado('2026-07-10');
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-brand text-[24px] font-bold text-ink">Agenda</h1>
          <p className="mt-0.5 text-[14px] text-ink-muted">
            Organize atendimentos e visualize o valor previsto por dia.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <div className="relative">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint" />
            <Input
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
              placeholder="Buscar paciente…"
              className="h-10 w-48 pl-9"
            />
          </div>
          <Button size="sm" className="h-10" onClick={() => setNovoAtendimentoOpen(true)}>
            <Plus size={16} /> Atendimento
          </Button>
        </div>
      </div>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_340px]">
        {/* Calendário */}
        <Card className="p-4 sm:p-5">
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <h2 className="font-brand text-[18px] font-semibold capitalize text-ink">
                {nomeMes(mes)} {ano}
              </h2>
            </div>
            <div className="flex items-center gap-2">
              <Segmented<'mes' | 'semana'>
                size="sm"
                value={modo}
                onChange={setModo}
                options={[
                  { value: 'mes', label: 'Mês' },
                  { value: 'semana', label: 'Semana' },
                ]}
              />
              <Button variant="outline" size="sm" onClick={hoje}>
                Hoje
              </Button>
              <div className="flex items-center rounded-lg border border-line">
                <button
                  onClick={() => navegar(-1)}
                  className="grid h-8 w-8 place-items-center text-ink-muted hover:bg-line2"
                  aria-label="Mês anterior"
                >
                  <ChevronLeft size={17} />
                </button>
                <button
                  onClick={() => navegar(1)}
                  className="grid h-8 w-8 place-items-center border-l border-line text-ink-muted hover:bg-line2"
                  aria-label="Próximo mês"
                >
                  <ChevronRight size={17} />
                </button>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-7 gap-1.5">
            {SEMANA.map((d) => (
              <div key={d} className="pb-1 text-center text-[11.5px] font-semibold uppercase text-ink-faint">
                {d}
              </div>
            ))}
            {visiveis.map((cell, i) => {
              if (!cell) return <div key={i} />;
              const iso = cell.iso;
              const itens = porData.get(iso) ?? [];
              const isSel = iso === selecionado;
              const isHoje = iso === '2026-07-10';
              const soma = itens.reduce((s, a) => s + a.valor, 0);
              return (
                <button
                  key={i}
                  onClick={() => setSelecionado(iso)}
                  className={`group flex flex-col rounded-xl border p-2 text-left transition-all ${
                    modo === 'semana' ? 'min-h-[220px]' : 'min-h-[86px]'
                  } ${
                    isSel
                      ? 'border-brand-500 bg-brand-50/50 shadow-ring'
                      : 'border-line hover:border-ink-faint hover:bg-line2/40'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span
                      className={`grid h-6 w-6 place-items-center rounded-full text-[13px] font-semibold ${
                        isHoje ? 'bg-ink text-white' : 'text-ink-soft'
                      }`}
                    >
                      {cell.dia}
                    </span>
                    {itens.length > 0 && (
                      <span className="num text-[10.5px] font-semibold text-ink-muted">
                        {itens.length}
                      </span>
                    )}
                  </div>
                  <div className="mt-1 flex flex-1 flex-col gap-0.5">
                    {itens.slice(0, modo === 'semana' ? 6 : 2).map((a) => (
                      <span
                        key={a.id}
                        className={`truncate rounded px-1 py-0.5 text-[10.5px] font-medium ${
                          toneClasses[statusServicoMeta[a.status].tone].chip
                        }`}
                      >
                        {modo === 'semana' && a.horaInicio ? `${a.horaInicio} ` : ''}
                        {a.tomadorNome.split(' ')[0]}
                      </span>
                    ))}
                    {itens.length > (modo === 'semana' ? 6 : 2) && (
                      <span className="px-1 text-[10px] text-ink-muted">
                        +{itens.length - (modo === 'semana' ? 6 : 2)}
                      </span>
                    )}
                  </div>
                  {soma > 0 && (
                    <span className="num mt-0.5 text-[10.5px] font-semibold text-brand-700">
                      {money(soma).replace(',00', '')}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </Card>

        {/* Painel do dia */}
        <Card className="flex flex-col">
          <div className="border-b border-line p-5">
            <p className="text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
              {formatDiaExtenso(selecionado)}
            </p>
            <div className="mt-1 flex items-end justify-between">
              <h3 className="font-brand text-[18px] font-semibold text-ink">
                {doDia.length} atendimento{doDia.length === 1 ? '' : 's'}
              </h3>
              {totalDia > 0 && (
                <span className="num text-[15px] font-bold text-brand-700">{money(totalDia)}</span>
              )}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            {doDia.length === 0 ? (
              <EmptyState
                icon={CalendarDays}
                titulo="Dia livre"
                descricao="Nenhum atendimento agendado."
                compact
                action={
                  <Button size="sm" variant="outline" onClick={() => setNovoAtendimentoOpen(true)}>
                    <Plus size={15} /> Adicionar
                  </Button>
                }
              />
            ) : (
              <div className="divide-y divide-line2">
                {doDia.map((a) => (
                  <div key={a.id} className="p-4 transition-colors hover:bg-line2/30">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="truncate text-[14px] font-semibold text-ink">{a.tomadorNome}</p>
                        <p className="text-[12.5px] text-ink-muted">
                          {tipoServicoMeta[a.tipo].label}
                        </p>
                      </div>
                      <span className="num shrink-0 text-[14px] font-bold text-ink">
                        {money(a.valor)}
                      </span>
                    </div>
                    <div className="mt-2 flex items-center justify-between">
                      <StatusChip {...statusServicoMeta[a.status]} />
                      {a.horaInicio && (
                        <span className="flex items-center gap-1 text-[12px] text-ink-muted">
                          <Clock3 size={13} /> {a.horaInicio}
                          {a.horaFim && `–${a.horaFim}`}
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
}

interface Cell {
  dia: number;
  iso: string;
}
function buildGrid(ano: number, mes: number): (Cell | null)[] {
  const first = new Date(Date.UTC(ano, mes, 1));
  const startDow = first.getUTCDay();
  const days = new Date(Date.UTC(ano, mes + 1, 0)).getUTCDate();
  const cells: (Cell | null)[] = [];
  for (let i = 0; i < startDow; i++) cells.push(null);
  for (let d = 1; d <= days; d++) {
    const iso = `${ano}-${String(mes + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    cells.push({ dia: d, iso });
  }
  while (cells.length % 7 !== 0) cells.push(null);
  return cells;
}

function formatDiaExtenso(iso: string): string {
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('pt-BR', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
  });
}
