# ThemeKit component patterns — copy-pasteable templates

Three reference skeletons, distilled from real library code (`Badge.swift`,
`FlightRoute`, `FlightListItemStyle.swift`). Copy the one that matches the component
you're building, rename, and fill in. Every template already obeys the 6 house rules
in `SKILL.md`: stateless, token-fed, init=content / modifiers=appearance, native
size/disabled, a11y + RTL + localization ready.

---

## §1. Atom — copy-on-write modifiers

The canonical configurable leaf. Content + optional action in `init`; every knob is a
chainable modifier routed through one `copy(_:)` point. Styling is driven by a
**semantic enum** that maps to tokens, never by raw colors passed in.

```swift
import SwiftUI

/// Semantic style → tokens. Add variants here, not color params on the component.
public enum TagStyle: String, CaseIterable {
    case neutral, info, success, warning, error

    func background(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgSecondaryLight)
        case .info:    return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error:   return theme.background(.systemcolorsBgErrorLight)
        }
    }
    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.text(.textSecondary)
        case .info:    return theme.foreground(.systemcolorsFgInfo)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        case .error:   return theme.foreground(.systemcolorsFgError)
        }
    }
}

public enum TagSize {
    case small, medium, large
    var height: CGFloat { self == .small ? 20 : self == .medium ? 24 : 32 }
    var textStyle: TextStyle { self == .large ? .labelBase600 : .labelSm600 }
    var hPadding: CGFloat { self == .large ? Theme.SpacingKey.md.value : Theme.SpacingKey.sm.value }
}

public struct Tag: View {
    @Environment(\.theme) private var theme

    private let text: String
    private let action: (() -> Void)?
    // Appearance — mutated ONLY through the modifiers below.
    private var style: TagStyle = .neutral
    private var size: TagSize = .medium
    private var leadingSystemImage: String?

    public init(_ text: String, action: (() -> Void)? = nil) {   // content + action only
        self.text = text
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage).font(.system(size: size.height * 0.5))
            }
            Text(text).textStyle(size.textStyle)
        }
        .foregroundStyle(style.foreground(theme))
        .padding(.horizontal, size.hPadding)
        .frame(height: size.height)
        .background(style.background(theme),
                    in: Capsule(style: .continuous))
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)
public extension Tag {
    func tagStyle(_ s: TagStyle) -> Self { copy { $0.style = s } }
    func size(_ s: TagSize) -> Self { copy { $0.size = s } }
    func icon(_ systemName: String?) -> Self { copy { $0.leadingSystemImage = systemName } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self; mutate(&c); return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(TagStyle.allCases, id: \.self) { s in
            Tag(s.rawValue.capitalized).tagStyle(s).icon("star.fill")
        }
        HStack {
            Tag("Small").tagStyle(.info).size(.small)
            Tag("Large").tagStyle(.success).size(.large)
        }
    }
    .padding()
    .environment(Theme.shared)
}
```

**Deprecating a raw escape hatch** (keep the API but steer callers to tokens):
```swift
@available(*, deprecated, message: "Use tagStyle(_:) with a semantic TagStyle instead of a raw color.")
func tagColor(_ color: Color?) -> Self { copy { $0.textColor = color } }
```

---

## §2. Molecule — a couple of atoms + light logic

Composes atoms, adds only presentational logic (formatting, layout). Still stateless
and token-fed. Note the RTL-safe stack layout and locale-driven formatting.

```swift
import SwiftUI

/// From/to time + code endpoints with a route track between them.
public struct RouteRow: View {
    @Environment(\.theme) private var theme

    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    private var stops: Int = 0
    private var locale: Locale = .current   // override via .locale(_:) for RTL/i18n demos

    public init(origin: String, destination: String, departure: Date, arrival: Date) {
        self.origin = origin; self.destination = destination
        self.departure = departure; self.arrival = arrival
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            endpoint(time(departure), origin, .leading)
            track
            endpoint(time(arrival), destination, .trailing)
        }
    }

    private var track: some View {
        VStack(spacing: 3) {
            Text(duration).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            HStack(spacing: 0) {
                Circle().stroke(theme.border(.borderPrimary), lineWidth: 1.5).frame(width: 7, height: 7)
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1.5)
                Icon(systemName: "airplane").size(.xs).accent(.primary)
            }
            Text(stopsText)
                .textStyle(.overline400)
                .foregroundStyle(stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private func endpoint(_ t: String, _ code: String, _ a: HorizontalAlignment) -> some View {
        VStack(alignment: a, spacing: 2) {
            Text(t).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            Text(code).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
        }
    }

    private func time(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
    private var duration: String {
        let m = max(0, Int(arrival.timeIntervalSince(departure) / 60))
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
    private var stopsText: String {
        switch stops {
        case 0: return String(localized: "Nonstop", bundle: .module)
        case 1: return String(localized: "1 stop", bundle: .module)
        default: return String(localized: "\(stops) stops", bundle: .module)
        }
    }
}

public extension RouteRow {
    func stops(_ n: Int) -> Self { copy { $0.stops = n } }
    func locale(_ l: Locale) -> Self { copy { $0.locale = l } }
    private func copy(_ m: (inout Self) -> Void) -> Self { var c = self; m(&c); return c }
}
```

---

## §3. Style-driven organism — protocol + configuration + type erasure

For a component that needs several fundamentally different layouts. The `Configuration`
carries **typed data** (not pre-laid content), so each style owns its whole layout.
This is the `FlightListItem` architecture, generalized.

```swift
import SwiftUI

// 1) Typed inputs every style lays out. Include the captured locale + shared helpers.
public struct MediaCardConfiguration {
    public let title: String
    public let subtitle: String?
    public let imageSystemName: String
    public let badge: String?
    public let isSelected: Bool
    public let onSelect: (() -> Void)?
    public let surfaceKey: Theme.BackgroundColorKey?
    public let locale: Locale

    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }
}

// 2) The style protocol.
public protocol MediaCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: MediaCardConfiguration) -> Body
}

// 3) Shared card shell (private) — every carded style reuses it.
private extension View {
    func cardShell(_ c: MediaCardConfiguration, theme: Theme) -> some View {
        background(theme.background(c.surface(default: .bgBase)),
                   in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                .strokeBorder(c.isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
                              lineWidth: c.isSelected ? 1.5 : 1)
        )
    }
}

// 4) One archetype = thin struct over a private Chrome view.
public struct CompactMediaCardStyle: MediaCardStyle {
    public init() {}
    public func makeBody(configuration c: MediaCardConfiguration) -> some View {
        CompactChrome(configuration: c)
    }
}
private struct CompactChrome: View {
    @Environment(\.theme) private var theme
    let configuration: MediaCardConfiguration
    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: configuration.imageSystemName).size(.md).accent(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.title).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                if let s = configuration.subtitle {
                    Text(s).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            if let badge = configuration.badge { Badge(badge).badgeStyle(.info).size(.small) }
        }
        .padding(Theme.SpacingKey.md.value)
        .cardShell(configuration, theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }
}
// …add HeroMediaCardStyle, TileMediaCardStyle the same way.

// 5) Static accessors → callers write `.mediaCardStyle(.compact)`.
public extension MediaCardStyle where Self == CompactMediaCardStyle {
    static var compact: CompactMediaCardStyle { CompactMediaCardStyle() }
}

// 6) Type erasure + environment plumbing.
struct AnyMediaCardStyle: MediaCardStyle {
    private let _makeBody: @MainActor (MediaCardConfiguration) -> AnyView
    init<S: MediaCardStyle>(_ style: sending S) { _makeBody = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: MediaCardConfiguration) -> AnyView { _makeBody(configuration) }
}
private struct MediaCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyMediaCardStyle(CompactMediaCardStyle())
}
extension EnvironmentValues {
    var mediaCardStyle: AnyMediaCardStyle {
        get { self[MediaCardStyleKey.self] } set { self[MediaCardStyleKey.self] = newValue }
    }
}
public extension View {
    /// Set the style for MediaCards in this subtree; a list can mix archetypes per section.
    func mediaCardStyle<S: MediaCardStyle>(_ style: sending S) -> some View {
        environment(\.mediaCardStyle, AnyMediaCardStyle(style))
    }
}

// 7) The public component reads the style from the environment and builds the config.
public struct MediaCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.mediaCardStyle) private var style
    @Environment(\.locale) private var locale

    private let title: String
    private var subtitle: String?
    private var imageSystemName: String = "photo"
    private var badge: String?
    private var isSelected: Bool = false
    private var surfaceKey: Theme.BackgroundColorKey?
    private var onSelect: (() -> Void)?

    public init(_ title: String) { self.title = title }

    public var body: some View {
        style.makeBody(configuration: .init(
            title: title, subtitle: subtitle, imageSystemName: imageSystemName,
            badge: badge, isSelected: isSelected, onSelect: onSelect,
            surfaceKey: surfaceKey, locale: locale
        ))
    }
}
public extension MediaCard {
    func subtitle(_ s: String?) -> Self { copy { $0.subtitle = s } }
    func image(systemName: String) -> Self { copy { $0.imageSystemName = systemName } }
    func badge(_ b: String?) -> Self { copy { $0.badge = b } }
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    func surface(_ key: Theme.BackgroundColorKey?) -> Self { copy { $0.surfaceKey = key } }
    func onSelect(_ a: @escaping () -> Void) -> Self { copy { $0.onSelect = a } }
    private func copy(_ m: (inout Self) -> Void) -> Self { var c = self; m(&c); return c }
}
```

Usage:
```swift
List(items) { MediaCard($0.title).subtitle($0.sub).onSelect { pick($0) } }
    .mediaCardStyle(.compact)   // one line styles the whole list; swap to .hero per section
```
