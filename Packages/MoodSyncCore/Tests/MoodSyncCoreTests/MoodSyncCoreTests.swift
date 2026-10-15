import XCTest
@testable import MoodSyncCore

final class MoodSyncCoreTests: XCTestCase {
    func testInviteCodesStayInTheSafeAlphabet() {
        var generator = SplitMix64(seed: 42)
        for _ in 0..<200 {
            let code = InviteCode.make(using: &generator)
            XCTAssertTrue(InviteCode.isValid(code))
            XCTAssertEqual(code.count, InviteCode.length)
            XCTAssertFalse(code.contains("I"))
            XCTAssertFalse(code.contains("O"))
            XCTAssertFalse(code.contains("0"))
            XCTAssertFalse(code.contains("1"))
        }
    }

    func testNormalizeDropsConfusableCharacters() {
        XCTAssertEqual(InviteCode.normalize(" ab-io 12 "), "AB2")
        XCTAssertFalse(InviteCode.isValid(InviteCode.normalize("HELLO")))
        XCTAssertTrue(InviteCode.isValid(InviteCode.normalize("k7m2qp")))
    }

    func testMoodEntryClampsTheChartValueAndTheNote() {
        let entry = MoodEntry(
            emoji: "",
            label: "   ",
            colorHex: "#f5c451",
            note: String(repeating: "a", count: 120),
            valence: 4
        )
        XCTAssertEqual(entry.emoji, "😐")
        XCTAssertEqual(entry.label, "Mood")
        XCTAssertEqual(entry.colorHex, "F5C451")
        XCTAssertEqual(entry.note.count, 80)
        XCTAssertEqual(entry.valence, 1)
        XCTAssertEqual(MoodColor.normalize("nope"), "F5C451")
    }

    func testDailyChartKeepsTheLatestCheckInEachDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 21)))
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 8)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 19)))
        let old = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12)))
        let entries = [
            MoodPreset.tired.entry(note: "morning", at: morning),
            MoodPreset.happy.entry(note: "evening", at: now),
            MoodPreset.calm.entry(at: yesterday),
            MoodPreset.low.entry(at: old)
        ]

        let week = HistoryChart.dailyLatest(entries, in: .week, now: now, calendar: calendar)
        XCTAssertEqual(week.map(\.label), ["Calm", "Happy"])
        XCTAssertEqual(HistoryChart.filtered(entries, in: .week, now: now, calendar: calendar).count, 3)
        XCTAssertEqual(HistoryChart.dailyLatest(entries, in: .all, now: now, calendar: calendar).count, 3)
        XCTAssertEqual(HistoryStats.mostCommonLabel([
            MoodPreset.tired.entry(),
            MoodPreset.tired.entry(),
            MoodPreset.happy.entry()
        ]), "Tired")
        XCTAssertEqual(HistoryStats.word(for: 0.9), "bright")
        XCTAssertEqual(HistoryStats.word(for: -0.9), "low")
        XCTAssertNil(HistoryStats.averageValence([]))
    }

    func testStoreRoundTripAndPreviewRefreshKeepsMe() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("moodsync-tests-\(UUID().uuidString)", isDirectory: true)
        let store = MoodStore(directory: directory)
        var state = store.load(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(state.circles.count, 1)
        XCTAssertTrue(state.circles[0].isPreview)

        state.profile.displayName = "Anubhav"
        state.profile.hasCompletedOnboarding = true
        let mood = MoodPreset.grateful.entry(note: "Soup", at: Date(timeIntervalSince1970: 1_700_000_100))
        state.history = [mood]
        state.circles[0].members.insert(
            CircleMember(
                id: state.profile.id,
                displayName: "Anubhav",
                isCurrentUser: true,
                isPreview: false,
                latestMood: mood
            ),
            at: 0
        )
        try store.save(state)

        let loaded = store.load(now: Date(timeIntervalSince1970: 1_700_003_000))
        XCTAssertEqual(loaded.profile.displayName, "Anubhav")
        XCTAssertEqual(loaded.history.first?.note, "Soup")
        let me = try XCTUnwrap(loaded.circles[0].members.first { $0.isCurrentUser })
        XCTAssertEqual(me.latestMood?.label, "Grateful")
        XCTAssertEqual(loaded.circles[0].friends.count, 4)
        XCTAssertGreaterThan(loaded.circles[0].friends[0].latestMood?.createdAt ?? .distantPast, Date(timeIntervalSince1970: 1_700_000_000))

        let snapshotURL = directory.appendingPathComponent("snapshot.json")
        let snapshot = WidgetSnapshot.make(from: loaded)
        try WidgetSnapshot.write(snapshot, to: snapshotURL)
        let readBack = try WidgetSnapshot.read(from: snapshotURL)
        XCTAssertEqual(readBack.groupName, "Preview")
        XCTAssertEqual(readBack.you?.name, "Anubhav")
        XCTAssertEqual(readBack.friends.count, 4)
    }

    func testMergeKeepsMyMoodAndTakesFriendsFromTheRelay() {
        let me = UUID()
        let friend = UUID()
        let localMood = MoodPreset.happy.entry(note: "mine", at: Date(timeIntervalSince1970: 50))
        let local = FriendCircle(
            name: "Circle ABCDEF",
            inviteCode: "ABCDEF",
            members: [CircleMember(id: me, displayName: "Me", isCurrentUser: true, isPreview: false, latestMood: localMood)]
        )
        let remoteMoodID = UUID()
        let remote = RemoteCircle(
            name: "Saturday",
            members: [
                RemotePerson(id: me, member: RemoteMember(displayName: "Old name", emoji: "😔", label: "Low", colorHex: "6E8CA8", note: "stale", valence: -0.8, moodID: UUID(), updatedAt: Date(timeIntervalSince1970: 10))),
                RemotePerson(id: friend, member: RemoteMember(displayName: "Maya", emoji: "😌", label: "Calm", colorHex: "7EB6B0", note: "Walk", valence: 0.45, moodID: remoteMoodID, updatedAt: Date(timeIntervalSince1970: 40)))
            ]
        )
        let merged = CircleMerge.merging(local, with: remote, currentUserID: me)
        XCTAssertEqual(merged.name, "Saturday")
        XCTAssertEqual(merged.members.count, 2)
        XCTAssertEqual(merged.members[0].latestMood?.note, "mine")
        XCTAssertEqual(merged.members[1].displayName, "Maya")
        XCTAssertEqual(merged.members[1].latestMood?.id, remoteMoodID)
    }

    func testRelayURLBuilderRejectsThePlaceholder() {
        XCTAssertTrue(SyncConfiguration.isPlaceholder(""))
        XCTAssertTrue(SyncConfiguration.isPlaceholder(SyncConfiguration.exampleRelayURL))
        XCTAssertFalse(SyncConfiguration.isPlaceholder("https://mood-sync-demo-default-rtdb.firebaseio.com"))

        XCTAssertThrowsError(try RelayEndpoint.url(base: SyncConfiguration.exampleRelayURL, path: "moodsync/circles/ABCDEF.json", auth: "")) { error in
            XCTAssertEqual(error as? SyncError, .notConfigured)
        }

        let url = try? RelayEndpoint.url(
            base: "https://mood-sync-demo-default-rtdb.firebaseio.com/",
            path: RelayEndpoint.memberPath(code: "ABCDEF", userID: UUID(uuidString: "55555555-5555-4555-8555-555555555555")!),
            auth: "secret token"
        )
        XCTAssertEqual(
            url?.absoluteString,
            "https://mood-sync-demo-default-rtdb.firebaseio.com/moodsync/circles/ABCDEF/members/55555555-5555-4555-8555-555555555555.json?auth=secret%20token"
        )
    }

    func testRelayDecodeSkipsNullAndBadMemberKeys() throws {
        let client = RelayClient()
        let empty = try client.decodeCircle(Data("null".utf8))
        XCTAssertTrue(empty.members.isEmpty)

        let json = """
        {
          "name": "Saturday",
          "members": {
            "55555555-5555-4555-8555-555555555555": {
              "displayName": "Maya",
              "emoji": "😌",
              "label": "Calm",
              "colorHex": "7EB6B0",
              "note": "Walk",
              "valence": 0.45,
              "moodID": "66666666-6666-4666-8666-666666666666",
              "updatedAt": "2026-10-15T18:00:00Z"
            },
            "not-a-uuid": {
              "displayName": "Nope"
            }
          }
        }
        """.data(using: .utf8)!
        let circle = try client.decodeCircle(json)
        XCTAssertEqual(circle.name, "Saturday")
        XCTAssertEqual(circle.members.count, 1)
        XCTAssertEqual(circle.members[0].member.note, "Walk")
        XCTAssertEqual(circle.members[0].member.updatedAt, Date(timeIntervalSince1970: 1_792_087_200))
    }
}

/// Tiny deterministic generator so invite-code tests don't flake.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
