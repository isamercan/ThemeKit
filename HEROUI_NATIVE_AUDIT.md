# HeroUI Native → ThemeKit Gap Analysis

This document records an audit of ThemeKit against the full **HeroUI Native** component set (38 components, React Native). Each HeroUI component was compared per-API against the HeroUI Native source/docs and judged **by role, not by name** — a ThemeKit component with a different name counts as coverage if it fills the same role. ThemeKit conventions (atom/molecule/organism tiers, chainable copy-on-write modifiers, theme tokens, MicroMotion gating) follow the `themekit-authoring` skill.

Outcome: **5 covered**, **27 partial** (gap plans below), **6 missing** — all 6 implemented on this branch (see "Newly built in this PR").

## Summary

File paths are relative to `Sources/ThemeKit/`.

| HeroUI component | ThemeKit counterpart | Status |
|---|---|---|
| Button | `Components/Molecules/Buttons/ThemeButton.swift`, `ButtonSize.swift`, `Buttons.swift` | Partial |
| CloseButton | `Components/Atoms/CloseButton.swift` | **Newly built** |
| LinkButton | `Components/Atoms/TextLink.swift`, `Components/Molecules/Buttons/Buttons.swift` | Covered |
| PressableFeedback | `Components/Molecules/Buttons/ThemeButton.swift`, `Theme/MicroMotion.swift` | Partial |
| Chip | `Components/Atoms/Tag.swift`, `Chip.swift`, `ChipStyle.swift`, `Badge.swift` | Partial |
| Menu | `Components/Molecules/Dropdown.swift`, `Components/Organisms/MenuCard.swift` | Partial |
| TagGroup | `Components/Atoms/Tag.swift`, `Chip.swift`, `Components/Molecules/Chips.swift`, `FilterGroup.swift` | Partial |
| Select | `Components/Molecules/Select.swift`, `SelectBox.swift`, `SelectStyle.swift`, `MultiSelect.swift` | Partial |
| RadioGroup | `Components/Molecules/RadioButton.swift`, `RadioGroup.swift` | Partial |
| Checkbox | `Components/Molecules/Checkbox.swift`, `CheckboxGroup.swift` | Covered |
| Switch | `Components/Molecules/ThemeToggle.swift`, `ToggleGroup.swift` | Partial |
| Slider | `Components/Molecules/Slider.swift`, `RangeSlider.swift` | Partial |
| ControlField | `Components/Molecules/ControlRow.swift` | **Newly built** |
| Label | `Components/Atoms/InputLabel.swift` | Partial |
| Description | `Components/Atoms/HelperText.swift` | **Newly built** |
| FieldError | `Validation/InfoMessage.swift`, `InfoMessageUI.swift`, `Components/Molecules/ValidationRule.swift` | Partial |
| Input | `Components/Molecules/TextInput.swift`, `FieldStyle.swift`, `TextInputFormatter.swift` | Partial |
| InputGroup | `Components/Molecules/TextInput.swift` | Covered |
| TextField | `Components/Molecules/TextInput.swift`, `Components/Atoms/InputLabel.swift`, `Validation/InfoMessageUI.swift` | Partial |
| TextArea | `Components/Molecules/MultiLineTextInput.swift`, `FieldStyle.swift` | Covered |
| SearchField | `Components/Molecules/SearchBar.swift` | Partial |
| InputOTP | `Components/Molecules/OTPInput.swift` | Partial |
| Tabs | `Components/Organisms/SegmentedTabBar.swift`, `Components/Molecules/SegmentedControl.swift` | Partial |
| Accordion | `Components/Organisms/Accordion.swift`, `AccordionGroup.swift` | Partial |
| BottomSheet | `Components/Organisms/BottomSheet.swift`, `SheetHeader.swift` | Partial |
| Dialog | `Components/Organisms/Dialog.swift`, `Feedback.swift` | Partial |
| Popover | `Components/Molecules/Tooltip.swift`, `Components/Organisms/Popconfirm.swift` | Partial |
| Toast | `Components/Organisms/Toast.swift`, `ToastStyle.swift`, `AlertToast.swift`, `Feedback.swift` | Partial |
| Alert | `Components/Organisms/InfoBanner.swift`, `Callout.swift`, `AlertToast.swift` | Partial |
| Skeleton | `Components/Atoms/Skeleton.swift` | Partial |
| SkeletonGroup | `Components/Atoms/SkeletonGroup.swift` | **Newly built** |
| Spinner | `Components/Atoms/Spinner.swift` | Partial |
| ScrollShadow | `Components/Molecules/ScrollShadow.swift` | **Newly built** |
| ListGroup | `Components/Organisms/ListView.swift`, `ListRow.swift`, `ListRowStyle.swift` | Partial |
| Card | `Components/Organisms/Card.swift`, `CardStyle.swift` | Partial |
| Surface | `Components/Atoms/SurfaceView.swift` | **Newly built** |
| Separator | `Components/Atoms/DividerView.swift` | Covered |
| Avatar | `Components/Atoms/Avatar.swift` | Partial |

Mapping notes on the "Covered" rows: HeroUI LinkButton = TextLink atom + `LinkButton` preset + `ThemeButton.variant(.link)`; InputGroup is native to TextInput (`.icon(leading:)`/`.trailing{}`/`.clearable()`/`.secure()`/`.addons(before:after:)`); TextArea = MultiLineTextInput; Separator = DividerView (adds dashed and titled variants); Checkbox exceeds HeroUI (indeterminate, box styles, group select-all).

## Gap plans

Each subsection is a follow-up-PR-sized checklist for a partially covered component, prioritized high → low.

### Button

ThemeButton covers HeroUI variants via variant × SemanticColor; loading/disabled/press feedback covered.

- [ ] **[medium]** Custom label slot (Button.Label / arbitrary children) — Add content-slot path in `ThemeButton.swift`: `init(action:@ViewBuilder label:)` storing AnyView replacing the built-in HStack, or a `.label{}`/`.leading{}`/`.trailing{}` slot trio mirroring Chip's AnyView slot pattern; slot content inherits size textStyle + variant token foreground.
- [ ] **[low]** Per-button press-feedback variant (scale-highlight/scale-ripple/scale/none) — Add chainable `pressFeedback(_ v: ButtonPressFeedback)` enum on ThemeButton routed through `copy(_:)`; ripple tint from the SemanticColor ladder; motion gated by microAnimations + Reduce Motion.

### PressableFeedback

Covered by PressFeedbackStyle/`.microPressScale` + RowPressStyle + the microAnimations gate; missing ripple and hygiene items.

- [ ] **[medium]** RowPressStyle takes a raw cornerRadius CGFloat — Add `init(radius: Theme.RadiusRole)` resolving `.value` internally; deprecate the raw-CGFloat init.
- [ ] **[low]** No ripple press feedback (PressableFeedback.Ripple) — Add `RipplePressStyle: ButtonStyle` next to PressFeedbackStyle/RowPressStyle; touch-point circle expansion, token tint (default bgElevatorTertiary or SemanticColor `.soft`), Motion token duration, gated by microAnimations + Reduce Motion.
- [ ] **[low]** No composed scale+highlight style with configurable tint — Expose `SurfacePressStyle(radius: Theme.RadiusRole, tint: SemanticColor?)` ButtonStyle, or add an optional tint to RowPressStyle.

### Chip

HeroUI Chip's role = ThemeKit Tag atom (color × variant axes); ThemeKit's Chip is the selectable filter-chip superset.

- [ ] **[low]** Tag has no size ramp (sm/md/lg) — Add `func size(_ s: ChipSize)` to `Tag.swift` as a copy-on-write extension driving textStyle + SpacingKey paddings; replace the fixed 28pt height with a padding-derived minHeight.
- [ ] **[low]** Tag lacks arbitrary leading/trailing content slots — Port Chip's slot pattern to `Tag.swift`: leading/trailing @ViewBuilder slots stored as AnyView.

### Menu

Dropdown is the role match (anchored floating action menu). Missing the selection half, richer item anatomy, SubMenu, bottom-sheet presentation, and controlled open state.

- [ ] **[high]** Selection groups with checkmark/dot indicators (Menu.Group + Menu.ItemIndicator) — In `Dropdown.swift` add DropdownSection (optional heading + items) and a selection-aware `DropdownItem(_:isSelected:)` or `Dropdown(sections:selection:)` init binding a Set/optional value; render the leading indicator via Icon checkmark / filled Circle tinted `theme.foreground(.fgHero)`; chainable `indicator(_ v: DropdownIndicator)` enum {checkmark, dot}; `.accessibilityAddTraits(.isSelected)` on selected rows; add a `shouldCloseOnSelect(_:)` modifier.
- [ ] **[medium]** Section headings (Menu.Label) — Render an optional section title as a non-interactive row: `Text(title).textStyle(.overline400)` in `theme.text(.textTertiary)`, padded SpacingKey.sm, `.isHeader` trait.
- [ ] **[medium]** Item description line (Menu.ItemDescription) — Add `subtitle: String?` to `DropdownItem.init`; render `.bodySm400` textSecondary under the title in a VStack.
- [ ] **[medium]** SubMenu (inline expandable nested items) — Add `DropdownItem.submenu(_ title:systemImage:items:)` rendered as a disclosure row with chevron rotation 0→90° via MicroMotion fast, nested rows indented SpacingKey.md; state-aware a11y label.
- [ ] **[medium]** Bottom-sheet presentation mode — Add chainable `presentation(_ p: DropdownPresentation)` enum {popover, sheet} routing rows into the BottomSheet organism.
- [ ] **[low]** Controlled open state (isOpen/onOpenChange) — Add init overload `Dropdown(items:isPresented: Binding<Bool>, trigger:)`.

### TagGroup

Covered by the family: ChipGroup (multiple), FilterGroup (single), CheckableTag, `Tag(onRemove:)`.

- [ ] **[high]** Per-option disabled (disabledKeys) — Add an `optionEnabled(_ predicate:)` chainable modifier to ChipGroup (`Chips.swift`) and FilterGroup (`FilterGroup.swift`), matching the RadioGroup/CheckboxGroup/Select convention.
- [ ] **[medium]** Selection + removal combined — Add `removable(_ onRemove: (Option) -> Void)` to ChipGroup appending a trailing xmark via Chip's `.trailing{}` slot, Icon `.xs`, textTertiary, a11y label "Remove <label>".
- [ ] **[medium]** Invalid/required state — Add `infoMessages(_:)` to ChipGroup and FilterGroup rendering InfoMessageList under the chips; error-tint the group title when the dominant kind is `.error`.
- [ ] **[low]** Empty state (renderEmptyState) — Add an `emptyContent(@ViewBuilder)` modifier to ChipGroup shown when `options.isEmpty`.

### Select

Strong coverage across Select/SelectBox/MultiSelect.

- [ ] **[medium]** Bottom-sheet / dialog presentation modes — Add `presentation(_ p: SelectPresentation)` enum {menu, panel, sheet} to `Select.swift`; `.sheet` presents the option list inside the BottomSheet organism.
- [ ] **[medium]** Option descriptions (Select.ItemDescription) — Add `optionDescription(_ text: (Option) -> String?)` to `Select.swift` and `MultiSelect.swift` rendering a `.bodySm400` textSecondary second line.
- [ ] **[low]** Custom option row content — Add an `optionLeading(@ViewBuilder (Option) -> V)` slot modifier rendered before the title in panel rows.
- [ ] **[low]** Controlled open state — Add an init overload with `isExpanded: Binding<Bool>` (panel mode only; document the Menu limitation).

### RadioGroup

Core covered; RadioButtonGroup adds a segmented form HeroUI lacks.

- [ ] **[high]** Per-option description (Label + Description anatomy) — Add `optionDescription(_ description: (Option) -> String?)` to `RadioGroup.swift` (identical to ToggleGroup's) rendering `.bodySm400` textSecondary under the row label, RadioButton top-aligned.
- [ ] **[medium]** Group-level accent/variant inheritance — Add `accent(_ color: SemanticColor?)` to RadioGroup forwarded to the inner RadioButtons.
- [ ] **[low]** Horizontal orientation — Add `axis(_ a: Axis)` to RadioGroup (default `.vertical`) switching the container to an HStack spaced SpacingKey.md.

### Switch

ThemeToggle IS the generic switch and covers the core API plus a `.loading()` extra.

- [ ] **[medium]** Track start/end content (Switch.StartContent/EndContent) — Add a `trackSymbols(on: String?, off: String?)` chainable modifier to `ThemeToggle.swift` rendering an SF Symbol via Icon inside a Capsule overlay opposite the thumb, sized off knobSize, textHero on active / textTertiary on inactive, MicroMotion animated. Distinct from `.symbols(on:off:)`, which targets the knob.
- [ ] **[low]** Custom thumb content slot — Add `thumbContent(@ViewBuilder (Bool) -> C)` storing an AnyView closure rendered inside the knob Circle in place of the symbol/spinner.
- [ ] **[low]** Press feedback (scale on press) — Replace `.buttonStyle(.plain)` with a private ButtonStyle applying scaleEffect 0.96 when pressed, under MicroMotion/reduceMotion gates.

### Slider

Slider + RangeSlider together cover the role; ThemeKit adds marks and linked inputs.

- [ ] **[medium]** Persistent formatted value output (Slider.Output + formatOptions) — Add `valueLabel(_ format: ((Double) -> String)?)` to `Slider.swift` (mirroring RangeSlider's); render a trailing label row `.labelBase600` textSecondary; reuse the closure for the drag tooltip and accessibilityValue.
- [ ] **[medium]** Tap-to-set on track — Attach `DragGesture(minimumDistance: 0)` to the full track ZStack via contentShape in `Slider.swift` and `RangeSlider.swift`, snapping to step; RangeSlider moves the nearest thumb.
- [ ] **[medium]** Semantic accent for fill/thumb — Add `accent(_ color: SemanticColor?)` to both files: fill `accent?.solid ?? bgHero`, thumb ring `accent?.solid ?? borderHero`.
- [ ] **[low]** Vertical orientation for RangeSlider — Add an `axis(_:height:)` modifier and vertical body to `RangeSlider.swift` reusing Slider's approach.
- [ ] **[low]** Thumb press feedback — Apply `scaleEffect(dragging ? 0.9 : 1)` to thumbs under microAnimations/reduceMotion gates.

### Label

InputLabel is the direct counterpart (`.required`, `.hasError`, `.hasInfo` extra).

- [ ] **[medium]** Disabled state styling — In `InputLabel.swift` add `@Environment(\.isEnabled)`; resolve text color: hasError → systemcolorsFgError, !isEnabled → textDisabled, else textPrimary; dim the asterisk and info glyph too. No new modifier — native `.disabled` is the API.

### FieldError

HeroUI FieldError maps to `InfoMessage(kind: .error)` + InfoMessageList wired via `.errorText`/`.infoMessages`/`.validate`.

- [ ] **[medium]** Animated appearance/disappearance of field messages — Add `.transition(.opacity.combined(with: .move(edge: .top)))` per message row in `InfoMessageUI.swift` and `.animation(Motion.fast.animation, value: messages)` at InfoMessageList call sites in `TextInput.swift` and `MultiLineTextInput.swift`; optional chainable `messagesAnimated(_:)` opt-out.
- [ ] **[low]** Custom (non-text) message content slot — Add a chainable `footer(@ViewBuilder)` on TextInput stored as AnyView like the leading/trailing slots, rendered in the message row area.

### Input

TextInput is a superset of HeroUI Input except the "secondary" on-surface variant and invalid-tinted caret.

- [ ] **[medium]** Secondary / on-surface field chrome (variant=secondary) — Add MutedFieldStyle in `FieldStyle.swift`: fill `theme.background(.bgSecondaryLight)`, no shadow, border transparent until focus/error, static accessor `.muted`.
- [ ] **[low]** Invalid-state caret/selection tint — In `TextInput.swift` change `.tint(theme.foreground(.fgHero))` to `hasError ? systemcolorsFgError : fgHero`; same for the MultiLineTextInput TextEditor.

### TextField

The TextField container role is covered by the monolithic TextInput anatomy; only isRequired is missing.

- [ ] **[high]** Required-field indicator on TextInput — Add `var isRequired` to TextInputModel + chainable `required(_:)` on TextInput; render an asterisk after the floating label in systemcolorsFgError as InputLabel does; append localized ", required" to the accessibilityLabel; mirror on MultiLineTextInput.

### SearchField

HeroUI SearchField maps to ThemeKit SearchBar (ThemeKit's SearchField is a search-form summary card — a different role).

- [ ] **[medium]** Invalid/error state (isInvalid + FieldError) — In `SearchBar.swift` add `errorText(_:)` and `infoMessages(_:)` copy-on-write modifiers; render InfoMessageList below the field; feed dominantKind into FieldStyleConfiguration.hasError/hasWarning.
- [ ] **[low]** Replaceable leading search icon — Add `leadingIcon(_ systemName:)` (default magnifyingglass) and `leadingIconColor(_ key: Theme.TextColorKey)`.
- [ ] **[low]** Inline helper/description line — Add a `helperText(_:)` modifier rendering `.bodySm400` textTertiary, suppressed while errorText is active (hideOnInvalid).

### InputOTP

Core covered, including extras (secure masking, resend countdown).

- [ ] **[medium]** Character pattern / input mode — Add `enum OTPCharacterSet {digits, letters, alphanumeric}` + a `characters(_:)` chainable modifier switching the sanitize filter and keyboard traits, keeping `.oneTimeCode`.
- [ ] **[medium]** Slot grouping with separator — Add `groups(_ sizes: [Int])` validated against digitCount, inserting a separator glyph (Rectangle or dash Text in textTertiary, SpacingKey.sm).
- [ ] **[low]** Per-slot placeholder characters — Add `placeholder(_ text: String)`; OTPDigitBox renders the per-slot char in textTertiary when empty and not the caret cell.
- [ ] **[low]** Digit entry micro-animation — Give the digit Text `.contentTransition(.numericText())` or an opacity+scale transition gated by microAnimations + reduceMotion.

### Tabs

SegmentedTabBar covers the strip role; missing the content-panel half and scroll-follow.

- [ ] **[medium]** Tab content panels (Tabs.Content) — Add a generic init overload `init(_ items:selection:@ViewBuilder content: (Int) -> Content)` rendering the selected pane below the bar with `.transition(.opacity)` + `.id(selection)`, MicroMotion/reduceMotion aware.
- [ ] **[medium]** Auto-scroll selected tab into view — Wrap the bar in ScrollViewReader, tag tabs, scroll on selection change; expose `enum TabScrollAlignment {start, center, end, none}` via `scrollAlign(_:)` (default `.center`).
- [ ] **[low]** Inter-tab separators — Add `dividers(_:)` (mirroring SegmentedControl's) drawing a 1pt hairline borderPrimary between tabs, hidden when the neighbor is the selection.

### Accordion

Split across Accordion (single row) + AccordionGroup (single/multiple modes, surface chrome).

- [ ] **[high]** Controlled expansion (value/onValueChange) — AccordionGroup: add an init overload with `expanded: Binding<Set<Item.ID>>`; Accordion: an init overload with `isExpanded: Binding<Bool>`; keep initiallyExpanded as the uncontrolled path.
- [ ] **[medium]** Custom trigger content and indicator in AccordionGroup — Add a generic init overload with `@ViewBuilder header: (Item, Bool) -> Header`; surface the AccordionIndicator enum via chainable `indicator(_:)`.
- [ ] **[medium]** Variant parity: plain group + hideSeparator — Add `surface(_ on: Bool = true)` and `dividers(_ on: Bool = true)` to AccordionGroup.
- [ ] **[low]** isCollapsible — Add `collapsible(_ on: Bool = true)`; when false, `toggle()` early-returns so one item stays open in single mode.
- [ ] **[low]** Per-item disabled — Add `itemDisabled(_ isDisabled: (Item) -> Bool)`; disabled rows get textDisabled + `.disabled(true)`.

### BottomSheet

Covered by `.bottomSheet` + SheetPresenter/`.sheetHost` on the native sheet; SheetHeader for Title/Close.

- [ ] **[medium]** Detached (inset floating card) presentation — Add `detached: Bool = false` to `.bottomSheet` and `SheetPresenter.present`: `.presentationBackground(.clear)` with content wrapped in a card padded SpacingKey.md, bgWhite continuous RoundedRectangle RadiusRole.box.
- [ ] **[low]** Sheet surface token override — Add `surface: Theme.BackgroundColorKey? = nil` mapping to `.presentationBackground(theme.background(key))`.
- [ ] **[low]** Corner radius role for the sheet — Add `radius: Theme.RadiusRole? = nil` mapped to `.presentationCornerRadius`.

### Dialog

Role fully covered by the three `.dialog` overloads + `FeedbackPresenter.confirm`.

- [ ] **[medium]** Swipe/drag-to-dismiss gesture on the dialog card — Add `swipeToDismiss: Bool` (default false) to all three `.dialog` overloads; a shared DragGesture offsets the card, fades the scrim proportionally, dismisses past ~1/3 card height, springs back otherwise — gated on microAnimations + reduceMotion (mirror `Feedback.swift` FeedbackToastRow swipe).
- [ ] **[low]** Scale + fade presentation transition — Change the card transition to `.opacity.combined(with: .scale(scale: 0.96))`; the scrim stays fade-only; MicroMotion gating keeps Reduce Motion a plain fade.

### Popover

Role split across Tooltip (bubble+arrow) and the Popconfirm custom-content overload (generic anchored card).

- [ ] **[high]** Outside-tap dismissal (overlay close-on-press) — Extend PopconfirmPresenter with `dismissOnOutsideTap: Bool = true` (exposed on `.popconfirm` overloads and self-managed `.tooltip`): a transparent full-screen tap-catcher behind the card flipping the binding.
- [ ] **[medium]** Stock titled popover layout (Title+Description+Close) — Add a `.popover(isPresented:title:message:edge:)` convenience beside `.popconfirm` composing a labelBase600 title, bodySm400 textSecondary message, and the existing xmark close onto PopconfirmSurface.
- [ ] **[medium]** Alignment along the placement axis (align start/center/end) — Add a PopoverAlign enum + `align:` parameter to `.tooltip`/`.popconfirm`/`.popover` via alignment guides; gap distance from SpacingKey.xs instead of a hardcoded 8pt.
- [ ] **[low]** Arrow on the popover card — Add `showsArrow: Bool = false` composing TooltipArrow filled bgWhite, stroked borderPrimary.
- [ ] **[low]** Width strategy for the card — Add PopoverWidth (`.contentFit` → `.fixedSize()`, `.matchTrigger`, `.fixed(CGFloat)` escape) threaded through PopconfirmSurface, defaulting to today's fixed 260pt.
- [ ] **[low]** Edge-collision avoidance — GeometryReader-based flip in PopconfirmPresenter swapping top↔bottom / leading↔trailing when the card exceeds the safe area; or document caller responsibility.

### Toast

Strong coverage: AlertToast view + `.toast` presenter + FeedbackPresenter/`.feedbackHost` imperative manager.

- [ ] **[low]** Neutral ("default") and accent toast variants — Add a `.neutral` case to AlertToastType (bgTertiary/fgSecondary/bell.fill) and an accent case fed by `SemanticColor.primary.solid`/`.onSolid`; extend the FeedbackKind mapping.
- [ ] **[low]** Per-toast placement override — Add `position: ToastPosition? = nil` to `FeedbackPresenter.toast` stored on ToastItem; render two anchored stacks in FeedbackHostModifier.
- [ ] **[low]** Show/hide lifecycle callbacks — Add onShow/onDismiss closures to `FeedbackPresenter.toast`, invoking onDismiss from the single removal point.
- [ ] **[low]** Stacked depth (peek/scale) animation — Switch toastLayer to a ZStack keyed by index with peek offset + 0.97 scale under `Motion.base.spring`, honoring Reduce Motion.

### Alert

HeroUI Alert maps to InfoBanner (variants, title/message, showsIcon, action, dismiss); Callout is the compact case.

- [ ] **[medium]** Custom leading indicator (icon override + view slot) — Add an `.icon(_ systemName: String?)` override + a `.leading(@ViewBuilder)` copy-on-write slot replacing the stock Icon (e.g. Spinner); apply `.icon(_:)` to `Callout.swift` too.
- [ ] **[medium]** Trailing accessory slot for real buttons — Add a `.trailing(@ViewBuilder)` modifier rendering after the text block (e.g. small ThemeButton); keep `.action` as the lightweight default.
- [ ] **[low]** Accent (brand) status variant — Add an `.accent` case to InfoBannerType and CalloutType fed by SemanticColor.primary (`.soft` surface, `.border` hairline, `.base` icon).
- [ ] **[low]** Alert semantics for assistive tech — Add `.accessibilityElement(children: .combine)` on the root HStack; localized accessibilityLabel on the stock status icon per variant.

### Skeleton

Skeleton atom + `.skeleton(isLoading)` modifier cover the role; shimmer is token-bound and static under Reduce Motion.

- [ ] **[medium]** Pulse animation variant — Add `public enum SkeletonVariant { shimmer, pulse, none }` + copy-on-write `variant(_:)` on Skeleton; thread through SkeletonShimmer; pulse animates fill opacity ~0.5…1.0 easeInOut repeatForever; accept the variant in the `.skeleton(_:)` modifier.
- [ ] **[medium]** Animated skeleton-to-content reveal — In SkeletonModifier add `.animation(.easeOut, value: isLoading)` and `.transition(.opacity)` on the overlay so the placeholder fades out (skip under reduceMotion).
- [ ] **[low]** Token-fed corner radius for skeleton shapes — Add `static func rounded(_ role: Theme.RadiusRole)` and a `.skeleton(_:radius:)` overload; deprecate the raw-CGFloat paths.
- [ ] **[low]** Configurable shimmer highlight — Add `highlight(_ color: SemanticColor?)` (nil = bgWhite default) resolving to `color?.soft` in the shimmer gradient.

### Spinner

Covers and exceeds the core role (5 shapes vs 1).

- [ ] **[medium]** Loading accessibility label — Add `.accessibilityLabel(String(localized: "Loading", bundle: .module))` + a Reduce Motion static 270-degree arc fallback.
- [ ] **[low]** Custom rotating indicator slot — Add an `indicator(@ViewBuilder)` AnyView slot; the body renders the slot inside the continuous-rotation driver (extract SpinnerRing rotation into a private RotationDriver).
- [ ] **[low]** Native controlSize support — Read `@Environment(\.controlSize)` deriving diameter/stroke presets (small 16/2, regular 24/3, large 40/4); keep `.size(points)` as the explicit override.

### ListGroup

Role fully present and richer than HeroUI; one meaningful gap.

- [ ] **[medium]** Surface variants on the list container — Add `public enum ListSurfaceVariant { primary, secondary, tertiary, transparent }` + a `surface(_:)` copy-on-write modifier to `ListView.swift` mapping theme.background tokens (`.bgWhite`/`.bgSecondaryLight`/`.bgElevatorTertiary`/`.clear`), stroke only for bordered primary; keep `.bordered(_:)` as an alias; move the container radius from RadiusKey.md to RadiusRole.box.

### Card

Card organism covers the role; exceeds with `.loading` skeleton, `.extraAction`, pressable init.

- [ ] **[high]** Footer slot for bottom-aligned actions — Add a `footer(@ViewBuilder)` copy-on-write slot storing `AnyView?`, rendered in cardContent below the body with `DividerView().size(.small)` above, using the existing contentPadding/SpacingKey.
- [ ] **[medium]** Custom header content slot — Add `header(@ViewBuilder)` storing a customHeader `AnyView?` replacing the string header when set.
- [ ] **[medium]** Surface-fill variants (default/secondary/tertiary/transparent) — Add `surface(_ key: Theme.BackgroundColorKey)` threading into `CardStyleConfiguration.surfaceKey` (already modeled, never set); default→`.bgWhite`, secondary→`.bgSecondaryLight`, tertiary→`.bgTertiary`; transparent = `.cardStyle(.outlined)`.

### Avatar

Core covered; adds shape, presence dots, and AvatarGroup beyond HeroUI.

- [ ] **[high]** Remote image with automatic fallback, load fade and delayed fallback — Add `case remote(URL?, fallback: AvatarContent = .icon("person.fill"))` to AvatarContent, rendered via RemoteImage/AsyncImage phases: Skeleton while loading, fade-in via a Motion token on success, fallback via the normal token path on failure with a brief built-in delay.
- [ ] **[medium]** Soft fill variant — Add `fill(_ v: FillVariant)` (`.solid`/`.soft`; default `.solid`): `.soft` resolves surfaceFill to `SemanticColor.soft` and contentColor to the `.base`/700-step; thread through AvatarGroup.
- [ ] **[low]** Default accessibility label — Add `.accessibilityElement(children: .ignore)` + a default accessibilityLabel `String(localized: "Avatar")` (initials text when `.initials`); callers override natively.

## Newly built in this PR

The 6 HeroUI components with no ThemeKit counterpart were implemented on this branch:

- **CloseButton** (Atom, `Sources/ThemeKit/Components/Atoms/CloseButton.swift`) — ports HeroUI CloseButton: a circular xmark dismiss button (previously hand-rolled 8+ times across sheets, dialogs and toasts) with token tint/glyph overrides, a plain overlay mode, controlSize-driven icon sizing, a ≥44pt hit target and a localized "Close" accessibility label.
- **HelperText** (Atom, `Sources/ThemeKit/Components/Atoms/HelperText.swift`) — ports HeroUI Description: a standalone field helper-text atom (`.bodySm400` textSecondary) with `.hasError` recoloring, `.hidesOnError` (hideOnInvalid) and disabled-state dimming via the native environment.
- **SurfaceView** (Atom, `Sources/ThemeKit/Components/Atoms/SurfaceView.swift`) — ports HeroUI Surface: a brand-neutral nestable themed container with `level` (primary/secondary/tertiary/transparent), `elevation`, token radius and contentPadding modifiers, plus a `surfaceChrome` View extension standing in for asChild.
- **SkeletonGroup** (Atom, `Sources/ThemeKit/Components/Atoms/SkeletonGroup.swift`) — ports HeroUI SkeletonGroup: coordinates child Skeletons through an environment-provided group state so a card of placeholders shares one loading flag and phase-locked shimmer, with `skeletonOnly` and cross-fade on reveal.
- **ControlRow** (Molecule, `Sources/ThemeKit/Components/Molecules/ControlRow.swift`) — ports HeroUI ControlField: fuses label + description + a boolean control (toggle/checkbox/radio, or a custom indicator slot) into one pressable row with required/error/errorText validation states and combined accessibility.
- **ScrollShadow** (Molecule, `Sources/ThemeKit/Components/Molecules/ScrollShadow.swift`) — ports HeroUI ScrollShadow: wraps a caller's scroll view with scroll-aware, token-fed edge fade scrims (auto/start/end/both/none visibility, RTL-safe leading/trailing alignment) using `onScrollGeometryChange` with an iOS 17 fallback.

## Method notes

HeroUI Native's React-isms were translated to ThemeKit idioms rather than ported literally: `className`/Tailwind variant strings became theme tokens and style types; render props and compound sub-components (`Component.Item`, `Component.Label`) became chainable copy-on-write modifiers and `@ViewBuilder` slots; raw animation configs became Motion/MicroMotion tokens gated by the microAnimations setting and Reduce Motion; `isDisabled` props map to native `.disabled`/`@Environment(\.isEnabled)`; and string props with fixed pixel values map to token keys (SpacingKey, RadiusRole, semantic color roles) instead of raw CGFloats.
