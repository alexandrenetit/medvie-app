import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, ShieldCheck, ArrowRight, Loader2, FileCheck2, TrendingUp, Clock } from 'lucide-react';
import { Logo, LogoMark } from '@/components/Logo';
import { Button } from '@/components/ui/Button';
import { Field, Input } from '@/components/ui/Field';

// Login SIMULADO — nenhuma autenticação real, nenhum token armazenado.
export default function Login() {
  const navigate = useNavigate();
  const [cpf, setCpf] = useState('');
  const [senha, setSenha] = useState('');
  const [lembrar, setLembrar] = useState(true);
  const [entrando, setEntrando] = useState(false);

  function entrar() {
    setEntrando(true);
    // Apenas simula latência de rede e navega — sem chamada de backend.
    setTimeout(() => navigate('/'), 700);
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-[1fr_1.05fr]">
      {/* Coluna do formulário */}
      <div className="flex flex-col justify-center px-6 py-10 sm:px-12 lg:px-16 xl:px-24">
        <div className="mx-auto w-full max-w-sm">
          <Logo />
          <div className="mt-12">
            <h1 className="font-brand text-[28px] font-bold leading-tight text-ink">
              Sua vida financeira e fiscal, sob controle.
            </h1>
            <p className="mt-2 text-[15px] text-ink-muted">
              Entre para acompanhar seus honorários, notas e impostos em um só lugar.
            </p>
          </div>

          <form
            className="mt-8 space-y-4"
            onSubmit={(e) => {
              e.preventDefault();
              entrar();
            }}
          >
            <Field label="CPF">
              <Input
                value={cpf}
                onChange={(e) => setCpf(e.target.value)}
                placeholder="000.000.000-00"
                inputMode="numeric"
                autoComplete="username"
              />
            </Field>
            <Field label="Senha">
              <div className="relative">
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-faint" />
                <Input
                  type="password"
                  value={senha}
                  onChange={(e) => setSenha(e.target.value)}
                  placeholder="••••••••"
                  autoComplete="current-password"
                  className="pl-10"
                />
              </div>
            </Field>

            <div className="flex items-center justify-between pt-0.5">
              <label className="flex cursor-pointer select-none items-center gap-2 text-[13.5px] text-ink-soft">
                <input
                  type="checkbox"
                  checked={lembrar}
                  onChange={(e) => setLembrar(e.target.checked)}
                  className="h-4 w-4 rounded border-line text-brand-600 focus:ring-brand-500"
                />
                Lembrar acesso
              </label>
              <button type="button" className="text-[13.5px] font-semibold text-brand-600 hover:text-brand-700">
                Recuperar senha
              </button>
            </div>

            <Button type="submit" size="md" className="w-full" disabled={entrando}>
              {entrando ? (
                <>
                  <Loader2 size={17} className="animate-spin" /> Entrando…
                </>
              ) : (
                <>
                  Entrar <ArrowRight size={17} />
                </>
              )}
            </Button>

            <Button
              type="button"
              variant="outline"
              size="md"
              className="w-full"
              onClick={() => navigate('/')}
            >
              Acesso demonstrativo
            </Button>
          </form>

          <div className="mt-8 flex items-center gap-2 rounded-xl bg-canvas px-3.5 py-3 text-[12.5px] text-ink-muted">
            <ShieldCheck size={16} className="shrink-0 text-brand-600" />
            Conexão segura. Seus dados fiscais são protegidos e nunca compartilhados.
          </div>
        </div>
      </div>

      {/* Coluna visual — proposta de valor */}
      <div className="relative hidden overflow-hidden bg-sidebar lg:block">
        <div
          className="absolute inset-0 opacity-[0.14]"
          style={{
            backgroundImage:
              'radial-gradient(circle at 20% 20%, #12CE97 0, transparent 40%), radial-gradient(circle at 80% 70%, #2E8FE6 0, transparent 45%)',
          }}
        />
        <div className="absolute inset-0 bg-[linear-gradient(180deg,transparent,rgba(11,21,36,0.6))]" />

        <div className="relative flex h-full flex-col justify-between p-12 xl:p-16">
          <div className="flex items-center gap-2.5">
            <LogoMark size={30} />
            <span className="font-brand text-[17px] font-semibold text-white/80">
              Medvie para médicos PJ
            </span>
          </div>

          <div className="max-w-md">
            <p className="font-brand text-[30px] font-semibold leading-[1.25] text-white">
              Do plantão à nota fiscal emitida, sem planilha e sem contador no meio do caminho.
            </p>

            <div className="mt-10 space-y-4">
              <ValorItem
                icon={FileCheck2}
                titulo="NFS-e automática"
                texto="Registre o atendimento; a nota é emitida e assinada pelo seu certificado."
              />
              <ValorItem
                icon={TrendingUp}
                titulo="Impostos sempre à vista"
                texto="IBS, CBS, ISS e retenções calculados em tempo real pelo backend."
              />
              <ValorItem
                icon={Clock}
                titulo="Fechamento em minutos"
                texto="Relatórios mensais e informe de rendimentos prontos para o contador."
              />
            </div>
          </div>

          <div className="flex items-center gap-6 text-white/70">
            <Metric valor="R$ 12,4 mi" label="honorários processados" />
            <span className="h-8 w-px bg-white/15" />
            <Metric valor="38 mil" label="NFS-e emitidas" />
            <span className="h-8 w-px bg-white/15" />
            <Metric valor="4,9/5" label="satisfação médica" />
          </div>
        </div>
      </div>
    </div>
  );
}

function ValorItem({
  icon: Icon,
  titulo,
  texto,
}: {
  icon: typeof FileCheck2;
  titulo: string;
  texto: string;
}) {
  return (
    <div className="flex gap-3.5">
      <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-white/10 text-brand-400">
        <Icon size={19} />
      </span>
      <div>
        <p className="text-[15px] font-semibold text-white">{titulo}</p>
        <p className="mt-0.5 text-[13.5px] leading-snug text-white/60">{texto}</p>
      </div>
    </div>
  );
}

function Metric({ valor, label }: { valor: string; label: string }) {
  return (
    <div>
      <p className="num font-brand text-[19px] font-bold text-white">{valor}</p>
      <p className="text-[12px] text-white/55">{label}</p>
    </div>
  );
}
