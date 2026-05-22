# ADR-0001 — Exceção à regra "apenas pacotes oficiais Google/Flutter": `file_picker`

**Status:** Aceito
**Data:** 2026-05-22
**Contexto:** Spec `cd-upload`

---

## Contexto

CLAUDE.md do projeto `medvie-app` restringe dependências a "pacotes oficiais Google/Flutter". A feature `cd-upload` precisa permitir que o médico selecione um arquivo PFX/P12 do dispositivo, restrito por extensão, com binding direto em `Uint8List`. Não há pacote oficial Google/Flutter equivalente.

Alternativas:
1. Implementar platform channel próprio (Android `Intent.ACTION_OPEN_DOCUMENT` + iOS `UIDocumentPickerViewController`).
2. Aprovar `file_picker` (`pub.dev`, mantido pela comunidade, > 4M downloads/semana, 4 anos de manutenção contínua, suportado em Android, iOS, Web, Desktop).
3. Reduzir escopo: deixar usuário enviar via desktop web (fora do escopo do app móvel).

## Decisão

Aprovar exceção para `file_picker` (^8.x).

**Justificativa:**
- Maturidade: > 4 anos de releases consistentes, contribuição ativa, suporte multi-plataforma.
- Esforço alternativo: platform channel próprio = ~2 dias de implementação + testes + manutenção em 2 SOs. Para uma startup com dev solo no app, ROI negativo.
- Escopo: o pacote cobre 100% do uso (filtro por extensão, retorno em bytes).
- Risco mitigado por:
  - Versão fixa em `pubspec.yaml` (`file_picker: 8.x.x` pinned).
  - Revisão de segurança da release antes de cada bump.
  - Bytes retornados são tratados como sensíveis (zerados após uso).

## Alternativas Rejeitadas

- **Platform channel próprio**: descartado por custo/benefício na fase atual; reconsiderar quando o app tiver dev mobile dedicado e mais features dependendo de file picker.
- **Reduzir escopo para web**: viola o objetivo de onboarding 100% mobile-first.

## Consequências

**Positivas**
- Implementação rápida e bem testada.
- Suporte multi-plataforma incluído.

**Negativas**
- Adicionamos um pacote não-oficial à dependência (precedente).
- Atualizações exigem auditoria humana antes do bump.

**Mitigações**
- ADR explícita registra a exceção (este documento).
- `MEMORY.md` atualizado com "exceção aprovada: file_picker".
- PR de bump exige revisão de changelog + diff manual.
