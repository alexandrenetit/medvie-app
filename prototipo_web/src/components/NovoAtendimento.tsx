import { useMemo, useState } from 'react';
import {
  User,
  Building2,
  Search,
  Check,
  Loader2,
  ArrowRight,
  ArrowLeft,
  UserPlus,
  CheckCircle2,
  Sparkles,
} from 'lucide-react';
import { cn } from '@/lib/cn';
import { Modal } from '@/components/ui/Modal';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';
import { Segmented } from '@/components/ui/Segmented';
import { useAppState } from '@/context/AppState';
import { tomadores, medico, simular, aliquotasRegime } from '@/data/mock';
import { money, moneyPlain } from '@/lib/format';
import { tipoServicoMeta } from '@/data/domain';
import type { TipoServico, TipoTomador, Tomador } from '@/types';

type Passo = 1 | 2 | 3;
type BuscaEstado = 'idle' | 'buscando' | 'encontrado' | 'novo';

const tiposServico: TipoServico[] = [
  'consulta',
  'plantao',
  'atoAnestesico',
  'procedimentoCirurgico',
  'laudo',
  'outros',
];

export function NovoAtendimento() {
  const { novoAtendimentoOpen, setNovoAtendimentoOpen, cnpjAtivoId, pushToast } = useAppState();
  const [passo, setPasso] = useState<Passo>(1);
  const [tipoTomador, setTipoTomador] = useState<TipoTomador>('cnpj');
  const [busca, setBusca] = useState('');
  const [buscaEstado, setBuscaEstado] = useState<BuscaEstado>('idle');
  const [tomador, setTomador] = useState<Tomador | null>(null);
  const [tipoServico, setTipoServico] = useState<TipoServico>('consulta');
  const [data, setData] = useState('2026-07-10');
  const [hora, setHora] = useState('');
  const [valor, setValor] = useState<number>(0);
  const [sucesso, setSucesso] = useState(false);

  const cnpj = medico.cnpjs.find((c) => c.id === cnpjAtivoId) ?? medico.cnpjs[0];

  const candidatos = useMemo(
    () => tomadores.filter((t) => t.tipo === tipoTomador),
    [tipoTomador],
  );

  const resultado = useMemo(
    () => simular(valor, tipoServico, cnpj.regime),
    [valor, tipoServico, cnpj.regime],
  );

  function reset() {
    setPasso(1);
    setTipoTomador('cnpj');
    setBusca('');
    setBuscaEstado('idle');
    setTomador(null);
    setTipoServico('consulta');
    setData('2026-07-10');
    setHora('');
    setValor(0);
    setSucesso(false);
  }

  function fechar() {
    setNovoAtendimentoOpen(false);
    setTimeout(reset, 250);
  }

  function simularBusca() {
    setBuscaEstado('buscando');
    window.setTimeout(() => {
      const achado = candidatos.find((t) =>
        t.nome.toLowerCase().includes(busca.trim().toLowerCase()),
      );
      if (busca.trim() && achado) {
        setTomador(achado);
        setBuscaEstado('encontrado');
      } else {
        setBuscaEstado('novo');
      }
    }, 900);
  }

  function confirmar() {
    setSucesso(true);
    pushToast({
      tipo: 'sucesso',
      titulo: 'Atendimento registrado',
      descricao: `${tipoServicoMeta[tipoServico].label} · ${money(valor)} — pronto para emitir NFS-e.`,
    });
  }

  const podeAvancar1 = buscaEstado === 'encontrado' || buscaEstado === 'novo';
  const podeAvancar2 = valor > 0 && !!data;

  const docLabel = tipoTomador === 'cpf' ? 'CPF do paciente' : 'CNPJ da empresa / convênio';
  const docPlaceholder = tipoTomador === 'cpf' ? '000.000.000-00' : '00.000.000/0000-00';

  return (
    <Modal
      open={novoAtendimentoOpen}
      onClose={fechar}
      size="xl"
      title={sucesso ? undefined : 'Novo atendimento'}
      subtitle={sucesso ? undefined : `Registrando em ${cnpj.nomeFantasia}`}
      footer={
        sucesso ? undefined : (
          <div className="flex w-full items-center justify-between">
            <StepDots passo={passo} />
            <div className="flex items-center gap-3">
              {passo > 1 && (
                <Button variant="ghost" size="sm" onClick={() => setPasso((p) => (p - 1) as Passo)}>
                  <ArrowLeft size={16} /> Voltar
                </Button>
              )}
              {passo < 3 ? (
                <Button
                  size="sm"
                  disabled={passo === 1 ? !podeAvancar1 : !podeAvancar2}
                  onClick={() => setPasso((p) => (p + 1) as Passo)}
                >
                  Continuar <ArrowRight size={16} />
                </Button>
              ) : (
                <Button size="sm" onClick={confirmar}>
                  <Check size={16} /> Confirmar atendimento
                </Button>
              )}
            </div>
          </div>
        )
      }
    >
      {sucesso ? (
        <SucessoView
          tomadorNome={tomador?.nome ?? 'Novo paciente'}
          tipo={tipoServico}
          valor={valor}
          onNovo={reset}
          onFechar={fechar}
        />
      ) : (
        <div className="min-h-[340px]">
          {/* ── Passo 1: tomador ─────────────────────────────────────────── */}
          {passo === 1 && (
            <div className="space-y-5 animate-fade-in">
              <div>
                <p className="mb-2 text-[13px] font-medium text-ink-soft">Para quem é o atendimento?</p>
                <Segmented<TipoTomador>
                  value={tipoTomador}
                  onChange={(v) => {
                    setTipoTomador(v);
                    setBuscaEstado('idle');
                    setTomador(null);
                  }}
                  options={[
                    { value: 'cnpj', label: 'Empresa / Convênio', icon: <Building2 size={16} /> },
                    { value: 'cpf', label: 'Paciente (PF)', icon: <User size={16} /> },
                  ]}
                />
              </div>

              <Field label={docLabel} hint="Simulado — nenhum dado real é consultado.">
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
                    <Input
                      value={busca}
                      onChange={(e) => {
                        setBusca(e.target.value);
                        setBuscaEstado('idle');
                      }}
                      onKeyDown={(e) => e.key === 'Enter' && simularBusca()}
                      placeholder={`${docPlaceholder}  ou nome`}
                      className="pl-10"
                    />
                  </div>
                  <Button
                    variant="outline"
                    size="md"
                    onClick={simularBusca}
                    disabled={buscaEstado === 'buscando'}
                  >
                    {buscaEstado === 'buscando' ? (
                      <Loader2 size={16} className="animate-spin" />
                    ) : (
                      'Localizar'
                    )}
                  </Button>
                </div>
              </Field>

              {buscaEstado === 'encontrado' && tomador && (
                <div className="flex items-center gap-3 rounded-xl border border-brand-100 bg-brand-50/60 p-3.5 animate-slide-up">
                  <CheckCircle2 size={20} className="shrink-0 text-brand-600" />
                  <div className="min-w-0 flex-1">
                    <p className="text-[14px] font-semibold text-ink">{tomador.nome}</p>
                    <p className="num text-[12.5px] text-ink-muted">
                      {tomador.documento} · {tomador.municipio}/{tomador.uf}
                    </p>
                  </div>
                  <span className="chip bg-brand-100 text-brand-700">Cadastro encontrado</span>
                </div>
              )}

              {buscaEstado === 'novo' && (
                <div className="flex items-center gap-3 rounded-xl border border-info-100 bg-info-50/60 p-3.5 animate-slide-up">
                  <UserPlus size={20} className="shrink-0 text-info-600" />
                  <div className="min-w-0 flex-1">
                    <p className="text-[14px] font-semibold text-ink">
                      {tipoTomador === 'cpf' ? 'Novo paciente' : 'Nova empresa'}
                    </p>
                    <p className="text-[12.5px] text-ink-muted">
                      Cadastro rápido — completaremos o endereço fiscal na emissão.
                    </p>
                  </div>
                  <span className="chip bg-info-100 text-info-700">Será criado</span>
                </div>
              )}

              <div>
                <p className="mb-2 text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
                  {tipoTomador === 'cpf' ? 'Pacientes recentes' : 'Tomadores recentes'}
                </p>
                <div className="grid gap-1.5 sm:grid-cols-2">
                  {candidatos.slice(0, 4).map((t) => (
                    <button
                      key={t.id}
                      onClick={() => {
                        setTomador(t);
                        setBusca(t.nome);
                        setBuscaEstado('encontrado');
                      }}
                      className={cn(
                        'flex items-center gap-2.5 rounded-xl border p-2.5 text-left transition-colors',
                        tomador?.id === t.id
                          ? 'border-brand-500 bg-brand-50/50'
                          : 'border-line hover:border-ink-faint hover:bg-line2/50',
                      )}
                    >
                      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-line2 text-ink-muted">
                        {t.tipo === 'cpf' ? <User size={15} /> : <Building2 size={15} />}
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-[13px] font-medium text-ink">
                          {t.nome}
                        </span>
                        <span className="num block truncate text-[11.5px] text-ink-muted">
                          {t.documento}
                        </span>
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ── Passo 2: serviço ─────────────────────────────────────────── */}
          {passo === 2 && (
            <div className="grid gap-6 animate-fade-in md:grid-cols-[1.4fr_1fr]">
              <div className="space-y-5">
                <div>
                  <p className="mb-2 text-[13px] font-medium text-ink-soft">Tipo de serviço</p>
                  <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
                    {tiposServico.map((ts) => {
                      const ativo = ts === tipoServico;
                      return (
                        <button
                          key={ts}
                          onClick={() => setTipoServico(ts)}
                          className={cn(
                            'rounded-xl border p-3 text-left transition-all',
                            ativo
                              ? 'border-brand-500 bg-brand-50/60 shadow-ring'
                              : 'border-line hover:border-ink-faint',
                          )}
                        >
                          <p className="text-[13px] font-semibold text-ink">
                            {tipoServicoMeta[ts].label}
                          </p>
                          <p className="num mt-0.5 text-[11px] text-ink-muted">
                            NBS {tipoServicoMeta[ts].codigoNbs}
                          </p>
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <Field label="Data do serviço" required>
                    <Input type="date" value={data} onChange={(e) => setData(e.target.value)} />
                  </Field>
                  <Field label="Horário" hint="Opcional">
                    <Input type="time" value={hora} onChange={(e) => setHora(e.target.value)} />
                  </Field>
                </div>

                <Field label="Valor bruto" required>
                  <MoneyInput value={valor} onChange={setValor} autoFocus />
                </Field>
              </div>

              {/* Resumo ao vivo */}
              <div className="rounded-2xl border border-line bg-canvas p-4">
                <p className="flex items-center gap-1.5 text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
                  <Sparkles size={13} className="text-brand-500" /> Prévia fiscal
                </p>
                <p className="num mt-3 text-[28px] font-bold leading-none text-ink">
                  {money(resultado.valorLiquido)}
                </p>
                <p className="mt-1 text-[12px] text-ink-muted">líquido estimado ao médico</p>
                <div className="mt-4 space-y-2 border-t border-line pt-3 text-[13px]">
                  <ResumoLinha label="Valor bruto" valor={valor} />
                  <ResumoLinha label={`ISS (${(resultado.aliquotaIss * 100).toFixed(0)}%)`} valor={-resultado.descontoIss} />
                  {resultado.descontoIrrf > 0 && (
                    <ResumoLinha label="IRRF (1,5%)" valor={-resultado.descontoIrrf} />
                  )}
                  <ResumoLinha
                    label={`Regime · ${(aliquotasRegime[cnpj.regime] * 100).toFixed(1)}%`}
                    valor={-resultado.cargaRegime}
                  />
                </div>
                <p className="mt-3 text-[11px] leading-snug text-ink-faint">
                  Estimativa simulada. No produto, o cálculo vem do backend Medvie.
                </p>
              </div>
            </div>
          )}

          {/* ── Passo 3: resumo ──────────────────────────────────────────── */}
          {passo === 3 && (
            <div className="grid gap-6 animate-fade-in md:grid-cols-2">
              <div className="space-y-4">
                <ResumoBloco titulo="Tomador">
                  <p className="text-[15px] font-semibold text-ink">
                    {tomador?.nome ?? (tipoTomador === 'cpf' ? 'Novo paciente' : 'Nova empresa')}
                  </p>
                  <p className="num text-[13px] text-ink-muted">
                    {tomador?.documento ?? 'Cadastro rápido'} ·{' '}
                    {tipoTomador === 'cpf' ? 'Paciente' : 'Empresa / Convênio'}
                  </p>
                </ResumoBloco>
                <ResumoBloco titulo="Serviço">
                  <p className="text-[15px] font-semibold text-ink">
                    {tipoServicoMeta[tipoServico].label}
                  </p>
                  <p className="text-[13px] text-ink-muted">
                    {new Date(data).toLocaleDateString('pt-BR', { timeZone: 'UTC' })}
                    {hora && ` · ${hora}`} · NBS {tipoServicoMeta[tipoServico].codigoNbs}
                  </p>
                </ResumoBloco>
                <ResumoBloco titulo="Emissão">
                  <p className="text-[13px] text-ink-soft">
                    Certificado <span className="font-semibold text-brand-600">ativo</span> em{' '}
                    {cnpj.nomeFantasia}. A NFS-e entra na fila automática após confirmar.
                  </p>
                </ResumoBloco>
              </div>

              <div className="rounded-2xl border border-brand-100 bg-gradient-to-b from-brand-50/70 to-canvas p-5">
                <p className="text-[12px] font-semibold uppercase tracking-wide text-brand-700">
                  Resumo financeiro
                </p>
                <p className="num mt-3 text-[34px] font-bold leading-none text-ink">
                  {money(resultado.valorLiquido)}
                </p>
                <p className="mt-1 text-[13px] text-ink-muted">líquido estimado</p>
                <div className="mt-5 space-y-2.5 text-[13.5px]">
                  <ResumoLinha label="Valor bruto" valor={valor} destaque />
                  <ResumoLinha label="Total de deduções" valor={-(valor - resultado.valorLiquido)} />
                  <div className="flex items-center justify-between border-t border-brand-100 pt-2.5 text-[13px]">
                    <span className="text-ink-muted">Alíquota efetiva</span>
                    <span className="num font-semibold text-ink">
                      {(resultado.aliquotaEfetiva * 100).toFixed(1)}%
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </Modal>
  );
}

function StepDots({ passo }: { passo: Passo }) {
  const labels = ['Tomador', 'Serviço', 'Resumo'];
  return (
    <div className="hidden items-center gap-2 sm:flex">
      {labels.map((l, i) => {
        const n = (i + 1) as Passo;
        const done = passo > n;
        const active = passo === n;
        return (
          <div key={l} className="flex items-center gap-2">
            <span
              className={cn(
                'grid h-6 w-6 place-items-center rounded-full text-[11px] font-bold transition-colors',
                done
                  ? 'bg-brand-600 text-white'
                  : active
                    ? 'bg-brand-50 text-brand-700 ring-2 ring-brand-500'
                    : 'bg-line2 text-ink-muted',
              )}
            >
              {done ? <Check size={13} /> : n}
            </span>
            <span
              className={cn(
                'text-[12.5px] font-medium',
                active ? 'text-ink' : 'text-ink-muted',
              )}
            >
              {l}
            </span>
            {i < labels.length - 1 && <span className="mx-1 h-px w-5 bg-line" />}
          </div>
        );
      })}
    </div>
  );
}

function ResumoLinha({
  label,
  valor,
  destaque,
}: {
  label: string;
  valor: number;
  destaque?: boolean;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-ink-muted">{label}</span>
      <span
        className={cn(
          'num font-medium',
          destaque ? 'text-ink' : valor < 0 ? 'text-danger-600' : 'text-ink',
        )}
      >
        {valor < 0 ? '−' : ''}
        {money(Math.abs(valor))}
      </span>
    </div>
  );
}

function ResumoBloco({ titulo, children }: { titulo: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-line bg-card p-4">
      <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
        {titulo}
      </p>
      {children}
    </div>
  );
}

function MoneyInput({
  value,
  onChange,
  autoFocus,
}: {
  value: number;
  onChange: (v: number) => void;
  autoFocus?: boolean;
}) {
  const [texto, setTexto] = useState(value ? moneyPlain(value) : '');
  return (
    <div className="relative">
      <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[15px] font-medium text-ink-muted">
        R$
      </span>
      <input
        inputMode="decimal"
        autoFocus={autoFocus}
        value={texto}
        onChange={(e) => {
          const raw = e.target.value.replace(/[^\d,]/g, '');
          setTexto(raw);
          const n = Number(raw.replace(/\./g, '').replace(',', '.'));
          onChange(Number.isFinite(n) ? n : 0);
        }}
        onBlur={() => setTexto(value ? moneyPlain(value) : '')}
        placeholder="0,00"
        className="field num pl-10 text-[15px]"
      />
    </div>
  );
}

function SucessoView({
  tomadorNome,
  tipo,
  valor,
  onNovo,
  onFechar,
}: {
  tomadorNome: string;
  tipo: TipoServico;
  valor: number;
  onNovo: () => void;
  onFechar: () => void;
}) {
  return (
    <div className="flex flex-col items-center py-6 text-center animate-fade-in">
      <div className="grid h-16 w-16 place-items-center rounded-2xl bg-brand-50 text-brand-600">
        <CheckCircle2 size={34} strokeWidth={2} />
      </div>
      <h2 className="mt-5 font-brand text-xl font-semibold text-ink">Atendimento registrado</h2>
      <p className="mt-1.5 max-w-sm text-[14px] text-ink-muted">
        {tipoServicoMeta[tipo].label} para <span className="font-medium text-ink-soft">{tomadorNome}</span> no
        valor de <span className="num font-semibold text-ink">{money(valor)}</span>. A NFS-e será
        emitida automaticamente pelo Medvie.
      </p>
      <div className="mt-6 flex items-center gap-3">
        <Button variant="outline" size="md" onClick={onNovo}>
          Registrar outro
        </Button>
        <Button size="md" onClick={onFechar}>
          Concluir
        </Button>
      </div>
    </div>
  );
}
