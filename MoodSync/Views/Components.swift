import SwiftUI
import MoodSyncCore

struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.paper.ignoresSafeArea())
    }
}

extension View {
    func paperBackground() -> some View {
        modifier(PaperBackground())
    }
}

struct SectionLabel: View {
    var title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            if let caption {
                Text(caption)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FillButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.ink))
            .foregroundStyle(Theme.paper)
        }
        .buttonStyle(.plain)
    }
}

struct PresetButton: View {
    var preset: MoodPreset
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(preset.emoji)
                    .font(.title2)
                Text(preset.label)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.color(hex: preset.colorHex).opacity(isSelected ? 0.38 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.color(hex: preset.colorHex).opacity(isSelected ? 0.95 : 0), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set mood to \(preset.label)")
    }
}

struct FriendRow: View {
    var name: String
    var emoji: String
    var label: String
    var note: String
    var colorHex: String
    var updatedAt: Date?
    var isPreview: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.color(hex: colorHex).opacity(0.24)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if isPreview {
                        Text("Preview")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.hairline))
                    }
                }
                Text(label)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                if !note.isEmpty {
                    Text(note)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let updatedAt {
                Text(updatedAt, format: .relative(presentation: .named))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 88, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct Card<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill((tint ?? Theme.paper).opacity(tint == nil ? 0 : 0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            }
    }
}
