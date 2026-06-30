# Versions & Releases

## Two products, two tag namespaces

This repo ships **two independently-versioned products**, so their git tags use
distinct namespaces — and they must not collide, because **SwiftPM resolves
versions from SemVer git tags** (`vX.Y.Z`):

| Product | Where | Tag format | Example |
|---|---|---|---|
| **ThemeKit** (Swift package) | repo root | `vX.Y.Z` | `v0.3.0` |
| **@isamercan/themekit-mcp** (npm) | [`mcp/`](https://github.com/isamercan/ThemeKit/tree/main/mcp) | `mcp-vX.Y.Z` | `mcp-v2.6.0` |

> ⚠️ **Never tag an MCP release as `vX.Y.Z`** — SwiftPM would pick it up as a
> ThemeKit Swift-package version (e.g. a `v2.6.0` tag would make SwiftPM think the
> Swift package jumped to 2.6.0). The `mcp-` prefix is **not** valid SemVer, so
> SwiftPM ignores it, and the prefix also separates the two on the Releases page.

The two version numbers are unrelated: ThemeKit is in `0.x`; the MCP server has its
own line (currently `2.x`).

## Semantic Versioning

The package follows [SemVer](https://semver.org): `MAJOR.MINOR.PATCH`.

| Bump | Meaning |
|------|---------|
| **MAJOR** | A source-breaking change to the public API. |
| **MINOR** | Backward-compatible additions (new component, new defaulted parameter, new token). |
| **PATCH** | Backward-compatible fixes (bugs, visuals, docs). |

## We're in `0.x`

While the version is `0.x`, the public API is still stabilising — **a minor
release may include breaking changes**. Pin conservatively:

```swift
.upToNextMinor(from: "0.1.0")
```

When the API is considered stable we tag **`1.0.0`**, after which every breaking
change requires a MAJOR bump.

## Pre-releases

Release candidates are tagged with a suffix, e.g. `1.0.0-rc.1`, so you can test
an upcoming release before it's final. SPM treats these as pre-release versions.

## How releases are cut

**ThemeKit (Swift package):**

1. Changes land on `main` via PR (CI must be green).
2. `scripts/check-api.sh` reports whether the public API changed — this drives
   the MAJOR vs MINOR decision (see `docs/API-STABILITY.md`).
3. A maintainer tags the release: `git tag -a vX.Y.Z -m "…" && git push origin vX.Y.Z`.
4. A matching **GitHub Release** is published with notes.

**themekit-mcp (npm package, `mcp/`):**

1. Bump `mcp/package.json` and finalize `mcp/CHANGELOG.md`.
2. Publish: `cd mcp && npm publish --access public`.
3. Tag with the **`mcp-` prefix**: `git tag -a mcp-vX.Y.Z -m "…" && git push origin mcp-vX.Y.Z`.
4. Publish a **GitHub Release** on that tag (`gh release create mcp-vX.Y.Z …`).

## Following releases

- **Releases:** https://github.com/isamercan/ThemeKit/releases
- **Tags:** https://github.com/isamercan/ThemeKit/tags

Watch the repo (Releases only) to be notified of new versions.
