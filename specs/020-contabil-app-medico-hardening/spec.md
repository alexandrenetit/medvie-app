# Espelho de contrato — SDD 020 (Contábil no app do médico)

**Origem da verdade:** `medvie-api/specs/020-contabil-app-medico-hardening/`.
Este arquivo espelha **só o que o app Flutter consome**, com o contrato **final** (pós-Phase 10).
Divergiu? A API manda — abrir issue lá, não corrigir aqui.

**Estado:** backend concluído e na `develop`. Swagger regenerado e verificado como **estritamente
aditivo** (0 quebras; 4 rotas novas, 11 schemas novos, 3 campos novos). O app da SDD 018 **continua
funcionando sem alteração**; o que segue é oportunidade, não obrigação de migração.

---

## 1. `GET /api/v1/vinculos` — campos ADITIVOS

Forma preservada (array na raiz). Novidades **dentro** de cada vínculo:

```jsonc
{
  "empresas": [
    {
      "cnpjProprioId": "…",
      "cnpj": "12345678000190",
      "escoposConcedidos": ["fiscal.leitura", "cadastro.leitura"], // NOVO
      "autorizadoEm": "2026-06-02T09:14:00-03:00"                  // NOVO
    }
  ],
  "naoAcessivel": {                                                // NOVO
    "escoposNaoConcedidos": ["fiscal.documentos", "cadastro.curadoria"],
    "empresasNaoAutorizadas": [{ "cnpjProprioId": "…", "cnpj": "98765432000110" }],
    "classesNuncaAcessiveis": ["certificado-digital", "token-de-provider"]
  }
}
```

**O que isso muda na tela.** `naoAcessivel` é **derivado no servidor**. Não escrever essa lista
como texto fixo no Flutter é requisito (FR-007): texto fixo mente no dia em que o catálogo de
escopos mudar, e a tela existe justamente para o médico saber a fronteira.

Dois casos que a tela precisa aguentar:

- vínculo `Ativo` com `empresas: []` **existe** e não pode ser escondido (FR-008);
- o mesmo CNPJ pode aparecer em **dois** vínculos, quando autorizado a dois escritórios (FR-009).
  Não é duplicata a deduplicar.

## 2. `POST /api/v1/convites/previa` — NOVA

```jsonc
// request
{ "token": "<token do convite>" }
```

```jsonc
// 200
{
  "escritorioNome": "Contabilidade Exemplo ME",
  "escoposAConceder": ["fiscal.leitura", "fiscal.documentos", "cadastro.leitura"],
  "exigeConferenciaCpf": true,
  "expiraEm": "2026-08-25T12:00:00-03:00",
  "consentimentoPeloBotao": false,
  "empresasElegiveis": [
    { "cnpjProprioId": "…", "cnpj": "12345678000190", "jaConcedida": false }
  ]
}
```

**É POST porque o token é credencial** — em rota ele vazaria para `Referer`, histórico e log de
proxy. Não tem efeito colateral: não consome o convite.

**Regras que a UI tem de respeitar:**

- `consentimentoPeloBotao = true` ⇒ há **uma** empresa elegível e o botão **é** o consentimento.
- `false` com 2+ empresas ⇒ **nenhuma vem pré-marcada**, e o app **não pode** pré-marcar (FR-004).
  Marcar é o ato de consentir; pré-marcar por conveniência falsifica o consentimento.
- `jaConcedida = true` ⇒ mostrar como já concedida, nunca como oferta nova.
- **404** é indistinguível por design (inexistente ≡ expirado ≡ cancelado ≡ já aceito ≡ CPF
  divergente). Não tentar adivinhar o caso na mensagem: a resposta é igual em corpo, status e tempo.
- **429** com `Retry-After: 60` — teto de 5/min e 20/h por médico. Balde **separado** do aceite:
  navegar pela prévia não bloqueia aceitar.

## 3. `GET /api/v1/auditoria/resumo` — NOVA

```jsonc
{
  "janelaDias": 90,
  "membros": [
    {
      "escritorioId": "…",
      "membroAuthUserId": "…",
      "membroNome": "Ana Souza",
      "membroRevogado": false,
      "totalAcessosJanela": 42,
      "ultimoAcessoEm": "2026-08-09T16:40:00-03:00"
    }
  ]
}
```

Sub-rota nova em vez de campo em `GET /api/v1/auditoria` — aquela devolve **array na raiz** e
envelopá-la quebraria todo cliente da 018 de uma vez. **`GET /api/v1/auditoria` segue intacta.**

`membroRevogado = true` continua aparecendo, marcado. Sumir com ele apagaria a evidência de quem
acessou (FR-011) — a lista é auditoria, não catálogo de gente ativa.

## 4. Rotas de escritório (fora do app do médico)

`GET /api/v1/escritorios/membros/inativos` e `GET /api/v1/escritorios/revisao-acessos` são do
**portal do contador** (web), não do app. Estão aqui só para o app não tentar consumi-las: a sessão
do médico recebe `403`.

---

## O que NÃO mudou (e não deve ser "melhorado" no cliente)

| | |
|---|---|
| `POST /api/v1/convites/aceitar` | Mesma forma. Passa a poder responder **429** |
| `POST /api/v1/codigos-conexao` | Mesma forma; uso único, 15 min |
| `GET /api/v1/auditoria` | **Array na raiz**, intacta |
| Revogação (`/autorizacoes/{id}/revogar`, `/vinculos/{id}/revogar`) | Inalteradas |

## Gates deste repo (T107 da SDD 020)

Rodados nesta feature: `flutter analyze` **limpo**, `dcm` (via `./run_dcm.sh`) **sem issues**,
`flutter test` **775 passando**.

⚠️ **Os 4 testes de golden falham quando `flutter test` roda pelo WSL/Linux** (diffs de 0,14% a
0,22% — 657 a 1078 px). Os **mesmos quatro passam** no `flutter` do Windows. É renderização de
fonte por plataforma, não regressão: os goldens foram gerados no Windows. Rodar golden test na
mesma plataforma em que o baseline nasceu, ou fixar um runner de CI para eles.
