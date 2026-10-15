import Foundation

public struct WidgetMember: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var isCurrentUser: Bool
    public var emoji: String
    public var label: String
    public var colorHex: String
    public var note: String
    public var updatedAt: Date?

    public init(
        id: UUID,
        name: String,
        isCurrentUser: Bool,
        emoji: String,
        label: String,
        colorHex: String,
        note: String,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.isCurrentUser = isCurrentUser
        self.emoji = emoji
        self.label = label
        self.colorHex = colorHex
        self.note = note
        self.updatedAt = updatedAt
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public enum Availability: String, Codable, Sendable {
        case ready
        case empty
        case appGroupOff
    }

    public var availability: Availability
    public var groupName: String
    public var updatedAt: Date
    public var members: [WidgetMember]

    public init(availability: Availability, groupName: String, updatedAt: Date, members: [WidgetMember]) {
        self.availability = availability
        self.groupName = groupName
        self.updatedAt = updatedAt
        self.members = members
    }

    public var you: WidgetMember? {
        members.first { $0.isCurrentUser }
    }

    public var friends: [WidgetMember] {
        members.filter { !$0.isCurrentUser }
    }

    public var tintHex: String {
        friends.first?.colorHex ?? you?.colorHex ?? MoodPreset.happy.colorHex
    }

    public static func make(from state: AppState, now: Date = Date()) -> WidgetSnapshot {
        guard let circle = state.activeCircle else {
            return WidgetSnapshot(availability: .empty, groupName: "Mood Sync", updatedAt: now, members: [])
        }
        let members = circle.members.map { member in
            WidgetMember(
                id: member.id,
                name: member.isCurrentUser ? state.profile.resolvedName : member.displayName,
                isCurrentUser: member.isCurrentUser,
                emoji: member.latestMood?.emoji ?? "·",
                label: member.latestMood?.label ?? "No check-in",
                colorHex: member.latestMood?.colorHex ?? "A39890",
                note: member.latestMood?.note ?? "",
                updatedAt: member.latestMood?.createdAt
            )
        }
        let sorted = members.sorted { lhs, rhs in
            if lhs.isCurrentUser != rhs.isCurrentUser {
                return lhs.isCurrentUser
            }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }
        return WidgetSnapshot(availability: .ready, groupName: circle.name, updatedAt: now, members: sorted)
    }

    public static func loadShared(now: Date = Date()) -> WidgetSnapshot {
        guard AppGroup.isAvailable else {
            return WidgetSnapshot(availability: .appGroupOff, groupName: "Mood Sync", updatedAt: now, members: [])
        }
        guard let url = AppGroup.snapshotURL, let snapshot = try? read(from: url) else {
            return WidgetSnapshot(availability: .empty, groupName: "Mood Sync", updatedAt: now, members: [])
        }
        return snapshot
    }

    public static func writeToSharedContainer(_ snapshot: WidgetSnapshot) {
        guard let url = AppGroup.snapshotURL else { return }
        try? write(snapshot, to: url)
    }

    public static func read(from url: URL) throws -> WidgetSnapshot {
        let data = try Data(contentsOf: url)
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }

    public static func write(_ snapshot: WidgetSnapshot, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
