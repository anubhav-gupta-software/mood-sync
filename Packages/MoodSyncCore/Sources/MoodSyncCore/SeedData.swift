import Foundation

public enum SeedData {
    public static let previewCircleID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
    public static let mayaID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    public static let leoID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    public static let priyaID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    public static let samID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

    public static func previewCircle(now: Date = Date()) -> FriendCircle {
        FriendCircle(
            id: previewCircleID,
            name: "Preview",
            inviteCode: "SAMPLE",
            members: previewMembers(now: now),
            createdAt: now.addingTimeInterval(-86_400 * 12),
            isPreview: true
        )
    }

    public static func previewMembers(now: Date) -> [CircleMember] {
        [
            member(mayaID, "Maya", .calm, "Slow morning", minutesAgo: 25, now: now),
            member(leoID, "Leo", .excited, "Show tonight", minutesAgo: 120, now: now),
            member(priyaID, "Priya", .tired, "Three meetings", minutesAgo: 280, now: now),
            member(samID, "Sam", .grateful, "Soup and a movie", minutesAgo: 60 * 20, now: now)
        ]
    }

    public static func refreshingPreview(in state: AppState, now: Date = Date()) -> AppState {
        var copy = state
        guard copy.profile.includePreviewCircle else {
            copy.circles.removeAll { $0.isPreview }
            if copy.activeCircleID == previewCircleID {
                copy.activeCircleID = copy.circles.first?.id
            }
            return copy
        }

        if let index = copy.circles.firstIndex(where: { $0.isPreview }) {
            let me = copy.circles[index].members.first(where: \.isCurrentUser)
            var members = previewMembers(now: now)
            if let me {
                members.insert(me, at: 0)
            }
            copy.circles[index].members = members
            copy.circles[index].name = "Preview"
            copy.circles[index].isPreview = true
        } else {
            copy.circles.insert(previewCircle(now: now), at: 0)
        }
        if copy.activeCircleID == nil {
            copy.activeCircleID = previewCircleID
        }
        return copy
    }

    /// A couple of weeks of check-ins for SwiftUI previews and the widget gallery.
    public static func sampleHistory(now: Date = Date(), calendar: Calendar = .current) -> [MoodEntry] {
        let cycle: [MoodPreset] = [.calm, .happy, .focused, .tired, .grateful, .loved, .meh, .excited, .low, .happy, .calm, .stressed, .grateful, .happy]
        return cycle.enumerated().map { offset, preset in
            let day = calendar.date(byAdding: .day, value: -(cycle.count - 1 - offset), to: now) ?? now
            let stamped = calendar.date(bySettingHour: 19, minute: 10, second: 0, of: day) ?? day
            return preset.entry(note: offset.isMultiple(of: 3) ? "Checked in" : "", at: stamped)
        }
    }

    public static func sampleSnapshot(now: Date = Date()) -> WidgetSnapshot {
        let profileID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        var circle = previewCircle(now: now)
        circle.members.insert(
            CircleMember(
                id: profileID,
                displayName: "Alex",
                isCurrentUser: true,
                isPreview: false,
                latestMood: MoodPreset.happy.entry(note: "Coffee was good", at: now.addingTimeInterval(-600))
            ),
            at: 0
        )
        return WidgetSnapshot.make(from: AppState(
            profile: UserProfile(
                id: profileID,
                displayName: "Alex",
                remindersEnabled: true,
                reminderHour: 20,
                reminderMinute: 0,
                includePreviewCircle: true,
                hasCompletedOnboarding: true
            ),
            circles: [circle],
            activeCircleID: previewCircleID,
            history: [],
            sync: SyncSettings(mode: .local, relayURL: "")
        ), now: now)
    }

    private static func member(
        _ id: UUID,
        _ name: String,
        _ preset: MoodPreset,
        _ note: String,
        minutesAgo: Int,
        now: Date
    ) -> CircleMember {
        let when = now.addingTimeInterval(TimeInterval(-minutesAgo * 60))
        return CircleMember(
            id: id,
            displayName: name,
            isCurrentUser: false,
            isPreview: true,
            latestMood: preset.entry(note: note, at: when)
        )
    }
}
