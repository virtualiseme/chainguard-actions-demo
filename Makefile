# Chainguard Actions parity demo — deploy / run / destroy
#
# Requires: gh (GitHub CLI, authenticated via `gh auth login`) and git.
# One-time org setup (Chainguard entitlement) is described in README.md.

REPO    ?= chainguard-actions-demo
OWNER   ?= virtualiseme
SLUG    := $(OWNER)/$(REPO)
VIS     ?= public           # public | private
PUSH    ?= false            # set PUSH=true to push images to GHCR when running

.PHONY: help deploy run watch destroy status

help:
	@echo "Targets:"
	@echo "  make deploy    Create GitHub repo $(SLUG) and push this demo"
	@echo "  make run       Trigger the parity workflow (PUSH=true to push to GHCR)"
	@echo "  make watch     Trigger the workflow and stream the run"
	@echo "  make status    Open the repo Actions page in a browser"
	@echo "  make destroy   Delete the GitHub repo (removes everything)"

deploy:
	@echo ">> Creating $(SLUG) ($(VIS)) and pushing demo..."
	git init -q
	git add -A
	git -c user.email=demo@local -c user.name=demo commit -q -m "Chainguard Actions parity demo" || true
	git branch -M main
	gh repo create $(SLUG) --$(VIS) --source=. --remote=origin --push
	@echo ">> Done. Run: make run"

run:
	@echo ">> Triggering parity-demo.yml on $(SLUG) (push=$(PUSH))..."
	gh workflow run parity-demo.yml -R $(SLUG) -f push=$(PUSH)
	@echo ">> Started. View: make status  (or: make watch)"

watch:
	gh workflow run parity-demo.yml -R $(SLUG) -f push=$(PUSH)
	@sleep 4
	gh run watch -R $(SLUG) $$(gh run list -R $(SLUG) -w parity-demo.yml -L1 --json databaseId --jq ".[0].databaseId")

status:
	gh repo view $(SLUG) --web

destroy:
	@echo ">> Deleting $(SLUG) ..."
	gh repo delete $(SLUG) --yes
	rm -rf .git
	@echo ">> Gone."

