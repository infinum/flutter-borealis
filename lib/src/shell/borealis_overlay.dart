part of 'shell.dart';

/// Hosts the floating debug button and the panel it opens.
///
/// Wrap the app once, usually through `MaterialApp.builder`, and list the
/// pages that become tabs:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => BorealisOverlay(
///     pages: const [
///       DeviceInfoBorealisPage(),
///       LogsBorealisPage(),
///       WiretapBorealisPage(),
///     ],
///     child: child!,
///   ),
///   home: const HomeScreen(),
/// )
/// ```
///
/// The overlay adds no page of its own, so [pages] decides both the tabs and
/// their order. It hosts its own navigator, so the panel opens from any
/// context and needs no navigator key.
///
/// A draggable red button floats above [child] and settles against the nearest
/// side edge when released. Tapping it opens the panel. A page can take the
/// button over while it is showing, through
/// [BorealisPage.replaceBorealisButton]; a long press always opens the panel
/// anyway.
///
/// With [BorealisSettings.enabled] set to `false` the overlay renders [child]
/// alone. That hides the UI only — read `BorealisSettings.enabled` for what it
/// does not do.
class BorealisOverlay extends StatefulWidget {
  const BorealisOverlay({
    super.key,
    required this.child,
    required this.pages,
    this.settings = const BorealisSettings(),
  });

  /// The app the overlay sits above.
  final Widget child;

  /// Behavior options. Defaults to `const BorealisSettings()`.
  final BorealisSettings settings;

  /// The pages to show as tabs, in the order given. Must not be empty.
  final List<BorealisPage> pages;

  @override
  State<BorealisOverlay> createState() => _BorealisOverlayState();
}

class _BorealisOverlayState extends State<BorealisOverlay> {
  // Stable key on the app subtree.
  final GlobalKey _appKey = GlobalKey();

  static const double _buttonSize = 52;

  // Null until the first frame positions the button from the screen bounds.
  final ValueNotifier<Offset?> _position = ValueNotifier(null);

  // Hide the button while the debug panel is presented.
  final ValueNotifier<bool> _visible = ValueNotifier(true);

  late final ValueNotifier<int> _currentPage;

  Size? _lastScreenSize;

  /// The page instances [BorealisPage.onAttach] has already run for.
  ///
  /// Identity, not equality: pages carry no `==`, and every built-in is
  /// `const`, so the same instance comes back on every rebuild and each one
  /// attaches exactly once. `didUpdateWidget` used to re-attach the whole list,
  /// which fires on every rebuild of the app above the overlay.
  final Set<BorealisPage> _attachedPages = Set.identity();

  @override
  void initState() {
    super.initState();
    if (widget.pages.isEmpty) {
      throw ArgumentError.value(widget.pages, 'pages', 'BorealisOverlay requires at least one page');
    }
    _currentPage = ValueNotifier(_clampPage(widget.settings.initialPage));
    _applySettings(null);
  }

  @override
  void didUpdateWidget(covariant BorealisOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The retained index can point past the end when the page list shrinks.
    if (widget.pages.length != oldWidget.pages.length) {
      _currentPage.value = _clampPage(_currentPage.value);
    }
    _applySettings(oldWidget.settings);
  }

  /// Pushes the settings that reach beyond this widget, and keeps page
  /// attachment in step with them. [previous] is null on the first pass.
  ///
  /// Everything here is skipped while the overlay is disabled, because
  /// `BorealisSettings.enabled` promises no overhead: writing the global gamify
  /// flag and attaching store listeners from a `build` that returns the child
  /// untouched is overhead by any reading. Enabling the overlay later runs them
  /// then.
  void _applySettings(BorealisSettings? previous) {
    if (!widget.settings.enabled) {
      _detachPages();
      return;
    }
    // Written only when the declared value changes. The Rendering tab flips
    // this global at runtime, and a rebuild of the app above the overlay must
    // not undo that.
    if (previous == null || !previous.enabled || previous.gamify != widget.settings.gamify) {
      gamifyBorealis.value = widget.settings.gamify;
    }
    for (final page in widget.pages) {
      if (_attachedPages.add(page)) page.onAttach();
    }
    // A page dropped from the list has left this overlay.
    final current = Set<BorealisPage>.identity()..addAll(widget.pages);
    for (final page in _attachedPages.toList()) {
      if (!current.contains(page)) {
        _attachedPages.remove(page);
        page.onDetach();
      }
    }
  }

  void _detachPages() {
    for (final page in _attachedPages) {
      page.onDetach();
    }
    _attachedPages.clear();
  }

  // Guards against an out-of-range page index. The empty-list case is rejected
  // in initState, so this only has to cope with a list that shrank.
  int _clampPage(int page) => widget.pages.isEmpty ? 0 : page.clamp(0, widget.pages.length - 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reposition the button when the screen size changes (mirrors keying the
    // original effect on MediaQuery.sizeOf).
    // Aspect-scoped, matching build. `MediaQuery.of` subscribes to every
    // aspect, so the overlay — and the whole app beneath it — rebuilt on each
    // keyboard inset and text-scale change.
    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (screenSize == _lastScreenSize) return;
    _lastScreenSize = screenSize;

    final resting = _restingPosition(screenSize, viewPadding);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _position.value = resting;
    });
  }

  /// Where the button sits before it is dragged: against the left edge, a fifth
  /// of the way down the usable height and never above 150px.
  static Offset _restingPosition(Size screenSize, EdgeInsets viewPadding) {
    return Offset(viewPadding.left, max(150, _maxTop(screenSize, viewPadding) * 0.2));
  }

  /// Largest top offset that still leaves the whole button on screen.
  ///
  /// Subtracts the bottom inset alone. `viewPadding.vertical` is top plus
  /// bottom, and since the offset is measured from the top of a full-screen
  /// stack that counted the top inset twice and shortened the reachable band.
  static double _maxTop(Size screenSize, EdgeInsets viewPadding) =>
      max(viewPadding.top, screenSize.height - _buttonSize - viewPadding.bottom);

  /// Largest left offset that still leaves the whole button on screen.
  static double _maxLeft(Size screenSize, EdgeInsets viewPadding) =>
      max(viewPadding.left, screenSize.width - _buttonSize - viewPadding.right);

  /// Gap left between the button and the edge it snaps to.
  static const double _edgeInset = 2;

  /// Marks the layer the button is positioned within, so a drag can be read in
  /// that layer's coordinates. `globalPosition` matches only when the overlay
  /// happens to fill the window, and [BorealisOverlay] can be placed anywhere.
  final GlobalKey _dragSurfaceKey = GlobalKey();

  /// Where inside the button the current drag started.
  Offset _dragGrab = Offset.zero;

  /// Built once. `Listenable.merge` returns a new object each call and defines
  /// no `==`, so creating these in `build` made every rebuild tear down and
  /// re-establish both subscriptions.
  late final Listenable _gamifyLayerTriggers = Listenable.merge([gamifyBorealis, _position]);
  late final Listenable _buttonTriggers = Listenable.merge([_visible, _position]);

  Offset _dragSurfaceOffset(Offset globalPosition) {
    final box = _dragSurfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return globalPosition;
    return box.globalToLocal(globalPosition);
  }

  @override
  void dispose() {
    _detachPages();
    _position.dispose();
    _visible.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  /// Opens the panel on [page] and hides the button behind it.
  ///
  /// [context] must sit below the overlay's own [Overlay.wrap], which is what
  /// [DebugPanel.show] inserts into.
  void _openPanel(BuildContext context, int page) {
    _currentPage.value = page;
    DebugPanel.show(
      context,
      pages: widget.pages,
      onDismiss: () {
        if (!mounted) return;
        _visible.value = true;
      },
      currentPage: page,
      onPageChange: (page) {
        if (!mounted) return;
        // The panel indexes the list it was opened with, which can be longer
        // than the current one.
        _currentPage.value = _clampPage(page);
      },
    );
    _visible.value = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.enabled) {
      return widget.child;
    }

    final viewPadding = MediaQuery.viewPaddingOf(context);
    final screenSize = MediaQuery.sizeOf(context);
    final minY = viewPadding.top;
    final maxY = _maxTop(screenSize, viewPadding);
    final minX = viewPadding.left;
    final maxX = _maxLeft(screenSize, viewPadding);

    final defaultPosition = _restingPosition(screenSize, viewPadding);
    final borealisPages = widget.pages;

    final button = _FloatingBorealisButton(pages: borealisPages, currentPage: _currentPage, onOpen: _openPanel);

    return Stack(
      children: [
        KeyedSubtree(key: _appKey, child: widget.child),
        // Rebuilds only when gamify toggles or the button moves.
        ListenableBuilder(
          listenable: _gamifyLayerTriggers,
          builder: (context, _) {
            if (!gamifyBorealis.value) return const SizedBox.shrink();
            return _BorealisGamifiedOverlay(position: _position.value ?? defaultPosition);
          },
        ),
        // Always mounted: saved annotation markers stay visible even when
        // capture is off. The overlay swaps between its capture and passive
        // layers internally based on AnnotationStore.active.
        Builder(
          builder: (context) => Stack(
            fit: StackFit.expand,
            children: [
              for (final page in borealisPages)
                if (page.stackPage(context, _appKey) case final layer?) Positioned.fill(child: layer),
            ],
          ),
        ),
        Positioned.fill(
          key: _dragSurfaceKey,
          child: Overlay.wrap(
            // Rebuilds only when visibility or the button position changes;
            // the button itself is passed as [child] so it is not rebuilt.
            child: ListenableBuilder(
              listenable: _buttonTriggers,
              builder: (context, child) {
                final position = _position.value ?? defaultPosition;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_visible.value)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        top: position.dy,
                        left: position.dx,
                        child: GestureDetector(
                          // Where inside the button the finger went down, so
                          // the button follows the drag instead of jumping its
                          // own top-left under the finger on the first move.
                          onPanStart: (details) => _dragGrab = details.localPosition,
                          onPanUpdate: (details) {
                            final target = _dragSurfaceOffset(details.globalPosition) - _dragGrab;
                            // Clamped here, not only on release: the button
                            // could otherwise be dragged off the screen and
                            // only reappear when the finger lifted.
                            _position.value = Offset(target.dx.clamp(minX, maxX), target.dy.clamp(minY, maxY));
                          },
                          onPanEnd: (_) {
                            // Snap to whichever edge the button — not the
                            // finger — ended up nearer.
                            final current = _position.value ?? defaultPosition;
                            final towardsLeft = (current.dx - minX) < (maxX - current.dx);
                            _position.value = Offset(
                              towardsLeft ? minX + _edgeInset : maxX - _edgeInset,
                              current.dy.clamp(minY, maxY),
                            );
                            _dragGrab = Offset.zero;
                          },
                          child: child,
                        ),
                      ),
                  ],
                );
              },
              child: button,
            ),
          ),
        ),
      ],
    );
  }
}

/// The draggable button that opens the debug panel.
///
/// A page may take it over through [BorealisPage.replaceBorealisButton] — the
/// Annotations tab turns it into a ✕ while capture is on — so a long press
/// always opens the panel, which is the only way back in.
class _FloatingBorealisButton extends StatelessWidget {
  const _FloatingBorealisButton({required this.pages, required this.currentPage, required this.onOpen});

  final List<BorealisPage> pages;
  final ValueListenable<int> currentPage;

  /// Takes a context below [Overlay.wrap], which is what the panel is inserted
  /// into, so the [Builder] below is load-bearing.
  final void Function(BuildContext context, int page) onOpen;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return ValueListenableBuilder<int>(
          valueListenable: currentPage,
          builder: (context, page, _) {
            return ValueListenableBuilder<BorealisButtonReplacement?>(
              valueListenable: pages[page].replaceBorealisButton,
              builder: (context, replacement, _) {
                return ElevatedButton(
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: WidgetStateProperty.all(
                      replacement?.borderSide ?? BorderSide(color: replacement?.color ?? Colors.red),
                    ),
                    backgroundColor: WidgetStateProperty.all(replacement?.color ?? Colors.red),
                    padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
                    minimumSize: WidgetStateProperty.all(Size.zero),
                    shape: WidgetStateProperty.all(const CircleBorder()),
                  ),
                  onPressed: () {
                    if (replacement != null) {
                      replacement.onTap();
                    } else {
                      onOpen(context, page);
                    }
                  },
                  // Long-press always opens the panel, even while a page has
                  // taken the button over — it is the only way back in.
                  onLongPress: () => onOpen(context, page),
                  child: Icon(
                    replacement?.icon ?? Icons.bug_report,
                    color: replacement?.iconColor ?? Colors.white,
                    size: 24,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
