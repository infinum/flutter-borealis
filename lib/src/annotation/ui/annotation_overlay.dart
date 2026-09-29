part of '../annotation.dart';

/// Transparent full-screen layer that captures taps while annotation mode is
/// active.
///
/// Mounted by [BorealisOverlay] above the app [targetKey]'s subtree but below
/// the floating button. Swallows every app tap; on tap it hit-tests the app
/// subtree, resolves the deepest meaningful widget, highlights it and opens a
/// note dialog. Saving records an [Annotation] in [store].
///
/// The tree walking lives in [_AnnotationResolver] and the saved-marker
/// bookkeeping in [_AnnotationMarkerTracker]; this widget owns the lifecycle,
/// the selection and the layers.
class AnnotationOverlay extends StatefulWidget {
  const AnnotationOverlay({super.key, required this.targetKey, this.store});

  /// Key attached to the app subtree to hit-test (the frozen current screen).
  final GlobalKey targetKey;

  /// Store to record annotations in. Defaults to [AnnotationStore.instance].
  final AnnotationStore? store;

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<AnnotationOverlay> with WidgetsBindingObserver {
  // Held in a notifier so the route page can rebuild on selection changes
  // without recreating the route (which would lose the dialog's Navigator).
  final ValueNotifier<_AnnotationTarget?> _selected = ValueNotifier(null);

  // Bumped whenever the app subtree relays out under a metrics change (keyboard
  // show/hide, rotation, resize) so the markers and the selected highlight
  // rebuild and recompute their positions against the new layout.
  final ValueNotifier<int> _relayout = ValueNotifier(0);

  late _AnnotationResolver _resolver;
  late _AnnotationMarkerTracker _markers;

  AnnotationStore get _store => widget.store ?? AnnotationStore.instance;

  @override
  void initState() {
    super.initState();
    _bindTracking();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_followLiveMarkers);
  }

  @override
  void didUpdateWidget(AnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The resolver captures the key it hit-tests and the tracker the store it
    // reads, so both have to be rebuilt when either changes: otherwise the
    // markers keep following the old subtree and reporting the old store's
    // annotations while saves and edits go to the new one.
    if (widget.targetKey != oldWidget.targetKey || widget.store != oldWidget.store) {
      _bindTracking();
      // The selection was resolved against the outgoing subtree.
      _selected.value = null;
    }
  }

  /// Points the resolver and the marker tracker at the current [targetKey] and
  /// store. The tracker's marker cache starts empty and is refilled by the next
  /// post-frame pass.
  void _bindTracking() {
    _resolver = _AnnotationResolver(widget.targetKey);
    _markers = _AnnotationMarkerTracker(store: _store, resolver: _resolver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relayout.dispose();
    _selected.dispose();
    super.dispose();
  }

  /// Keep the saved markers in sync with the live app in both modes: they
  /// follow their widgets as the screen scrolls AND drop/return as a dialog or
  /// route is pushed/popped over them (resolved via the per-marker visibility
  /// hit test in the tracker).
  ///
  /// Re-arms itself after every frame so it keeps tracking; this is a
  /// post-frame (not persistent) callback for two reasons — it runs post-layout
  /// so the hit test is safe even mid route transition (during build the app
  /// subtree may still need layout, and hit-testing it throws), and only here
  /// can the repaint it requests actually schedule a frame. Re-arming stops once
  /// unmounted, and a frame with no change requests nothing, so a still screen
  /// settles.
  void _followLiveMarkers(Duration _) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(_followLiveMarkers);

    if (_markers.refresh()) _relayout.value++;
  }

  @override
  void didChangeMetrics() {
    // The metrics (e.g. keyboard insets) change before the app subtree relays
    // out, so refresh on the next frame — once the render boxes report their
    // new positions — rather than reading stale ones in the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _relayout.value++;
    });
  }

  void _handleTap(Offset globalPosition, BuildContext context) {
    // The corner badge of a saved annotation edits it; a tap anywhere else —
    // including inside an already-annotated widget — resolves a fresh target,
    // so the same widget (or a nested one) can get another note.
    final badge = _markers.badgeAt(globalPosition);
    if (badge != null) {
      _editAnnotation(context, badge);
      return;
    }

    final fresh = _resolver.resolveTarget(globalPosition);
    if (fresh == null) return;

    // Tapping a spot that resolves to the already-selected widget broadens the
    // selection one annotatable widget *up*, toward the enclosing component;
    // past the outermost one it wraps back to the deepest target.
    final current = _selected.value;
    if (current != null && identical(fresh.firstElement, current.firstElement)) {
      _selected.value = _resolver.stepUp(current) ?? fresh;
    } else {
      _selected.value = fresh;
    }
  }

  Future<void> _showNoteSheet(BuildContext context, _AnnotationTarget target) async {
    final note = (await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NoteSheet(widgetType: target.widgetType),
    ))?.trim();

    if (!mounted) {
      return;
    }

    if (note != null && note.isNotEmpty) {
      // Resolved at save time (not at tap) so it reflects the widget actually
      // being saved — broadening the selection can change its type.
      final (ordinal, ordinalCount) = _resolver.ordinalOf(target.element);
      _store.add(
        Annotation(
          note: note,
          widgetType: target.widgetType,
          tappedWidgetRoute: target.tappedWidgetRoute,
          sourceLocation: target.sourceLocation,
          screenWidget: target.screenWidget,
          routeName: target.routeName,
          rect: target.rect,
          props: target.props,
          widgetKey: target.widgetKey,
          widgetOrdinal: ordinal,
          widgetOrdinalCount: ordinalCount,
          element: target.element,
        ),
      );
    }

    _selected.value = null;
  }

  /// Re-opens the note sheet for an existing [annotation]. Saving non-empty
  /// text updates it; saving empty (or Delete) removes it; Cancel leaves it.
  Future<void> _editAnnotation(BuildContext context, Annotation annotation) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NoteSheet(widgetType: annotation.widgetType, initial: annotation.note),
    );
    if (result == null) return; // Cancelled.
    if (result.trim().isEmpty) {
      _store.remove(annotation);
    } else {
      _store.updateNote(annotation, result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    // A dedicated borealis Navigator so the note sheet has a Navigator
    // ancestor — the app's Navigator is below BorealisOverlay, not above it.
    // HeroControllerScope.none keeps it from sharing the app's HeroController.
    // The Theme makes the overlay (info panel + sheet) use the Borealis theme.
    // The overlay is always mounted (so saved markers stay visible even when
    // capture is off); the route page swaps between the capture and the passive
    // layer based on whether annotation mode is active.
    return Theme(
      data: OverlayNestedNavigation.theme,
      child: HeroControllerScope.none(
        child: Navigator(
          // A barrier-free base route (not a PageRoute) so the passive layer
          // lets app taps through; a PageRoute's modal barrier would swallow
          // every tap. Active-mode blocking comes from the capture layer's own
          // opaque catcher. The Navigator exists only to host edit sheets.
          onGenerateRoute: (_) => _OverlayHostRoute(
            builder: (routeContext) => ValueListenableBuilder<bool>(
              valueListenable: _store.active,
              builder: (context, active, _) =>
                  active ? _buildCaptureLayer(routeContext) : _buildPassiveLayer(routeContext),
            ),
          ),
        ),
      ),
    );
  }

  /// Active annotation mode: a full-screen catcher swallows every app tap to
  /// resolve targets and edit badges, plus the saved markers and the current
  /// selection highlight. The app underneath is effectively frozen.
  Widget _buildCaptureLayer(BuildContext routeContext) {
    return ListenableBuilder(
      // Rebuild on selection changes and on relayout (keyboard, rotation,
      // resize) so the overlay tracks the live screen.
      listenable: Listenable.merge([_selected, _relayout]),
      builder: (context, _) {
        // Recompute the selection's rect from its live element so the highlight
        // follows the widget after the screen relays out.
        final selected = _selected.value?.withLiveRect();
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTap(details.globalPosition, routeContext),
              ),
            ),
            // Visual markers for already-saved annotations. Inert — the catcher
            // above handles badge-corner taps. Drawn from the tracker's cache,
            // resolved post-layout by [_followLiveMarkers]; never hit-test here
            // in build, where the app subtree (mid route/dialog transition) may
            // still need layout. Listening to [_store] schedules the frame whose
            // post-frame pass refreshes the cache when notes change.
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _store,
                builder: (context, _) => _SavedAnnotationMarkers(markers: _markers.markers),
              ),
            ),
            if (selected != null)
              _AnnotationHighlight(target: selected, onAddNote: () => _showNoteSheet(routeContext, selected)),
          ],
        );
      },
    );
  }

  /// Capture off: only the saved markers, drawn over a live app. Outlines are
  /// inert and non-badge taps fall through, so the app stays usable; badges
  /// stay tappable to edit their note. The markers come from the tracker,
  /// recomputed post-layout by [_followLiveMarkers] (which bumps [_relayout]),
  /// so they track scrolling and re-evaluate visibility without hit-testing
  /// during build.
  Widget _buildPassiveLayer(BuildContext routeContext) {
    return ListenableBuilder(
      listenable: Listenable.merge([_store, _relayout]),
      builder: (context, _) => _SavedAnnotationMarkers(
        markers: _markers.markers,
        onBadgeTap: (annotation) => _editAnnotation(routeContext, annotation),
      ),
    );
  }
}

/// Base route for the always-mounted overlay [Navigator]. Unlike a [PageRoute]
/// it installs no modal barrier, so when the passive layer is showing (capture
/// off) taps fall through to the live app instead of being swallowed. The
/// Navigator exists only so saved-note edit sheets have somewhere to be pushed.
class _OverlayHostRoute extends OverlayRoute<void> {
  _OverlayHostRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Iterable<OverlayEntry> createOverlayEntries() sync* {
    yield OverlayEntry(builder: builder, maintainState: true);
  }
}
