//
//  Dialog.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A modal dialog (title / message / up to two actions) presented over
//  a dimmed scrim via the `.dialog(...)` modifier.
//

import SwiftUI

struct DialogCard: View {
    @Environment(\.theme) private var theme

    let title: String
    let message: String?
    let primaryTitle: String
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    /// When set, the primary action uses a `ThemeButton` in this color
    /// (e.g. `.error` for destructive confirms). `nil` keeps the default primary.
    var primaryColor: SemanticColor? = nil
    /// When set, an icon header is shown (info / success / warning / error variant).
    var kind: FeedbackKind? = nil
    /// When set, a close (X) button is shown in the top-trailing corner.
    var onClose: (() -> Void)? = nil
    /// Maximum card width (default 320).
    var width: CGFloat? = nil
    /// While true the primary button spins and the secondary is disabled.
    var isPrimaryLoading: Bool = false

    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if let kind {
                Icon(systemName: kind.systemImage, size: .xl, color: kind.semanticColor.accent)
            }
            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(title)
                    .textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let primaryColor {
                    ThemeButton(primaryTitle, color: primaryColor, block: true, isLoading: .constant(isPrimaryLoading), action: onPrimary)
                } else {
                    PrimaryButton(primaryTitle, isContentWidth: true, isLoading: .constant(isPrimaryLoading), action: onPrimary)
                }
                if let secondaryTitle, let onSecondary {
                    OutlineButton(secondaryTitle, isContentWidth: true, isEnabled: .constant(!isPrimaryLoading), action: onSecondary)
                }
            }
        }
        .padding(Theme.SpacingKey.lg.value)
        .frame(maxWidth: width ?? 320)
        // Floating modal chrome → Liquid Glass on OS 26+, Material below, opaque under Reduce Transparency.
        .glassChrome(in: RoundedRectangle(cornerRadius: Theme.RadiusKey.lg.value, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let onClose {
                Button(action: onClose) {
                    Icon(systemName: "xmark", size: .sm, color: theme.text(.textTertiary))
                        .padding(Theme.SpacingKey.md.value)
                }
                .buttonStyle(.plain)
            }
        }
        .themeShadow(.elevated)
    }
}

private struct DialogModifier: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let primaryTitle: String
    let onPrimary: () async -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    let kind: FeedbackKind?
    let closable: Bool
    let maskClosable: Bool
    let width: CGFloat?

    @State private var primaryLoading = false
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    theme.background(.bgTertiary).opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { if maskClosable, !primaryLoading { isPresented = false } }
                    DialogCard(
                        title: title, message: message,
                        primaryTitle: primaryTitle,
                        onPrimary: {
                            // Keep the dialog open with a spinner until the (possibly
                            // async) work resolves, then dismiss. (Ant Modal confirmLoading.)
                            Task {
                                primaryLoading = true
                                await onPrimary()
                                primaryLoading = false
                                isPresented = false
                            }
                        },
                        secondaryTitle: secondaryTitle,
                        onSecondary: onSecondary.map { handler in { isPresented = false; handler() } },
                        primaryColor: kind?.semanticColor,
                        kind: kind,
                        onClose: (closable && !primaryLoading) ? { isPresented = false } : nil,
                        width: width,
                        isPrimaryLoading: primaryLoading
                    )
                    .padding(Theme.SpacingKey.lg.value)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    func dialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        primaryTitle: String,
        onPrimary: @escaping () async -> Void = {},
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        kind: FeedbackKind? = nil,
        closable: Bool = false,
        maskClosable: Bool = true,
        width: CGFloat? = nil
    ) -> some View {
        modifier(DialogModifier(
            isPresented: isPresented, title: title, message: message,
            primaryTitle: primaryTitle, onPrimary: onPrimary,
            secondaryTitle: secondaryTitle, onSecondary: onSecondary,
            kind: kind, closable: closable, maskClosable: maskClosable, width: width
        ))
    }
}

// MARK: - Custom content + footer slot (Ant Modal footer / scroll / afterClose)

private struct CustomDialogModifier<DialogContent: View, Footer: View>: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let title: String?
    let closable: Bool
    let maskClosable: Bool
    let width: CGFloat?
    let maxContentHeight: CGFloat
    let afterClose: (() -> Void)?
    let dialogContent: () -> DialogContent
    let footer: () -> Footer

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private func close() {
        isPresented = false
        afterClose?()
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    theme.background(.bgTertiary).opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { if maskClosable { close() } }

                    VStack(spacing: 0) {
                        if title != nil || closable {
                            HStack {
                                if let title {
                                    Text(title).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                                }
                                Spacer(minLength: Theme.SpacingKey.sm.value)
                                if closable {
                                    Button(action: close) {
                                        Icon(systemName: "xmark", size: .sm, color: theme.text(.textTertiary))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(Theme.SpacingKey.lg.value)
                        }

                        ScrollView {
                            dialogContent()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.SpacingKey.lg.value)
                                .padding(.bottom, Theme.SpacingKey.md.value)
                        }
                        .frame(maxHeight: maxContentHeight)

                        DividerView(size: .small)

                        footer()
                            .padding(Theme.SpacingKey.lg.value)
                    }
                    .frame(maxWidth: width ?? 360)
                    .background(theme.background(.bgWhite),
                                in: RoundedRectangle(cornerRadius: Theme.RadiusKey.lg.value, style: .continuous))
                    .themeShadow(.elevated)
                    .padding(Theme.SpacingKey.lg.value)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    /// A modal with custom scrollable content and a pinned footer slot
    /// (Ant Modal `footer` + long-content scroll + `afterClose`).
    func dialog<DialogContent: View, Footer: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        closable: Bool = true,
        maskClosable: Bool = true,
        width: CGFloat? = nil,
        maxContentHeight: CGFloat = 420,
        afterClose: (() -> Void)? = nil,
        @ViewBuilder content dialogContent: @escaping () -> DialogContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) -> some View {
        modifier(CustomDialogModifier(
            isPresented: isPresented, title: title, closable: closable, maskClosable: maskClosable,
            width: width, maxContentHeight: maxContentHeight, afterClose: afterClose,
            dialogContent: dialogContent, footer: footer
        ))
    }
}

#Preview {
    struct Demo: View {
        @State var show = true
        var body: some View {
            Color.gray.opacity(0.1).ignoresSafeArea()
                .dialog(isPresented: $show, title: "Delete trip?",
                        message: "This action cannot be undone.",
                        primaryTitle: "Delete", secondaryTitle: "Cancel", onSecondary: {})
        }
    }
    return Demo()
}
