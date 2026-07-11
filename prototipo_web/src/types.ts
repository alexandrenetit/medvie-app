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

export interface CargaTributaria {
  irpj: number;
  csll: number;
  pis: number;
  cofins: number;
  iss: number;
  ibs: number;
  cbs: number;
  totalImpostos: number;
  aliquotaEfetiva: number;
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
  totalImpostos: number;
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
  carga: CargaTributaria;
}

export interface SerieMensal {
  mesIndex: number; // 0-11
  bruto: number;
  liquido: number;
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

export interface SimuladorResultado {
  valorBruto: number;
  descontoIss: number;
  aliquotaIss: number;
  descontoIrrf: number;
  aliquotaIrrf: number;
  cargaRegime: number; // impostos do regime (IRPJ/CSLL/PIS/COFINS/IBS/CBS)
  aliquotaEfetiva: number;
  valorLiquido: number;
}
