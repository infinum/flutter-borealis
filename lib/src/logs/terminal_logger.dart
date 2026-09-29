part of 'logs.dart';

/// Logger name Loggy uses for Dio records. They are shown in the Network tab
/// instead, so the Logs tab drops them to avoid printing the same call twice.
const _kDioLoggerName = 'DioLoggy';

/// Color that represents a [LogLevel], shared by the log list rows and the
/// gamify popup so both render the same level the same way.
extension LogLevelColor on LogLevel {
  Color get color => switch (this) {
    LogLevel.error => Colors.redAccent,
    LogLevel.warning => Colors.orangeAccent,
    LogLevel.debug => Colors.lightBlueAccent,
    LogLevel.info => Colors.tealAccent,
    LogLevel() => Colors.grey,
  };
}

/// Capped, observable buffer of captured log records, newest first.
///
/// Extends [ChangeNotifier], so widgets wrapped in a [ListenableBuilder]
/// rebuild whenever a record arrives or the buffer is cleared.
class TerminalEventList extends ChangeNotifier {
  static const _maxEvents = kBorealisMaxStoredEntries;

  /// Newest first. A deque, so capturing a record is O(1) at both ends — a
  /// plain list would shift every element on each log line.
  final ListQueue<LogRecord> _events = ListQueue<LogRecord>();

  /// The captured records, newest first. Read-only: adding a record has to go
  /// through [add] so listeners are notified.
  late final List<LogRecord> events = _TerminalEventListView(_events);

  /// Records [event] as the newest entry, dropping the oldest ones past the
  /// [_maxEvents] cap, and notifies dependents.
  void add(LogRecord event) {
    _events.addFirst(event);
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
    notifyListeners();
  }

  /// Clears [events] and notifies dependents.
  void clear() {
    _events.clear();
    notifyListeners();
  }
}

/// Unmodifiable list view over the event deque. [ListQueue.elementAt] is O(1),
/// so indexed reads (the log list's `itemBuilder`) stay cheap.
class _TerminalEventListView extends ListBase<LogRecord> {
  _TerminalEventListView(this._events);

  final ListQueue<LogRecord> _events;

  @override
  int get length => _events.length;

  @override
  set length(int value) => throw UnsupportedError('Cannot resize an unmodifiable list');

  @override
  LogRecord operator [](int index) => _events.elementAt(index);

  @override
  void operator []=(int index, LogRecord value) => throw UnsupportedError('Cannot modify an unmodifiable list');
}

/// The shared log buffer the Logs tab reads from.
class TerminalLogger extends TerminalEventList {
  static final TerminalLogger instance = TerminalLogger();
}

/// [LoggyPrinter] that captures records for the Logs tab and forwards them to
/// a second printer (the console, by default).
class BorealisPrinter extends LoggyPrinter {
  BorealisPrinter({this.forwardPrinter = const PrettyPrinter(showColors: true)});

  final LoggyPrinter forwardPrinter;

  /// Called after every captured record. Optional hook for apps that want to
  /// react to new logs (e.g. flash their own indicator).
  static VoidCallback? onLogsChanged;

  @override
  void onLog(LogRecord record) {
    if (record.loggerName != _kDioLoggerName) {
      TerminalLogger.instance.add(record);
    }

    forwardPrinter.onLog(record);

    onLogsChanged?.call();
  }
}
