/// Fallback used on platforms without `dart:io` (web). Exporting to a file is
/// not possible there, so the call fails loudly instead of silently doing
/// nothing — the export UI turns the error into a snackbar.
Future<String> writeExportFile({
  required String title,
  required String unit,
  required String filePrefix,
  required List<String> records,
}) {
  throw UnsupportedError('Borealis file export is not supported on this platform.');
}
