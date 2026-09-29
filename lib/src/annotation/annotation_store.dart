part of 'annotation.dart';

/// An observable, in-memory store of [Annotation]s plus the single source of
/// truth for whether annotation mode is [active].
///
/// Extends [ChangeNotifier]; widgets wrapped in a [ListenableBuilder] rebuild
/// when annotations are added or cleared. Annotation mode is exposed as a
/// separate [ValueNotifier] so the floating button and capture overlay can
/// listen to it independently of the annotation list.
///
/// Annotations are kept in memory only and lost on app restart.
class AnnotationStore extends ChangeNotifier {
  AnnotationStore();

  /// Shared singleton used by the default Borealis setup.
  static final instance = AnnotationStore();

  final List<Annotation> _annotations = [];
  final Random _random = Random();

  List<Annotation>? _annotationsCache;

  /// Whether annotation mode is currently active.
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Unmodifiable view of the captured annotations, in insertion order.
  ///
  /// Built once per mutation rather than once per read, the way
  /// [WiretapStore.entries] is: the marker tracker reads this two or three
  /// times for every frame it resolves, and copying the list each time was
  /// allocation for nothing.
  List<Annotation> get annotations => _annotationsCache ??= List.unmodifiable(_annotations);

  void add(Annotation annotation) {
    final stored = annotation.id.isEmpty ? annotation.copyWith(id: _generateId()) : annotation;
    _annotations.add(stored);
    _annotationsCache = null;
    notifyListeners();
  }

  /// A short random alphanumeric id, unique among the annotations currently
  /// stored. Opaque — it identifies an annotation for edits and for exporters
  /// that need to refer back to one; nothing parses its shape.
  String _generateId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String candidate;
    do {
      candidate = List.generate(8, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
    } while (_annotations.any((a) => a.id == candidate));
    return candidate;
  }

  /// Replaces [annotation]'s note in place, keeping its position. No-op if it
  /// is no longer in the store.
  void updateNote(Annotation annotation, String note) {
    final index = _indexOf(annotation);
    if (index < 0) return;
    _annotations[index] = _annotations[index].copyWith(note: note);
    _annotationsCache = null;
    notifyListeners();
  }

  /// Re-points [annotation] at a freshly created [element] — the same widget
  /// shown again after navigating away and back — keeping its note and place.
  /// No-op if it is no longer in the store.
  void rebindElement(Annotation annotation, Element element) {
    final index = _indexOf(annotation);
    if (index < 0) return;
    _annotations[index] = _annotations[index].copyWith(element: element);
    _annotationsCache = null;
    notifyListeners();
  }

  void remove(Annotation annotation) {
    final index = _indexOf(annotation);
    if (index < 0) return;
    _annotations.removeAt(index);
    _annotationsCache = null;
    notifyListeners();
  }

  /// Position of [annotation] in the store, or `-1` when it is gone.
  ///
  /// Matched by [Annotation.id], not by value: two notes can carry the same
  /// text on the same widget, and value equality would then edit or delete
  /// whichever one happens to come first.
  int _indexOf(Annotation annotation) {
    if (annotation.id.isEmpty) return _annotations.indexOf(annotation);
    return _annotations.indexWhere((a) => a.id == annotation.id);
  }

  void clear() {
    _annotations.clear();
    _annotationsCache = null;
    notifyListeners();
  }

  @override
  void dispose() {
    active.dispose();
    super.dispose();
  }
}
