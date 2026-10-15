import Foundation
import MoodSyncCore
import Observation
import WidgetKit

@MainActor
@Observable
final class AppModel {
    private let store: MoodStore
    private let relay = RelayClient()
    private var syncGeneration = 0

    private(set) var state: AppState
    var isSyncing = false
    var statusMessage: String?
    var reminderMessage: String?
    var saveError: String?
    var lastSyncedAt: Date?

    init(store: MoodStore = MoodStore(), state: AppState? = nil) {
        self.store = store
        self.state = state ?? store.load()
    }

    var activeCircle: FriendCircle? { state.activeCircle }

    var currentMood: MoodEntry? {
        if let mood = activeCircle?.members.first(where: \.isCurrentUser)?.latestMood {
            return mood
        }
        return state.history.last
    }

    var friends: [CircleMember] {
        activeCircle?.friends ?? []
    }

    var widgetSharingAvailable: Bool { AppGroup.isAvailable }

    func completeOnboarding(name: String, includePreview: Bool) {
        state.profile.displayName = String(name.prefix(24))
        state.profile.includePreviewCircle = includePreview
        state.profile.hasCompletedOnboarding = true
        state = SeedData.refreshingPreview(in: state)
        persist()
    }

    func setMood(_ preset: MoodPreset) {
        setMood(
            emoji: preset.emoji,
            label: preset.label,
            colorHex: preset.colorHex,
            note: "",
            valence: preset.valence
        )
    }

    func setMood(emoji: String, label: String, colorHex: String, note: String, valence: Double) {
        let entry = MoodEntry(emoji: emoji, label: label, colorHex: colorHex, note: note, valence: valence)
        state.history.append(entry)
        if state.history.count > 500 {
            state.history.removeFirst(state.history.count - 500)
        }
        stampCurrentUser(with: entry)
        persist()
        scheduleSync(pushName: false)
    }

    func createCircle(named rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let circle = FriendCircle(
            name: trimmed.isEmpty ? "My circle" : trimmed,
            inviteCode: InviteCode.make(),
            members: [currentMember(mood: state.history.last)]
        )
        state.circles.append(circle)
        state.activeCircleID = circle.id
        persist()
        scheduleSync(pushName: true)
    }

    func join(code raw: String) async -> String? {
        let code = InviteCode.normalize(raw)
        guard InviteCode.isValid(code) else {
            return SyncError.invalidCode.errorDescription
        }
        if let existing = state.circles.first(where: { !$0.isPreview && $0.inviteCode == code }) {
            state.activeCircleID = existing.id
            persist()
            scheduleSync(pushName: false)
            return nil
        }

        var circle = FriendCircle(
            name: "Circle \(code)",
            inviteCode: code,
            members: [currentMember(mood: state.history.last)]
        )
        var shouldPushName = true
        if state.sync.mode == .relay, !SyncConfiguration.isPlaceholder(state.sync.relayURL) {
            do {
                let remote = try await relay.fetchCircle(code: code, settings: state.sync, auth: RelaySecret.load())
                circle = CircleMerge.merging(circle, with: remote, currentUserID: state.profile.id)
                shouldPushName = remote.name?.isEmpty != false
            } catch {
                state.circles.append(circle)
                state.activeCircleID = circle.id
                persist()
                return "Saved the circle on this phone. \(error.localizedDescription)"
            }
        } else if state.sync.mode == .cloudKit {
            do {
                let remote = try await CloudKitSync.fetchCircle(code: code)
                circle = CircleMerge.merging(circle, with: remote, currentUserID: state.profile.id)
                shouldPushName = remote.name?.isEmpty != false
            } catch {
                state.circles.append(circle)
                state.activeCircleID = circle.id
                persist()
                return "Saved the circle on this phone. \(error.localizedDescription)"
            }
        }

        state.circles.append(circle)
        state.activeCircleID = circle.id
        persist()
        scheduleSync(pushName: shouldPushName)
        return nil
    }

    func leaveActiveCircle() {
        guard let circle = activeCircle else { return }
        if circle.isPreview {
            setIncludePreview(false)
            return
        }
        state.circles.removeAll { $0.id == circle.id }
        if state.activeCircleID == circle.id {
            state.activeCircleID = state.circles.first?.id
        }
        persist()
    }

    func selectCircle(id: UUID) {
        guard state.circles.contains(where: { $0.id == id }) else { return }
        state.activeCircleID = id
        persist()
        scheduleSync(pushName: false)
    }

    func renameActiveCircle(_ raw: String) {
        guard var circle = activeCircle, !circle.isPreview else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        circle.name = String(trimmed.prefix(32))
        replace(circle)
        persist()
        scheduleSync(pushName: true)
    }

    func setDisplayName(_ raw: String) {
        state.profile.displayName = String(raw.prefix(24))
        for index in state.circles.indices {
            guard let me = state.circles[index].members.firstIndex(where: \.isCurrentUser) else { continue }
            state.circles[index].members[me].displayName = state.profile.resolvedName
        }
        persist()
    }

    func setIncludePreview(_ include: Bool) {
        state.profile.includePreviewCircle = include
        state = SeedData.refreshingPreview(in: state)
        persist()
    }

    func setSyncMode(_ mode: SyncMode) {
        state.sync.mode = mode
        statusMessage = nil
        persist()
    }

    func setRelayURL(_ url: String) {
        state.sync.relayURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func updateReminders(enabled: Bool, hour: Int, minute: Int) async {
        state.profile.reminderHour = min(23, max(0, hour))
        state.profile.reminderMinute = min(59, max(0, minute))
        guard enabled else {
            state.profile.remindersEnabled = false
            reminderMessage = nil
            persist()
            NotificationScheduler.cancel()
            return
        }
        let allowed = await NotificationScheduler.requestPermission()
        if allowed {
            state.profile.remindersEnabled = true
            reminderMessage = nil
            persist()
            NotificationScheduler.schedule(hour: state.profile.reminderHour, minute: state.profile.reminderMinute)
        } else {
            state.profile.remindersEnabled = false
            reminderMessage = "Notifications are off for Mood Sync. Turn them on in iOS Settings, then come back."
            persist()
        }
    }

    func restoreRemindersIfNeeded() async {
        guard state.profile.remindersEnabled else { return }
        let status = await NotificationScheduler.authorizationStatus()
        if status == .authorized || status == .provisional || status == .ephemeral {
            NotificationScheduler.schedule(hour: state.profile.reminderHour, minute: state.profile.reminderMinute)
        }
    }

    func scheduleSync(pushName: Bool) {
        syncGeneration += 1
        let generation = syncGeneration
        Task {
            await syncActiveCircle(pushName: pushName, generation: generation)
        }
    }

    func syncActiveCircle(pushName: Bool, generation: Int) async {
        guard var circle = activeCircle, !circle.isPreview else {
            if generation == syncGeneration { isSyncing = false }
            return
        }
        switch state.sync.mode {
        case .local:
            if generation == syncGeneration { isSyncing = false }
            return
        case .relay:
            if SyncConfiguration.isPlaceholder(state.sync.relayURL) {
                statusMessage = SyncError.notConfigured.errorDescription
                return
            }
            isSyncing = true
            defer { if generation == syncGeneration { isSyncing = false } }
            do {
                let auth = RelaySecret.load()
                if pushName {
                    try await relay.publishName(circle: circle, settings: state.sync, auth: auth)
                }
                guard generation == syncGeneration else { return }
                try await relay.publishMember(circle: circle, settings: state.sync, auth: auth)
                guard generation == syncGeneration else { return }
                let remote = try await relay.fetchCircle(code: circle.inviteCode, settings: state.sync, auth: auth)
                guard generation == syncGeneration else { return }
                circle = CircleMerge.merging(circle, with: remote, currentUserID: state.profile.id)
                replace(circle)
                persist()
                lastSyncedAt = Date()
                statusMessage = nil
            } catch {
                guard generation == syncGeneration else { return }
                statusMessage = error.localizedDescription
            }
        case .cloudKit:
            isSyncing = true
            defer { if generation == syncGeneration { isSyncing = false } }
            do {
                if pushName {
                    try await CloudKitSync.publishName(circle)
                }
                guard generation == syncGeneration else { return }
                try await CloudKitSync.publishMember(circle)
                guard generation == syncGeneration else { return }
                let remote = try await CloudKitSync.fetchCircle(code: circle.inviteCode)
                guard generation == syncGeneration else { return }
                circle = CircleMerge.merging(circle, with: remote, currentUserID: state.profile.id)
                replace(circle)
                persist()
                lastSyncedAt = Date()
                statusMessage = nil
            } catch {
                guard generation == syncGeneration else { return }
                statusMessage = error.localizedDescription
            }
        }
    }

    private func stampCurrentUser(with mood: MoodEntry) {
        guard var circle = activeCircle else { return }
        if let index = circle.members.firstIndex(where: \.isCurrentUser) {
            circle.members[index].latestMood = mood
            circle.members[index].displayName = state.profile.resolvedName
        } else {
            circle.members.insert(currentMember(mood: mood), at: 0)
        }
        replace(circle)
    }

    private func currentMember(mood: MoodEntry?) -> CircleMember {
        CircleMember(
            id: state.profile.id,
            displayName: state.profile.resolvedName,
            isCurrentUser: true,
            isPreview: false,
            latestMood: mood
        )
    }

    private func replace(_ circle: FriendCircle) {
        guard let index = state.circles.firstIndex(where: { $0.id == circle.id }) else { return }
        state.circles[index] = circle
        state.activeCircleID = circle.id
    }

    private func persist() {
        do {
            try store.save(state)
            saveError = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            saveError = "Couldn't save on this iPhone."
        }
    }

    static func preview() -> AppModel {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoodSyncPreview-\(UUID().uuidString)", isDirectory: true)
        var state = AppState.fresh()
        state.profile.displayName = "Alex"
        state.profile.hasCompletedOnboarding = true
        state.profile.remindersEnabled = true
        state.history = SeedData.sampleHistory()
        let saturday = FriendCircle(
            name: "Saturday",
            inviteCode: "K7M2QP",
            members: [
                CircleMember(
                    id: state.profile.id,
                    displayName: "Alex",
                    isCurrentUser: true,
                    isPreview: false,
                    latestMood: MoodPreset.happy.entry(note: "Coffee was good")
                ),
                CircleMember(
                    id: SeedData.mayaID,
                    displayName: "Maya",
                    isCurrentUser: false,
                    isPreview: false,
                    latestMood: MoodPreset.calm.entry(note: "Slow morning", at: Date().addingTimeInterval(-1800))
                ),
                CircleMember(
                    id: SeedData.leoID,
                    displayName: "Leo",
                    isCurrentUser: false,
                    isPreview: false,
                    latestMood: MoodPreset.excited.entry(note: "Show tonight", at: Date().addingTimeInterval(-7200))
                )
            ]
        )
        state.circles.append(saturday)
        state.activeCircleID = saturday.id
        return AppModel(store: MoodStore(directory: directory), state: state)
    }
}
