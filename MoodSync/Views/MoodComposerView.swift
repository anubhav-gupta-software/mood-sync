import SwiftUI
import MoodSyncCore

struct MoodComposerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var emoji: String
    @State private var label: String
    @State private var colorHex: String
    @State private var note: String
    @State private var valence: Double

    init(starting: MoodEntry?) {
        let preset = MoodPreset.happy
        _emoji = State(initialValue: starting?.emoji ?? preset.emoji)
        _label = State(initialValue: starting?.label ?? preset.label)
        _colorHex = State(initialValue: starting?.colorHex ?? preset.colorHex)
        _note = State(initialValue: starting?.note ?? "")
        _valence = State(initialValue: starting?.valence ?? preset.valence)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(emoji.isEmpty ? "✨" : emoji)
                        .font(.system(size: 72))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emoji")
                            .font(.system(.headline, design: .rounded))
                        TextField("Emoji", text: $emoji)
                            .font(.title2)
                            .padding(14)
                            .background(fieldBackground)
                            .onChange(of: emoji) { _, newValue in
                                if newValue.count > 8 {
                                    emoji = String(newValue.prefix(8))
                                }
                            }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(MoodPreset.allCases) { preset in
                                Button {
                                    emoji = preset.emoji
                                    label = preset.label
                                    colorHex = preset.colorHex
                                    valence = preset.valence
                                } label: {
                                    Text(preset.emoji)
                                        .font(.title2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Theme.color(hex: preset.colorHex).opacity(emoji == preset.emoji ? 0.4 : 0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(preset.label)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Label")
                            .font(.system(.headline, design: .rounded))
                        TextField("Happy", text: $label)
                            .font(.system(.body, design: .rounded))
                            .padding(14)
                            .background(fieldBackground)
                            .onChange(of: label) { _, newValue in
                                if newValue.count > 24 {
                                    label = String(newValue.prefix(24))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(.headline, design: .rounded))
                        HStack(spacing: 10) {
                            ForEach(MoodPreset.allCases) { preset in
                                Button {
                                    colorHex = preset.colorHex
                                } label: {
                                    Circle()
                                        .fill(Theme.color(hex: preset.colorHex))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle().strokeBorder(Theme.ink.opacity(colorHex == preset.colorHex ? 0.9 : 0), lineWidth: 2)
                                        )
                                        .padding(2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(preset.label) color")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Note")
                                .font(.system(.headline, design: .rounded))
                            Spacer()
                            Text("\(note.count)/80")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondary)
                                .monospacedDigit()
                        }
                        TextField("A few words", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.system(.body, design: .rounded))
                            .padding(14)
                            .background(fieldBackground)
                            .onChange(of: note) { _, newValue in
                                if newValue.count > 80 {
                                    note = String(newValue.prefix(80))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Roughly how does this feel?")
                            .font(.system(.headline, design: .rounded))
                        Slider(value: $valence, in: -1...1)
                            .tint(Theme.color(hex: colorHex))
                        HStack {
                            Text("Low")
                            Spacer()
                            Text("High")
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                    }

                    FillButton(title: "Share mood", systemImage: "paperplane.fill") {
                        model.setMood(emoji: emoji, label: label, colorHex: colorHex, note: note, valence: valence)
                        dismiss()
                    }
                    .disabled(emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.bottom, 12)
                }
                .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle("Your mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}
