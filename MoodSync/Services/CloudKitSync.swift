import CloudKit
import Foundation
import MoodSyncCore

/// Optional iCloud sync. This compiles without the iCloud capability so a free
/// Apple ID can still install the app. Calls fail with a clear message until
/// you switch Config/App.xcconfig to MoodSyncPaid.entitlements on a paid team.
enum CloudKitSync {
    private static let container = CKContainer(identifier: SyncConfiguration.cloudKitContainerID)
    private static var database: CKDatabase { container.publicCloudDatabase }

    static func publishName(_ circle: FriendCircle) async throws {
        try await ensureAccount()
        let recordID = CKRecord.ID(recordName: "circle-\(circle.inviteCode)")
        let record = (try? await database.record(for: recordID))
            ?? CKRecord(recordType: "MoodCircle", recordID: recordID)
        record.setObject(circle.name as NSString, forKey: "name")
        record.setObject(circle.inviteCode as NSString, forKey: "inviteCode")
        _ = try await database.save(record)
    }

    static func publishMember(_ circle: FriendCircle) async throws {
        try await ensureAccount()
        guard let me = circle.members.first(where: { $0.isCurrentUser }) else { return }
        let recordID = CKRecord.ID(recordName: "presence-\(circle.inviteCode)-\(me.id.uuidString)")
        let record = (try? await database.record(for: recordID))
            ?? CKRecord(recordType: "MoodPresence", recordID: recordID)
        record.setObject(circle.inviteCode as NSString, forKey: "circleCode")
        record.setObject(me.id.uuidString as NSString, forKey: "userId")
        record.setObject(me.displayName as NSString, forKey: "displayName")
        if let mood = me.latestMood {
            record.setObject(mood.emoji as NSString, forKey: "emoji")
            record.setObject(mood.label as NSString, forKey: "label")
            record.setObject(mood.colorHex as NSString, forKey: "colorHex")
            record.setObject(mood.note as NSString, forKey: "note")
            record.setObject(mood.valence as NSNumber, forKey: "valence")
            record.setObject(mood.id.uuidString as NSString, forKey: "moodID")
            record.setObject(mood.createdAt as NSDate, forKey: "updatedAt")
        }
        _ = try await database.save(record)
    }

    static func fetchCircle(code: String) async throws -> RemoteCircle {
        try await ensureAccount()
        var name: String?
        let circleID = CKRecord.ID(recordName: "circle-\(code)")
        if let circleRecord = try? await database.record(for: circleID) {
            name = circleRecord["name"] as? String
        }

        let query = CKQuery(recordType: "MoodPresence", predicate: NSPredicate(format: "circleCode == %@", code))
        let matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
        do {
            (matchResults, _) = try await database.records(matching: query)
        } catch {
            throw SyncError.cloudKit(queryMessage(for: error))
        }

        var people: [RemotePerson] = []
        for (_, result) in matchResults {
            if case .success(let record) = result, let person = person(from: record) {
                people.append(person)
            }
        }
        return RemoteCircle(name: name, members: people)
    }

    private static func ensureAccount() async throws {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw SyncError.cloudKitUnavailable
        }
        switch status {
        case .available:
            return
        case .noAccount:
            throw SyncError.cloudKit("Sign in to iCloud on this iPhone, then try again.")
        case .restricted:
            throw SyncError.cloudKit("iCloud is restricted on this iPhone.")
        case .couldNotDetermine, .temporarilyUnavailable:
            throw SyncError.cloudKitUnavailable
        @unknown default:
            throw SyncError.cloudKitUnavailable
        }
    }

    private static func person(from record: CKRecord) -> RemotePerson? {
        guard let idString = record["userId"] as? String, let id = UUID(uuidString: idString) else {
            return nil
        }
        let valence = (record["valence"] as? NSNumber)?.doubleValue
        let moodID = (record["moodID"] as? String).flatMap(UUID.init(uuidString:))
        return RemotePerson(
            id: id,
            member: RemoteMember(
                displayName: record["displayName"] as? String ?? "Friend",
                emoji: record["emoji"] as? String,
                label: record["label"] as? String,
                colorHex: record["colorHex"] as? String,
                note: record["note"] as? String,
                valence: valence,
                moodID: moodID,
                updatedAt: record["updatedAt"] as? Date
            )
        )
    }

    private static func queryMessage(for error: Error) -> String {
        let text = error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("queryable") || lower.contains("index") || lower.contains("not marked") {
            return "CloudKit needs a queryable index on MoodPresence.circleCode. The README lists the fields to add in the dashboard."
        }
        return text
    }
}
