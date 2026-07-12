// src/components/onboarding/steps/StepDados.tsx
// Passo 1a — Dados pessoais + criação de senha. Espelha os campos do medvie-app
// (nome, CPF, CRM+UF, e-mail, telefone, senha + força, confirmar). Validação
// inline; só avança quando o formulário está válido. 100% simulado.

import { useState } from 'react';
import { Lock } from 'lucide-react';
import { Field, Input, Select } from '@/components/ui/Field';
import { PasswordStrength } from '@/components/onboarding/PasswordStrength';
import { StepHeader, StepFooter, type StepProps } from '@/components/onboarding/StepShell';
import type { DadosPessoais } from '@/data/onboardingMock';

const UFS = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
  'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

const soDigitos = (v: string) => v.replace(/\D/g, '');

function mascararCpf(v: string): string {
  const n = soDigitos(v).slice(0, 11);
  if (n.length <= 3) return n;
  if (n.length <= 6) return `${n.slice(0, 3)}.${n.slice(3)}`;
  if (n.length <= 9) return `${n.slice(0, 3)}.${n.slice(3, 6)}.${n.slice(6)}`;
  return `${n.slice(0, 3)}.${n.slice(3, 6)}.${n.slice(6, 9)}-${n.slice(9)}`;
}

function mascararTelefone(v: string): string {
  const n = soDigitos(v).slice(0, 11);
  if (n.length <= 2) return n;
  if (n.length <= 7) return `(${n.slice(0, 2)}) ${n.slice(2)}`;
  return `(${n.slice(0, 2)}) ${n.slice(2, 7)}-${n.slice(7)}`;
}

type Erros = Partial<Record<keyof DadosPessoais, string>>;

export function StepDados({ data, setData, avancar, voltar, podeVoltar }: StepProps) {
  const d = data.dados;
  const [erros, setErros] = useState<Erros>({});

  function set<K extends keyof DadosPessoais>(campo: K, valor: DadosPessoais[K]) {
    setData((prev) => ({ ...prev, dados: { ...prev.dados, [campo]: valor } }));
    if (erros[campo]) setErros((e) => ({ ...e, [campo]: undefined }));
  }

  function validar(): boolean {
    const e: Erros = {};
    if (!d.nome.trim()) e.nome = 'Informe seu nome';
    if (soDigitos(d.cpf).length !== 11) e.cpf = 'CPF inválido';
    if (!d.crm.trim()) e.crm = 'Informe o CRM';
    if (!d.email.includes('@')) e.email = 'E-mail inválido';
    if (soDigitos(d.telefone).length < 10) e.telefone = 'Telefone inválido';
    if (d.senha.length < 8) e.senha = 'Mínimo 8 caracteres';
    if (d.confirmarSenha !== d.senha) e.confirmarSenha = 'As senhas não conferem';
    setErros(e);
    return Object.keys(e).length === 0;
  }

  function handleAvancar() {
    if (validar()) avancar();
  }

  return (
    <form
      onSubmit={(ev) => {
        ev.preventDefault();
        handleAvancar();
      }}
    >
      <StepHeader titulo="Seus dados" subtitulo="Vamos configurar seu perfil médico." />

      <div className="space-y-4">
        <Field label="Nome completo" error={erros.nome}>
          <Input
            autoFocus
            value={d.nome}
            onChange={(e) => set('nome', e.target.value)}
            placeholder="Dr. Alexandre Silva"
            autoComplete="name"
          />
        </Field>

        <Field label="CPF" error={erros.cpf}>
          <Input
            value={d.cpf}
            onChange={(e) => set('cpf', mascararCpf(e.target.value))}
            placeholder="000.000.000-00"
            inputMode="numeric"
            className="num"
          />
        </Field>

        <div className="grid grid-cols-[1fr_110px] gap-3">
          <Field label="CRM" error={erros.crm}>
            <Input
              value={d.crm}
              onChange={(e) => set('crm', soDigitos(e.target.value))}
              placeholder="123456"
              inputMode="numeric"
              className="num"
            />
          </Field>
          <Field label="UF">
            <Select value={d.ufCrm} onChange={(e) => set('ufCrm', e.target.value)}>
              {UFS.map((uf) => (
                <option key={uf} value={uf}>
                  {uf}
                </option>
              ))}
            </Select>
          </Field>
        </div>

        <Field label="E-mail" error={erros.email}>
          <Input
            type="email"
            value={d.email}
            onChange={(e) => set('email', e.target.value)}
            placeholder="seu.email@exemplo.com"
            autoComplete="email"
          />
        </Field>

        <Field label="Telefone celular" error={erros.telefone}>
          <Input
            value={d.telefone}
            onChange={(e) => set('telefone', mascararTelefone(e.target.value))}
            placeholder="(11) 99999-9999"
            inputMode="tel"
            className="num"
          />
        </Field>

        <div className="!mt-6 border-t border-line pt-6">
          <p className="mb-4 text-[13.5px] font-semibold text-ink">Crie sua senha</p>

          <Field label="Senha" error={erros.senha}>
            <div className="relative">
              <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
              <Input
                type="password"
                value={d.senha}
                onChange={(e) => set('senha', e.target.value)}
                placeholder="Mínimo 8 caracteres"
                autoComplete="new-password"
                className="pl-10"
              />
            </div>
            <PasswordStrength senha={d.senha} />
          </Field>

          <Field label="Confirmar senha" error={erros.confirmarSenha} className="mt-4">
            <Input
              type="password"
              value={d.confirmarSenha}
              onChange={(e) => set('confirmarSenha', e.target.value)}
              placeholder="Repita a senha"
              autoComplete="new-password"
            />
          </Field>
        </div>
      </div>

      <StepFooter podeVoltar={podeVoltar} onVoltar={voltar} onAvancar={handleAvancar} />
    </form>
  );
}
