# Contributing to ThemeKit

Thanks for your interest in improving ThemeKit! This guide covers the basics.

## Development

```sh
make ci            # format-lint + lint + build + test (the full gate)
swift test         # the test suite
make screenshots   # re-render component PNGs + rebuild the README gallery
make skill         # regenerate the MCP data, the Agent skill, and llms.txt
```

`make ci` is what the pre-push hook and CI run — keep it green.

## Conventions

- **Tokens, not literals.** Components never hardcode a color/radius/spacing/font —
  every value resolves from the active `Theme`. New components must follow this.
- **English strings.** All user-facing and placeholder text in the source, demo,
  and docs is written in English. Localized translations live only in the bundled
  String Catalog (`Resources/Localizable.xcstrings`).
- **Accessibility.** Honor Dynamic Type and Reduce Motion; components read the
  environment directly.
- **Generated files stay generated.** Colors come from `tools/gen_tokens.py`
  (`python3 tools/gen_tokens.py .`); the MCP data / skill / llms.txt come from
  `make skill`. Don't hand-edit the generated outputs.

## Pull requests

- Branch off `main`, keep the change focused, and include tests where it makes sense.
- Make sure `make ci` passes locally; CI runs the same gates on every PR.
- Describe what changed and why; screenshots help for visual changes.

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
