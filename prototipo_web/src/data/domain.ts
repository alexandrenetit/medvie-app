import type {
  StatusServico,
  StatusNota,
  TipoServico,
  RegimeTributario,
  StatusCertificado,
  TipoTomador,
} from '@/types';

export type Tone =
  | 'brand'
  | 'info'
  | 'warn'
  | 'danger'
  | 'indigo'
  | 'orange'
  | 'neutral';

/** Classes utilitárias por tom — usadas por StatusChip e por chips inline. */
export const toneClasses: Record<Tone, { chip: string; dot: string; soft: string; text: string }> = {
  brand: { chip: 'bg-brand-50 text-brand-700', dot: 'bg-brand-500', soft: 'bg-brand-50', text: 'text-brand-700' },
  info: { chip: 'bg-info-50 text-info-700', dot: 'bg-info-500', soft: 'bg-info-50', text: 'text-info-700' },
  warn: { chip: 'bg-warn-50 text-warn-700', dot: 'bg-warn-500', soft: 'bg-warn-50', text: 'text-warn-700' },
  danger: { chip: 'bg-danger-50 text-danger-700', dot: 'bg-danger-500', soft: 'bg-danger-50', text: 'text-danger-700' },
  indigo: { chip: 'bg-[#EEF0FE] text-indigo-600', dot: 'bg-indigo-500', soft: 'bg-[#EEF0FE]', text: 'text-indigo-600' },
  orange: { chip: 'bg-[#FEF0E4] text-orange-600', dot: 'bg-orange-500', soft: 'bg-[#FEF0E4]', text: 'text-orange-600' },
  neutral: { chip: 'bg-line2 text-ink-muted', dot: 'bg-ink-faint', soft: 'bg-line2', text: 'text-ink-muted' },
};

export interface StatusMeta {
  label: string;
  tone: Tone;
}

// Ciclo de vida do atendimento (StatusServico) — cores herdadas do medvie-app.
export const statusServicoMeta: Record<StatusServico, StatusMeta> = {
  pendente: { label: 'Pendente', tone: 'warn' },
  nfEmProcessamento: { label: 'Em processamento', tone: 'info' },
  nfEmitida: { label: 'NF emitida', tone: 'indigo' },
  aguardandoPagamento: { label: 'Aguardando pagamento', tone: 'orange' },
  pago: { label: 'Pago', tone: 'brand' },
  cancelado: { label: 'Cancelado', tone: 'danger' },
};

export const statusNotaMeta: Record<StatusNota, StatusMeta> = {
  emProcessamento: { label: 'Em processamento', tone: 'info' },
  autorizada: { label: 'Autorizada', tone: 'brand' },
  rejeitada: { label: 'Rejeitada', tone: 'danger' },
  cancelamentoPendente: { label: 'Cancelando…', tone: 'orange' },
  cancelada: { label: 'Cancelada', tone: 'neutral' },
};

export interface TipoServicoMeta {
  label: string;
  codigoNbs: string;
  descricaoCurta: string;
}

export const tipoServicoMeta: Record<TipoServico, TipoServicoMeta> = {
  plantao: {
    label: 'Plantão',
    codigoNbs: '40119',
    descricaoCurta: 'Plantão médico',
  },
  atoAnestesico: {
    label: 'Ato anestésico',
    codigoNbs: '40119',
    descricaoCurta: 'Ato anestésico',
  },
  laudo: {
    label: 'Laudo / Exame',
    codigoNbs: '40201',
    descricaoCurta: 'Emissão de laudo/exame',
  },
  procedimentoCirurgico: {
    label: 'Procedimento cirúrgico',
    codigoNbs: '40119',
    descricaoCurta: 'Procedimento cirúrgico',
  },
  consulta: {
    label: 'Consulta / Atendimento',
    codigoNbs: '40101',
    descricaoCurta: 'Consulta médica',
  },
  outros: {
    label: 'Outros',
    codigoNbs: '40119',
    descricaoCurta: 'Prestação de serviços médicos',
  },
};

export const regimeMeta: Record<RegimeTributario, { label: string; descricao: string }> = {
  simplesNacional: {
    label: 'Simples Nacional',
    descricao: 'Faturamento até R$ 4,8M/ano — DAS unificado',
  },
  lucroPresumido: {
    label: 'Lucro Presumido',
    descricao: 'Até R$ 78M/ano — o mais comum para médicos PJ',
  },
  lucroReal: {
    label: 'Lucro Real',
    descricao: 'Obrigatório acima de R$ 78M/ano',
  },
};

export const statusCertificadoMeta: Record<StatusCertificado, StatusMeta> = {
  pendente: { label: 'Pendente', tone: 'warn' },
  ativo: { label: 'Ativo', tone: 'brand' },
  expirado: { label: 'Expirado', tone: 'danger' },
  substituido: { label: 'Substituído', tone: 'neutral' },
  removido: { label: 'Removido', tone: 'danger' },
};

export const tipoTomadorMeta: Record<TipoTomador, string> = {
  cpf: 'Paciente',
  cnpj: 'Empresa / Convênio',
};

export const especialidades = [
  'Anestesiologia',
  'Cardiologia',
  'Cirurgia Geral',
  'Clínica Médica',
  'Dermatologia',
  'Endocrinologia',
  'Gastroenterologia',
  'Ginecologia e Obstetrícia',
  'Neurologia',
  'Oftalmologia',
  'Ortopedia',
  'Pediatria',
  'Radiologia',
];
