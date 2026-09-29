part of 'logs.dart';

/// Renders captured log records into the plain-text file the **Logs** tab
/// exports.
///
/// Internal. The public entry point is [LogsConfig.onExport], which receives
/// the path of the file this writes.
abstract class LogsExportUtils {
  LogsExportUtils._();

  /// Renders [events] to per-record text on the main isolate ([LogRecord]s
  /// can hold non-sendable error objects), then assembles and writes the file
  /// off the main isolate via [BorealisExportUtils.writeExportFile].
  static Future<String> buildExportFile(List<LogRecord> events) {
    final records = events.map(_buildRecord).toList();
    return BorealisExportUtils.writeExportFile(
      title: 'Borealis logs export',
      unit: 'records',
      filePrefix: 'logs_export',
      records: records,
    );
  }

  static String _buildRecord(LogRecord e) {
    final buffer = StringBuffer();
    buffer.writeln('${e.time.toLocal()}  ${e.level.name.toUpperCase()}  ${e.loggerName}');
    buffer.writeln(e.message);
    if (e.error != null) {
      buffer.writeln('Error: ${e.error}');
    }
    if (e.stackTrace != null) {
      buffer.writeln('Stack trace:');
      buffer.writeln(e.stackTrace);
    }
    return buffer.toString();
  }
}
