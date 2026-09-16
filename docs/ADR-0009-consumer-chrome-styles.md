# ADR-0009 — Consumer chrome styles (component paint through style protocols)

- **Status:** **Accepted** (2026-09-16)
- **Date:** 2026-09-16
- **Deciders:** ThemeKit architecture (maintainer decision)
- **Context source:** A host design system that wraps ThemeKit components — its own component's `body` *is* the ThemeKit component — and has to reach its Figma spec with its own tokens, text styles and icon font, plus a per-component gap report for the ten components it wraps most.
- **Rollout:** Additive. With no style set, every component renders its 1.4.0 body unchanged apart from the five fixes listed under Consequences (the snapshot suite pins it), and `swift package diagnose-api-breaking-changes` against 1.4.0 reports no breakage.
- **Precedent mirrored:** `ChipStyle` (the environment style whose stock value is marked `isDefault`) and SwiftUI's `ButtonStyle`.
- **Builds on:** ADR-0008 (consumer-defined tokens), ADR-0006 (per-subtree theme resolution), ADR-0004 §4 (styles never read the motion environment).
- **Shipped in:** 1.5.0.

## Context

ADR-0008 gave a host app a place for its own tokens and stopped short of components on purpose:

> This is a **token-read API, not a component-theming API**. A custom color reaches a component only where that component accepts a raw `Color`.

That left one question open: how a host's paint reaches a ThemeKit component at all. Components take colours from `SemanticColor` or theme token keys, and type from the closed `TextStyle` enum, so a host's `custom.` colour, its own text style or its icon font has no way in. Three constraints decide the answer.

1. **The raw-value escape hatch is closed.** The variant-naming gate (ADR-3, `scripts/check-variant-naming.sh`) fails any public modifier that takes a raw `Color`, and any `size` / `variant` modifier that takes a raw `CGFloat`. The library has spent releases deprecating the raw modifiers it once had (`Badge.badgeColor(_:)`, `Badge.gradient(_: [Color]?)`, `RadioButton.fillColor(_:)`). A `.fill(_ color: Color)` per component would reopen what the gate exists to keep closed, and a raw `Color` doesn't follow dark mode or a per-subtree theme anyway.
2. **The host wants ThemeKit's behaviour, not only its look.** A wrapper such as `struct HostBadge: View { var body: some View { Badge(text).badgeStyle(tone) } }` exists to inherit ThemeKit's content model, slots, press feedback, accessibility, RTL and state handling. Forking the component loses all of that and every later fix. Rebuilding it from scratch does the same.
3. **The spec differs in chrome, not in anatomy.** The host's badge is a badge: same text, same optional glyph, same tone. Padding, height, corner, type style, glyph size and fill are what differ. That is paint, and the library had no seam for paint below the container level.

What already existed: `ChipStyle` worked the way this ADR needs. It's a `ButtonStyle`-shaped protocol read from the environment, and its default eraser is marked `isDefault`, so a chip keeps its own body until someone sets a style. The six archetype protocols (`CardStyle`, `FieldStyle`, `BarStyle`, `MeterStyle`, `ToastStyle`, `ListRowStyle`) re-skin container shells. The atoms and controls a host wraps most had no style at all.

| Component | What a host could not reach in 1.4.0 |
|---|---|
| `ThemeButton` | height, padding, corner, the fill for each state, the title's type, the focus ring; swapping only the title; the spinner |
| `Badge` | type style, icon size, padding, height, corner; a non-SF-Symbol glyph |
| `countBadge(_:)` | the bubble's font, size and fill; no standalone view |
| `IconTile` | a glyph other than an SF Symbol; a circular tile; sizes under 24 pt |
| `PriceTag` | a price the host already formatted; the type and colour of each part; a stacked layout |
| `RadioButton` | the indicator, the label's type, a description line |
| `Skeleton` | the fill and the animation |
| `DividerView` | line colour, thickness, dash pattern, the title's type |
| `Callout` | the row layout, the text's type and colour, the icon, the surface |
| `InlineText` | the type style and base colour; glyphs before or after the text |

## Decision

### D1 — One style protocol per component whose chrome a consumer must own

A component gets a style protocol when a host must own its chrome to reach its spec. This trigger is separate from ADR-F5's "three shipped archetypes" rule: the protocol ships with exactly one implementation, the stock look, and exists so a consumer can supply the rest.

1.5.0 adds ten:

| Component | Protocol | Set with |
|---|---|---|
| `ThemeButton` | `ButtonChromeStyle` | `.buttonChromeStyle(_:)` |
| `Badge` | `BadgeChromeStyle` | `.badgeChromeStyle(_:)` |
| `CountBadge` (new view) | `CountBadgeStyle` | `.countBadgeStyle(_:)` |
| `IconTile` | `IconTileStyle` | `.iconTileStyle(_:)` |
| `PriceTag` | `PriceTagStyle` | `.priceTagStyle(_:)` |
| `RadioButton` | `RadioButtonChromeStyle` | `.radioButtonChromeStyle(_:)` |
| `Skeleton` | `SkeletonStyle` | `.skeletonStyle(_:)` |
| `DividerView` | `DividerStyle` | `.dividerStyle(_:)` |
| `Callout` | `CalloutChromeStyle` | `.calloutChromeStyle(_:)` |
| `InlineText` | `InlineTextStyle` | `.inlineTextStyle(_:)` |

`ChipStyle` already had this shape, except for the `Default…` / `.default` pair: its stock styles are `TonalChipStyle` (`.tonal`, the environment default) and `SolidChipStyle` (`.solid`), and `Chip` always draws through `makeBody` (only the chip-shaped molecules check `isDefault`). 1.5.0 adds `ChipStyleConfiguration.title` to it and lets a chip style set the title's font.

### D2 — The uniform shape

Every protocol has the same parts, so learning one teaches all of them:

```swift
public struct BadgeChromeStyleConfiguration {        // public lets, internal memberwise init
    public let text: String
    public let leading: AnyView?
    public let tone: BadgeStyle
    // …
}

public protocol BadgeChromeStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: BadgeChromeStyleConfiguration) -> Body
}

public struct DefaultBadgeChromeStyle: BadgeChromeStyle, Sendable { public init() {} … }   // the stock look
public extension BadgeChromeStyle where Self == DefaultBadgeChromeStyle {
    static var `default`: DefaultBadgeChromeStyle { … }
}

struct AnyBadgeChromeStyle: BadgeChromeStyle { let isDefault: Bool … }            // internal eraser
private struct BadgeChromeStyleKey: EnvironmentKey {
    static let defaultValue = AnyBadgeChromeStyle(DefaultBadgeChromeStyle(), isDefault: true)
}

public extension View {
    func badgeChromeStyle<S: BadgeChromeStyle>(_ style: sending S) -> some View
}
```

- **Configurations are read-only for consumers.** Their inits are internal, so a minor release can add a field without breaking anyone (the ADR-0004 §4 rule).
- **Content arrives raw or unpainted.** Strings arrive as `String`, not styled `Text`, so a style picks its own type. Composed views (a button's `label`, a callout's or inline text's `content`, a tile's `glyph`) arrive as `AnyView` with no font or colour applied, so a `.font(_:)` or `.foregroundStyle(_:)` in the style takes effect. The exceptions are stock pieces offered as-is:
  - `DividerStyleConfiguration.label`, the stock title, for a style that keeps it;
  - the SF Symbol shorthands, which arrive already sized: `ThemeButton.icon(leading:trailing:)` glyphs inside the button's `label`, `Badge.icon(_:)` / `trailingIcon(_:)` in `leading` / `trailing`, and the callout's 14 pt stock status icon in `leading`. Badge and Callout also hand over the symbol names (`leadingSystemImage`, …) so a style can draw its own; a button host supplies its own glyphs through the `.prefix { }` / `.suffix { }` / `.label { }` slots, which arrive exactly as written;
  - the callout's wired action and dismiss buttons, which keep their stock type (their raw inputs are there too).
- **State arrives resolved:** `isEnabled`, `isPressed`, `isFocused`, `isLoading`, and the motion flag.
- **Axes arrive as the modifiers set them:** tone, variant, size, shape and so on, so a style can map them onto its own ramp.
- **Controls arrive wired.** A callout's action and dismiss buttons, for example, are ready to place, and their raw inputs (`actionTitle`, `onAction`, `onClose`) are there too, for a style that draws its own buttons.
- **`sending`, as in the existing protocols.** The eraser stores an escaping `@MainActor` closure in the environment, so the modifier takes the style `sending`.
- **The stock style is `Sendable`.** `Default<Name>` holds no state, so a host can keep one instance (a `static let`) and set it on any number of views.

### D3 — The `isDefault` bridge keeps defaults byte-identical

Every component body follows one shape:

```swift
public var body: some View {
    if style.isDefault {
        // the 1.4.0 body, unchanged
    } else {
        // the behaviour wrapper around style.makeBody(configuration:)
    }
}
```

Only the environment key's stock value is marked `isDefault`. Setting `.xStyle(.default)` explicitly gives an unmarked eraser, which goes through `makeBody`, and `Default<Name>` is written to draw the same pixels as the built-in body. The unit tests render both and compare them. So a custom style can hand some cases back to `.default` and nothing moves.

One exception, documented on the type: `AnyRadioButtonChromeStyle` also treats an explicit `DefaultRadioButtonChromeStyle` as the default. On RadioButton's built-in path, its `.plain` button supplies the disabled fade and the press feedback. The style path's bridge adds neither, so setting `.default` restores the built-in path rather than an approximation of it.

The rejected alternative was to route the default through `makeBody` as well. That puts every component on every existing screen onto a new render path, behind an extra `AnyView` with a different view identity, and every snapshot reference with it, for no visual gain. With the bridge, adopting this change costs nothing.

### D4 — ThemeKit keeps the behaviour; the style draws the chrome

The component still owns everything that isn't paint, and it applies that around whatever the style returns.

| Component | Stays in the component | Drawn by the style |
|---|---|---|
| `ThemeButton` | tap guard while loading, haptics, focus, VoiceOver label/value/identifier, the arranged label (title or `.label { }`, prefix/suffix, icon-only glyph, spinner placement, `.loadingIndicator { }`) | padding, frame, fill, border, shape, foreground, focus ring |
| `Badge` | text + slots / SF Symbol shorthands, the axes, the action button and its press feedback, one combined VoiceOver element | type, icon size, padding, height, fill, border, corner, lift |
| `CountBadge` | count / text / glyph, locale formatting, overflow cap, zero rule, one combined VoiceOver element | type, padding, minimum size, fill, corner, halo |
| `IconTile` | glyph, axes, hidden from VoiceOver | glyph size and colour, tile size, fill, outline |
| `PriceTag` | formatted or verbatim price, free/sold-out states, discount maths, slots, one VoiceOver element with the spoken label | layout, type and colour of every part, the discount badge |
| `RadioButton` | select vs toggle, read-only, `.disabled(_:)`, VoiceOver label/value/hint/traits/identifier, validation messages | indicator, label, description, their layout |
| `Skeleton` | size, loading flag, reveal cross-fade, motion resolution, restart on change, hidden from VoiceOver | fill, sweep or pulse |
| `DividerView` | axis, dashed, size, title and its placement, the VoiceOver rule (bare = hidden, titled = its title once) | line colour, thickness, dash pattern, title type |
| `Callout` | text + links, slots, wired action and dismiss buttons, link routing, the status label on the leading indicator | row layout, type, colour, icon, padding, surface, stroke, corner |
| `InlineText` | text + links, link marking, tap routing (other URLs go to the surrounding `openURL`) | type style, base colour, how the slots sit |

- **Live press state.** Controls with a pressed look (`ThemeButton`, `RadioButton`) hand the style to a real SwiftUI `ButtonStyle` internally, so `isPressed` is live.
- **Motion is resolved before the style sees it.** The configurations that carry motion carry it resolved: `isMotionEnabled` (`ButtonChromeStyle`), `animation` (`RadioButtonChromeStyle`), `isAnimated` (`SkeletonStyle`) and `animatesValue` (`PriceTagStyle`). Styles never read `microAnimations` or Reduce Motion themselves (ADR-0004 §4). `animatesValue` is resolved against Reduce Motion only: `PriceTag` never consulted `microAnimations` in 1.4.0, and 1.5.0 keeps that behaviour. A later minor release gates it on `microAnimations` too; a style that uses the flag picks that up with no change.
- **New slots take the canonical names where they're free.** The slots added alongside use the authoring skill's vocabulary: `ThemeButton.label { }`, `.leading { }` / `.trailing { }` on `Badge`, `InlineText` and `PriceTag`. The button's loading slot is the exception: the generic `.indicator { }` name was taken, because on any view it is the corner overlay `View.indicator(_:content:)`. A `ThemeButton` member of that name would win overload resolution (the overlay's position has a default) and silently turn a 1.4.0 `ThemeButton(…).indicator { Badge("3") }` into a loading slot, so the slot is `.loadingIndicator { }`.

### D5 — Naming: `<Component>Style`, else `<Component>ChromeStyle`

A protocol takes `<Component>Style` when that name is free: `CountBadgeStyle`, `IconTileStyle`, `PriceTagStyle`, `SkeletonStyle`, `DividerStyle`, `InlineTextStyle`.

A 1.x public enum already owns the `…Style` name for four of these components. `ThemeButtonStyle` picks a preset button, `BadgeStyle` a tone, `CalloutStyle` a plain or soft surface, `RadioButtonStyle` a check indicator. Renaming those in a minor is a source break, so their protocols take `…ChromeStyle`: `ButtonChromeStyle`, `BadgeChromeStyle`, `CalloutChromeStyle`, `RadioButtonChromeStyle`. The button's protocol is named after the control rather than the `Theme` prefix: `ButtonChromeStyle`, set with `.buttonChromeStyle(_:)`.

**2.0 plan.** The removal epoch (`docs/2.0-removal-epoch.md`, "Planned enum renames") renames the four owning enums to names that describe what they pick (tone, surface, indicator, preset). Each keeps its old `…Style` spelling as a deprecated `typealias` for the epoch, so existing call sites still compile with a migration hint. The `…ChromeStyle` protocols keep their names through 2.0. Whether any protocol later takes a freed `…Style` name is a separate decision, made only after the aliases are gone.

### D6 — Environment propagation into ThemeKit's own compositions

A style is an environment value, so it reaches the component wherever it renders, including inside ThemeKit's own compositions:

- **`ButtonChromeStyle`:** dialog, popconfirm and tour actions, banner and result-view buttons, the icon-only circles in travel rows.
- **`BadgeChromeStyle`:** list rows, price tags, cards.
- **`PriceTagStyle`:** `PriceBreakdown`, `DestinationCard`, `PriceAlertCard`, `MapCallout`, the ThemeKitTravel fare and flight cards.
- **`DividerStyle`:** `Card` rules and the list and menu separators.
- **`SkeletonStyle`:** the `Card` and `ListView` loading states, `Stat`, `Avatar`, `RemoteImage`, `AnimatedImage`.
- **`RadioButtonChromeStyle`:** `RadioGroup` rows and the indicator-only radios in `ControlRow`, `RadioCard`, `ListRow`.
- **`InlineTextStyle`:** helper text, validation messages, banners, callouts.

This is deliberate. A host sets its styles once at the root, and its brand reaches the components ThemeKit composes as well as the ones it places itself. Set a style on a single component to scope it.

The consequence for style authors is that a style must render every configuration it can be handed: an indicator-only radio (no label), an icon-only button, a vertical or titled divider, a callout with or without trailing accessories. Each protocol's documentation lists what reaches it.

### D7 — Styles resolve colours from the environment theme

Configurations carry semantic inputs: `SemanticColor`, token keys, the tone enum. Resolved `Color`s appear only where a composing component has already decided the colour: `InlineTextStyleConfiguration.baseColor` (a callout's tone, a validation message's status) and `linkColor`. A style resolves the rest inside a `View` that reads `@Environment(\.theme)`, which is why the documentation samples return a private view from `makeBody`. Resolving there means:

- a per-subtree `.theme(_:)` (ADR-0006) re-skins a custom style exactly as it re-skins the stock one;
- a host's own tokens (ADR-0008) are one call away: `theme.custom.color(.fareBadge) ?? theme.resolve(configuration.tone.semantic).soft`;
- a host's own type ramp works too: register a `Theme.ResolvedTextStyle` (its init is public from 1.5.0) under `custom.`, then apply it with `.font(style.font).lineSpacing(style.lineSpacing)`.

Reading `Theme.shared` inside a style defeats per-subtree theming, the same way it does in a component. The ADR-0006 rule applies to styles too.

## Consequences

- **ADR-0008's open end is closed for these ten components.** A `custom.` token, a host text style or an icon-font glyph now reaches them, through a style. ThemeKit still learns nothing about the host, and the brand-neutrality gate passes unchanged.
- **No raw-value modifiers were added.** The variant-naming gate stays clean with no new allowlist entries. `BadgeChromeStyleConfiguration` and `RadioButtonChromeStyleConfiguration` keep the deprecated raw overrides as *internal* fields, so `.default` paints what the deprecated modifiers ask for, and custom styles never see a raw colour.
- **The public surface grows**, by ten protocols, ten configurations, ten `Default…` styles, ten modifiers and the new slots and inits. Every configuration field is public API: fields can be added in a minor and never removed before 2.0.
- **Each component now has two render paths.** `Default<Name>` must track the built-in body. Unit tests compare the two pixel for pixel, and the snapshot suite pins the built-in one.
- **The style path differs in documented ways.** A custom-styled `ThemeButton` draws no focus ring unless the style does. `RadioButton` adds no press or disabled effect (the stock `DefaultRadioButtonChromeStyle` draws both, so a style that hands a radio back to it keeps them), and `RadioGroup` no longer fades disabled options; its styled rows read to VoiceOver like its built-in rows (label and selected trait). A `Badge` without an action reads as one combined VoiceOver element.
- **No new member shadows a generic modifier.** The API digester can't see a member that re-resolves an existing call, because the change is in overload resolution rather than in a signature. So the rule is to rename instead: the button's loading slot is `.loadingIndicator { }`, and `ThemeButton(…).indicator { }` stays the corner overlay, as in 1.4.0. (`ControlRow.indicator { }` and `Spinner.indicator { }` predate 1.5.0.)
- **Type erasure costs only on the style path.** `AnyView` wraps the style's body and the pre-composed views in its configuration; the default paths render their concrete 1.4.0 bodies.
- **Relation to ADR-F5** (`THEMEKITTRAVEL_ARCHITECTURE.md` §6). ADR-F5's ladder gives a full style protocol only to components with three or more shipped archetypes of distinct anatomy, and keeps atoms on enum variants or style-exempt. ADR-0009 adds a second, independent trigger, consumer-owned chrome, so **atoms now get style protocols** (`Badge`, `CountBadge`, `IconTile`, `PriceTag`, `Skeleton`, `DividerView`, `InlineText`). ADR-F5 still governs *library-shipped presets*: a chrome style ships `.default` only, and any further built-in preset must still clear ADR-F5's bar. ADR-0004's override of the promotion rule stays scoped to ThemeKitTravel.
- **Fixes found while building the chrome paths ship with them:**
  - `Skeleton` honours `microAnimations` and restarts its loop when motion settings change.
  - A `ChipStyle` can set the title font (slots without a font still take the one around the chip).
  - `Theme.ResolvedTextStyle` has a public init, so a host can register its own text styles.
  - A `Callout`'s linked text keeps the tone colour.
  - `DividerView`'s dashed line mirrors under RTL.

## Testing strategy

- **Unit tests, one class per protocol** (`ButtonChromeStyleTests`, `BadgeChromeStyleTests`, `CountBadgeStyleTests`, `IconTileStyleTests`, `PriceTagStyleTests`, `RadioButtonChromeStyleTests`, `SkeletonStyleTests`, `DividerStyleTests`, `CalloutChromeStyleTests`, `InlineTextStyleTests`), one per fix (`ChipStyleTitleTests`, `CustomTextStyleRegistrationTests`), and `ChromeStyleBehaviourTests` for what the protocols share. Each covers:
  - the default path is unchanged;
  - `.default` matches the built-in body pixel for pixel, and every such loop carries an in-loop control that must see a real change;
  - a custom style receives the configuration it should;
  - the component's behaviour survives on the style path where a unit test can observe it: link routing (the `openURL` action a style's body sees), the content model (slots, the loading indicator, validation messages) and the state the style is handed;
  - the style reaches ThemeKit's own compositions.
- **What the unit tests don't drive.** Taps, the loading guard and the accessibility modifiers are the same code on both paths (one tap handler, one modifier chain around the style's output). A unit-test host builds no SwiftUI accessibility tree without an assistive client, so the accessibility decisions (which label a button speaks, whether a radio has a hint) are tested as decisions, and taps aren't simulated.
- **Compile-time and resolution checks.** The stock styles are `Sendable` (a `static let` of each compiles in Swift 6 mode); `ChipStyleTitleTests`, `RadioButtonChromeStyleTests` and `CustomTextStyleRegistrationTests` compile against a plain `import ThemeKit`, as a host would; and `.indicator { }` on a `ThemeButton` still resolves to the corner overlay and draws while the button isn't loading, on both chrome paths.
- **Snapshot tests** (iOS, opt-in, iPhone 17 / iOS 26): `ButtonChromeStyleSnapshotTests`, `BadgesChromeStyleSnapshotTests`, `ChipRadioChromeStyleSnapshotTests`, `PriceTagChromeStyleSnapshotTests`, `SkeletonDividerChromeStyleSnapshotTests`, `CalloutInlineTextChromeStyleSnapshotTests` record the custom-style paths. Every existing reference must pass unchanged.
- **API check.** `swift package diagnose-api-breaking-changes` against 1.4.0 reports no breakage.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Custom-token-keyed modifiers (`.fill(_: Theme.CustomToken)`, `.textStyle(_: Theme.CustomToken)` on each component) | It reverses ADR-0008's boundary ("a token-read API, not a component-theming API") and makes every component resolve stringly consumer names. ThemeKit's `TextStyle` is more than a font: it carries the line box (line spacing, the Dynamic Type anchor), so accepting a consumer text style would need a consumer text-style line-box engine inside every component. And state-heavy chrome such as a button (variant × colour × pressed × disabled × focused × loading, plus height, padding and corner per size) would need dozens of token-keyed modifiers per component to get anywhere near a Figma spec. |
| Raw `Color` / `CGFloat` modifiers (`.fill(_: Color)`, `.cornerRadius(12)`) | Blocked by the variant-naming gate (ADR-3). The library has been deprecating exactly these, and a raw value ignores dark mode and per-subtree themes. |
| Fork or re-implement the component in the host | Loses ThemeKit's behaviour, accessibility, RTL and state handling, and every later fix. This is the outcome the ADR exists to prevent. |
| Route the default through `makeBody` too | Puts every existing screen and every snapshot reference on a new render path with a different view identity; see D3. |
| More built-in presets (a "compact", a "square" badge…) | Guesses at the host's spec instead of letting the host own it. Every guess is permanent public API, and ADR-F5's anti-sprawl rule forbids speculative presets. |
| One shared `ComponentChromeStyle` protocol for every component | The configurations have nothing in common beyond "a view", so a shared one would be a bag of optionals or `Any`, and a style couldn't tell which component it's drawing. |
