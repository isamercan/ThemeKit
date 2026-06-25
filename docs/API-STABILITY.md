# API Stability & Versioning Policy

`ThemeKit` is a library: every type, initializer, modifier, and token
we mark `public` is a promise to the apps that depend on us. This document
defines what that promise is, how we version it, and how the toolchain enforces
it.

## Semantic Versioning

We follow [SemVer 2.0.0](https://semver.org). Given `MAJOR.MINOR.PATCH`:

| Bump | When | Examples |
|------|------|----------|
| **MAJOR** | A source-breaking change to the public API. | Removing/renaming a public symbol, changing a function signature, removing an enum case, making a non-failable init failable. |
| **MINOR** | Backward-compatible additions. | A new component, a new modifier, a new optional parameter **with a default**, a new enum case on a non-`@frozen` enum, a new theme token. |
| **PATCH** | Backward-compatible fixes. | Bug fixes, visual corrections, performance, docs, internal refactors that don't touch the public surface. |

Consumers pin with `.upToNextMajor(from: "1.2.0")`, so a MAJOR bump is the only
release that may break their build. Treat it as expensive.

## What counts as "public API"

Everything reachable by a consumer:

- `public` / `open` types, properties, methods, initializers.
- Public `View` modifiers (e.g. `.textStyle(_:)`) and their parameter labels & defaults.
- `public` enum cases and their associated values — including token enums
  (`TextStyle`, `Theme.SpacingKey`, color keys). **Renaming or removing a token
  case is a breaking change**, because consumers reference them by name.
- The JSON theme schema keys (a runtime contract, even though it isn't Swift).

`internal`, `private`, and `fileprivate` symbols are free to change at any time.
When in doubt, default to `internal` — you can always promote later (MINOR), but
you can't demote without a MAJOR.

## Deprecation policy

Don't delete in one step. Soften, then remove:

1. **Deprecate** in a MINOR release with a migration hint:
   ```swift
   @available(*, deprecated, renamed: "GlobalButton(label:)")
   public init(title: String) { self.init(label: title) }
   ```
2. Keep the deprecated symbol for **at least one MINOR cycle**.
3. **Remove** it only in the next MAJOR, and record it in
   `.api-breakage-allowlist.txt` + the CHANGELOG with migration steps.

## How it's enforced

The public surface is checked automatically with SwiftPM's API digester.

- **CI** runs `scripts/check-api.sh` on every PR (see `.github/workflows/ci.yml`,
  job `api-breakage`). It compares the PR against its base and reports any
  source-breaking change. The job is `continue-on-error` — a break is sometimes
  intended — but it makes the break **visible**, so the version bump is a
  conscious decision and never an accident.

- **Locally**, before opening a PR:
  ```bash
  scripts/check-api.sh                 # vs latest release tag (or origin/main)
  scripts/check-api.sh v1.3.0          # vs a specific release
  ```

### Recording an intentional break

When a MAJOR release deliberately removes or changes API, copy the breakage
message into `.api-breakage-allowlist.txt`. That keeps CI green while preserving
an auditable record of exactly what changed and why.

## Release checklist

1. `swift test` and the iOS scheme are green.
2. `scripts/check-api.sh` is clean **or** every reported break is in the
   allowlist and the version bump is MAJOR.
3. CHANGELOG updated; deprecations from the previous cycle removed if this is a MAJOR.
4. Tag the release: `git tag x.y.z && git push --tags`.
5. Clear `.api-breakage-allowlist.txt` after a MAJOR so the next cycle starts clean.
