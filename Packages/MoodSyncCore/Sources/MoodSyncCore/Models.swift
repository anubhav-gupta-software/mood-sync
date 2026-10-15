import Foundation

public struct MoodEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var emoji: String
    public var label: String
    public var colorHex: String
    public var note: String
    public var valence: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        emoji: String,
        label: String,
        colorHex: String,
        note: String,
        valence: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.emoji = emoji.isEmpty ? "😐" : emoji
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = String((trimmedLabel.isEmpty ? "Mood" : trimmedLabel).prefix(24))
        self.colorHex = MoodColor.normalize(colorHex)
        self.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        self.valence = min(1, max(-1, valence))
        self.createdAt = createdAt
    }
}

public struct RGB: Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum MoodColor {
    public static func normalize(_ hex: String) -> String {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        let filtered = String(value.filter(\.isHexDigit))
        if filtered.count == 6 {
            return filtered
        }
        return "F5C451"
    }

    public static func rgb(_ hex: String) -> RGB {
        let normalized = normalize(hex)
        var number: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&number)
        return RGB(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}

public struct CircleMember: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String
    public var isCurrentUser: Bool
    public var isPreview: Bool
    public var latestMood: MoodEntry?

    public init(
        id: UUID,
        displayName: String,
        isCurrentUser: Bool,
        isPreview: Bool,
        latestMood: MoodEntry? = nil
    ) {
        self.id = id
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = String((trimmed.isEmpty ? "Friend" : trimmed).prefix(24))
        self.isCurrentUser = isCurrentUser
        self.isPreview = isPreview
        self.latestMood = latestMood
    }
}

public struct FriendCircle: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var inviteCode: String
    public var members: [CircleMember]
    public var createdAt: Date
    public var isPreview: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        inviteCode: String,
        members: [CircleMember],
        createdAt: Date = Date(),
        isPreview: Bool = false
    ) {
        self.id = id
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = String((trimmed.isEmpty ? "Circle" : trimmed).prefix(32))
        self.inviteCode = inviteCode
        self.members = members
        self.createdAt = createdAt
        self.isPreview = isPreview
    }

    public var friends: [CircleMember] {
        members.filter { !$0.isCurrentUser }
    }
}

public struct UserProfile: Codable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String
    public var remindersEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    public var includePreviewCircle: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        remindersEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        includePreviewCircle: Bool,
        hasCompletedOnboarding: Bool
    ) {
        self.id = id
        self.displayName = String(displayName.prefix(24))
        self.remindersEnabled = remindersEnabled
        self.reminderHour = min(23, max(0, reminderHour))
        self.reminderMinute = min(59, max(0, reminderMinute))
        self.includePreviewCircle = includePreviewCircle
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var resolvedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Me" : trimmed
    }
}

public struct SyncSettings: Codable, Hashable, Sendable {
    public var mode: SyncMode
    public var relayURL: String

    public init(mode: SyncMode, relayURL: String) {
        self.mode = mode
        self.relayURL = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SyncMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case relay
    case cloudKit

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .local: "On this iPhone"
        case .relay: "Shared relay"
        case .cloudKit: "iCloud"
        }
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var profile: UserProfile
    public var circles: [FriendCircle]
    public var activeCircleID: UUID?
    public var history: [MoodEntry]
    public var sync: SyncSettings

    public init(
        version: Int = AppState.currentVersion,
        profile: UserProfile,
        circles: [FriendCircle],
        activeCircleID: UUID?,
        history: [MoodEntry],
        sync: SyncSettings
    ) {
        self.version = version
        self.profile = profile
        self.circles = circles
        self.activeCircleID = activeCircleID
        self.history = history
        self.sync = sync
    }

    public var activeCircle: FriendCircle? {
        if let activeCircleID, let match = circles.first(where: { $0.id == activeCircleID }) {
            return match
        }
        return circles.first
    }

    public static func fresh(now: Date = Date()) -> AppState {
        let profile = UserProfile(
            displayName: "",
            remindersEnabled: false,
            reminderHour: 20,
            reminderMinute: 0,
            includePreviewCircle: true,
            hasCompletedOnboarding: false
        )
        let preview = SeedData.previewCircle(now: now)
        return AppState(
            profile: profile,
            circles: [preview],
            activeCircleID: preview.id,
            history: [],
            sync: SyncSettings(mode: .local, relayURL: "")
        )
    }
}
