part of 'logs.dart';

/// The **Logs** tab: the records [BorealisPrinter] captures, newest first.
///
/// Install `BorealisPrinter` as the Loggy printer or this tab stays empty:
///
/// ```dart
/// Loggy.initLoggy(logPrinter: BorealisPrinter());
/// ```
///
/// It keeps the most recent 1000 records, colors each one by level and shows a
/// relative timestamp that ticks every second. A search bar filters by message
/// or logger name. Dio records are left out, because the **Network** tab shows
/// them in full.
///
/// Set [LogsConfig.onExport] to add an export action beside the search bar.
class LogsBorealisPage extends BorealisPage {
  const LogsBorealisPage({super.useAppTheme = false, this.logsConfig, this.eventList})
    : super(title: 'Logs', icon: Icons.terminal_outlined);

  /// The buffer this tab reads. Defaults to [TerminalLogger.instance], the one
  /// [BorealisPrinter] writes to.
  ///
  /// The badge, the clear action and the gamify popups all follow it. They used
  /// to be pinned to the singleton while the page below accepted a list of its
  /// own, so passing one made the badge count a different buffer than the tab
  /// displayed.
  final TerminalEventList? eventList;

  final LogsConfig? logsConfig;

  TerminalEventList get _events => eventList ?? TerminalLogger.instance;

  // Cached per buffer rather than held in one static, for the reason
  // [WiretapBorealisPage] gives: the page is const so it cannot build these
  // itself, and the overlay subscribes to them, so the same instance has to
  // come back on every call. Weakly keyed, so a short-lived buffer takes its
  // listenables with it.
  static final Expando<CountListenable> _badges = Expando('borealis.logsBadge');
  static final Expando<BorealisGamifyHook<LogRecord>> _gamifyHooks = Expando('borealis.logsGamify');

  @override
  Widget build(BuildContext context) => LogsPage(config: logsConfig, eventList: eventList);

  @override
  VoidCallback? get onClearTap => _events.clear;

  @override
  ValueListenable<int>? get badgeListenable {
    final events = _events;
    return _badges[events] ??= CountListenable(events, () => events.events.length);
  }

  BorealisGamifyHook<LogRecord> get _gamify {
    final events = _events;
    return _gamifyHooks[events] ??= BorealisGamifyHook<LogRecord>(
      source: events,
      latest: () => events.events.firstOrNull,
      toEvent: (record) => BorealisGamifyEvent(label: record.level.name.toUpperCase(), color: record.level.color),
    );
  }

  @override
  void onAttach() => _gamify.attach();

  @override
  void onDetach() => _gamifyHooks[_events]?.detach();
}
