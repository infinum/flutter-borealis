part of '../actions.dart';

/// A debug action that runs [action] when tapped.
///
/// Pass it in the `actions` list of an [ActionsBorealisPage], or in the
/// `actions` builder of a [ScreenDebugActions].
///
/// ```dart
/// ButtonActionWidget(
///   label: 'Clear cache',
///   icon: Icons.delete_outline,
///   action: () async => CacheService.clear(),
/// )
/// ```
///
/// If [action] throws, Borealis writes the error with `debugPrint` and the
/// button returns to its resting state.
class ButtonActionWidget extends StatefulWidget {
  const ButtonActionWidget({super.key, required this.label, this.icon, required this.action});

  /// Text shown on the button.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Runs on tap. May be async — the button shows a spinner and ignores
  /// further taps until it completes.
  final FutureOr<void> Function() action;

  @override
  State<ButtonActionWidget> createState() => _ButtonActionWidgetState();
}

class _ButtonActionWidgetState extends State<ButtonActionWidget> with _DebugActionRunner<ButtonActionWidget> {
  Future<void> _run() {
    return runGuarded('debug action "${widget.label}"', () async {
      await resolve(widget.action());
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: _actionPadding,
      child: Row(
        children: [
          Expanded(child: _buildButton(context, onSurface)),
          if (failed) const _ActionFailureMark(),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, Color onSurface) {
    return BorealisLoadingOverlay(
      loading: loading,
      child: FilledButton(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(onSurface),
          textStyle: WidgetStateProperty.all(DefaultTextStyle.of(context).style),
          alignment: Alignment.centerLeft,
        ),
        onPressed: loading ? null : _run,
        child: Center(
          child: Text.rich(
            TextSpan(
              children: [
                if (widget.icon != null)
                  WidgetSpan(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(widget.icon, color: onSurface),
                    ),
                  ),
                TextSpan(text: widget.label),
              ],
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onSurface),
          ),
        ),
      ),
    );
  }
}
