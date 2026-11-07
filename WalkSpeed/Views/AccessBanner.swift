import SwiftUI
import UIKit

/// Explains a missing location permission and links to Settings.
struct AccessBanner: View {
    var access: LocationAccess

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let content {
            VStack(alignment: .leading, spacing: 10) {
                Label(content.title, systemImage: "location.slash.fill")
                    .font(.headline)
                Text(content.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.orange.opacity(0.15), in: .rect(cornerRadius: 20))
        }
    }

    private var content: (title: LocalizedStringKey, message: LocalizedStringKey)? {
        switch access {
        case .denied:
            return (
                "Location is off for WalkSpeed",
                "WalkSpeed needs your location to measure your walking speed. Turn it on in Settings."
            )
        case .restricted:
            return (
                "Location is restricted",
                "Location Services are restricted on this iPhone, so WalkSpeed can't measure your speed."
            )
        case .approximateOnly:
            return (
                "Precise Location is off",
                "WalkSpeed can't measure speed from an approximate location. Turn on Precise Location in Settings."
            )
        case .notDetermined, .granted:
            return nil
        }
    }
}
