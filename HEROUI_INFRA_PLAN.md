# HeroUI Native → ThemeKit Infrastructure Plan

**Author:** iOS Architect agent · **Date:** 2026-07-10 · **Status:** PROPOSED — awaiting sr-ios-dev pressure-test
**Companion docs:** `HEROUI_NATIVE_AUDIT.md` (per-component gaps — NOT duplicated here), `MODIFIERS_PLAN.md` (init→modifier migration), `AUDIT.md` (maturity state).

## 1. Scope & non-goals

This plan translates HeroUI Native's **cross-cutting technical infrastructure** — provider/global defaults, slot composition, variant matrices, controlled/uncontrolled state, polymorphic rendering, unified tokens, platform behaviors, and form handling — into ThemeKit-native architecture that every existing component can adopt uniformly. It is the layer *above* `HEROUI_NATIVE_AUDIT.md`: that document plans per-component feature gaps (e.g. "Dropdown needs sections"); this one decides the **shared idioms and engine pieces** those gap plans should be expressed in, so 175+ components converge on one convention instead of 175 ad-hoc ones. Non-goals: no per-component re-audit, no literal port of React idioms (`className`, render props, compound `Component.Item` children), no new external dependencies (core stays zero-dep), and no breaking API changes — the library is public at v1.0.0, so every change below is additive or deprecate-and-forward.

**Ground truth this plan is built on** (verified in source):

| Existing infra | Where |
|---|---|
| `Theme` env cascade (`\.theme`, `.theme(_:)`, `.themeKit()`, `Theme.shared` fallback) | `Sources/ThemeKitCore/Theme/ThemeContext.swift`, `ThemeKit.swift` |
| `ComponentDefaults` env (radius / elevation / accent house style) | `Sources/ThemeKit/ComponentDefaults.swift` |
| `SemanticColor` (12 hues × solid/soft/accent/border + 50–900 ladder) + `FillVariant` | `Sources/ThemeKitCore/Theme/SemanticColor.swift` |
| `Motion` tokens + `MicroMotion` gate (`\.microAnimations` + Reduce Motion) | `Sources/ThemeKitCore/Theme/Motion.swift`, `MicroMotion.swift` |
| 10 Style protocols with `Configuration` + `Any…Style` erasure + env key (Card, Field, Toast, Select, Stat, Chip, Meter, ListRow, PageHeader, Bar) | e.g. `Sources/ThemeKit/Components/Organisms/CardStyle.swift` |
| Controlled/uncontrolled dual inits (precedent) | `Sources/ThemeKit/Components/Organisms/Accordion.swift`, `AccordionGroup.swift` |
| AnyView slot modifiers (precedent) | `Card.header{}/.footer{}`, `Chip.trailing{}`, `TextInput.addons(before:after:)` |
| asChild analog (precedent) | `SurfaceView.swift` → `surfaceChrome(_:radius:)` |
| Form layer | `Validation/FormValidator.swift` (`@MainActor @Observable`), `InfoMessage.swift`, `InfoMessageUI.swift` |
| Presenters | `Feedback.swift` (`FeedbackPresenter` `@Observable`), `BottomSheet.swift` (`SheetPresenter`), Dialog shared scrim/swipe chrome |

---

## 2. Infra themes (ADRs)

### T1 — Provider & global defaults

**HeroUI pattern:** `HeroUIProvider` supplies app-wide text, text-input, animation, and toast defaults from one wrapper.

**ADR-1 — Decision:** ThemeKit gets **no wrapper "provider" view**. The provider *is* the environment stack, and we complete it: keep `.themeKit()` + `.theme(_:)` + `.microAnimations(_:)` + the 10 `…Style` env modifiers as-is, and close the two real gaps with two new environment groups modeled exactly on `ComponentDefaults` (optional fields, `transformEnvironment` merge, per-call modifier always wins):

1. **`FieldDefaults`** — house defaults for the text-field family (TextInput, MultiLineTextInput, SearchBar, DateField, InputNumber, OTPInput): default size, messages animation, label behavior.
2. **`FeedbackDefaults`** — house defaults for toast/notification presentation (position, duration, max visible), read by `.feedbackHost`/`.toast` at the host layer and used as fallback when a `FeedbackPresenter.toast(...)` call doesn't specify them.

`ComponentDefaults` itself stays the umbrella for *chrome* defaults (radius/elevation/accent) and gains nothing new in this pass — text defaults are already the typography tokens, animation defaults are already `.microAnimations`.

**Rejected:**
- *`ThemeKitProvider { … }` wrapper view* — un-SwiftUI; fights composition (a subtree can't override one axis without re-wrapping), duplicates what environment already does.
- *Defaults on the `Theme` object* — global mutable state; not subtree-scopable; couples the token engine to component knobs (violates the Core/catalog split shipped in #229/#230).

**API sketch (additive):**

```swift
// Sources/ThemeKit/FieldDefaults.swift  (new, sibling of ComponentDefaults.swift)
public struct FieldDefaults: Equatable {
    public var size: TextInputSize?          // nil → component default
    public var messagesAnimated: Bool?       // InfoMessageList appear/disappear motion
    public var requiredIndicator: Bool?      // show the asterisk on .required() fields
    public init(size: TextInputSize? = nil, messagesAnimated: Bool? = nil, requiredIndicator: Bool? = nil) { … }
}

public extension EnvironmentValues { var fieldDefaults: FieldDefaults { get set } }

public extension View {
    /// House defaults for the field family in this subtree. Per-field modifiers still win.
    func fieldDefaults(size: TextInputSize? = nil,
                       messagesAnimated: Bool? = nil,
                       requiredIndicator: Bool? = nil) -> some View {
        transformEnvironment(\.fieldDefaults) { d in /* merge non-nil fields */ }
    }
}

// Sources/ThemeKit/Components/Organisms/FeedbackDefaults.swift  (new)
public struct FeedbackDefaults: Equatable {
    public var toastPosition: ToastPosition?   // .top / .bottom
    public var toastDuration: Double?
    public var maxVisibleToasts: Int?
    public init(…) { … }
}

public extension View {
    func feedbackDefaults(toastPosition: ToastPosition? = nil,
                          toastDuration: Double? = nil,
                          maxVisibleToasts: Int? = nil) -> some View { … }
}
```

Inside a field: `let effectiveSize = model.sizeExplicitlySet ? model.size : (fieldDefaults.size ?? model.size)` — same "explicit wins" resolution `ComponentDefaults` already uses for radius/elevation/accent.

**Compatibility:** purely additive. Document the full "provider recipe" in DocC as *the* HeroUIProvider equivalent:

```swift
RootView()
    .themeKit()
    .componentDefaults(radius: .field, accent: .turquoise)
    .fieldDefaults(size: .large)
    .feedbackDefaults(toastPosition: .top, toastDuration: 3)
    .microAnimations(true)
    .feedbackHost(feedback)
```

---

### T2 — Slot / compound composition

**HeroUI pattern:** compound children — `Card.Header/Body/Footer`, `TextField.Label/Description/Input/ErrorMessage`, `InputGroup` prefix/suffix.

**ADR-2 — Decision:** ThemeKit's one slot idiom is the **copy-on-write `@ViewBuilder` slot modifier storing `AnyView?`** — already live on Card/Chip/TextInput — promoted from precedent to *convention* with a fixed slot vocabulary and a shared internal helper. Required content stays a generic `@ViewBuilder` init parameter (type-preserved); **optional** slots are always modifiers (type-erased), never extra init overloads.

**Canonical slot vocabulary** (a component uses these names or none):

| Slot name | Meaning | Existing precedent |
|---|---|---|
| `.header { }` | replaces the built-in title header | `Card` |
| `.footer { }` | bottom-aligned accessory area | `Card` |
| `.leading { }` / `.trailing { }` | before/after the main content (RTL-safe by name) | `Chip.trailing{}` |
| `.label { }` | replaces a control's built-in text label | planned `ThemeButton` (audit item) |
| `.indicator { }` | replaces a state glyph (spinner, chevron, thumb) | planned Spinner/Accordion (audit items) |
| `.emptyContent { }` | shown when a collection component has no items | planned ChipGroup (audit item) |

**Rejected:**
- *Compound sub-structs (`Card.Header { … }` as children)* — a React-ism; SwiftUI has no unordered child introspection without `_VariadicView` private API; breaks the "init = content, modifiers = appearance" house rule.
- *Generic slot type parameters (`Card<Content, Header, Footer>`)* — combinatorial generic explosion (2ⁿ overloads), breaks source compatibility of every existing `Card<Content>` usage, and gains nothing measurable over `AnyView` for chrome-level slots (AUDIT already accepts 31 AnyViews for style erasure).

**API sketch (additive; the shared helper is internal):**

```swift
// Sources/ThemeKit/Extensions/SlotContent.swift  (new, internal)
/// The single blessed way to store an optional slot: type-erased, nil = "use built-in".
@usableFromInline
struct SlotContent {
    let view: AnyView
    @usableFromInline init<V: View>(@ViewBuilder _ content: () -> V) { view = AnyView(content()) }
}

// A component adopting the convention:
public extension ThemeButton {
    /// Replaces the built-in title+icon label. Inherits the size's textStyle and
    /// the variant's foreground token via .textStyle/.foregroundStyle defaults.
    func label<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.customLabel = SlotContent(content).view }
    }
}
```

Slot content must render correctly with **zero configuration** (inherits `textStyle` + token foreground from the surrounding chrome via environment, as Card's header slot already does). This section is the *convention*; which components grow which slot is already sequenced per-component in `HEROUI_NATIVE_AUDIT.md`.

**Compatibility:** additive. No existing slot is renamed; `TextInput.addons(before:after:)` keeps its domain name (it's an input-group concept, not a generic slot) but is documented as the InputGroup prefix/suffix answer.

---

### T3 — Variant matrices

**HeroUI pattern:** every component exposes a uniform `color × variant × size` matrix (`color="success" variant="soft" size="sm"`).

**ADR-3 — Decision:** the canonical ThemeKit matrix is the **triad already carried by ThemeButton**, promoted to a library-wide naming contract:

| Axis | Modifier | Type | Notes |
|---|---|---|---|
| Color | `.color(_ c: SemanticColor)` | the 12-hue semantic enum | never raw `Color` |
| Fill | `.variant(_ v: FillVariant)` | `.solid/.soft/.outline/.ghost` | status organisms (InfoBanner/Callout/AlertToast) keep their richer semantic type enum but expose it as `.variant(_:)` — already true |
| Size | native `.controlSize(_:)` where the component maps to ControlSize; else `.size(_ s: <Component>Size)` | per-component ramp enum | never a CGFloat knob |

Enforcement work is a **sweep, not a redesign**: (a) grep-audit all copy-on-write modifiers against the table; (b) deprecate-and-forward the stragglers — notably the raw-`Color` escape hatches found in the survey (`func color(_ c: Color?)` on Icon and 2–3 atoms) get `@available(*, deprecated, message: "Use color(_: SemanticColor) or colorOverride(token:)")` per the token-fed-modifiers rule; (c) add a CI grep gate (`scripts/check-variant-naming.sh`) so new components can't drift.

**Rejected:**
- *A generic `StyleMatrix` protocol (`Configurable { color; variant; size }`)* — protocol-with-Self plumbing across 175 value types for zero rendering benefit; the matrix is a *naming* contract, not a type-system one.
- *One mega-modifier `.style(color:variant:size:)`* — hides the axes, fights chainability, and collides with the existing `…Style` protocol vocabulary.

**Compatibility:** additive + deprecations. Deprecated raw-Color modifiers forward to the token path where a lossless mapping exists, else keep rendering but warn.

---

### T4 — Controlled vs uncontrolled state

**HeroUI pattern:** `isOpen`/`defaultOpen`/`onOpenChange` — every stateful component works uncontrolled by default and controlled on demand.

**ADR-4 — Decision:** standardize the **dual-init pattern Accordion already ships** — `initiallyX:` seeds `@State` (uncontrolled), an overload takes `x: Binding<…>` (controlled) — and extract its plumbing into one reusable `DynamicProperty` so the other ~10 stateful components adopt it without re-implementing the fallback dance. **No `onOpenChange`:** `Binding` *is* the change channel; observers use `.onChange(of:)` at the call site.

**Standard vocabulary:** expansion → `initiallyExpanded:` / `isExpanded: Binding<Bool>` (`expanded: Binding<Set<ID>>` for groups); presentation → `isPresented: Binding<Bool>`; selection → `selection: Binding<…>` (already universal).

**API sketch:**

```swift
// Sources/ThemeKitCore/Utils/ControllableState.swift  (new, public — Core so both layers can use it)
/// Unifies the uncontrolled (@State-seeded) and controlled (Binding-driven) paths of a
/// component's interaction state behind one accessor. The Accordion pattern, extracted.
@propertyWrapper
public struct ControllableState<Value>: DynamicProperty {
    @State private var stored: Value
    private let external: Binding<Value>?

    /// Uncontrolled: the initial value seeds internal @State.
    public init(wrappedValue: Value) {
        _stored = State(initialValue: wrappedValue); external = nil
    }
    /// Controlled: reads/writes flow through the caller's binding.
    public init(wrappedValue: Value, external: Binding<Value>?) {
        _stored = State(initialValue: external?.wrappedValue ?? wrappedValue)
        self.external = external
    }

    public var wrappedValue: Value {
        get { external?.wrappedValue ?? stored }
        nonmutating set {
            if let external { external.wrappedValue = newValue } else { stored = newValue }
        }
    }
    /// Hand to child views / gestures exactly like a normal binding.
    public var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}

// Adoption shape (Dropdown example — matches its existing audit gap item):
public struct Dropdown…: View {
    @ControllableState private var isPresented = false
    public init(…) { … }                                      // uncontrolled (today's API, unchanged)
    public init(…, isPresented: Binding<Bool>) {              // controlled overload
        _isPresented = ControllableState(wrappedValue: false, external: isPresented)
    }
}
```

**Rollout targets** (each is already an `[low]`/`[high]` line in `HEROUI_NATIVE_AUDIT.md`; this ADR fixes *how*): Dropdown, Select (panel mode), Tooltip/Popconfirm self-managed mode, Rating hover…, plus a no-API-change refactor of Accordion/AccordionGroup onto the wrapper to prove parity.

**Rejected:**
- *Controlled-only (always require a Binding)* — breaking, and punishes the 90% drop-in case.
- *`onOpenChange` callback pairs* — duplicates Binding; two sources of truth; a React-ism.

**Compatibility:** additive (new overloads); the Accordion refactor is behavior-neutral (existing tests + snapshot must stay green).

---

### T5 — Polymorphic rendering (asChild analog)

**HeroUI pattern:** `asChild` lets a component donate its chrome/behavior to an arbitrary child element.

**ADR-5 — Decision:** ThemeKit's general idiom is the **chrome view-extension family**: when a container's shell is independently useful, expose it as a `View` extension that applies the *same tokens and the same active Style protocol* the organism uses — exactly what `surfaceChrome(_:radius:)` already does for SurfaceView. Ship two more members to make it a family, not a one-off:

```swift
// Card's shell on any view, driven by the *active* .cardStyle — so a consumer's
// custom CardStyle re-skins bespoke layouts too.
public extension View {
    /// Applies the active CardStyle's surface (fill, border, shadow, radius) to this
    /// view without adopting Card's header/body anatomy. (asChild analog.)
    func cardChrome(elevation: CardElevation = .soft,
                    surface: Theme.BackgroundColorKey = .bgWhite,
                    radius: Theme.RadiusRole = .box) -> some View {
        modifier(CardChrome(elevation: elevation, surface: surface, radius: radius))
        // internally: cardStyle.makeBody(configuration: .init(content: AnyView(content), …))
    }

    /// Applies the active FieldStyle's chrome (fill, border, focus/error border) to a
    /// custom control so bespoke inputs sit visually inside the form family.
    func fieldChrome(isFocused: Bool = false, hasError: Bool = false) -> some View { … }
}
```

Content-side polymorphism (custom label inside a button, custom row inside a list) is **T2's slot modifiers** — the two halves together fully replace `asChild`/render-props: slots customize the inside, chrome extensions donate the outside.

**Rejected:**
- *A `ChromeDonating` protocol / generic `asChild(of:)`* — abstraction with one call shape; the three concrete extensions are simpler and each rides its existing Style env.
- *Publishing the `…Chrome` private views* — leaks style internals; the extension + env-style indirection keeps them private.

**Compatibility:** additive.

---

### T6 — Unified theme tokens (backdrop, soft foreground, radius capping)

**HeroUI pattern:** a `--backdrop` variable for scrims, soft-foreground tokens per color, and `min()`-capped border-radius so small elements never over-round.

**ADR-6 — Decision (three token moves):**

1. **Backdrop token.** Today Dialog hardcodes `theme.background(.bgTertiary).opacity(0.4)` and Drawer/Tour roll their own. Add one semantic key — `Theme.BackgroundColorKey.bgBackdrop` — emitted by the JSON token generator (light: black @ ~40%, dark: black @ ~55%, per-theme overridable), and a tiny shared atom used by every presenter:

```swift
// Sources/ThemeKit/Components/Atoms/Backdrop.swift  (new)
/// The standard modal scrim: bgBackdrop fill, fade-only transition, optional
/// progress dimming for drag-to-dismiss. Used by Dialog, Drawer, Tour, Popconfirm.
struct Backdrop: View {
    var fade: Double = 1                       // dismiss-drag progress hook
    @Environment(\.theme) private var theme
    var body: some View {
        theme.background(.bgBackdrop).opacity(fade).ignoresSafeArea()
    }
}
```
    The always-dark **media scrims** over imagery (`.black.opacity(0.35)` × 10 sites in travel cards) are *not* backdrop: they must stay dark in dark mode over photos. Give them one shared constant pair (`MediaScrim.solid` / `MediaScrim.gradient`) in `Effects.swift` rather than a theme key, and sweep the 10 sites onto it.

2. **Soft foreground.** Already covered: `SemanticColor.accent` (soft/outline/ghost foreground) + the `strong`/`shade(.s700)` ladder role. **No new API** — document the mapping (`HeroUI text-{color}-soft` → `SemanticColor.accent`; `-soft-hover` → `.strong`) in the SemanticColor DocC article so component authors stop reaching past it.

3. **Radius capping.** Add two additive helpers on the radius engine (no per-component GeometryReader mandated — callers that already know their height use them; pill-shaped atoms keep `Capsule`):

```swift
public extension Theme.RadiusRole {
    /// The role's radius, capped so a small element never over-rounds (HeroUI min()).
    func value(cappedFor height: CGFloat) -> CGFloat { min(value, height / 2) }
    /// Concentric inner radius: outer role minus the inset, floored at 0 —
    /// the standard nested-corner relationship (already hand-computed in FlightListItemStyle).
    func concentric(inset: Theme.SpacingKey) -> CGFloat { max(value - inset.value, 0) }
}
```

**Rejected:**
- *Opacity-in-code (`bgTertiary.opacity(0.4)`) as the blessed pattern* — not themable per-brand, and dark themes need a different strength.
- *A backdrop* ViewModifier *on every presenter ad hoc* — that's the current drift; the shared atom is the fix.

**Compatibility:** additive token + helpers; Dialog/Drawer/Tour adopt `Backdrop` in a behavior-preserving PR (snapshots guard the 0.4 look in the default theme).

---

### T7 — Platform behaviors (dismiss gestures, motion gating, type/RTL)

**HeroUI pattern:** swipe-to-dismiss, native modal offsets, Dynamic Type, RTL, reduced-motion handling as platform-level guarantees.

**ADR-7 — Decision:** most of this axis is **already ThemeKit law** (Dynamic Type via `.textStyle`, RTL-by-construction + `.flipsForRightToLeftLayoutDirection`, Reduce Motion via `MicroMotion` — 118 call sites per AUDIT). The one genuinely shared *mechanism* still duplicated is the **dismiss drag**: Dialog's scrim-fading swipe, FeedbackToastRow's swipe, and the planned detached-sheet drag are three hand-rolled copies of one gesture. Extract it:

```swift
// Sources/ThemeKit/Extensions/DismissDrag.swift  (new; internal first, public if a
// third-party presenter needs it later)
/// The standard dismiss gesture: drag along `edge`, card offsets with the finger,
/// `progress` reports 0…1 for scrim fading, releases past `threshold` call `onDismiss`,
/// otherwise spring back via Motion.base — all gated by microAnimations + Reduce Motion
/// (gesture still works with motion off; only the animation is dropped).
func dismissDrag(edge: Edge,
                 threshold: CGFloat = 0.33,
                 progress: Binding<Double>? = nil,
                 onDismiss: @escaping () -> Void) -> some View
```

Adoption: Dialog (replace its private copy), toast rows, detached BottomSheet, Drawer panel. Everything else on this axis stays per-component work already listed in the audit (native sheet detents/`presentationCornerRadius` etc.).

**Rejected:** *a `PlatformBehaviors` env config object* — the behaviors are per-surface, not per-subtree; existing native modifiers (`.interactiveDismissDisabled`, `.presentationDetents`) already carry the policy.

**Compatibility:** internal extraction, behavior-neutral (Dialog's tuned feel is the reference implementation; snapshot + demo verify).

---

### T8 — Form validation & submission

**HeroUI pattern:** form-level validation state, submission handling, and field wiring as a framework concern, not per-field plumbing.

**ADR-8 — Decision:** keep `FormValidator` as the single form brain (it already does rules-per-field, dominant-kind messages, first-invalid focus) and remove the remaining per-field boilerplate with a **direct wiring modifier** on the field family, plus a submit convenience:

```swift
// Sources/ThemeKit/Validation/FormWiring.swift  (new)
public extension TextInput {
    /// Wires this field into a FormValidator: renders its [InfoMessage]s, adopts its
    /// focus binding, and re-validates live on editing end after a failed submit.
    /// Replaces the three-line infoMessages + externalFocus + validate dance.
    func field<F: Hashable>(_ field: F, in form: FormValidator<F>) -> Self {
        self.infoMessages(form.messages(for: field))
            .externalFocus(form.focusBinding(field))
            .onValidation { _ in }            // exact composition for sr-ios-dev to settle:
                                              // live revalidate hook → form.validate(field, text)
    }
}
// Same one-liner on MultiLineTextInput, SearchBar, DateField, SelectBox (their
// infoMessages/focus APIs already exist; the modifier is sugar, not new state).

public extension FormValidator {
    /// Submission handling: validate everything, focus the first invalid field,
    /// run `action` only when clean. `Button("Pay") { form.submit(values) { pay() } }`
    @discardableResult
    func submit(_ values: [Field: String], onValid action: () -> Void) -> Bool {
        if validateAll(values) == nil { action(); return true }
        return false
    }
}
```

**Rejected:**
- *Environment-cascaded validator (`.formValidator(form)` + `.field(.email)` with no `in:`)* — `FormValidator<Field>` is generic; the environment would need an `AnyFormValidator` erased over `AnyHashable` fields, trading a compile-time-safe one-liner for stringly-ish lookup. Not worth it while `in:` costs six characters. (Flagged below as an open question in case sr-ios-dev finds erasure cheap.)
- *A `ThemeForm { }` result-builder container* — components must stay stateless/data-driven (house rule 1); a form DSL drags app-state shape into the library.

**Compatibility:** additive sugar over existing APIs; `FormValidator` unchanged except the `submit` extension.

---

## 3. Sequenced backlog

PR-per-unit, ordered by dependency then leverage. Every unit lands with `#Preview` coverage and a Demo/Gallery hook verified by `xcrun simctl launch <bundle> -startTab 0 -openDemo "<Name>"`.

**Sprint I-1 — engine primitives (everything else builds on these)**

| # | Unit | Effort | Files | Verify |
|---|---|---|---|---|
| 1 | `ControllableState` property wrapper + behavior-neutral refactor of Accordion/AccordionGroup onto it | **medium** | new `Sources/ThemeKitCore/Utils/ControllableState.swift`; `Organisms/Accordion.swift`, `AccordionGroup.swift`; unit test for controlled/uncontrolled parity | existing Accordion previews + `-openDemo "Accordion"`; snapshot unchanged |
| 2 | `bgBackdrop` token (generator + all theme JSONs) + `Backdrop` atom + adopt in Dialog/Drawer/Tour | **medium** | `ThemeKitCore` generator + token JSONs; new `Atoms/Backdrop.swift`; `Organisms/Dialog.swift`, `Drawer.swift`, `Tour.swift` | `-openDemo "Dialog"` light/dark; scrim snapshots |
| 3 | Radius capping helpers (`value(cappedFor:)`, `concentric(inset:)`) + retrofit the hand-computed FlightListItem site | **low** | `ThemeKitCore/Theme/ThemeModel.swift`; `Organisms/FlightListItemStyle.swift` | unit tests on the math; `-openDemo "Flight List Item"` |
| 4 | `MediaScrim` shared constants + sweep the ~10 `.black.opacity(…)` media-scrim sites | **low** | `Utils/Effects.swift`; DestinationCard/HotelResultCard/BlogCard/LocationCard/ImageCollage/VideoPlayerView | snapshots of the travel cards |

**Sprint I-2 — provider completion**

| # | Unit | Effort | Files | Verify |
|---|---|---|---|---|
| 5 | `FieldDefaults` env + resolution in TextInput/MultiLineTextInput/SearchBar/DateField/InputNumber/OTPInput | **medium** | new `FieldDefaults.swift`; 6 field files (read-side only) | new "Field Defaults" demo section; `-openDemo "Text Input"` |
| 6 | `FeedbackDefaults` env + fallback wiring in `.feedbackHost`/`.toast`/FeedbackPresenter host layer | **medium** | new `Organisms/FeedbackDefaults.swift`; `Feedback.swift`, `Toast.swift` | `-openDemo "Feedback"`; toast position/duration demo toggles |
| 7 | DocC "Global defaults (Provider)" article — the one-stop recipe (T1 sketch) + SemanticColor soft-foreground mapping table (T6.2) | **low** | `Documentation.docc` | docs build in CI |

**Sprint I-3 — conventions rollout**

| # | Unit | Effort | Files | Verify |
|---|---|---|---|---|
| 8 | Variant-matrix sweep: audit script (`scripts/check-variant-naming.sh` in CI) + deprecate-and-forward raw-`Color` modifiers and off-convention names | **medium** | script + `.github/workflows/ci.yml`; the 4–6 straggler component files | `swift build` warning-clean except intended deprecations; api-breakage gate green |
| 9 | `SlotContent` helper + slot-vocabulary section in the `themekit-authoring` skill/CONTRIBUTING; convert Card/Chip's existing slots to the helper (no API change) | **low** | new `Extensions/SlotContent.swift`; `Card.swift`, `Chip.swift`; `.claude/skills/themekit-authoring` | Card/Chip previews + snapshots unchanged |
| 10 | Controlled-state rollout wave: `isPresented:` overloads on Dropdown, Select (panel), Tooltip/Popconfirm self-managed mode via `ControllableState` | **medium** | `Molecules/Dropdown.swift`, `Select.swift`, `Tooltip.swift`, `Organisms/Popconfirm.swift` | `-openDemo` each; controlled-binding demo toggles |
| 11 | `dismissDrag` extraction + adoption in Dialog (replace private copy), toast rows, Drawer | **medium** | new `Extensions/DismissDrag.swift`; `Dialog.swift`, `Feedback.swift`, `Drawer.swift` | `-openDemo "Dialog"` swipe; Reduce-Motion sim check |

**Sprint I-4 — capstones**

| # | Unit | Effort | Files | Verify |
|---|---|---|---|---|
| 12 | Chrome family: `cardChrome` + `fieldChrome` view extensions riding the active Style envs | **medium** | `Organisms/CardStyle.swift` (or new `Extensions/Chrome.swift`); `Molecules/FieldStyle.swift` | new "Chrome" demo page; custom-CardStyle re-skin check |
| 13 | Form wiring: `.field(_:in:)` on the field family + `FormValidator.submit(_:onValid:)` + demo form page exercising focus-first-invalid | **high** | new `Validation/FormWiring.swift`; `FormValidator.swift`; Demo form page | `-openDemo "Form"`; live-revalidate + submit flow on sim |
| 14 | `FeedbackPresenter` per-toast position/lifecycle hooks consuming FeedbackDefaults (overlaps audit's Toast items — implement once, here) | **low** | `Feedback.swift` | `-openDemo "Feedback"` |

Leverage note: units 1, 5–6, and 8 unblock or standardize the largest number of per-component audit items; unit 13 is the biggest single consumer-facing win.

## 4. Open questions for the Sr. iOS Dev

Pressure-test each with a real call site and a Swift 6 build before locking the ADR:

1. **`ControllableState` feasibility (ADR-4, unit 1).** Does a custom `DynamicProperty` wrapping `@State` + an optional captured `Binding` behave correctly under Swift 6 strict concurrency (does it need `@MainActor`? does `nonmutating set` through the captured binding update out-of-band during view updates?), and does seeding `@State` from `external?.wrappedValue` in `init` fight SwiftUI's state persistence across identity changes? Validate with the Accordion refactor: controlled and uncontrolled previews must be behaviorally identical to today.
2. **`sending`/AnyView in `SlotContent` (ADR-2, unit 9).** The style-erasure inits already need `sending S` under Swift 6 — do slot modifiers taking `@ViewBuilder () -> V` need the same treatment, and is there any animation/identity regression when a slot's `AnyView` is rebuilt every `copy(_:)`?
3. **FeedbackDefaults reach (ADR-1, unit 6).** `FeedbackPresenter.toast(...)` is called from outside the view tree, so environment can't reach the *call*; the plan reads defaults at the `.feedbackHost` layer and applies them to items that didn't specify explicit values. Is "nil-means-default" representable in `ToastItem` without breaking its public initializer, or does this need a parallel internal item type?
4. **Environment-erased FormValidator (ADR-8 rejected alternative).** Is `AnyFormValidator` over `AnyHashable` fields actually cheap in Swift 6 (`@MainActor @Observable` + generic subscripting), such that `.field(.email)` without `in:` becomes worth it? If yes, ADR-8 upgrades; if not, `.field(_:in:)` ships as designed.
5. **`fieldChrome` configuration surface (ADR-5, unit 12).** `FieldStyleConfiguration` carries focus/error/warning state — what's the minimal knob set for the public extension that doesn't leak the whole configuration struct, and can it stay `some View` (no AnyView) end-to-end?
6. **Deprecation sweep vs the api-breakage CI gate (unit 8).** Confirm `@available(*, deprecated)` on existing public modifiers passes `check-api.sh`, and pick the forwarding story for `func color(_ c: Color?)` call sites where no lossless token mapping exists (keep rendering + warn vs `colorOverride` escape hatch).

---

## Sr. iOS Dev review (feasibility pass)

**Reviewer:** sr-ios-dev agent · **Date:** 2026-07-10 · **Evidence:** source inspection of every file the plan cites, two `swiftc -typecheck -swift-version 6` probes (arm64 iOS 17 simulator target), one executable overload-resolution probe, and a **live `scripts/check-api.sh HEAD` run** at `b3b8a5f` with probe edits applied. No claims below are from memory.

Ground-truth check first: every precedent §1 cites **exists as described** — Accordion's dual init + `externalExpanded` fallback (`Accordion.swift:66–91`), Card/Chip/TextInput `AnyView?` slots (`Card.swift:166–174`, `Atoms/Chip.swift:136–141`, `TextInput.swift:457`), `surfaceChrome(_:radius:)` (`SurfaceView.swift:102`), the 10 `…Style` protocols with `sending S` erasure (`CardStyle.swift:136`, `FieldStyle.swift:157`), `FormValidator` (`@MainActor @Observable`, `focusBinding`, `validateAll → Field?`), and the `FeedbackPresenter`/`FeedbackHostModifier` split. Where the plan's *claims about gaps* diverge from source, it's flagged below — several planned items are already partially or fully shipped.

### 1. Verdicts on the §4 open questions

**Q1 — `ControllableState`: FEASIBLE, compile-proven, with one required change.**
The architect's exact sketch typechecks under Swift 6 strict concurrency but emits `SendableClosureCaptures` **warnings** in `projectedValue` (the plain `Binding(get:set:)` overload takes `@Sendable` closures in the iOS 17+ SDK, and `ControllableState` is not Sendable). Adding **`@MainActor` to `wrappedValue` and `projectedValue`** selects the MainActor-isolated `Binding` initializer and the whole thing typechecks **warning-clean** (verified: `swiftc -typecheck -swift-version 6 -target arm64-apple-ios17.0-simulator` → PASS, including an Accordion-shaped dual-init adoption, a Dropdown-shaped optional-binding adoption, a `Toggle(isOn: $expanded)` projected-value hand-off, and `withAnimation { expanded.toggle() }` through the `nonmutating set`). Specifics:
- **No `@MainActor` on the struct** — mirror `State` itself; only the accessors are isolated. `Value` needs no `Sendable` bound.
- **`@State` seeding in `init` is safe**: in controlled mode `stored` is never read (the getter short-circuits to `external`), so the seed being stale across identity changes is unobservable; in uncontrolled mode it's exactly today's `State(initialValue:)` semantics. One documented rule: a call site must not *switch* a live view between controlled and uncontrolled across renders (same today with Accordion — the `@State` would rejoin at its old value).
- **`nonmutating set` through the captured binding** is byte-for-byte what `Accordion.setExpanded` does today from button/gesture handlers — writes happen outside body evaluation; no out-of-band update hazard.
- **`DynamicProperty`**: the synthesized conformance (nested `@State` registers storage) is sufficient; no custom `update()` needed.
- Placement in `ThemeKitCore` is fine — Core already imports SwiftUI (`ThemeContext.swift`).

Final struct (the one that passed):

```swift
@propertyWrapper
public struct ControllableState<Value>: DynamicProperty {
    @State private var stored: Value
    private let external: Binding<Value>?

    public init(wrappedValue: Value) {
        _stored = State(initialValue: wrappedValue); external = nil
    }
    public init(wrappedValue: Value, external: Binding<Value>?) {
        _stored = State(initialValue: external?.wrappedValue ?? wrappedValue)
        self.external = external
    }
    @MainActor public var wrappedValue: Value {
        get { external?.wrappedValue ?? stored }
        nonmutating set {
            if let external { external.wrappedValue = newValue } else { stored = newValue }
        }
    }
    @MainActor public var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
```

**Q2 — Slots need no `sending`; `AnyView` identity is safe; one documented rule.**
Slot modifiers take a **non-escaping** `@ViewBuilder` closure evaluated immediately on the caller (which is MainActor, since modifiers run during body construction) — nothing crosses an isolation boundary, so no `sending`. The style erasers need it only because `AnyCardStyle` stores an *escaping* closure into an environment key. Proof by existing code: `Card.header{}`, `Chip.leading{}/.trailing{}`, `TextInput.trailing{}` all compile today in v6 language mode with exactly the proposed shape. Identity: `AnyView` diffs by the dynamic type of the wrapped view; the slot is re-erased on every parent body evaluation but wraps the *same concrete type* each time, so SwiftUI structurally diffs the content — `@State` inside slot content survives, transitions run (Card's slots have snapshot coverage proving it). The only real hazard: a call site that puts an `if/else` of two *different* view types directly in a slot loses branch identity (cross-fade instead of insert/remove) — document "wrap alternating slot content in `.id(_:)`" in the authoring skill. Two nits on the `SlotContent` sketch: drop `@usableFromInline` (no inlinable clients; plain `internal` is right), and give it a convenience accessor so adoption is `copy { $0.customLabel = SlotContent(content) }` storing `SlotContent?` — slightly clearer than storing the unwrapped `AnyView`.

**Q3 — FeedbackDefaults reach: WORKABLE, no parallel item type, three separate mechanics.**
Source facts that reshape this question: (a) `ToastItem`'s memberwise init is **internal** — only `id` is public — so "breaking its public initializer" is moot; (b) `ToastItem.position` *already* implements nil-falls-back-to-host (`Feedback.swift:90–91, 393`); (c) `duration: Double? = 2.5` already overloads `nil` to mean **sticky**, so nil cannot also mean "use default", and a defaulted argument cannot detect omission; (d) the presenter's `maxVisibleToasts` is a `private let` fixed in `FeedbackHostModifier.init`, where the environment is **not readable** (`@State` presenter is constructed before env injection). Prescription, all additive:
1. **position** — read `\.feedbackDefaults` in `FeedbackHostModifier.body` as the fallback ahead of the `feedbackHost(toastPosition:)` parameter. No item change.
2. **maxVisibleToasts** — make the presenter's cap `var` (internal setter) and sync it from the environment in host `body`.
3. **duration** — resolve at the host layer, where the environment *is* readable (`FeedbackToastRow` is in the view tree). Represent "unspecified" with an internal flag on `ToastItem`; publicly, add an **omitted-argument overload pair**: a second `toast(...)` *without* the `duration` parameter. Verified by an executable probe: a call omitting `duration:` resolves ambiguity-free to the new overload (Swift prefers not synthesizing the default), `duration: nil` (sticky) and `duration: 3` still hit the existing signature, and every current call site compiles unchanged. Same treatment for the custom-content `toast {}` overload and `notify`.

One flag for the implementer: `FeedbackPresenter` is `@Observable` but **not `@MainActor`**. Don't "fix" that in this pass (adding `@MainActor` to a public class is source-breaking for nonisolated callers); the new members should simply follow the class's current isolation.

**Q4 — `AnyFormValidator`: NO. Ship `.field(_:in:)` as designed.**
Erasure is *runtime*-cheap (an `AnyHashable`-keyed facade whose closures capture the concrete validator keeps `@Observable` tracking intact), so cost was never the issue. The disqualifiers are structural: (1) `.field(.email)` under a host keyed by a different `Field` type becomes a silent no-op — the compile-time safety `in:` gives us for free is exactly what the token-fed-modifiers rule exists to protect; (2) it compiles with *no* `.formValidator()` ancestor at all — another silent no-op; (3) TextInput's modifiers are copy-on-write `-> Self` calls evaluated in the parent's body, where **environment is not readable** — an env-cascaded validator would force the wiring into deferred body-time lookup state, i.e. real machinery replacing a six-character parameter. Verified the sketch composes: `infoMessages(_:)` (TextInput.swift:498), `externalFocus(_:)` (:522), `onValidation(_:)` (:519) all exist as `-> Self` modifiers. ADR-8's rejected alternative stays rejected. (But see the T8 correction in §3 — the *family* claim is wrong.)

**Q5 — `fieldChrome` knobs: feasible; two knobs must be added to the sketch.**

```swift
public extension View {
    /// Applies the active FieldStyle's chrome (fill + state border) to a custom
    /// control so bespoke inputs sit visually inside the form family.
    func fieldChrome(isFocused: Bool = false,
                     hasError: Bool = false,
                     hasWarning: Bool = false,
                     size: TextInputSize = .medium) -> some View
}
```

- **`hasWarning` is required**: all three stock `FieldStyle`s branch on it (`FieldStyle.swift:56, 90, 120`); omitting it makes the warning border unreachable from bespoke controls.
- **`size` is required**: `FieldStyleConfiguration.size` is public and custom styles may key chrome off it; default `.medium` matches `TextInputModel`.
- **`isEnabled` must NOT be a parameter** — the modifier reads `@Environment(\.isEnabled)` (house rule: native for native), matching how TextInput populates the configuration.
- It stays `some View` end-to-end from the caller's perspective; internally one `AnyView(content)` feeds `FieldStyleConfiguration` — the identical erasure cost TextInput already pays per the accepted style-erasure budget. `FieldStyleConfiguration` is already public, so nothing new leaks; the extension just must not *take* one as a parameter, and it doesn't.

**Q6 — Deprecation sweep vs the gate: CONFIRMED GREEN, empirically.**
`scripts/check-api.sh` exists (wraps `swift package diagnose-api-breaking-changes` vs latest tag/PR base, with `.api-breakage-allowlist.txt`), and the CI job (`ci.yml` `api-breakage`) is PR-only and **informational** — a nonzero exit downgrades to `::warning`, never red. I ran the experiment rather than guessing: added `@available(*, deprecated)` to `Spinner.color(_:)` **and** a new `bgBackdrop` case to the public `BackgroundColorKey` enum, then ran `scripts/check-api.sh HEAD` → **"No breaking changes detected in ThemeKit", exit 0**. So both the T3 deprecations and the T6 token-enum addition pass the gate with no allowlist entries. (Probe edits reverted.)
Forwarding story: **already decided by shipped precedent** — `Icon.color(_:)` is deprecated and forwards to an *internal* `colorOverride(_:)` that keeps rendering (`Icon.swift:61–66`); `InlineText.color(_:)` ships the same pattern. Adopt it verbatim for the stragglers: deprecate + forward internally + keep rendering, message pointing at the token path. And a scope correction that shrinks unit 8 (see §3): the sweep is **~80% already shipped**.

### 2. Call-site pressure test — top 3 backlog units

**Unit 1 — `ControllableState` + Accordion refactor. Verdict: SHIP WITH CHANGES.**
Changes: (1) `@MainActor` on both accessors (Q1 — otherwise warning-noise in every adopter); (2) Accordion's two public inits stay **byte-identical** — only `_expanded`/`externalExpanded`/`isExpanded`/`setExpanded` collapse onto the wrapper; (3) add the controlled/uncontrolled parity unit test the plan names, plus one for "controlled write propagates to the binding, uncontrolled write doesn't touch it".

```swift
// Uncontrolled — today's API, unchanged:
Accordion("What is your refund policy?", initiallyExpanded: true) {
    Text("You can request a refund within 14 days of purchase.")
}
// Controlled — today's API, unchanged:
@State private var open = false
Accordion("Controlled from outside", isExpanded: $open) { Text("…") }

// Inside Accordion, after:
@ControllableState private var expanded: Bool
// init 1: _expanded = ControllableState(wrappedValue: initiallyExpanded)
// init 2: _expanded = ControllableState(wrappedValue: false, external: isExpanded)
// body:  withAnimation(motion) { expanded.toggle() }   // replaces setExpanded(!isExpanded)
//        .animation(motion, value: expanded)
```

This compiles (proven, §Q1) and reads better than the fallback dance it replaces.

**Unit 2 — `bgBackdrop` token + `Backdrop` atom. Verdict: SHIP WITH CHANGES (one is mandatory).**

```swift
// Dialog's presentation chrome, after:
if isPresented {
    Backdrop(fade: scrimFade)                 // replaces bgTertiary.opacity(0.4 * scrimFade)
        .onTapGesture { dismissFromScrim() }
    dialogCard
        .transition(.scale(scale: 0.96).combined(with: .opacity))
}
// Drawer: Backdrop(fade: scrimFactor) — same shape, replaces its private copy.
```

1. **MANDATORY — missing-token fallback.** `Theme.background(_:)` returns **`.clear`** for absent keys (`Theme.swift:243`). Every consumer theme JSON in the wild lacks `bg-backdrop`, so the naive `theme.background(.bgBackdrop)` renders an **invisible scrim** — a silent, ugly regression for every app with a custom theme. `Backdrop` (or a `Theme.backdrop` accessor) must fall back in code, mirroring the `RadiusRole` pattern (`radiusList[role] ?? fallback`): `background[.bgBackdrop] ?? background(.bgTertiary).opacity(0.4)`.
2. `tools/gen_tokens.py` has **stale output paths** (`Sources/ThemeKit/Resources` / `Sources/ThemeKit/Theme` — pre-#229 Core split; real files live under `Sources/ThemeKitCore/`). Fix the paths in this PR or the "emitted by the generator" claim silently becomes "hand-edit the generated file".
3. The JSON format supports alpha hex (`00092914` skeleton token precedent), so a translucent token needs no format work. The enum-case addition passes the API gate (proven, §Q6).
4. **Tour dims at 0.6, not 0.4** (`Tour.swift:124`); Dialog/Drawer use 0.4. One token can't carry both — either accept Tour converging on the standard strength (snapshot churn, my recommendation: yes, that's the point of the token) or give `Backdrop` an emphasis multiplier. Decide in the PR, don't discover it in snapshots.

**Unit 3 — Radius capping helpers. Verdict: SHIP WITH CHANGES.**
The cited retrofit site doesn't type-check against the sketch: `FlightListItemStyle.swift:767` computes `Theme.RadiusKey.base.value - Theme.SpacingKey.xs.value` — it's on **`RadiusKey`** (size ramp), not `RadiusRole`. Put both helpers on **both enums** (implement once on `RadiusKey`, forward from `RadiusRole` through its resolved value), otherwise the plan's own verification target can't adopt them. Note the existing site also has no `max(…, 0)` floor — the helper is a strict improvement.

```swift
// FlightListItemStyle retrofit:
private var cardRadius: CGFloat { Theme.RadiusKey.base.concentric(inset: .xs) }   // was: base.value - xs.value

// Capped corner on a small element:
RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value(cappedFor: rowHeight),
                 style: .continuous)
```

`value(cappedFor:)` overloading the `value` property by argument list is legal and reads fine. Resolution through `Theme.shared` matches the existing `.value` behavior — consistent, keep it.

### 3. Sequencing corrections

The sprint ordering and dependency direction are right (engine primitives → provider → conventions → capstones). Five scope corrections, two of which the architect could not have seen without the source:

| Unit | Correction | Effort re-tag |
|---|---|---|
| 2 | Add the mandatory missing-token fallback + `gen_tokens.py` path fix + the Tour-0.6 decision (above) | stays **medium** |
| 5 | `TextInputModel.size` is a non-optional `public var` with `= .medium` init default — "explicit wins" is **undetectable** for init-passed sizes. Add an internal `explicitSize: TextInputSize?` set by the `.size(_:)` modifier; resolve `explicitSize ?? fieldDefaults.size ?? model.size`, and document that the (init-era, MODIFIERS_PLAN-legacy) `size:` init parameter yields to FieldDefaults | stays **medium** |
| 8 | **Shrinks.** The raw-`Color` deprecation sweep is ~80% shipped: Icon, InlineText, Spinner, AmenityGrid, RadioButton, PriceHistogram, RadialProgress, RollingNumber, Badge already carry `@available(*, deprecated)` toward token paths (verified per-symbol). Un-deprecated stragglers: `Indicator.indicatorDot(_ color: Color?)`, `EmptyState.iconForeground/iconBackground`. Re-scope to: naming-audit script + CI wiring + 2–3 stragglers | **medium → low** |
| 10 | **Mostly a refactor, not new API.** Dropdown *already has* `isPresented: Binding<Bool>? = nil` + `@State` fallback (`Dropdown.swift:228–260`); Select has `externalExpanded` (`Select.swift:87`); Tooltip ships both a binding-driven modifier and a self-managed `@State` wrapper. The only genuinely new API is an **uncontrolled overload for Popconfirm** (today controlled-only, `@Binding isPresented`). Re-scope: behavior-neutral `ControllableState` adoption ×3 + one Popconfirm overload | **medium → low/medium** |
| 13 | **Must split — the plan's premise is wrong for 3 of 5 fields.** Only TextInput has `externalFocus`; MultiLineTextInput, SearchBar, DateField (and SelectBox) have `infoMessages` but **no focus API** — "the modifier is sugar, not new state" only holds for TextInput. Split: **13a** add `externalFocus` plumbing to the rest of the field family (new state, its own PR, prerequisite); **13b** `.field(_:in:)` + `submit(_:onValid:)` + demo page. 13b also needs one internal hook the sketch hand-waves: an editing-end callback on TextInput so `.field` can run `form.validate(field, text)` live — `onValidation` alone only reports the field's *own inline* rules, not the form's | **high → 13a medium + 13b medium** |
| 14 | **Collapse into unit 6.** Per-toast `position:` override and `onShow`/`onDismiss` lifecycle hooks *already shipped* (`Feedback.swift:90–96, 173–188`). What remains of unit 14 is exactly unit 6's fallback wiring. Delete the row | **low → 0 (merged)** |

Ordering dependencies confirmed sound otherwise: 9 (SlotContent) touches Card/Chip only mechanically and can land any time; 11 (dismissDrag) correctly waits for nothing but should land *before* any audit-side detached-sheet work; 12 (chrome family) depends on nothing new. One addition: unit 8's audit **script** should land before Sprint I-3's other units open PRs, so their new modifiers are linted from day one — keep 8 first in I-3 as sequenced.

### 4. Bottom line — go/no-go per theme

| Theme | Verdict | Condition |
|---|---|---|
| T1 Provider/defaults | 🟡 **yellow** | FieldDefaults: internal `explicitSize` detection (unit 5 row). FeedbackDefaults: the three mechanics from Q3 — host-body env reads, presenter cap → `var`, omitted-argument overload pair for `duration` (nil already means sticky) |
| T2 Slots | 🟢 **green** | Drop `@usableFromInline`; add the slot-type-stability (`.id`) rule to the authoring skill. No `sending` needed — proven by shipped slots |
| T3 Variant matrix | 🟢 **green** | Sweep is ~80% shipped; gate empirically tolerates deprecations (exit 0). Remaining: script + `Indicator`/`EmptyState` stragglers |
| T4 Controlled state | 🟢 **green** | Compile-proven with `@MainActor` accessors; Accordion refactor is API-byte-identical |
| T5 Chrome family | 🟢 **green** | `fieldChrome` must add `hasWarning` + `size` knobs and read `isEnabled` from env |
| T6 Tokens | 🟡 **yellow** | MANDATORY missing-token fallback (`.clear` scrim regression for consumer themes); fix `gen_tokens.py` stale paths; decide Tour 0.6 vs standard |
| T7 dismissDrag | 🟢 **green** | Internal-first extraction as planned; Dialog's tuned feel is the reference; snapshots guard |
| T8 Form wiring | 🟡 **yellow** | Split unit 13; `externalFocus` does not exist on 3 of 5 family members (13a prerequisite); keep `in:` (Q4 — no erasure); add the internal editing-end hook |

No red. The plan's architecture is sound and its rejected alternatives stay rejected; every yellow has a concrete, PR-sized fix specified above.
