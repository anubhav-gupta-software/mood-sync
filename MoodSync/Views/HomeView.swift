import SwiftUI
import MoodSyncCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingComposer = false

    private var mood: MoodEntry? { model.currentMood }
    private var tintHex: String { mood?.colorHex ?? MoodPreset.happy.colorHex }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                hero
                if let message = model.statusMessage {
                    status(message)
                }
                if let saveError = model.saveError {
                    status(saveError)
                }
                presets
                friends
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingComposer = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Write a mood note")
            }
        }
        .refreshable {
            model.scheduleSync(pushName: false)
            try? await Task.sleep(for: .milliseconds(400))
        }
        .sheet(isPresented: $showingComposer) {
            MoodComposerView(starting: mood)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.selection, trigger: model.state.history.count)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Greeting.text())
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(model.state.profile.resolvedName)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                circleMenu
            }
        }
        .padding(.top, 8)
    }

    private var circleMenu: some View {
        Menu {
            if model.state.circles.isEmpty {
                Text("No circles yet")
            } else {
                ForEach(model.state.circles) { circle in
                    Button {
                        model.selectCircle(id: circle.id)
                    } label: {
                        if circle.id == model.activeCircle?.id {
                            Label(circle.name, systemImage: "checkmark")
                        } else {
                            Text(circle.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(model.activeCircle?.name ?? "Circle")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .accessibilityLabel("Choose a circle")
    }

    private var hero: some View {
        Card(tint: Theme.color(hex: tintHex)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if model.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Spacer()
                    Text(checkedInCaption)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }
                Text(mood?.emoji ?? "✨")
                    .font(.system(size: 84))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                Text(mood?.label ?? "How are you?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(heroDetail)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Add a note") {
                    showingComposer = true
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var heroDetail: String {
        if let note = mood?.note, !note.isEmpty {
            return note
        }
        if mood == nil {
            return "Tap a mood below. That's the whole thing."
        }
        if let created = mood?.createdAt, Date().timeIntervalSince(created) > 18 * 60 * 60 {
            return "It's been a while. One tap updates your circle."
        }
        return "Shared with \(model.activeCircle?.name ?? "your circle")."
    }

    private var checkedInCaption: String {
        guard let created = mood?.createdAt else { return "Not yet today" }
        return created.formatted(.relative(presentation: .named))
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "One tap", caption: "Sets your mood right away. Add a note if you want.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(MoodPreset.allCases) { preset in
                    PresetButton(preset: preset, isSelected: mood?.label == preset.label && mood?.emoji == preset.emoji) {
                        model.setMood(preset)
                    }
                }
            }
        }
    }

    private var friends: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(
                title: "Circle",
                caption: model.activeCircle?.isPreview == true
                    ? "These are samples. Create a real circle when you're ready."
                    : "Latest mood from each person."
            )
            if model.friends.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.activeCircle == nil ? "No circle yet" : "It's just you so far")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("Share an invite code from the Circle tab. Friends who join it show up here.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                    }
                }
            } else {
                Card {
                    VStack(spacing: 16) {
                        ForEach(model.friends) { friend in
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
        }
    }

    private func status(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.color(hex: "E0A35A").opacity(0.25)))
    }
}
