part of 'foundation.dart';

/// One tab of the debug panel.
///
/// Subclass to add your own tab, then pass an instance in [BorealisOverlay]'s
/// `pages` list — the overlay renders a bottom-bar entry per page, in the order
/// given. Only [title], [icon] and [build] are required; every other member has
/// a do-nothing default, so a page opts into the features it needs.
///
/// ```dart
/// class FeatureFlagsPage extends BorealisPage {
///   const FeatureFlagsPage() : super(title: 'Flags', icon: Icons.flag_outlined);
///
///   @override
///   Widget build(BuildContext context) => const FlagList();
/// }
/// ```
///
/// Pages are usually `const`, so they cannot hold mutable state themselves.
/// Anything that has to survive a rebuild belongs in a store the page reads —
/// see [badgeListenable] and [replaceBorealisButton] for why the listenables
/// they return have to be stable.
abstract class BorealisPage {
  const BorealisPage({required this.title, required this.icon, this.useAppTheme = false});

  /// Label shown under this page's bottom-bar icon.
  final String title;

  /// Bottom-bar icon for this page.
  final IconData icon;

  /// Whether to render this page with the host app's theme instead of the
  /// panel's own dark theme.
  ///
  /// The panel is dark by default so it stays legible over any app. Opt in
  /// when the page shows the app's own widgets and should match them.
  final bool useAppTheme;

  /// Builds this page's body. The panel supplies the surrounding scaffold,
  /// app bar and bottom bar.
  Widget build(BuildContext context);

  /// Called when the user taps the panel's clear action while this page is
  /// showing. Return `null` — the default — to hide the action.
  VoidCallback? get onClearTap => null;

  /// A count badged on this page's bottom-bar icon, e.g. captured requests.
  /// Return `null` — the default — for no badge.
  ///
  /// Must be a *stable* listenable, for the reason given on
  /// [replaceBorealisButton]. [CountListenable] builds one from a store.
  ValueListenable<int>? get badgeListenable => null;

  /// A reactive override for the floating Borealis button while this page is
  /// the current page. Emit a [BorealisButtonReplacement] to swap the icon and
  /// tap behaviour; emit `null` to fall back to the default (open the panel).
  ///
  /// Must return a *stable* listenable (e.g. a `static final`) — the overlay
  /// subscribes to it and rebuilds when it fires. Returning a fresh notifier
  /// per call breaks reactivity.
  ValueListenable<BorealisButtonReplacement?> get replaceBorealisButton => _noButtonReplacement;

  static final ValueNotifier<BorealisButtonReplacement?> _noButtonReplacement = ValueNotifier(null);

  /// An extra full-screen layer stacked above the app for this page (e.g. an
  /// annotation capture overlay). Returns `null` when the page needs none.
  Widget? stackPage(BuildContext context, GlobalKey appKey) => null;

  /// Called when this page instance joins a [BorealisOverlay].
  ///
  /// Override to register listeners (e.g. on a data store) that translate
  /// changes into [emitGamify] calls, and undo them in [onDetach].
  ///
  /// Called once per instance per overlay: the overlay tracks which pages it
  /// has attached by identity, so a rebuild of the app above it does not
  /// re-attach. A page held `const` — which every built-in is — therefore
  /// attaches exactly once. A page rebuilt into a fresh instance on every
  /// frame is a different instance each time and attaches each time, so hold
  /// a page that registers listeners `const`, or keep the registration
  /// idempotent.
  ///
  /// Not called at all while [BorealisSettings.enabled] is `false`.
  void onAttach() {}

  /// Called when this page instance leaves a [BorealisOverlay] — the overlay
  /// was disposed, the page was dropped from its list, or the overlay was
  /// disabled.
  ///
  /// Override to undo whatever [onAttach] registered. Without it a listener
  /// registered on a long-lived store outlives the overlay that wanted it.
  void onDetach() {}

  /// Push a popup (label + color) to the gamified overlay.
  void emitGamify(BorealisGamifyEvent event) => BorealisGamify.emit(event);
}

/// Describes how a [BorealisPage] overrides the floating Borealis button.
///
/// A non-null instance means "replace": show [icon] and run [onTap] instead of
/// opening the panel. The absence of a replacement is modelled by a `null`
/// [BorealisPage.replaceBorealisButton] value, not by a flag here.
class BorealisButtonReplacement {
  final VoidCallback onTap;
  final IconData icon;
  final Color? color;
  final Color? iconColor;
  final BorderSide? borderSide;

  BorealisButtonReplacement({required this.onTap, required this.icon, this.color, this.iconColor, this.borderSide});
}

/// A [ValueListenable] whose value is derived from another [Listenable] source
/// via `map`, re-evaluated and re-published whenever the source notifies.
///
/// Gives you a *stable* listenable backed by mutable state — exactly what UI
/// (e.g. [BorealisPage.replaceBorealisButton]) needs to subscribe to, instead
/// of a fresh notifier per build.
///
/// ```dart
/// static final _replacement = MappedListenable<BorealisButtonReplacement?>(
///   MyStore.instance.active,
///   () => MyStore.instance.active.value ? BorealisButtonReplacement(...) : null,
/// );
/// ```
///
/// Call [dispose] when no longer needed if the source outlives this object;
/// not required for app-singleton sources.
class MappedListenable<T> extends ValueNotifier<T> {
  MappedListenable(this._source, this._map) : super(_map()) {
    _source.addListener(_sync);
  }

  final Listenable _source;
  final T Function() _map;

  void _sync() {
    final next = _map();
    if (next != value) value = next;
  }

  @override
  void dispose() {
    _source.removeListener(_sync);
    super.dispose();
  }
}

/// A [MappedListenable] of `int` that mirrors a count derived from a
/// [Listenable] source — e.g. for [BorealisPage.badgeListenable].
///
/// ```dart
/// static final _badge = CountListenable(
///   MyStore.instance,
///   () => MyStore.instance.items.length,
/// );
/// ```
class CountListenable extends MappedListenable<int> {
  CountListenable(super.source, super.count);
}
