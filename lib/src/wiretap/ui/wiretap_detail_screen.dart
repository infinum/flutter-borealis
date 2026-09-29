part of '../wiretap.dart';

/// One captured request in full: the method and URL, the timings, both header
/// tables and both bodies, with the export actions in the app bar.
///
/// Internal. The **Network** tab pushes this onto the panel's own navigator
/// when a row is tapped.
class WiretapDetailScreen extends StatefulWidget {
  const WiretapDetailScreen({super.key, required this.entryId, this.store, required this.config});

  final String entryId;
  final WiretapStore? store;
  final WiretapConfig config;

  static Route<void> route({required String entryId, required WiretapConfig config, WiretapStore? store}) {
    return MaterialPageRoute<void>(
      builder: (_) => WiretapDetailScreen(entryId: entryId, config: config, store: store),
    );
  }

  @override
  State<WiretapDetailScreen> createState() => _WiretapDetailScreenState();
}

class _WiretapDetailScreenState extends State<WiretapDetailScreen> {
  WiretapStore get _store => widget.store ?? WiretapStore.instance;

  WiretapEntry? _findEntry() => _store[widget.entryId];

  bool get _canExport => widget.config.onExport != null || widget.config.onCurlExport != null;

  Future<void> _showExportSheet(BuildContext context, WiretapEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ExportSheet(
        onExportCurl: widget.config.onCurlExport == null
            ? null
            : () {
                Navigator.pop(context);
                _exportCurl(entry);
              },
        onExportLogFile: widget.config.onExport == null
            ? null
            : () {
                Navigator.pop(context);
                _exportLogFile(entry);
              },
      ),
    );
  }

  Future<void> _exportCurl(WiretapEntry entry) async {
    final onCurlExport = widget.config.onCurlExport;
    if (onCurlExport == null) {
      return;
    }

    await runBorealisExport(context, () async {
      await onCurlExport(_buildCurl(entry));
      return null;
    });
  }

  Future<void> _exportLogFile(WiretapEntry entry) async {
    final onExport = widget.config.onExport;
    if (onExport == null) {
      return;
    }

    await runBorealisExport(context, () async {
      final file = await WiretapExportUtils.buildExportFile([entry], parsers: widget.config.parsers);
      await onExport(file);
      return null;
    });
  }

  String _buildCurl(WiretapEntry entry) {
    final buffer = StringBuffer('curl -X ${entry.method}');
    buffer.write(' ${_shellQuote('${entry.uri}')}');

    for (final header in entry.requestHeaders.entries) {
      // One flag per value. A header dio kept as a list rendered through
      // `toString` as `-H 'set-cookie: [a=1, b=2]'`, which cURL sends verbatim
      // as a single malformed header.
      for (final value in _headerValues(header.value)) {
        buffer.write(" \\\n  -H ${_shellQuote('${header.key}: $value')}");
      }
    }

    buffer.write(_curlBody(entry.requestBody));
    return buffer.toString();
  }

  /// Every value of one captured header, as separate strings.
  static Iterable<String> _headerValues(Object? value) {
    if (value == null) return const [''];
    if (value is Iterable) return value.map((element) => element?.toString() ?? '');
    return [value.toString()];
  }

  /// The body flags for [body], or a trailing note when the body is something
  /// a pasted command cannot carry.
  ///
  /// The note goes after the command on its own line, so what precedes it stays
  /// runnable.
  static String _curlBody(Object? body) {
    if (body == null) return '';

    // Multipart: cURL builds the parts itself from -F, so hand it the fields
    // and the file names rather than dio's object.
    if (body is FormData) {
      final buffer = StringBuffer();
      for (final field in body.fields) {
        buffer.write(" \\\n  -F ${_shellQuote('${field.key}=${field.value}')}");
      }
      for (final file in body.files) {
        final name = file.value.filename ?? 'file';
        buffer.write(" \\\n  -F ${_shellQuote('${file.key}=@$name')}");
      }
      return buffer.toString();
    }

    // Raw bytes cannot be pasted into a shell, and printing them as an integer
    // array produced a command that sent the wrong thing without saying so.
    if (body is List<int>) {
      return '\n# request body omitted: ${body.length} bytes';
    }

    final text = body is String ? body : _encodeCurlBody(body);
    return ' \\\n  --data-raw ${_shellQuote(text)}';
  }

  /// Serializes a non-String request [body] as JSON for `--data-raw`, so Map
  /// and List payloads produce valid JSON rather than Dart's `toString` form.
  /// Falls back to `toString` when the body isn't JSON-encodable.
  static String _encodeCurlBody(Object? body) {
    try {
      return jsonEncode(body);
    } catch (_) {
      return body.toString();
    }
  }

  /// Single-quotes [value] for POSIX shells, escaping embedded single quotes,
  /// so pasted commands can't break out of their quoting.
  static String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Detail'),
        actions: [
          if (_canExport)
            ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final entry = _findEntry();
                return IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Export',
                  onPressed: entry == null || entry.isLoading ? null : () => _showExportSheet(context, entry),
                );
              },
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final entry = _findEntry();
          if (entry == null) {
            return const Center(child: Text('Entry not found.'));
          }

          return SingleChildScrollView(
            child: SafeArea(
              child: _DetailsContent(entry: entry, config: widget.config),
            ),
          );
        },
      ),
    );
  }
}

class _DetailsContent extends StatefulWidget {
  const _DetailsContent({required this.entry, required this.config});

  final WiretapEntry entry;
  final WiretapConfig config;

  @override
  State<_DetailsContent> createState() => _DetailsContentState();
}

class _DetailsContentState extends State<_DetailsContent> {
  Future<WiretapParsedBody>? _requestBodyFuture;
  Future<WiretapParsedBody>? _responseBodyFuture;

  @override
  void initState() {
    super.initState();
    _buildBodyFutures();
  }

  @override
  void didUpdateWidget(_DetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry) {
      _buildBodyFutures();
    }
  }

  void _buildBodyFutures() {
    final entry = widget.entry;
    final parsers = widget.config.parsers;
    _requestBodyFuture = entry.requestBody != null
        ? WiretapExportUtils.buildBodyContentWithParsers(entry: entry, forRequest: true, parsers: parsers)
        : null;
    _responseBodyFuture = entry.responseBody != null
        ? WiretapExportUtils.buildBodyContentWithParsers(entry: entry, forRequest: false, parsers: parsers)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final config = widget.config;
    final decodedUrl = config.urlDecoded ? Uri.decodeFull(entry.uri.toString()) : entry.uri.toString();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            icon: Icons.arrow_upward_rounded,
            title: 'Request',
            color: Colors.blue,
            children: [
              SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KeyValueRow(label: 'Method', value: entry.method),
                    _KeyValueRow(label: 'URL', value: decodedUrl),
                    _KeyValueRow(label: 'Time', value: entry.timestamp.toLocal().toString()),
                  ],
                ),
              ),
              if (entry.requestHeaders.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SubSectionHeader(title: 'Headers'),
                SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: entry.prettyRequestHeaders.entries
                        .map((e) => _KeyValueRow(label: e.key, value: e.value))
                        .toList(),
                  ),
                ),
              ],
              if (entry.requestBody != null) ...[
                const SizedBox(height: 12),
                _SubSectionHeader(title: 'Body'),
                _BodyText(contentFuture: _requestBodyFuture!),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.arrow_downward_rounded,
            title: 'Response',
            color: Colors.green,
            children: [
              if (entry.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KeyValueRow(label: 'Status', value: entry.statusCode?.toString() ?? '-'),
                    if (entry.responseTimestamp != null) ...[
                      _KeyValueRow(label: 'Response Time', value: entry.responseTimestamp!.toLocal().toString()),
                      _KeyValueRow(label: 'Duration', value: '${entry.duration!.inMilliseconds} ms'),
                    ],
                  ],
                ),
                if (entry.responseHeaders != null && entry.responseHeaders!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SubSectionHeader(title: 'Headers'),
                  Column(
                    spacing: 2,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entry.prettyResponseHeaders!.entries
                        .map((e) => _KeyValueRow(label: e.key, value: e.value))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                if (entry.error != null) ...[_SubSectionHeader(title: 'Error'), _ErrorText(error: entry.error!)],
                if (entry.responseBody != null) ...[
                  const SizedBox(height: 8),
                  _SubSectionHeader(title: 'Body'),
                  _BodyText(contentFuture: _responseBodyFuture!),
                ],
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.onExportCurl, required this.onExportLogFile});

  final VoidCallback? onExportCurl;
  final VoidCallback? onExportLogFile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onExportCurl != null)
            ListTile(leading: const Icon(Icons.terminal), title: const Text('Export as cURL'), onTap: onExportCurl),
          if (onExportLogFile != null)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Export as log file'),
              onTap: onExportLogFile,
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.color, required this.children});

  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: color.withAlpha(30),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  const _SubSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Align(
                  widthFactor: 1,
                  alignment: Alignment.topLeft,
                  child: Text(
                    '$label ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  widthFactor: 1,
                  alignment: Alignment.bottomLeft,
                  child: Text(value, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText({required this.contentFuture});

  final Future<WiretapParsedBody> contentFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WiretapParsedBody>(
      future: contentFuture,
      builder: (context, snapshot) {
        final content = snapshot.data ?? const WiretapParsedBody(formattedBody: '');
        final isLoading = snapshot.connectionState != ConnectionState.done;

        return SelectionArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                if (isLoading) const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                if (content.widget != null) ...[
                  Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    child: InteractiveViewer(minScale: 1, maxScale: 4, child: content.widget!),
                  ),
                ],
                if (content.formattedBody != null) _MonospaceBodyText(text: content.formattedBody!),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonospaceBodyText extends StatelessWidget {
  const _MonospaceBodyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'));
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        error.toString(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
