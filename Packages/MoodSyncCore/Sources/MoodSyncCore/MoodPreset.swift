import Foundation

public enum MoodPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case happy
    case calm
    case tired
    case excited
    case low
    case stressed
    case loved
    case focused
    case grateful
    case meh

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .happy: "😊"
        case .calm: "😌"
        case .tired: "😴"
        case .excited: "🤩"
        case .low: "😔"
        case .stressed: "😤"
        case .loved: "🥰"
        case .focused: "🎯"
        case .grateful: "🙏"
        case .meh: "😐"
        }
    }

    public var label: String {
        switch self {
        case .happy: "Happy"
        case .calm: "Calm"
        case .tired: "Tired"
        case .excited: "Excited"
        case .low: "Low"
        case .stressed: "Stressed"
        case .loved: "Loved"
        case .focused: "Focused"
        case .grateful: "Grateful"
        case .meh: "Meh"
        }
    }

    /// Stored without a leading "#".
    public var colorHex: String {
        switch self {
        case .happy: "F5C451"
        case .calm: "7EB6B0"
        case .tired: "8E86B8"
        case .excited: "F07A4A"
        case .low: "6E8CA8"
        case .stressed: "E15A5A"
        case .loved: "E989A8"
        case .focused: "3E8E7E"
        case .grateful: "E0A35A"
        case .meh: "A39890"
        }
    }

    /// -1 feels low, 1 feels high. The history chart plots this.
    public var valence: Double {
        switch self {
        case .happy: 0.9
        case .calm: 0.45
        case .tired: -0.25
        case .excited: 0.85
        case .low: -0.8
        case .stressed: -0.55
        case .loved: 0.7
        case .focused: 0.35
        case .grateful: 0.6
        case .meh: 0
        }
    }

    public func entry(note: String = "", at date: Date = Date()) -> MoodEntry {
        MoodEntry(
            emoji: emoji,
            label: label,
            colorHex: colorHex,
            note: note,
            valence: valence,
            createdAt: date
        )
    }
}
