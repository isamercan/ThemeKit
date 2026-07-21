//
//  UtilityDemos.swift
//  Demo
//
//  Interactive knob demos for the remaining utility/display components that used
//  to ship as frozen `.static` previews. Every public prop/modifier is now an
//  editable knob — so every entry in the gallery is tweakable.
//

import SwiftUI
import ThemeKit

// MARK: - Atoms

struct AnimatedImageDemo: View {
    @State private var size = 180.0
    @State private var cornerRadius = 16.0
    @State private var fill = false

    private let url = URL(string: "https://upload.wikimedia.org/wikipedia/commons/d/d3/Newtons_cradle_animation_book_2.gif")

    var body: some View {
        ComponentStage("AnimatedImage", inspector: [
            ("size", "\(Int(size))pt"), ("mode", fill ? "fill" : "fit"),
        ]) {
            AnimatedImage(url)
                .contentMode(fill ? .fill : .fit)
                .cornerRadius(cornerRadius)
                .frame(width: size, height: size)
                .clipped()
        } knobs: {
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 80...260, step: 4); Text("\(Int(size))").font(.caption.monospacedDigit()) }
            HStack { Text("Corner radius"); SwiftUI.Slider(value: $cornerRadius, in: 0...60, step: 2); Text("\(Int(cornerRadius))").font(.caption.monospacedDigit()) }
            Toggle("Fill (instead of fit)", isOn: $fill)
        }
    }
}

struct KbdDemo: View {
    @State private var text = "⌘"
    @State private var showsChord = true

    var body: some View {
        ComponentStage("Kbd", inspector: [("text", text)]) {
            HStack(spacing: 6) {
                Kbd(text)
                if showsChord {
                    Kbd("K")
                    Text("then").font(.caption).foregroundStyle(.secondary)
                    Kbd("esc")
                }
            }
        } knobs: {
            TextField("Key label", text: $text).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            Toggle("Show chord (⌘ K … esc)", isOn: $showsChord)
        }
    }
}

struct InlineTextDemo: View {
    @State private var text = "By continuing you accept the Terms and the Privacy Policy."
    @State private var styleIdx = 0
    @State private var tinted = false

    private let styles: [(String, TextStyle)] = [
        ("Body", .bodyBase400), ("Small", .bodySm400), ("Label", .labelBase600),
    ]

    private var inline: InlineText {
        var t = InlineText(text, links: [("Terms", { flash("Terms tapped") }), ("Privacy Policy", { flash("Privacy tapped") })])
            .inlineStyle(styles[styleIdx].1)
        if tinted { t = t.accent(.purple) }
        return t
    }

    var body: some View {
        ComponentStage("InlineText", inspector: [("style", styles[styleIdx].0)]) {
            inline.frame(maxWidth: 340)
        } knobs: {
            TextField("Text (keep the link words)", text: $text).textFieldStyle(.roundedBorder)
            Picker("Style", selection: $styleIdx) {
                ForEach(styles.indices, id: \.self) { Text(styles[$0].0).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Custom base color (purple)", isOn: $tinted)
        }
    }
}

struct JoinDemo: View {
    @State private var vertical = false

    private let labels = ["Day", "Week", "Month"]

    var body: some View {
        ComponentStage("Join", inspector: [("axis", vertical ? "vertical" : "horizontal")]) {
            Join(vertical ? .vertical : .horizontal) {
                ForEach(labels, id: \.self) { label in
                    Text(label).textStyle(.labelBase600).padding(.horizontal, 14).frame(height: 40).frame(minWidth: 72)
                }
            }
        } knobs: {
            Toggle("Vertical axis", isOn: $vertical)
        }
    }
}

struct MaskDemo: View {
    @State private var shape: MaskShape = .squircle
    @State private var size = 96.0

    var body: some View {
        ComponentStage("Mask", inspector: [("shape", "\(shape)"), ("size", "\(Int(size))pt")]) {
            Rectangle().fill(LinearGradient(colors: [.blue, .blue.opacity(0.55)], startPoint: .top, endPoint: .bottom)).frame(width: size, height: size).themeMask(shape)
        } knobs: {
            Picker("Shape", selection: $shape) {
                ForEach(MaskShape.allCases, id: \.self) { Text("\($0)".capitalized).tag($0) }
            }.pickerStyle(.segmented)
            HStack { Text("Size"); SwiftUI.Slider(value: $size, in: 48...160, step: 4); Text("\(Int(size))").font(.caption.monospacedDigit()) }
        }
    }
}

struct TextRotateDemo: View {
    @State private var interval = 2.0
    @State private var wordsText = "faster., themed., accessible."

    private var words: [String] {
        let parsed = wordsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parsed.isEmpty ? ["…"] : parsed
    }

    var body: some View {
        ComponentStage("TextRotate", inspector: [("words", "\(words.count)"), ("interval", String(format: "%.1fs", interval))]) {
            HStack(spacing: 4) {
                Text("Build").textStyle(.headingSm)
                TextRotate(words, interval: interval).id("\(interval)-\(wordsText)")   // restart cycle on edit
            }
        } knobs: {
            TextField("Words (comma-separated)", text: $wordsText).textFieldStyle(.roundedBorder)
            HStack { Text("Interval"); SwiftUI.Slider(value: $interval, in: 0.5...4, step: 0.5); Text(String(format: "%.1fs", interval)).font(.caption.monospacedDigit()) }
        }
    }
}

struct GaugeDemo: View {
    @State private var value = 0.72
    @State private var style: GaugeView.Style = .circular
    @State private var showsValue = true
    @State private var showsLabel = true

    var body: some View {
        ComponentStage("Gauge", inspector: [("value", String(format: "%.0f%%", value * 100)), ("style", "\(style)")]) {
            GaugeView(value: value, label: showsLabel ? "CPU" : nil)
                .gaugeStyle(style)
                .showsValue(showsValue)
                .frame(width: style == .linear ? 160 : 90)
        } knobs: {
            HStack { Text("Value"); SwiftUI.Slider(value: $value); Text(String(format: "%.0f%%", value * 100)).font(.caption.monospacedDigit()) }
            Picker("Style", selection: $style) {
                Text("Circular").tag(GaugeView.Style.circular); Text("Linear").tag(GaugeView.Style.linear)
            }.pickerStyle(.segmented)
            Toggle("Shows value", isOn: $showsValue)
            Toggle("Shows label", isOn: $showsLabel)
        }
    }
}

struct ShareButtonDemo: View {
    @State private var title = "Share"
    @State private var item = "https://github.com/isamercan/ThemeKit"

    var body: some View {
        ComponentStage("ShareButton", inspector: [("title", title)]) {
            ShareButton(title, item: item)
        } knobs: {
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Shared item", text: $item).textFieldStyle(.roundedBorder).autocorrectionDisabled()
        }
    }
}

// MARK: - Molecules

struct ColorFieldDemo: View {
    @State private var color: Color = .blue
    @State private var label = "Brand color"
    @State private var supportsOpacity = false

    var body: some View {
        ComponentStage("ColorField", inspector: [("opacity", "\(supportsOpacity)")]) {
            ColorField(label, selection: $color).supportsOpacity(supportsOpacity).frame(maxWidth: 340)
        } knobs: {
            TextField("Label", text: $label).textFieldStyle(.roundedBorder)
            Toggle("Supports opacity", isOn: $supportsOpacity)
        }
    }
}

struct GuestSelectorDemo: View {
    @State private var guests = GuestSelection(rooms: 1, adults: 2, children: 1)
    @State private var showsRooms = true
    @State private var showsInfants = false
    @State private var maxTotal = 9.0
    @State private var maxAdults = 9.0
    @State private var maxChildren = 6.0

    private var selector: GuestSelector {
        GuestSelector(selection: $guests)
            .showsRooms(showsRooms)
            .showsInfants(showsInfants)
            .maxTotal(Int(maxTotal))
            .adultRange(1...Int(maxAdults))
            .childRange(0...Int(maxChildren))
            .onChange { _ in flash("Guests updated") }
    }

    var body: some View {
        ComponentStage("GuestSelector", inspector: [("summary", guests.summary), ("total", "\(guests.guestCount)")]) {
            VStack(alignment: .leading, spacing: 12) {
                Text(guests.summary).textStyle(.bodyBase400)
                selector
            }.frame(maxWidth: 340)
        } knobs: {
            Toggle("Shows rooms row", isOn: $showsRooms)
            Toggle("Shows infants row", isOn: $showsInfants)
            HStack { Text("Max total"); SwiftUI.Slider(value: $maxTotal, in: 2...16, step: 1); Text("\(Int(maxTotal))").font(.caption.monospacedDigit()) }
            HStack { Text("Max adults"); SwiftUI.Slider(value: $maxAdults, in: 1...12, step: 1); Text("\(Int(maxAdults))").font(.caption.monospacedDigit()) }
            HStack { Text("Max children"); SwiftUI.Slider(value: $maxChildren, in: 0...8, step: 1); Text("\(Int(maxChildren))").font(.caption.monospacedDigit()) }
        }
    }
}

// MARK: - Organisms

struct FooterDemo: View {
    @State private var columnCount = 3.0
    @State private var showNote = true

    private let allColumns: [Footer.Column] = [
        .init("Company", items: [.init("About"), .init("Careers")]),
        .init("Support", items: [.init("Help"), .init("Contact")]),
        .init("Legal", items: [.init("Terms"), .init("Privacy")]),
    ]

    var body: some View {
        ComponentStage("Footer", inspector: [("columns", "\(Int(columnCount))"), ("note", "\(showNote)")]) {
            Footer(columns: Array(allColumns.prefix(Int(columnCount))), note: showNote ? "© 2026 ThemeKit." : nil)
        } knobs: {
            HStack { Text("Columns"); SwiftUI.Slider(value: $columnCount, in: 1...3, step: 1); Text("\(Int(columnCount))").font(.caption.monospacedDigit()) }
            Toggle("Copyright note", isOn: $showNote)
        }
    }
}

struct DiffDemo: View {
    @State private var aspect = 1.6

    var body: some View {
        ComponentStage("Diff", inspector: [("aspect", String(format: "%.2f", aspect))]) {
            Diff {
                Theme.shared.background(.bgHero).overlay(Text("BEFORE").foregroundStyle(.white).font(.headline))
            } after: {
                Theme.shared.background(.bgTertiary).overlay(Text("AFTER").foregroundStyle(.white).font(.headline))
            }
            .aspect(aspect)
            .frame(maxWidth: 340)
        } knobs: {
            HStack { Text("Aspect ratio"); SwiftUI.Slider(value: $aspect, in: 0.6...2.5, step: 0.1); Text(String(format: "%.1f", aspect)).font(.caption.monospacedDigit()) }
        }
    }
}

struct KeyValueTableDemo: View {
    @State private var showTitle = true
    @State private var bordered = true
    @State private var showDiscount = true

    private var rows: [KeyValueTable.Row] {
        var r: [KeyValueTable.Row] = [.init("Status", value: "Active", style: .success)]
        if showDiscount { r.append(.init("Old price", value: "$5,000", style: .strikethrough)) }
        r.append(.init("Taxes & fees", value: "$250", style: .muted))
        r.append(.init("Total", value: "$4,250"))
        return r
    }

    private var table: KeyValueTable {
        KeyValueTable(rows: rows).title(showTitle ? "Reservation summary" : nil).bordered(bordered)
    }

    var body: some View {
        ComponentStage("KeyValueTable", inspector: [("rows", "\(rows.count)"), ("bordered", "\(bordered)")]) {
            table.frame(maxWidth: 360)
        } knobs: {
            Toggle("Title", isOn: $showTitle)
            Toggle("Bordered", isOn: $bordered)
            Toggle("Strikethrough discount row", isOn: $showDiscount)
        }
    }
}

struct ConfettiDemo: View {
    @State private var burst = 0
    @State private var count = 40.0
    @State private var brandOnly = false

    var body: some View {
        ComponentStage("Confetti", inspector: [("pieces", "\(Int(count))"), ("bursts", "\(burst)")]) {
            ZStack {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(Theme.shared.foreground(.fgHero))
                    Text("Thanks for your feedback!").textStyle(.labelMd700)
                    PrimaryButton("Celebrate 🎉") { burst += 1 }.size(.small)
                }
                Confetti()
                    .pieceCount(Int(count))
                    .colors(brandOnly ? [.primary, .purple] : nil)
                    .id("\(burst)-\(Int(count))-\(brandOnly)")
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
        } knobs: {
            HStack { Text("Pieces"); SwiftUI.Slider(value: $count, in: 10...120, step: 5); Text("\(Int(count))").font(.caption.monospacedDigit()) }
            Toggle("Brand colors only", isOn: $brandOnly)
            Button { burst += 1 } label: { Label("Replay burst", systemImage: "arrow.clockwise") }.buttonStyle(.bordered)
        }
    }
}
