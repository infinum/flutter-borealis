part of 'annotation.dart';

/// An immutable note attached to a widget captured on the running app.
///
/// Created by [AnnotationOverlay] when the user taps a widget in annotation
/// mode and saves a note. Stored in [AnnotationStore] and rendered by
/// [AnnotationBorealisPage].
@immutable
/// One note attached to a widget on a screen.
///
/// Borealis records what it resolved about the widget at the moment of the
/// tap: its type, its key, its position, its properties, the route it was on
/// and, in a debug build, the source location that created it. An
/// [AnnotationExporter] receives these objects, so every field is public.
///
/// Call [toExportJson] for the shape the built-in clipboard exporter writes.
class Annotation {
  Annotation({
    required this.note,
    required this.widgetType,
    required this.tappedWidgetRoute,
    required this.sourceLocation,
    required this.screenWidget,
    required this.routeName,
    required this.rect,
    required Map<String, String> props,
    this.widgetKey,
    this.widgetOrdinal = 1,
    this.widgetOrdinalCount = 1,
    Element? element,
    this.id = '',
  }) : props = Map.unmodifiable(props),
       _element = element == null ? null : WeakReference(element);

  /// Session-unique id, assigned by [AnnotationStore.add]. Identifies this
  /// annotation for edits and deletes, and is included in the export so a
  /// receiver can refer back to it. Empty until stored.
  final String id;

  /// The free-text note the user typed.
  final String note;

  /// Runtime type of the targeted widget, e.g. `Text`.
  final String widgetType;

  /// String form of the targeted widget's [Key] (e.g. `[<'saveFab'>]`), or
  /// `null` when it has none. Together with [widgetOrdinal] this tells two
  /// otherwise-identical siblings apart — a key is the exact, code-mappable id.
  final String? widgetKey;

  /// 1-based position of the target among same-type widgets on the same screen,
  /// ordered top-to-bottom then left-to-right (so `1` is the topmost). The
  /// positional fallback for distinguishing identical siblings when no
  /// [widgetKey] is set. `1` when the widget is the only one of its type.
  final int widgetOrdinal;

  /// Total count of same-type widgets on the screen — the `M` in "N of M".
  final int widgetOrdinalCount;

  /// The drill path from the widget the tap originally resolved to down to
  /// the final selection, runtime types joined with `>`
  /// (e.g. `Card>Button>Icon`). Equals [widgetType] when the selection was
  /// not stepped.
  final String tappedWidgetRoute;

  /// Best-effort `file:line` creation location; `null` when unavailable
  /// (profile/release builds, or when widget creation tracking is off).
  final String? sourceLocation;

  /// Runtime type of the screen's root custom widget (e.g. `HomePage`);
  /// `null` when no custom screen widget resolved.
  final String? screenWidget;

  /// Name of the [ModalRoute] the target lives in; `null` for unnamed routes.
  final String? routeName;

  /// Global bounds of the target when captured. Used for on-page display and as
  /// the anchor for re-attaching to the widget after it is recreated (see
  /// [element]). Not exported.
  final Rect rect;

  /// Open-ended display-only properties (e.g. `text`, `color`, `size`,
  /// `padding`) captured from the widget. Empty when nothing resolved. Not
  /// exported. Stored as an unmodifiable copy and compared by content.
  final Map<String, String> props;

  /// Live handle to the targeted widget's element. Lets the overlay re-resolve
  /// the widget's current on-screen bounds and tell whether it is still
  /// visible. Goes stale when the screen is disposed (navigated away); the
  /// overlay then re-binds it to the freshly created equivalent widget when the
  /// same screen is shown again, keyed by [screenWidget]/[routeName],
  /// [widgetType] and [rect] plus the captured identity ([widgetKey], creation
  /// site and text content). Debug/display only — never exported, and `null`
  /// until (re)bound or once the disposed element has been garbage-collected.
  ///
  /// Held via a [WeakReference] so a stored annotation never keeps a disposed
  /// widget subtree alive; reads return `null` after collection.
  Element? get element => _element?.target;

  final WeakReference<Element>? _element;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Annotation &&
          note == other.note &&
          widgetType == other.widgetType &&
          tappedWidgetRoute == other.tappedWidgetRoute &&
          sourceLocation == other.sourceLocation &&
          screenWidget == other.screenWidget &&
          routeName == other.routeName &&
          rect == other.rect &&
          mapEquals(props, other.props) &&
          widgetKey == other.widgetKey &&
          widgetOrdinal == other.widgetOrdinal &&
          widgetOrdinalCount == other.widgetOrdinalCount;

  @override
  int get hashCode => Object.hash(
    note,
    widgetType,
    tappedWidgetRoute,
    sourceLocation,
    screenWidget,
    routeName,
    rect,
    Object.hashAllUnordered(props.entries.map((e) => Object.hash(e.key, e.value))),
    widgetKey,
    widgetOrdinal,
    widgetOrdinalCount,
  );

  /// A copy with a new [note] and/or re-bound [element]; everything else is
  /// preserved. Used when an annotation is edited or re-attached.
  Annotation copyWith({String? id, String? note, Element? element}) => Annotation(
    id: id ?? this.id,
    note: note ?? this.note,
    widgetType: widgetType,
    tappedWidgetRoute: tappedWidgetRoute,
    sourceLocation: sourceLocation,
    screenWidget: screenWidget,
    routeName: routeName,
    rect: rect,
    props: props,
    widgetKey: widgetKey,
    widgetOrdinal: widgetOrdinal,
    widgetOrdinalCount: widgetOrdinalCount,
    element: element ?? this.element,
  );

  /// Minimal payload for clipboard export: note, widget type, the instance
  /// identity (key + ordinal), screen identity and source location.
  Map<String, dynamic> toExportJson() => {
    'id': id,
    'note': note,
    'widgetType': widgetType,
    'tappedWidgetRoute': tappedWidgetRoute,
    'widgetKey': widgetKey,
    'widgetOrdinal': widgetOrdinal,
    'widgetOrdinalCount': widgetOrdinalCount,
    'screen': screenWidget,
    'route': routeName,
    'sourceLocation': sourceLocation,
  };
}
