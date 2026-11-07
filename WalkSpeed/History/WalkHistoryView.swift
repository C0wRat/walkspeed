import SwiftData
import SwiftUI
import WalkSpeedCore

/// Past walks, newest first, each with a little map of its route.
struct WalkHistoryView: View {
    @Query(sort: \Walk.startDate, order: .reverse) private var walks: [Walk]
    @Environment(\.modelContext) private var modelContext
    @Environment(Preferences.self) private var preferences

    var body: some View {
        List {
            ForEach(walks) { walk in
                NavigationLink(value: walk) {
                    WalkRow(walk: walk, unit: preferences.unit)
                }
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if walks.isEmpty {
                ContentUnavailableView(
                    "No Walks Yet",
                    systemImage: "figure.walk",
                    description: Text("Each time you stop monitoring, WalkSpeed saves a summary of your walk here.")
                )
            }
        }
        .navigationTitle("Walks")
        .navigationDestination(for: Walk.self) { walk in
            WalkSummaryView(walk: walk)
        }
        .toolbar {
            if !walks.isEmpty {
                EditButton()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(walks[index])
        }
        try? modelContext.save()
    }
}

/// A walk in the history list.
private struct WalkRow: View {
    let walk: Walk
    let unit: SpeedUnit

    var body: some View {
        let summary = walk.summary
        HStack(spacing: 14) {
            WalkThumbnail(walk: walk)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Text("\(WalkFormat.distance(summary.distance, unit: unit)) · \(WalkFormat.duration(summary.duration))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                limitLabel(for: summary)
            }
        }
        .padding(.vertical, 4)
    }

    private func limitLabel(for summary: WalkSummary) -> some View {
        let isClean = summary.timeOverLimit < 1
        return Label {
            if isClean {
                Text("Under the limit")
            } else {
                Text("\(summary.fractionOverLimit.formatted(.percent.precision(.fractionLength(0)))) over the limit")
            }
        } icon: {
            Image(systemName: isClean ? "checkmark.circle.fill" : "tortoise.fill")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(isClean ? Color.accentColor : .red)
    }
}

/// A little map of a walk's route. It's rendered once, saved with the walk
/// and redrawn when the app switches between light and dark mode.
struct WalkThumbnail: View {
    let walk: Walk

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext

    static let size = CGSize(width: 64, height: 64)

    var body: some View {
        content
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(.rect(cornerRadius: 12))
            .task(id: colorScheme) {
                await renderIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let image = cachedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(.background.secondary)
                Image(systemName: walk.routePointCount > 1 ? "map" : "figure.walk")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var cachedImage: UIImage? {
        guard let data = walk.thumbnailData, walk.thumbnailIsDark == isDark else { return nil }
        return UIImage(data: data)
    }

    private func renderIfNeeded() async {
        guard walk.routePointCount > 1, cachedImage == nil else { return }
        let image = try? await RouteThumbnailRenderer.render(
            route: walk.route,
            size: Self.size,
            scale: displayScale,
            isDark: isDark
        )
        // Without a network connection the map can't load. Keep the
        // placeholder and try again next time the row appears.
        guard let image, let data = image.pngData() else { return }
        walk.thumbnailData = data
        walk.thumbnailIsDark = isDark
        try? modelContext.save()
    }
}
