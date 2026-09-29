part of 'logs.dart';

/// Configuration for the logs page.
class LogsConfig {
  const LogsConfig({this.onExport});

  static const LogsConfig defaultConfig = LogsConfig();

  /// Called with the path of the exported log file (written to the system
  /// temp directory). May be asynchronous — the export UI awaits it, keeps
  /// its loading indicator visible and reports errors it throws. When null,
  /// the export action is hidden.
  final BorealisExportCallback? onExport;
}
