# Mood Sync

Mood Sync is a small iPhone app for close friends. You share how you are — an emoji, a color, and a short note — in one tap. A Home Screen widget and a Lock Screen widget show each friend's latest mood.

Circles are little groups. You create one, share a 6-character invite code, and friends join with that code. Your own check-ins are kept on the phone and charted over the week, the month, or everything you've logged. A daily reminder can nudge you to check in. The reminder is a local notification, so it does not need push.

The app runs with no accounts and no API keys. Sync to other phones is optional.

## What you can do

- Set a mood in one tap from ten presets, or open the composer for your own emoji, color, note, and a rough high-to-low feeling.
- Create a circle, copy or share the invite code, and join someone else's code.
- Start with a preview circle (Maya, Leo, Priya, and Sam) so the home screen isn't empty. Those people are samples and never leave the phone.
- See a simple history chart and the list of check-ins.
- Turn on a daily check-in reminder.
- Add a widget: small, medium, and large on the Home Screen, plus circular, rectangular, and inline on the Lock Screen.

## Requirements

- A Mac with Xcode 16 or later
- An iPhone running iOS 17 or later
- A free Apple ID, if you only want to install it on your own phone

You do not need a paid Apple Developer Program membership to build or install the default project.

## Install it on your iPhone with a free Apple ID

1. Install Xcode from the Mac App Store. Open it once and let it finish installing the extra components.
2. In Xcode, open **Settings → Accounts** and sign in with your Apple ID if you haven't already. Xcode creates a free "Personal Team" for you.
3. Clone this repo and open `MoodSync.xcodeproj` (double-click it, or choose File → Open).
4. Connect the iPhone, unlock it, and tap Trust on the phone if it asks. In Xcode's toolbar, set the run destination to that iPhone, not a simulator.
5. Click the Mood Sync project in the navigator, select the **MoodSync** target, and open **Signing & Capabilities**.
6. Check **Automatically manage signing**. Choose your Personal Team.
7. Select the **MoodSyncWidget** target and choose the same team.
8. If Xcode says the bundle identifier is already in use, change it in `Config/App.xcconfig`:

   ```
   PRODUCT_BUNDLE_IDENTIFIER = app.moodsync.yourname
   ```

   Then set the widget id in `Config/Widget.xcconfig` to that same id plus `.widget`:

   ```
   PRODUCT_BUNDLE_IDENTIFIER = app.moodsync.yourname.widget
   ```

9. Press Run. The first build can take a minute while Swift Package Manager resolves `MoodSyncCore`.
10. If the iPhone says the developer isn't trusted, open **Settings → General → VPN & Device Management**, tap your Apple ID, and tap Trust.
11. A free provisioning profile lasts about 7 days. When the app stops opening, connect the phone and press Run again.

The widget is a second bundle id. That's expected. Both targets need the same team.

Leave the entitlements files as they are for a free Apple ID. The default files are empty on purpose. Personal teams cannot sign App Groups, iCloud, push notifications, or associated domains, and Xcode will refuse to install the app if those capabilities are turned on.

## Widgets

After the app is on the phone:

- Home Screen: touch and hold the background, tap +, search for Mood Sync, and add **Mood Circle**. Small shows one mood, medium shows you plus a few friends, large shows the circle.
- Lock Screen: touch and hold the Lock Screen, tap Customize, tap the Lock Screen area, then add the circular, rectangular, or inline Mood Sync widget.

The widget gallery shows sample friends so you can see the layout. On the Home Screen and Lock Screen, live moods need a shared App Group. A free personal team cannot sign that capability, so until you turn it on the widget installs and then says the App Group is off.

### Turn on live widget data

This needs the paid [Apple Developer Program](https://developer.apple.com/programs/) ($99/year).

1. Enroll, then in Xcode switch both targets from your Personal Team to that paid team.
2. In `Config/App.xcconfig`, comment out the default entitlements line and use:

   ```
   CODE_SIGN_ENTITLEMENTS = MoodSync/MoodSyncAppGroup.entitlements
   ```

   Use `MoodSync/MoodSyncPaid.entitlements` instead if you also want iCloud. That file includes the App Group and CloudKit.

3. In `Config/Widget.xcconfig`:

   ```
   CODE_SIGN_ENTITLEMENTS = MoodSyncWidget/MoodSyncWidgetAppGroup.entitlements
   ```

4. Build and run. Automatic signing usually registers the group `group.app.moodsync.shared`. If it doesn't, add the **App Groups** capability on both targets and use that exact id.
5. Open the app and check in once. If a widget was already on the Home Screen, remove it and add it again.

The group id lives in `Packages/MoodSyncCore/Sources/MoodSyncCore/AppGroup.swift` and in the entitlement files. If you change it, change it in all of those places.

## Sync

Settings → Sync has three modes. The default is **On this iPhone**. Nothing is uploaded.

### Shared relay (no SDK, no keys required to compile)

This talks to a [Firebase Realtime Database](https://firebase.google.com/docs/database) over plain HTTPS. You don't add the Firebase SDK and you don't commit a `GoogleService-Info.plist`.

1. Create a Firebase project and a Realtime Database.
2. For a private prototype, you can start with open rules. Lock them down before anyone you don't trust has the URL.

   ```json
   {
     "rules": {
       "moodsync": {
         ".read": true,
         ".write": true
       }
     }
   }
   ```

   Open rules mean anyone with the database URL can read and write those paths. That's fine for trying the app with friends. It is not fine for a public launch. Add auth and tighten the rules before you share the URL widely. If you do, paste the database secret or auth token into Settings. The token is stored in the iPhone keychain, not in the mood file.

3. Copy the database URL. It looks like `https://your-project-default-rtdb.firebaseio.com`.
4. On each phone, choose **Shared relay**, paste that URL, and save the token if you use one.
5. Create a circle on one phone and join with the code on the others. Pull to refresh, or tap **Sync now**.

The app writes here:

```
PUT {database}/moodsync/circles/{CODE}/name.json
PUT {database}/moodsync/circles/{CODE}/members/{USER-UUID}.json
GET {database}/moodsync/circles/{CODE}.json
```

A member looks like:

```json
{
  "displayName": "Anubhav",
  "emoji": "😊",
  "label": "Happy",
  "colorHex": "F5C451",
  "note": "Coffee was good",
  "valence": 0.9,
  "moodID": "66666666-6666-4666-8666-666666666666",
  "updatedAt": "2026-10-15T18:00:00Z"
}
```

The placeholder `https://YOUR-PROJECT-default-rtdb.firebaseio.com` is not a real server. While that text is still in the field, the app stays on this phone and tells you the relay isn't configured.

`http://` URLs are allowed so you can point the app at a small test server. Use `https://` for Firebase.

### iCloud (paid developer account)

CloudKit is in the app, and it compiles without the iCloud entitlement, so a free Apple ID can still install the build. Calls fail with a short explanation until the capability is signed.

1. Use a paid team.
2. Point `Config/App.xcconfig` at `MoodSync/MoodSyncPaid.entitlements`.
3. In the [CloudKit console](https://icloud.developer.apple.com/) for container `iCloud.app.moodsync.ios`, the development schema is created the first time you save. Add a **queryable** index on `MoodPresence.circleCode` or fetches will fail.

Record types the app uses:

| Type | Fields |
| --- | --- |
| `MoodCircle` | `name` (String), `inviteCode` (String) |
| `MoodPresence` | `circleCode` (String, queryable), `userId`, `displayName`, `emoji`, `label`, `colorHex`, `note`, `valence` (Double), `moodID`, `updatedAt` (Date/Time) |

The widget does not talk to CloudKit itself. The app writes the latest circle into the App Group, and the widget reads that file. Turn on the App Group as well if you want the widget to update after an iCloud sync.

If you change the app's bundle id, change the iCloud container to `iCloud.` plus the new bundle id, in both `MoodSyncPaid.entitlements` and `SyncConfiguration.cloudKitContainerID`.

## Reminders

Settings → Reminders → Daily reminder, then pick a time. iOS will ask for notification permission. If you decline, the toggle turns back off and you can open iOS Settings from that screen.

This uses a repeating local notification (`UNCalendarNotificationTrigger`). It does not use the Push Notifications capability, so it works with a free Apple ID. The phone has to be on, and iOS may delay the alert a little, the way it does for any local notification.

## Shared package tests

The models, the chart bucketing, invite codes, and the relay URL builder live in `Packages/MoodSyncCore`. On a Mac, or anywhere Swift is installed:

```sh
swift test --package-path Packages/MoodSyncCore
```

## Regenerate the Xcode project

`project.yml` is the XcodeGen spec. The committed `MoodSync.xcodeproj` was generated from it. After you add files, either let Xcode's synchronized folders pick them up (the app and widget folders are folder references of that kind) or regenerate:

```sh
brew install xcodegen
xcodegen generate
```

Signing overrides live in `Config/App.xcconfig` and `Config/Widget.xcconfig`, not buried in the project file. Edit those when you change the bundle id or turn on the App Group.

## Move to TestFlight later

TestFlight needs the paid Apple Developer Program. A free Apple ID cannot upload builds.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/).
2. In [App Store Connect](https://appstoreconnect.apple.com), create an app whose bundle id matches `PRODUCT_BUNDLE_IDENTIFIER` in `Config/App.xcconfig`.
3. If you want testers to see live widgets, switch the entitlements to the App Group files before you archive. See [Turn on live widget data](#turn-on-live-widget-data).
4. In Xcode, select **Any iOS Device (arm64)** as the destination. Product → Archive.
5. In the Organizer, click **Distribute App → App Store Connect → Upload**.
6. The target sets `ITSAppUsesNonExemptEncryption` to NO. When App Store Connect asks about export compliance, you can answer that the app only uses standard HTTPS, as long as that is still true.
7. Open the TestFlight tab. Internal testers (people on your App Store Connect team) can install as soon as the build finishes processing. External testers need a short Beta App Review.
8. Testers install Apple's TestFlight app, accept the invite, and install Mood Sync. A TestFlight build is available for 90 days.

The widget extension is uploaded as part of the app archive. You don't create a separate App Store record for it.

## Project layout

```
MoodSync.xcodeproj          app and widget targets
project.yml                 XcodeGen spec
Config/                     bundle ids and entitlements switch
MoodSync/                   SwiftUI app
MoodSyncWidget/             Home Screen and Lock Screen widget
Packages/MoodSyncCore/      models, storage, relay client, widget snapshot
```

Moods are stored in Application Support as `state.json`. When the App Group is entitled, the app also writes `widget-snapshot.json` into the shared container. The widget only reads that file.

## What needs a paid developer account

| Capability | Free Apple ID | Paid program |
| --- | --- | --- |
| Install on your own iPhone from Xcode | Yes, about 7 days | Yes |
| Local check-in reminders | Yes | Yes |
| Firebase relay over HTTPS | Yes | Yes |
| App Group, so the widget shows live moods | No | Yes |
| iCloud / CloudKit | No | Yes |
| Push notifications | Not used | Not used |
| TestFlight and the App Store | No | Yes |
