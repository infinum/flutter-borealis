part of 'wiretap.dart';

/// Renders captured requests into the plain-text file the **Network** tab
/// exports, and resolves a body through the configured parsers.
///
/// Internal. The public entry point is [WiretapConfig.onExport], which
/// receives the path of the file this writes.
abstract class WiretapExportUtils {
  WiretapExportUtils._();

  static Future<WiretapParsedBody> buildBodyContentWithParsers({
    required WiretapEntry entry,
    required bool forRequest,
    required List<WiretapBodyParser> parsers,
  }) async {
    // [parsers] is already in priority order (see [WiretapConfig.parsers]).
    for (final parser in parsers) {
      try {
        // Inside the try: a parser that throws while deciding must not skip the
        // parsers after it or the raw-body fallback either.
        if (!parser.shouldParse(entry, forRequest: forRequest)) {
          continue;
        }

        return await Future.sync(() => parser.parse(entry, forRequest: forRequest));
      } catch (e, stackTrace) {
        // A broken parser must not blank the body — fall through to the next
        // one, but say so, otherwise the failure is invisible.
        debugPrint('Borealis: ${parser.runtimeType} failed to parse a body: $e\n$stackTrace');
        continue;
      }
    }

    final body = forRequest ? entry.requestBody : entry.responseBody;
    return WiretapParsedBody(formattedBody: body?.toString() ?? '');
  }

  /// Renders [entries] to per-request text records on the main isolate — the
  /// entries can hold non-sendable objects (streamed bodies, [DioException]s)
  /// and [parsers] can be arbitrary user instances, so only plain strings may
  /// cross the isolate boundary inside [BorealisExportUtils.writeExportFile].
  static Future<String> buildExportFile(List<WiretapEntry> entries, {required List<WiretapBodyParser> parsers}) async {
    final records = await Future.wait(
      entries.mapIndexed(
        (index, entry) => _buildEntryRecord(entry, index: index, total: entries.length, parsers: parsers),
      ),
    );
    return BorealisExportUtils.writeExportFile(
      title: 'Wiretap export',
      unit: 'requests',
      filePrefix: 'wiretap_export',
      records: records,
    );
  }

  static Future<String> _buildEntryRecord(
    WiretapEntry e, {
    required int index,
    required int total,
    required List<WiretapBodyParser> parsers,
  }) async {
    final (requestBody, responseBody) = await (
      e.requestBody == null
          ? Future<String?>.value()
          : buildBodyContentWithParsers(
              entry: e,
              forRequest: true,
              parsers: parsers,
            ).then((body) => body.formattedBody),
      e.responseBody == null
          ? Future<String?>.value()
          : buildBodyContentWithParsers(
              entry: e,
              forRequest: false,
              parsers: parsers,
            ).then((body) => body.formattedBody),
    ).wait;

    final statusLabel = e.isLoading ? 'LOADING' : (e.statusCode?.toString() ?? 'ERR');
    final durationLabel = e.duration != null ? '${e.duration!.inMilliseconds}ms' : '—';

    final buffer = StringBuffer();
    if (total > 1) {
      buffer.write('[${index + 1}/$total] ');
    }
    buffer.writeln('${e.method}  ${e.uri}  •  $statusLabel  •  $durationLabel');
    buffer.writeln('Time: ${e.timestamp.toLocal()}');
    buffer.writeln();

    if (e.requestHeaders.isNotEmpty) {
      buffer.writeln('── Request Headers ──');
      for (final h in e.prettyRequestHeaders.entries) {
        buffer.writeln('  ${h.key}: ${h.value}');
      }
      buffer.writeln();
    }

    if (e.requestBody != null) {
      buffer.writeln('── Request Body ──');
      buffer.writeln(requestBody ?? '');
      buffer.writeln();
    }

    if (e.responseHeaders != null && e.responseHeaders!.isNotEmpty) {
      buffer.writeln('── Response Headers ──');
      for (final h in e.prettyResponseHeaders!.entries) {
        buffer.writeln('  ${h.key}: ${h.value}');
      }
      buffer.writeln();
    }

    if (e.error != null) {
      buffer.writeln('── Error ──');
      buffer.writeln(e.error.toString());
      buffer.writeln();
    }

    if (e.responseBody != null) {
      buffer.writeln('── Response Body ──');
      buffer.writeln(responseBody ?? '');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
