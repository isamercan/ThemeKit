// REGISTER: CheckInFlow · deep-link "CheckInFlow" · organism · isNew
//
//  CheckInFlowDemo.swift
//  Demo
//
//  Interactive demo for the ThemeKitTravel `CheckInFlow` organism (F3.4) — a
//  realistic check-in journey (Passengers → Seats → Boarding pass) where the
//  scaffold owns only the progression chrome: pages compose ThemeKit's neutral
//  `SeatMap` and `BoardingPass`. Stepper visibility, seat gating, accent and
//  read-only are live knobs.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct CheckInFlowDemo: View {
    @State private var step = 0
    @State private var seats: Set<String> = []
    @State private var completed = false
    @State private var showStepper = true
    @State private var gateOnSeat = true
    @State private var accented = false
    @State private var readOnly = false

    private let steps: [Steps.Step] = [
        .init("Passengers", state: .active),
        .init("Seats", state: .todo),
        .init("Boarding pass", state: .todo),
    ]

    private var flow: some View {
        CheckInFlow(steps: steps, selection: $step) { index in
            switch index {
            case 0: passengersPage
            case 1: seatsPage
            default: boardingPassPage
            }
        }
        .canAdvance { index in
            guard gateOnSeat, index == 1 else { return true }
            return !seats.isEmpty
        }
        .onComplete { completed = true }
        .showsStepper(showStepper)
        .accent(accented ? .success : nil)
        .readOnly(readOnly)
        .frame(height: 520)
    }

    // MARK: Pages — the app's content, not the scaffold's

    private var passengersPage: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text("Review passengers").textStyle(.headingSm)
            ListRow("Alex Morgan") {}
                .subtitle("Adult · Passport verified")
            ListRow("Jamie Doe") {}
                .subtitle("Adult · Passport verified")
        }
        .padding(Theme.SpacingKey.md.value)
    }

    private var seatsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                Text("Choose a seat").textStyle(.headingSm)
                SeatMap(columns: "ABC DEF", rows: Array(1...5), selection: $seats)
            }
            .padding(Theme.SpacingKey.md.value)
        }
    }

    private var boardingPassPage: some View {
        ScrollView {
            BoardingPass(passenger: "Alex Morgan", from: "SFO", to: "JFK")
                .qr("DEMO-BOARDING-PASS")
                .padding(Theme.SpacingKey.md.value)
        }
    }

    var body: some View {
        ComponentStage("CheckInFlow", inspector: [
            ("step", "\(step + 1) of \(steps.count)"),
            ("seats", seats.isEmpty ? "none" : seats.sorted().joined(separator: ", ")),
            ("completed", completed ? "yes" : "no"),
        ]) {
            flow
        } knobs: {
            Toggle("Steps header", isOn: $showStepper)
            Toggle("Gate Continue on seat choice", isOn: $gateOnSeat)
            Toggle("Success accent", isOn: $accented)
            Toggle("Read-only", isOn: $readOnly)
            Button("Reset journey") {
                step = 0
                seats = []
                completed = false
            }
        }
    }
}
