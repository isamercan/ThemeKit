# CI / CD

A component library is someone else's dependency, so nothing merges unless it is
green. This repo is **private**, where GitHub-hosted **macOS runners bill at 10×**
the Linux rate — so the pipeline spends them deliberately, and every gate also runs
for **$0 locally**.

## The gates

| Gate | Runner | main push | pull request | What it proves |
|------|--------|:---------:|:------------:|----------------|
| **SPM build & test** | macOS 10× | ✅ | ✅ | Package compiles + full logic/theme/validation suite passes |
| **iOS Simulator** | macOS 10× | — | ✅ | No iOS-only API breakage; suite runs on-device |
| **SwiftLint** | Linux 1× | ✅ | ✅ | No error-level style violations |
| **API breakage** | macOS 10× | — | ✅ | Public-API changes vs the PR base are surfaced (informational) |

`main` pushes run only **SPM + lint** (1× macOS); the two extra macOS jobs gate
**merges**, where they have value, instead of re-running on already-merged code.

### Cost levers in `ci.yml`
- **`concurrency: cancel-in-progress`** — superseded commits stop burning minutes.
- **Composite `swift-setup`** (`.github/actions/swift-setup`) — Xcode select + a
  combined **SwiftPM + DerivedData** cache, shared by every macOS job. Caching
  DerivedData is the single biggest saver: `xcodebuild` stops recompiling the whole
  package each run.
- **`paths-ignore`** — doc/wiki/`*.md` changes don't trigger CI.
- **iOS + API jobs are PR-only** (`if: github.event_name == 'pull_request'`).

## Run CI locally — $0, no billing required

The same gates, on your machine:

```bash
make ci          # format-lint + swiftlint + build + test   (scripts/ci.sh)
make ci-fast     # build + test only
make test        # just the suite
make hooks       # install a pre-push hook that runs `make ci` before every push
```

`scripts/ci.sh` degrades gracefully: if `swiftformat` / `swiftlint` aren't
installed it skips them with a hint (`brew install swiftformat swiftlint`) and still
runs the must-pass build + test. Install the hook once and a red build never leaves
your machine — independent of GitHub Actions entirely.

## If Actions is blocked by billing

GitHub-hosted runners on a private repo require an active payment method and a
non-zero Actions spending limit. If runs fail instantly with *"recent account
payments have failed or your spending limit needs to be increased"*, the jobs never
start — it's an **account-level block, not a pipeline bug** (local `make ci` is
unaffected). Resolve it once in the web UI (API can't set these):

1. **Settings → Billing and licensing → Payment information** — clear the failed
   payment / add a valid card.
2. **Settings → Billing and licensing → Spending limits → GitHub Actions** — raise
   it above `$0` (or enable "limited spending").

### Alternative: self-hosted macOS runner (free minutes)
Register your own Mac and macOS jobs run on it at no per-minute cost:

1. **Repo → Settings → Actions → Runners → New self-hosted runner** (macOS) and
   follow the registration commands.
2. Point the macOS jobs at it by changing `runs-on: macos-15` to
   `runs-on: [self-hosted, macOS]` in `.github/workflows/ci.yml`.

Keep `lint` on `ubuntu-latest` (Linux minutes are cheap / often free).
