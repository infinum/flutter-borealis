part of 'foundation.dart';

/// Global toggle for the gamified overlay. Flipped from the Rendering page
/// and read by the shell overlay.
final ValueNotifier<bool> gamifyBorealis = ValueNotifier(false);

/// A single gamified popup: what to show ([label]) and in which [color]. Where
/// it appears is decided by the overlay, not by the emitter.
class BorealisGamifyEvent {
  const BorealisGamifyEvent({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Pub/sub for gamified overlay popups.
///
/// Any page or external code can call [emit] to flash a label+color popup
/// over the floating debug button (when gamify is enabled). The overlay
/// subscribes to [events] when mounted.
class BorealisGamify {
  BorealisGamify._();

  static final BorealisGamify instance = BorealisGamify._();

  // Lives for the whole process: the singleton is the app-wide event bus, so
  // there is no point at which closing it would be correct.
  // ignore: close_sinks
  final _controller = StreamController<BorealisGamifyEvent>.broadcast();

  Stream<BorealisGamifyEvent> get events => _controller.stream;

  static void emit(BorealisGamifyEvent event) => instance._controller.add(event);
}

/// Emits a gamify popup whenever the newest item of a store changes.
///
/// Pages own one as a `static final` and call [attach] from
/// [BorealisPage.onAttach]; attaching twice is a no-op, so a page rebuilt or
/// listed twice still hooks the store only once.
///
/// [latest] must return the store's newest item (`null` when empty) and
/// [toEvent] turns it into the popup to emit — return `null` to skip one.
class BorealisGamifyHook<T extends Object> {
  BorealisGamifyHook({required this.source, required this.latest, required this.toEvent});

  /// The store to listen to; also the source [latest] reads from.
  final Listenable source;
  final T? Function() latest;
  final BorealisGamifyEvent? Function(T newest) toEvent;

  /// How many attachments are outstanding.
  ///
  /// Counted rather than flagged because one hook is shared by every page
  /// instance reading the same store. With two overlays mounted, the first to
  /// be disposed would otherwise detach a hook the second still relies on, and
  /// its popups would stop with nothing to explain it.
  int _attachCount = 0;

  T? _lastSeen;

  /// Whether this hook is currently listening.
  bool get isAttached => _attachCount > 0;

  void attach() {
    if (_attachCount++ > 0) return;
    // Seed with what is already there so mounting the overlay does not replay
    // the existing history as popups.
    _lastSeen = latest();
    source.addListener(_emit);
  }

  /// Releases one attachment, and stops listening once the last one goes.
  ///
  /// Safe to call when not attached, and [attach] re-seeds from the store, so
  /// a page can be detached and attached again without replaying what arrived
  /// in between.
  void detach() {
    if (_attachCount == 0) return;
    if (--_attachCount > 0) return;
    source.removeListener(_emit);
    _lastSeen = null;
  }

  void _emit() {
    // Nothing downstream is listening when the layer is unmounted, and this
    // runs once per captured request, so the formatting and the colour lookup
    // below would be per-request work for a feature that is off by default.
    if (!gamifyBorealis.value) return;

    final newest = latest();
    if (identical(_lastSeen, newest)) return;
    _lastSeen = newest;
    if (newest == null) return;
    final event = toEvent(newest);
    if (event != null) BorealisGamify.emit(event);
  }
}
