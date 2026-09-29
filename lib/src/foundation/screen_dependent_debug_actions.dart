part of 'foundation.dart';

/// One screen's contribution to the **Debug options** tab: the controls a
/// [ScreenDebugActions] registered, under the name of the screen that owns
/// them.
///
/// Internal. [id] is an opaque sentinel identifying the registering widget,
/// so two screens of the same type cannot collide.
class ScreenActionEntry {
  ScreenActionEntry(this.id, this.screenName, this.actions);

  final Object id;
  final String screenName;
  final List<Widget> actions;
}

final ValueNotifier<List<ScreenActionEntry>> visibleScreenActions = ValueNotifier([]);

/// Contributes screen-specific debug actions to the Borealis overlay for as
/// long as this widget is mounted.
///
/// Drop it into any `build` — it works from a `StatelessWidget`, a plain
/// `StatefulWidget`, and from hook widgets (`HookConsumerWidget`, `HookWidget`):
///
/// ```dart
/// class MyScreen extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final productId = ref.watch(productProvider);
///     return ScreenDebugActions(
///       keys: [productId],
///       actions: (context) => [/* action widgets */],
///       child: Scaffold(/* ... */),
///     );
///   }
/// }
/// ```
///
/// Actions are grouped under [screenName] in the overlay and removed
/// automatically when this widget is disposed.
class ScreenDebugActions extends StatefulWidget {
  const ScreenDebugActions({
    required this.actions,
    required this.child,
    this.screenName,
    this.activeRouteOnly = false,
    this.keys = const [],
    super.key,
  });

  /// Labels the action group in the overlay. When omitted it is inferred: the
  /// enclosing widget's type (`MyScreen`), then the route name, then
  /// `'Unknown screen'`. Pass it explicitly to override the label, or when the
  /// app runs without widget creation tracking (release and profile builds),
  /// where the type can't be recovered.
  final String? screenName;

  /// Builds the action widgets; re-invoked whenever the actions are refreshed.
  final List<Widget> Function(BuildContext context) actions;

  /// The widget below this one in the tree. Returned unchanged from `build`.
  final Widget child;

  /// When `true`, actions are contributed only while this route is the active
  /// (top-most, not covered by an opaque route) one. Mirrors how Riverpod pauses
  /// covered consumers.
  final bool activeRouteOnly;

  /// `useEffect`-style keys: the actions are built on the first build and again
  /// whenever any key changes. The default `const []` builds once; pass the
  /// values your actions depend on (e.g. `keys: [productId]`) to refresh them
  /// when those change.
  final List<Object?> keys;

  @override
  State<ScreenDebugActions> createState() => _ScreenDebugActionsState();
}

class _ScreenDebugActionsState extends State<ScreenDebugActions> {
  final Object _debugActionId = Object();

  // Null until the first build() call. Doubles as the "have we registered yet?"
  // flag for the lifecycle callbacks, which can fire before the first build.
  List<Object?>? _keys;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDebugActions();
  }

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keysChanged = _keys == null || !listEquals(_keys, widget.keys);
    _keys = widget.keys;

    if (keysChanged) _syncDebugActions();

    return widget.child;
  }

  void _syncDebugActions() {
    // No-op until the first build() has run.
    if (_keys == null) return;

    // TickerMode is read only when opted in, so default consumers register no
    // dependency on it and keep the "show all live screens" behavior. When
    // opted in, reading it here registers a dependency, so [didChangeDependencies]
    // re-runs when this route is covered/uncovered and toggles contribution.
    final isActive = !widget.activeRouteOnly || TickerMode.valuesOf(context).enabled;

    if (!isActive) {
      _removeEntry();
      return;
    }

    final actions = widget.actions(context);

    // The name is resolved in the microtask, not here: while this build runs,
    // the ancestor elements have not been handed their child yet, and that
    // child is what marks them as app-defined widgets.
    scheduleMicrotask(() {
      if (!mounted) return;
      visibleScreenActions.value = [
        ...visibleScreenActions.value.where((e) => e.id != _debugActionId),
        ScreenActionEntry(_debugActionId, _resolvedScreenName(), actions),
      ];
    });
  }

  /// Explicit name, else the widget that hosts these actions, else the route
  /// they live on. Widget creation tracking is off outside debug builds, which
  /// is what the route and the placeholder cover.
  String _resolvedScreenName() =>
      widget.screenName ??
      enclosingCustomWidgetName(context) ??
      ModalRoute.settingsOf(context)?.name ??
      'Unknown screen';

  void _removeEntry() {
    scheduleMicrotask(() {
      visibleScreenActions.value = visibleScreenActions.value.where((e) => e.id != _debugActionId).toList();
    });
  }
}
