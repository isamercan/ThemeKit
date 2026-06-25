# Validation

A pure, testable validation core with a separate SwiftUI presentation layer —
extensible with your own predicates, regex, or async checks.

## Overview

Validation is split so the logic never depends on SwiftUI or the theme:

- ``Validators`` — pure `(String) -> Bool` predicates (`email`, `phone`,
  `password`, `intInRange`, …). Reusable and unit-testable on their own.
- ``ValidationRule`` — binds a predicate to a message and a severity.
- ``Validator`` — runs rules against a value and returns ``InfoMessage`` results.
- ``InfoMessage`` — the pure message value; ``InfoMessageList`` renders it.

```swift
let rules: [ValidationRule] = [.required(), .email()]
let messages = Validator.validate(email, rules)   // [InfoMessage]
InfoMessageList(messages)                          // SwiftUI rendering
```

### Feeding your own logic

Any predicate, any regex pattern, or a typed Swift `Regex` (iOS 16+):

```swift
// Custom predicate
ValidationRule("only AAA") { $0 == "AAA" }

// Regex pattern, optionally case-insensitive
.regex("^[a-z]+$", caseInsensitive: true, "letters only")

// Typed Regex (compile-time checked)
.matches(try Regex(#"^\d{3}$"#), "3 digits")
```

### Async rules

For server-side checks (username taken, coupon valid…), use
``AsyncValidationRule`` and the async overload of ``Validator``:

```swift
let unique = AsyncValidationRule("Username taken") { name in
    await api.isAvailable(name)
}
let messages = await Validator.validate(name, async: [unique])
```

### Driving a form

``FormValidator`` ties fields, rules, focus, and messages together for a whole
form, and vends focus bindings for ``TextInput``.

## Topics

### Logic

- ``Validators``
- ``ValidationRule``
- ``AsyncValidationRule``
- ``Validator``
- ``FormValidator``

### Messages & presentation

- ``InfoMessage``
- ``InfoMessageList``
