// Smoke test guarding the public barrel: if the Annotation / AnnotationExporter
// API stops being exported from package:borealis/borealis.dart, this file fails
// to compile. It deliberately imports only the barrel — never src/.
import 'package:borealis/borealis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SmokeExporter extends AnnotationExporter {
  const _SmokeExporter();

  @override
  BorealisExportButtonReplacement get exportButtonReplacement =>
      BorealisExportButtonReplacement(icon: Icons.import_export, label: 'Smoke');

  @override
  Future<String> export(List<Annotation> annotations) async => 'exported ${annotations.length}';
}

void main() {
  test('Annotation and AnnotationExporter are reachable through the public barrel', () async {
    final annotation = Annotation(
      note: 'note',
      widgetType: 'Text',
      tappedWidgetRoute: 'Text',
      sourceLocation: 'lib/main.dart:42',
      screenWidget: 'HomePage',
      routeName: '/home',
      rect: const Rect.fromLTWH(0, 0, 10, 20),
      props: const {'text': 'Hello'},
    );

    expect(annotation.toExportJson()['note'], 'note');

    const exporter = _SmokeExporter();
    expect(exporter.exportButtonReplacement.label, 'Smoke');
    expect(await exporter.export([annotation]), 'exported 1');
  });
}
