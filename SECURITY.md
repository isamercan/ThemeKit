# Security Policy

## Reporting a vulnerability

Please report security issues privately rather than opening a public issue.

Use GitHub's **[Report a vulnerability](https://github.com/isamercan/ThemeKit/security/advisories/new)**
(Security → Advisories) to open a private advisory. Include:

- a description of the issue and its impact,
- steps to reproduce (a minimal sample if possible),
- affected version(s).

You can expect an initial response within a few days. Once a fix is available,
we'll coordinate a disclosure and credit you if you'd like.

## Scope

ThemeKit is a UI component library with no networking in its core. The most
relevant surface is the optional MCP server under [`mcp/`](mcp/) (which can read
local files and call the Figma API when `FIGMA_TOKEN` is set) — reports there are
especially welcome.
