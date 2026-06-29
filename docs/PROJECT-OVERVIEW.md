# ThemeKit — Project Overview

> **In one sentence:** An enterprise-grade SwiftUI component library, fed by Figma design tokens,
> able to take on any brand or theme without changing a single line of code, with zero third-party
> dependencies.

---

## 1. Why does it exist? (The problem it solves)

Every team rewrites its own button, input, and card. The result: inconsistent UI, copy-paste
debt, weeks of manual fixes on every rebrand, and repeated accessibility/localization work in every project.

**ThemeKit reduces all of this to a single token-based source:**
- A designer changes a color in Figma → the JSON token updates → the entire app turns over automatically.
- A new project starts → it `import`s the library → from day one it has 117 ready-made, consistent components.
- A brand/theme change becomes a matter of **configuration**, not code.

---

## 2. At a glance (the numbers)

| | |
|---|---|
| **Production-ready components** | 117 components · 280 public types |
| **Architecture** | Atomic Design — Atoms · Molecules · Organisms |
| **Codebase** | ~20,000 lines of Swift · 154 files |
| **Third-party dependencies (core)** | **0** (native SwiftUI only) |
| **Themes** | 32 theme presets + 3 bundled themes (default/ocean/sunset × light/dark) |
| **Color tokens** | 217 design tokens + 50–900 color ramps |
| **Accessibility** | Dynamic Type + Reduce Motion + accessibility identifiers |
| **Localization** | String Catalog — English by default + Turkish |
| **Tests** | 180+ tests · 44 test files |
| **Documentation** | DocC catalog + 9 design/analysis documents |
| **Platform** | iOS 17+ · macOS 14+ · Swift 6.2 |

---

## 3. Why is it impressive? (Differentiators)

**🎨 Token-first architecture (ADR-0001)**
No component hard-codes its color, spacing, or radius — everything is resolved from the active `Theme`.
Tokens are generated from Figma and loaded as JSON at runtime. This is the very thing that moves a
"design system" from a slide deck into code.

**🔄 Live theme switching at runtime**
`Theme.shared.loadTheme(named: "oceanTheme")` — a single line, and the app turns over without recompiling.
What's more: there is a **live theme configurator**; given any accent color, it instantly regenerates the
entire 50–900 palette (a Swift port of the logic in the Python `gen_tokens.py`).

**📦 Zero dependencies + optional add-on**
The core library is entirely native. Anyone who wants Lottie animation gets it from a separate add-on target;
anyone who doesn't never even downloads it. A deliberate decision to keep the dependency chain clean.

**♿ Enterprise hygiene built-in**
Accessibility (Dynamic Type scaling, Reduce Motion gates, accessibility identifiers),
localization (String Catalog), and form validation (`FormValidator`) are baked into the core —
not work that has to be solved over again in every project.

**🏷️ Brand-agnostic**
By design, it contains no brand name; it can be applied generically to any product or brand.

---

## 4. Architecture (how it's put together)

```
Figma design system
        │  (tokens)
        ▼
Resources/*.json  ──►  Theme (ObservableObject)  ──►  Components
  color · radius         @ThemeContext               Atoms → Molecules → Organisms
  spacing                runtime loading             (resolve color/spacing from Theme)
```

- **Atoms** (26 files): Icon, Badge, Chip, Avatar, Divider, Kbd…
- **Molecules** (38 files): Buttons, Checkbox, TextInput, Select, OTPInput, ListRow…
- **Organisms** (44 files): Card, Carousel, DataTable, CalendarView, NavigationBar, Hero, Pagination…

Token groups: Color/Radius/Spacing → JSON (varies by theme) · Typography/Shadows → code (structural, fixed).

---

## 5. Proof: a working Demo app

A complete SwiftUI demo app is available that links the library as a local SPM reference:

- **Gallery / Catalog** — registry-based; every component is previewed live with adjustable "knobs".
- **Real-flow example** — an end-to-end **hotel booking flow** (Search → Results → Detail →
  Checkout → Favorites) built entirely from these components. Not a "toy demo," but a real product scenario.
- **Theme gallery + live configurator** — switching between themes and generating custom accents is seen instantly.

> The fastest impact on a lead: open the demo, change the theme live, and show the same hotel flow
> instantly taking on a different brand.

---

## 6. Engineering rigor

- Compatible with **Swift 6 strict concurrency** (Sendable cleanup done).
- **Design discipline:** Ant Design's 10 principles translated into concrete rules, and the library audited
  against them (`docs/design-principles.md`); gap analyses performed against Ant and daisyUI.
- **DocC** documentation catalog (Theming / Accessibility / FormValidation articles).
- **Tests:** theme integrity, token-generator robustness, validator edge cases, and render smoke tests.

---

## 7. Business value (what the lead wants to hear)

| Impact | Result |
|---|---|
| **Speed** | New screen/project in hours, not days — the components are ready. |
| **Consistency** | A single token source → pixel consistency across the brand. |
| **Brand agility** | Rebranding is a config job, not a code job (hours, not weeks). |
| **Maintenance cost** | Accessibility/localization/validation solved once, not again in every project. |
| **Risk** | Zero third-party dependencies (core) → less security/version risk. |

---

## 8. What's next? (roadmap)

- Spreading press/active feedback across all tappable surfaces (ListRow, Chip, Card).
- Auditing `Motion` token consistency in navigation/accordion transitions.
- Optional enrichments for Select such as loading/grouped/custom-option.
- Broader test coverage and snapshot tests.

---

## 9. 60-second pitch (for the lead conversation)

> "Every team was rewriting the same button, input, and card. We reduced that to a single SwiftUI library
> fed by Figma tokens. There are over 65 production-ready components, all token-based — meaning we can switch
> the entire app to a different theme with a single line, without touching the component code. Zero third-party
> dependencies in the core, with accessibility and localization built in. We have a working demo: we built a
> real hotel booking flow with these components, and I can change the theme live and show the same flow
> instantly taking on a different brand. The result: spinning up a new project drops to hours, a brand change
> becomes a config job, and maintenance debt goes down."

---

*Source: `ThemeKit` SPM package · `Demo/` SwiftUI app · `docs/` design & analysis documents.*
