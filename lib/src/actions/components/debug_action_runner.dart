part of '../actions.dart';

/// The run discipline every debug action widget shares: one run at a time, a
/// spinner while an asynchronous callback is outstanding, and a failure that is
/// reported and marked rather than thrown or swallowed.
///
/// Written once because the four widgets had drifted while holding four copies
/// of it — one checked `mounted` after its dialog and another did not, one
/// raised its guard before the callback and another only once a `Future` came
/// back, and the error handling latched two of them off for good.
mixin _DebugActionRunner<W extends StatefulWidget> on State<W> {
  bool _loading = false;
  bool _running = false;
  bool _failed = false;

  /// Whether a spinner covers the control.
  bool get loading => _loading;

  /// Whether the last run threw.
  ///
  /// The control stays usable. A debug action that failed once — a flaky
  /// preferences read at startup, a backend that was down — usually works on
  /// the next tap, and disabling it for the session left no way back.
  bool get failed => _failed;

  /// Resolves [result], raising the spinner while a `Future` is outstanding.
  ///
  /// A synchronous callback never schedules a frame, so a control backed by one
  /// does not flicker.
  Future<T> resolve<T>(FutureOr<T> result) async {
    if (result is! Future<T>) return result;
    if (mounted) setState(() => _loading = true);
    return result;
  }

  /// Runs [body] under the shared guard, naming the control as [describe] in
  /// the error line.
  ///
  /// The guard is raised before [body] starts rather than when the first
  /// `Future` appears, so a callback with nothing to await is covered too, and
  /// so is the stretch where a control is waiting on its dialog.
  ///
  /// [onError] applies whatever the control has to undo — an optimistic switch
  /// flip, a selection already shown — and runs inside the same `setState` that
  /// records the failure.
  Future<void> runGuarded(String describe, Future<void> Function() body, {VoidCallback? onError}) async {
    if (_running) return;
    _running = true;
    try {
      await body();
      if (mounted && _failed) setState(() => _failed = false);
    } catch (error, stackTrace) {
      // Non-fatal by design: the panel stays usable and the console keeps the
      // detail. Awaited rather than handed to `onPressed`, so an async failure
      // is reported here instead of surfacing as an unhandled error.
      debugPrint('Borealis: $describe failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _failed = true;
          onError?.call();
        });
      }
    } finally {
      _running = false;
      if (_loading && mounted) setState(() => _loading = false);
    }
  }
}

/// Marks a control whose last run threw.
///
/// Deliberately quiet: the console holds the error, and the mark only has to
/// say which control to look at.
class _ActionFailureMark extends StatelessWidget {
  const _ActionFailureMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: 'Last run failed — the console has the error',
        child: Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// Outer padding shared by every debug action, so a list mixing the four types
/// lines up.
const EdgeInsets _actionPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 4);
