# athan_call_to_success

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Planning

- User stories aligned to the current implementation are maintained in [docs/issue-tracker-user-stories.md](docs/issue-tracker-user-stories.md).

## Masjid Map Setup

The Masjid page uses the [Mawaqit](https://mawaqit.net) API for nearby mosque search — **no Google Places key required**.

### 1. Create a free Mawaqit account

Register at [https://mawaqit.net](https://mawaqit.net). You will use your email and password to sign in from within the app.

### 2. Sign in inside the app

The first time you open the Masjid page a sign-in dialog will appear. Enter your mawaqit.net credentials. The API token is cached locally, so you only need to do this once.

### 3. Google Maps API key (for map tiles)

The native map tile renderer still requires a Google Maps SDK key:

```powershell
setx GOOGLE_MAPS_API_KEY "AIzaSy...YOUR_REAL_KEY"
```

After running `setx`, fully close and reopen VS Code.

The launch configs in [.vscode/launch.json](.vscode/launch.json) already pass:

```
--dart-define=GOOGLE_MAPS_API_KEY=${env:GOOGLE_MAPS_API_KEY}
```

### Notes

- If `GOOGLE_MAPS_API_KEY` is missing, the map view is replaced by a text message.
- Mosque search data comes from Mawaqit (covers 85+ countries). No billing required for the search itself.
