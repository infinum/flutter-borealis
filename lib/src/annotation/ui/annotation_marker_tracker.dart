part of '../annotation.dart';

/// Keeps the saved annotations of [store] mapped onto their current on-screen
/// positions, using [resolver] to read the live tree.
///
/// Owns the marker cache the overlay paints from: [refresh] recomputes it after
/// a frame and reports whether anything moved, so a still screen repaints
/// nothing.
class _AnnotationMarkerTracker {
  _AnnotationMarkerTracker({required this.store, required this.resolver});

  final AnnotationStore store;
  final _AnnotationResolver resolver;

  /// The markers to draw, resolved post-layout. Rendered as-is by both the
  /// capture and the passive layer.
  List<_AnnotationMarker> get markers => _markers;
  List<_AnnotationMarker> _markers = const [];

  /// Recomputes the markers; returns `true` when the visible set changed and
  /// the overlay has to repaint.
  bool refresh() {
    _reattachStaleAnnotations();
    final next = store.annotations.isEmpty ? const <_AnnotationMarker>[] : _liveMarkers();
    if (_sameMarkers(_markers, next)) return false;
    _markers = next;
    return true;
  }

  /// Whether two marker lists draw the same thing — same annotations, same
  /// numbers, same bounds to within a tenth of a pixel. Compared field by field
  /// rather than through a rendered signature: this runs after every frame.
  static bool _sameMarkers(List<_AnnotationMarker> a, List<_AnnotationMarker> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final first = a[i];
      final second = b[i];
      if (first.number != second.number) return false;
      if (!identical(first.annotation, second.annotation)) return false;
      final ra = first.rect;
      final rb = second.rect;
      if ((ra.left - rb.left).abs() > 0.1 ||
          (ra.top - rb.top).abs() > 0.1 ||
          (ra.width - rb.width).abs() > 0.1 ||
          (ra.height - rb.height).abs() > 0.1) {
        return false;
      }
    }
    return true;
  }

  /// The visible saved annotations resolved to their current on-screen
  /// positions, ready to draw. Skips annotations whose widget has been removed,
  /// scrolled out of view, or belongs to a screen other than the one shown;
  /// the badge [_AnnotationMarker.number] stays the 1-based store position so a
  /// given annotation keeps its number even when earlier ones are hidden.
  List<_AnnotationMarker> _liveMarkers() {
    final annotations = store.annotations;
    if (annotations.isEmpty) return const [];

    final viewport = resolver.appViewportRect();
    final markers = <_AnnotationMarker>[];
    for (var i = 0; i < annotations.length; i++) {
      final annotation = annotations[i];
      final rect = resolver.visibleRectOf(annotation, viewport);
      if (rect == null) continue;
      // Show only if the widget is the thing actually painted at its own
      // centre. This naturally keeps persistent shell chrome (bottom nav bar,
      // app bar) — still on top there — while hiding widgets a pushed
      // dialog/route covers, ones on a screen we navigated away from, or ones
      // scrolled under other content.
      if (!resolver.isVisibleAt(annotation, rect.center)) continue;
      markers.add(_AnnotationMarker(number: i + 1, rect: rect, annotation: annotation));
    }
    return markers;
  }

  /// The saved annotation whose corner badge sits under [position], topmost
  /// (most recently added) first; `null` when the tap missed every badge.
  ///
  /// A badge qualifies only when its annotation is still on the screen under
  /// [position] *and* its widget is currently visible: annotations saved on
  /// other screens, removed widgets, or widgets scrolled out of view must not
  /// be editable. The badge is hit-tested against the widget's *live* bounds so
  /// it tracks the widget after a scroll.
  Annotation? badgeAt(Offset position) {
    final annotations = store.annotations;
    if (annotations.isEmpty) return null;

    final (screenWidget, routeName) = resolver.screenIdentityAt(position);
    final viewport = resolver.appViewportRect();

    for (var i = annotations.length - 1; i >= 0; i--) {
      final annotation = annotations[i];
      if (annotation.screenWidget != screenWidget || annotation.routeName != routeName) continue;
      final rect = resolver.visibleRectOf(annotation, viewport);
      if (rect == null) continue;
      // Same occlusion test [_liveMarkers] applies, so only a badge that is
      // actually drawn can be tapped — a covered annotation has no badge on
      // screen and must not open its sheet from the spot where one would be.
      if (!resolver.isVisibleAt(annotation, rect.center)) continue;
      if (Rect.fromLTWH(rect.left, rect.top, _kBadgeSize, _kBadgeSize).contains(position)) {
        return annotation;
      }
    }
    return null;
  }

  /// Re-binds annotations whose element went stale (their screen was disposed)
  /// to the freshly created equivalent widget once that screen is shown again,
  /// so a note survives navigating away and back. Cheap when nothing is stale.
  ///
  /// Runs on every frame, and an annotation whose widget never comes back stays
  /// stale forever, so each probe has to stay cheap rather than be skipped —
  /// deferring one would strand it, since a frame is only ever scheduled by the
  /// change this sweep is looking for. [_AnnotationResolver.reresolveElement]
  /// keeps the repeat cost to a hit test and the cheap identity checks.
  void _reattachStaleAnnotations() {
    for (final annotation in store.annotations) {
      final element = annotation.element;
      if (element != null && element.mounted) continue;
      final rebound = resolver.reresolveElement(annotation);
      if (rebound != null) store.rebindElement(annotation, rebound);
    }
  }
}
