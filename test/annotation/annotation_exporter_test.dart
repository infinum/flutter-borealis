import 'dart:convert';

import 'package:borealis/src/annotation/annotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Annotation _annotation({String note = 'note', String widgetType = 'Text'}) {
  return Annotation(
    note: note,
    widgetType: widgetType,
    tappedWidgetRoute: widgetType,
    sourceLocation: 'lib/main.dart:42',
    screenWidget: 'HomePage',
    routeName: '/home',
    rect: const Rect.fromLTWH(0, 0, 10, 20),
    props: const {'text': 'Hello'},
  );
}

class _FakeExporter extends AnnotationExporter {
  _FakeExporter(this.message);

  final String message;
  List<Annotation>? received;

  @override
  BorealisExportButtonReplacement get exportButtonReplacement =>
      BorealisExportButtonReplacement(icon: Icons.import_export, label: 'Fake Exporter');

  @override
  Future<String> export(List<Annotation> annotations) async {
    received = annotations;
    return message;
  }
}

class _ThrowingExporter extends AnnotationExporter {
  const _ThrowingExporter();

  @override
  BorealisExportButtonReplacement get exportButtonReplacement =>
      BorealisExportButtonReplacement(icon: Icons.minor_crash, label: 'Throwing Exporter');

  @override
  Future<String> export(List<Annotation> annotations) async => throw StateError('boom');
}

Widget _host(AnnotationBorealisPage page) {
  return MaterialApp(
    home: Scaffold(body: Builder(builder: page.build)),
  );
}

void main() {
  // The page reads the shared singleton store; keep tests isolated.
  tearDown(AnnotationStore.instance.clear);

  testWidgets('Export delegates to the injected exporter and shows its message', (tester) async {
    AnnotationStore.instance.add(_annotation(note: 'hi'));
    final fake = _FakeExporter('sent 1');

    await tester.pumpWidget(_host(AnnotationBorealisPage(exporter: fake)));
    await tester.tap(find.text('Fake Exporter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.received, isNotNull);
    expect(fake.received!.single.note, 'hi');
    expect(find.text('sent 1'), findsOneWidget);
  });

  testWidgets('shows an error snackbar when the exporter throws', (tester) async {
    AnnotationStore.instance.add(_annotation());

    await tester.pumpWidget(_host(const AnnotationBorealisPage(exporter: _ThrowingExporter())));
    await tester.tap(find.text('Throwing Exporter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Export failed'), findsOneWidget);
  });

  testWidgets('the per-row delete button removes a single annotation', (tester) async {
    AnnotationStore.instance.add(_annotation(note: 'keep'));
    AnnotationStore.instance.add(_annotation(note: 'remove me'));

    await tester.pumpWidget(_host(const AnnotationBorealisPage()));
    expect(AnnotationStore.instance.annotations, hasLength(2));

    // The delete icon on the second card.
    await tester.tap(find.byTooltip('Delete annotation').last);
    await tester.pumpAndSettle();

    // Confirm the deletion in the dialog.
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(AnnotationStore.instance.annotations.single.note, 'keep');
  });

  test('ClipboardAnnotationExporter copies the export JSON and reports the count', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Object? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'];
        return null;
      },
    );

    final annotations = [_annotation(widgetType: 'Center')];
    final result = await const ClipboardAnnotationExporter().export(annotations);

    expect(result, 'Copied 1 annotations');
    expect(copied, jsonEncode(annotations.map((a) => a.toExportJson()).toList()));
  });
}
