# Borealis example

Demo app for the [Borealis](../README.md) debugging overlay.

What it demonstrates:

- `BorealisOverlay` wired through `MaterialApp.builder` with an explicit `pages` list (`lib/main.dart`)
- Loggy set up with `BorealisPrinter` so app logs land in the **Logs** tab
- A counter that emits `debug`/`info`/`warning`/`error` records to populate the Logs tab
- Screen-dependent debug actions via the `ScreenDebugActions` widget (`lib/screen_with_action.dart`)
- A test API client wired with `Borealis.initNetworkLogger`, so its traffic fills the **Network** tab (`lib/api_client.dart`). The ☁ button fires every demo request at once — success, 404, 500, slow and failed connections — so the **Network** tab fills with one of each
- `WiretapConfig` export hooks: *Export as log file* logs the file path, *Export as cURL* copies the command to the clipboard

Run it:

```sh
cd example
flutter run
```

Then tap the floating red 🐛 button to open the debug panel.
