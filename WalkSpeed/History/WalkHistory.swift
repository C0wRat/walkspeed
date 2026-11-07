import Foundation
import os
import SwiftData
import WalkSpeedCore

private let logger = Logger(subsystem: "com.c0wrat.walkspeed", category: "history")

/// Saves finished walks with SwiftData.
@MainActor
final class WalkHistory {
    let container: ModelContainer

    /// Walks shorter than this, in seconds, aren't worth keeping.
    static let minimumDuration: TimeInterval = 30

    init(inMemory: Bool = false) {
        do {
            container = try ModelContainer(
                for: Walk.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            logger.error("Couldn't open the walk history, so it won't persist: \(error.localizedDescription, privacy: .public)")
            do {
                container = try ModelContainer(for: Walk.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("Couldn't create an in-memory walk history: \(error)")
            }
        }
    }

    /// Saves a walk, unless it was too short to keep.
    ///
    /// - Returns: The saved walk, or `nil` if it was too short.
    func save(_ summary: WalkSummary, route: [RoutePoint], speedTrace: [SpeedTrace.Point]) -> Walk? {
        guard summary.duration >= Self.minimumDuration else { return nil }
        let walk = Walk(summary: summary, route: route, speedTrace: speedTrace)
        let context = container.mainContext
        context.insert(walk)
        do {
            try context.save()
        } catch {
            logger.error("Couldn't save the walk: \(error.localizedDescription, privacy: .public)")
        }
        return walk
    }
}
