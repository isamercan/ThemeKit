# Design principles

Ant Design's ten principles, translated into concrete rules for ThemeKit and
audited against the current library. Use this as the contributor checklist when adding or
reviewing a component.

## The ten principles → how we encode them

| # | Principle | In our system |
|---|---|---|
| 1 | **Proximity** — related things group together | Single 8-pt spacing scale (`SpacingKey` xs 4 … 4xl 64). Group with `sp-sm/md`, separate sections with `sp-lg/base`. Never ad-hoc paddings. |
| 2 | **Alignment** | Shared scale + `Grid`/`VStack(alignment:)`; text uses one leading edge. Icons sized via `IconSize`, not magic numbers. |
| 3 | **Contrast** | `TextStyle` ramp (Display→Overline) for hierarchy; color contrast from the token system (text-primary/secondary/tertiary), now WCAG-checked in dark too. |
| 4 | **Repetition** | One token source (`Theme`) drives every component; `RadiusKey`/`SpacingKey`/`TextStyle` reused everywhere — no per-component constants (ADR-0001). |
| 5 | **Directness** — act where you are | Inline editing (`QuantityStepper`, `Slider`, `Chip`), inline field `errorText`, swipe/tap on the element itself rather than a separate panel. |
| 6 | **Stay on the page** — don't jump away | `Skeleton`, `Spinner`, `ProgressBar`, `RadialProgress` keep layout stable while loading; `BottomSheet`/`Drawer`/`Tooltip`/`feedback.toast` keep context instead of full-screen navigation. |
| 7 | **Lightweight** — progressive disclosure | `Accordion`, `Tooltip`, `Drawer`, `Popover`-style surfaces reveal detail on demand; defaults are minimal. |
| 8 | **Invitation** — hint what's possible | `EmptyState` / `ResultView` with a clear CTA, `Tooltip`, placeholder text, `Badge`/`Indicator` cues. |
| 9 | **Transition** | `Motion` tokens (instant/fast/base/slow) standardize animation; toasts slide+fade, dialogs fade, theme/dark switches animate. |
| 10 | **React immediately** | `PressFeedbackStyle` + `FillButtonStyle` give every button a press/active state (Ant's hover/active analog); toggles/steppers reflect state instantly. |

## Audit (current state)

| Principle | Status | Notes / next |
|---|---|---|
| Repetition / tokens | ✅ Strong | 128 semantic tokens + 50–900 ladders; zero hardcoded colors in components. |
| Contrast (incl. dark) | ✅ Good | Real dark theme derived from the ladders; soft accent surfaces + text verified readable on sim. |
| Stay on the page | ✅ Good | Skeleton/Spinner/Progress + toast/sheet/drawer cover loading and feedback without leaving context. |
| React immediately | ⚠️ Buttons done | Press feedback covers `ThemeButton` + preset buttons. **Next:** extend a press style to other tappable surfaces (`ListRow`, `Chip`, `Card`-as-button, `MenuCard`) so taps feel equally responsive. |
| Transition | ⚠️ Partial | `Motion` exists and is used by toggles/toasts/dialogs. **Next:** audit list/detail navigation pushes and accordion expand for consistent `Motion.base`. |
| Invitation | ✅ Good | EmptyState + new ResultView templates give every dead-end a CTA. |
| Directness | ✅ Good | Inline steppers/sliders/chips; field-level errors. |
| Proximity / Alignment | ✅ Good | Single spacing scale; no ad-hoc paddings found in spot checks. |
| Lightweight | ✅ Good | Accordion/Drawer/Tooltip provide progressive disclosure. |

## Checklist for a new component

- [ ] Colors/spacing/radius/type come **only** from `Theme` tokens (Repetition).
- [ ] Tappable? It has a press/active state (React immediately).
- [ ] Animates with a `Motion` token, not an ad-hoc duration (Transition).
- [ ] Loading/empty/error states use `Skeleton` / `EmptyState` / `ResultView` (Stay on page, Invitation).
- [ ] Readable in **both** light and dark (Contrast) — check on device.
- [ ] Errors shown inline at the field, not as a toast (Directness; see feedback-patterns.md).
