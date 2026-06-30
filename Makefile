# caipora — harness commands (single source of truth)
# Override the Godot binary with: make test GODOT=/path/to/godot
GODOT   ?= $(HOME)/.local/bin/godot
PROJECT := .
GODOT_USER_DATA_DIR ?= /tmp/caipora-godot-data
GODOT_HEADLESS_ENV := XDG_DATA_HOME=$(GODOT_USER_DATA_DIR)
# Os modelos de exportação vivem sob o XDG_DATA_HOME real do desenvolvedor. Como
# os alvos headless redirecionam XDG_DATA_HOME para isolar o user://, o Godot
# procuraria os modelos dentro do sandbox e não os acharia. O alvo `export`
# faz um symlink do dir real para dentro do sandbox antes de exportar.
GODOT_TEMPLATES_SRC ?= $(HOME)/.local/share/godot/export_templates

.PHONY: help smoke test import export gate audio audio-check audio-budget

help: ## list available targets
	@grep -hE '^[a-z]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t-/' | sort

smoke: ## boot the game headless for ~50 frames and exit (smoke test)
	$(GODOT_HEADLESS_ENV) timeout 60 $(GODOT) --headless --path $(PROJECT) --quit-after 50

test: ## run the GUT regression gate
	$(GODOT_HEADLESS_ENV) $(GODOT) --headless --path $(PROJECT) -s res://addons/gut/gut_cmdln.gd \
		-gdir=res://tests/unit -gprefix=test_ -gsuffix=.gd -gexit

import: ## refresh Godot import/class cache after adding class_name scripts
	$(GODOT_HEADLESS_ENV) $(GODOT) --headless --path $(PROJECT) --import

# Versão do jogo: alpha-X.Y.Z. A base alpha-X.Y vem do config/version do project.godot
# (fonte única — bump de MAJOR/MINOR é lá); Z é a contagem de commits do git e
# incrementa sozinho a cada commit.
export: ## build the reproducible HTML5 release
	mkdir -p export
	@set -e; \
	BASE=$$(sed -n 's/^config\/version="\(alpha-[0-9]\+\.[0-9]\+\).*/\1/p' project.godot); \
	: "$${BASE:?config/version do project.godot deve comecar com alpha-X.Y}"; \
	COMMITS=$$(git rev-list --count HEAD 2>/dev/null || echo 0); \
	VERSION="$$BASE.$$COMMITS"; \
	SHA=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown); \
	DATE=$$(date -u +%F); \
	printf '# GERADO por `make export` — NÃO editar à mão. Versão alpha-X.Y.Z derivada do git\n# (Z = contagem de commits) e lida pelo menu (main_menu._resolve_version). Gitignored;\n# recriado a cada build.\nextends RefCounted\n\nconst VERSION := "%s"\nconst BUILD := "%s"\nconst DATE := "%s"\n' "$$VERSION" "$$SHA" "$$DATE" > scripts/core/build_info.gd; \
	echo "build_info.gd -> $$VERSION ($$SHA, $$DATE)"; \
	if [ ! -d "$(GODOT_TEMPLATES_SRC)" ]; then echo "ERRO: modelos de exportacao ausentes em $(GODOT_TEMPLATES_SRC) (instale via Editor > Gerenciar Modelos de Exportacao, ou defina GODOT_TEMPLATES_SRC=/caminho)" >&2; exit 1; fi; \
	mkdir -p "$(GODOT_USER_DATA_DIR)/godot"; \
	ln -sfn "$(GODOT_TEMPLATES_SRC)" "$(GODOT_USER_DATA_DIR)/godot/export_templates"; \
	$(GODOT_HEADLESS_ENV) $(GODOT) --headless --path $(PROJECT) --export-release "Web" export/index.html; \
	cp html/update-notifier.js export/; \
	printf '{"version":"%s","build":"%s","date":"%s"}\n' "$$VERSION" "$$SHA" "$$DATE" > export/version.json; \
	echo "version.json -> $$VERSION ($$SHA, $$DATE)"

audio: ## regenerate all procedural audio, reimport and verify loudness
	python3 scripts/tools/gen_sfx.py
	$(GODOT_HEADLESS_ENV) $(GODOT) --headless --path $(PROJECT) --import
	python3 scripts/tools/check_audio.py

audio-check: ## verify assets/audio against the loudness standard (PRD-audio-v2 §3)
	python3 scripts/tools/check_audio.py

audio-budget: audio-check ## alias: loudness + weight report live in check_audio.py

gate: smoke test ## full verification before commit
