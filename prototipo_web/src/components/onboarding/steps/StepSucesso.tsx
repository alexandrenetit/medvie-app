// src/components/onboarding/steps/StepSucesso.tsx
// Passo 5 — conclusão animada e resumo enxuto da configuração finalizada.

import { motion, useReducedMotion } from 'framer-motion';
import { ArrowRight, Building2, Check, Hospital } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import type { OnboardingData } from '@/data/onboardingMock';

export function StepSucesso({ data, onComecar }: { data: OnboardingData; onComecar: () => void }) {
  const reduzirMovimento = useReducedMotion();
  const primeiroNome = data.dados.nome.trim().split(' ')[0] || '';
  const totalTomadores = data.cnpjs.reduce((total, cnpj) => total + cnpj.tomadores.length, 0);

  return (
    <div className="flex min-h-[68vh] flex-col items-center justify-center py-8 text-center">
      <motion.div
        initial={reduzirMovimento ? false : { scale: 0.35, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ type: 'spring', stiffness: 220, damping: 14 }}
        className="grid h-24 w-24 place-items-center rounded-full border-2 border-brand-200 bg-brand-50 text-brand-600"
      >
        <Check size={48} strokeWidth={2.5} />
      </motion.div>

      <motion.div
        initial={reduzirMovimento ? false : { y: 14, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.35, delay: reduzirMovimento ? 0 : 0.18 }}
      >
        <h1 className="mt-7 font-brand text-[28px] font-bold leading-tight text-ink">
          Tudo configurado{primeiroNome ? `, Dr. ${primeiroNome}` : ''}!
        </h1>
        <p className="mx-auto mt-3 max-w-md text-[14.5px] leading-relaxed text-ink-muted">
          Seu perfil e CNPJ estão prontos. Agora você pode emitir NFS-e diretamente pelo Medvie.
        </p>

        <div className="mt-7 flex flex-wrap justify-center gap-2.5">
          <Resumo
            icon={Building2}
            texto={`${data.cnpjs.length} ${data.cnpjs.length === 1 ? 'CNPJ ativo' : 'CNPJs ativos'}`}
            tom="brand"
          />
          <Resumo
            icon={Hospital}
            texto={`${totalTomadores} ${totalTomadores === 1 ? 'tomador cadastrado' : 'tomadores cadastrados'}`}
            tom="info"
          />
        </div>

        <Button className="mt-9" onClick={onComecar}>
          Começar a usar <ArrowRight size={17} />
        </Button>
      </motion.div>
    </div>
  );
}

function Resumo({
  icon: Icon,
  texto,
  tom,
}: {
  icon: typeof Building2;
  texto: string;
  tom: 'brand' | 'info';
}) {
  const classes = tom === 'brand' ? 'bg-brand-50 text-brand-700' : 'bg-info-50 text-info-700';
  return (
    <span className={`inline-flex items-center gap-2 rounded-full px-3.5 py-2 text-[12.5px] font-semibold ${classes}`}>
      <Icon size={15} /> {texto}
    </span>
  );
}
