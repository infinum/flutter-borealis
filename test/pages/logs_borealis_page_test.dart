import 'package:borealis/src/logs/logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggy/loggy.dart';

import 'page_test_support.dart';

LogRecord _record({LogLevel level = LogLevel.info, String message = 'hello', String logger = 'AppLoggy'}) {
  return LogRecord(level, message, logger);
}

void main() {
  final logger = TerminalLogger.instance;
  const page = LogsBorealisPage();

  setUp(logger.clear);
  tearDown(logger.clear);

  group('page wiring', () {
    test('title and icon', () {
      expect(page.title, 'Logs');
      expect(page.icon, Icons.terminal_outlined);
    });

    test('onClearTap empties the logger', () {
      logger.add(_record());
      expect(logger.events, isNotEmpty);

      page.onClearTap!();

      expect(logger.events, isEmpty);
    });

    testWidgets('badge reflects the event count', (tester) async {
      expect(page.badgeListenable!.value, 0);

      logger.add(_record());
      await tester.pump();

      expect(page.badgeListenable!.value, 1);
    });
  });

  group('render', () {
    testWidgets('empty logger renders the search field and no rows', (tester) async {
      await tester.pumpWidget(host(page));

      expect(find.byType(LogsPage), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // No log records, so no level labels are rendered.
      expect(find.text('INFO'), findsNothing);
      expect(find.text('ERROR'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('renders a seeded log record', (tester) async {
      logger.add(_record(level: LogLevel.error, message: 'Boom happened'));
      await tester.pumpWidget(host(page));

      expect(find.text('Boom happened'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);

      // Unmount so the per-row periodic timer (_AutoUpdate) is cancelled before
      // the test completes.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('filters records by the search query', (tester) async {
      logger.add(_record(message: 'first message', logger: 'AppLoggy'));
      logger.add(_record(message: 'second entry', logger: 'NetLoggy'));
      await tester.pumpWidget(host(page));

      await tester.enterText(find.byType(TextField), 'second');
      await tester.pump();

      expect(find.text('second entry'), findsOneWidget);
      expect(find.text('first message'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('custom event list', () {
    test('badges the list it was given, not the shared one', () {
      final own = TerminalEventList()..add(LogRecord(LogLevel.info, 'mine', 'test', DateTime.now()));

      const page = LogsBorealisPage(eventList: null);
      const scoped = LogsBorealisPage();
      expect(page.badgeListenable, same(scoped.badgeListenable), reason: 'the default stays one shared listenable');

      final custom = LogsBorealisPage(eventList: own);
      expect(custom.badgeListenable!.value, 1);

      own.add(LogRecord(LogLevel.info, 'second', 'test', DateTime.now()));
      expect(custom.badgeListenable!.value, 2);
    });

    testWidgets('clears the list it was given', (tester) async {
      final own = TerminalEventList()..add(LogRecord(LogLevel.info, 'mine', 'test', DateTime.now()));
      final page = LogsBorealisPage(eventList: own);

      await tester.pumpWidget(host(page));
      page.onClearTap!();
      await tester.pumpAndSettle();

      expect(own.events, isEmpty);
    });
  });
}
