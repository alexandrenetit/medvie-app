// src/pages/Onboarding.tsx
// Orquestrador do onboarding web — máquina de estado + layout "split wizard"
// (rail dark à esquerda, painel do passo à direita). Reaproveita a assinatura
// visual do Login. 100% simulado, sem backend.
//
// Cada passo é dono do próprio rodapé (valida antes de chamar `avancar`). Passos
// ainda não implementados usam um placeholder "em construção". Ver
// HANDOFF_ONBOARDING.md.

import { useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { ProgressBar } from '@/components/ui/Progress';
import { StepRail } from '@/components/onboarding/StepRail';
import { StepHeader, StepFooter, type StepProps } from '@/components/onboarding/StepShell';
import { StepDados } from '@/components/onboarding/steps/StepDados';
import { StepAtuacao } from '@/components/onboarding/steps/StepAtuacao';
import { StepEspecialidade } from '@/components/onboarding/steps/StepEspecialidade';
import { StepCnpj } from '@/components/onboarding/steps/StepCnpj';
import { StepAssinatura } from '@/components/onboarding/steps/StepAssinatura';
import { StepTomadores } from '@/components/onboarding/steps/StepTomadores';
import { StepConfirmacao } from '@/components/onboarding/steps/StepConfirmacao';
import { StepSucesso } from '@/components/onboarding/steps/StepSucesso';
import { Toaster } from '@/components/ui/Toaster';
import {
  mostrarTomadores,
  onboardingDataInicial,
  type OnboardingData,
  type PerfilAtuacaoId,
} from '@/data/onboardingMock';

// ── Definição dos passos ───────────────────────────────────────────────────────
type StepId =
  | 'dados'
  | 'atuacao'
  | 'especialidade'
  | 'cnpj'
  | 'assinatura'
  | 'tomadores'
  | 'confirmacao'
  | 'sucesso';

interface StepDef {
  id: StepId;
  titulo: string;
  railCopy: string;
}

// Passos numerados exibidos no rail (sucesso é terminal, fora da contagem).
const STEPS_BASE: StepDef[] = [
  { id: 'dados', titulo: 'Seus dados', railCopy: 'Vamos configurar seu perfil médico.' },
  { id: 'atuacao', titulo: 'Como você atua?', railCopy: 'Isso define como organizamos suas notas.' },
  { id: 'especialidade', titulo: 'Especialidade', railCopy: 'Sua área de atuação principal.' },
  { id: 'cnpj', titulo: 'Seu CNPJ', railCopy: 'De onde você emite as NFS-e.' },
  { id: 'assinatura', titulo: 'Assinatura digital', railCopy: 'Como sua PJ assina as notas.' },
  { id: 'tomadores', titulo: 'Tomadores', railCopy: 'Hospitais e clínicas onde você atua.' },
  { id: 'confirmacao', titulo: 'Confirmação', railCopy: 'Confira tudo antes de concluir.' },
];

/** Lista de passos considerando o perfil (Tomadores só p/ Plantonista). */
function passosPara(perfil: PerfilAtuacaoId | null): StepDef[] {
  return STEPS_BASE.filter((s) => s.id !== 'tomadores' || mostrarTomadores(perfil));
}

export default function Onboarding() {
  const navigate = useNavigate();
  const reduzirMovimento = useReducedMotion();
  const [data, setData] = useState<OnboardingData>(onboardingDataInicial);
  const [stepId, setStepId] = useState<StepId>('dados');
  const [direcao, setDirecao] = useState<1 | -1>(1);
  const painelRef = useRef<HTMLDivElement>(null);

  const passos = useMemo(() => passosPara(data.perfil), [data.perfil]);
  const isSucesso = stepId === 'sucesso';
  const indiceAtual = passos.findIndex((s) => s.id === stepId);
  const passoAtual = passos[indiceAtual];
  const total = passos.length;
  const ehUltimo = indiceAtual >= total - 1;

  // ── Navegação ────────────────────────────────────────────────────────────────
  function avancar() {
    if (isSucesso) return;
    setDirecao(1);
    if (ehUltimo) {
      setStepId('sucesso'); // confirmação → sucesso
      return;
    }
    setStepId(passos[indiceAtual + 1].id);
  }

  function voltar() {
    setDirecao(-1);
    if (isSucesso) {
      setStepId(passos[total - 1].id);
      return;
    }
    if (indiceAtual <= 0) return; // passo 1 cria a conta — sem retorno
    setStepId(passos[indiceAtual - 1].id);
  }

  function consolidarCnpj(proximoStep: 'cnpj' | 'sucesso') {
    setDirecao(proximoStep === 'sucesso' ? 1 : -1);
    setData((prev) => {
      const atual = prev.cnpjEmEdicao;
      if (!atual) return prev;
      const documentoAtual = atual.lookup.cnpj.replace(/\D/g, '');
      return {
        ...prev,
        cnpjs: [
          ...prev.cnpjs.filter((cnpj) => cnpj.lookup.cnpj.replace(/\D/g, '') !== documentoAtual),
          atual,
        ],
        cnpjEmEdicao: null,
      };
    });
    setStepId(proximoStep);
  }

  function focarPassoAtual() {
    const alvo = painelRef.current?.querySelector<HTMLElement>(
      '[autofocus], [data-step-focus], input:not([disabled]), select:not([disabled]), [role="radio"]',
    );
    alvo?.focus({ preventScroll: true });
  }

  const stepProps: StepProps = { data, setData, avancar, voltar, podeVoltar: indiceAtual > 0 };

  function renderStep() {
    switch (stepId) {
      case 'dados':
        return <StepDados {...stepProps} />;
      case 'atuacao':
        return <StepAtuacao {...stepProps} />;
      case 'especialidade':
        return <StepEspecialidade {...stepProps} />;
      case 'cnpj':
        return <StepCnpj {...stepProps} />;
      case 'assinatura':
        return <StepAssinatura {...stepProps} />;
      case 'tomadores':
        return <StepTomadores {...stepProps} />;
      case 'confirmacao':
        return (
          <StepConfirmacao
            data={data}
            voltar={voltar}
            podeVoltar={indiceAtual > 0}
            onAdicionarCnpj={() => consolidarCnpj('cnpj')}
            onConcluir={() => consolidarCnpj('sucesso')}
          />
        );
      case 'sucesso':
        return <StepSucesso data={data} onComecar={() => navigate('/')} />;
      default:
        return (
          <StepEmConstrucao
            titulo={passoAtual?.titulo ?? ''}
            subtitulo={passoAtual?.railCopy ?? ''}
            labelAvancar={ehUltimo ? 'Concluir' : 'Continuar'}
            {...stepProps}
          />
        );
    }
  }

  return (
    <div className="grid min-h-screen min-w-0 bg-canvas lg:grid-cols-[minmax(300px,380px)_1fr]">
      {/* ── Rail (desktop) ── */}
      <StepRail passos={passos} indiceAtual={isSucesso ? total : indiceAtual} />

      {/* ── Painel do passo ── */}
      <main className="min-w-0 overflow-x-hidden flex flex-col">
        {/* Barra de progresso compacta — só mobile (no desktop o rail já orienta) */}
        <div className="border-b border-line px-6 py-4 lg:hidden">
          <div className="mx-auto flex max-w-lg items-center gap-4">
            <div className="flex-1">
              <ProgressBar value={isSucesso ? total : indiceAtual + 1} max={total} className="h-1.5" />
            </div>
            <span className="shrink-0 text-[12.5px] font-medium text-ink-muted">
              {isSucesso ? 'Concluído' : `Passo ${indiceAtual + 1} de ${total}`}
            </span>
          </div>
        </div>

        <div className="flex flex-1 items-start justify-center px-4 py-8 sm:px-6 sm:py-10 lg:px-10">
          <div className="w-full max-w-lg">
            <AnimatePresence mode="wait" initial={false} custom={direcao}>
              <motion.div
                key={stepId}
                ref={painelRef}
                custom={direcao}
                initial={reduzirMovimento ? false : { x: direcao * 28, opacity: 0 }}
                animate={{ x: 0, opacity: 1 }}
                exit={reduzirMovimento ? { opacity: 1 } : { x: direcao * -20, opacity: 0 }}
                transition={{ duration: reduzirMovimento ? 0 : 0.22, ease: 'easeOut' }}
                onAnimationComplete={focarPassoAtual}
              >
                {renderStep()}
              </motion.div>
            </AnimatePresence>
          </div>
        </div>
      </main>
      <Toaster />
    </div>
  );
}

// ── Placeholder de passo ainda não implementado ────────────────────────────────
function StepEmConstrucao({
  titulo,
  subtitulo,
  labelAvancar,
  avancar,
  voltar,
  podeVoltar,
}: StepProps & { titulo: string; subtitulo: string; labelAvancar: string }) {
  return (
    <div>
      <StepHeader titulo={titulo} subtitulo={subtitulo} />
      <div className="rounded-2xl border border-dashed border-line bg-canvas px-5 py-8 text-center text-[13.5px] text-ink-muted">
        Painel em construção — este passo será implementado em uma task dedicada.
      </div>
      <StepFooter podeVoltar={podeVoltar} onVoltar={voltar} onAvancar={avancar} labelAvancar={labelAvancar} />
    </div>
  );
}
