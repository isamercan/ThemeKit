# Versions & Releases

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

1. Changes land on `main` via PR (CI must be green).
2. `scripts/check-api.sh` reports whether the public API changed — this drives
   the MAJOR vs MINOR decision (see `docs/API-STABILITY.md`).
3. A maintainer tags the release: `git tag -a vX.Y.Z -m "…" && git push --tags`.
4. A matching **GitHub Release** is published with notes.

## Following releases

- **Releases:** https://github.com/isamercan/ThemeKit/releases
- **Tags:** https://github.com/isamercan/ThemeKit/tags

Watch the repo (Releases only) to be notified of new versions.
