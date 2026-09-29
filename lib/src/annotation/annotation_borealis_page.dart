part of 'annotation.dart';

/// Borealis page for capturing and reviewing widget annotations.
///
/// Shows a centered "Enable annotations" button when empty, otherwise a list
/// of captured notes plus "Start annotating" and "Export JSON" actions.
class AnnotationBorealisPage extends BorealisPage {
  const AnnotationBorealisPage({super.useAppTheme = false, this.exporter = const ClipboardAnnotationExporter()})
    : super(title: 'Annotations', icon: Icons.edit_note_outlined);

  /// Strategy used by the "Export" action. Defaults to copying JSON to the
  /// clipboard; pass a custom [AnnotationExporter] to send notes elsewhere.
  final AnnotationExporter exporter;

  static final _badge = CountListenable(AnnotationStore.instance, () => AnnotationStore.instance.annotations.length);

  static final _buttonReplacement = MappedListenable<BorealisButtonReplacement?>(
    AnnotationStore.instance.active,
    () => AnnotationStore.instance.active.value
        ? BorealisButtonReplacement(onTap: () => AnnotationStore.instance.active.value = false, icon: Icons.close)
        : null,
  );

  @override
  ValueListenable<BorealisButtonReplacement?> get replaceBorealisButton => _buttonReplacement;

  @override
  Widget? stackPage(BuildContext context, GlobalKey appKey) {
    // A build that cannot resolve widgets gets no layer at all, rather than a
    // full-screen one that swallows taps and never selects anything.
    if (!annotationCaptureSupported) return null;
    return AnnotationOverlay(targetKey: appKey);
  }

  @override
  VoidCallback? get onClearTap => AnnotationStore.instance.clear;

  @override
  ValueListenable<int>? get badgeListenable => _badge;

  @override
  Widget build(BuildContext context) {
    return AnnotationPageBody(captureSupported: annotationCaptureSupported, exporter: exporter);
  }
}

/// The body of the Annotations tab.
///
/// Takes [captureSupported] rather than reading it, so both branches can be
/// built and tested: the running build always reports the supported one.
class AnnotationPageBody extends StatelessWidget {
  const AnnotationPageBody({
    super.key,
    required this.captureSupported,
    this.exporter = const ClipboardAnnotationExporter(),
  });

  /// Whether this build can resolve a tapped widget — see
  /// [annotationCaptureSupported]. When false the tab explains itself instead
  /// of offering a capture it cannot perform.
  final bool captureSupported;

  final AnnotationExporter exporter;

  @override
  Widget build(BuildContext context) {
    final store = AnnotationStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final annotations = store.annotations;

        // Saved notes stay readable in any build; only capturing them needs
        // the debug machinery, so an unsupported build still lists and exports
        // whatever it already has.
        final Widget content;
        if (annotations.isEmpty) {
          content = captureSupported
              ? _AnnotationEmptyState(onEnable: () => _enable(context))
              : const _AnnotationUnsupportedState();
        } else {
          content = _AnnotationList(
            annotations: annotations,
            exporter: exporter,
            onStart: captureSupported ? () => _enable(context) : null,
            onDelete: store.remove,
          );
        }

        final options = exporter.buildExporterOptions(context);

        if (options == null) {
          return content;
        }

        return Column(
          children: [
            options,
            Expanded(child: content),
          ],
        );
      },
    );
  }

  void _enable(BuildContext context) {
    AnnotationStore.instance.active.value = true;
    OverlayNestedNavigation.hide();
  }
}

/// Shown in place of the enable button when the build cannot resolve widgets.
class _AnnotationUnsupportedState extends StatelessWidget {
  const _AnnotationUnsupportedState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('Annotations need a debug build', textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Picking a widget relies on data Flutter keeps only in a debug '
              'build, so capture is unavailable here. Notes captured earlier '
              'still appear in this tab.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnotationEmptyState extends StatelessWidget {
  const _AnnotationEmptyState({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: onEnable,
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Enable annotations'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Tap a widget on the current screen to attach a note.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationList extends StatelessWidget {
  const _AnnotationList({
    required this.annotations,
    required this.exporter,
    required this.onStart,
    required this.onDelete,
  });

  final List<Annotation> annotations;
  final AnnotationExporter exporter;

  /// Null in a build that cannot capture, which disables the start button and
  /// leaves the existing notes listed and exportable.
  final VoidCallback? onStart;
  final void Function(Annotation annotation) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Start annotating'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ExportButton(exporter: exporter, annotations: annotations),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: annotations.length,
            separatorBuilder: (context, _) =>
                Divider(height: 0.5, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
            itemBuilder: (context, index) => _AnnotationCard(
              annotationIndex: index,
              annotation: annotations[index],
              onDelete: () => onDelete(annotations[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Export action that shows a spinner while [AnnotationExporter.export] runs
/// and reports the outcome in a snack bar.
class _ExportButton extends StatefulWidget {
  const _ExportButton({required this.exporter, required this.annotations});

  final AnnotationExporter exporter;
  final List<Annotation> annotations;

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final buttonReplacement = widget.exporter.exportButtonReplacement;
    return FilledButton.icon(
      onPressed: _exporting ? null : _exportShowStatus,
      label: Text(buttonReplacement.label),
      icon: _exporting
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            )
          : Icon(buttonReplacement.icon),
    );
  }

  /// Runs the exporter and reports its status message (or failure) in a
  /// snackbar.
  Future<void> _exportShowStatus() async {
    setState(() => _exporting = true);
    try {
      await runBorealisExport(context, () async {
        final notSentAnnotations = widget.annotations.where((a) => !a.isSent).toList();
        if (notSentAnnotations.isEmpty) {
          throw Exception('No annotations to export');
        }

        final message = await widget.exporter.export(notSentAnnotations);
        AnnotationStore.instance.markAsSent();
        return message;
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({required this.annotationIndex, required this.annotation, required this.onDelete});

  final int annotationIndex;
  final Annotation annotation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: annotation.isSent ? 0.6 : 1.0,
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${annotationIndex + 1}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            annotation.note,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      annotation.widgetType,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    if (annotation.sourceLocation != null) ...[
                      Text(
                        annotation.sourceLocation!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (annotation.isSent) ...[
                Text(
                  'Sent',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primaryContainer,
                  ),
                ),
                SizedBox(width: 12),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete annotation',
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirms before deleting, so a stray tap can't silently drop a note.
  /// [onDelete] runs only when the user explicitly confirms.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete annotation?'),
        content: Text('This will remove annotation ${annotationIndex + 1}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed ?? false) onDelete();
  }
}
