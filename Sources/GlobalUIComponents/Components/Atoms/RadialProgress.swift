//
//  RadialProgress.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. Circular determinate progress with status colors and an optional
//  dashboard (gapped) variant. (Ant Progress type="circle"/"dashboard".)
//

import SwiftUI

public struct RadialProgress: View {
    private let value: Double
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let showLabel: Bool
    private let status: ProgressStatus
    private let dashboard: Bool
    private let tint: Color?

    public init(
        value: Double,
        size: CGFloat = 64,
        lineWidth: CGFloat = 6,
        showLabel: Bool = true,
        status: ProgressStatus = .normal,
        dashboard: Bool = false,
        tint: Color? = nil
    ) {
        self.value = min(max(value, 0), 1)
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.status = status
        self.dashboard = dashboard
        self.tint = tint
    }

    private var gap: CGFloat { dashboard ? 0.25 : 0 }            // fraction left open
    private var rotation: Double { dashboard ? 90 + Double(gap) * 180 : -90 }
    private var color: Color { tint ?? status.semantic.solid }

    public var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1 - gap)
                .stroke(Theme.shared.border(.borderPrimary), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
            Circle()
                .trim(from: 0, to: value * (1 - gap))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
                .animation(Motion.base.animation, value: value)
            if showLabel {
                if status == .success && value >= 1 {
                    Image(systemName: "checkmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(status.semantic.accent)
                } else if status == .exception {
                    Image(systemName: "xmark").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(status.semantic.accent)
                } else {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: size * 0.26, weight: .semibold))
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                }
            }
        }
        .frame(width: size, height: size)
        // The ring fill is purely visual; speak the percentage to VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(globalUIComponents: "Progress")))
        .accessibilityValue(Text("\(Int(value * 100))%"))
        .accessibilityAddTraits(status == .active ? .updatesFrequently : [])
    }
}

#Preview {
    HStack(spacing: 20) {
        RadialProgress(value: 0.25)
        RadialProgress(value: 0.7, size: 80, lineWidth: 8, dashboard: true)
        RadialProgress(value: 1.0, status: .success)
        RadialProgress(value: 0.4, status: .exception)
    }
    .padding()
}
