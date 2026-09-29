part of 'shell.dart';

/// Behavior options for [BorealisOverlay].
class BorealisSettings {
  const BorealisSettings({this.gamify = false, this.initialPage = 0, this.enabled = true});

  /// Whether the overlay is mounted at all.
  ///
  /// When `false`, [BorealisOverlay] renders its child untouched — no button,
  /// no panel, no overhead. Gate it on a build flavor or `!kReleaseMode` to
  /// keep the panel out of production.
  ///
  /// This hides the UI only. It does **not** detach the Dio interceptor, so a
  /// [Borealis.initNetworkLogger] call left ungated keeps capturing traffic
  /// into [WiretapStore] with nothing to display it. Gate that call too.
  final bool enabled;

  /// Index into [BorealisOverlay.pages] to show first.
  final int initialPage;

  /// Whether to gamify the overlay.
  final bool gamify;
}
