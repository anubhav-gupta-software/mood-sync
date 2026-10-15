import SwiftUI
import UIKit
import MoodSyncCore

struct CircleView: View {
    @Environment(AppModel.self) private var model
    @State private var showingCreate = false
    @State private var showingJoin = false
    @State private var showingRename = false
    @State private var confirmLeave = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let circle = model.activeCircle {
                    inviteCard(circle)
                    membersCard(circle)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start a circle")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Text("A circle is a small group. You share a code, they join, and everyone sees the latest mood.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                }

                if model.state.circles.count > 1 {
                    otherCircles
                }

                VStack(spacing: 10) {
                    FillButton(title: "New circle", systemImage: "plus") {
                        showingCreate = true
                    }
                    Button("Join with a code") {
                        showingJoin = true
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                    .foregroundStyle(Theme.ink)
                }

                if model.activeCircle != nil {
                    Button(model.activeCircle?.isPreview == true ? "Hide preview circle" : "Leave circle", role: .destructive) {
                        confirmLeave = true
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .navigationTitle("Circle")
        .sheet(isPresented: $showingCreate) {
            NameEntrySheet(title: "New circle", placeholder: "Saturday", button: "Create") { name in
                model.createCircle(named: name)
            }
        }
        .sheet(isPresented: $showingJoin) {
            JoinSheet { code in
                await model.join(code: code)
            }
        }
        .sheet(isPresented: $showingRename) {
            NameEntrySheet(
                title: "Rename circle",
                placeholder: model.activeCircle?.name ?? "Circle",
                button: "Save",
                initial: model.activeCircle?.name ?? ""
            ) { name in
                model.renameActiveCircle(name)
            }
        }
        .confirmationDialog("Leave this circle?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(model.activeCircle?.isPreview == true ? "Hide" : "Leave", role: .destructive) {
                model.leaveActiveCircle()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your check-ins stay on this phone. New moods won't be shared with this circle.")
        }
    }

    private func inviteCard(_ circle: FriendCircle) -> some View {
        Card(tint: Theme.color(hex: model.currentMood?.colorHex ?? MoodPreset.calm.colorHex)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(circle.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if !circle.isPreview {
                        Button("Rename") { showingRename = true }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                }
                if circle.isPreview {
                    Text("This circle is sample data on your phone. It isn't shared.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                } else {
                    Text("Invite code")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                    Text(circle.inviteCode)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(Theme.ink)
                        .accessibilityLabel("Invite code \(circle.inviteCode.map { String($0) }.joined(separator: " "))")
                    Text(syncCaption)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = circle.inviteCode
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        ShareLink(item: shareText(circle)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(Theme.ink)
                }
            }
        }
    }

    private var syncCaption: String {
        switch model.state.sync.mode {
        case .local:
            "Saved on this iPhone. Turn on a relay or iCloud in Settings when you want other phones to see it."
        case .relay:
            SyncConfiguration.isPlaceholder(model.state.sync.relayURL)
                ? "Add the relay URL in Settings so this code works on other phones."
                : "Anyone with this code and the same relay can join."
        case .cloudKit:
            "Anyone with this code, signed into iCloud, can join once CloudKit is enabled."
        }
    }

    private func shareText(_ circle: FriendCircle) -> String {
        "Join my Mood Sync circle \"\(circle.name)\" with the code \(circle.inviteCode)."
    }

    private func membersCard(_ circle: FriendCircle) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("People")
                    .font(.system(.headline, design: .rounded))
                if let me = circle.members.first(where: \.isCurrentUser) {
                    FriendRow(
                        name: "\(me.displayName) (you)",
                        emoji: me.latestMood?.emoji ?? "·",
                        label: me.latestMood?.label ?? "No check-in yet",
                        note: me.latestMood?.note ?? "",
                        colorHex: me.latestMood?.colorHex ?? "A39890",
                        updatedAt: me.latestMood?.createdAt,
                        isPreview: false
                    )
                }
                ForEach(circle.friends) { friend in
                    FriendRow(
                        name: friend.displayName,
                        emoji: friend.latestMood?.emoji ?? "·",
                        label: friend.latestMood?.label ?? "No check-in",
                        note: friend.latestMood?.note ?? "",
                        colorHex: friend.latestMood?.colorHex ?? "A39890",
                        updatedAt: friend.latestMood?.createdAt,
                        isPreview: friend.isPreview
                    )
                }
            }
        }
    }

    private var otherCircles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Switch")
                .font(.system(.headline, design: .rounded))
            ForEach(model.state.circles) { circle in
                Button {
                    model.selectCircle(id: circle.id)
                } label: {
                    HStack {
                        Text(circle.name)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        if circle.isPreview {
                            Text("Preview")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        if circle.id == model.activeCircle?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct NameEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var placeholder: String
    var button: String
    var initial: String = ""
    var onSave: (String) -> Void
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(placeholder, text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.system(.title3, design: .rounded))
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                    .focused($focused)
                FillButton(title: button) {
                    onSave(name)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(20)
            .background(Theme.paper)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                name = initial
                focused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct JoinSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onJoin: (String) async -> String?
    @State private var code = ""
    @State private var working = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ask a friend for their 6-character code.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                TextField("K7M2QP", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(3)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                    .focused($focused)
                    .onChange(of: code) { _, newValue in
                        let normalized = InviteCode.normalize(newValue)
                        if normalized != newValue {
                            code = normalized
                        }
                        if code.count > InviteCode.length {
                            code = String(code.prefix(InviteCode.length))
                        }
                    }
                Text("I, O, 0, and 1 are left out so they're harder to mix up.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                FillButton(title: working ? "Joining…" : "Join") {
                    working = true
                    errorMessage = nil
                    Task {
                        let message = await onJoin(code)
                        working = false
                        if let message {
                            errorMessage = message
                        } else {
                            dismiss()
                        }
                    }
                }
                .disabled(working || !InviteCode.isValid(InviteCode.normalize(code)))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.paper)
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
