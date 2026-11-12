# Militant - Mobile App

<p align="center">
  <img src="assets/logo.svg" alt="Militant Logo" width="200"/>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat&logo=flutter" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat&logo=dart" alt="Dart"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-red?style=flat" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=flat&logo=android" alt="Android">
  <img src="https://img.shields.io/badge/iOS-Coming%20Soon-999999?style=flat&logo=apple" alt="iOS">
</p>

<p align="center">
  Flutter mobile app for the decentralized activist social network
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.militant.militant_flutter&pcampaignid=web_share">
    <img src="https://img.shields.io/badge/Google%20Play-Download-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Get it on Google Play">
  </a>
  <a href="https://apkpure.com/p/com.militant.militant_flutter">
    <img src="assets/apkpure-logo.svg" alt="Available on APKPure" height="40">
  </a>
</p>

---

## Description

Militant is a decentralized social network designed for activist movements and political organizations. This mobile app lets you connect to any self-hosted Militant instance.

Current version: **1.1.0+141**.


## What's new in 1.1.0 (build 141)

- Tapping a notification while the app is closed opens the right conversation, post or profile again, instead of the home feed.
- Comments are shown as reply threads on posts, groups and pages, and every page of comments is loaded.
- The French interface uses the informal "tu" everywhere.
- Text fields share one look that follows the visual identity.
- Accessibility: page rows and follow buttons are announced by screen readers.


## What's new in 1.1.0 (build 140)

- New high-readability red and black visual identity (Archivo and Atkinson Hyperlegible Next).
- Redesigned visual components: cut-corner cards, status stamps and smooth micro-animations.
- Improved image caching, progressive loading and online presence indicator.
- Stronger accessibility (48 dp touch targets, WCAG AA contrast, respect for reduced motion).


## What's new in 1.1.0 (build 139)

- Harmonized navigation and interface for more direct access to the main areas.
- Better support for light and dark themes, accessibility and loading states.
- More visible offline mode and more reliable media loading.
- Saving posts with immediate confirmation and the option to undo.


## What's new in 1.0.9 (build 138)

- **Reliable calls and notifications**: fixes for receiving incoming calls and notifications, with **OneSignal** restored as the default choice in the Google Play edition.
- **Mentions**: mentioned profiles now show their avatar and the link correctly opens their profile.
- **Two separate binaries**: the F-Droid binary is built without the OneSignal SDK; the Google Play APK/AAB keeps OneSignal. The build script automatically picks the matching dependency manifest.

- **Email Notification Management & Interaction Controls (Build 136)**:
  - **Dedicated email toggle**: the switch is back in Settings > Notifications to turn email alerts on or off directly from the mobile app.
  - **Strict respect for interaction preferences**: turning off "Like" (or comments, messages...) now prevents unwanted emails or push notifications for every like.
  - **Two-way sync**: notification preferences are automatically aligned between the mobile app and the web profile.
  - **Interaction settings always available**: fine-grained interaction settings stay visible and configurable even when the main push is turned off.
- **De-Googled Push Notifications (ntfy) & Dual Delivery**:
  - Full support for a self-hosted, de-Googled push notification server via [ntfy](https://ntfy.sh/) (`push.revlibertaire.com`).
  - Real-time WebSocket connection / persistent HTTP stream with no dependency on Google Play Services or Firebase.
  - Provider selector in Settings: **ntfy**, **OneSignal** or **both at the same time** (dual delivery).
  - Support for incoming audio & video calls with ntfy: tapping "Answer" opens the call screen directly.
  - Proactive Android 13+ permission request (`POST_NOTIFICATIONS`) at startup and when preferences change.
- **F-Droid (Free) & Google Play Store Variants**:
  - **F-Droid edition** (`FDROID_BUILD=true`): 100% free and de-Googled, Firebase services disabled, streamlined settings without proprietary options.
  - **Play Store edition** (`FDROID_BUILD=false`): OneSignal (Google FCM) integration for Play Store distribution.
  - Both versions can coexist on the same test device thanks to a separate `applicationId` (`.fdroid`).
  - Automated build scripts in the `scripts/` folder (`build_fdroid.sh` and `build_playstore.sh`).
- **Fediverse & Profile**:
  - The email address on the profile is replaced by the full Fediverse handle (e.g. `@username@militant.revlibertaire.com`).
  - Tap the Fediverse handle to copy it straight to the clipboard, with confirmation.
  - Fixes and improvements to the Fediverse screen and decentralized profile navigation.
  - Smooth infinite scrolling (automatic pagination) added for posts on profiles.
- **Notifications & Messaging**:
  - Tapping a push notification for a private or group message automatically opens the conversation (`ChatScreen` and `GroupChatScreen`).
  - Dynamic resolution of the other person's avatar and username in the chat title bar.
  - Safe and resilient JSON decoding in the API client to avoid errors when receiving server data.
- **Voice & Video Calls (WebRTC)**:
  - Full support for long calls: TURN relay extended to 24h without interruption.
  - Optimized loading and resizing of incoming call avatars with Coil 2.7.0 (saves RAM).
- **Android 15 Compliance & Performance**:
  - Native support for Android 15 edge-to-edge (`Edge-to-Edge`) and cleanup of deprecated system APIs.
  - R8 optimizations (fullMode) and resource shrinking.
  - App version synced to `1.0.9` (version code 138).

## What's new in 1.0.8

- Optimization and full internationalization of the group search bar (Facebook style) and messages (French, English, Spanish)
- Open a user's profile by tapping their name/avatar from messages, invitations and member lists.
- Fixed account switching and logout showing on other people's profiles (now only visible on your own profile).
- Password reset from the login screen.
- Quick account switching with locally saved accounts.
- Add another account without logging out first.
- The active session is protected while adding or switching accounts.
- Fixed cases where a local account could disappear after adding another account.
- Version shown in **About** synced with `1.0.8`.
- Android release build generated as an APK and a Play Store App Bundle.

## Features


### Authentication & Accounts
- **Forgot password**: request a reset link directly from the login screen.
- **Quick accounts**: logged-in accounts are saved locally so you can switch quickly between several profiles.
- **Add an account**: log in to another account without manually logging out of the current one.
- **Session protection**: if a saved session has expired, the app restores the previous session and asks you to log in again.

### Full Social Network
- **Posts**: create, edit and delete posts with multimedia support (images, videos, audio)
- **Interactions**: likes, comments, shares, reactions
- **Profiles**: full customization with avatar, banner, bio and social links
- **Activist badges**: badge system exclusive to the mobile app (Militant, Antifa, Anarchist, CNT-AIT, CNT-F, CNT-SO, FA, OCL, CGA, UCL, FLL, SLM, IWA-AIT, IWW, IAF-IFA, CNT-AIT-E, ULET-AIT)

### Communication
- **Private messages**: one-to-one and group conversations in real time
- **De-Googled push notifications**: alerts through a self-hosted ntfy server (no Google account, no trackers) or OneSignal
- **WebRTC calls**: encrypted peer-to-peer audio and video calls with incoming call notifications and direct answer
- **Mentions**: mention other users with @
- **Clickable links**: automatic URL detection with preview cards for social networks

### Groups & Events
- **Groups**: create and join activist groups with private membership and invitations.
- **Events**: organize and take part in local or national activist events.
- **Stories**: share ephemeral moments (24h) with video preview.
- **Lives (v1.0.6)**: live streams with community moderation and real-time guest management.

### Fediverse
- **Mobile Fediverse space**: dedicated **Feed**, **Profiles**, **Following** and **Followers** tabs.
- **Federated search**: search for profiles and addresses such as `@user@instance.tld`.
- **Remote profiles**: open external Fediverse profiles and see their recent posts.
- **Remote follows**: follow and unfollow ActivityPub/Mastodon accounts from the app.
- **Remote feed**: read content published by the federated accounts you follow.
- **Local identity**: the user's local Fediverse identity is shown in the app.

### Moderation & Security
- **Democratic moderation**: a revolutionary system where moderators are elected by vote (70% consensus)
- **Transparency**: public log of every moderation action
- **Candidacy**: any user can stand as a candidate and withdraw their candidacy
- **Recall**: moderators can be recalled by popular vote
- **Actions**: direct removal and warnings for elected moderators
- **Reports**: report inappropriate content
- **Private accounts**: control who can follow you


### Multilingual
- **3 languages**: French, English, Spanish
- **Automatic translation**: translate posts into your language

### Technical
- **Multi-instance login**: connect to any Militant instance
- **Offline mode**: browse content even without a connection
- **Dark theme**: modern interface in the project's colors
- **Performance**: optimized to support thousands of simultaneous users

## Requirements

- Flutter 3.0 or later
- Dart 3.0 or later
- Android Studio (for Android development)
- An Android emulator or physical device

**Note:** Android is supported.

## Installation

### Clone the project

```bash
git clone https://gitlab.com/votre-username/militant-flutter.git
cd militant_flutter
```

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
# On a connected emulator/device
flutter run

# Debug APK build
flutter build apk --debug

# Release APK build
flutter build apk --release
```

## Configuration

### Instance URL

By default the app connects to `https://api.militant.revlibertaire.com`. You can switch instances directly from the login screen.

### Lives (v1.0.6) - Advanced System

The **Live** tab is built on [LiveKit](https://livekit.io/) and offers a secure activist streaming experience.

> [!CAUTION]
> **Security**: **never** build the app with your secrets (`LIVEKIT_API_SECRET`). The app only uses the server URL and the API URL to fetch secure tokens. The secret must stay exclusively on your `militant-api` server.

> [!TIP]
> **URL format**: the server URL (`LIVEKIT_URL`) must start with **`wss://`** (e.g. `wss://live.votre-instance.org`).

- **Democratic moderation**: creators can appoint recallable moderators without hierarchy. Blocking users from the chat takes effect immediately.
- **Guest management (Request Guest)**: a robust system that lets viewers ask to "join" the live, with real-time approval/rejection by the creator.
- **u{id} security**: persistent identifiers ensure effective moderation even if a user changes their username.
- **Auto-cleanup**: inactive sessions are closed automatically, as are sessions after a prolonged disconnection of the creator (2 min timeout).
- **Report consensus**: community reporting option; if a vote threshold is reached, the live is automatically suspended for safety.

**Technical configuration (militant-api)**: set at least `LIVEKIT_URL`, `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` so the `POST …/v1/lives.php?path=token` endpoint can respond.

### Mobile Fediverse

The app now includes a **Fediverse** space to connect more directly with the ActivityPub ecosystem.

- **Remote account search**: support for federated handles and profiles.
- **Following / followers**: dedicated lists to find the accounts you follow and your Fediverse followers.
- **Fediverse feed**: read remote content synced by the API.
- **Remote profiles**: avatars, bios, handles and recent posts are shown.

**On the API side (`militant-api`)**, this requires the mobile Fediverse endpoints to be enabled, in particular for:
- remote search
- following / unfollowing external accounts
- fetching the `followers` / `following` lists
- exposing the Fediverse `feed`
- resolving remote profiles

### Activist badges (mobile exclusive)

Activist badges are a feature exclusive to the mobile app. They let you show that you belong to a movement or organization:

- Militant (generic)
- Antifa
- Anarchist
- CNT-AIT, CNT-F, CNT-SO
- FA (Fédération Anarchiste)
- OCL (Organisation Communiste Libertaire)
- CGA (Coordination des Groupes Anarchistes)
- UCL (Union Communiste Libertaire)
- FLL (Front de Libération Libertaire)
- SLM (Solidarité Libertaire Militante)
- IWA-AIT (International Workers' Association)
- IWW (Industrial Workers of the World)
- IAF-IFA (International of Anarchist Federations)
- CNT-AIT-E (Confederación Nacional del Trabajo)
- ULET-AIT

To choose your badge: Profile → Settings → My activist badge

## Project structure

```
militant_flutter/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/                      # Data models
│   │   ├── post.dart
│   │   ├── user.dart
│   │   └── ...
│   ├── screens/                     # App screens
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── messages_screen.dart
│   │   ├── groups_screen.dart
│   │   ├── events_screen.dart
│   │   ├── badge_selection_screen.dart
│   │   └── ...
│   ├── widgets/                     # Reusable components
│   │   ├── post_card.dart
│   │   ├── militant_badge.dart
│   │   ├── linkable_text.dart
│   │   └── ...
│   └── services/                    # Services (API, language)
│       ├── account_switcher_service.dart
│       ├── api_service.dart
│       └── language_service.dart
├── android/                         # Android configuration
├── ios/                             # iOS configuration
├── assets/
│   ├── logo.svg                    # App logo
│   ├── badges/                     # Activist badges (mobile exclusive)
│   │   ├── militant.svg
│   │   ├── antifa.svg
│   │   ├── anarchist.svg
│   │   ├── cnt-ait.png
│   │   ├── cnt-f.jpg
│   │   ├── cnt-so.png
│   │   ├── fa.png
│   │   ├── ocl.gif
│   │   ├── cga.svg
│   │   ├── ucl.jpg
│   │   ├── fll.jpg
│   │   ├── slm.png
│   │   ├── iwa-ait.png
│   │   ├── iww.svg
│   │   ├── iaf-ifa.png
│   │   ├── cnt-ait-e.jpg
│   │   ├── ulet-ait.png
│   │   └── ...
│   └── offline.html                 # Offline page
├── docs/                            # Technical and release documentation
├── scripts/
│   ├── test/                        # Manual tests and diagnostics
│   └── release/                     # Version publishing
├── test/                            # Automated Flutter tests
└── pubspec.yaml                    # Flutter dependencies
```

## Documentation

- [Audio and video calls](docs/APPELS_AUDIO_VIDEO.md)
- [F-Droid build and release](docs/FDROID_GUIDE.md)
- [ICE reconnection on network change](docs/ICE_RESTART.md)
- [Publishing on Google Play](docs/PLAY_STORE.md)
- [Publishing the project on GitLab](docs/PUBLISH.md)

Manual tests and diagnostics are grouped in `scripts/test/`. Build scripts stay
directly in `scripts/` and release scripts are in `scripts/release/`.

## Main dependencies

- `http`: communication with the REST API
- `shared_preferences`: saving user preferences
- `flutter_svg`: displaying SVG logos and badges
- `image_picker`: picking images and videos
- `video_player`: video playback
- `audioplayers`: audio file playback
- `file_picker`: picking files
- `url_launcher`: opening external links
- `share_plus`: sharing content
- `intl`: internationalization and date formatting

## Compilation & Production Builds

The app supports two separate build modes depending on the distribution target:

### 1. F-Droid / Standalone Version (100% Free & De-Googled)

This version has no trackers and no dependency on proprietary Google services:
- **Default push**: `ntfy` over a persistent WebSocket to your self-hosted server (`push.revlibertaire.com`).
- **Google / Firebase services**: disabled at the Gradle level.
- **Settings**: streamlined interface that hides proprietary options while keeping fine-grained alert configuration.

```bash
# Build with the automated script:
./scripts/build_fdroid.sh

# Or with the Flutter command directly:
flutter build apk --release \
  --dart-define=DEFAULT_PUSH_PROVIDER=ntfy \
  --dart-define=FDROID_BUILD=true
```
The ready-to-distribute APK is generated in `dist/militant-fdroid.apk`.

### 2. Google Play Store Version

This version includes Google Play services and OneSignal for standard distribution on the Play Store:
- **Default push**: OneSignal (Google FCM), with the option for users to switch to ntfy or dual delivery.
- **Release format**: Android App Bundle (`.aab`), required by the Google Play Console.

```bash
# Build with the automated script (generates .aab and .apk):
./scripts/build_playstore.sh

# Or with the Flutter commands directly:
# For the Play Console (App Bundle):
flutter build appbundle --release \
  --dart-define=DEFAULT_PUSH_PROVIDER=onesignal \
  --dart-define=FDROID_BUILD=false

# To test as a local APK:
flutter build apk --release \
  --dart-define=DEFAULT_PUSH_PROVIDER=onesignal \
  --dart-define=FDROID_BUILD=false
```
The files are generated in:
- `dist/militant-playstore.aab` (to upload to the Google Play Console)
- `dist/militant-playstore.apk` (for direct testing)

---

### Testing both versions side by side on the same device

To test the Play Store and F-Droid versions at the same time without installation conflicts:
- **Play Store** uses the standard package: `com.militant.militant_flutter`
- **F-Droid** uses a dedicated suffix: `com.militant.militant_flutter.fdroid`

```bash
# Install the F-Droid version on your connected device
adb install dist/militant-fdroid-debug.apk

# Install the Play Store version on the same device
adb install dist/militant-playstore-debug.apk
```
Both apps will appear separately on your phone's home screen.

---

## Performance & Scalability

The app and the API are optimized to support a large number of users:

- **Generous rate limiting**: 1000 requests/minute per IP, 500-1000 requests/hour per user
- **Capacity**: support for 5,000 to 50,000+ simultaneous active users depending on the server
- **Optimizations**: pagination, caching, optimized queries
- **Security**: protection against DDoS, brute force, SQL injection and XSS attacks

## Deployment

### Google Play Store
1. Create or open the Google Play Console.
2. Upload the `dist/militant-playstore.aab` file.
3. Fill in the release details and confirm the rollout.

### F-Droid / Third-party repository
1. Upload the `dist/militant-fdroid.apk` APK to your web server or F-Droid repository.
2. Sign the file with your official keystore.

## Contributing

Contributions are welcome! To contribute:

1. Fork the project
2. Create a branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -m 'Add feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Merge Request

## Contributors

Thanks to everyone who keeps Militant alive.

<p align="center">
  <a href="https://gitlab.com/AnARCHIS12" title="Contributor">
    <img src="https://secure.gravatar.com/avatar/afe587487cc8d7001386da28375c1d7349eb2d19a1b1d831f0204ff6c7106694?s=80&d=identicon" width="80" height="80" alt="CALYPS" style="border-radius: 50%;" />
  </a>
  <a href="https://gitlab.com/Jibhey" title="Contributor">
    <img src="https://secure.gravatar.com/avatar/89a6712d07969727069a4673ae307f552d3e5d060e114708200e94f63f144437?s=80&d=identicon" width="80" height="80" alt="Jibhey" style="border-radius: 50%;" />
  </a>
</p>

<p align="center">
  <a href="https://gitlab.com/AnARCHIS12">CALYPS</a> ·
  <a href="https://gitlab.com/Jibhey">Jibhey</a>
</p>

## License

This project is licensed under the AGPL-3.0. See the [LICENSE](LICENSE) file for details.

## Links

- [Website](https://militant.revlibertaire.com)
- [Google Play](https://play.google.com/store/apps/details?id=com.militant.militant_flutter&pcampaignid=web_share)
- [APKPure](https://apkpure.com/p/com.militant.militant_flutter)
- [Documentation](https://jointomilitant.revliebrtaire.com)
- [Main instance](https://api.militant.revlibertaire.com)
- [Main project](https://gitlab.com/militant1)

## Support

For any question or problem:

- Open an issue on GitLab
- Contact the development team
- Read the documentation
