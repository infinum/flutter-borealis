part of '../actions.dart';

/// A debug action that collects a string through a dialog.
///
/// A tap opens an [AlertDialog] holding a [TextField]. **Save** calls [action]
/// with the text. **Disable** calls [action] with `null`. Closing the dialog
/// with a tap outside or with the back gesture calls nothing, so a dismissal
/// and a deliberate `null` stay distinguishable.
///
/// ```dart
/// InputActionWidget(
///   label: 'Override API base URL',
///   dialogLabel: 'Enter base URL',
///   initialValue: 'https://api.example.com',
///   icon: Icons.link,
///   action: (value) async {
///     if (value != null) await ApiConfig.setBaseUrl(value);
///   },
/// )
/// ```
class InputActionWidget extends StatefulWidget {
  /// Text shown on the button.
  final String label;

  /// Title of the dialog. Defaults to `'Enter value'`.
  final String? dialogLabel;

  /// Text the field holds when the dialog opens.
  final String? initialValue;

  /// Optional leading icon.
  final IconData? icon;

  /// Called with the entered text on **Save**, or with `null` on **Disable**.
  final FutureOr<void> Function(String?) action;
  const InputActionWidget({
    super.key,
    required this.label,
    this.dialogLabel,
    this.initialValue,
    this.icon,
    required this.action,
  });

  @override
  State<InputActionWidget> createState() => _InputActionWidgetState();
}

class _InputActionWidgetState extends State<InputActionWidget> with _DebugActionRunner<InputActionWidget> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _actionWrapper() {
    return runGuarded('debug action "${widget.label}"', () async {
      // Wrap the value so a dismissed dialog (null) is distinguishable from
      // the explicit Disable choice (which carries a null value).
      final result = await showDialog<({String? value})>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.dialogLabel ?? 'Enter value'),
          content: TextField(controller: _controller),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop((value: null)), child: const Text('Disable')),
            TextButton(
              onPressed: () => Navigator.of(context).pop((value: _controller.text)),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      // Only run the action when a button was pressed; skip on dismissal.
      if (result == null) return;

      await resolve(widget.action(result.value));

      // Disable means "no override", so the field empties to match. A saved
      // value stays put: restoring `initialValue` here made a successful save
      // look as though it had been discarded.
      if (result.value == null) _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _actionPadding,
      child: Row(
        children: [
          Expanded(
            child: BorealisLoadingOverlay(
              loading: loading,
              child: FilledButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.onSurface),
                  textStyle: WidgetStateProperty.all(DefaultTextStyle.of(context).style),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: loading ? null : _actionWrapper,
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (widget.icon != null)
                        WidgetSpan(
                          child: Padding(padding: const EdgeInsets.only(right: 8.0), child: Icon(widget.icon)),
                        ),
                      TextSpan(text: widget.label),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (failed) const _ActionFailureMark(),
        ],
      ),
    );
  }
}
