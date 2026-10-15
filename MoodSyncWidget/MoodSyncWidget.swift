import SwiftUI
import WidgetKit
import MoodSyncCore

@main
struct MoodSyncWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoodCircleWidget()
    }
}

struct MoodWidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

struct MoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodWidgetEntry {
        MoodWidgetEntry(date: Date(), snapshot: SeedData.sampleSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? SeedData.sampleSnapshot() : WidgetSnapshot.loadShared()
        completion(MoodWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodWidgetEntry>) -> Void) {
        let entry = MoodWidgetEntry(date: Date(), snapshot: WidgetSnapshot.loadShared())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct MoodCircleWidget: Widget {
    let kind = "MoodCircle"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodProvider()) { entry in
            MoodWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    MoodWidgetBackground(hex: entry.snapshot.tintHex)
                }
        }
        .configurationDisplayName("Mood Circle")
        .description("See the latest mood from each friend.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct MoodWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MoodWidgetEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        Group {
            if snapshot.availability != .ready || (snapshot.friends.isEmpty && snapshot.you == nil) {
                placeholder
            } else {
                switch family {
                case .systemSmall:
                    small
                case .systemMedium:
                    medium
                case .systemLarge, .systemExtraLarge:
                    large
                case .accessoryCircular:
                    circular
                case .accessoryRectangular:
                    rectangular
                case .accessoryInline:
                    inline
                default:
                    small
                }
            }
        }
    }

    private var focus: WidgetMember? {
        snapshot.you ?? snapshot.friends.first
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.groupName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(focus?.emoji ?? "·")
                .font(.system(size: 40))
                .widgetAccentable()
            Text(focus?.label ?? "Mood")
                .font(.headline)
                .lineLimit(1)
            Text(focus?.name ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !snapshot.friends.isEmpty {
                Text(snapshot.friends.prefix(4).map(\.emoji).joined(separator: " "))
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.groupName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(focus?.emoji ?? "·")
                    .font(.system(size: 42))
                    .widgetAccentable()
                Text(focus?.label ?? "Mood")
                    .font(.headline)
                    .lineLimit(1)
                Text(focusNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.friends.prefix(3)) { friend in
                    HStack(spacing: 6) {
                        Text(friend.emoji)
                            .widgetAccentable()
                        VStack(alignment: .leading, spacing: 0) {
                            Text(friend.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(friend.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                if snapshot.friends.isEmpty {
                    Text("No friends yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var focusNote: String {
        if let note = focus?.note, !note.isEmpty { return note }
        return focus?.name ?? ""
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.groupName)
                    .font(.headline)
                Spacer()
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                ForEach(snapshot.members.prefix(6)) { member in
                    HStack(spacing: 8) {
                        Text(member.emoji)
                            .font(.title2)
                            .widgetAccentable()
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.isCurrentUser ? "\(member.name) · you" : member.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(member.note.isEmpty ? member.label : member.note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var circular: some View {
        Text(snapshot.friends.first?.emoji ?? focus?.emoji ?? "·")
            .font(.title)
            .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.groupName)
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            ForEach(displayedFriends.prefix(2)) { friend in
                Text("\(friend.emoji) \(friend.name) · \(friend.label)")
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text(inlineText)
            .widgetAccentable()
    }

    private var displayedFriends: [WidgetMember] {
        snapshot.friends.isEmpty ? snapshot.members : snapshot.friends
    }

    private var inlineText: String {
        let bits = displayedFriends.prefix(3).map { "\($0.name) \($0.emoji)" }
        if bits.isEmpty { return snapshot.groupName }
        return bits.joined(separator: "  ")
    }

    @ViewBuilder
    private var placeholder: some View {
        let message = snapshot.availability == .appGroupOff
            ? "Turn on the App Group to see live moods."
            : "Open Mood Sync and check in."
        switch family {
        case .accessoryInline:
            Text(snapshot.availability == .appGroupOff ? "Mood Sync setup" : "Mood Sync")
                .widgetAccentable()
        case .accessoryCircular:
            Text("·")
                .font(.title)
                .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Mood Sync").font(.headline).widgetAccentable()
                Text(message).font(.caption2).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("Mood Sync")
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct MoodWidgetBackground: View {
    @Environment(\.widgetFamily) private var family
    var hex: String

    var body: some View {
        let rgb = MoodColor.rgb(hex)
        let accent = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        return Group {
            if family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline {
                AccessoryWidgetBackground()
            } else {
                LinearGradient(
                    colors: [accent.opacity(0.62), accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
