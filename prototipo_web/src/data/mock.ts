// ─────────────────────────────────────────────────────────────────────────────
// DADOS SIMULADOS — Medvie protótipo web
//
// Tudo aqui é fictício e pré-calculado. No produto real, o backend .NET é a
// fonte única da verdade (impostos, status de NFS-e, agregados do dashboard).
// Este arquivo apenas alimenta a UI para demonstração — NÃO reproduz regra
// fiscal de produção. CPFs aparecem sempre mascarados; CNPJs são inventados.
// ─────────────────────────────────────────────────────────────────────────────

import type {
  Atendimento,
  Dashboard,
  Medico,
  NotaFiscal,
  Notificacao,
  SerieMensal,
  SimuladorResultado,
  StatusServico,
  TipoServico,
  Tomador,
} from '@/types';

export const COMPETENCIA_ATUAL = '2026-07';
export const HOJE = '2026-07-10';

// ── Médico ───────────────────────────────────────────────────────────────────
export const medico: Medico = {
  id: 'med-001',
  nome: 'Dr. Rafael Andrade Lima',
  cpf: maskCpf('***.***.***-18'),
  crm: '154.302',
  ufCrm: 'SP',
  especialidade: 'Anestesiologia',
  telefone: '(11) 98844-2071',
  email: 'rafael.lima@medvie.com.br',
  avatarIniciais: 'RA',
  cnpjs: [
    {
      id: 'cnpj-01',
      cnpj: '41.928.663/0001-24',
      razaoSocial: 'Andrade Lima Serviços Médicos LTDA',
      nomeFantasia: 'RAL Medicina',
      municipio: 'São Paulo',
      uf: 'SP',
      inscricaoMunicipal: '5.482.113-9',
      regime: 'lucroPresumido',
      metodoAssinatura: 'certificadoA1',
      certificado: {
        status: 'ativo',
        subjectCnpj: '41.928.663/0001-24',
        issuerName: 'AC Certisign RFB G5',
        provider: 'PlugNotas',
        validFrom: '2025-11-20',
        validUntil: '2026-11-20',
        diasParaVencer: 133,
        fingerprint: 'a91f…742c',
      },
      tomadores: [],
    },
    {
      id: 'cnpj-02',
      cnpj: '33.512.884/0001-70',
      razaoSocial: 'RAL Anestesia e Dor EIRELI',
      nomeFantasia: 'Clínica da Dor RAL',
      municipio: 'Campinas',
      uf: 'SP',
      inscricaoMunicipal: '1.209.774-2',
      regime: 'simplesNacional',
      metodoAssinatura: 'certificadoA1',
      certificado: {
        status: 'ativo',
        subjectCnpj: '33.512.884/0001-70',
        issuerName: 'AC Safeweb RFB',
        provider: 'FocusNFe',
        validFrom: '2025-07-28',
        validUntil: '2026-07-28',
        diasParaVencer: 18,
        fingerprint: 'c30b…9de1',
      },
      tomadores: [],
    },
  ],
};

// ── Tomadores ────────────────────────────────────────────────────────────────
export const tomadores: Tomador[] = [
  t('tom-01', 'cnpj', 'Hospital Santa Beatriz', '58.204.119/0001-63', 'São Paulo', 'SP', 2400, 3, false, 0),
  t('tom-02', 'cnpj', 'Clínica CardioVida', '12.657.430/0001-08', 'São Paulo', 'SP', 1800, 5, true, 0),
  t('tom-03', 'cnpj', 'Hospital São Lucas', '09.331.775/0001-41', 'São Paulo', 'SP', 2200, 2, false, 1.5),
  t('tom-04', 'cnpj', 'Hospital Municipal Bandeirantes', '46.395.001/0001-90', 'São Paulo', 'SP', 1650, 4, true, 1.5),
  t('tom-05', 'cnpj', 'Unimed Campinas', '44.501.229/0001-15', 'Campinas', 'SP', 3200, 2, true, 1.5),
  t('tom-06', 'cnpj', 'Centro Cirúrgico Vita', '31.884.552/0001-77', 'Campinas', 'SP', 5200, 0, false, 0),
  // Pacientes (PF)
  tPf('pac-01', 'Mariana Oliveira Prado', '***.***.***-42', 'São Paulo', 'SP', true),
  tPf('pac-02', 'Carlos Henrique Souza', '***.***.***-09', 'São Paulo', 'SP', true),
  tPf('pac-03', 'Beatriz Nunes Carvalho', '***.***.***-71', 'Campinas', 'SP', false),
  tPf('pac-04', 'Eduardo Ramos Teixeira', '***.***.***-30', 'São Paulo', 'SP', true),
];

// Vincula tomadores aos CNPJs (os 5 primeiros ao CNPJ 01; Unimed/Vita ao 02).
medico.cnpjs[0].tomadores = tomadores.filter((x) =>
  ['tom-01', 'tom-02', 'tom-03', 'tom-04', 'pac-01', 'pac-02', 'pac-04'].includes(x.id),
);
medico.cnpjs[1].tomadores = tomadores.filter((x) =>
  ['tom-05', 'tom-06', 'pac-03'].includes(x.id),
);

const tomadorById = new Map(tomadores.map((x) => [x.id, x]));

// ── Atendimentos ─────────────────────────────────────────────────────────────
// Competência de julho/2026 + alguns de junho para o comparativo/histórico.
const raw: Array<[string, TipoServico, string, string, number, StatusServico | 'rejeitadaFix', string?]> = [
  // id, tipo, data, tomadorId, valor, status, hora
  ['atd-101', 'atoAnestesico', '2026-07-09', 'tom-01', 2400, 'pago', '07:30'],
  ['atd-102', 'atoAnestesico', '2026-07-09', 'tom-03', 2200, 'aguardandoPagamento', '13:00'],
  ['atd-103', 'plantao', '2026-07-08', 'tom-04', 1650, 'nfEmitida', '19:00'],
  ['atd-104', 'procedimentoCirurgico', '2026-07-08', 'tom-06', 6800, 'nfEmProcessamento', '08:00'],
  ['atd-105', 'consulta', '2026-07-07', 'pac-01', 620, 'pago'],
  ['atd-106', 'atoAnestesico', '2026-07-07', 'tom-05', 3200, 'nfEmitida', '10:30'],
  ['atd-107', 'consulta', '2026-07-06', 'pac-02', 480, 'pago'],
  ['atd-108', 'laudo', '2026-07-06', 'tom-02', 380, 'pago'],
  ['atd-109', 'atoAnestesico', '2026-07-04', 'tom-01', 2400, 'pago', '07:30'],
  ['atd-110', 'plantao', '2026-07-03', 'tom-04', 1650, 'pago', '19:00'],
  ['atd-111', 'procedimentoCirurgico', '2026-07-03', 'tom-06', 8200, 'aguardandoPagamento', '08:00'],
  ['atd-112', 'consulta', '2026-07-02', 'pac-04', 560, 'pago'],
  ['atd-113', 'atoAnestesico', '2026-07-02', 'tom-03', 2200, 'nfEmitida', '14:00'],
  ['atd-114', 'atoAnestesico', '2026-07-01', 'tom-05', 3200, 'rejeitadaFix', '09:00'],
  ['atd-115', 'plantao', '2026-07-10', 'tom-04', 1650, 'pendente', '19:00'],
  ['atd-116', 'consulta', '2026-07-10', 'pac-03', 520, 'pendente'],
  ['atd-117', 'atoAnestesico', '2026-07-10', 'tom-01', 2400, 'pendente', '07:30'],
  ['atd-118', 'laudo', '2026-07-05', 'tom-02', 420, 'pago'],
  ['atd-119', 'procedimentoCirurgico', '2026-07-05', 'tom-06', 5200, 'nfEmitida', '08:00'],
  ['atd-120', 'consulta', '2026-07-04', 'pac-01', 620, 'aguardandoPagamento'],
  // Junho (histórico)
  ['atd-090', 'atoAnestesico', '2026-06-27', 'tom-01', 2300, 'pago', '07:30'],
  ['atd-091', 'plantao', '2026-06-26', 'tom-04', 1600, 'pago', '19:00'],
  ['atd-092', 'procedimentoCirurgico', '2026-06-24', 'tom-06', 7400, 'pago', '08:00'],
  ['atd-093', 'consulta', '2026-06-20', 'pac-02', 480, 'pago'],
  ['atd-094', 'atoAnestesico', '2026-06-18', 'tom-05', 3100, 'cancelado', '10:00'],
];

export const atendimentos: Atendimento[] = raw.map(([id, tipo, data, tomadorId, valor, statusRaw, hora]) => {
  const tom = tomadorById.get(tomadorId)!;
  const status: StatusServico =
    statusRaw === 'rejeitadaFix' ? 'pendente' : (statusRaw as StatusServico);
  const rejeitada = statusRaw === 'rejeitadaFix';
  const cnpjId = medico.cnpjs.find((c) => c.tomadores.some((x) => x.id === tomadorId))?.id ?? 'cnpj-01';
  const liquido = round2(valor * (tom.retemIrrf || tom.retemIss ? 0.915 : 0.94));
  return {
    id,
    tipo,
    data,
    horaInicio: hora,
    horaFim: hora ? somaHoras(hora, tipo) : undefined,
    tomadorId,
    tomadorNome: tom.nome,
    tomadorTipo: tom.tipo,
    tomadorDocumento: tom.documento,
    cnpjId,
    valor,
    valorLiquido: liquido,
    status,
    observacao: rejeitada ? 'Reenviar — endereço fiscal do tomador incompleto' : undefined,
    notaId: temNota(status) || rejeitada ? `nf-${id}` : undefined,
  };
});

// ── Notas fiscais ────────────────────────────────────────────────────────────
export const notas: NotaFiscal[] = atendimentos
  .filter((a) => a.notaId)
  .map((a, i) => {
    const rejeitada = a.observacao?.includes('Reenviar');
    const status = rejeitada
      ? ('rejeitada' as const)
      : a.status === 'nfEmProcessamento'
        ? ('emProcessamento' as const)
        : ('autorizada' as const);
    return {
      id: a.notaId!,
      numero: status === 'autorizada' ? `2026${(1200 + i).toString()}` : undefined,
      status,
      atendimentoId: a.id,
      tomadorNome: a.tomadorNome,
      tomadorTipo: a.tomadorTipo,
      tipoServico: a.tipo,
      valorBruto: a.valor,
      valorLiquido: a.valorLiquido,
      dataServico: a.data,
      dataEmissao: status === 'autorizada' ? a.data : undefined,
      codigoNbs: nbs(a.tipo),
      motivoRejeicao: rejeitada
        ? 'Endereço fiscal do tomador incompleto — código do município (IBGE) ausente.'
        : undefined,
      linkPdf: status === 'autorizada' ? '#' : undefined,
      cnpjId: a.cnpjId,
    };
  });

// ── Dashboard (competência atual) ────────────────────────────────────────────
export const dashboard: Dashboard = {
  competencia: COMPETENCIA_ATUAL,
  totalBruto: 58890,
  totalImpostos: 8951,
  totalLiquidoEstimado: 49939,
  recebido: 20890,
  aReceber: 24700,
  aguardandoEmissao: 13300,
  metaMensal: 65000,
  variacaoLiquido: 0.083,
  liquidoMesAnterior: 46110,
  notasAutorizadas: 6,
  notasPendentes: 3,
  notasRejeitadas: 1,
  pipeline: {
    recebido: { valor: 20890, quantidade: 9 },
    aReceber: { valor: 24700, quantidade: 5 },
    aguardandoEmissao: { valor: 13300, quantidade: 3 },
    dataPrevista: '2026-07-25',
  },
  carga: {
    irpj: 2650,
    csll: 1590,
    pis: 383,
    cofins: 1767,
    iss: 1178,
    ibs: 883,
    cbs: 500,
    totalImpostos: 8951,
    aliquotaEfetiva: 0.152,
    liquidoPosImpostos: 49939,
    regimeDescricao: 'Lucro Presumido · anexo serviços',
  },
};

// ── Série mensal (12 meses de 2026) ──────────────────────────────────────────
export const serieAnual: SerieMensal[] = [
  m(0, 41200), m(1, 46800), m(2, 52100), m(3, 48900), m(4, 54300),
  m(5, 50120), m(6, 58890), m(7, 0), m(8, 0), m(9, 0), m(10, 0), m(11, 0),
];

// ── Notificações ─────────────────────────────────────────────────────────────
export const notificacoes: Notificacao[] = [
  {
    id: 'ntf-01',
    tipo: 'erro',
    titulo: 'Nota rejeitada',
    descricao: 'Ato anestésico — Unimed Campinas. Endereço fiscal incompleto.',
    quando: 'há 2 h',
    lida: false,
  },
  {
    id: 'ntf-02',
    tipo: 'atencao',
    titulo: 'Certificado vence em 18 dias',
    descricao: 'RAL Anestesia e Dor (Simples Nacional) — renove para não travar emissões.',
    quando: 'há 5 h',
    lida: false,
  },
  {
    id: 'ntf-03',
    tipo: 'sucesso',
    titulo: 'Pagamento recebido',
    descricao: 'Hospital Santa Beatriz — R$ 2.400,00 conciliado.',
    quando: 'ontem',
    lida: true,
  },
  {
    id: 'ntf-04',
    tipo: 'info',
    titulo: '3 atendimentos prontos para emitir',
    descricao: 'Você tem R$ 4.570,00 aguardando emissão de NFS-e.',
    quando: 'ontem',
    lida: true,
  },
];

// ── Simulador (cálculo simulado — não é regra fiscal de produção) ─────────────
export function simular(
  valorBruto: number,
  tipo: TipoServico,
  regime: keyof typeof aliquotasRegime,
): SimuladorResultado {
  const iss = tipo === 'laudo' ? 0.02 : 0.03;
  const retIrrf = valorBruto >= 1200 ? 0.015 : 0;
  const descontoIss = round2(valorBruto * iss);
  const descontoIrrf = round2(valorBruto * retIrrf);
  const cargaRegime = round2(valorBruto * aliquotasRegime[regime]);
  const valorLiquido = round2(valorBruto - descontoIss - descontoIrrf - cargaRegime);
  const aliquotaEfetiva = valorBruto > 0 ? (valorBruto - valorLiquido) / valorBruto : 0;
  return {
    valorBruto,
    descontoIss,
    aliquotaIss: iss,
    descontoIrrf,
    aliquotaIrrf: retIrrf,
    cargaRegime,
    aliquotaEfetiva,
    valorLiquido,
  };
}

export const aliquotasRegime = {
  simplesNacional: 0.06,
  lucroPresumido: 0.1133,
  lucroReal: 0.1465,
} as const;

// ── Informe de rendimentos (por ano) ─────────────────────────────────────────
export const informeRendimentos = {
  ano: 2025,
  status: 'Disponível',
  totalRecebido: 548720,
  impostosRetidos: 32410,
  emitidoEm: '2026-02-27',
};

// ─────────────────────────────────────────────────────────────────────────────
// helpers de construção
// ─────────────────────────────────────────────────────────────────────────────
function t(
  id: string,
  tipo: 'cnpj',
  nome: string,
  doc: string,
  municipio: string,
  uf: string,
  valorPadrao: number,
  aliquotaIss: number,
  retemIss: boolean,
  aliquotaIrrf: number,
): Tomador {
  return {
    id,
    tipo,
    nome,
    documento: doc,
    municipio,
    uf,
    valorPadrao,
    aliquotaIss,
    retemIss,
    aliquotaIrrf,
    retemIrrf: aliquotaIrrf > 0,
    enderecoFiscalCompleto: true,
  };
}

function tPf(
  id: string,
  nome: string,
  cpfMasc: string,
  municipio: string,
  uf: string,
  enderecoCompleto: boolean,
): Tomador {
  return {
    id,
    tipo: 'cpf',
    nome,
    documento: cpfMasc,
    municipio,
    uf,
    aliquotaIss: 3,
    retemIss: false,
    aliquotaIrrf: 0,
    retemIrrf: false,
    enderecoFiscalCompleto: enderecoCompleto,
  };
}

function m(mesIndex: number, bruto: number): SerieMensal {
  return {
    mesIndex,
    bruto,
    liquido: round2(bruto * 0.848),
    impostos: round2(bruto * 0.152),
  };
}

function temNota(status: StatusServico): boolean {
  return ['nfEmProcessamento', 'nfEmitida', 'aguardandoPagamento', 'pago'].includes(status);
}

function nbs(tipo: TipoServico): string {
  return tipo === 'laudo' ? '40201' : tipo === 'consulta' ? '40101' : '40119';
}

function somaHoras(hora: string, tipo: TipoServico): string {
  const [h, min] = hora.split(':').map(Number);
  const dur = tipo === 'plantao' ? 12 : tipo === 'procedimentoCirurgico' ? 3 : 2;
  const fim = (h + dur) % 24;
  return `${fim.toString().padStart(2, '0')}:${min.toString().padStart(2, '0')}`;
}

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

function maskCpf(v: string): string {
  return v;
}
