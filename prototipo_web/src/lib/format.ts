// Formatadores pt-BR. Espelham o comportamento do medvie-app (BRL, datas,
// máscaras de documento) — mas aqui só para exibição de dados mockados.

const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const brlCompact = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  notation: 'compact',
  maximumFractionDigits: 1,
});

/** R$ 12.450,00 */
export function money(value: number): string {
  return brl.format(value);
}

/** R$ 12,5 mil — para eixos de gráfico e rótulos densos. */
export function moneyCompact(value: number): string {
  return brlCompact.format(value);
}

/** 12.450,00 (sem símbolo) — útil em inputs monetários. */
export function moneyPlain(value: number): string {
  return value.toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/** 8,3% — percentual com uma casa. `fraction` recebe 0.083. */
export function percent(fraction: number, digits = 1): string {
  return `${(fraction * 100).toLocaleString('pt-BR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: digits,
  })}%`;
}

const MESES = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const MESES_CURTO = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

export function nomeMes(mesIndex0: number): string {
  return MESES[mesIndex0] ?? '';
}
export function nomeMesCurto(mesIndex0: number): string {
  return MESES_CURTO[mesIndex0] ?? '';
}

/** Converte ISO em Date sem deslocar o dia: strings date-only ("2026-07-10")
 *  são ancoradas à meia-noite LOCAL, evitando o -1 dia em fusos negativos. */
function paraData(iso: string | Date): Date {
  if (iso instanceof Date) return iso;
  return /^\d{4}-\d{2}-\d{2}$/.test(iso) ? new Date(`${iso}T00:00:00`) : new Date(iso);
}

/** 15/07/2026 */
export function dataBR(iso: string | Date): string {
  return paraData(iso).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

/** 15 jul */
export function dataCurta(iso: string | Date): string {
  const d = paraData(iso);
  const dia = d.getDate().toString().padStart(2, '0');
  return `${dia} ${MESES_CURTO[d.getMonth()].toLowerCase()}`;
}

/** Máscara CNPJ 12.345.678/0001-90 (aceita valor já mascarado). */
export function maskCNPJ(v: string): string {
  const digits = v.replace(/\D/g, '');
  if (digits.length !== 14) return v;
  return digits.replace(
    /^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/,
    '$1.$2.$3/$4-$5',
  );
}

/** CPF mascarado por privacidade: ***.***.***-09 */
export function maskCPF(v: string): string {
  const digits = v.replace(/\D/g, '');
  if (digits.length < 2) return v;
  const fim = digits.slice(-2);
  return `***.***.***-${fim}`;
}

export function saudacao(d = new Date()): string {
  const h = d.getHours();
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}
