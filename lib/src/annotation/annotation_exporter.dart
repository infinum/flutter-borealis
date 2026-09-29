part of 'annotation.dart';

/// Strategy for exporting captured [Annotation]s.
///
/// Implement to send notes somewhere custom — a local server, a file, an API.
/// The full [Annotation] objects are passed in (all fields public), so an
/// implementation has total control over what it serializes: use
/// [Annotation.toExportJson] or read `props`/`rect`/`tappedWidgetRoute`
/// directly.
///
/// Return a short status message to surface to the user (e.g. in a snackbar);
/// throw to signal failure. Implementations stay UI-free — the page owns the
/// snackbar.
abstract class AnnotationExporter {
  const AnnotationExporter();

  Future<String> export(List<Annotation> annotations);

  /// Exporter options widget, if any. They are shown above the export button.
  ///
  /// Return `null` if no options are available.
  Widget? buildExporterOptions(BuildContext context) => null;

  /// Icon and label metadata used by the UI to render the export button.
  /// This is required to be implemented.
  BorealisExportButtonReplacement get exportButtonReplacement;
}

/// The icon and label an [AnnotationExporter] puts on the export button.
class BorealisExportButtonReplacement {
  final IconData icon;
  final String label;

  const BorealisExportButtonReplacement({required this.icon, required this.label});
}

/// Default exporter: copies the export JSON to the clipboard. Reproduces the
/// behavior the Annotations page had before exporters were pluggable.
class ClipboardAnnotationExporter extends AnnotationExporter {
  const ClipboardAnnotationExporter();

  @override
  BorealisExportButtonReplacement get exportButtonReplacement =>
      const BorealisExportButtonReplacement(icon: Icons.copy, label: 'Copy to clipboard');

  @override
  Future<String> export(List<Annotation> annotations) async {
    final json = jsonEncode(annotations.map((a) => a.toExportJson()).toList());
    await Clipboard.setData(ClipboardData(text: json));
    return 'Copied ${annotations.length} annotations';
  }
}
