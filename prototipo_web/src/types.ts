// Tipos de domínio do protótipo — espelham o medvie-app (Dart) somente no
// vocabulário e nos status. Nenhuma regra fiscal real roda aqui: valores são
// pré-calculados nos mocks (o backend .NET é a fonte da verdade no produto).

export type StatusServico =
  | 'pendente'
  | 'nfEmProcessamento'
  | 'nfEmitida'
  | 'aguardandoPagamento'
  | 'pago'
  | 'cancelado';

export type StatusNota =
  | 'emProcessamento'
  | 'autorizada'
  | 'rejeitada'
  | 'cancelamentoPendente'
  | 'cancelada';

export type TipoServico =
  | 'plantao'
  | 'atoAnestesico'
  | 'laudo'
  | 'procedimentoCirurgico'
  | 'consulta'
  | 'outros';

export type TipoTomador = 'cpf' | 'cnpj';

export type RegimeTributario =
  | 'simplesNacional'
  | 'lucroPresumido'
  | 'lucroReal';

export type StatusCertificado =
  | 'pendente'
  | 'ativo'
  | 'expirado'
  | 'substituido'
  | 'removido';

export interface Tomador {
  id: string;
  tipo: TipoTomador;
  nome: string;
  documento: string; // CNPJ formatado ou CPF mascarado
  municipio: string;
  uf: string;
  valorPadrao?: number;
  aliquotaIss: number;
  retemIss: boolean;
  aliquotaIrrf: number;
  retemIrrf: boolean;
  enderecoFiscalCompleto: boolean;
}

export interface Certificado {
  status: StatusCertificado;
  subjectCnpj: string;
  issuerName: string;
  provider: 'PlugNotas' | 'FocusNFe';
  validFrom: string;
  validUntil: string;
  diasParaVencer: number;
  fingerprint: string;
}

export interface Cnpj {
  id: string;
  cnpj: string;
  razaoSocial: string;
  nomeFantasia: string;
  municipio: string;
  uf: string;
  inscricaoMunicipal: string;
  regime: RegimeTributario;
  metodoAssinatura: 'certificadoA1' | 'govBr';
  certificado: Certificado;
  tomadores: Tomador[];
}

export interface Medico {
  id: string;
  nome: string;
  cpf: string;
  crm: string;
  ufCrm: string;
  especialidade: string;
  telefone: string;
  email: string;
  avatarIniciais: string;
  cnpjs: Cnpj[];
}

export interface Atendimento {
  id: string;
  tipo: TipoServico;
  data: string; // ISO
  horaInicio?: string;
  horaFim?: string;
  tomadorId: string;
  tomadorNome: string;
  tomadorTipo: TipoTomador;
  tomadorDocumento: string;
  cnpjId: string;
  valor: number;
  valorLiquido: number;
  status: StatusServico;
  observacao?: string;
  notaId?: string;
}

export interface NotaFiscal {
  id: string;
  numero?: string;
  status: StatusNota;
  atendimentoId: string;
  tomadorNome: string;
  tomadorTipo: TipoTomador;
  tipoServico: TipoServico;
  valorBruto: number;
  valorLiquido: number;
  dataServico: string;
  dataEmissao?: string;
  codigoNbs: string;
  motivoRejeicao?: string;
  linkPdf?: string;
  cnpjId: string;
}

/** Retenções na fonte do mês — ISS/IRRF retidos pelos tomadores (cadastro do tomador). */
export interface RetencoesFonte {
  iss: number;
  irrf: number;
  total: number;
}

/**
 * Carga tributária mensal estimada do regime, espelhando o contrato
 * `CargaTributariaResultado` do backend (CargaTributariaCalculator). Agrupada
 * por NATUREZA do tributo para deixar claro o que a Reforma Tributária altera
 * (consumo) e o que ela NÃO altera (renda):
 *
 *  • Renda (fora da reforma)  — IRPJ, CSLL. Regidos pela legislação de renda.
 *  • Consumo (a reforma substitui) — PIS/COFINS (→ CBS em 2027), ISS (→ IBS até 2033).
 *  • Reforma, fase de teste 2026 — IBS/CBS: destaque informativo na NFS-e, sem
 *    recolhimento (LC 214/2025) — NÃO entram em `totalImpostos`.
 *
 * Estimativa de referência (não é apuração). No produto, vem 100% do backend.
 */
export interface CargaTributaria {
  // Sobre a renda — inalterados pela reforma
  irpj: number;
  csll: number;
  // Sobre o consumo — substituídos pela reforma na transição
  pis: number;
  cofins: number;
  iss: number;
  // Reforma — fase de teste 2026 (informativos, fora do total)
  ibs: number;
  cbs: number;
  /** Renda + consumo vigente (IRPJ+CSLL+PIS+COFINS+ISS). NÃO inclui IBS/CBS em 2026. */
  totalImpostos: number;
  aliquotaEfetiva: number;
  /** Bruto − totalImpostos: o que o médico retém após TODOS os tributos do regime. */
  liquidoPosImpostos: number;
  regimeDescricao: string;
}

export interface PipelineSegmento {
  valor: number;
  quantidade: number;
}

export interface Dashboard {
  competencia: string; // '2026-07'
  totalBruto: number;
  /** Bruto − retenções na fonte (ISS/IRRF retidos): caixa imediato. Contrato TotalLiquidoEstimado. */
  totalLiquidoEstimado: number;
  recebido: number;
  aReceber: number;
  aguardandoEmissao: number;
  metaMensal: number;
  variacaoLiquido: number; // fração vs mês anterior
  liquidoMesAnterior: number;
  notasAutorizadas: number;
  notasPendentes: number;
  notasRejeitadas: number;
  pipeline: {
    recebido: PipelineSegmento;
    aReceber: PipelineSegmento;
    aguardandoEmissao: PipelineSegmento;
    dataPrevista: string;
  };
  /** Retenções na fonte do mês (ISS/IRRF) — antecipação/caixa imediato. */
  retencoes: RetencoesFonte;
  /** Carga completa do regime — o líquido real após todos os tributos. */
  carga: CargaTributaria;
}

export interface SerieMensal {
  mesIndex: number; // 0-11
  bruto: number;
  /** Bruto − carga total do regime (líquido real após todos os impostos). */
  liquido: number;
  /** Carga total do regime no mês (IRPJ+CSLL+PIS+COFINS+ISS). */
  impostos: number;
}

export interface Notificacao {
  id: string;
  tipo: 'sucesso' | 'atencao' | 'erro' | 'info';
  titulo: string;
  descricao: string;
  quando: string;
  lida: boolean;
}

/**
 * Espelha o contrato do backend `POST /api/v1/atendimentos/preview`
 * (`AtendimentoFiscalPreview` no app Flutter). O preview fiscal por atendimento
 * exibe SOMENTE IBS/CBS (reforma — informativos) e as retenções na fonte do
 * tomador. IRPJ/CSLL/PIS/COFINS pertencem à carga mensal do regime
 * (CargaTributaria) e NUNCA aparecem no preview por atendimento.
 */
export interface AtendimentoFiscalPreview {
  bruto: number;
  /** Retenção declarada no cadastro do tomador. PF autônomo: sempre 0 (FR-007/SDD 017). */
  issRetido: number;
  /** Retenção declarada no cadastro do tomador. PF autônomo: sempre 0. */
  irrfRetido: number;
  /** IBS destacado na NFS-e (reforma). 2026 = fase de teste 0,1%, informativo. */
  ibs: number;
  /** CBS destacada na NFS-e (reforma). 2026 = fase de teste 0,9%, informativo. */
  cbs: number;
  /** Bruto − retenções na fonte. IBS/CBS não reduzem o líquido na fase de teste. */
  liquidoEstimado: number;
  prontoParaEmitir: boolean;
}
