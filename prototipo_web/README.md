# Medvie · Protótipo Web

Protótipo web navegável do **Medvie** — um cockpit financeiro e fiscal para
médicos PJ, pensado para uso diário em desktop/notebook.

> ⚠️ **Somente protótipo.** Sem backend, sem autenticação real, sem banco de
> dados. Toda a interface roda com **dados mockados** (`src/data/mock.ts`) e
> todas as operações sensíveis (login, emissão de NFS-e, upload de certificado,
> downloads) são **simuladas** e sinalizadas no código.

## Stack

- **React 18** + **TypeScript**
- **Vite 5** (dev server + build)
- **Tailwind CSS 3** (design system próprio)
- **lucide-react** (ícones)
- **Recharts** (gráficos)
- **framer-motion** (animações curtas de modais, drawers e toasts)
- **react-router-dom** (navegação com HashRouter — funciona em qualquer host estático)

## Como executar

```bash
cd prototipo_web
npm install
npm run dev
```

Abra o endereço exibido no terminal (por padrão `http://localhost:5175`).
A aplicação inicia na tela de **Login** — clique em **Entrar** ou **Acesso
demonstrativo** para chegar à Visão Geral.

### Outros comandos

```bash
npm run build     # typecheck (tsc) + build de produção em dist/
npm run preview   # serve o build de produção localmente
npm run lint      # ESLint
```

## Telas

| Rota            | Tela                        |
| --------------- | --------------------------- |
| `/login`        | Login premium (simulado)    |
| `/`             | Visão geral (SyncView)      |
| `/agenda`       | Agenda mensal/semanal       |
| `/atendimentos` | Atendimentos (operacional)  |
| `/notas`        | Notas fiscais + timeline    |
| `/relatorios`   | Fechamento / anual / informe|
| `/simulador`    | Simulador de honorários     |
| `/perfil`       | Perfil, empresas, certificado|
| `/config`       | Configurações               |

## Interações navegáveis

- Troca de **CNPJ ativo** e de **competência** no header.
- **Command palette** com `Ctrl/Cmd + K` (navegação + ações + busca de tomadores).
- **Novo atendimento**: wizard em 3 passos (tomador → serviço → resumo fiscal ao vivo → sucesso).
- Seleção de dia na agenda atualiza o painel lateral sem trocar de página.
- Filtros e busca em Atendimentos e Notas; drawers de detalhe.
- Emitir/reenviar nota, baixar PDF/informe, exportar relatório → **toasts** de feedback.
- Simulador recalcula em tempo real e compara os três regimes tributários.
- Central de notificações e indicador de certificado digital.

## Estados de interface incluídos

Loading (skeleton/spinners), vazio, sucesso, erro, alerta, processamento,
certificado próximo do vencimento e nota fiscal rejeitada — todos como parte
natural do design.

## Design system

- Workspace claro (`#F6F7F9`) com sidebar azul-marinho (`#0B1524`).
- Ação/sucesso em verde-esmeralda; azul informacional; âmbar para atenção;
  vermelho reservado a falhas/risco.
- Tipografia: **Outfit** (marca/títulos), **Inter** (interface),
  **JetBrains Mono** (valores monetários).
- Tokens centralizados em `tailwind.config.js` e `src/index.css`.

## Origem do domínio

O vocabulário (status de serviço/nota, tipos de serviço, regimes, certificado,
IBS/CBS/ISS, pipeline financeiro, informe de rendimentos) foi extraído dos
_models_ e _providers_ do cliente Flutter `medvie-app`. Nenhum código do
`medvie-app` foi alterado.

## Segurança conceitual

Não há autenticação real, tokens, chamadas de API, envio de arquivos ou
armazenamento de dados médicos. Pontos simulados estão comentados no código
(ex.: `Login.tsx`, `NovoAtendimento.tsx`, `SecaoCertificado`).
