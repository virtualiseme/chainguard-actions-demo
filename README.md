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
resolves. The four this demo uses (checkout is intentionally held one release
behind latest):

- `actions/checkout`          → `chainguard-actions/actions-checkout`          @ `v7.0.0`
- `docker/setup-buildx-action` → `chainguard-actions/docker-setup-buildx-action` @ `v4.2.0`
- `docker/login-action`       → `chainguard-actions/docker-login-action`       @ `v4.5.1`
- `docker/build-push-action`  → `chainguard-actions/docker-build-push-action`  @ `v7.3.0`

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
2. **Open the workflow.** "Two jobs. Same four steps, same version pins. Look at
   the only diff — the `uses:` prefix. That's the migration: `chainguard-actions/…`."
3. **Run it live** (`make run`). Both jobs go green.
4. **Open the run summary.** Point at the digest table: *identical image, drop-in
   proven.* Then the **hardening table** — pulled live from each action's
   `HARDENING.md` at run time — showing the *actual* findings Chainguard fixed
   (e.g. `actions-checkout@v7.0.0` had 13 findings fixed — script-injection,
   unpinned-uses, missing-permissions, and more). *Those exact weaknesses still ship in the identical
   upstream actions running in the other job.* Then the security callout: SBOM,
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

The checkout action is deliberately pinned one release behind latest (`v7.0.0`,
while `v7.0.1` exists), so Dependabot has a real upgrade to propose — expect a PR
bumping it on **both** the `actions/checkout` and `chainguard-actions/actions-checkout`
pins. That's the live "Dependabot recommends an upgrade" moment.

To see PRs quickly without waiting for the weekly cron, open the repo's
**Insights → Dependency graph → Dependabot** tab and click *Check for updates*.

## How parity is proven

Both jobs build the identical `Dockerfile` with `SOURCE_DATE_EPOCH` pinned for a
reproducible build, so a successful run yields the **same image digest** from both
sources. The `compare` job asserts equality and writes the result, plus the
security callout, to the GitHub Actions run summary.
