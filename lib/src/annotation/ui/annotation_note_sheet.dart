part of '../annotation.dart';

/// Note input bottom sheet. Owns its [TextEditingController] so it is disposed
/// only after the sheet (and its close transition) is fully gone — pops the
/// typed note on Save, `null` on Cancel.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.widgetType, this.initial});

  final String widgetType;

  /// Existing note when editing; `null` when creating a new one.
  final String? initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_isEditing ? 'Edit note' : 'Note'} for ${widget.widgetType}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Describe the issue here',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isEditing) ...[
                  TextButton(
                    // Empty result signals removal to the caller.
                    onPressed: () => Navigator.of(context).pop(''),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                    child: const Text('Delete'),
                  ),
                  const Spacer(),
                ],
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
