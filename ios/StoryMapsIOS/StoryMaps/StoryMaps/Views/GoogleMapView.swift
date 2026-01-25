/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import MapKit

#if canImport(GoogleMaps)
import GoogleMaps
#endif

struct GoogleMapView: UIViewRepresentable {
    let route: RouteDetails
    let currentSegmentIndex: Int
    let totalSegments: Int
    
    #if canImport(GoogleMaps)
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero)
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 13)
        mapView.camera = camera
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        
        // Apply custom map style
        if let styleURL = Bundle.main.url(forResource: "MapStyle", withExtension: "json"),
           let styleData = try? Data(contentsOf: styleURL),
           let styleString = String(data: styleData, encoding: .utf8) {
            do {
                mapView.mapStyle = try GMSMapStyle(jsonString: styleString)
            } catch {
                print("Failed to load map style: \(error)")
            }
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Clear existing overlays
        mapView.clear()
        
        // Draw route polyline
        let path = GMSMutablePath()
        for coord in route.polyline {
            path.add(CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude))
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor(red: 0.565, green: 0.078, blue: 0.686, alpha: 0.9)
        polyline.strokeWidth = 5.0
        polyline.map = mapView
        
        // Add start marker
        if let first = route.polyline.first {
            let startMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude))
            startMarker.title = "Start"
            startMarker.icon = GMSMarker.markerImage(with: .systemGreen)
            startMarker.map = mapView
        }
        
        // Add end marker
        if let last = route.polyline.last {
            let endMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
            endMarker.title = "Destination"
            endMarker.icon = GMSMarker.markerImage(with: .systemRed)
            endMarker.map = mapView
        }
        
        // Add progress marker
        if !route.polyline.isEmpty {
            let progressRatio = Double(currentSegmentIndex) / Double(max(1, totalSegments))
            let pathIndex = min(Int(progressRatio * Double(route.polyline.count - 1)), route.polyline.count - 1)
            let progressCoord = route.polyline[pathIndex]
            
            let progressMarker = GMSMarker(position: CLLocationCoordinate2D(latitude: progressCoord.latitude, longitude: progressCoord.longitude))
            progressMarker.icon = GMSMarker.markerImage(with: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
            progressMarker.zIndex = 999
            progressMarker.map = mapView
        }
        
        // Fit bounds to show entire route
        let bounds = GMSCoordinateBounds(path: path)
        let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
        mapView.moveCamera(update)
    }
    #else
    func makeUIView(context: Context) -> UIView {
        let label = UILabel()
        label.text = "Google Maps not configured"
        label.textAlignment = .center
        return label
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    #endif
}

