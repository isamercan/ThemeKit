//
//  LoginLandingView.swift
//  Demo
//
//  The full "Login" landing screen rebuilt from the Figma node
//  (file MX2ACwPhpSO9gyRImA7Dnc · node 25795:9025) — the superset of the
//  form-only `LoginView` (node 25795:9030). It adds the brand header, the
//  "Yardım Destek" / "Rezervasyon Sorgula" menu rows and the ETS+ promo card.
//  The Figma node is assembled from component instances that figma_to_swiftui
//  can't expand, so the structure + Turkish copy were mapped onto ThemeKit
//  components + tokens by hand (no bespoke chrome — every surface is a kit view).
//

import SwiftUI
import ThemeKit

struct LoginLandingView: View {
    private var theme: Theme { Theme.shared }

    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var attempted = false
    @State private var isLoading = false

    // MARK: Validation (mirrors LoginView)

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

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.SpacingKey.md.value) {
                loginForm
                MenuCard(title: "Yardım Destek") { flash("Yardım Destek") }
                    .icon("questionmark.bubble")
                MenuCard(title: "Rezervasyon Sorgula") { flash("Rezervasyon Sorgula") }
                    .icon("plus.magnifyingglass")
                etsPlusPromo
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { brandWordmark }
        }
    }

    // MARK: Login / register form

    private var loginForm: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                Text("Giriş Yap")
                    .textStyle(.headingXs)
                    .foregroundStyle(theme.text(.textPrimary))

                TextInput("E-posta adresi", text: $email)
                    .placeholder("ornek@eposta.com")
                    .icon(leading: "envelope")
                    .clearable()
                    .infoMessages(emailMessages)
                    .keyboard(.emailAddress, contentType: .emailAddress, capitalization: .never)
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
                    TextLink("Şifremi Unuttum") { flash("Şifremi Unuttum") }.underline(false)
                }

                ThemeButton("Giriş Yap") { signIn() }
                    .color(.primary).size(.small).fullWidth()
                    .icon(trailing: "arrow.right").loading(isLoading)

                DividerView("veya")

                HStack(spacing: Theme.SpacingKey.md.value) {
                    socialButton("g.circle.fill", color: .primary) { flash("Google ile giriş") }
                    socialButton("applelogo", color: .neutral) { flash("Apple ile giriş") }
                    socialButton("f.square.fill", color: .primary) { flash("Facebook ile giriş") }
                }

                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text("Henüz hesabınız yok mu?")
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                    TextLink("Üye Olun") { flash("Üye Olun") }.underline(false)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func socialButton(_ symbol: String, color: SemanticColor, action: @escaping () -> Void) -> some View {
        ThemeButton(action: action)
            .icon(leading: symbol)
            .variant(.outline)
            .color(color)
            .size(.medium)
            .fullWidth()
    }

    // MARK: ETS+ promo

    private struct PromoFeature: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
    }

    private let features: [PromoFeature] = [
        .init(title: "Valiz ve Kontrol Listeleri", icon: "suitcase.fill"),
        .init(title: "Çevre Bilgileri", icon: "mappin.and.ellipse"),
        .init(title: "ETS Tesis Rehberi", icon: "building.2.fill"),
        .init(title: "Seyahat İpuçları", icon: "map.fill"),
    ]

    private var etsPlusPromo: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                Button { flash("ETS+") } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Text("ETS+")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.foreground(.systemcolorsFgInfo))
                            .padding(.horizontal, Theme.SpacingKey.sm.value)
                            .padding(.vertical, 2)
                            .background(theme.background(.bgTurquoiseLight), in: Capsule())
                        Text("ETS'nin Dijital Tatil Asistanı Yanında!")
                            .textStyle(.labelBase600)
                            .foregroundStyle(theme.text(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Theme.SpacingKey.sm.value)
                        Icon(systemName: "chevron.right").size(.sm).accent(.neutral)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ForEach(features) { feature in
                            Chip(feature.title, isSelected: .constant(false))
                                .icon(feature.icon)
                                .disabled(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: Brand

    private var brandWordmark: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text("etstur")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.foreground(.systemcolorsFgError))
            theme.border(.borderPrimary).frame(width: 1, height: 16)
            Text("35.YIL")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.foreground(.systemcolorsFgError))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("etstur 35. yıl")
    }

    // MARK: Actions

    private func signIn() {
        attempted = true
        guard isValid else { return }
        isLoading = true
        // Simulate an auth round-trip.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isLoading = false
            flash("Giriş başarılı")
        }
    }
}

#Preview {
    NavigationStack { LoginLandingView() }
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
