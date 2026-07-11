//
//  FeatureModels.swift
//  ThemeKit
//
//  The brand-neutral "feature line" vocabulary — a labelled item with an
//  included / excluded / info status and an SF Symbol. Generic on purpose: it
//  backs both fare-perk lists (``FareFeatureRow``, the flight edition's
//  `FareFamilyCard`) and non-flight amenity lists (``RoomCard``'s feature block),
//  so it stays in the neutral catalog even though the flight family moved to the
//  `ThemeKitTravel` edition.
//

import Foundation

/// Whether a fare / amenity feature is granted, denied, or neutral info.
public enum FareFeatureStatus: Sendable { case included, excluded, info }

/// A single feature / rule line (fare perk, room amenity, plan capability…).
public struct FareFeature: Identifiable, Sendable {
    public var id: String { "\(systemImage):\(text)" }
    public let text: String
    public let systemImage: String
    public let detail: String?
    public let status: FareFeatureStatus
    public init(_ text: String, systemImage: String, detail: String? = nil, status: FareFeatureStatus = .info) {
        self.text = text
        self.systemImage = systemImage
        self.detail = detail
        self.status = status
    }
}
