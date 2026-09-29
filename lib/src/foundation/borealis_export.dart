part of 'foundation.dart';

/// Signature of the export callbacks exposed by the built-in pages.
///
/// The callback may be asynchronous: the exporting UI awaits it and surfaces
/// any error it throws in a snackbar. Some call sites also keep a loading
/// indicator visible until it completes.
typedef BorealisExportCallback = FutureOr<void> Function(String value);

/// Shared writer for the plain-text export files produced by the built-in
/// pages.
abstract class BorealisExportUtils {
  BorealisExportUtils._();

  /// Assembles the export text from pre-rendered [records] and writes it to a
  /// timestamped file in the system temp directory, off the main isolate.
  ///
  /// [title] heads the file (e.g. `Wiretap export`), [unit] names the records
  /// in the header count (e.g. `requests`) and [filePrefix] prefixes the file
  /// name. Records must be plain pre-rendered strings so the closure stays
  /// sendable across the isolate boundary. Returns the written file's path.
  ///
  /// Throws [UnsupportedError] on platforms without a file system (web).
  static Future<String> writeExportFile({
    required String title,
    required String unit,
    required String filePrefix,
    required List<String> records,
  }) {
    return export_file.writeExportFile(title: title, unit: unit, filePrefix: filePrefix, records: records);
  }
}

/// Runs an export and reports its outcome in a snackbar: the string [export]
/// resolves to on success (nothing when it is `null`), or `Export failed: …`
/// when it throws.
///
/// Shared by every page that exports, so success and failure read the same
/// everywhere. The messenger is captured before the `await`, so the snackbar
/// still shows when the calling widget is gone by the time the export finishes.
Future<void> runBorealisExport(BuildContext context, Future<String?> Function() export) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final message = await export();
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

/// How many entries a Borealis store keeps before it evicts the oldest.
///
/// One figure for the request store and the log buffer, which held a private
/// copy each. Not a setting: the per-body cap in `WiretapInterceptor` is what
/// bounds memory in practice, and a second knob would only invite tuning the
/// wrong one.
const int kBorealisMaxStoredEntries = 1000;
