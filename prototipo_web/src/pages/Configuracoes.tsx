import { useState } from 'react';
import {
  Bell,
  Palette,
  Globe,
  Building2,
  Info,
  Mail,
  MessageSquare,
  Smartphone,
} from 'lucide-react';
import { Card, CardHeader } from '@/components/ui/Card';
import { Select } from '@/components/ui/Field';
import { useAppState } from '@/context/AppState';
import { medico } from '@/data/mock';
import { cn } from '@/lib/cn';

export default function Configuracoes() {
  const { pushToast, cnpjAtivoId, setCnpjAtivoId } = useAppState();
  const [notif, setNotif] = useState({ email: true, push: true, sms: false });

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-brand text-[24px] font-bold text-ink">Configurações</h1>
        <p className="mt-0.5 text-[14px] text-ink-muted">
          Preferências de notificação, exibição e conta.
        </p>
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        {/* Notificações */}
        <Card>
          <CardHeader title="Notificações" subtitle="Como você quer ser avisado" icon={<Bell size={18} />} />
          <div className="divide-y divide-line2">
            <ToggleRow
              icon={Mail}
              titulo="E-mail"
              texto="Notas emitidas, rejeições e recebimentos"
              checked={notif.email}
              onChange={(v) => setNotif((n) => ({ ...n, email: v }))}
            />
            <ToggleRow
              icon={Smartphone}
              titulo="Push no aplicativo"
              texto="Alertas em tempo real de emissão"
              checked={notif.push}
              onChange={(v) => setNotif((n) => ({ ...n, push: v }))}
            />
            <ToggleRow
              icon={MessageSquare}
              titulo="SMS"
              texto="Apenas alertas críticos (certificado vencendo)"
              checked={notif.sms}
              onChange={(v) => setNotif((n) => ({ ...n, sms: v }))}
            />
          </div>
        </Card>

        {/* Exibição */}
        <Card>
          <CardHeader title="Exibição" subtitle="Aparência e formato" icon={<Palette size={18} />} />
          <div className="space-y-4 p-5">
            <SelectRow label="Tema" icon={Palette}>
              <Select defaultValue="claro" className="w-40">
                <option value="claro">Claro</option>
                <option value="auto" disabled>
                  Automático (em breve)
                </option>
              </Select>
            </SelectRow>
            <SelectRow label="Idioma" icon={Globe}>
              <Select defaultValue="pt-BR" className="w-40">
                <option value="pt-BR">Português (BR)</option>
              </Select>
            </SelectRow>
            <SelectRow label="Empresa padrão" icon={Building2}>
              <Select
                value={cnpjAtivoId}
                onChange={(e) => setCnpjAtivoId(e.target.value)}
                className="w-48"
              >
                {medico.cnpjs.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.nomeFantasia}
                  </option>
                ))}
              </Select>
            </SelectRow>
          </div>
        </Card>

        {/* Conta */}
        <Card className="lg:col-span-2">
          <CardHeader title="Conta" subtitle="Ações administrativas" icon={<Info size={18} />} />
          <div className="flex flex-col gap-3 p-5 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-[14px] font-semibold text-ink">{medico.nome}</p>
              <p className="text-[13px] text-ink-muted">
                {medico.email} · CRM {medico.crm}/{medico.ufCrm}
              </p>
            </div>
            <button
              onClick={() =>
                pushToast({ tipo: 'info', titulo: 'Exportação solicitada', descricao: 'Enviaremos seus dados por e-mail (simulado).' })
              }
              className="btn btn-outline btn-sm w-fit"
            >
              Exportar meus dados
            </button>
          </div>
        </Card>
      </div>

      <div className="flex items-start gap-3 rounded-2xl border border-info-100 bg-info-50/50 p-4">
        <Info size={18} className="mt-0.5 shrink-0 text-info-600" />
        <p className="text-[13px] text-ink-soft">
          Este é um <span className="font-semibold">protótipo navegável</span>. Todas as ações são
          simuladas — nenhum dado é enviado, armazenado ou conectado a serviços reais.
        </p>
      </div>
    </div>
  );
}

function ToggleRow({
  icon: Icon,
  titulo,
  texto,
  checked,
  onChange,
}: {
  icon: typeof Mail;
  titulo: string;
  texto: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-4 px-5 py-4">
      <div className="flex items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-lg bg-canvas text-ink-soft">
          <Icon size={17} />
        </span>
        <div>
          <p className="text-[13.5px] font-semibold text-ink">{titulo}</p>
          <p className="text-[12.5px] text-ink-muted">{texto}</p>
        </div>
      </div>
      <button
        role="switch"
        aria-checked={checked}
        aria-label={titulo}
        onClick={() => onChange(!checked)}
        className={cn('relative h-6 w-11 shrink-0 rounded-full transition-colors', checked ? 'bg-brand-500' : 'bg-line')}
      >
        <span
          className={cn(
            'absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform',
            checked ? 'translate-x-5' : 'translate-x-0.5',
          )}
        />
      </button>
    </div>
  );
}

function SelectRow({
  label,
  icon: Icon,
  children,
}: {
  label: string;
  icon: typeof Palette;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-4">
      <div className="flex items-center gap-2.5 text-[13.5px] font-medium text-ink-soft">
        <Icon size={16} className="text-ink-muted" />
        {label}
      </div>
      {children}
    </div>
  );
}
