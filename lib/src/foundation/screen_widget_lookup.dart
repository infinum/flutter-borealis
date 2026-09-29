part of 'foundation.dart';

/// Runtime type of the nearest app-defined widget above [context], or `null`
/// when only framework widgets wrap it up to the route boundary (the first
/// [Navigator]/[Overlay] ancestor) — widgets hosting the whole app say nothing
/// about the screen the caller sits on.
///
/// Requires widget creation tracking (debug builds); otherwise always `null`.
String? enclosingCustomWidgetName(BuildContext context) {
  String? name;
  context.visitAncestorElements((ancestor) {
    if (ancestor.widget is Navigator || ancestor.widget is Overlay) return false;
    if (!isCustomWidget(ancestor)) return true;
    name = ancestor.widget.runtimeType.toString();
    return false;
  });
  return name;
}

/// Whether [element]'s widget is an app-defined (or non-framework package)
/// component class. A class is "custom" when its `build` runs outside
/// `packages/flutter/`, i.e. its child widget has a local creation location.
/// The instance itself must also be locally created — that rejects framework
/// pass-through widgets (e.g. Scaffold's internal body wrapper) whose child
/// is the app-created widget they re-parent.
/// Requires widget creation tracking (debug builds); otherwise always false.
bool isCustomWidget(Element element) {
  if (element is! StatelessElement && element is! StatefulElement) return false;
  // Inline builders and verbatim pass-throughs would pass the locality
  // checks below despite being framework classes.
  if (_isInlineBuilder(element.widget) || element.widget is KeyedSubtree) return false;
  if (!debugIsWidgetLocalCreation(element.widget)) return false;
  Element? child;
  element.visitChildren((c) => child ??= c);
  final childWidget = child?.widget;
  return childWidget != null && debugIsWidgetLocalCreation(childWidget);
}

/// Framework builder widgets whose child is created by an app-side closure;
/// they would pass the local-creation check but are not custom classes.
bool _isInlineBuilder(Widget widget) =>
    widget is Builder ||
    widget is StatefulBuilder ||
    widget is LayoutBuilder ||
    widget is OrientationBuilder ||
    widget is ListenableBuilder ||
    widget is ValueListenableBuilder<Object?> ||
    widget is StreamBuilder<Object?> ||
    widget is FutureBuilder<Object?>;
