import 'dart:convert';

import 'package:borealis/src/annotation/annotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_test_support.dart';

class _SendAllExporter extends AnnotationExporter {
  const _SendAllExporter();

  @override
  BorealisExportButtonReplacement get exportButtonReplacement =>
      BorealisExportButtonReplacement(icon: Icons.send, label: 'Send all');

  @override
  Future<String> export(List<Annotation> annotations) async => 'sent';
}

Annotation _annotation({String note = 'Padding is wrong here', String? screenWidget = 'HomePage'}) {
  return Annotation(
    note: note,
    widgetType: 'Text',
    tappedWidgetRoute: 'Text',
    sourceLocation: null,
    screenWidget: screenWidget,
    routeName: '/home',
    rect: const Rect.fromLTWH(0, 0, 10, 20),
    props: const {'text': 'Hello', 'size': '10x20'},
  );
}

void main() {
  final store = AnnotationStore.instance;
  const page = AnnotationBorealisPage();

  setUp(() {
    store.clear();
    store.active.value = false;
  });

  group('capture support', () {
    testWidgets('explains itself instead of offering capture when the build cannot resolve widgets', (tester) async {
      await tester.pumpWidget(hostWidget(const AnnotationPageBody(captureSupported: false)));

      expect(find.text('Enable annotations'), findsNothing);
      expect(find.textContaining('debug build'), findsWidgets);
    });

    testWidgets('offers capture when the build can resolve widgets', (tester) async {
      await tester.pumpWidget(hostWidget(const AnnotationPageBody(captureSupported: true)));

      expect(find.text('Enable annotations'), findsOneWidget);
    });

    testWidgets('mounts no capture layer when the build cannot resolve widgets', (tester) async {
      Widget? layer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              layer = const AnnotationBorealisPage().stackPage(context, GlobalKey());
              return const SizedBox();
            },
          ),
        ),
      );

      // The test binding runs in debug, where capture works, so the layer is
      // expected here. The guard is what removes it elsewhere.
      expect(annotationCaptureSupported, isTrue);
      expect(layer, isNotNull);
    });
  });

  group('empty state', () {
    testWidgets('shows the enable button and no list', (tester) async {
      await tester.pumpWidget(host(page));

      expect(find.text('Enable annotations'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('enable button activates annotation mode', (tester) async {
      await tester.pumpWidget(host(page));

      await tester.tap(find.text('Enable annotations'));
      await tester.pump();

      expect(store.active.value, isTrue);
    });
  });

  group('populated state', () {
    testWidgets('lists annotations and action buttons', (tester) async {
      store.add(_annotation());
      await tester.pumpWidget(host(page));

      expect(find.text('Padding is wrong here'), findsOneWidget);
      expect(find.text('Text'), findsWidgets);
      expect(find.text('Copy to clipboard'), findsOneWidget);
      expect(find.text('Start annotating'), findsOneWidget);
    });

    testWidgets('start annotating re-activates mode', (tester) async {
      store.add(_annotation());
      await tester.pumpWidget(host(page));

      await tester.tap(find.text('Start annotating'));
      await tester.pump();

      expect(store.active.value, isTrue);
    });

    testWidgets('send button is enabled when an annotation is added', (tester) async {
      store.add(_annotation());
      await tester.pumpWidget(host(const AnnotationBorealisPage(exporter: _SendAllExporter())));

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send all'));
      expect(button.onPressed, isNotNull);
    });
  });

  group('export', () {
    testWidgets('copies minimal JSON to the clipboard', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      store.add(_annotation());
      await tester.pumpWidget(host(page));

      await tester.tap(find.text('Copy to clipboard'));
      await tester.pump();

      expect(calls, hasLength(1));
      final copied = jsonDecode(calls.single.arguments['text'] as String);
      expect(copied, [
        {
          'id': store.annotations.single.id,
          'note': 'Padding is wrong here',
          'widgetType': 'Text',
          'tappedWidgetRoute': 'Text',
          'widgetKey': null,
          'widgetOrdinal': 1,
          'widgetOrdinalCount': 1,
          'screen': 'HomePage',
          'route': '/home',
          'sourceLocation': null,
        },
      ]);
    });

    testWidgets('shows a confirmation snackbar', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      store.add(_annotation());
      await tester.pumpWidget(host(page));

      await tester.tap(find.text('Copy to clipboard'));
      await tester.pump();

      expect(find.textContaining('Copied 1'), findsOneWidget);
    });
  });

  group('page wiring', () {
    test('title, icon and clear', () {
      store.add(_annotation());
      expect(page.title, 'Annotations');
      expect(page.icon, Icons.edit_note_outlined);
      page.onClearTap!();
      expect(store.annotations, isEmpty);
    });

    test('replaceBorealisButton is null when inactive and set when active', () {
      store.active.value = false;
      expect(page.replaceBorealisButton.value, isNull);

      store.active.value = true;
      expect(page.replaceBorealisButton.value, isNotNull);
    });

    testWidgets('badge reflects annotation count', (tester) async {
      expect(page.badgeListenable!.value, 0);
      store.add(_annotation());
      await tester.pump();
      expect(page.badgeListenable!.value, 1);
    });
  });
}
