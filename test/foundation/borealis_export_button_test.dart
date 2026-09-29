import 'dart:async';

import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('renders nothing when no export callback is configured', (tester) async {
    await tester.pumpWidget(_host(const BorealisExportButton(onExport: null, tooltip: 'Export logs')));

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('is disabled when there is nothing to export', (tester) async {
    await tester.pumpWidget(
      _host(BorealisExportButton(onExport: () async => null, enabled: false, tooltip: 'Export logs')),
    );

    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
  });

  testWidgets('shows a spinner while exporting and clears it afterwards', (tester) async {
    final export = Completer<String?>();

    await tester.pumpWidget(_host(BorealisExportButton(onExport: () => export.future, tooltip: 'Export logs')));

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    export.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a second tap while an export is running does not start another', (tester) async {
    var runs = 0;
    final export = Completer<String?>();

    await tester.pumpWidget(
      _host(
        BorealisExportButton(
          onExport: () {
            runs++;
            return export.future;
          },
          tooltip: 'Export logs',
        ),
      ),
    );

    final button = tester.getCenter(find.byType(IconButton));
    await tester.tapAt(button);
    await tester.pump();
    await tester.tapAt(button);
    await tester.pump();

    expect(runs, 1);

    export.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('reports a failure in a snackbar', (tester) async {
    await tester.pumpWidget(_host(BorealisExportButton(onExport: () async => throw StateError('boom'), tooltip: 'E')));

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Export failed'), findsOneWidget);
  });

  testWidgets('reports the message an export returns', (tester) async {
    await tester.pumpWidget(_host(BorealisExportButton(onExport: () async => 'Wrote 3 records', tooltip: 'E')));

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Wrote 3 records'), findsOneWidget);
  });
}
