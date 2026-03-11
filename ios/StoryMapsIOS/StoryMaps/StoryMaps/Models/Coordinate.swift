/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import CoreLocation

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(clLocation: CLLocationCoordinate2D) {
        self.latitude = clLocation.latitude
        self.longitude = clLocation.longitude
    }
    
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: Coordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    static func nearestPoint(
        to target: Coordinate,
        on polyline: [Coordinate]
    ) -> (point: Coordinate, distanceMeters: CLLocationDistance)? {
        guard !polyline.isEmpty else { return nil }
        guard polyline.count > 1 else {
            return (polyline[0], polyline[0].distance(to: target))
        }

        var bestPoint = polyline[0]
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude

        for index in 0..<(polyline.count - 1) {
            let projected = project(point: target, ontoSegmentStart: polyline[index], segmentEnd: polyline[index + 1])
            let distance = projected.distance(to: target)
            if distance < bestDistance {
                bestDistance = distance
                bestPoint = projected
            }
        }

        return (bestPoint, bestDistance)
    }

    private static func project(
        point: Coordinate,
        ontoSegmentStart start: Coordinate,
        segmentEnd end: Coordinate
    ) -> Coordinate {
        let metersPerDegreeLat = 111_320.0
        let avgLatRadians = ((start.latitude + end.latitude) / 2.0) * .pi / 180.0
        let metersPerDegreeLon = max(1.0, cos(avgLatRadians) * metersPerDegreeLat)

        let ax = start.longitude * metersPerDegreeLon
        let ay = start.latitude * metersPerDegreeLat
        let bx = end.longitude * metersPerDegreeLon
        let by = end.latitude * metersPerDegreeLat
        let px = point.longitude * metersPerDegreeLon
        let py = point.latitude * metersPerDegreeLat

        let abx = bx - ax
        let aby = by - ay
        let abLengthSquared = (abx * abx) + (aby * aby)

        guard abLengthSquared > 0 else {
            return start
        }

        let apx = px - ax
        let apy = py - ay
        let t = max(0.0, min(1.0, ((apx * abx) + (apy * aby)) / abLengthSquared))

        let projectedX = ax + (abx * t)
        let projectedY = ay + (aby * t)

        return Coordinate(
            latitude: projectedY / metersPerDegreeLat,
            longitude: projectedX / metersPerDegreeLon
        )
    }
}
