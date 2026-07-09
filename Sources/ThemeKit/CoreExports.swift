//
//  CoreExports.swift
//  ThemeKit
//
//  ThemeKit is the full catalog built on top of ``ThemeKitCore`` (the token-only
//  theme engine). This re-export makes every Core symbol — `Theme`, `SemanticColor`,
//  `Theme.SpacingKey`, `@Environment(\.theme)`, presets, the generator — visible
//  through a plain `import ThemeKit`, exactly as before the split. Existing consumers
//  need no source changes; only someone who wants the *minimal* layer reaches for
//  `import ThemeKitCore` directly.
//
//  This is the one place `@_exported` is the right tool: ThemeKit genuinely *is*
//  Core-plus-components, permanently — not a temporary migration shim.
//

@_exported import ThemeKitCore
