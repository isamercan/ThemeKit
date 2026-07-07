---
title: Atoms
description: Every ThemeKit atom, with a verified usage example for each.
---

The smallest building blocks — a single visual idea each, with no internal composition of other ThemeKit components.

44 atoms. Every example below feeds modifiers with semantic color
tokens (`SemanticColor` cases, `theme.foreground(_:)`…) — never a raw `Color` or `CGFloat`
literal. See the [DocC reference](/ThemeKit/api/documentation/themekit/) for the full API.

### AnimatedImage {#animatedimage}

GIF/APNG animated image via ImageIO — no third-party dependency.

```swift
AnimatedImage(gifURL).contentMode(.fit).cornerRadius(16)   // GIF/APNG via ImageIO — no dependency
```

### Aura {#aura}

A breathing glow halo behind a view, or standalone.

```swift
card.aura(.primary)   // breathing glow halo · Aura().color(.purple).size(120).intensity(0.7)
```

### Avatar / AvatarGroup {#avatar}

Circular or square user avatar — initials, image, or icon, with a presence dot. `AvatarGroup` stacks a set of avatars with overflow.

```swift
Avatar(.initials("AB")).size(.md).presence(.online)
```

### Badge {#badge}

Small status/label pill with an icon and a semantic style.

```swift
Badge("Label").badgeStyle(.info).icon("star.fill")
```

### Barcode {#barcode}

Code 128 barcode generated on-device, with an optional caption.

```swift
Barcode("9824097217421298").height(56).showsValue()   // Code 128, no dep
```

### BorderBeam {#borderbeam}

An animated light beam that travels around a view's border.

```swift
card.borderBeam(cornerRadius: 16, lineWidth: 2)
```

### Chip {#chip}

Selectable filter/tag pill with a tonal or solid style.

```swift
Chip("Recommended", isSelected: $selected).chipStyle(.tonal)
```

### CodeBlock {#codeblock}

Terminal-style code mockup with per-line semantic highlights.

```swift
CodeBlock([CodeLine("npm i themekit", prefix: "$"), CodeLine("Done!", prefix: ">", highlight: .success)]).copyable()
```

### Confetti {#confetti}

A one-shot celebratory confetti burst, triggerable from any view.

```swift
Confetti().pieceCount(60)   // or: view.confetti(trigger: submissions)
```

### CountBadge & Ribbon {#countbadge}

`.countBadge(_:)` / `.dotBadge()` overlay a numeric or dot badge on any view; `Ribbon` wraps a corner banner around a card.

```swift
icon.countBadge(5)   //  .dotBadge() · Ribbon("New") { card }
```

### CountdownTimer {#countdowntimer}

Live HH:MM:SS countdown with an urgency escalation past a threshold.

```swift
CountdownTimer(until: deadline).style(.urgent).format(.boxed).size(.large).showsDays(false)
```

### DividerView {#divider}

A horizontal or vertical rule with an optional inline title.

```swift
DividerView("OR").dashed().titleAlign(.center)
```

### FareFeatureRow {#farefeaturerow}

Included/excluded fare feature row with an icon and a status.

```swift
FareFeatureRow("Checked bag", systemImage: "suitcase.fill", detail: "1 × 20 kg", status: .included)   // .included/.excluded/.info
```

### FlightStatusBadge {#flightstatusbadge}

Flight status pill — on-time, boarding, delayed, cancelled…

```swift
FlightStatusBadge(.delayed).time("+35m").solid()   // on-time/boarding/delayed/cancelled…
```

### GaugeView {#gauge}

Circular or linear gauge for a bounded value, with a label.

```swift
GaugeView(value: 0.72, label: "CPU").gaugeStyle(.circular).showsValue()
```

### Icon {#icon}

SF Symbol wrapper with a token-bound size and color.

```swift
Icon(systemName: "star.fill").size(.md).color(theme.foreground(.fgHero))
```

### IconTile {#icontile}

Rounded, accent-tinted icon tile used as a shared leading glyph.

```swift
IconTile("suitcase.fill").accent(.turquoise).size(46)   // shared leading tile
```

### Indicator {#indicator}

Small dot or custom badge overlay modifier for any view.

```swift
icon.indicatorDot()   // or .indicator { Badge("3") }
```

### InlineText {#inlinetext}

Paragraph text with tappable inline links.

```swift
InlineText("Accept the Terms.", links: [("Terms", { })]).inlineStyle(.bodyBase400).color(tint)
```

### InputLabel {#inputlabel}

Form field label with a required asterisk and an info glyph.

```swift
InputLabel("Email").required().hasInfo()
```

### Join {#join}

Groups a row of views into one connected cluster with rounded outer corners.

```swift
Join(.horizontal) { ButtonA; ButtonB; ButtonC }   // connected group, rounded outer corners
```

### Kbd {#kbd}

A keyboard-key glyph, for shortcuts and hints.

```swift
Kbd("⌘").size(.lg)  Kbd("K").size(.lg)   // xs/sm/md/lg
```

### Mask {#mask}

Clips a view to a circle, squircle, hexagon, or star.

```swift
image.themeMask(.squircle)   // .circle / .squircle / .hexagon / .star
```

### PointsBadge {#pointsbadge}

Loyalty points/miles pill for earn, redeem, and balance states.

```swift
PointsBadge(1_250).unit("mil").style(.earn).size(.large).showsSign(true)   // .earn · .redeem · .balance
```

### PriceTag {#pricetag}

Currency price display with a struck-through original price and an auto discount badge.

```swift
PriceTag(1_299).original(1_899).unit("/ night").size(.large).emphasis(.hero).discountBadge()   // .free() · .soldOut() · .from() · .fractionDigits(2)
```

### ProgressBar {#progressbar}

Linear progress bar with a percentage readout and step markers; `StepIndicator` renders discrete step dots.

```swift
ProgressBar(value: 0.4).showsPercentage()
```

### QRCode {#qrcode}

Scannable QR code generated on-device via CoreImage.

```swift
QRCode("https://themekit.dev/pass/BID12025").size(160)   // CoreImage, no dep
```

### RadialProgress {#radialprogress}

Circular ring progress indicator with an optional dashboard style.

```swift
RadialProgress(0.6).size(96).accent(.purple).showsLabel()
```

### Rating {#rating}

Star rating control with half-star and tap-to-rate support.

```swift
Rating(value: 4.5).allowHalf().onRate { value = $0 }
```

### RemoteImage {#remoteimage}

Async-loaded image with aspect ratio, corner radius, and circle clipping.

```swift
RemoteImage(url, ratio: "16:9").cornerRadius(12)   // .gif/.apng animate natively
```

### RollingNumber {#rollingnumber}

Odometer-style rolling-digit animation for numeric values.

```swift
RollingNumber(1284).size(40)   // odometer digit roll
```

### ScoreBadge {#scorebadge}

Compact numeric score badge (e.g. a review score).

```swift
ScoreBadge(9.0, large: false)
```

### SearchBadge {#searchbadge}

Small pill for search-context chips (dates, guests, filters).

```swift
SearchBadge("SAW")   // soft-blue pill; .colors(background:foreground:) · .icon("bolt.fill")
```

### ShareButton {#sharebutton}

Wraps the native SwiftUI `ShareLink` in ThemeKit styling.

```swift
ShareButton(item: url)   // wraps SwiftUI ShareLink
```

### Skeleton {#skeleton}

Redacted-placeholder loading shimmer for any content.

```swift
Text("Loading…").skeleton(isLoading)
```

### Spinner {#spinner}

Loading spinner with ring, dots, bars, ball, or infinity styles.

```swift
Spinner().style(.dots).accent(.success).size(24)   // ring/dots/bars/ball/infinity
```

### StatusDot {#status}

Status dot with a label and an optional pulse animation.

```swift
StatusDot(.online, label: "Online").pulse()
```

### Swap {#swap}

Two-state icon toggle that crossfades between two symbols.

```swift
Swap(isOn: $on).symbols(on: "xmark", off: "line.3.horizontal")
```

### SwapButton {#swapbutton}

Circular action button for flipping two bound values (e.g. origin/destination).

```swift
SwapButton { swap(&from, &to) }.size(34)   // action flip; see Swap for the on/off toggle
```

### Tag {#tag}

Removable label pill with a semantic color and a solid/soft variant.

```swift
Tag("Sold out", onRemove: { }).tagStyle(.error).variant(.solid)
```

### TextLink {#textlink}

A tappable inline link with underline and accent color.

```swift
TextLink("Forgot password?") { }.accent(.primary)   // .underline(false) to remove
```

### TextRotate {#textrotate}

Rotates through a list of strings on a timer.

```swift
TextRotate(["faster.", "themed.", "accessible."], interval: 2)
```

### TiltCard {#tiltcard}

Touch/hover 3D tilt effect with spring-back and an optional specular shine.

```swift
card.tilt3D(shine: true)   // drag to tilt · TiltCard { … }.maxAngle(.degrees(12))
```

### Title {#title}

Section title with a subtitle and a trailing action.

```swift
Title("Section").subtitle("Sub").action("See all", action: { })
```
