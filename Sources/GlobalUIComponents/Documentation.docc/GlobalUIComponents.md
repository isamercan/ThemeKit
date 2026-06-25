# ``GlobalUIComponents``

@Metadata {
    @DisplayName("GlobalUIComponents")
    @PageColor(blue)
}

A token-driven, brand-neutral SwiftUI design system: a themable palette, a full
component library, validation, and accessibility — with zero third-party
dependencies.

## Overview

`GlobalUIComponents` is built in layers, bottom to top:

- **Tokens** — every color, radius, spacing step, type ramp entry, and shadow is
  a semantic token resolved from the active ``Theme``. Components never hard-code
  a value; they ask the theme. Swap the theme and the whole UI re-skins.
- **Components** — ~130 SwiftUI views grouped as Atoms (``Badge``, ``Chip``,
  ``Avatar``…), Molecules (``TextInput``, ``GlobalButton``, ``OTPInput``…), and
  Organisms (``Carousel``, ``DataTable``, ``ResultView``…). All token-bound.
- **Theming** — recipes (``ThemeConfig``) generate a complete palette from a
  single accent color at runtime, and persist/export it. See <doc:Theming>.
- **Validation** — a pure logic layer (``Validators`` / ``ValidationRule`` /
  ``Validator``) with a separate SwiftUI presentation layer. See <doc:FormValidation>.
- **Accessibility** — Dynamic Type and Reduce Motion are honored throughout.
  See <doc:Accessibility>.

```swift
import GlobalUIComponents

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome").textStyle(.headingLg)
            PrimaryButton("Get started") { await signIn() }
        }
        .padding()
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView().globalUITheme() }
    }
}
```

The optional **`GlobalUIComponentsLottie`** product adds Lottie-backed animation
views; the core library stays dependency-free.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Installation>
- <doc:Theming>
- <doc:Accessibility>
- <doc:FormValidation>

### Theme & Tokens

- ``Theme``
- ``ThemeConfig``
- ``ThemeContext``
- ``TextStyle``
- ``SemanticColor``
- ``Theme/SpacingKey``
- ``Theme/RadiusKey``
- ``ShadowStyle``
- ``Motion``

### Buttons

- ``GlobalButton``
- ``PrimaryButton``
- ``SecondaryButton``
- ``OutlineButton``
- ``GhostButton``
- ``LinkButton``
- ``ButtonGroup``
- ``FloatingActionButton``

### Inputs & Forms

- ``TextInput``
- ``MultiLineTextInput``
- ``OTPInput``
- ``Select``
- ``SelectBox``
- ``MultiSelect``
- ``Autocomplete``
- ``Checkbox``
- ``CheckboxGroup``
- ``RadioButton``
- ``RadioGroup``
- ``Slider``
- ``RangeSlider``
- ``QuantityStepper``
- ``SearchBar``
- ``DateField``
- ``FileInput``
- ``Upload``
- ``FormValidator``

### Validation

- ``Validators``
- ``ValidationRule``
- ``AsyncValidationRule``
- ``Validator``
- ``InfoMessage``
- ``InfoMessageList``

### Display & Feedback

- ``Badge``
- ``Chip``
- ``Avatar``
- ``AvatarGroup``
- ``Rating``
- ``RatingSummary``
- ``StatusDot``
- ``Skeleton``
- ``Spinner``
- ``ProgressBar``
- ``RadialProgress``
- ``AlertToast``
- ``Callout``
- ``InfoBanner``
- ``EmptyState``
- ``ResultView``
- ``RollingNumber``

### Containers & Navigation

- ``Card``
- ``Accordion``
- ``AccordionGroup``
- ``Carousel``
- ``PagingCarousel``
- ``Steps``
- ``Timeline``
- ``NavigationBar``
- ``SegmentedControl``
- ``SegmentedTabBar``
- ``Pagination``
- ``TreeSelect``
- ``DataTable``

### Media & Decoration

- ``AnimatedImage``
- ``RemoteImage``
- ``VideoPlayerView``

### Analytics

- ``ImpressionInfo``
