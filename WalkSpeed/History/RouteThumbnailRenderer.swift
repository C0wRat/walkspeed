import MapKit
import UIKit
import WalkSpeedCore

/// Draws small map pictures of a walk's route for lists.
///
/// A live map in every row of a list would be slow, so each walk gets a
/// static snapshot with the route drawn on top. The picture is drawn for
/// light or dark mode to match the app. Fetching the map runs in the
/// background, and drawing the small picture on the main actor is quick.
@MainActor
enum RouteThumbnailRenderer {
    /// Renders the route over a map snapshot.
    ///
    /// - Parameters:
    ///   - route: The route to draw.
    ///   - size: The size of the picture in points.
    ///   - scale: The display scale.
    ///   - isDark: Whether to draw for dark mode.
    /// - Returns: The picture, or `nil` if the route has no points.
    static func render(route: [RoutePoint], size: CGSize, scale: CGFloat, isDark: Bool) async throws -> UIImage? {
        guard let bounds = RouteBounds(of: route) else { return nil }
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = isDark ? .dark : .light
            traits.displayScale = scale
        }

        let configuration = MKStandardMapConfiguration()
        configuration.pointOfInterestFilter = .excludingAll
        let options = MKMapSnapshotter.Options()
        options.preferredConfiguration = configuration
        options.traitCollection = traits
        options.size = size
        // Pad the route so it doesn't touch the edges, and don't zoom in
        // further than a few streets for very short walks.
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: bounds.centerLatitude, longitude: bounds.centerLongitude),
            span: MKCoordinateSpan(
                latitudeDelta: max(bounds.latitudeSpan * 1.5, 0.003),
                longitudeDelta: max(bounds.longitudeSpan * 1.5, 0.003)
            )
        )

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let underLimit = (UIColor(named: "AccentColor") ?? .systemGreen).resolvedColor(with: traits)
        let overLimit = UIColor.systemRed.resolvedColor(with: traits)

        return UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat(for: traits)).image { _ in
            snapshot.image.draw(at: .zero)
            for segment in RouteSegment.segments(of: route) {
                let path = UIBezierPath()
                for (index, point) in segment.points.enumerated() {
                    let location = snapshot.point(for: point.coordinate)
                    if index == 0 {
                        path.move(to: location)
                    } else {
                        path.addLine(to: location)
                    }
                }
                path.lineWidth = 3
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                (segment.isOverLimit ? overLimit : underLimit).setStroke()
                path.stroke()
            }
        }
    }
}
