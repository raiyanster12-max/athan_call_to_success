# athan_call_to_success

A new Flutter project.

## Download the Android APK

A GitHub Actions workflow automatically builds an APK on every push to `main`/`master`.

### How to download

1. Go to the **Actions** tab of this repository on GitHub.
2. Click the latest **"Build Android APK"** workflow run.
3. Scroll to the **Artifacts** section at the bottom of the page.
4. Download **`athan-apk`**, unzip it, and side-load the `.apk` onto your Android device.

> **Note:** Make sure *Install from unknown sources* (or *Install unknown apps*) is enabled in your Android settings before installing a side-loaded APK.

### Release APK with Google Maps

By default the workflow builds a **debug APK** (fully functional; Google Maps tiles are replaced by a text message). To build a proper **release APK** with Google Maps:

1. Obtain a Google Maps Android API key from the [Google Cloud Console](https://console.cloud.google.com/).
2. Add it as a repository secret named `GOOGLE_MAPS_API_KEY` (*Settings → Secrets and variables → Actions → New repository secret*).
3. Re-run the workflow — it will automatically detect the secret and produce a release APK.

---

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
