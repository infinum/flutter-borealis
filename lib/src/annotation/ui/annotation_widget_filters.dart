part of '../annotation.dart';

/// Whether this build can map a tapped widget back to the code that created
/// it — the precondition for every part of annotation capture.
///
/// Picking a widget needs two pieces of debug-only machinery. A render
/// object's `debugCreator`, which [_creatorElement] reads to get from a
/// hit-test result to an element, is assigned inside an `assert` and so exists
/// in debug builds alone. [isCustomWidget] needs widget creation tracking for
/// the same reason. Without them every hit test resolves to nothing, and the
/// tab would sit there absorbing taps and doing nothing at all.
///
/// One case this does not catch: a debug build compiled with
/// `--no-track-widget-creation` has `debugCreator` but no creation locations,
/// so capture selects far less than usual. `flutter run` enables tracking by
/// default, so the common path is covered; erring towards "supported" keeps a
/// wrong answer here from disabling a feature that works.
bool get annotationCaptureSupported => kDebugMode;

/// Returns the first candidate in a deepest-first hit-test [pathDeepestFirst]
/// that satisfies [isResolvable], or `null` when none do.
///
/// Kept pure (no Flutter types) so target-selection ordering can be unit
/// tested independently of the render tree.
@visibleForTesting
T? firstAnnotationTarget<T>(Iterable<T> pathDeepestFirst, {required bool Function(T candidate) isResolvable}) {
  for (final candidate in pathDeepestFirst) {
    if (isResolvable(candidate)) return candidate;
  }
  return null;
}

/// Elements worth selecting: custom (app-defined) widgets, plus basic UI and
/// layout-grouping elements the dev wrote themselves (locally created —
/// framework-internal instances of the same types don't count).
bool _isAnnotatable(Element element) =>
    isCustomWidget(element) || (_isBasicUiElement(element.widget) && debugIsWidgetLocalCreation(element.widget));

/// Whitelist of visually editable framework primitives.
bool _isBasicUiElement(Widget widget) =>
    // Content.
    widget is Text ||
    widget is RichText ||
    widget is SelectableText ||
    widget is Icon ||
    widget is Image ||
    // Buttons.
    widget is ButtonStyleButton || // ElevatedButton, TextButton, OutlinedButton, FilledButton
    widget is IconButton ||
    widget is FloatingActionButton ||
    widget is MaterialButton ||
    // Inputs.
    widget is TextField ||
    widget is Checkbox ||
    widget is Radio<Object?> ||
    widget is Switch ||
    widget is Slider ||
    widget is DropdownButton<Object?> ||
    widget is Chip ||
    // Composed material surfaces.
    widget is ListTile ||
    widget is Card ||
    widget is Divider ||
    widget is AppBar ||
    // Layout groupings — annotatable as whole sections.
    widget is Flex || // Column, Row
    widget is Wrap ||
    widget is Stack ||
    // Visual styling primitives.
    widget is Container ||
    widget is DecoratedBox ||
    widget is ColoredBox ||
    widget is Padding;

RenderBox? _renderBoxOf(Element? element) {
  final renderObject = element?.renderObject;
  if (renderObject is RenderBox && renderObject.hasSize && !renderObject.size.isEmpty) return renderObject;
  return null;
}

Element? _creatorElement(RenderObject renderObject) {
  final creator = renderObject.debugCreator;
  if (creator is DebugCreator) return creator.element;
  return null;
}
