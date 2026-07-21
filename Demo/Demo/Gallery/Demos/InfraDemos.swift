//
//  InfraDemos.swift
//  Demo
//
//  Interactive demo pages for the #250 infrastructure layer: subtree house
//  defaults (fieldDefaults / feedbackDefaults), one-liner form wiring
//  (FormValidator + .field(_:in:)), and the chrome view-extension family
//  (cardChrome / fieldChrome — the `asChild` analog).
//

import SwiftUI
import ThemeKit

// MARK: - Field Defaults (subtree house style for the field family)

struct FieldDefaultsDemo: View {
    @State private var size: TextInputSize = .large
    @State private var messagesAnimated = true
    @State private var requiredIndicator = true

    @State private var email = ""
    @State private var promo = ""
    @State private var query = ""
    @State private var date: Date?

    private var sizeLabel: String {
        switch size {
        case .xsmall: return ".xsmall"
        case .small: return ".small"
        case .medium: return ".medium"
        case .large: return ".large"
        }
    }

    var body: some View {
        ComponentStage("Field Defaults", inspector: [
            ("size", sizeLabel),
            ("messagesAnimated", "\(messagesAnimated)"),
            ("requiredIndicator", "\(requiredIndicator)"),
        ]) {
            // One `.fieldDefaults(...)` on the stack re-configures the whole
            // field family below it; the promo field's explicit `.size` wins.
            VStack(spacing: Theme.SpacingKey.md.value) {
                TextInput("Email", text: $email)
                    .required()
                    .validate([.required(), .email()], on: .live)
                TextInput("Promo code", text: $promo)
                    .placeholder("Explicit .size(.xsmall) wins")
                    .size(.xsmall)                    // per-field modifier beats the default
                SearchBar(text: $query)               // maps the default onto its control height
                DateField("Check-in", date: $date)
            }
            .fieldDefaults(size: size,
                           messagesAnimated: messagesAnimated,
                           requiredIndicator: requiredIndicator)
        } knobs: {
            Picker("Default size", selection: $size) {
                Text("XS").tag(TextInputSize.xsmall); Text("S").tag(TextInputSize.small)
                Text("M").tag(TextInputSize.medium); Text("L").tag(TextInputSize.large)
            }
            .pickerStyle(.segmented)
            Toggle("Animate message rows", isOn: $messagesAnimated)
            Toggle("Required asterisk (a11y suffix always spoken)", isOn: $requiredIndicator)
        }
    }
}

// MARK: - Feedback Defaults (subtree house style for toasts)

struct FeedbackDefaultsDemo: View {
    @State private var position: ToastPosition = .top
    @State private var duration: Double = 2
    @State private var maxVisible = 2

    var body: some View {
        ComponentStage("Feedback Defaults", inspector: [
            ("toastPosition", position == .top ? ".top" : ".bottom"),
            ("toastDuration", String(format: "%.1fs", duration)),
            ("maxVisibleToasts", "\(maxVisible)"),
        ]) {
            // A page-local `.feedbackHost()` so the knobs' defaults apply to
            // this canvas only — `.feedbackDefaults` wraps *around* the host.
            FeedbackDefaultsStage()
                .frame(height: 300)
                .feedbackHost()
                .feedbackDefaults(toastPosition: position,
                                  toastDuration: duration,
                                  maxVisibleToasts: maxVisible)
        } knobs: {
            Picker("Position", selection: $position) {
                Text("Top").tag(ToastPosition.top); Text("Bottom").tag(ToastPosition.bottom)
            }
            .pickerStyle(.segmented)
            NumberKnob(title: "Duration (s)", value: $duration, range: 0.5 ... 6, step: 0.5)
            Stepper("Max visible toasts: \(maxVisible)", value: $maxVisible, in: 1 ... 5)
        }
    }
}

/// The area inside the local `.feedbackHost()` — reads the page presenter and
/// the ambient defaults (to demo that an explicit per-call argument wins).
private struct FeedbackDefaultsStage: View {
    @EnvironmentObject private var feedback: FeedbackPresenter
    @Environment(\.feedbackDefaults) private var defaults
    @Environment(\.theme) private var theme
    @State private var count = 0

    private var oppositeEdge: ToastPosition { defaults.toastPosition == .top ? .bottom : .top }

    var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            ThemeButton("Toast (rides the defaults)") {
                count += 1
                feedback.toast("Toast #\(count) — position, duration and cap from defaults", kind: .success)
            }
            .fullWidth()
            ThemeButton("Stack ×4 (cap drops oldest)") {
                for _ in 1 ... 4 { count += 1; feedback.toast("Toast #\(count)", kind: .info) }
            }
            .variant(.soft)
            .fullWidth()
            ThemeButton("Explicit position wins") {
                feedback.toast("Pinned to the other edge", kind: .neutral, position: oppositeEdge)
            }
            .variant(.outline)
            .fullWidth()
            ThemeButton("Explicit duration: nil (sticky)") {
                feedback.toast("Sticky despite the default", kind: .accent, duration: nil)
            }
            .variant(.outline)
            .fullWidth()
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
    }
}

// MARK: - Form Wiring (FormValidator + .field(_:in:))

struct FormWiringDemo: View {
    private enum Field { case email, password, promo }

    @StateObject private var form = FormValidator<Field>([
        .email: [.required(), .email()],
        .password: [.required(), .minLength(8)],
        .promo: [.required("Promo code is required")],
    ])
    @State private var email = ""
    @State private var password = ""
    @State private var promo = ""
    @State private var lastSubmit = "—"

    private var values: [Field: String] { [.email: email, .password: password, .promo: promo] }

    var body: some View {
        ComponentStage("Form Wiring", inspector: [
            ("focusedField", form.focusedField.map { "\($0)" } ?? "nil"),
            ("last submit", lastSubmit),
        ]) {
            // `.field(_:in:)` = infoMessages + externalFocus + live re-validate
            // in one line; `submit` focuses the first invalid field.
            VStack(spacing: Theme.SpacingKey.md.value) {
                TextInput("Email", text: $email)
                    .icon(leading: "envelope")
                    .keyboard(.emailAddress, contentType: .emailAddress, submit: .next, capitalization: .never)
                    .field(.email, in: form)
                TextInput("Password", text: $password)
                    .secure()
                    .field(.password, in: form)
                TextInput("Promo code", text: $promo)
                    .required()
                    .field(.promo, in: form)
                PrimaryButton("Submit") {
                    let ran = form.submit(values) { flash("Form valid — action ran ✓") }
                    lastSubmit = ran ? "valid ✓" : "invalid — first error focused"
                }
                .fullWidth()
            }
        } knobs: {
            Text("Submit with empty fields: the first invalid field gets focus and every field shows its messages. Fix a field and defocus — it re-validates live.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset validation state") {
                form.reset()
                lastSubmit = "—"
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Chrome (cardChrome / fieldChrome — the `asChild` analog)

struct ChromeDemo: View {
    @Environment(\.theme) private var theme
    @State private var elevationIdx = 1        // none / soft / elevated
    @State private var outlinedCard = false
    @State private var fieldStyleIdx = 0       // default / muted / underlined
    @State private var stars = 3
    @State private var focused = false
    @State private var hasError = false
    @State private var hasWarning = false

    private var elevation: CardElevation { [CardElevation.none, .soft, .elevated][elevationIdx] }

    var body: some View {
        ComponentStage("Chrome", inspector: [
            ("cardStyle", outlinedCard ? ".outlined" : ".default"),
            ("fieldStyle", [".default", ".muted", ".underlined"][fieldStyleIdx]),
            ("elevation", [".none", ".soft", ".elevated"][elevationIdx]),
        ]) {
            restyled
        } knobs: {
            Picker("Card elevation", selection: $elevationIdx) {
                Text("None").tag(0); Text("Soft").tag(1); Text("Elevated").tag(2)
            }
            .pickerStyle(.segmented)
            Toggle("Re-skin cards (.cardStyle(.outlined))", isOn: $outlinedCard)
            Picker("Field style", selection: $fieldStyleIdx) {
                Text("Default").tag(0); Text("Muted").tag(1); Text("Underlined").tag(2)
            }
            .pickerStyle(.segmented)
            Toggle("Focused", isOn: $focused)
            Toggle("Error", isOn: $hasError)
            Toggle("Warning", isOn: $hasWarning)
        }
    }

    // Both chromes ride the ambient style environment, so the re-skin toggles
    // reach the bespoke layouts too.
    @ViewBuilder private var restyled: some View {
        if outlinedCard {
            fieldStyled.cardStyle(.outlined)
        } else {
            fieldStyled
        }
    }

    @ViewBuilder private var fieldStyled: some View {
        switch fieldStyleIdx {
        case 1: stack.fieldStyle(.muted)
        case 2: stack.fieldStyle(.underlined)
        default: stack
        }
    }

    private var stack: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            // A bespoke layout wearing Card's shell — no Card anatomy.
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                Text("Bespoke layout").textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                Text("cardChrome donates the active CardStyle's surface — fill, border, shadow, radius.")
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.SpacingKey.md.value)
            .cardChrome(elevation: elevation)

            // A custom control wearing the field family's chrome.
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Text("Rating").textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textPrimary))
                Spacer()
                ForEach(1 ... 5, id: \.self) { star in
                    Button {
                        stars = star
                        focused = true
                    } label: {
                        Image(systemName: star <= stars ? "star.fill" : "star")
                            .foregroundStyle(star <= stars ? SemanticColor.warning.base : theme.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rate \(star) of 5")
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(height: 56)   // the .medium field height (TextInputSize metrics are library-internal)
            .fieldChrome(isFocused: focused, hasError: hasError, hasWarning: hasWarning)
        }
    }
}
