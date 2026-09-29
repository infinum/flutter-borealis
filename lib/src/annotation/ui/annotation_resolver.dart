part of '../annotation.dart';

/// Turns screen positions into annotation targets by hit-testing the app
/// subtree under [targetKey], and re-resolves saved annotations back onto the
/// live tree.
///
/// Pure query object: it reads the element tree and never mounts, paints or
/// stores anything. Split out of [AnnotationOverlay] so the widget keeps only
/// lifecycle and rendering, and so the tree walks can be reasoned about (and
/// exercised) on their own.
class _AnnotationResolver {
  const _AnnotationResolver(this.targetKey);

  /// Key on the app subtree to hit-test — the screen the user sees.
  final GlobalKey targetKey;

  Element? get _appRoot {
    // currentContext is a BuildContext, which is always an Element at runtime.
    return targetKey.currentContext as Element?;
  }

  RenderBox? get _appBox {
    final renderObject = targetKey.currentContext?.findRenderObject();
    return renderObject is RenderBox ? renderObject : null;
  }

  /// Global bounds of the hit-tested app subtree (the visible viewport), or
  /// `null` before it has laid out.
  Rect? appViewportRect() {
    final box = _appBox;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The deepest resolvable hit-test entry at [globalPosition], or `null` when
  /// nothing there can be annotated.
  HitTestEntry? _hitTestAt(Offset globalPosition) {
    final box = _appBox;
    if (box == null) return null;

    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(globalPosition));
    return firstAnnotationTarget(result.path, isResolvable: _isResolvableTarget);
  }

  /// Whether a hit-test [entry] points at a laid-out box with a creator element
  /// — the precondition for resolving it to an annotatable widget.
  bool _isResolvableTarget(HitTestEntry entry) {
    final target = entry.target;
    if (target is! RenderBox || !target.hasSize || target.size.isEmpty) return false;
    return _creatorElement(target) != null;
  }

  /// The annotation target under [globalPosition]: the deepest annotatable
  /// widget at or above the hit, with its drill path and screen identity.
  _AnnotationTarget? resolveTarget(Offset globalPosition) {
    final entry = _hitTestAt(globalPosition);
    if (entry == null) return null;

    final deepestBox = entry.target as RenderBox;
    final deepest = _creatorElement(deepestBox)!;

    // The selection matches what's under the finger: the deepest annotatable
    // widget at or above the hit. The deepest (framework) widget is the
    // fallback when nothing annotatable wraps it.
    final element = nearestAnnotatable(deepest) ?? deepest;
    final box = _renderBoxOf(element) ?? deepestBox;

    return _AnnotationTarget(
      element: element,
      firstElement: element,
      routeTypes: drillTypesFrom(element),
      rect: box.localToGlobal(Offset.zero) & box.size,
      screenWidget: screenWidgetOf(element),
      routeName: ModalRoute.settingsOf(element)?.name,
    );
  }

  /// The (screen widget type, route name) currently under [globalPosition] on
  /// the frozen app, mirroring how [resolveTarget] tags a fresh target;
  /// `(null, null)` when nothing resolves there.
  (String?, String?) screenIdentityAt(Offset globalPosition) {
    final entry = _hitTestAt(globalPosition);
    if (entry == null) return (null, null);

    final element = _creatorElement(entry.target as RenderBox)!;
    return (screenWidgetOf(element), ModalRoute.settingsOf(element)?.name);
  }

  /// The selection broadened one annotatable element from [current] toward the
  /// screen root, or `null` when [current] already is the outermost annotatable
  /// ancestor (so the caller wraps back to the deepest target).
  _AnnotationTarget? stepUp(_AnnotationTarget current) {
    final appRoot = _appRoot;
    Element? next;
    current.element.visitAncestorElements((ancestor) {
      if (identical(ancestor, appRoot)) return false;
      if (_isAnnotatable(ancestor) && _renderBoxOf(ancestor) != null) {
        next = ancestor;
        return false;
      }
      return true;
    });
    if (next == null) return null;

    final box = _renderBoxOf(next)!;
    return _AnnotationTarget(
      element: next!,
      firstElement: current.firstElement,
      // The path is already the full chain from the first tap; broadening only
      // moves the highlighted selection along it, so carry it unchanged.
      routeTypes: current.routeTypes,
      rect: box.localToGlobal(Offset.zero) & box.size,
      screenWidget: current.screenWidget,
      routeName: current.routeName,
    );
  }

  /// The complete drill chain for [start]: its own type, then every annotatable
  /// ancestor with a laid-out box up to (but not including) the app root,
  /// deepest first. This is the same walk [stepUp] performs one widget at a
  /// time, run eagerly so a single tap records the full biggest→deepest path
  /// without the user broadening the selection by hand.
  List<String> drillTypesFrom(Element start) {
    final appRoot = _appRoot;
    final types = [start.widget.runtimeType.toString()];
    start.visitAncestorElements((ancestor) {
      if (identical(ancestor, appRoot)) return false;
      if (_isAnnotatable(ancestor) && _renderBoxOf(ancestor) != null) {
        types.add(ancestor.widget.runtimeType.toString());
      }
      return true;
    });
    return types;
  }

  /// The deepest annotatable element at or above [start], or `null` when none
  /// exists up to the app root.
  Element? nearestAnnotatable(Element start) {
    final appRoot = _appRoot;
    if (_isAnnotatable(start)) return start;
    Element? found;
    start.visitAncestorElements((ancestor) {
      if (identical(ancestor, appRoot)) return false;
      if (_isAnnotatable(ancestor)) {
        found = ancestor;
        return false;
      }
      return true;
    });
    return found;
  }

  /// Runtime type of the outermost custom widget between [element] and the
  /// route boundary (the first [Navigator]/[Overlay] ancestor) — the screen
  /// the tap landed on, e.g. `HomePage`.
  String? screenWidgetOf(Element element) => screenRootOf(element)?.widget.runtimeType.toString();

  /// The outermost custom-widget element between [element] and the route
  /// boundary (the first [Navigator]/[Overlay] ancestor) — the root of the
  /// screen the tap landed on. `null` when no custom widget wraps it.
  Element? screenRootOf(Element element) {
    final appRoot = _appRoot;
    Element? screen = isCustomWidget(element) ? element : null;
    element.visitAncestorElements((ancestor) {
      if (identical(ancestor, appRoot)) return false;
      if (ancestor.widget is Navigator || ancestor.widget is Overlay) return false;
      if (isCustomWidget(ancestor)) screen = ancestor;
      return true;
    });
    return screen;
  }

  /// Position of [selected] among the same-type widgets on its screen, as
  /// `(ordinal, count)` — `ordinal` 1-based, ordered top-to-bottom then
  /// left-to-right. Lets the export tell two identical siblings (e.g. two
  /// `FloatingActionButton`s) apart. `(1, 1)` when it stands alone, and `(1, n)`
  /// as a safe fallback if [selected] can't be located among the matches.
  (int, int) ordinalOf(Element selected) {
    final root = screenRootOf(selected) ?? _appRoot;
    final type = selected.widget.runtimeType.toString();
    final matches = <Element>[];
    void visit(Element element) {
      final candidate = element.widget;
      if (candidate.runtimeType.toString() == type &&
          _renderBoxOf(element) != null &&
          debugIsWidgetLocalCreation(candidate)) {
        matches.add(element);
      }
      element.visitChildren(visit);
    }

    root?.visitChildren(visit);
    matches.sort((a, b) {
      final ra = _renderBoxOf(a)!.localToGlobal(Offset.zero);
      final rb = _renderBoxOf(b)!.localToGlobal(Offset.zero);
      final byTop = ra.dy.compareTo(rb.dy);
      return byTop != 0 ? byTop : ra.dx.compareTo(rb.dx);
    });

    final index = matches.indexWhere((element) => identical(element, selected));
    if (index < 0) return (1, matches.isEmpty ? 1 : matches.length);
    return (index + 1, matches.length);
  }

  /// The annotation widget's current global bounds, or `null` when it should no
  /// longer be shown — its element was unmounted (widget removed / different
  /// screen), it has no laid-out box, or it sits fully outside [viewport]
  /// (scrolled away). Recomputed from the live element so markers follow the
  /// widget when the user scrolls. An annotation whose element reference is
  /// gone (garbage-collected after its screen was disposed) is hidden too —
  /// never drawn at its stale captured rect — until [reresolveElement] re-binds
  /// it on the matching screen.
  Rect? visibleRectOf(Annotation annotation, Rect? viewport) {
    final element = annotation.element;
    if (element == null || !element.mounted) return null;
    final box = _renderBoxOf(element);
    if (box == null || !box.attached) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (viewport != null && !viewport.overlaps(rect)) return null;
    return rect;
  }

  /// Whether [annotation]'s widget is the one painted at [position] — i.e. its
  /// render box is in the hit-test path there. False when something covers it:
  /// a pushed dialog/route, an overlapping widget, a screen we navigated to, or
  /// the chrome it scrolled under. Annotations with no live element can't be
  /// occlusion-tested, so they are hidden until re-bound.
  bool isVisibleAt(Annotation annotation, Offset position) {
    final element = annotation.element;
    if (element == null) return false;
    final box = _appBox;
    if (box == null) return true;
    final target = _renderBoxOf(element);
    if (target == null) return false;

    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(position));
    for (final entry in result.path) {
      if (identical(entry.target, target)) return true;
    }
    return false;
  }

  /// Finds the live element [annotation] should now point at: the widget of the
  /// same [Annotation.widgetType] at the same bounds, on the same screen — and
  /// with the same captured identity (key, creation site, text content) — as
  /// when it was saved. `null` when that screen is not the one currently painted
  /// at the saved spot (navigated away) or no matching widget sits there.
  Element? reresolveElement(Annotation annotation) {
    final entry = _hitTestAt(annotation.rect.center);
    if (entry == null) return null;
    final deepest = _creatorElement(entry.target as RenderBox)!;

    // Must be the same screen showing at that spot.
    if (screenWidgetOf(deepest) != annotation.screenWidget ||
        ModalRoute.settingsOf(deepest)?.name != annotation.routeName) {
      return null;
    }

    // The recreated widget: same type, (re-laid-out to the) same bounds and
    // the same captured identity.
    bool matches(Element element) {
      if (element.widget.runtimeType.toString() != annotation.widgetType) return false;
      final box = _renderBoxOf(element);
      if (box == null) return false;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      return _rectsAlign(rect, annotation.rect) && _matchesCapturedIdentity(annotation, element, rect);
    }

    if (matches(deepest)) return deepest;
    final appRoot = _appRoot;
    Element? match;
    deepest.visitAncestorElements((ancestor) {
      if (identical(ancestor, appRoot)) return false;
      if (matches(ancestor)) {
        match = ancestor;
        return false;
      }
      return true;
    });
    return match;
  }

  /// Whether two rects describe the same widget bounds, within 1 logical pixel.
  static bool _rectsAlign(Rect a, Rect b) =>
      (a.center - b.center).distance < 1.0 && (a.width - b.width).abs() < 1.0 && (a.height - b.height).abs() < 1.0;

  /// Whether [element] carries the identity captured on [annotation] beyond
  /// type and bounds: the same widget key, creation site and text content.
  /// Guards re-binding against look-alikes sitting at the annotated spot — a
  /// same-type widget on another instance of the same screen class (showing
  /// different data), a recycled list item, or a sibling with a different key.
  /// Creation site and text are compared only when both sides resolved
  /// (profile builds track no creation locations, and not every widget has
  /// text), so unknowns stay permissive rather than orphaning the annotation.
  static bool _matchesCapturedIdentity(Annotation annotation, Element element, Rect rect) {
    final live = _AnnotationTarget(
      element: element,
      firstElement: element,
      routeTypes: const [],
      rect: rect,
      screenWidget: annotation.screenWidget,
      routeName: annotation.routeName,
    );
    if (live.widgetKey != annotation.widgetKey) return false;

    final savedText = annotation.props['text'];
    final liveText = live._text()?.text;
    if (savedText != null && liveText != null && savedText != liveText) return false;

    // Last: the only check that can reach the widget inspector. A stale
    // annotation is re-probed on every frame, so the cheap discriminators above
    // rule out the common look-alike first (and see [_sourceLocations], which
    // keeps a repeat probe of the same widget off the inspector entirely).
    final savedLocation = annotation.sourceLocation;
    final liveLocation = live.sourceLocation;
    if (savedLocation != null && liveLocation != null && savedLocation != liveLocation) return false;

    return true;
  }
}
