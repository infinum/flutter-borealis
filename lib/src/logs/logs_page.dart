part of 'logs.dart';

/// The body of the **Logs** tab: a search field, an export action and the
/// captured records, newest first.
///
/// Internal to the package — reach it through [LogsBorealisPage], which is
/// also where the buffer it reads is chosen.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.eventList, this.config});

  /// Event list to listen for event changes.
  ///
  /// Defaults to [TerminalLogger.instance] when not provided.
  final TerminalEventList? eventList;

  /// Display options such as [LogsConfig.onExport].
  ///
  /// Defaults to [LogsConfig.defaultConfig] when not provided.
  final LogsConfig? config;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();

  LogsConfig get _config => widget.config ?? LogsConfig.defaultConfig;

  TerminalEventList get _eventList => widget.eventList ?? TerminalLogger.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The records matching the search query, newest first.
  List<LogRecord> _getEvents() {
    if (_searchController.text.isEmpty) return _eventList.events;

    final query = _searchController.text.toLowerCase();
    return _eventList.events.where((it) {
      return it.message.toLowerCase().contains(query) || it.loggerName.toLowerCase().contains(query);
    }).toList();
  }

  /// Writes the filtered records to a file and hands the path to the config's
  /// callback. Null when no callback is set, which hides the action.
  Future<String?> Function()? get _exportEvents {
    final onExport = _config.onExport;
    if (onExport == null) return null;

    return () async {
      // Events are stored newest-first; export them in chronological order.
      final records = _getEvents().reversed.toList();
      final file = await LogsExportUtils.buildExportFile(records);
      await onExport(file);
      return 'Exported ${records.length} ${records.length == 1 ? 'record' : 'records'}';
    };
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when new log records arrive or the search query changes.
    return ListenableBuilder(
      listenable: Listenable.merge([_eventList, _searchController]),
      builder: (context, _) {
        final events = _getEvents();

        return Column(
          children: [
            BorealisListHeader(
              controller: _searchController,
              hintText: 'Search by message or logger…',
              resultCount: events.length,
              actions: [
                BorealisExportButton(
                  onExport: _exportEvents,
                  tooltip: 'Export filtered logs',
                  enabled: events.isNotEmpty,
                ),
              ],
            ),
            Expanded(
              child: _TimestampTicker(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 24.0),
                  itemCount: events.length,
                  itemBuilder: (context, index) => _LogTile(record: events[index], striped: index.isEven),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One log record: level icon and name, relative age, message, optional error
/// and the logger it came from — all tinted by the record's level.
class _LogTile extends StatelessWidget {
  const _LogTile({required this.record, required this.striped});

  final LogRecord record;

  /// Alternating row background, so consecutive records stay readable.
  final bool striped;

  IconData get _icon => switch (record.level) {
    LogLevel.error => Icons.error_outline,
    LogLevel.warning => Icons.warning_amber_outlined,
    LogLevel.debug => Icons.bug_report_outlined,
    LogLevel.info => Icons.info_outline,
    _ => Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = record.level.color;

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      color: striped ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(_icon, color: levelColor),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.level.name.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: levelColor),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    _RelativeTime(
                      time: record.time,
                      style: theme.textTheme.labelSmall?.copyWith(color: levelColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                Text(
                  record.message,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: levelColor),
                ),
                const SizedBox(height: 2.0),
                if (record.error != null)
                  Text(record.error.toString(), style: theme.textTheme.labelMedium?.copyWith(color: levelColor)),
                Text(
                  record.loggerName,
                  style: theme.textTheme.labelMedium?.copyWith(color: levelColor.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
