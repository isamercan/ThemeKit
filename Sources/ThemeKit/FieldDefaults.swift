//
//  FieldDefaults.swift
//  ThemeKit
//
//  A subtree-level "house style" for the text-field family — default control
//  size, message-row animation, and required-asterisk visibility. Set it once
//  with `.fieldDefaults(...)` and the field components (TextInput,
//  MultiLineTextInput, SearchBar, DateField, InputNumber, OTPInput) read it as
//  their default when the corresponding modifier isn't set explicitly. Additive
//  and Open/Closed: a per-field modifier still wins; this only fills the default.
//
//  ```swift
//  BookingForm()
//      .fieldDefaults(size: .large, messagesAnimated: false)
//  ```
//

import SwiftUI

/// House defaults for the field family (`TextInput`, `MultiLineTextInput`,
/// `SearchBar`, `DateField`, `InputNumber`, `OTPInput`). Every axis is optional;
/// `nil` keeps the component's own default, and an explicit per-field modifier
/// (e.g. `TextInput.size(_:)`) always wins over the subtree default.
public struct FieldDefaults: Equatable {
    /// Default control-size preset for the field family. Fields without their
    /// own `TextInputSize` axis map it onto their nearest metric (SearchBar's
    /// control height, InputNumber's regular/large height, OTPInput's cell height).
    public var size: TextInputSize?
    /// Whether validation / info message rows animate in and out
    /// (`InfoMessageList` appear-disappear motion). This only narrows or widens
    /// the field family's default — the `microAnimations` switch and the system
    /// Reduce Motion setting still win when they turn motion off.
    public var messagesAnimated: Bool?
    /// Whether `.required()` fields render the asterisk indicator (defaults to
    /// shown). The ", required" accessibility suffix is spoken regardless, so
    /// hiding the asterisk never hides the semantics from VoiceOver.
    public var requiredIndicator: Bool?

    public init(size: TextInputSize? = nil, messagesAnimated: Bool? = nil, requiredIndicator: Bool? = nil) {
        self.size = size
        self.messagesAnimated = messagesAnimated
        self.requiredIndicator = requiredIndicator
    }
}

private struct FieldDefaultsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = FieldDefaults()   // immutable empty default — safe
}

public extension EnvironmentValues {
    var fieldDefaults: FieldDefaults {
        get { self[FieldDefaultsKey.self] }
        set { self[FieldDefaultsKey.self] = newValue }
    }
}

public extension View {
    /// Sets the house-style defaults for the field family in this subtree. Only
    /// the provided fields are set (nested calls merge, inner wins per axis);
    /// a field's explicit modifier still overrides.
    func fieldDefaults(size: TextInputSize? = nil,
                       messagesAnimated: Bool? = nil,
                       requiredIndicator: Bool? = nil) -> some View {
        transformEnvironment(\.fieldDefaults) { d in
            if let size { d.size = size }
            if let messagesAnimated { d.messagesAnimated = messagesAnimated }
            if let requiredIndicator { d.requiredIndicator = requiredIndicator }
        }
    }
}

#Preview("Field defaults: size + required indicator") {
    struct Demo: View {
        @State var email = ""
        @State var note = ""
        @State var query = ""
        @State var date: Date?
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    Text("fieldDefaults(size: .large)").textStyle(.labelSm600)
                    TextInput("Email", text: $email).required()      // follows the default → large
                    TextInput("Promo code", text: $note).size(.xsmall)   // explicit wins → xsmall
                    SearchBar(text: $query)                           // maps the default onto its height
                    DateField("Check-in", date: $date)

                    Text("requiredIndicator: false").textStyle(.labelSm600)
                    TextInput("Email", text: $email).required()       // asterisk hidden, a11y suffix kept
                        .fieldDefaults(requiredIndicator: false)
                }
                .padding()
            }
            .fieldDefaults(size: .large)
        }
    }
    return Demo()
}
