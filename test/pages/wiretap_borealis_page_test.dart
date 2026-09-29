import 'package:borealis/src/wiretap/wiretap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_test_support.dart';

WiretapEntry _entry({
  String id = '1',
  String method = 'GET',
  String url = 'https://api.example.com/users',
  int? statusCode = 200,
}) {
  final start = DateTime(2026, 6, 9, 12);
  return WiretapEntry(
    id: id,
    method: method,
    uri: Uri.parse(url),
    requestHeaders: const {},
    requestBody: null,
    timestamp: start,
    responseTimestamp: start.add(const Duration(milliseconds: 120)),
    statusCode: statusCode,
    isLoading: false,
  );
}

void main() {
  final store = WiretapStore.instance;
  const page = WiretapBorealisPage();

  setUp(store.clear);
  tearDown(store.clear);

  group('page wiring', () {
    test('title and icon', () {
      expect(page.title, 'Network');
      expect(page.icon, Icons.network_ping_outlined);
    });

    test('onClearTap empties the store', () {
      store.add(_entry());
      expect(store.entries, isNotEmpty);

      page.onClearTap!();

      expect(store.entries, isEmpty);
    });

    testWidgets('badge reflects the entry count', (tester) async {
      expect(page.badgeListenable!.value, 0);

      store.add(_entry());
      await tester.pump();

      expect(page.badgeListenable!.value, 1);
    });
  });

  group('render', () {
    testWidgets('empty store shows the placeholder', (tester) async {
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      expect(find.byType(WiretapContent), findsOneWidget);
      expect(find.text('No requests recorded yet.'), findsOneWidget);
    });

    testWidgets('renders a seeded entry with method and status', (tester) async {
      store.add(_entry(method: 'POST', statusCode: 201));
      await tester.pumpWidget(host(page));
      await tester.pumpAndSettle();

      expect(find.text('POST'), findsOneWidget);
      expect(find.text('201'), findsOneWidget);
      expect(find.textContaining('/users'), findsOneWidget);
    });
  });

  group('custom store', () {
    late WiretapStore custom;
    late WiretapBorealisPage customPage;

    setUp(() {
      custom = WiretapStore();
      customPage = WiretapBorealisPage(store: custom);
    });

    testWidgets('renders the custom store, not the singleton', (tester) async {
      store.add(_entry(method: 'GET', url: 'https://api.example.com/singleton'));
      custom.add(_entry(id: '2', method: 'PUT', url: 'https://api.example.com/custom'));

      await tester.pumpWidget(host(customPage));
      await tester.pumpAndSettle();

      expect(find.textContaining('/custom'), findsOneWidget);
      expect(find.textContaining('/singleton'), findsNothing);
    });

    testWidgets('badge counts the custom store', (tester) async {
      expect(customPage.badgeListenable!.value, 0);

      custom.add(_entry(id: '2'));
      await tester.pump();

      expect(customPage.badgeListenable!.value, 1);
      expect(page.badgeListenable!.value, 0);
    });

    test('badgeListenable is stable across calls', () {
      expect(identical(customPage.badgeListenable, WiretapBorealisPage(store: custom).badgeListenable), isTrue);
      expect(identical(customPage.badgeListenable, page.badgeListenable), isFalse);
    });

    test('onClearTap empties the custom store only', () {
      store.add(_entry());
      custom.add(_entry(id: '2'));

      customPage.onClearTap!();

      expect(custom.entries, isEmpty);
      expect(store.entries, isNotEmpty);
    });
  });
}
