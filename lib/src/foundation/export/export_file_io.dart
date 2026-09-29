import 'dart:io';
import 'dart:isolate';

/// Name of the directory Borealis owns inside the system temp directory.
///
/// Exports go here rather than straight into temp so the package can clean up
/// after itself without touching a file it did not write.
const _exportDirName = 'borealis_exports';

/// When this process first exported.
///
/// An export holds request URLs, headers, bodies and log records in plain text,
/// so leaving it on disk indefinitely turns a debug convenience into a store of
/// captured data that nothing ever clears. Every file older than this is from a
/// previous run and is deleted on the next export, which bounds what is on disk
/// to one session's worth.
///
/// Lazily initialised, so it marks the first export rather than app start —
/// which is what the purge needs, since no file from this run exists before it.
final DateTime _firstExportAt = DateTime.now();

/// Assembles the export text from pre-rendered [records] and writes it to a
/// timestamped file in the Borealis export directory, off the main isolate.
///
/// [title] heads the file (e.g. `Wiretap export`), [unit] names the records in
/// the header count (e.g. `requests`) and [filePrefix] prefixes the file name.
/// Records must be plain pre-rendered strings so the closure stays sendable
/// across the isolate boundary. Returns the written file's path.
///
/// Deletes every export left by an earlier run before writing — see
/// [_firstExportAt].
Future<String> writeExportFile({
  required String title,
  required String unit,
  required String filePrefix,
  required List<String> records,
}) {
  final exportDirPath = '${Directory.systemTemp.path}${Platform.pathSeparator}$_exportDirName';
  // Read on this isolate: a spawned one would initialise its own copy to the
  // moment it started, and then treat this run's own exports as stale.
  final firstExportAt = _firstExportAt;

  return Isolate.run(() async {
    final directory = await Directory(exportDirPath).create(recursive: true);
    await _purgeEarlierRuns(directory, firstExportAt);

    final separator = '━' * 60;

    final buffer = StringBuffer(title);
    if (records.length > 1) {
      buffer.write(' — ${records.length} $unit');
    }
    buffer.writeln();
    buffer.writeln('Exported at: ${DateTime.now().toLocal()}');
    buffer.writeln();

    for (final record in records) {
      buffer.writeln(separator);
      buffer.write(record);
    }
    buffer.write(separator);

    // Microseconds, not milliseconds: two exports a few hundred microseconds
    // apart used to land on the same name and overwrite each other.
    final name = '${filePrefix}_${DateTime.now().microsecondsSinceEpoch}.txt';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString(buffer.toString());
    return file.path;
  });
}

/// Deletes the files in [directory] last written before [keepAfter].
///
/// Best effort: a file that vanishes underneath us, or that the platform will
/// not let us remove, is skipped rather than failing the export the user asked
/// for.
Future<void> _purgeEarlierRuns(Directory directory, DateTime keepAfter) async {
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    try {
      if ((await entity.lastModified()).isBefore(keepAfter)) await entity.delete();
    } on FileSystemException {
      continue;
    }
  }
}
