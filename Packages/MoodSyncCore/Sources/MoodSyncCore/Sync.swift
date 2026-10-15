import Foundation

public enum SyncConfiguration {
    public static let exampleRelayURL = "https://YOUR-PROJECT-default-rtdb.firebaseio.com"
    public static let cloudKitContainerID = "iCloud.app.moodsync.ios"

    public static func isPlaceholder(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let upper = trimmed.uppercased()
        return upper.contains("YOUR-PROJECT") || upper.contains("YOUR_PROJECT") || upper.contains("YOURPROJECT")
    }
}

public enum SyncError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL
    case invalidCode
    case server(String)
    case cloudKitUnavailable
    case cloudKit(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Add your Firebase Realtime Database URL in Settings to sync this circle."
        case .invalidURL:
            "That relay URL doesn't look right."
        case .invalidCode:
            "Codes are 6 characters. I, O, 0, and 1 are left out so they're harder to mix up."
        case .server(let message):
            message
        case .cloudKitUnavailable:
            "iCloud sync needs the iCloud capability, which a free Apple ID can't sign. Use a paid developer team, or stay on the shared relay."
        case .cloudKit(let message):
            message
        }
    }
}

public struct RemoteMember: Codable, Equatable, Sendable {
    public var displayName: String
    public var emoji: String?
    public var label: String?
    public var colorHex: String?
    public var note: String?
    public var valence: Double?
    public var moodID: UUID?
    public var updatedAt: Date?

    public init(
        displayName: String,
        emoji: String? = nil,
        label: String? = nil,
        colorHex: String? = nil,
        note: String? = nil,
        valence: Double? = nil,
        moodID: UUID? = nil,
        updatedAt: Date? = nil
    ) {
        self.displayName = displayName
        self.emoji = emoji
        self.label = label
        self.colorHex = colorHex
        self.note = note
        self.valence = valence
        self.moodID = moodID
        self.updatedAt = updatedAt
    }

    public static func from(member: CircleMember) -> RemoteMember? {
        guard !member.isPreview else { return nil }
        return RemoteMember(
            displayName: member.displayName,
            emoji: member.latestMood?.emoji,
            label: member.latestMood?.label,
            colorHex: member.latestMood?.colorHex,
            note: member.latestMood?.note,
            valence: member.latestMood?.valence,
            moodID: member.latestMood?.id,
            updatedAt: member.latestMood?.createdAt
        )
    }
}

public struct RemotePerson: Equatable, Sendable {
    public var id: UUID
    public var member: RemoteMember

    public init(id: UUID, member: RemoteMember) {
        self.id = id
        self.member = member
    }
}

public struct RemoteCircle: Equatable, Sendable {
    public var name: String?
    public var members: [RemotePerson]

    public init(name: String?, members: [RemotePerson]) {
        self.name = name
        self.members = members
    }
}

public enum CircleMerge {
    /// Remote friends replace local friends. The current user's mood stays local.
    public static func merging(_ local: FriendCircle, with remote: RemoteCircle, currentUserID: UUID) -> FriendCircle {
        var result = local
        if let name = remote.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            result.name = String(name.prefix(32))
        }

        let me = local.members.first { $0.isCurrentUser } ?? CircleMember(
            id: currentUserID,
            displayName: "Me",
            isCurrentUser: true,
            isPreview: false,
            latestMood: nil
        )

        var friends: [CircleMember] = remote.members.compactMap { person in
            guard person.id != currentUserID else { return nil }
            return CircleMember(
                id: person.id,
                displayName: person.member.displayName,
                isCurrentUser: false,
                isPreview: false,
                latestMood: mood(from: person.member)
            )
        }
        friends.sort { lhs, rhs in
            (lhs.latestMood?.createdAt ?? .distantPast) > (rhs.latestMood?.createdAt ?? .distantPast)
        }
        result.members = [me] + friends
        result.isPreview = false
        return result
    }

    private static func mood(from member: RemoteMember) -> MoodEntry? {
        guard let emoji = member.emoji, let label = member.label, let colorHex = member.colorHex else {
            return nil
        }
        return MoodEntry(
            id: member.moodID ?? UUID(),
            emoji: emoji,
            label: label,
            colorHex: colorHex,
            note: member.note ?? "",
            valence: member.valence ?? 0,
            createdAt: member.updatedAt ?? Date()
        )
    }
}
