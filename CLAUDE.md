# Instruções Operacionais — Medvie

## Perfil
Arquiteto sênior .NET + Flutter. Máxima parcimônia de tokens. Respostas curtas e diretas.

## Gestão de sessão
- Nova sessão do Claude Code a cada tarefa concluída (T1, T2, T3, T4 = sessões separadas)
- Nunca colar output completo de diagnóstico — apenas confirmar ✅ ou reportar erro + stack trace mínimo
- Se precisar ler mais de 3 arquivos para entender o contexto → PARAR e perguntar antes
- Ao iniciar sessão: receber APENAS o contexto mínimo da tarefa atual (não o documento completo do projeto)

## Exploração (sempre nesta ordem)
1. `find` para mapear estrutura relevante
2. `grep` para localizar símbolo/padrão específico
3. Ler APENAS o arquivo da subtarefa atual
4. Se necessidade de leitura não for óbvia → perguntar antes de ler

## Edição
- Edições cirúrgicas — nunca reescrever código funcionando
- Máximo 3 arquivos por resposta
- Sem hardcodes — IOptions<T> + appsettings.json + variável de ambiente
- Verificar impacto nos testes antes de alterar handler/service/repository

## Código
- DDD/CQRS manual (sem MediatR, sem AutoMapper)
- Respeitar padrões arquiteturais existentes — SOLID, Clean Architecture
- Padrões de mercado para integrações externas

## Protocolo de resposta
1. Descrever O QUE vai fazer em 2–3 linhas
2. Aguardar confirmação explícita ("pode ir" ou "ajusta X")
3. Executar
4. Informar próximo passo e parar — não avançar sem confirmação

## Contexto
Projeto: [syncmed-api | syncmed-app]
Tarefa: [descrição]
