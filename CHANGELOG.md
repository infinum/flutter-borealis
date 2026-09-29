# Changelog

## 2.0.0 — 2026-09-24

First public release.

* Floating debug panel overlay for Flutter apps
* Network tab — Dio request/response inspector
* Logs tab — Loggy log viewer
* Device info tab — device, OS and package data
* Rendering tab — render debug flags (slow animations, repaint rainbow, widget sizes, hitboxes)
* Annotation tab — draw notes over the app and export them
* Debug actions — buttons, inputs, toggles and selectables, global or per screen
* Custom pages — add your own tabs
* Credential headers (`Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization`,
  `X-Api-Key`) are masked before capture, so they reach neither the Network tab nor
  its exports. Configure with `redactHeaders` on `Borealis.initNetworkLogger` or
  `WiretapInterceptor`.
* `redactBodyKeys` masks named keys inside request and response bodies, matched
  without case and applied through nested maps and lists. Empty by default.
* Captured bodies are bounded. A binary body over
  `WiretapInterceptor.maxCapturedBodyBytes` (512 KiB) is replaced with a marker
  stating its real size, a text body over `WiretapInterceptor.maxCapturedBodyChars`
  (512 Ki characters) is truncated with a note of its full length, and captured
  bodies are snapshotted so a caller that mutates a request map afterwards
  cannot rewrite what the panel recorded.
* Log file exports are written to `borealis_exports/` in the system temporary
  directory, and exports left by an earlier run are deleted on the next export.
* A request the wiretap never sees finish — an interceptor registered after it
  answered the request itself — no longer occupies the store forever. After two
  minutes it stops outranking completed entries during eviction.
* Annotation capture reports itself as unavailable in profile and release
  builds, where the widget data it relies on does not exist, instead of mounting
  a capture layer that absorbs taps and selects nothing.
* Debug action widgets share one run discipline. A failed action now marks the
  control and stays usable instead of disabling it for the session,
  `SelectableActionWidget` takes its colors from the theme rather than painting
  black on the dark panel, and `InputActionWidget` keeps the value it saved.
* `BorealisPage.onDetach` undoes what `onAttach` registered. `onAttach` now runs
  once per page instance rather than on every rebuild of the app above the
  overlay, and neither runs while `BorealisSettings.enabled` is `false`.
* `Borealis.hideDebugPanel()` closes the panel even when a page has pushed a
  screen onto it; it used to pop one route and leave the panel open.
* The floating button follows the point it was grabbed by and stays on screen
  while dragged.
* `BorealisOverlay` throws `ArgumentError` for an empty `pages` list instead of
  asserting, which was stripped in release and failed later as a `RangeError`.
* The Network search matches the path and query string, as the field says. It
  used to match the whole URL, so `https` matched everything.
* cURL export emits one `-H` per value of a multi-value header, renders
  `FormData` as `-F` parts, and notes a byte body instead of pasting it as an
  integer array.
* A JSON-labelled body that is a string is pretty-printed rather than escaped,
  and one that is bytes is described by size.
* `LogsBorealisPage` takes an `eventList`, and its badge, clear action and
  gamify popups follow it.
* `BorealisExportCallback` is exported. `ScreenActionEntry` is not — it could be
  named but never obtained or passed.
* The panel's `OverlayEntry` is disposed, not just removed.
* The Accessibility tab is now **Rendering** (`RenderingBorealisPage`). It only
  ever held Flutter's render debug flags, and no accessibility tooling.
* `WiretapParsedBody` no longer carries a `label`. Nothing read it, and a
  third-party `WiretapBodyParser` had to supply one anyway.
* `WiretapInterceptor.maxCapturedBodySize` is now `maxCapturedBodyBytes` and
  `maxCapturedBodyChars`. One constant was compared against a byte count and a
  character count, so the effective cap on text depended on its alphabet.
* Export actions report what they wrote. `WiretapExportUtils` replaces
  `LoggingUtils`, which named neither its subsystem nor its job.
* Fewer rebuilds: merged listenables are built once rather than per frame, the
  overlay depends on the two `MediaQuery` aspects it reads, the panel builds
  the visible tab instead of all of them, and one ticker drives every relative
  timestamp in the Logs tab rather than one timer per row.
* Gamify hooks do nothing while the layer is off, pace themselves on a
  monotonic clock, and count their attachments, so one overlay being disposed
  no longer stops another's popups.
* Store eviction is a single resumed pass rather than a rescan per entry.
* CI measures coverage and fails below 80%.

Requires Dart 3.10 / Flutter 3.38.1 or newer.
