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
    @State private var background: AvatarBackground = .blue
    @State private var initials = false
    @State private var square = false
    @State private var group = false
    @State private var numeric = 0.0   // 0 = use enum tier; >0 = custom point size
    @State private var presenceIdx = 1   // 0 = none

    private let presences: [(String, StatusKind?)] = [
        ("None", nil), ("Online", .online), ("Away", .away), ("Busy", .busy), ("Offline", .offline),
    ]
    private var presence: StatusKind? { presences[presenceIdx].1 }

    var body: some View {
        ComponentStage("Avatar", inspector: [
            ("size", numeric > 0 ? "\(Int(numeric))pt" : "\(Int(size.rawValue))"), ("presence", presences[presenceIdx].0),
        ]) {
            if group {
                AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .icon("person.fill"), .initials("GH"), .initials("IJ")], size: size, max: 4)
            } else if numeric > 0 {
                Avatar(initials ? .initials("AB") : .icon("person.fill"), dimension: numeric, background: background, shape: square ? .square : .circle, presence: presence, presencePulse: presence == .online)
            } else {
                Avatar(initials ? .initials("AB") : .icon("person.fill"), size: size, background: background, shape: square ? .square : .circle, presence: presence, presencePulse: presence == .online)
            }
        } knobs: {
            Picker("Presence", selection: $presenceIdx) {
                ForEach(Array(presences.enumerated()), id: \.offset) { i, p in Text(p.0).tag(i) }
            }.pickerStyle(.segmented).disabled(group)
            Picker("Size", selection: $size) {
                ForEach(AvatarSize.allCases, id: \.self) { Text("\(Int($0.rawValue))").tag($0) }
            }.pickerStyle(.segmented).disabled(numeric > 0)
            HStack { Text("Numeric"); SwiftUI.Slider(value: $numeric, in: 0...96, step: 4) }
            Picker("Background", selection: $background) {
                Text("Blue").tag(AvatarBackground.blue); Text("White").tag(AvatarBackground.white); Text("Dark").tag(AvatarBackground.dark)
            }.pickerStyle(.segmented)
            Toggle("Square shape", isOn: $square)
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
                    Ribbon("New", color: .error) {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.shared.background(.bgElevatorTertiary)).frame(width: 96, height: 72)
                    }
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
            Badge(text, style: style, variant: variant, size: size,
                  leadingSystemImage: icon ? "star.fill" : nil,
                  action: tappable ? { tapped += 1; flash("Badge tıklandı") } : nil)
                .badgeShape(pill ? .pill : .rounded)
                .badgeColor(gradient ? Theme.shared.foreground(.fgSecondary) : nil)
                .gradient(gradient ? [SemanticColor.primary.base, SemanticColor.purple.base] : nil)
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
    @State private var large = false
    @State private var enabled = true
    @State private var rating = false
    @State private var exists = true
    @State private var expands = false

    var body: some View {
        ComponentStage("Chip", inspector: [
            ("isSelected", "\(selected)"), ("isExist", "\(exists)"), ("isEnabled", "\(enabled)"),
        ]) {
            Chip(exists ? "Recommended" : "Sold out", isSelected: $selected, size: large ? .large : .small,
                 selectionStyle: solid ? .solid : .tonal,
                 rating: rating ? 4.6 : nil, isExist: exists, expandsHorizontally: expands)
                    .disabled(!enabled)
        } knobs: {
            Toggle("Selected", isOn: $selected)
            Toggle("Embedded rating", isOn: $rating)
            Toggle("isExist (strike-through when off)", isOn: $exists)
            Toggle("Expands horizontally", isOn: $expands)
            Toggle("Solid style", isOn: $solid)
            Toggle("Large", isOn: $large)
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
                ProgressBar(value: value, showPercentage: true, status: status)
                    .gradient(gradient && !custom)
                    .steps(segmented ? 6 : nil)
                    .colors(fill: custom ? SemanticColor.purple.base : nil,
                            track: custom ? SemanticColor.purple.base.opacity(0.15) : nil)
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
    @State private var reviewLink = true
    @State private var taps = 0

    private var layout: RatingLayout { layoutIdx == 1 ? .numberRate : layoutIdx == 2 ? .rateNumberText : .stars }

    var body: some View {
        ComponentStage("Rating", inspector: [("value", String(format: "%.1f", value)), ("layout", "\(layout)"), ("reviewTaps", "\(taps)")]) {
            Rating(value: value, layout: layout,
                   allowHalf: allowHalf,
                   countLabel: "1.284 yorum",
                   onRate: (interactive && layoutIdx == 0) ? { value = $0; flash("Puan: \(String(format: "%.1f", $0))") } : nil,
                   onReviewTap: reviewLink ? { taps += 1; flash("Yorumlara dokunuldu") } : nil)
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value, in: 0...5, step: 0.1) }
            Picker("Layout", selection: $layoutIdx) { Text("Stars").tag(0); Text("Number").tag(1); Text("Number+text").tag(2) }.pickerStyle(.segmented)
            Text("Stars: fill/half-tap. Number: value + star. Number+text: score chip + sentiment word.").font(.caption).foregroundStyle(.secondary)
            Toggle("Interactive (tap to rate, stars)", isOn: $interactive)
            Toggle("Allow half", isOn: $allowHalf)
            Toggle("Tappable review count", isOn: $reviewLink)
        }
    }
}

struct SpinnerDemo: View {
    @State private var size = 24.0
    @State private var width = 3.0

    var body: some View {
        ComponentStage("Spinner", inspector: [("size", "\(Int(size))"), ("lineWidth", "\(Int(width))")]) {
            Spinner(size: size, lineWidth: width)
        } knobs: {
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 12...64) }
            HStack { Text("Line"); SwiftUI.Slider(value: $width, in: 1...8) }
        }
    }
}

struct TagDemo: View {
    @State private var text = "İstanbul"
    @State private var removable = true
    @State private var icon = false
    @State private var styleIdx = 0   // 0 = neutral (no style)
    @State private var variant: FillVariant = .soft

    private let styles: [(String, BadgeStyle?)] = [
        ("Neutral", nil), ("Success", .success), ("Warning", .warning), ("Error", .error), ("Info", .info),
    ]

    var body: some View {
        ComponentStage("Tag", inspector: [("style", styles[styleIdx].0), ("variant", "\(variant)")]) {
            Tag(text, leadingSystemImage: icon ? "mappin" : nil,
                style: styles[styleIdx].1, variant: variant,
                onRemove: removable ? { flash("Tag silindi") } : nil)
        } knobs: {
            TextField("Text", text: $text).textFieldStyle(.roundedBorder)
            Picker("Style", selection: $styleIdx) {
                ForEach(Array(styles.enumerated()), id: \.offset) { i, s in Text(s.0).tag(i) }
            }.pickerStyle(.segmented)
            Picker("Variant", selection: $variant) {
                Text("Soft").tag(FillVariant.soft); Text("Solid").tag(FillVariant.solid); Text("Outline").tag(FillVariant.outline)
            }.pickerStyle(.segmented)
            Toggle("Removable", isOn: $removable)
            Toggle("Leading icon", isOn: $icon)
        }
    }
}
