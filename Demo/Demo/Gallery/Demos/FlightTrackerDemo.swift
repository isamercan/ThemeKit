// REGISTER: FlightTracker · deep-link "FlightTracker" · organism · isNew
//
//  FlightTrackerDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel `FlightTracker` organism (F3.3) —
//  status, gate/terminal/belt facts, en-route progress, estimates, timeline,
//  accent and footer are all live knobs. Toggling the status while VoiceOver
//  runs demonstrates the `AccessibilityNotification.Announcement` live-region
//  pattern (the tracker announces the change itself).
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct FlightTrackerDemo: View {
    @State private var status: FlightStatus = .delayed
    @State private var showFacts = true
    @State private var showEstimates = true
    @State private var showProgress = true
    @State private var progress = 0.62
    @State private var showTimeline = true
    @State private var showUpdated = true
    @State private var showDetails = true
    @State private var showFooter = false
    @State private var accented = false
    @State private var readOnly = false

    private var leg: FlightLeg {
        let departure = Date().addingTimeInterval(-90 * 60)
        return FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                         departure: departure, arrival: departure.addingTimeInterval(4 * 3600))
    }

    private var info: FlightStatusInfo {
        FlightStatusInfo(
            leg: leg,
            status: status,
            gate: showFacts ? "B12" : nil,
            terminal: showFacts ? "1" : nil,
            checkInDesk: showFacts ? "34–38" : nil,
            baggageBelt: showFacts && status == .arrived ? "7" : nil,
            estimatedDeparture: showEstimates ? leg.departure.addingTimeInterval(35 * 60) : nil,
            estimatedArrival: showEstimates ? leg.arrival.addingTimeInterval(35 * 60) : nil,
            aircraft: showDetails ? "A321neo" : nil
        )
    }

    private var tracker: some View {
        var t = FlightTracker(info)
            .progress(showProgress ? progress : nil)
            .updated(showUpdated ? Date().addingTimeInterval(-120) : nil)
            .showsTimeline(showTimeline)
            .accent(accented ? .accent : nil)
        if showDetails {
            t = t.details([("Meal", "Included")])
        }
        if showFooter {
            t = t.footer {
                ThemeButton("Share status") {}
                    .variant(.ghost)
                    .size(.small)
            }
        }
        return t.readOnly(readOnly)
    }

    var body: some View {
        ComponentStage("FlightTracker", inspector: [
            ("status", status.rawValue),
            ("progress", showProgress ? String(format: "%.0f%%", progress * 100) : "hidden"),
            ("facts", showFacts ? "gate/terminal/desk" : "none"),
        ]) {
            tracker
        } knobs: {
            Picker("Status", selection: $status) {
                ForEach(FlightStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Facts (gate B12 · terminal 1 · desk)", isOn: $showFacts)
            Toggle("Estimates (+35m vs schedule)", isOn: $showEstimates)
            Toggle("Progress track", isOn: $showProgress)
            if showProgress {
                Slider(value: $progress, in: 0...1) { Text("Progress") }
            }
            Toggle("Phase timeline", isOn: $showTimeline)
            Toggle("Updated caption (2 min ago)", isOn: $showUpdated)
            Toggle("Details (aircraft · meal)", isOn: $showDetails)
            Toggle("Footer slot (share action)", isOn: $showFooter)
            Toggle("Accent override (.accent)", isOn: $accented)
            Toggle("Read-only", isOn: $readOnly)
        }
    }
}
