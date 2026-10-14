# Chainguard Actions — Parity Demo

A self-contained, **deploy-and-destroy** demo that proves Chainguard Actions are a
true drop-in replacement for community GitHub Actions.

One workflow runs the **same Docker build/push pipeline twice** — once with
upstream actions (`actions/*`, `docker/*`) and once with the hardened Chainguard
versions (`chainguard-actions/*`). The only difference between the two jobs is the
org prefix on each `uses:` line. A final job compares the built image digests to
prove parity, then prints a security callout showing what the Chainguard versions
add (SBOM, provenance, hardening report, continuous re-securing).

```
.
├── Makefile                       # make deploy / run / watch / destroy
├── Dockerfile                     # tiny reproducible image on a Chainguard base
├── app/index.html                 # the one file we build into the image
├── .github/dependabot.yml         # weekly action-version bumps (the upstream treadmill)
└── .github/workflows/parity-demo.yml
```

## Prerequisites

- [`gh`](https://cli.github.com/) (GitHub CLI), authenticated: `gh auth login`
- `git` and `make`

### One-time Chainguard setup (org admin)

The `chainguard-actions/*` jobs need your organization to hold the Chainguard
Actions entitlement. Create it once:

```sh
chainctl actions entitlements create --parent $ORGANIZATION
```

Then confirm the exact catalog names for the actions this demo uses. Chainguard
flattens the upstream org into the name, e.g. `docker/build-push-action` becomes
`docker-build-push-action` under the `chainguard-actions` org. The Chainguard tags
mirror the upstream version numbers, so both jobs run the **same version** of each
action — the only diff is the org prefix. Each `uses:` is pinned to an immutable
40-char commit SHA (best practice; a `# vX.Y.Z` comment records the version). The
SHA differs between the two orgs because they're separate repos, but the version
tag is identical. Note these repos publish `action.yml` **only on version tags**:
the `@main` branch holds just metadata (`source.json`, README), so `@main` never
resolves. The six this demo uses — a typical enterprise build → scan → sign
pipeline (checkout, trivy-action and cosign-installer are intentionally held one
release behind latest):

- `actions/checkout`           → `chainguard-actions/actions-checkout`           @ `v7.0.0`  (latest `v7.0.1`)
- `docker/setup-buildx-action` → `chainguard-actions/docker-setup-buildx-action` @ `v4.2.0`
- `docker/login-action`        → `chainguard-actions/docker-login-action`        @ `v4.5.1`
- `docker/build-push-action`   → `chainguard-actions/docker-build-push-action`   @ `v7.3.0`
- `aquasecurity/trivy-action`  → `chainguard-actions/aquasecurity-trivy-action`  @ `v0.35.0` (latest `v0.36.0`)
- `sigstore/cosign-installer`  → `chainguard-actions/sigstore-cosign-installer`  @ `v4.1.1`  (latest `v4.1.2`)

Trivy and cosign-installer were chosen because their hardening fixes land in the
**shipped action code** (`action.yml`/`action.yaml`, `entrypoint.sh`), not just in
the upstream repo's own CI workflows — so the upstream job really does run the
unpatched code.

Resolve a tag to its SHA with `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`;
list tags with `gh api repos/chainguard-actions/<name>/tags`.

## Deploy → Run → Destroy

```sh
make deploy      # creates a private repo in the virtualiseme org and pushes this demo
make run         # triggers the workflow (build only, no registry needed)
make watch       # same as run, but streams the run to your terminal
make destroy     # deletes the repo — everything is gone
```

Push the built images to GHCR (uses the built-in `GITHUB_TOKEN`, no extra secrets):

```sh
make run PUSH=true
```

Options: `make deploy VIS=public`, `make deploy REPO=my-demo-name`,
`make deploy OWNER=your-org` (defaults to the `virtualiseme` org).

## The 60-second talk track

1. **The scare.** "CI/CD is the most privileged system you own — and last year the
   `tj-actions/changed-files` action was hijacked and leaked secrets across 23,000+
   repos. You inherit whatever the community last pushed."
2. **Open the workflow.** "Two jobs. Same build → scan → sign steps, same version pins. Look at
   the only diff — the `uses:` prefix. That's the migration: `chainguard-actions/…`."
3. **Run it live** (`make run`). Both jobs go green.
4. **Open the run summary.** Point at the digest table: *identical image, drop-in
   proven.* Then the **hardening table** — pulled live from each action's
   `HARDENING.md` at the exact pinned SHA — showing the *actual* findings Chainguard
   fixed. Point at the ⚠️ rows: `sigstore-cosign-installer@v4.1.1` (unsanitized
   `$GITHUB_PATH` writes + unquoted shell expansion in `action.yml`) and
   `aquasecurity-trivy-action@v0.35.0` (`$GITHUB_PATH` injection in `action.yaml`,
   unquoted user input in `entrypoint.sh`). *That unpatched code is what the
   upstream job just ran.* Then the security callout: SBOM,
   provenance, continuous re-securing.
5. **Destroy it** (`make destroy`). "Nothing left behind — spin it up for the next
   customer in 30 seconds."

## Bonus: Dependabot (the upstream treadmill)

`.github/dependabot.yml` enables weekly `github-actions` update checks. Once the
repo is live, Dependabot scans the `uses:` pins and opens PRs for newer versions.

Be precise about what this shows: **Dependabot bumps each action to a newer
version of the same action — it does not suggest swapping `actions/*` for
`chainguard-actions/*`.** There is no org-migration recommendation in stock
Dependabot. What it *does* demonstrate is the treadmill you're on with community
actions: a constant stream of version-bump PRs, each pulling in whatever upstream
last pushed, each needing review. The Chainguard drop-ins are re-secured for you
instead — the hardening table in the run summary is that work, done continuously.

Checkout (`v7.0.0` → `v7.0.1`), trivy-action (`v0.35.0` → `v0.36.0`) and
cosign-installer (`v4.1.1` → `v4.1.2`) are deliberately pinned one release behind
latest, so Dependabot has real upgrades to propose — expect bumps on **both** the
upstream and `chainguard-actions/*` pins. That's the live "Dependabot recommends an
upgrade" moment. The hardening table reads the pins from the workflow itself, so
it stays accurate after you merge a Dependabot PR.

To see PRs quickly without waiting for the weekly cron, open the repo's
**Insights → Dependency graph → Dependabot** tab and click *Check for updates*.

## How parity is proven

Both jobs build the identical `Dockerfile` with `SOURCE_DATE_EPOCH` pinned for a
reproducible build, so a successful run yields the **same image digest** from both
sources. The `compare` job asserts equality and writes the result, plus the
security callout, to the GitHub Actions run summary.
