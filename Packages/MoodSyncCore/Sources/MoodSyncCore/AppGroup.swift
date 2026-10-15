import Foundation

/// Shared container for the app and the widget.
///
/// The id has to match the App Group entitlement. Personal (free) Apple IDs
/// cannot sign that entitlement, so the container is missing until you switch
/// to a paid team and the App Group entitlements. See Config/App.xcconfig.
public enum AppGroup {
    public static let identifier = "group.app.moodsync.shared"
    public static let snapshotFileName = "widget-snapshot.json"

    public static var containerURL: URL? {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(macOS)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        #else
        nil
        #endif
    }

    public static var isAvailable: Bool {
        containerURL != nil
    }

    public static var snapshotURL: URL? {
        guard let containerURL else { return nil }
        return containerURL
            .appendingPathComponent("Library/Application Support/MoodSync", isDirectory: true)
            .appendingPathComponent(snapshotFileName)
    }
}
