import SwiftUI
import UIKit
import MoodSyncCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var relayAuth = ""
    @State private var authSaved = false

    var body: some View {
        Form {
            Section("You") {
                TextField("Name", text: Binding(
                    get: { model.state.profile.displayName },
                    set: { model.setDisplayName($0) }
                ))
                .textInputAutocapitalization(.words)
            }

            Section {
                Toggle("Daily reminder", isOn: Binding(
                    get: { model.state.profile.remindersEnabled },
                    set: { enabled in
                        Task {
                            await model.updateReminders(
                                enabled: enabled,
                                hour: model.state.profile.reminderHour,
                                minute: model.state.profile.reminderMinute
                            )
                        }
                    }
                ))
                DatePicker(
                    "Time",
                    selection: reminderBinding,
                    displayedComponents: .hourAndMinute
                )
                if let reminderMessage = model.reminderMessage {
                    Text(reminderMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("This is a local notification on this iPhone. It doesn't need a paid developer account or push notifications.")
            }

            Section {
                Picker("Sync", selection: Binding(
                    get: { model.state.sync.mode },
                    set: { model.setSyncMode($0) }
                )) {
                    ForEach(SyncMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                switch model.state.sync.mode {
                case .local:
                    Text("Moods stay on this iPhone. Preview friends are samples. A real circle gets a code you can use once a relay or iCloud is on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .relay:
                    TextField(SyncConfiguration.exampleRelayURL, text: Binding(
                        get: { model.state.sync.relayURL },
                        set: { model.setRelayURL($0) }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    SecureField("Optional auth token", text: $relayAuth)
                    Button(authSaved ? "Token saved" : "Save token") {
                        RelaySecret.save(relayAuth)
                        authSaved = true
                    }
                    Text("Use a Firebase Realtime Database URL. No SDK and no GoogleService-Info.plist. The README has the rules and the JSON shape. Leave the URL as the placeholder to stay local.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .cloudKit:
                    Text("iCloud uses CloudKit. A free Apple ID can build this target, but signing the iCloud capability needs the paid Apple Developer Program. Switch Config/App.xcconfig to MoodSyncPaid.entitlements after you enroll. The container id is \(SyncConfiguration.cloudKitContainerID).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    model.scheduleSync(pushName: true)
                } label: {
                    if model.isSyncing {
                        HStack {
                            ProgressView()
                            Text("Syncing…")
                        }
                    } else {
                        Text("Sync now")
                    }
                }
                .disabled(model.state.sync.mode == .local || model.isSyncing || model.activeCircle?.isPreview == true)

                if let status = model.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let lastSyncedAt = model.lastSyncedAt {
                    Text("Last sync \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Sync")
            }

            Section {
                if model.widgetSharingAvailable {
                    Label("The widget can read your circle.", systemImage: "checkmark.circle.fill")
                } else {
                    Text("The widget is part of the app, but a free personal team can't sign the App Group, so the widget can't see live moods yet. After you join the paid program, point the xcconfig files at the App Group entitlements and rebuild. The README has the steps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Widgets")
            }

            Section {
                Toggle("Preview circle", isOn: Binding(
                    get: { model.state.profile.includePreviewCircle },
                    set: { model.setIncludePreview($0) }
                ))
            } footer: {
                Text("Sample friends named Maya, Leo, Priya, and Sam. They never leave this phone.")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Text("Mood Sync keeps your check-ins on this phone. A relay or iCloud is only used when you turn it on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .onAppear {
            relayAuth = RelaySecret.load()
        }
    }

    private var reminderBinding: Binding<Date> {
        Binding(
            get: {
                var parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                parts.hour = model.state.profile.reminderHour
                parts.minute = model.state.profile.reminderMinute
                return Calendar.current.date(from: parts) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                Task {
                    await model.updateReminders(
                        enabled: model.state.profile.remindersEnabled,
                        hour: parts.hour ?? 20,
                        minute: parts.minute ?? 0
                    )
                }
            }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
