// This module intentionally exposes no API. It exists only so the Demo app's package
// graph pulls the root ThemeKit package with the "Calendar" trait enabled (see the
// adjacent Package.swift). Re-exporting ThemeKitCalendar keeps the module non-empty and
// lets `import DemoCalendarSupport` stand in for the add-on if a call site prefers it.
@_exported import ThemeKitCalendar
