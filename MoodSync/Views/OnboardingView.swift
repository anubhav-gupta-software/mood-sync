import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var includePreview = true
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 8) {
                    ForEach(MoodPreset.allCases.prefix(5)) { preset in
                        Text(preset.emoji)
                            .font(.largeTitle)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Theme.color(hex: preset.colorHex).opacity(0.25)))
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mood Sync")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Share how you are with the people close enough to ask. One tap, a color, a short note.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should they call you?")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .font(.system(.title3, design: .rounded))
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .focused($nameFocused)
                }

                Toggle(isOn: $includePreview) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show a preview circle")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("A few sample friends so the home screen and widgets aren't empty before anyone joins.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .tint(Theme.color(hex: MoodPreset.happy.colorHex))

                FillButton(title: "Continue", systemImage: "arrow.right") {
                    model.completeOnboarding(name: name.trimmingCharacters(in: .whitespacesAndNewlines), includePreview: includePreview)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(24)
        }
        .onAppear { nameFocused = true }
    }
}
