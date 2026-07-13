//
//  AtomDemos.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Interactive demo pages for atom components. Each wraps the real component in
//  ComponentStage with live @State knobs.
//

import SwiftUI
import ThemeKit

struct AvatarDemo: View {
    @State private var size: AvatarSize = .md
    @State private var accent: SemanticColor = .primary
    @State private var initials = false
    @State private var square = false
    @State private var bordered = false
    @State private var group = false
    @State private var numeric = 0.0   // 0 = use enum tier; >0 = custom point size
    @State private var presenceIdx = 1   // 0 = none

    private let presences: [(String, StatusKind?)] = [
        ("None", nil), ("Online", .online), ("Away", .away), ("Busy", .busy), ("Offline", .offline),
    ]
    private var presence: StatusKind? { presences[presenceIdx].1 }

    var body: some View {
        ComponentStage("Avatar", inspector: [
            ("size", numeric > 0 ? "\(Int(numeric))pt" : "\(Int(size.rawValue))"), ("presence", presences[presenceIdx].0), ("bordered", "\(bordered)"),
        ]) {
            if group {
                AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .icon("person.fill"), .initials("GH"), .initials("IJ")]).size(size).maxVisible(4)
            } else if numeric > 0 {
                Avatar(initials ? .initials("AB") : .icon("person.fill")).dimension(numeric).accent(accent).shape(square ? .square : .circle).bordered(bordered, accent: accent).presence(presence, pulse: presence == .online)
            } else {
                Avatar(initials ? .initials("AB") : .icon("person.fill")).size(size).accent(accent).shape(square ? .square : .circle).bordered(bordered, accent: accent).presence(presence, pulse: presence == .online)
            }
        } knobs: {
            Picker("Presence", selection: $presenceIdx) {
                ForEach(Array(presences.enumerated()), id: \.offset) { i, p in Text(p.0).tag(i) }
            }.pickerStyle(.segmented).disabled(group)
            Picker("Size", selection: $size) {
                ForEach(AvatarSize.allCases, id: \.self) { Text("\(Int($0.rawValue))").tag($0) }
            }.pickerStyle(.segmented).disabled(numeric > 0)
            HStack { Text("Numeric"); SwiftUI.Slider(value: $numeric, in: 0...96, step: 4) }
            Picker("Accent", selection: $accent) {
                Text("Primary").tag(SemanticColor.primary); Text("Neutral").tag(SemanticColor.neutral); Text("Purple").tag(SemanticColor.purple)
            }.pickerStyle(.segmented)
            Toggle("Square shape", isOn: $square)
            Toggle("Bordered ring (accent-tinted)", isOn: $bordered)
            Toggle("Initials", isOn: $initials)
            Toggle("Avatar group (+N)", isOn: $group)
        }
    }
}

struct CountBadgeDemo: View {
    @State private var count = 5.0
    @State private var dot = false
    @State private var ribbon = false

    var body: some View {
        ComponentStage("CountBadge", inspector: [("count", "\(Int(count))"), ("dot", "\(dot)")]) {
            HStack(spacing: 40) {
                if ribbon {
                    Ribbon("New") {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.shared.background(.bgElevatorTertiary)).frame(width: 96, height: 72)
                    }
                    .accent(.error)
                } else if dot {
                    Image(systemName: "bell.fill").font(.largeTitle).foregroundStyle(Theme.shared.text(.textPrimary)).dotBadge(color: .success)
                } else {
                    Image(systemName: "bell.fill").font(.largeTitle).foregroundStyle(Theme.shared.text(.textPrimary)).countBadge(Int(count))
                }
            }
        } knobs: {
            HStack { Text("Count"); SwiftUI.Slider(value: $count, in: 0...120, step: 1) }
            Toggle("Dot only", isOn: $dot)
            Toggle("Ribbon", isOn: $ribbon)
        }
    }
}

struct BadgeDemo: View {
    @State private var text = "Badge"
    @State private var style: BadgeStyle = .info
    @State private var variant: FillVariant = .soft
    @State private var size: BadgeSize = .medium
    @State private var pill = true
    @State private var icon = false
    @State private var gradient = false
    @State private var highlighted = false
    @State private var tappable = false
    @State private var tapped = 0

    var body: some View {
        ComponentStage("Badge", inspector: [
            ("style", style.rawValue), ("size", "\(size)"), ("highlighted", "\(highlighted)"), ("taps", "\(tapped)"),
        ]) {
            Badge(text, action: tappable ? { tapped += 1; flash("Badge tapped") } : nil)
                .badgeStyle(style).variant(variant).size(size)
                .icon(icon ? "star.fill" : nil)
                .badgeShape(pill ? .pill : .rounded)
                .gradient(gradient ? [SemanticColor.primary, SemanticColor.purple] : nil)
                .highlighted(highlighted)
        } knobs: {
            TextField("Text", text: $text).textFieldStyle(.roundedBorder)
            Picker("Style", selection: $style) {
                ForEach(BadgeStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Size", selection: $size) {
                Text("S").tag(BadgeSize.small); Text("M").tag(BadgeSize.medium); Text("L").tag(BadgeSize.large); Text("XL").tag(BadgeSize.xlarge)
            }.pickerStyle(.segmented)
            Toggle("Pill shape", isOn: $pill)
            Toggle("Leading icon", isOn: $icon)
            Toggle("Gradient bg", isOn: $gradient)
            Toggle("Highlighted (shadow)", isOn: $highlighted)
            Toggle("Tappable (action)", isOn: $tappable)
        }
    }
}

struct ChipDemo: View {
    @State private var selected = true
    @State private var solid = false
    @State private var size: ChipSize = .small
    @State private var enabled = true
    @State private var rating = false
    @State private var exists = true
    @State private var expands = false

    var body: some View {
        ComponentStage("Chip", inspector: [
            ("isSelected", "\(selected)"), ("size", "\(size)"), ("isExist", "\(exists)"), ("isEnabled", "\(enabled)"),
        ]) {
            Chip(exists ? "Recommended" : "Sold out", isSelected: $selected)
                    .size(size)
                    .chipStyle(solid ? .solid : .tonal)
                    .rating(rating ? 4.6 : nil)
                    .exists(exists)
                    .fullWidth(expands)
                    .disabled(!enabled)
        } knobs: {
            Toggle("Selected", isOn: $selected)
            Toggle("Embedded rating", isOn: $rating)
            Toggle("isExist (strike-through when off)", isOn: $exists)
            Toggle("Expands horizontally", isOn: $expands)
            Toggle("Solid style", isOn: $solid)
            Picker("Size", selection: $size) {
                Text("Small").tag(ChipSize.small); Text("Medium").tag(ChipSize.medium); Text("Large").tag(ChipSize.large)
            }.pickerStyle(.segmented)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct ProgressBarDemo: View {
    @State private var value = 0.6
    @State private var statusIdx = 0   // 0 normal, 1 success, 2 exception
    @State private var gradient = false
    @State private var segmented = false
    @State private var custom = false
    @State private var success = false

    private var status: ProgressStatus { statusIdx == 1 ? .success : statusIdx == 2 ? .exception : .normal }

    var body: some View {
        ComponentStage("ProgressBar", inspector: [("value", String(format: "%.2f", value)), ("status", "\(status)")]) {
            VStack(spacing: 20) {
                ProgressBar(value: value)
                    .showsPercentage()
                    .status(status)
                    .gradient(gradient && !custom)
                    .steps(segmented ? 6 : nil)
                    .accent(custom ? .purple : nil)
                    .successSegment(success ? min(value, 0.4) : nil)
                StepIndicator(current: Int(value * 4), total: 5)
            }
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value) }
            Picker("Status", selection: $statusIdx) { Text("Normal").tag(0); Text("Success").tag(1); Text("Exception").tag(2) }.pickerStyle(.segmented)
            Toggle("Custom stroke/trail color", isOn: $custom)
            Toggle("Success segment (green)", isOn: $success)
            Toggle("Gradient", isOn: $gradient)
            Toggle("Segmented (steps)", isOn: $segmented)
        }
    }
}

struct RatingDemo: View {
    @State private var value = 4.3
    @State private var layoutIdx = 0   // 0 stars, 1 numberRate, 2 rateNumberText
    @State private var interactive = true
    @State private var allowHalf = true
    @State private var allowClear = false
    @State private var reviewLink = true
    @State private var taps = 0

    private var layout: RatingLayout { layoutIdx == 1 ? .numberRate : layoutIdx == 2 ? .rateNumberText : .stars }

    var body: some View {
        ComponentStage("Rating", inspector: [("value", String(format: "%.1f", value)), ("layout", "\(layout)"), ("reviewTaps", "\(taps)")]) {
            Rating(value: value)
                .layout(layout)
                .countLabel("1,284 reviews")
                .allowHalf(allowHalf)
                .allowClear(allowClear)
                .onRate((interactive && layoutIdx == 0) ? { value = $0; flash("Rating: \(String(format: "%.1f", $0))") } : nil)
                .onReviewTap(reviewLink ? { taps += 1; flash("Reviews tapped") } : nil)
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value, in: 0...5, step: 0.1) }
            Picker("Layout", selection: $layoutIdx) { Text("Stars").tag(0); Text("Number").tag(1); Text("Number+text").tag(2) }.pickerStyle(.segmented)
            Text("Stars: fill/half-tap. Number: value + star. Number+text: score chip + sentiment word.").font(.caption).foregroundStyle(.secondary)
            Toggle("Interactive (tap to rate, stars)", isOn: $interactive)
            Toggle("Allow half", isOn: $allowHalf)
            Toggle("Clear on re-tap (tap current value → 0)", isOn: $allowClear)
            Toggle("Tappable review count", isOn: $reviewLink)
        }
    }
}

struct SpinnerDemo: View {
    @State private var size = 24.0
    @State private var width = 3.0

    var body: some View {
        ComponentStage("Spinner", inspector: [("size", "\(Int(size))"), ("lineWidth", "\(Int(width))")]) {
            Spinner().size(size).lineWidth(width)
        } knobs: {
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 12...64) }
            HStack { Text("Line"); SwiftUI.Slider(value: $width, in: 1...8) }
        }
    }
}

struct TagDemo: View {
    @State private var text = "Istanbul"
    @State private var removable = true
    @State private var closable = false
    @State private var icon = false
    @State private var styleIdx = 0   // 0 = neutral (no style)
    @State private var variant: FillVariant = .soft
    @State private var bordered = false
    @State private var checkA = true
    @State private var checkB = false

    private let styles: [(String, BadgeStyle?)] = [
        ("Neutral", nil), ("Success", .success), ("Warning", .warning), ("Error", .error), ("Info", .info),
    ]
    private let palette: [(String, SemanticColor)] = [
        ("turquoise", .turquoise), ("orange", .orange), ("purple", .purple), ("pink", .pink), ("info", .info),
    ]

    /// `.closable(_:)` takes a non-optional closure, so the chain is built here
    /// and the modifier applied conditionally.
    private var demoTag: Tag {
        let tag = Tag(text, onRemove: removable ? { flash("Tag removed") } : nil)
            .icon(icon ? "mappin" : nil)
            .tagStyle(styles[styleIdx].1)
            .variant(variant)
            .bordered(bordered)
        return closable ? tag.closable { flash("Tag closed") } : tag
    }

    var body: some View {
        ComponentStage("Tag", inspector: [("style", styles[styleIdx].0), ("variant", "\(variant)"), ("closable", "\(closable)")]) {
            VStack(spacing: 18) {
                demoTag

                // .color(_) — the broader Ant palette
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(palette, id: \.0) { name, c in Tag(name).color(c) }
                }

                // CheckableTag
                HStack(spacing: 8) {
                    CheckableTag("Nonstop", isChecked: $checkA)
                    CheckableTag("Morning", isChecked: $checkB).icon("sunrise")
                }
            }
        } knobs: {
            TextField("Text", text: $text).textFieldStyle(.roundedBorder)
            Picker("Style", selection: $styleIdx) {
                ForEach(Array(styles.enumerated()), id: \.offset) { i, s in Text(s.0).tag(i) }
            }.pickerStyle(.segmented)
            Picker("Variant", selection: $variant) {
                Text("Soft").tag(FillVariant.soft); Text("Solid").tag(FillVariant.solid); Text("Outline").tag(FillVariant.outline)
            }.pickerStyle(.segmented)
            Toggle("Removable (init onRemove, bare glyph)", isOn: $removable)
            Toggle("Closable (kit CloseButton)", isOn: $closable)
            Toggle("Leading icon", isOn: $icon)
            Toggle("Bordered", isOn: $bordered)
        }
    }
}

struct CloseButtonDemo: View {
    @State private var sizeIdx = 2   // 0 mini, 1 small, 2 regular
    @State private var tintIdx = 0   // 0 muted default, 1 error, 2 primary
    @State private var plain = false
    @State private var chevron = false
    @State private var enabled = true
    @State private var overlay = false
    @State private var taps = 0

    private var size: ControlSize { sizeIdx == 0 ? .mini : sizeIdx == 1 ? .small : .regular }
    private var tint: SemanticColor? { tintIdx == 1 ? .error : tintIdx == 2 ? .primary : nil }

    var body: some View {
        ComponentStage("CloseButton", inspector: [
            ("controlSize", sizeIdx == 0 ? "mini" : sizeIdx == 1 ? "small" : "regular"), ("plain", "\(plain)"), ("taps", "\(taps)"),
        ]) {
            if overlay {
                // The .plain() ghost glyph over a media-like surface (photo cards, hero banners).
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.shared.background(.bgHero))
                        .frame(width: 220, height: 132)
                    CloseButton { taps += 1; flash("Close tapped") }
                        .plain()
                        .tint(.neutral)
                        .controlSize(.small)
                }
            } else {
                CloseButton { taps += 1; flash("Close tapped") }
                    .tint(tint)
                    .systemImage(chevron ? "chevron.down" : "xmark")
                    .plain(plain)
                    .controlSize(size)
                    .disabled(!enabled)
            }
        } knobs: {
            Picker("Size", selection: $sizeIdx) { Text("Mini").tag(0); Text("Small").tag(1); Text("Regular").tag(2) }.pickerStyle(.segmented)
            Picker("Tint", selection: $tintIdx) { Text("Muted").tag(0); Text("Error").tag(1); Text("Primary").tag(2) }.pickerStyle(.segmented)
            Toggle("Plain (no circle fill)", isOn: $plain)
            Toggle("Chevron glyph (sheet pull-down)", isOn: $chevron)
            Toggle("Media overlay (plain, top-trailing)", isOn: $overlay)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct HelperTextDemo: View {
    @State private var error = false
    @State private var hides = false
    @State private var links = false
    @State private var enabled = true

    var body: some View {
        ComponentStage("HelperText", inspector: [
            ("hasError", "\(error)"), ("hidesOnError", "\(hides)"), ("links", "\(links)"), ("isEnabled", "\(enabled)"),
        ]) {
            VStack(alignment: .leading, spacing: 6) {
                InputLabel("Password").required().hasError(error)
                Text("••••••••")
                    .textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Theme.shared.border(.borderPrimary)))
                HelperText(links ? "By continuing you agree to the Terms and Privacy Policy." : "Min. 8 characters, one number.")
                    .links(links ? [("Terms", { flash("Terms tapped") }), ("Privacy Policy", { flash("Privacy Policy tapped") })] : [])
                    .hasError(error)
                    .hidesOnError(hides)
                    .disabled(!enabled)
            }
        } knobs: {
            Toggle("Error (red helper)", isOn: $error)
            Toggle("Hide on error (yields to a field-error line)", isOn: $hides)
            Toggle("Inline links (tappable substrings)", isOn: $links)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}

struct DescriptionModalDemo: View {
    @State private var alignmentIdx = 0   // 0 leading, 1 center, 2 trailing
    @State private var longText = true

    private let alignments: [(String, TextAlignment)] = [
        ("Leading", .leading), ("Center", .center), ("Trailing", .trailing),
    ]
    private let short = "Delete this trip? This action can't be undone."
    private let long = "California is a state in the Western United States that lies on the Pacific Coast. With almost 40 million residents across an area of 163,696 square miles."

    var body: some View {
        ComponentStage("DescriptionModal", inspector: [
            ("textAlignment", alignments[alignmentIdx].0), ("body", longText ? "multi-line" : "short"),
        ]) {
            // A mock modal card: title + swappable description body.
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm").textStyle(.labelMd700).foregroundStyle(Theme.shared.text(.textPrimary))
                DescriptionModal(longText ? long : short)
                    .textAlignment(alignments[alignmentIdx].1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.shared.background(.bgWhite)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.shared.border(.borderPrimary)))
        } knobs: {
            Picker("Alignment", selection: $alignmentIdx) {
                Text("Leading").tag(0); Text("Center").tag(1); Text("Trailing").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Long multi-line body", isOn: $longText)
        }
    }
}

struct SurfaceViewDemo: View {
    @State private var levelIdx = 0
    @State private var elevationIdx = 0   // 0 none, 1 soft, 2 elevated
    @State private var fieldRadius = false
    @State private var smallPadding = false
    @State private var nested = false

    private let levels: [(String, SurfaceLevel)] = [
        ("Primary", .primary), ("Secondary", .secondary), ("Tertiary", .tertiary), ("Transparent", .transparent),
    ]
    private var elevation: CardElevation { elevationIdx == 1 ? .soft : elevationIdx == 2 ? .elevated : .none }

    var body: some View {
        ComponentStage("Surface", inspector: [
            ("level", levels[levelIdx].0), ("elevation", elevationIdx == 1 ? "soft" : elevationIdx == 2 ? "elevated" : "none"),
        ]) {
            if nested {
                // Hierarchy from nesting: primary > secondary > tertiary.
                SurfaceView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Primary").textStyle(.labelMd600).foregroundStyle(Theme.shared.text(.textPrimary))
                        SurfaceView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Secondary").textStyle(.labelMd600).foregroundStyle(Theme.shared.text(.textPrimary))
                                SurfaceView {
                                    Text("Tertiary").textStyle(.labelSm600)
                                        .foregroundStyle(Theme.shared.text(.textSecondary))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .level(.tertiary)
                            }
                        }
                        .level(.secondary)
                    }
                }
                .elevation(elevation)
            } else {
                SurfaceView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Booking summary").textStyle(.labelMd600).foregroundStyle(Theme.shared.text(.textPrimary))
                        Text("2 guests · 3 nights").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .level(levels[levelIdx].1)
                .elevation(elevation)
                .radius(fieldRadius ? .field : .box)
                .contentPadding(smallPadding ? .sm : .md)
            }
        } knobs: {
            Picker("Level", selection: $levelIdx) {
                ForEach(Array(levels.enumerated()), id: \.offset) { i, l in Text(l.0).tag(i) }
            }.pickerStyle(.segmented).disabled(nested)
            Picker("Elevation", selection: $elevationIdx) { Text("None").tag(0); Text("Soft").tag(1); Text("Elevated").tag(2) }.pickerStyle(.segmented)
            Toggle("Field radius (default .box)", isOn: $fieldRadius)
            Toggle("Small padding (default .md)", isOn: $smallPadding)
            Toggle("Nested (primary > secondary > tertiary)", isOn: $nested)
        }
    }
}

struct SkeletonGroupDemo: View {
    @State private var loading = true
    @State private var placeholderOnly = false

    var body: some View {
        ComponentStage("SkeletonGroup", inspector: [("isLoading", "\(loading)"), ("skeletonOnly", "\(placeholderOnly)")]) {
            if placeholderOnly {
                // Pure placeholder — the whole group collapses once loading ends.
                VStack(alignment: .leading, spacing: 14) {
                    SkeletonGroup {
                        HStack(spacing: 10) {
                            Skeleton(.circle).size(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 6) {
                                Skeleton(.capsule).size(width: 150, height: 12)
                                Skeleton(.capsule).size(width: 100, height: 12)
                            }
                        }
                    }
                    .skeletonOnly()
                    .loading(loading)
                    Text("Content below moves up when the placeholder collapses.")
                        .textStyle(.bodySm400)
                        .foregroundStyle(Theme.shared.text(.textSecondary))
                }
            } else {
                SkeletonGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weekend in Lisbon").textStyle(.headingSm)
                            .foregroundStyle(Theme.shared.text(.textPrimary))
                            .skeleton()
                        Text("Three days of tiles, trams and pastel facades by the river.")
                            .textStyle(.bodyBase400)
                            .foregroundStyle(Theme.shared.text(.textSecondary))
                            .skeleton()
                        Text("Updated today").textStyle(.labelSm600)
                            .foregroundStyle(Theme.shared.text(.textTertiary))
                            .skeleton(shape: .capsule)
                    }
                }
                .loading(loading)
            }
        } knobs: {
            Toggle("Loading", isOn: $loading)
            Toggle("Skeleton-only (collapses when loaded)", isOn: $placeholderOnly)
            Text("One .loading() flag drives every zero-argument .skeleton() below the group.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct WatermarkDemo: View {
    @Environment(\.theme) private var theme
    @State private var text = "SPECIMEN"
    @State private var fontSize = 16.0
    @State private var angle = -22.0

    var body: some View {
        ComponentStage("Watermark", inspector: [("text", text)]) {
            VStack(spacing: 8) {
                Text("Boarding pass").textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                Text("Istanbul → Antalya").textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
                Text("Seat 14A · Gate 22").textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: 20))
            .watermark(text.isEmpty ? " " : text, rotation: .degrees(angle), fontSize: fontSize)
        } knobs: {
            TextField("Text", text: $text).textFieldStyle(.roundedBorder)
            HStack { Text("Size"); SwiftUI.Slider(value: $fontSize, in: 10...28) }
            HStack { Text("Angle"); SwiftUI.Slider(value: $angle, in: -45...45) }
        }
    }
}
