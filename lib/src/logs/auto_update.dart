part of 'logs.dart';

String _timeDifference(DateTime time, [DateTime? origin]) {
  origin ??= DateTime.now();
  final delta = origin.difference(time);
  if (delta.inSeconds < 90) {
    return '${delta.inSeconds} s';
  } else if (delta.inMinutes < 90) {
    return '${delta.inMinutes} m';
  } else {
    return '${delta.inHours} h';
  }
}

/// One timer for a whole list of relative timestamps.
///
/// Every visible row used to own a `Timer.periodic` and call `setState` on
/// itself once a second, so fifteen rows meant fifteen timers and fifteen
/// rebuilds a second. This keeps the one timer above the list and hands the
/// rows a [ValueListenable] to watch, so the rebuild still reaches only the
/// timestamps.
class _TimestampTicker extends StatefulWidget {
  const _TimestampTicker({required this.child});

  final Widget child;

  /// A second is the finest step [_timeDifference] renders.
  static const Duration interval = Duration(seconds: 1);

  /// The ticking clock the nearest ancestor ticker publishes, or `null` when
  /// there is none — in which case a row simply renders once.
  static ValueListenable<DateTime>? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TimestampTickerScope>()?.now;
  }

  @override
  State<_TimestampTicker> createState() => _TimestampTickerState();
}

class _TimestampTickerState extends State<_TimestampTicker> {
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_TimestampTicker.interval, (_) => _now.value = DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TimestampTickerScope(now: _now, child: widget.child);
}

class _TimestampTickerScope extends InheritedWidget {
  const _TimestampTickerScope({required this.now, required super.child});

  final ValueListenable<DateTime> now;

  @override
  bool updateShouldNotify(_TimestampTickerScope oldWidget) => oldWidget.now != now;
}

/// A record's age, refreshed by the nearest [_TimestampTicker].
class _RelativeTime extends StatelessWidget {
  const _RelativeTime({required this.time, this.style});

  final DateTime time;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final now = _TimestampTicker.maybeOf(context);
    if (now == null) return Text(_timeDifference(time), style: style);

    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (context, value, _) => Text(_timeDifference(time, value), style: style),
    );
  }
}
