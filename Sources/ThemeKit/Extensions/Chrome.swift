//
//  Chrome.swift
//  ThemeKit
//
//  The chrome view-extension family — the SwiftUI analog of HeroUI's `asChild`.
//  When a container's shell is independently useful, it is exposed as a `View`
//  extension that applies the *same tokens and the same active Style protocol*
//  the organism uses: `surfaceChrome(_:radius:)` (SurfaceView.swift) donates the
//  surface atom's shell, `cardChrome(elevation:surface:radius:)` donates Card's,
//  and `fieldChrome(isFocused:hasError:hasWarning:size:)` donates the field
//  family's. Because both ride the ambient `.cardStyle(_:)` / `.fieldStyle(_:)`
//  environment, a consumer's custom style re-skins bespoke layouts too.
//
//      VStack { … }
//          .cardChrome(elevation: .elevated)      // Card's shell, no Card anatomy
//
//      MyRatingControl(value: $stars)
//          .fieldChrome(isFocused: focused, hasError: invalid)
//

import SwiftUI

public extension View {
    /// Applies the active ``CardStyle``'s surface (fill, border, shadow, radius)
    /// to this view without adopting `Card`'s header/body anatomy — the
    /// `asChild` analog for card-shaped bespoke layouts. Rides the ambient
    /// `.cardStyle(_:)` environment, so a custom style re-skins this chrome too.
    ///
    /// The chrome adds no padding, interaction or accessibility traits; content
    /// insets stay the caller's responsibility (as with `surfaceChrome`).
    func cardChrome(elevation: CardElevation = .soft,
                    surface: Theme.BackgroundColorKey = .bgWhite,
                    radius: Theme.RadiusRole = .box) -> some View {
        modifier(CardChrome(elevation: elevation, surface: surface, radius: radius))
    }

    /// Applies the active ``FieldStyle``'s chrome (fill + focus/error/warning
    /// border) to a custom control so bespoke inputs sit visually inside the
    /// form family — the `asChild` analog for field-shaped controls. Rides the
    /// ambient `.fieldStyle(_:)` environment.
    ///
    /// The enabled state is read natively from `\.isEnabled` (set with
    /// `.disabled(_:)`); `size` is advisory, for styles that key chrome off the
    /// field-height preset — the content keeps its own height.
    func fieldChrome(isFocused: Bool = false,
                     hasError: Bool = false,
                     hasWarning: Bool = false,
                     size: TextInputSize = .medium) -> some View {
        modifier(FieldChrome(isFocused: isFocused, hasError: hasError,
                             hasWarning: hasWarning, size: size))
    }
}

/// Wraps arbitrary content in the active `CardStyle`'s shell — the same
/// configuration `Card` builds, minus the header/body anatomy.
private struct CardChrome: ViewModifier {
    @Environment(\.cardStyle) private var cardStyle
    let elevation: CardElevation
    let surface: Theme.BackgroundColorKey
    let radius: Theme.RadiusRole

    func body(content: Content) -> some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(content),
            elevation: elevation,
            surfaceKey: surface,
            radius: radius
        ))
    }
}

/// Wraps arbitrary content in the active `FieldStyle`'s chrome — the same
/// configuration `TextInput` builds, with the enabled state read from the
/// native environment.
private struct FieldChrome: ViewModifier {
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.isEnabled) private var isEnabled   // native — set by `.disabled(_:)`
    let isFocused: Bool
    let hasError: Bool
    let hasWarning: Bool
    let size: TextInputSize

    func body(content: Content) -> some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(content),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: size
        ))
    }
}

// MARK: - Previews

#Preview("Chrome family") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var focused = false
        var body: some View {
            ScrollView {
                VStack(spacing: Theme.SpacingKey.md.value) {
                    // Card's shell on a bespoke layout — no Card anatomy.
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                        Text("Bespoke layout").textStyle(.headingSm)
                            .foregroundStyle(theme.text(.textPrimary))
                        Text("cardChrome donates the active CardStyle's surface.")
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.SpacingKey.md.value)
                    .cardChrome()

                    // Elevation / surface / radius knobs.
                    Text("Elevated · secondary surface · field radius")
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textSecondary))
                        .padding(Theme.SpacingKey.md.value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardChrome(elevation: .elevated, surface: .bgSecondaryLight, radius: .field)

                    // A custom-style re-skin reaches the chrome too (outlined).
                    Text("Outlined via .cardStyle(.outlined)")
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textSecondary))
                        .padding(Theme.SpacingKey.md.value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardChrome()
                        .cardStyle(.outlined)

                    // Field chrome on a bespoke control, all states.
                    HStack {
                        Text("Custom control").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                        Toggle("", isOn: $focused).labelsHidden()
                    }
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .frame(height: TextInputSize.medium.height)
                    .fieldChrome(isFocused: focused)

                    Text("Error").textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .frame(height: TextInputSize.small.height)
                        .fieldChrome(hasError: true, size: .small)

                    Text("Warning").textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .frame(height: TextInputSize.small.height)
                        .fieldChrome(hasWarning: true, size: .small)

                    // Disabled natively; underlined via the ambient FieldStyle.
                    Text("Disabled · underlined")
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textDisabled))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .frame(height: TextInputSize.small.height)
                        .fieldChrome(size: .small)
                        .disabled(true)
                        .fieldStyle(.underlined)
                }
                .padding()
            }
            .background(theme.background(.bgBase))
        }
    }
    return Demo()
}
