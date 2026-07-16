//
//  LoginModalView.swift
//  Demo
//
//  A HeroUI-style login modal, built on ThemeKit's `.dialog(…)` presentation.
//  Modeled after the HeroUI Modal "login" example
//  (https://heroui.com/docs/components/modal): ModalHeader → ModalBody →
//  ModalFooter maps onto `.dialog(title:content:footer:)`.
//
//  Contents:
//   • the modal shell — header title, body slot, footer actions;
//   • email + password fields (mail / lock end icons, secure entry);
//   • a Remember me checkbox + Forgot password link (HeroUI justify-between row);
//   • a Sign in action that validates, shows a loading spinner, then dismisses;
//   • knobs for the HeroUI Modal props: size · backdrop · placement.
//

import SwiftUI
import ThemeKit

struct LoginModalView: View {
    @Environment(\.theme) private var theme
    // Auto-opens at launch via `-openLoginModal YES` (screenshots), like `-startTab`.
    @State private var isPresented = UserDefaults.standard.bool(forKey: "openLoginModal")
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false

    // HeroUI Modal props, exposed as knobs below.
    @State private var size: DialogSize = .sm
    @State private var backdrop: BackdropStyle = .dim
    @State private var placement: DialogPlacement = .center

    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty }

    // A labeled segmented picker over any String-backed CaseIterable prop.
    @ViewBuilder
    private func knob<T: RawRepresentable & CaseIterable & Hashable>(
        _ title: String, selection: Binding<T>
    ) -> some View where T.RawValue == String {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
            Picker(title, selection: selection) {
                ForEach(Array(T.allCases), id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("HeroUI Modal").textStyle(.headingLg)
            Text("A login modal built on ThemeKit's .dialog(…).")
                .textStyle(.bodyMd400)
                .foregroundStyle(theme.text(.textTertiary))
                .multilineTextAlignment(.center)

            // Knobs — the HeroUI Modal props (size · backdrop · placement).
            VStack(spacing: 12) {
                knob("Size", selection: $size)
                knob("Backdrop", selection: $backdrop)
                knob("Placement", selection: $placement)
            }
            .padding(.vertical, 8)

            PrimaryButton("Open Login") { isPresented = true }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // HeroUI Modal → ThemeKit `.dialog`:
        //   title == ModalHeader · content == ModalBody · footer == ModalFooter.
        .dialog(isPresented: $isPresented, title: "Log in",
                backdrop: backdrop, size: size, placement: placement) {
            // ModalBody — email + password (HeroUI endContent mail / lock icons).
            VStack(spacing: 16) {
                TextInput("Email", text: $email)
                    .placeholder("Enter your email")
                    .icon(trailing: "envelope")
                    .keyboard(.emailAddress, contentType: .emailAddress, capitalization: .never)
                    .autocorrectionDisabled()

                TextInput("Password", text: $password)
                    .placeholder("Enter your password")
                    .secure()   // secure entry shows a built-in reveal (eye) toggle

                // Remember me — ThemeKit's full-width ControlRow (checkbox on the
                // leading edge). Forgot password sits on its own trailing-aligned
                // line, so a narrow width drops it below instead of cramping the
                // label onto two lines.
                ControlRow("Remember me", isOn: $rememberMe)
                    .control(.checkbox)
                    .controlPlacement(.leading)

                TextLink("Forgot password?") { flash("Forgot password") }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } footer: {
            // ModalFooter — Close (danger flat) + Sign in (primary), right-aligned.
            // Sign in is disabled until both fields are filled; its async `task:`
            // shows an automatic spinner while "authenticating", then dismisses.
            HStack(spacing: 8) {
                Spacer()
                DangerSoftButton("Close") { isPresented = false }
                PrimaryButton("Sign in", task: {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)   // pretend to authenticate
                    flash("Signed in as \(email)")
                    isPresented = false
                })
                .disabled(!canSubmit)
            }
        }
    }
}

#Preview {
    LoginModalView()
}
