part of 'foundation.dart';

/// Hosts the debug panel in its own [Navigator], inserted into the host app's
/// [Overlay].
///
/// The nested navigator is what lets a page push a screen of its own — the
/// Network tab opens a request that way — without touching the app's
/// navigation stack. Internal; [Borealis.hideDebugPanel] is the public way to
/// close what this opens.
abstract class OverlayNestedNavigation {
  const OverlayNestedNavigation._();

  static final _borealisNavigatorKey = GlobalKey<NavigatorState>();

  /// Shared dark theme used across the Borealis overlay UI. Built once —
  /// `ThemeData.dark()` is expensive and this is read from build methods.
  ///
  /// [ThemeData.materialTapTargetSize] and [ThemeData.visualDensity] are pinned
  /// rather than resolved from the host: their desktop values leave stacked
  /// actions touching, tap-target padding being all that separates them.
  static final ThemeData theme = ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(primary: Colors.red, onPrimary: Colors.white),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );

  static void show(BuildContext context, {required WidgetBuilder builder}) {
    if (_borealisNavigatorKey.currentState != null) return;

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Theme(
        data: theme,
        child: HeroControllerScope.none(
          child: Navigator(
            key: _borealisNavigatorKey,
            // generate empty route so navigator is not empty
            onGenerateRoute: (_) => MaterialPageRoute(builder: (context) => const SizedBox()),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Push modal bottom sheet onto overlay to show sheet animation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navContext = _borealisNavigatorKey.currentContext;
      if (navContext == null) {
        _remove(overlayEntry);
        return;
      }

      await showModalBottomSheet<void>(
        context: navContext,
        isScrollControlled: false,
        scrollControlDisabledMaxHeightRatio: 1,
        useSafeArea: true,
        clipBehavior: Clip.antiAlias,
        builder: builder,
      );
      // wait for animation to finish
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _remove(overlayEntry);
    });
  }

  /// Closes the panel, whatever a page has pushed on top of it.
  ///
  /// Pops to the placeholder route rather than popping one route: pages push
  /// their own screens onto this navigator (the Network tab opens a request
  /// that way), so popping once with one of those open merely went back to the
  /// tab and left the panel up.
  static void hide() {
    _borealisNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Removes [entry] and releases it.
  ///
  /// `remove` alone leaves the entry's internal notifier alive, which the
  /// framework's leak tracker flags — once per panel open.
  static void _remove(OverlayEntry entry) {
    entry
      ..remove()
      ..dispose();
  }
}
