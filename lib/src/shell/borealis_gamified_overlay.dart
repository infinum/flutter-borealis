part of 'shell.dart';

class _BorealisGamifiedOverlay extends StatefulWidget {
  const _BorealisGamifiedOverlay({required this.position});

  final Offset position;

  @override
  State<_BorealisGamifiedOverlay> createState() => _BorealisGamifiedOverlayState();
}

const _kPopupDuration = Duration(milliseconds: 2800);

class _BorealisGamifiedOverlayState extends State<_BorealisGamifiedOverlay> {
  static const _spawnInterval = Duration(milliseconds: 250);

  // Cap how far ahead popups may be scheduled. During a sustained burst
  // (events arriving faster than [_spawnInterval]) the horizon would otherwise
  // run away, piling up Future.delayed callbacks; events past this window are
  // dropped instead.
  static const _maxSpawnBacklog = Duration(seconds: 2);

  final Random _random = Random();
  final ValueNotifier<List<_DamagePopup>> _popups = ValueNotifier(<_DamagePopup>[]);
  int _idCounter = 0;

  /// Monotonic, unlike the wall clock: a clock that jumps forward — an NTP
  /// correction, a manual change — would otherwise push the spawn horizon into
  /// the future and silently drop every popup after it, with no way back short
  /// of restarting the app.
  final Stopwatch _clock = Stopwatch()..start();

  /// Earliest point on [_clock] at which the next popup may appear.
  Duration _nextPopupAt = Duration.zero;

  StreamSubscription<BorealisGamifyEvent>? _sub;

  @override
  void initState() {
    super.initState();
    // The stream listener lives for the widget's lifetime and reads
    // widget.position on each spawn, so popups always appear at the button's
    // current location.
    _sub = BorealisGamify.instance.events.listen((event) => _spawnPopup(event));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _popups.dispose();
    super.dispose();
  }

  void _spawnNow(BorealisGamifyEvent event) {
    final nextId = ++_idCounter;
    final isCrit = _random.nextDouble() > 0.8;
    final dxJitter = (_random.nextDouble() * 36) - 18;
    final dyJitter = (_random.nextDouble() * 12) - 6;
    final popup = _DamagePopup(
      id: nextId,
      event: event,
      isCrit: isCrit,
      spawnLeft: widget.position.dx + dxJitter,
      spawnTop: widget.position.dy + dyJitter,
    );

    _popups.value = <_DamagePopup>[..._popups.value, popup];
    // Removed only once its rise/fade animation has played out, so the popup
    // does not vanish mid-animation.
    Future<void>.delayed(_kPopupDuration, () {
      if (!mounted) return;
      _popups.value = _popups.value.where((item) => item.id != nextId).toList(growable: false);
    });
  }

  void _spawnPopup(BorealisGamifyEvent event) {
    final now = _clock.elapsed;
    final scheduledAt = now > _nextPopupAt ? now : _nextPopupAt;
    final wait = scheduledAt - now;

    // Drop the event without advancing the horizon when the backlog is full.
    if (wait > _maxSpawnBacklog) return;

    _nextPopupAt = scheduledAt + _spawnInterval;

    if (wait > Duration.zero) {
      Future.delayed(wait, () {
        if (!mounted) return;
        _spawnNow(event);
      });
      return;
    }

    _spawnNow(event);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: ValueListenableBuilder<List<_DamagePopup>>(
          valueListenable: _popups,
          builder: (context, popups, _) {
            final size = MediaQuery.sizeOf(context).width / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Keyed by popup id: without a key the children are matched by
                // index, so removing an expired popup shifts every later one
                // onto a different element and restarts its animation.
                for (final popup in popups)
                  Positioned(
                    key: ValueKey<int>(popup.id),
                    left: popup.spawnLeft > size ? null : popup.spawnLeft.abs(),
                    right: popup.spawnLeft > size ? ((size * 2) - popup.spawnLeft - 36).abs() : null,
                    top: popup.spawnTop,
                    child: _DamagePopupWidget(popup: popup),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DamagePopup {
  const _DamagePopup({
    required this.id,
    required this.event,
    required this.isCrit,
    required this.spawnLeft,
    required this.spawnTop,
  });

  final int id;
  final BorealisGamifyEvent event;
  final bool isCrit;
  final double spawnLeft;
  final double spawnTop;
}

class _DamagePopupWidget extends StatelessWidget {
  const _DamagePopupWidget({required this.popup});

  final _DamagePopup popup;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _kPopupDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final rise = value * 80;
        final scale = 0.4 + (value * 0.8);

        final opacity = ((1 - value) * 1.5).clamp(0.0, 1.0);

        return Transform(
          transform: Matrix4.identity()
            ..setTranslationRaw(0, -rise, 0)
            ..scaleByDouble(scale, scale, scale, 1),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: Text(
          popup.event.label,
          style: TextStyle(
            color: popup.event.color,
            fontSize: popup.isCrit ? 18 : 14,
            fontWeight: popup.isCrit ? FontWeight.w900 : FontWeight.w700,
            shadows: <Shadow>[const Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)],
          ),
        ),
      ),
    );
  }
}
