part of 'wiretap.dart';

/// Configuration for the Wiretap network logger UI.
class WiretapConfig {
  WiretapConfig({
    this.urlDisplay = WiretapUrlDisplay.pathOnly,
    this.urlDecoded = false,
    Iterable<WiretapBodyParser> parsers = const [],
    this.onExport,
    this.onCurlExport,
  }) : // Priority order, first match wins: caller-supplied parsers get the
       // first look at a body, the built-ins (ending in a catch-all) back
       // them up. Built once and unmodifiable — this is read per body render.
       parsers = List.unmodifiable([...parsers, ...WiretapBuiltInBodyParsers.parsers]);

  static final WiretapConfig defaultConfig = WiretapConfig();

  /// Controls whether list items show only the request path or the full URL.
  final WiretapUrlDisplay urlDisplay;
  final bool urlDecoded;

  /// Body parsers in priority order: the first one that accepts a body renders
  /// it. Caller-supplied parsers come before the built-ins.
  final List<WiretapBodyParser> parsers;

  /// Called with the path of the exported log file (written to the system
  /// temp directory). May be asynchronous — the export UI awaits it and
  /// reports any error it throws in a snackbar. In [WiretapContent] a loading
  /// indicator stays visible until it completes. When null, the export actions
  /// are hidden.
  final BorealisExportCallback? onExport;

  /// Called with the generated cURL command for a single request — the
  /// command text itself, not a file path. May be asynchronous. When null,
  /// the cURL export action is hidden.
  final BorealisExportCallback? onCurlExport;
}

/// How much of the URL a row in the **Network** tab shows.
enum WiretapUrlDisplay {
  /// Shows only the path component, e.g. `/api/market-data`.
  pathOnly,

  /// Shows the complete URL, e.g. `https://example.com/api/market-data`.
  fullUrl,
}
