part of '../actions.dart';

/// A debug action shown as a labeled switch over a boolean value.
///
/// The widget reads [initialState] one time when it mounts, then calls
/// [action] on every flip. Both callbacks may be asynchronous.
///
/// ```dart
/// ToggleActionWidget(
///   label: 'Enable feature flag',
///   initialState: () async => FeatureFlags.get('new_home'),
///   action: (enabled) async {
///     await FeatureFlags.set('new_home', enabled);
///     return enabled;
///   },
/// )
/// ```
///
/// [action] returns the state to display, which need not be the value it was
/// given: return the old value to reject a change. If either callback throws,
/// the widget disables the switch.
class ToggleActionWidget extends StatefulWidget {
  const ToggleActionWidget({super.key, required this.label, required this.initialState, required this.action});

  /// Text shown beside the switch.
  final String label;

  /// Returns the state to show when the widget mounts.
  final FutureOr<bool> Function() initialState;

  /// Called with the new value. The value it returns becomes the state shown.
  final FutureOr<bool> Function(bool) action;

  @override
  State<ToggleActionWidget> createState() => _ToggleActionWidgetState();
}

class _ToggleActionWidgetState extends State<ToggleActionWidget> with _DebugActionRunner<ToggleActionWidget> {
  bool _switchState = false;

  @override
  void initState() {
    super.initState();
    runGuarded('toggle "${widget.label}"', () async {
      final value = await resolve(widget.initialState());
      if (!mounted) return;
      setState(() => _switchState = value);
    });
  }

  Future<void> _switchAction() {
    final previous = _switchState;
    return runGuarded('toggle "${widget.label}"', () async {
      // Flipped inside the guard, so a second tap that slips into the same
      // frame cannot flip it again behind the run already under way.
      setState(() => _switchState = !previous);
      final value = await resolve(widget.action(!previous));
      if (!mounted) return;
      setState(() => _switchState = value);
    }, onError: () => _switchState = previous);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _actionPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(widget.label)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BorealisLoadingOverlay(
                loading: loading,
                child: Switch(onChanged: loading ? null : (_) => _switchAction(), value: _switchState),
              ),
              if (failed) const _ActionFailureMark(),
            ],
          ),
        ],
      ),
    );
  }
}
