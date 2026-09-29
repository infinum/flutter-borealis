part of '../actions.dart';

/// A debug action that picks one value of [T] from [options].
///
/// A tap opens a [SimpleDialog] listing every option. The button shows the
/// current selection, which the widget reads from [initialSelection] when it
/// mounts.
///
/// ```dart
/// SelectableActionWidget<String>(
///   label: 'Active environment',
///   options: const ['dev', 'staging', 'prod'],
///   initialSelection: () async => EnvConfig.current(),
///   onSelection: (selected) async {
///     await EnvConfig.set(selected ?? 'dev');
///     return selected ?? 'dev';
///   },
/// )
/// ```
///
/// [onSelection] receives `null` when the user clears the selection, and a
/// dismissed dialog calls nothing at all.
class SelectableActionWidget<T> extends StatefulWidget {
  const SelectableActionWidget({
    super.key,
    required this.label,
    required this.options,
    required this.initialSelection,
    required this.onSelection,
  });

  /// Text shown on the button.
  final String label;

  /// Every value the dialog offers.
  final List<T> options;

  /// Returns the value to show when the widget mounts.
  final FutureOr<T> Function() initialSelection;

  /// Called with the chosen value, or `null` when it is cleared. The value it
  /// returns becomes the selection shown.
  final FutureOr<T> Function(T?) onSelection;

  @override
  State<SelectableActionWidget<T>> createState() => _SelectableActionWidgetState<T>();
}

class _SelectableActionWidgetState<T> extends State<SelectableActionWidget<T>>
    with _DebugActionRunner<SelectableActionWidget<T>> {
  /// Shown in place of a value before one is read, or when the selection is
  /// cleared. The literal `null` used to be rendered here, which read as a bug.
  static const _placeholder = 'Not set';

  T? _selection;

  @override
  void initState() {
    super.initState();
    runGuarded('selectable "${widget.label}"', () async {
      final value = await resolve(widget.initialSelection());
      if (!mounted) return;
      setState(() => _selection = value);
    });
  }

  Future<void> _action() {
    final previous = _selection;
    return runGuarded('selectable "${widget.label}"', () async {
      // Wrap the value so a dismissed dialog (null) is distinguishable from
      // an option that carries a null value.
      final dialogResult = await _showDialog(context);

      // Dismissed with the barrier or the back gesture: leave the selection
      // alone and call nothing.
      if (dialogResult == null) return;
      if (!mounted) return;

      setState(() => _selection = dialogResult.value);
      final value = await resolve(widget.onSelection(dialogResult.value));
      if (!mounted) return;
      setState(() => _selection = value);
    }, onError: () => _selection = previous);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: _actionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(widget.label)),
              if (failed) const _ActionFailureMark(),
            ],
          ),
          const SizedBox(height: 8),
          BorealisLoadingOverlay(
            loading: loading,
            child: TextButton(
              style: ButtonStyle(
                // From the scheme, not a literal: the panel is dark by default,
                // where black on black was unreadable.
                backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
                foregroundColor: WidgetStateProperty.all(scheme.onSurface),
                textStyle: WidgetStateProperty.all(DefaultTextStyle.of(context).style),
              ),
              onPressed: loading ? null : _action,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(_selection?.toString() ?? _placeholder), const Icon(Icons.arrow_drop_down)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<({T? value})?> _showDialog(BuildContext context) {
    return showDialog<({T? value})>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select option'),
          children: widget.options
              .map(
                (item) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop((value: item)),
                  child: Text(item.toString()),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
