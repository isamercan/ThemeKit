# Contributing

Thanks for helping improve ThemeKit!

## Issues

- **Bug:** include platform/OS, a minimal repro, and what you expected.
- **Feature:** describe the use case before the API — what problem does it solve?

## Pull requests

1. Branch off `main` (e.g. `feat/…`, `fix/…`, `docs/…`).
2. Keep the change focused; one concern per PR.
3. Make sure CI is green — build + tests on iOS & macOS, and SwiftLint.
4. Update docs/DocC comments for any public API you touch.
5. Open the PR against `main` with a clear description.

## Local setup

```bash
git clone https://github.com/isamercan/ThemeKit
cd ThemeKit

swift build              # build the library
swift test               # run the logic/theme/validation suite (macOS)
swiftlint                # style check (matches CI)
```

The iOS build and the opt-in snapshot suite run under Xcode:

```bash
xcodebuild test -scheme ThemeKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Code style

- Enforced by **SwiftLint** (`.swiftlint.yml`); `swiftformat .` is the
  autocorrecting companion (`.swiftformat`).
- Components are token-bound — read colors/spacing/radii from the active
  `Theme`, never hard-code values.
- Every public type/init/method gets a real `///` doc comment.

## Public API & versioning

Adding public API is fine (it's a MINOR change). Run `scripts/check-api.sh` to
see how a change is classified; see `docs/API-STABILITY.md` and
**[[Sürümler & Release'ler|Versions-and-Releases]]**.
