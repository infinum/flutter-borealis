import 'dart:io';

import 'package:borealis/src/wiretap/wiretap.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WiretapEntry _entry({
  required String id,
  String method = 'GET',
  String url = 'https://api.example.com/users',
  int? statusCode = 200,
  dynamic requestBody,
  Map<String, dynamic> requestHeaders = const {},
}) {
  final start = DateTime(2026, 7, 16, 12);
  return WiretapEntry(
    id: id,
    method: method,
    uri: Uri.parse(url),
    requestHeaders: requestHeaders,
    requestBody: requestBody,
    timestamp: start,
    responseTimestamp: start.add(const Duration(milliseconds: 120)),
    statusCode: statusCode,
    isLoading: false,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('WiretapContent export button', () {
    testWidgets('is hidden when onExport is not configured', (tester) async {
      final store = WiretapStore()..add(_entry(id: '1'));

      await tester.pumpWidget(_wrap(WiretapContent(store: store, config: WiretapConfig())));

      expect(find.byTooltip('Export filtered logs'), findsNothing);
    });

    testWidgets('exports the filtered entries to a file handed to onExport', (tester) async {
      await tester.runAsync(() async {
        final store = WiretapStore()
          ..add(_entry(id: '1', url: 'https://api.example.com/users'))
          ..add(_entry(id: '2', url: 'https://api.example.com/orders'));
        String? exportedPath;
        final config = WiretapConfig(onExport: (path) => exportedPath = path);

        await tester.pumpWidget(_wrap(WiretapContent(store: store, config: config)));
        await tester.enterText(find.byType(TextField), 'orders');
        await tester.pump();
        await tester.tap(find.byTooltip('Export filtered logs'));
        // Real async work (isolate + file IO) inside runAsync.
        for (var i = 0; i < 50 && exportedPath == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        expect(exportedPath, isNotNull, reason: 'onExport was not invoked');

        final content = await File(exportedPath!).readAsString();
        expect(content, contains('Wiretap export'));
        expect(content, contains('/orders'));
        expect(content, isNot(contains('/users')));
      });
    });

    testWidgets('shows a snackbar when onExport throws', (tester) async {
      await tester.runAsync(() async {
        final store = WiretapStore()..add(_entry(id: '1'));
        final config = WiretapConfig(onExport: (_) => throw StateError('nope'));

        await tester.pumpWidget(_wrap(WiretapContent(store: store, config: config)));
        await tester.tap(find.byTooltip('Export filtered logs'));
        for (var i = 0; i < 50 && tester.widgetList(find.byType(SnackBar)).isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }

        expect(find.textContaining('Export failed'), findsOneWidget);
      });
    });
  });

  group('WiretapContent selection mode', () {
    testWidgets('is not entered by long-press when onExport is not configured', (tester) async {
      final store = WiretapStore()..add(_entry(id: '1'));

      await tester.pumpWidget(_wrap(WiretapContent(store: store, config: WiretapConfig())));
      await tester.longPress(find.text('GET'));
      await tester.pump();

      expect(find.text('Select items'), findsNothing);
    });

    testWidgets('exports selected entries even when the filter hides them', (tester) async {
      final store = WiretapStore()
        ..add(_entry(id: '1', url: 'https://api.example.com/users'))
        ..add(_entry(id: '2', url: 'https://api.example.com/orders'));
      String? exportedPath;
      final config = WiretapConfig(onExport: (path) => exportedPath = path);

      // Gestures run outside runAsync so recognizer timers stay on the fake clock.
      await tester.pumpWidget(_wrap(WiretapContent(store: store, config: config)));
      await tester.longPress(find.textContaining('/users'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      // Filter out the selected entry, then export the selection.
      await tester.enterText(find.byType(TextField), 'orders');
      await tester.pump();
      await tester.tap(find.byTooltip('Export selected'));

      await tester.runAsync(() async {
        for (var i = 0; i < 50 && exportedPath == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        expect(exportedPath, isNotNull, reason: 'onExport was not invoked');

        final content = await File(exportedPath!).readAsString();
        expect(content, contains('/users'));
        expect(content, isNot(contains('/orders')));
      });
      await tester.pump();
    });
  });

  group('WiretapDetailScreen', () {
    testWidgets('reads entries from the custom store of the list it was opened from', (tester) async {
      final store = WiretapStore()..add(_entry(id: '1', url: 'https://api.example.com/users'));

      await tester.pumpWidget(_wrap(WiretapContent(store: store, config: WiretapConfig())));
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();

      expect(find.text('Entry not found.'), findsNothing);
      expect(find.text('Request Detail'), findsOneWidget);
      expect(find.textContaining('api.example.com/users'), findsWidgets);
    });

    testWidgets('escapes single quotes in the exported cURL command', (tester) async {
      final store = WiretapStore()
        ..add(
          _entry(
            id: '1',
            method: 'POST',
            url: 'https://api.example.com/notes',
            requestBody: '{"note":"it\'s fine"}',
            requestHeaders: {'x-tag': "a'b"},
          ),
        );
      String? curl;
      final config = WiretapConfig(onCurlExport: (value) => curl = value);

      await tester.pumpWidget(
        _wrap(
          Navigator(
            onGenerateRoute: (_) => WiretapDetailScreen.route(entryId: '1', config: config, store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as cURL'));
      await tester.pumpAndSettle();

      expect(curl, isNotNull);
      expect(curl, contains(r"it'\''s fine"));
      expect(curl, contains(r"-H 'x-tag: a'\''b'"));
      expect(curl, isNot(contains("it's fine")));
    });

    testWidgets('emits one -H per value of a multi-value header', (tester) async {
      final store = WiretapStore()
        ..add(
          _entry(
            id: '1',
            url: 'https://api.example.com/notes',
            requestHeaders: {
              'set-cookie': <String>['a=1', 'b=2'],
            },
          ),
        );
      final curl = await _exportCurl(tester, store);

      // cURL has no syntax for a repeated header on one flag, so the list form
      // pasted through as `-H 'set-cookie: [a=1, b=2]'` and was not replayable.
      expect(curl, contains("-H 'set-cookie: a=1'"));
      expect(curl, contains("-H 'set-cookie: b=2'"));
      expect(curl, isNot(contains('[a=1')));
    });

    testWidgets('describes a byte body instead of pasting an integer array', (tester) async {
      final store = WiretapStore()
        ..add(_entry(id: '1', method: 'POST', url: 'https://api.example.com/upload', requestBody: [137, 80, 78, 71]));
      final curl = await _exportCurl(tester, store);

      expect(curl, isNot(contains('137')));
      expect(curl, isNot(contains('--data-raw')));
      expect(curl, contains('4 bytes'));
    });

    testWidgets('renders FormData fields and files as -F parts', (tester) async {
      final formData = FormData.fromMap({
        'title': 'a note',
        'upload': MultipartFile.fromString('hello', filename: 'note.txt'),
      });
      final store = WiretapStore()
        ..add(_entry(id: '1', method: 'POST', url: 'https://api.example.com/upload', requestBody: formData));
      final curl = await _exportCurl(tester, store);

      expect(curl, contains("-F 'title=a note'"));
      expect(curl, contains("-F 'upload=@note.txt'"));
      expect(curl, isNot(contains('FormData')));
    });
  });

  testWidgets('a successful export reports what it wrote', (tester) async {
    await tester.runAsync(() async {
      final store = WiretapStore()..add(_entry(id: '1', url: 'https://api.example.com/users'));
      var handed = false;
      final config = WiretapConfig(onExport: (_) => handed = true);

      await tester.pumpWidget(_wrap(WiretapContent(store: store, config: config)));
      await tester.tap(find.byTooltip('Export filtered logs'));
      for (var i = 0; i < 50 && !handed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      await tester.pump();

      // The success channel exists end to end; both built-in pages used to
      // return null through it, so a completed export said nothing at all.
      expect(find.textContaining('Exported 1 request'), findsOneWidget);
    });
  });
}

/// Opens the one entry in [store] and taps through to the cURL export.
Future<String> _exportCurl(WidgetTester tester, WiretapStore store) async {
  String? curl;
  final config = WiretapConfig(onCurlExport: (value) => curl = value);

  await tester.pumpWidget(
    _wrap(
      Navigator(
        onGenerateRoute: (_) =>
            WiretapDetailScreen.route(entryId: store.entries.single.id, config: config, store: store),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Export'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Export as cURL'));
  await tester.pumpAndSettle();

  return curl!;
}
