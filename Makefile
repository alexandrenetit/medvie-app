# Makefile — Medvie Flutter App
# Targets para execução seletiva de testes e tarefas de qualidade.
#
# Uso:
#   make test-unit        → providers, services, models, utils
#   make test-widget      → widget tests e goldens
#   make test-all         → suite completa
#   make test-coverage    → gera relatório lcov
#   make analyze          → lint + static analysis
#   make goldens          → regenera golden screenshots
#   make ci               → sequência completa (analyze + test-all)

FLUTTER := flutter
DART    := dart

.PHONY: test-unit test-widget test-golden test-all test-coverage \
        analyze goldens ci clean

## ── Testes unitários (sem UI) ──────────────────────────────────────────────

test-unit:
	$(FLUTTER) test \
	  test/providers/ \
	  test/services/ \
	  test/models/ \
	  test/utils/

## ── Testes de widget e goldens ─────────────────────────────────────────────

test-widget:
	$(FLUTTER) test \
	  test/widget/ \
	  test/shared/

test-golden:
	$(FLUTTER) test test/golden/

## ── Suite completa ─────────────────────────────────────────────────────────

test-all:
	$(FLUTTER) test

## ── Cobertura ──────────────────────────────────────────────────────────────

test-coverage:
	$(FLUTTER) test --coverage
	@echo "Relatório gerado em coverage/lcov.info"
	@command -v lcov >/dev/null 2>&1 && \
	  lcov --summary coverage/lcov.info || \
	  echo "(lcov não instalado — instale com: sudo apt install lcov)"

## ── Análise estática ───────────────────────────────────────────────────────

analyze:
	$(DART) analyze --fatal-infos

## ── Regenerar goldens ──────────────────────────────────────────────────────

goldens:
	$(FLUTTER) test --update-goldens test/golden/

## ── Pipeline CI local (igual ao CI do GitHub) ──────────────────────────────

ci: analyze test-all
	$(FLUTTER) build apk --debug --no-pub
	@echo "✅ CI local concluído."

## ── Limpeza ────────────────────────────────────────────────────────────────

clean:
	$(FLUTTER) clean
	rm -rf coverage/
