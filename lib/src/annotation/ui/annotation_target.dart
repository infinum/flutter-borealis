part of '../annotation.dart';

/// Creation locations already resolved, keyed weakly on the element they were
/// read from and validated against the widget instance that produced them.
///
/// [_AnnotationTarget.sourceLocation] only caches within one target instance,
/// and the re-attach check builds a throwaway target for the same element on
/// every frame for as long as an annotation stays stale — an annotation whose
/// widget never comes back stays stale forever. Without this the inspector
/// round trip below would repeat on every frame, forever. Entries die with
/// their element, and a rebuild that swaps in a different widget instance
/// re-resolves (the same element slot can be filled from another call site).
final Expando<({Widget widget, String? location})> _sourceLocations = Expando('borealis.sourceLocation');

/// Resolved details about a tapped widget, lazily extracted from its [element].
class _AnnotationTarget {
  _AnnotationTarget({
    required this.element,
    required this.firstElement,
    required this.routeTypes,
    required this.rect,
    required this.screenWidget,
    required this.routeName,
  });

  final Element element;

  /// The element the tap originally resolved to (the deepest annotatable pick);
  /// used to detect repeat taps. The selection broadens up from here.
  final Element firstElement;

  /// Runtime types of the full drill chain — the tapped target then every
  /// annotatable ancestor up to the screen root — deepest first, broadest last.
  /// Resolved from a single tap, so [tappedWidgetRoute] holds the whole path
  /// without the user broadening the selection by hand.
  final List<String> routeTypes;

  final Rect rect;

  /// Runtime type of the screen's root custom widget, e.g. `HomePage`.
  final String? screenWidget;

  /// Name of the [ModalRoute] the target lives in; `null` for unnamed routes.
  final String? routeName;

  /// A copy with [rect] recomputed from the live [element]'s current bounds, so
  /// the highlight tracks the widget after the screen relays out (keyboard,
  /// rotation, resize). Returns itself unchanged when the element is gone or
  /// not laid out.
  _AnnotationTarget withLiveRect() {
    if (!element.mounted) return this;
    final box = _renderBoxOf(element);
    if (box == null || !box.attached) return this;
    return _AnnotationTarget(
      element: element,
      firstElement: firstElement,
      routeTypes: routeTypes,
      rect: box.localToGlobal(Offset.zero) & box.size,
      screenWidget: screenWidget,
      routeName: routeName,
    );
  }

  String get widgetType => element.widget.runtimeType.toString();

  /// String form of the selected widget's [Key] (e.g. `[<'saveFab'>]`), or
  /// `null` when unkeyed. An exact id for telling identical siblings apart.
  String? get widgetKey => element.widget.key?.toString();

  /// The drill path from the broadest selection down to the deepest target,
  /// e.g. `Card>Button>Icon` — biggest widget first, drilling in to the tapped
  /// one. [routeTypes] is stored deepest-first, so reverse it for display.
  String get tappedWidgetRoute => routeTypes.reversed.join('>');

  /// Best-effort `file:line` where the target widget was created. Resolved
  /// through the public inspector serialization path, which emits a
  /// `creationLocation` when widget creation tracking is on (debug builds);
  /// `null` otherwise.
  ///
  /// Resolved once — the inspector round-trip is expensive and this is read
  /// from build methods and from the re-attach check.
  late final String? sourceLocation = _resolveSourceLocation();

  String? _resolveSourceLocation() {
    final cached = _sourceLocations[element];
    if (cached != null && identical(cached.widget, element.widget)) return cached.location;

    final location = _readSourceLocation();
    _sourceLocations[element] = (widget: element.widget, location: location);
    return location;
  }

  String? _readSourceLocation() {
    final json = element.toDiagnosticsNode().toJsonMap(
      InspectorSerializationDelegate(service: WidgetInspectorService.instance, subtreeDepth: 0),
    );
    final location = json['creationLocation'];
    if (location is! Map<String, Object?>) return null;
    final file = location['file'];
    final line = location['line'];
    if (file is! String || line is! int) return null;
    return '${_shortPath(file)}:$line';
  }

  /// Shortens a `file://` URI to a project-relative path where possible.
  static String _shortPath(String file) {
    final path = Uri.tryParse(file)?.path ?? file;
    for (final marker in ['/lib/', '/test/']) {
      final index = path.lastIndexOf(marker);
      if (index >= 0) return path.substring(index + 1);
    }
    final segments = path.split('/');
    return segments.length <= 2 ? path : segments.sublist(segments.length - 2).join('/');
  }

  /// Open-ended display-only properties shown in the inspect info window (e.g.
  /// `text`, `color`, `size`, `padding`). Empty when nothing resolved.
  ///
  /// Resolved once: each lookup walks the subtree, and this is read on every
  /// rebuild of the info window.
  late final Map<String, String> props = _resolveProps();

  Map<String, String> _resolveProps() {
    final map = <String, String>{};

    final text = _text();
    if (text != null) {
      if (text.text != null) {
        map['text'] = text.text!;
      }

      final style = text.textStyle;
      if (style != null) {
        map['fontSize'] = style.fontSize?.toStringAsFixed(1) ?? '';
        map['fontColor'] = style.color != null ? _hex(style.color!) : '';
      }
    }

    final color = _color();
    if (color != null) map['color'] = _hex(color);

    final padding = _padding();
    if (padding != null) map['padding'] = padding.toString();

    final border = _border();
    if (border != null) {
      if (border.radius != null) map['borderRadius'] = border.radius!;
      if (border.color != null) map['borderColor'] = _hex(border.color!);
    }

    map['size'] = '${rect.width.toStringAsFixed(0)}x${rect.height.toStringAsFixed(0)}';

    return map;
  }

  /// Text content and style of the target (or the first text-ish widget below
  /// it). Icons report their glyph and code point.
  ({String? text, TextStyle? textStyle})? _text() {
    return _getPropertyFromType([Icon, Text, RichText, SelectableText], (widget) {
      switch (widget) {
        case Icon(:final icon, :final color):
          final codePoint = icon?.codePoint;
          final glyph = String.fromCharCode(codePoint ?? 0);
          return (text: 'Icon(${icon?.fontFamily}, $glyph, codePoint: $codePoint)', textStyle: TextStyle(color: color));
        case SelectableText(:final data, :final textSpan, :final style):
          return (text: data ?? textSpan?.toPlainText(), textStyle: style);
        case Text(:final data, :final textSpan, :final style):
          return (text: data ?? textSpan?.toPlainText(), textStyle: style);
        case RichText(:final text):
          return (text: text.toPlainText(), textStyle: text.style);
        default:
          return null;
      }
    });
  }

  String? _padding() {
    return _getPropertyFromType([Padding, Container], (widget) {
      return switch (widget) {
        Padding(:final padding) => padding,
        Container(:final padding) => padding,
        _ => null,
      };
    })?.toString();
  }

  /// Corner radius and stroke color of the target's decoration, when it has one.
  ({String? radius, Color? color})? _border() {
    return _getPropertyFromType([Container, Material, DecoratedBox], (widget) {
      if (widget is Material) {
        final radius = widget.borderRadius;
        if (radius == null) return null;
        return (radius: radius.toString(), color: _shapeBorderColor(widget.shape));
      }

      final decoration = switch (widget) {
        Container(:final decoration) => decoration,
        DecoratedBox(:final decoration) => decoration,
        _ => null,
      };

      return switch (decoration) {
        BoxDecoration(:final borderRadius, :final border) when borderRadius != null => (
          radius: borderRadius.toString(),
          color: _boxBorderColor(border),
        ),
        ShapeDecoration(:final shape) => (radius: shape.toString(), color: _shapeBorderColor(shape)),
        _ => null,
      };
    });
  }

  /// Stroke color of a [BoxBorder]'s first visible side, or `null` when no side
  /// is visible or the border type is unsupported. The decoration's fill color
  /// is intentionally ignored.
  static Color? _boxBorderColor(BoxBorder? border) {
    final List<BorderSide> sides;
    if (border is Border) {
      sides = [border.top, border.right, border.bottom, border.left];
    } else if (border is BorderDirectional) {
      sides = [border.top, border.start, border.end, border.bottom];
    } else {
      return null;
    }
    for (final side in sides) {
      if (side.style != BorderStyle.none) return side.color;
    }
    return null;
  }

  /// Stroke color of a [ShapeBorder]'s outline, or `null` when it has none.
  /// The decoration's fill color is intentionally ignored.
  static Color? _shapeBorderColor(ShapeBorder? shape) {
    if (shape is! OutlinedBorder) return null;
    final side = shape.side;
    return side.style == BorderStyle.none ? null : side.color;
  }

  Color? _color() {
    return _getPropertyFromType([ColoredBox, Material, Container, DecoratedBox], (widget) {
      return switch (widget) {
        ColoredBox(:final color) => color,
        Material(:final color) => color,
        // A Container's decoration colour wins over its `color` shorthand —
        // they are mutually exclusive, but the decoration is the richer one.
        Container(:final decoration, :final color) => decoration is BoxDecoration ? decoration.color ?? color : color,
        DecoratedBox(:final decoration) => decoration is BoxDecoration ? decoration.color : null,
        _ => null,
      };
    });
  }

  /// The first non-null value [extract] yields for a widget of one of [types],
  /// looking at the target itself first and then at its nearest descendants.
  /// Types are tried in order, so the list doubles as the priority.
  E? _getPropertyFromType<E>(List<Type> types, E? Function(Widget widget) extract) {
    for (final type in types) {
      if (element.widget.runtimeType == type) {
        final property = extract(element.widget);
        if (property != null) return property;
      }

      final descendant = _firstDescendant((w) => w.runtimeType == type);
      if (descendant != null) {
        final property = extract(descendant);
        if (property != null) return property;
      }
    }
    return null;
  }

  Widget? _firstDescendant(bool Function(Widget widget) test, {int maxVisits = 40}) {
    Widget? found;
    var visits = 0;
    void visit(Element element) {
      if (found != null || visits++ > maxVisits) return;
      if (test(element.widget)) {
        found = element.widget;
        return;
      }
      element.visitChildren(visit);
    }

    element.visitChildren(visit);
    return found;
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
