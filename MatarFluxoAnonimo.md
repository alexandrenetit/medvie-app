# Matar Fluxo Anonimo por CPF

## Prompt medvie-app

Use Codex ChatGPT 5.5 com reasoning `xhigh`. Ative `$caveman ultra` para comunicacao curta, sem perder precisao tecnica.

Projeto: `C:\Projects\medvie\medvie-app`

Objetivo: matar definitivamente o fluxo anonimo antigo que consulta medico por CPF antes de existir Bearer token. O app nao pode depender de `/api/v1/medicos/by-cpf/{cpf}` em onboarding anonimo.

Escopo cirurgico:

- Inspecione somente arquivos relacionados a onboarding Step1A, auth/register/login, `MedvieApiService` e testes afetados.
- Remova a chamada pre-auth `getMedicoByCpf` do Step1A.
- Step1A deve apenas coletar CPF, dados cadastrais e senha.
- Cadastro novo deve usar somente `POST /auth/register`.
- Sucesso de register deve salvar sessao com `access_token`, `refresh_token` e `medico_id` ja retornados pelo backend.
- CPF ja cadastrado deve ser tratado via `409 Conflict` de `/auth/register`, com mensagem clara para o usuario fazer login.
- Login de usuario existente deve continuar usando `POST /auth/login`, depois `medico_id` + Bearer para `GET /api/v1/medicos/{medicoId}/onboarding-status`.
- Remova `getMedicoByCpf` do app se ficar sem uso valido. Se mantiver por compatibilidade, garanta que nao seja chamado antes de login.
- Nao altere contrato backend alem do tratamento esperado de `409`.
- Nao adicione packages.
- Nao mude arquitetura, rotas globais, storage, auth ou build config fora do necessario.
- Nao toque em arquivos nao relacionados.

Testes esperados no app:

- Teste/widget ou provider cobrindo que Step1A nao chama `by-cpf` ao perder foco do CPF.
- Teste de service para `register` com `409 Conflict` mapeando erro de CPF ja cadastrado/login.
- Teste de register sucesso mantendo armazenamento de tokens e `medico_id`.
- Teste de login/restauracao segue usando `onboarding-status` autenticado.
- Atualize/remova mocks quebrados por remocao de `getMedicoByCpf`.

Validacao obrigatoria final:

- Rode `flutter analyze` no Windows.
- Rode `flutter test` no Windows.
- Rode `flutter build apk --debug` no Windows.
- Rode DCM via WSL Ubuntu/Docker exatamente pelo projeto em `/mnt/c/Projects/medvie/medvie-app`:

```powershell
wsl --cd /mnt/c/Projects/medvie/medvie-app -e ./run_dcm.sh
```

Todos os testes devem estar 100% verdes. `flutter analyze`, `flutter build apk --debug` e `./run_dcm.sh` nao podem ter erros nem issues novas; DCM deve terminar sem issues bloqueantes no codigo tocado.

## Prompt medvie-api

Use Codex ChatGPT 5.5 com reasoning `xhigh`. Ative `$caveman ultra` para comunicacao curta, sem perder precisao tecnica.

Projeto: `C:\Projects\medvie\medvie-api`

Objetivo: matar definitivamente o risco backend do lookup anonimo por CPF. CPF nao pode ser chave de consulta anonima para retornar PII de medico.

Contexto de contrato:

- Swagger atual tem `Bearer` global.
- `/auth/register` deve continuar anonimo e retornar `AuthSessionResponse` com `access_token`, `refresh_token`, `medico_id`.
- `/auth/login` deve continuar anonimo e retornar `AuthSessionResponse` com `access_token`, `refresh_token`, `medico_id`.
- `/api/v1/medicos/by-cpf/{cpf}` retorna PII e nao pode ser acessivel sem token.

Escopo cirurgico:

- Inspecione somente controllers/endpoints de auth, medicos, policies/authorization, DTOs e testes relacionados.
- Garanta autorizacao real no runtime para `/api/v1/medicos/by-cpf/{cpf}`. Nao confie so em Swagger.
- Preferencia: remover/descontinuar uso publico de `by-cpf` se nao houver consumidor interno valido.
- Se endpoint permanecer, aplique policy estrita:
  - sem token: `401`;
  - token de outro medico: `403`;
  - proprio medico, admin ou internal service autorizado: `200`;
  - CPF invalido: `400`;
  - CPF inexistente: `404`.
- Use claims/`medico_id` autenticado como fonte de identidade; nao confie em CPF enviado pelo cliente para autorizar.
- Mantenha `[AllowAnonymous]` apenas em `/auth/register`, `/auth/login` e `/auth/refresh` se esse ja for o desenho atual.
- Em `/auth/register`, valide unicidade de CPF no backend e retorne `409 Conflict` quando ja existir.
- Nao vaze se possivel detalhes sensiveis alem da mensagem necessaria de conflito cadastral.
- Nao quebrar formato de `AuthSessionResponse`.
- Nao mudar banco, migrations, auth provider, signing, secrets, CORS, Docker ou CI sem necessidade comprovada.
- Nao fazer refactor amplo.

Testes esperados no backend:

- `GET /api/v1/medicos/by-cpf/{cpf}` sem Bearer retorna `401`.
- `GET /api/v1/medicos/by-cpf/{cpf}` com Bearer de outro medico retorna `403`.
- `GET /api/v1/medicos/by-cpf/{cpf}` com Bearer do proprio medico retorna `200`.
- `GET /api/v1/medicos/by-cpf/{cpf}` com admin/internal autorizado retorna `200`, se essa role existir no projeto.
- `POST /auth/register` com CPF existente retorna `409 Conflict`.
- `POST /auth/register` valido retorna tokens + `medico_id`.
- `POST /auth/login` valido retorna tokens + `medico_id`.
- Swagger deve continuar coerente com auth real.

Validacao obrigatoria final:

- Rode restore/build/test completos do .NET no Windows ou ambiente padrao do projeto.
- Rode todos os testes existentes e novos.
- Se houver suite de integracao/API, rode tambem.
- Gere/valide Swagger se houver comando/teste local para isso.

Todos os testes devem estar 100% verdes. Build, testes e validacoes de contrato/Swagger nao podem ter erros; nenhuma regressao de auth, PII, contrato ou status code deve permanecer.
