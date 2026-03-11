/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct StorySegment: Identifiable, Codable {
    let id: Int
    let text: String
    var audioData: Data? = nil
    var generatedFromRouteVersion: Int? = nil
    var location: Coordinate? = nil
    var referencedPOIs: [String] = []

    enum CodingKeys: String, CodingKey {
        case id = "index"
        case text
    }

    init(
        id: Int,
        text: String,
        audioData: Data? = nil,
        generatedFromRouteVersion: Int? = nil,
        location: Coordinate? = nil,
        referencedPOIs: [String] = []
    ) {
        self.id = id
        self.text = text
        self.audioData = audioData
        self.generatedFromRouteVersion = generatedFromRouteVersion
        self.location = location
        self.referencedPOIs = referencedPOIs
    }
}

struct NearbyPOI: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let address: String
    let coordinate: Coordinate
    let types: [String]
    let rating: Double?
    let userRatingsTotal: Int?
}

struct LiveJourneyContext: Codable {
    var currentLocation: Coordinate?
    var snappedLocation: Coordinate?
    var headingDegrees: Double?
    var speedMps: Double?
    var distanceFromRouteMeters: Double?
    var isOffRoute: Bool
    var nearbyPOIs: [NearbyPOI]
    var routeSummary: String

    static let empty = LiveJourneyContext(
        currentLocation: nil,
        snappedLocation: nil,
        headingDegrees: nil,
        speedMps: nil,
        distanceFromRouteMeters: nil,
        isOffRoute: false,
        nearbyPOIs: [],
        routeSummary: "No live route context yet."
    )
}

struct NarrativeState: Codable {
    var rollingSummary: String
    var openThreads: [String]
    var referencedPOIIDs: [String]
    var lastRouteVersion: Int

    static let empty = NarrativeState(
        rollingSummary: "",
        openThreads: [],
        referencedPOIIDs: [],
        lastRouteVersion: 1
    )
}

struct ContextualSegmentEnvelope: Codable {
    let narration: String
    let rollingSummary: String
    let openThreads: [String]
    let referencedPOIIDs: [String]
}

struct AudioStory {
    var totalSegmentsEstimate: Int
    var outline: [String]
    var segments: [StorySegment]
    var isContinuous: Bool
    var narrativeState: NarrativeState

    init(
        totalSegmentsEstimate: Int,
        outline: [String],
        segments: [StorySegment] = [],
        isContinuous: Bool = false,
        narrativeState: NarrativeState = .empty
    ) {
        self.totalSegmentsEstimate = totalSegmentsEstimate
        self.outline = outline
        self.segments = segments
        self.isContinuous = isContinuous
        self.narrativeState = narrativeState
    }
}
