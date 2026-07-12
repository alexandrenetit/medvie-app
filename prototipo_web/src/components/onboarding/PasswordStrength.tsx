// src/components/onboarding/PasswordStrength.tsx
// Indicador de força de senha — mesma regra do medvie-app: vazio → nada;
// < 8 caracteres → fraca; com número E caractere especial → forte; senão → média.

import { cn } from '@/lib/cn';

type Forca = 'vazio' | 'fraca' | 'media' | 'forte';

function avaliar(senha: string): Forca {
  if (senha.length === 0) return 'vazio';
  if (senha.length < 8) return 'fraca';
  const temNumero = /[0-9]/.test(senha);
  const temEspecial = /[!@#$%^&*(),.?":{}|<>]/.test(senha);
  if (temNumero && temEspecial) return 'forte';
  return 'media';
}

const META: Record<Exclude<Forca, 'vazio'>, { label: string; fracao: number; barra: string; texto: string }> = {
  fraca: { label: 'Fraca', fracao: 1 / 3, barra: 'bg-danger-500', texto: 'text-danger-600' },
  media: { label: 'Média', fracao: 2 / 3, barra: 'bg-warn-500', texto: 'text-warn-600' },
  forte: { label: 'Forte', fracao: 1, barra: 'bg-brand-500', texto: 'text-brand-600' },
};

export function PasswordStrength({ senha }: { senha: string }) {
  const forca = avaliar(senha);
  if (forca === 'vazio') return null;
  const { label, fracao, barra, texto } = META[forca];

  return (
    <div className="mt-2">
      <div className="h-1 w-full overflow-hidden rounded-full bg-line2">
        <div
          className={cn('h-full rounded-full transition-all duration-300', barra)}
          style={{ width: `${fracao * 100}%` }}
        />
      </div>
      <p className={cn('mt-1 text-[12px] font-medium', texto)}>Senha {label}</p>
    </div>
  );
}
