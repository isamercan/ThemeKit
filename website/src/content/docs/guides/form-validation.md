---
title: Form Validation
description: A pure validation-logic layer plus SwiftUI presentation — predicates, regex, and async rules.
---

ThemeKit splits validation into two layers: a **pure logic** layer you can unit
test in isolation, and a **SwiftUI presentation** layer that surfaces results
inline on your inputs.

## The logic layer

`Validator`, `ValidationRule`, and the built-in `Validators` compose into rules
that return a result you can drive UI from. Rules are extensible — plain
predicates, regular expressions, or async checks (e.g. server-side uniqueness).

```swift
let rule = ValidationRule.all(
    Validators.required(message: "Email is required"),
    Validators.email(message: "Enter a valid email")
)

let result = rule.validate(emailField)   // pure, synchronous, testable
```

## Presentation

Bind a rule to an input and ThemeKit renders the error state and message using
the active theme's semantic colors and spacing — consistent with the rest of your
UI.

```swift
TextInput("Email", text: $email)
    .validation(rule, message: $emailError)
```

## Extending

Add your own predicate or regex rule, or an async validator for checks that need
the network:

```swift
let unique = Validator.async { value in
    await api.isEmailAvailable(value) ? .valid : .invalid("Already taken")
}
```

:::note
For symbol-level docs on `Validators`, `ValidationRule`, and `Validator`, see the
[DocC Validation article](/ThemeKit/api/documentation/themekit/validation/).
:::
