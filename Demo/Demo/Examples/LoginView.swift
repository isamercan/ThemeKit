//
//  LoginView.swift
//  Demo
//
//  A login screen rebuilt from the Figma "Login-register form" node
//  (file MX2ACwPhpSO9gyRImA7Dnc · node 25795:9030), expressed with ThemeKit
//  components + tokens. The Figma node is built from component instances that
//  figma_to_swiftui can't expand, so the structure (title · inputs · remember
//  row · primary button · "veya" divider · social login · sign-up prompt) and
//  its Turkish copy were mapped to ThemeKit components by hand.
//

import SwiftUI
import ThemeKit

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var attempted = false
    @State private var isLoading = false

    private var emailRules: [ValidationRule] {
        [.required("Bu alan zorunludur"), .email("Geçerli bir e-posta adresi girin")]
    }

    private var passwordRules: [ValidationRule] {
        [.required("Bu alan zorunludur"), .minLength(6, "Şifre en az 6 karakter olmalı")]
    }

    private var emailMessages: [InfoMessage] { attempted ? Validator.validate(email, emailRules) : [] }
    private var passwordMessages: [InfoMessage] { attempted ? Validator.validate(password, passwordRules) : [] }
    private var isValid: Bool {
        Validator.validate(email, emailRules).isEmpty && Validator.validate(password, passwordRules).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                Title("Giriş Yap").subtitle("Hesabınıza giriş yapın")

                Card {
                    VStack(spacing: Theme.SpacingKey.md.value) {
                        TextInput("E-posta adresi", text: $email)
                            .placeholder("ornek@eposta.com")
                            .icon(leading: "envelope")
                            .clearable()
                            .infoMessages(emailMessages)
                            .keyboard(.emailAddress, contentType: .emailAddress, capitalization: TextInputCapitalization.never)
                            .autocorrectionDisabled()

                        TextInput("Şifre", text: $password)
                            .placeholder("Şifreniz")
                            .icon(leading: "lock")
                            .secure()
                            .infoMessages(passwordMessages)
                            .keyboard(contentType: .password)

                        HStack {
                            Checkbox("Beni Hatırla", isChecked: $rememberMe)
                            Spacer()
                            TextLink("Şifremi Unuttum") {}
                        }

                        PrimaryButton("Giriş Yap") { signIn() }.fullWidth().loading(isLoading)

                        DividerView("veya")

                        OutlineButton("Apple ile devam et") {}.fullWidth()
                    }
                }

                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text("Henüz hesabınız yok mu?")
                        .textStyle(.bodySm400)
                        .foregroundStyle(Theme.shared.text(.textSecondary))
                    TextLink("Üye Olun") {}
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Giriş")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signIn() {
        attempted = true
        guard isValid else { return }
        isLoading = true
        // Simulate an auth round-trip.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { isLoading = false }
    }
}

#Preview {
    NavigationStack { LoginView() }
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
