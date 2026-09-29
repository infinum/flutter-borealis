import 'dart:io';

import 'package:borealis/src/logs/logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggy/loggy.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(TerminalLogger.instance.clear);
  tearDown(TerminalLogger.instance.clear);

  group('LogsExportUtils', () {
    test('writes records in chronological order with level, logger and error', () async {
      final path = await LogsExportUtils.buildExportFile([
        LogRecord(LogLevel.info, 'first message', 'AppLogger'),
        LogRecord(LogLevel.error, 'second message', 'NetLogger', StateError('boom')),
      ]);

      final content = await File(path).readAsString();
      expect(content, contains('Borealis logs export — 2 records'));
      expect(content, contains('INFO  AppLogger'));
      expect(content, contains('first message'));
      expect(content, contains('ERROR  NetLogger'));
      expect(content, contains('Error: Bad state: boom'));
      expect(content.indexOf('first message'), lessThan(content.indexOf('second message')));
    });
  });

  group('LogsPage export button', () {
    testWidgets('is hidden when onExport is not configured', (tester) async {
      TerminalLogger.instance.add(LogRecord(LogLevel.info, 'hello', 'AppLogger'));

      await tester.pumpWidget(_wrap(LogsPage()));

      expect(find.byTooltip('Export filtered logs'), findsNothing);
    });

    testWidgets('exports the filtered records to a file handed to onExport', (tester) async {
      await tester.runAsync(() async {
        TerminalLogger.instance
          ..add(LogRecord(LogLevel.info, 'alpha message', 'AppLogger'))
          ..add(LogRecord(LogLevel.info, 'beta message', 'AppLogger'));
        String? exportedPath;

        await tester.pumpWidget(_wrap(LogsPage(config: LogsConfig(onExport: (path) => exportedPath = path))));
        await tester.enterText(find.byType(TextField), 'beta');
        await tester.pump();
        await tester.tap(find.byTooltip('Export filtered logs'));
        for (var i = 0; i < 50 && exportedPath == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        expect(exportedPath, isNotNull, reason: 'onExport was not invoked');

        final content = await File(exportedPath!).readAsString();
        expect(content, contains('beta message'));
        expect(content, isNot(contains('alpha message')));
      });
    });
  });

  group('LogsPage search bar', () {
    testWidgets('uses a logs-specific hint and shows the inline result count', (tester) async {
      TerminalLogger.instance
        ..add(LogRecord(LogLevel.info, 'alpha message', 'AppLogger'))
        ..add(LogRecord(LogLevel.info, 'beta message', 'AppLogger'));

      await tester.pumpWidget(_wrap(LogsPage()));

      expect(find.text('Search by message or logger…'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump();

      expect(find.text('1 results'), findsOneWidget);
      expect(find.text('beta message'), findsOneWidget);
      expect(find.text('alpha message'), findsNothing);
    });
  });
}
