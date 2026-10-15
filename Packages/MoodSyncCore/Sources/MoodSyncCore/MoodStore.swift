import Foundation

public struct MoodStore {
    public let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("MoodSync", isDirectory: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public var stateURL: URL {
        directory.appendingPathComponent("state.json")
    }

    public func load(now: Date = Date()) -> AppState {
        let decoded: AppState
        if let data = try? Data(contentsOf: stateURL),
           let state = try? decoder.decode(AppState.self, from: data) {
            decoded = state
        } else {
            decoded = .fresh(now: now)
        }
        return SeedData.refreshingPreview(in: decoded, now: now)
    }

    public func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
        WidgetSnapshot.writeToSharedContainer(WidgetSnapshot.make(from: state))
    }
}
