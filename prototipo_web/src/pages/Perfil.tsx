import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  User,
  Stethoscope,
  Building2,
  Users,
  ShieldCheck,
  Lock,
  Mail,
  Phone,
  BadgeCheck,
  UploadCloud,
  RefreshCw,
  Trash2,
  ShieldAlert,
  KeyRound,
  Smartphone,
  CheckCircle2,
  type LucideIcon,
} from 'lucide-react';
import { Card, CardHeader } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';
import { StatusChip } from '@/components/ui/StatusChip';
import { useAppState } from '@/context/AppState';
import { medico, tomadores } from '@/data/mock';
import { money, dataBR } from '@/lib/format';
import { regimeMeta, statusCertificadoMeta } from '@/data/domain';
import { cn } from '@/lib/cn';

type Secao = 'dados' | 'profissional' | 'empresas' | 'tomadores' | 'certificado' | 'seguranca';

const secoes: { id: Secao; label: string; icon: LucideIcon }[] = [
  { id: 'dados', label: 'Dados pessoais', icon: User },
  { id: 'profissional', label: 'Profissional', icon: Stethoscope },
  { id: 'empresas', label: 'Empresas (CNPJ)', icon: Building2 },
  { id: 'tomadores', label: 'Tomadores', icon: Users },
  { id: 'certificado', label: 'Certificado digital', icon: ShieldCheck },
  { id: 'seguranca', label: 'Segurança', icon: Lock },
];

export default function Perfil() {
  const [params] = useSearchParams();
  const inicial = (params.get('secao') as Secao) ?? 'dados';
  const [secao, setSecao] = useState<Secao>(secoes.some((s) => s.id === inicial) ? inicial : 'dados');

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-brand text-[24px] font-bold text-ink">Perfil e empresa</h1>
        <p className="mt-0.5 text-[14px] text-ink-muted">
          Gerencie seus dados profissionais, empresas e credenciais de emissão.
        </p>
      </div>

      <div className="grid gap-5 lg:grid-cols-[220px_minmax(0,1fr)]">
        {/* Nav de seções */}
        <nav className="flex gap-1 overflow-x-auto lg:flex-col lg:overflow-visible">
          {secoes.map((s) => {
            const ativo = s.id === secao;
            return (
              <button
                key={s.id}
                onClick={() => setSecao(s.id)}
                className={cn(
                  'flex shrink-0 items-center gap-2.5 rounded-xl px-3.5 py-2.5 text-[13.5px] font-medium transition-colors lg:w-full',
                  ativo ? 'bg-card text-ink shadow-card' : 'text-ink-muted hover:bg-line2/60 hover:text-ink',
                )}
              >
                <s.icon size={17} className={ativo ? 'text-brand-600' : ''} />
                {s.label}
              </button>
            );
          })}
        </nav>

        <div className="min-w-0">
          {secao === 'dados' && <SecaoDados />}
          {secao === 'profissional' && <SecaoProfissional />}
          {secao === 'empresas' && <SecaoEmpresas />}
          {secao === 'tomadores' && <SecaoTomadores />}
          {secao === 'certificado' && <SecaoCertificado />}
          {secao === 'seguranca' && <SecaoSeguranca />}
        </div>
      </div>
    </div>
  );
}

// ── Dados pessoais ───────────────────────────────────────────────────────────
function SecaoDados() {
  const { pushToast } = useAppState();
  return (
    <Card>
      <CardHeader title="Dados pessoais" subtitle="Informações da sua conta" />
      <div className="grid gap-4 p-5 sm:grid-cols-2">
        <Field label="Nome completo">
          <Input defaultValue={medico.nome} />
        </Field>
        <Field label="CPF" hint="Mascarado por segurança">
          <Input defaultValue={medico.cpf} readOnly className="num bg-canvas" />
        </Field>
        <Field label="E-mail">
          <div className="relative">
            <Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
            <Input defaultValue={medico.email} className="pl-10" />
          </div>
        </Field>
        <Field label="Telefone">
          <div className="relative">
            <Phone size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
            <Input defaultValue={medico.telefone} className="num pl-10" />
          </div>
        </Field>
      </div>
      <div className="flex justify-end gap-3 border-t border-line px-5 py-4">
        <Button variant="ghost" size="sm">Cancelar</Button>
        <Button size="sm" onClick={() => pushToast({ tipo: 'sucesso', titulo: 'Dados salvos' })}>
          Salvar alterações
        </Button>
      </div>
    </Card>
  );
}

// ── Profissional ─────────────────────────────────────────────────────────────
function SecaoProfissional() {
  return (
    <Card>
      <CardHeader title="Dados profissionais" subtitle="Registro no conselho e especialidade" />
      <div className="grid gap-4 p-5 sm:grid-cols-2">
        <Field label="CRM">
          <Input defaultValue={medico.crm} className="num" />
        </Field>
        <Field label="UF do CRM">
          <Input defaultValue={medico.ufCrm} />
        </Field>
        <Field label="Especialidade" className="sm:col-span-2">
          <Input defaultValue={medico.especialidade} />
        </Field>
      </div>
      <div className="mx-5 mb-5 flex items-center gap-3 rounded-xl bg-brand-50/50 px-4 py-3">
        <BadgeCheck size={18} className="text-brand-600" />
        <p className="text-[13px] text-ink-soft">
          CRM validado junto ao conselho. Habilita a emissão de NFS-e de serviços médicos.
        </p>
      </div>
    </Card>
  );
}

// ── Empresas ─────────────────────────────────────────────────────────────────
function SecaoEmpresas() {
  return (
    <div className="space-y-4">
      {medico.cnpjs.map((c) => (
        <Card key={c.id}>
          <div className="flex flex-col gap-3 border-b border-line p-5 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-3">
              <span className="grid h-11 w-11 place-items-center rounded-xl bg-canvas text-ink-soft">
                <Building2 size={20} />
              </span>
              <div>
                <p className="text-[15px] font-semibold text-ink">{c.razaoSocial}</p>
                <p className="num text-[13px] text-ink-muted">{c.cnpj}</p>
              </div>
            </div>
            <StatusChip {...statusCertificadoMeta[c.certificado.status]} />
          </div>
          <div className="grid gap-4 p-5 sm:grid-cols-3">
            <Info label="Regime tributário" valor={regimeMeta[c.regime].label} />
            <Info label="Município" valor={`${c.municipio}/${c.uf}`} />
            <Info label="Inscrição municipal" valor={c.inscricaoMunicipal} mono />
            <Info label="Nome fantasia" valor={c.nomeFantasia} />
            <Info label="Método de assinatura" valor={c.metodoAssinatura === 'certificadoA1' ? 'e-CNPJ (A1)' : 'gov.br'} />
            <Info label="Provedor fiscal" valor={c.certificado.provider} />
          </div>
        </Card>
      ))}
    </div>
  );
}

// ── Tomadores ────────────────────────────────────────────────────────────────
function SecaoTomadores() {
  const cnpjTomadores = tomadores.filter((t) => t.tipo === 'cnpj');
  const pf = tomadores.filter((t) => t.tipo === 'cpf');
  return (
    <Card>
      <CardHeader title="Tomadores" subtitle={`${tomadores.length} cadastrados`} icon={<Users size={18} />} />
      <div className="overflow-x-auto">
        <table className="w-full min-w-[560px] text-[13.5px]">
          <thead>
            <tr className="border-y border-line text-left text-[12px] font-semibold uppercase tracking-wide text-ink-faint">
              <th className="px-5 py-2.5">Nome</th>
              <th className="px-3 py-2.5">Tipo</th>
              <th className="px-3 py-2.5">Município</th>
              <th className="px-3 py-2.5 text-right">Valor padrão</th>
              <th className="px-5 py-2.5">Endereço fiscal</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line2">
            {[...cnpjTomadores, ...pf].map((t) => (
              <tr key={t.id} className="hover:bg-line2/40">
                <td className="px-5 py-2.5">
                  <p className="font-medium text-ink">{t.nome}</p>
                  <p className="num text-[11.5px] text-ink-muted">{t.documento}</p>
                </td>
                <td className="px-3 py-2.5 text-ink-soft">
                  {t.tipo === 'cpf' ? 'Paciente' : 'Empresa'}
                </td>
                <td className="px-3 py-2.5 text-ink-muted">{t.municipio}/{t.uf}</td>
                <td className="num px-3 py-2.5 text-right text-ink">
                  {t.valorPadrao ? money(t.valorPadrao) : '—'}
                </td>
                <td className="px-5 py-2.5">
                  {t.enderecoFiscalCompleto ? (
                    <StatusChip label="Completo" tone="brand" />
                  ) : (
                    <StatusChip label="Incompleto" tone="warn" />
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

// ── Certificado digital ──────────────────────────────────────────────────────
function SecaoCertificado() {
  const { pushToast } = useAppState();
  return (
    <div className="space-y-4">
      {medico.cnpjs.map((c) => {
        const cert = c.certificado;
        const alerta = cert.diasParaVencer <= 30;
        return (
          <Card key={c.id}>
            <div className="flex items-start justify-between gap-4 border-b border-line p-5">
              <div className="flex items-center gap-3">
                <span
                  className={cn(
                    'grid h-11 w-11 place-items-center rounded-xl',
                    alerta ? 'bg-warn-50 text-warn-600' : 'bg-brand-50 text-brand-600',
                  )}
                >
                  {alerta ? <ShieldAlert size={22} /> : <ShieldCheck size={22} />}
                </span>
                <div>
                  <p className="text-[15px] font-semibold text-ink">{c.nomeFantasia}</p>
                  <p className="num text-[12.5px] text-ink-muted">{cert.subjectCnpj}</p>
                </div>
              </div>
              <StatusChip {...statusCertificadoMeta[cert.status]} />
            </div>

            {alerta && (
              <div className="mx-5 mt-4 flex items-center gap-2.5 rounded-xl border border-warn-100 bg-warn-50/60 px-4 py-3">
                <ShieldAlert size={17} className="text-warn-600" />
                <p className="text-[13px] text-ink-soft">
                  Vence em <span className="font-semibold text-warn-700">{cert.diasParaVencer} dias</span>.
                  Renove para não interromper a emissão automática de NFS-e.
                </p>
              </div>
            )}

            <div className="grid gap-4 p-5 sm:grid-cols-3">
              <Info label="Validade" valor={`${dataBR(cert.validFrom)} → ${dataBR(cert.validUntil)}`} />
              <Info
                label="Dias para vencer"
                valor={`${cert.diasParaVencer} dias`}
                tone={alerta ? 'warn' : 'brand'}
              />
              <Info label="Provedor" valor={cert.provider} />
              <Info label="Emissor" valor={cert.issuerName} />
              <Info label="Tipo" valor="e-CNPJ A1 (.pfx)" />
              <Info label="Fingerprint" valor={cert.fingerprint} mono />
            </div>

            {/* Upload simulado */}
            <div className="mx-5 mb-5 rounded-xl border border-dashed border-line bg-canvas p-5 text-center">
              <UploadCloud size={22} className="mx-auto text-ink-faint" />
              <p className="mt-2 text-[13.5px] font-medium text-ink">
                Substituir certificado
              </p>
              <p className="text-[12px] text-ink-muted">
                Arraste um arquivo .pfx ou .p12, ou selecione manualmente (upload simulado).
              </p>
              <div className="mt-3 flex justify-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() =>
                    pushToast({ tipo: 'info', titulo: 'Upload simulado', descricao: 'No protótipo, nenhum arquivo é enviado.' })
                  }
                >
                  <RefreshCw size={15} /> Selecionar arquivo
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-danger-600 hover:bg-danger-50"
                  onClick={() =>
                    pushToast({ tipo: 'atencao', titulo: 'Remoção bloqueada', descricao: 'Emissão automática ficaria suspensa. Ação simulada.' })
                  }
                >
                  <Trash2 size={15} /> Remover
                </Button>
              </div>
            </div>
          </Card>
        );
      })}
    </div>
  );
}

// ── Segurança ────────────────────────────────────────────────────────────────
function SecaoSeguranca() {
  const { pushToast } = useAppState();
  const [doisFatores, setDoisFatores] = useState(true);
  return (
    <div className="space-y-4">
      <Card>
        <CardHeader title="Senha" subtitle="Atualize periodicamente" icon={<KeyRound size={18} />} />
        <div className="grid gap-4 p-5 sm:grid-cols-2">
          <Field label="Senha atual" className="sm:col-span-2">
            <Input type="password" placeholder="••••••••" />
          </Field>
          <Field label="Nova senha">
            <Input type="password" placeholder="••••••••" />
          </Field>
          <Field label="Confirmar nova senha">
            <Input type="password" placeholder="••••••••" />
          </Field>
        </div>
        <div className="flex justify-end border-t border-line px-5 py-4">
          <Button size="sm" onClick={() => pushToast({ tipo: 'sucesso', titulo: 'Senha atualizada' })}>
            Atualizar senha
          </Button>
        </div>
      </Card>

      <Card>
        <div className="flex items-center justify-between p-5">
          <div className="flex items-center gap-3">
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-brand-50 text-brand-600">
              <Smartphone size={19} />
            </span>
            <div>
              <p className="text-[14.5px] font-semibold text-ink">Verificação em duas etapas</p>
              <p className="text-[13px] text-ink-muted">Proteção extra com código no celular</p>
            </div>
          </div>
          <Toggle
            checked={doisFatores}
            onChange={(v) => {
              setDoisFatores(v);
              pushToast({ tipo: v ? 'sucesso' : 'atencao', titulo: v ? '2FA ativado' : '2FA desativado' });
            }}
          />
        </div>
      </Card>

      <Card>
        <CardHeader title="Sessão ativa" icon={<CheckCircle2 size={18} className="text-brand-600" />} />
        <div className="flex items-center justify-between px-5 pb-5 pt-1">
          <div>
            <p className="text-[13.5px] font-medium text-ink">Chrome · Windows — São Paulo</p>
            <p className="text-[12px] text-ink-muted">Sessão atual · agora</p>
          </div>
          <StatusChip label="Este dispositivo" tone="brand" />
        </div>
      </Card>
    </div>
  );
}

// ── auxiliares ───────────────────────────────────────────────────────────────
function Info({
  label,
  valor,
  mono,
  tone,
}: {
  label: string;
  valor: string;
  mono?: boolean;
  tone?: 'warn' | 'brand';
}) {
  const cor = tone === 'warn' ? 'text-warn-600' : tone === 'brand' ? 'text-brand-700' : 'text-ink';
  return (
    <div>
      <p className="text-[11.5px] font-semibold uppercase tracking-wide text-ink-faint">{label}</p>
      <p className={cn('mt-1 text-[13.5px] font-medium', mono && 'num', cor)}>{valor}</p>
    </div>
  );
}

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={cn(
        'relative h-6 w-11 rounded-full transition-colors',
        checked ? 'bg-brand-500' : 'bg-line',
      )}
    >
      <span
        className={cn(
          'absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform',
          checked ? 'left-0.5 translate-x-5' : 'left-0.5',
        )}
      />
    </button>
  );
}
