//
//  CardFormView.swift
//  Demo
//
//  HeroUI "Card with Form" (heroui.com/docs/components/card#with-form) rebuilt with
//  ThemeKit — and shown three ways from one piece of content: inline in the screen,
//  in a `.dialog`, and in a `.bottomSheet`. The login form (header + fields + submit)
//  lives in a single padding-free `formContent`; each container supplies its own
//  surface (Card chrome · dialog surface · sheet chrome), so there's no double frame.
//
//  Segmented knobs drive the dialog props (size · backdrop · placement) and the
//  sheet props (detent · attached/detached), mirroring the HeroUI prop tables.
//  All spacing comes from theme spacing tokens (`theme.spacing(_:)`), never raw px.
//

import SwiftUI
import ThemeKit

struct CardFormView: View {
    @Environment(\.theme) private var theme

    /// The card's max width — a layout dimension (HeroUI `max-w-md`), not spacing.
    private let cardMaxWidth: CGFloat = 420

    @State private var email = ""
    @State private var password = ""

    // Which presentation is showing. Inline starts open so the screen isn't empty.
    @State private var showInline = true
    @State private var showDialog = false
    @State private var showSheet = false

    // Dialog knobs — the HeroUI Modal props.
    @State private var dialogSize: DialogSize = .sm
    @State private var backdrop: BackdropStyle = .dim
    @State private var placement: DialogPlacement = .center

    // Sheet knobs — detent ramp + attached/detached (HeroUI floating) style.
    @State private var sheetSize: SheetSize = .compact
    @State private var sheetStyle: SheetStyle = .attached

    /// Detent ramp for the sheet. `.compact` hugs the form; both others allow a
    /// drag up to `.large`. A snug primary detent keeps the sheet card-like.
    private enum SheetSize: String, CaseIterable, Hashable {
        case compact, medium, large
        var detents: [BottomSheetDetent] {
            switch self {
            case .compact: return [.height(460), .large]
            case .medium: return [.medium, .large]
            case .large: return [.large]
            }
        }
    }

    /// Attached (edge-to-edge) vs. detached (inset floating card — HeroUI parity).
    private enum SheetStyle: String, CaseIterable, Hashable {
        case attached, detached
    }

    // MARK: - Field + form content

    // Filled (`.muted`) field — the HeroUI `variant="secondary"` look. The label sits
    // above the box and the placeholder inside; `formContent` opts the whole form into
    // `.above` once via `.fieldDefaults`, so no per-field placement call is needed.
    private func field(_ label: String, placeholder: String, text: Binding<String>,
                       secure: Bool = false, isEmail: Bool = false) -> some View {
        TextInput(label, text: text)
            .placeholder(placeholder)
            .secure(secure)
            .keyboard(isEmail ? TextInputKeyboard.emailAddress : .default,
                      contentType: isEmail ? TextInputContentType.emailAddress : nil,
                      capitalization: isEmail ? TextInputCapitalization.never : nil)
            .autocorrectionDisabled(isEmail)
            .fieldStyle(.muted)   // View-level; must come after the TextInput modifiers
    }

    // The reusable login form — header + fields + footer, with NO outer padding or
    // surface. Every presentation (Card · dialog · sheet) wraps it in its own chrome.
    @ViewBuilder private var formContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing(.base)) {
            // Header — title + description.
            VStack(alignment: .leading, spacing: theme.spacing(.xs)) {
                Text("Login").textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                Text("Enter your credentials to access your account")
                    .textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
            }

            // Body — the form.
            VStack(spacing: theme.spacing(.md)) {
                field("Email", placeholder: "email@example.com", text: $email, isEmail: true)
                field("Password", placeholder: "••••••••", text: $password, secure: true)
            }

            // Footer — full-width submit + centered link (mt-4, gap-2).
            VStack(spacing: theme.spacing(.sm)) {
                Button { submit() } label: {
                    Text("Sign In")
                        .textStyle(.labelBase600)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing(.md))
                        .background(Color.black, in: Capsule())   // HeroUI pure-black submit
                }
                .buttonStyle(.plain)
                Button { flash("Forgot password") } label: {
                    Text("Forgot password?").textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textPrimary))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, theme.spacing(.md))   // HeroUI footer `mt-4`
        }
        // Stacked labels for every field in the form (HeroUI `labelPlacement="outside"`).
        // Set on `formContent` itself, so all three presentations inherit it.
        .fieldDefaults(labelPlacement: .above)
    }

    // Submitting closes whatever presentation is open (no-op for the inline card).
    private func submit() {
        flash("Form submitted successfully!")
        showDialog = false
        showSheet = false
    }

    // MARK: - Knobs

    // A labeled segmented picker over any String-backed CaseIterable prop.
    @ViewBuilder
    private func knob<T: RawRepresentable & CaseIterable & Hashable>(
        _ title: String, selection: Binding<T>
    ) -> some View where T.RawValue == String {
        VStack(alignment: .leading, spacing: theme.spacing(.xs)) {
            Text(title).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
            Picker(title, selection: selection) {
                ForEach(Array(T.allCases), id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // A titled group of knobs, constrained to the card width.
    @ViewBuilder
    private func optionsSection<Content: View>(
        _ title: String, @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing(.sm)) {
            Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textSecondary))
            content()
        }
        .frame(maxWidth: cardMaxWidth, alignment: .leading)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing(.base)) {
                // Screen intro — what the three buttons do.
                VStack(spacing: theme.spacing(.xs)) {
                    Text("Card presentations").textStyle(.headingLg)
                        .foregroundStyle(theme.text(.textPrimary))
                    Text("The same login card, shown three ways.")
                        .textStyle(.bodyMd400).foregroundStyle(theme.text(.textTertiary))
                        .multilineTextAlignment(.center)
                }

                // The three triggers: inline · dialog · bottom sheet.
                VStack(spacing: theme.spacing(.sm)) {
                    PrimaryButton(showInline ? "Hide inline card" : "Show inline card") {
                        withAnimation { showInline.toggle() }
                    }
                    .fullWidth()
                    SecondaryButton("Open as dialog") { showDialog = true }.fullWidth()
                    OutlineButton("Open as bottom sheet") { showSheet = true }.fullWidth()
                }
                .frame(maxWidth: cardMaxWidth)

                // Knobs — dialog props then sheet props (applied when each opens).
                optionsSection("Dialog options") {
                    knob("Size", selection: $dialogSize)
                    knob("Backdrop", selection: $backdrop)
                    knob("Placement", selection: $placement)
                }
                optionsSection("Bottom sheet options") {
                    knob("Detent", selection: $sheetSize)
                    knob("Style", selection: $sheetStyle)
                }

                // 1) Inline — the Card supplies the card chrome.
                if showInline {
                    Card { formContent }
                        .contentPadding(.base)          // 24 — HeroUI card padding, via the token
                        .frame(maxWidth: cardMaxWidth)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing(.base))
        }
        // 2) Dialog — the dialog surface IS the card (single surface, no nested
        // Card / no frosted halo). The freeform dialog insets content by `.lg`
        // (32); trim it back to the card's `.base` (24) so the dialog's edge
        // padding matches the inline card exactly. Same `Theme.shared` spacing
        // resolution as the dialog's own inset, so this nets to precisely 24.
        .dialog(isPresented: $showDialog, closable: true,
                backdrop: backdrop, size: dialogSize, placement: placement) {
            formContent.padding(theme.spacing(.base) - theme.spacing(.lg))
        }
        // 3) Bottom sheet — the sheet surface IS the card (single opaque `.bgWhite`
        // surface, no nested Card / no double background). The sheet wrapper insets
        // content by `.md` (16); add the delta up to the card's `.base` (24) so the
        // sheet's edge padding matches the inline card + dialog exactly.
        .bottomSheet(isPresented: $showSheet, detents: sheetSize.detents,
                     detached: sheetStyle == .detached, surface: .bgWhite) {
            ScrollView {
                formContent.padding(theme.spacing(.base) - theme.spacing(.md))
            }
        }
    }
}

#Preview {
    CardFormView()
}
