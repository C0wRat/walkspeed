import MapKit
import SwiftUI
import WalkSpeedCore

/// A walk's route on a map, red where you were over the limit.
struct RouteMap: View {
    var route: [RoutePoint]

    private static let stroke = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)

    var body: some View {
        Map(initialPosition: .automatic) {
            ForEach(Array(RouteSegment.segments(of: route).enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.points.map(\.coordinate))
                    .stroke(segment.isOverLimit ? Color.red : Color.accentColor, style: Self.stroke)
            }
            if let start = route.first {
                Annotation("Start", coordinate: start.coordinate) {
                    RouteEndpoint(color: .green)
                }
                .annotationTitles(.hidden)
            }
            if route.count > 1, let end = route.last {
                Annotation("Finish", coordinate: end.coordinate) {
                    RouteEndpoint(color: .black)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }
}

/// A dot marking the start or finish of a route.
private struct RouteEndpoint: View {
    var color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(radius: 2)
    }
}

extension RoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
