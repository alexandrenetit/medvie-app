// src/data/onboardingMock.ts
// Dados e helpers SIMULADOS do onboarding web. Nenhuma chamada real — a "consulta
// à Receita Federal" é um setTimeout, como o resto do protótipo. O backend .NET é
// a fonte da verdade no produto; aqui só alimentamos a UI para demonstração.

import { Stethoscope, Syringe, Ambulance, Scissors, type LucideIcon } from 'lucide-react';
import type { RegimeTributario } from '@/types';

// ── Perfil de atuação (espelha enum PerfilAtuacao do medvie-app) ───────────────
export type PerfilAtuacaoId =
  | 'medicoClinico'
  | 'procedimentalistaAmbulatorial'
  | 'plantonistaHospitalar'
  | 'cirurgiao';

export type MetodoAssinatura = 'certificadoA1' | 'govBr';

export interface PerfilAtuacao {
  id: PerfilAtuacaoId;
  titulo: string;
  subtitulo: string;
  icon: LucideIcon;
}

export const perfisAtuacao: PerfilAtuacao[] = [
  {
    id: 'medicoClinico',
    titulo: 'Médico Clínico',
    subtitulo: 'Consultas em consultório próprio ou de terceiros',
    icon: Stethoscope,
  },
  {
    id: 'procedimentalistaAmbulatorial',
    titulo: 'Procedimentalista Ambulatorial',
    subtitulo: 'Procedimentos em clínica — dermatologia, oftalmologia, endoscopia, ginecologia',
    icon: Syringe,
  },
  {
    id: 'plantonistaHospitalar',
    titulo: 'Plantonista / Prestador Hospitalar',
    subtitulo: 'Escalas em hospitais, UTI, emergência ou anestesia — múltiplos tomadores',
    icon: Ambulance,
  },
  {
    id: 'cirurgiao',
    titulo: 'Cirurgião Hospitalar',
    subtitulo: 'Cirurgias eletivas ou de urgência — ortopedia, cirurgia geral, neuro, vascular',
    icon: Scissors,
  },
];

/** Só o Plantonista/Prestador Hospitalar passa pelo cadastro de Tomadores. */
export function mostrarTomadores(perfil: PerfilAtuacaoId | null): boolean {
  return perfil === 'plantonistaHospitalar';
}

// ── Consulta de CNPJ simulada ──────────────────────────────────────────────────
export interface CnpjLookup {
  cnpj: string;
  razaoSocial: string;
  nomeFantasia: string;
  situacao: string; // 'ATIVA' | 'INAPTA' | ...
  porte: string;
  municipio: string;
  uf: string;
  abertura: string; // 'yyyy-MM-dd'
}

// Base fictícia de CNPJs conhecidos (dígitos limpos → resultado).
const CNPJS_CONHECIDOS: Record<string, Omit<CnpjLookup, 'cnpj'>> = {
  '41928663000124': {
    razaoSocial: 'Andrade Lima Serviços Médicos LTDA',
    nomeFantasia: 'RAL Medicina',
    situacao: 'ATIVA',
    porte: 'Micro Empresa',
    municipio: 'São Paulo',
    uf: 'SP',
    abertura: '2019-03-14',
  },
  '33512884000170': {
    razaoSocial: 'RAL Anestesia e Dor EIRELI',
    nomeFantasia: 'Clínica da Dor RAL',
    situacao: 'ATIVA',
    porte: 'Empresa de Pequeno Porte',
    municipio: 'Campinas',
    uf: 'SP',
    abertura: '2021-08-02',
  },
};

/** Só dígitos do CNPJ. */
export function limparCnpj(cnpj: string): string {
  return cnpj.replace(/\D/g, '');
}

/** Aplica a máscara 00.000.000/0000-00 progressivamente. */
export function mascararCnpj(valor: string): string {
  const v = limparCnpj(valor).slice(0, 14);
  if (v.length <= 2) return v;
  if (v.length <= 5) return `${v.slice(0, 2)}.${v.slice(2)}`;
  if (v.length <= 8) return `${v.slice(0, 2)}.${v.slice(2, 5)}.${v.slice(5)}`;
  if (v.length <= 12) return `${v.slice(0, 2)}.${v.slice(2, 5)}.${v.slice(5, 8)}/${v.slice(8)}`;
  return `${v.slice(0, 2)}.${v.slice(2, 5)}.${v.slice(5, 8)}/${v.slice(8, 12)}-${v.slice(12)}`;
}

/**
 * Simula a consulta do CNPJ na Receita Federal (~700ms de latência, como o Login).
 * CNPJ conhecido → dados fixos. Qualquer outro CNPJ de 14 dígitos → resultado
 * genérico ATIVO. CNPJ com dígitos insuficientes → rejeita.
 */
export function consultarCnpjFake(cnpj: string): Promise<CnpjLookup> {
  const digitos = limparCnpj(cnpj);
  return new Promise((resolve, reject) => {
    window.setTimeout(() => {
      if (digitos.length !== 14) {
        reject(new Error('CNPJ deve ter 14 dígitos'));
        return;
      }
      const conhecido = CNPJS_CONHECIDOS[digitos];
      if (conhecido) {
        resolve({ cnpj: mascararCnpj(digitos), ...conhecido });
        return;
      }
      // Genérico — CNPJ válido porém fora da base fictícia.
      resolve({
        cnpj: mascararCnpj(digitos),
        razaoSocial: 'Serviços Médicos LTDA',
        nomeFantasia: 'Consultório Médico',
        situacao: 'ATIVA',
        porte: 'Micro Empresa',
        municipio: 'São Paulo',
        uf: 'SP',
        abertura: '2020-01-10',
      });
    }, 700);
  });
}

// ── Estado acumulado do onboarding ─────────────────────────────────────────────
export interface DadosPessoais {
  nome: string;
  cpf: string;
  crm: string;
  ufCrm: string;
  email: string;
  telefone: string;
  senha: string;
}

export interface TomadorOnb {
  cnpj: string;
  razaoSocial: string;
  municipio: string;
  uf: string;
  valorPadrao?: number;
  emailFinanceiro?: string;
  retemIss: boolean;
  aliquotaIss: number;
  retemIrrf: boolean;
  aliquotaIrrf: number;
}

export interface CnpjOnb {
  lookup: CnpjLookup;
  inscricaoMunicipal: string;
  regime: RegimeTributario;
  metodoAssinatura: MetodoAssinatura;
  certificadoAnexado: boolean;
  tomadores: TomadorOnb[];
}

export interface OnboardingData {
  dados: DadosPessoais;
  perfil: PerfilAtuacaoId | null;
  especialidade: string | null;
  /** CNPJ em construção nos passos 2a→2b→3. Commitado em `cnpjs` na confirmação. */
  cnpjEmEdicao: CnpjOnb | null;
  cnpjs: CnpjOnb[];
}

/** Cria um CNPJ de trabalho a partir do resultado da consulta, com defaults. */
export function novoCnpjOnb(lookup: CnpjLookup): CnpjOnb {
  return {
    lookup,
    inscricaoMunicipal: '',
    regime: 'lucroPresumido',
    metodoAssinatura: 'certificadoA1',
    certificadoAnexado: false,
    tomadores: [],
  };
}

export const dadosPessoaisVazio: DadosPessoais = {
  nome: '',
  cpf: '',
  crm: '',
  ufCrm: 'SP',
  email: '',
  telefone: '',
  senha: '',
};

export const onboardingDataInicial: OnboardingData = {
  dados: dadosPessoaisVazio,
  perfil: null,
  especialidade: null,
  cnpjEmEdicao: null,
  cnpjs: [],
};

// Regimes oferecidos no onboarding — só Simples/Presumido (Lucro Real fica fora,
// como no medvie-app).
export const regimesOnboarding: RegimeTributario[] = ['simplesNacional', 'lucroPresumido'];
