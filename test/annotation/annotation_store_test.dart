import 'dart:ui';

import 'package:borealis/src/annotation/annotation.dart';
import 'package:flutter_test/flutter_test.dart';

Annotation _annotation({
  String note = 'note',
  String widgetType = 'Text',
  String tappedWidgetRoute = 'Text',
  String? sourceLocation = 'lib/main.dart:42',
  String? screenWidget = 'HomePage',
  String? routeName = '/home',
  Map<String, String> props = const {'text': 'Hello'},
  String? widgetKey,
  int widgetOrdinal = 1,
  int widgetOrdinalCount = 1,
}) {
  return Annotation(
    note: note,
    widgetType: widgetType,
    tappedWidgetRoute: tappedWidgetRoute,
    sourceLocation: sourceLocation,
    screenWidget: screenWidget,
    routeName: routeName,
    rect: const Rect.fromLTWH(0, 0, 10, 20),
    props: props,
    widgetKey: widgetKey,
    widgetOrdinal: widgetOrdinal,
    widgetOrdinalCount: widgetOrdinalCount,
  );
}

void main() {
  group('Annotation.toExportJson', () {
    test('contains note, widget types, instance identity, screen, route and sourceLocation', () {
      final json = _annotation(
        widgetType: 'Center',
        tappedWidgetRoute: 'FancyCard',
        widgetKey: "[<'saveFab'>]",
        widgetOrdinal: 2,
        widgetOrdinalCount: 3,
      ).toExportJson();

      expect(json, {
        'id': '',
        'note': 'note',
        'widgetType': 'Center',
        'tappedWidgetRoute': 'FancyCard',
        'widgetKey': "[<'saveFab'>]",
        'widgetOrdinal': 2,
        'widgetOrdinalCount': 3,
        'screen': 'HomePage',
        'route': '/home',
        'sourceLocation': 'lib/main.dart:42',
      });
    });

    test('keeps null sourceLocation, screen and route', () {
      final json = _annotation(sourceLocation: null, screenWidget: null, routeName: null).toExportJson();

      expect(json.keys, containsAll(['note', 'widgetType', 'screen', 'route', 'sourceLocation']));
      expect(json['sourceLocation'], isNull);
      expect(json['screen'], isNull);
      expect(json['route'], isNull);
    });

    test('does not export rect or props', () {
      final json = _annotation().toExportJson();

      // id plus the nine fields the exporter carries.
      expect(json.keys, hasLength(10));
      expect(json.containsKey('rect'), isFalse);
      expect(json.containsKey('props'), isFalse);
    });
  });

  group('AnnotationStore', () {
    test('starts empty and inactive', () {
      final store = AnnotationStore();

      expect(store.annotations, isEmpty);
      expect(store.active.value, isFalse);
    });

    test('add appends and notifies', () {
      final store = AnnotationStore();
      var notified = 0;
      store.addListener(() => notified++);

      store.add(_annotation());

      expect(store.annotations, hasLength(1));
      expect(notified, 1);
    });

    test('add assigns a session-unique id when none is set', () {
      final store = AnnotationStore();

      store.add(_annotation(note: 'one'));
      store.add(_annotation(note: 'two'));

      final ids = store.annotations.map((a) => a.id).toList();
      expect(ids[0], isNotEmpty);
      expect(ids[1], isNotEmpty);
      expect(ids[0], isNot(ids[1]));
    });

    test('annotations view is unmodifiable', () {
      final store = AnnotationStore();
      store.add(_annotation());

      expect(() => store.annotations.add(_annotation()), throwsUnsupportedError);
    });

    test('updateNote edits the annotation it was handed, not a look-alike', () {
      final store = AnnotationStore();
      // Same note, type, rect and screen: these two are equal by value and can
      // only be told apart by their assigned id.
      store.add(_annotation(note: 'same'));
      store.add(_annotation(note: 'same'));
      final second = store.annotations[1];

      store.updateNote(second, 'edited');

      expect(store.annotations[0].note, 'same');
      expect(store.annotations[1].note, 'edited');
      expect(store.annotations[1].id, second.id);
    });

    test('remove deletes the annotation it was handed, not a look-alike', () {
      final store = AnnotationStore();
      store.add(_annotation(note: 'same'));
      store.add(_annotation(note: 'same'));
      final second = store.annotations[1];

      store.remove(second);

      expect(store.annotations, hasLength(1));
      expect(store.annotations.single.id, isNot(second.id));
    });

    test('updateNote and remove ignore annotations that are gone', () {
      final store = AnnotationStore();
      store.add(_annotation(note: 'kept'));
      final stranger = _annotation(note: 'never stored');

      store
        ..updateNote(stranger, 'edited')
        ..remove(stranger);

      expect(store.annotations.single.note, 'kept');
    });

    test('an id-less annotation is matched by value, not ignored', () {
      final store = AnnotationStore();
      store.add(_annotation(note: 'kept'));

      // The documented fallback in _indexOf: an annotation with no id is looked
      // up by value. This one was never stored (add() assigns the id to its own
      // copy) but is equal field-for-field to the one that was, so it resolves
      // to that entry rather than being dropped as gone.
      store.updateNote(_annotation(note: 'kept'), 'edited');
      expect(store.annotations.single.note, 'edited');
      expect(store.annotations.single.id, isNotEmpty);

      store.remove(_annotation(note: 'edited'));
      expect(store.annotations, isEmpty);
    });

    test('clear empties and notifies', () {
      final store = AnnotationStore();
      store.add(_annotation());
      var notified = 0;
      store.addListener(() => notified++);

      store.clear();

      expect(store.annotations, isEmpty);
      expect(notified, 1);
    });

    test('active toggle is observable', () {
      final store = AnnotationStore();
      var changes = 0;
      store.active.addListener(() => changes++);

      store.active.value = true;

      expect(store.active.value, isTrue);
      expect(changes, 1);
    });

    test('exposes a shared singleton instance', () {
      expect(AnnotationStore.instance, same(AnnotationStore.instance));
    });
  });

  test('hands back the same list until the store changes', () {
    // Read two or three times per frame by the marker tracker, so a fresh
    // unmodifiable copy per read is pure allocation.
    final store = AnnotationStore()..add(_annotation(note: 'one'));

    final first = store.annotations;
    expect(identical(store.annotations, first), isTrue);

    store.add(_annotation(note: 'two'));

    expect(identical(store.annotations, first), isFalse);
    expect(store.annotations, hasLength(2));
  });

  test('the cached list stays unmodifiable', () {
    final store = AnnotationStore()..add(_annotation(note: 'one'));

    expect(() => store.annotations.add(_annotation(note: 'two')), throwsUnsupportedError);
  });
}
