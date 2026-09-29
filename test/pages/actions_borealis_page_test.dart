import 'package:borealis/src/actions/actions.dart';
import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_test_support.dart';

void main() {
  setUp(() => visibleScreenActions.value = []);
  tearDown(() => visibleScreenActions.value = []);

  group('page wiring', () {
    test('title and icon', () {
      const page = ActionsBorealisPage();
      expect(page.title, 'Debug options');
      expect(page.icon, Icons.devices_other_outlined);
    });

    test('has no clear action or badge', () {
      const page = ActionsBorealisPage();
      expect(page.onClearTap, isNull);
      expect(page.badgeListenable, isNull);
    });
  });

  group('render', () {
    testWidgets('renders the provided actions', (tester) async {
      const page = ActionsBorealisPage(actions: [Text('Reset onboarding')]);
      await tester.pumpWidget(host(page));

      expect(find.byType(ActionsPage), findsOneWidget);
      expect(find.text('Reset onboarding'), findsOneWidget);
    });

    testWidgets('renders without actions', (tester) async {
      const page = ActionsBorealisPage();
      await tester.pumpWidget(host(page));

      expect(find.byType(ActionsPage), findsOneWidget);
    });

    testWidgets('appends screen-dependent actions', (tester) async {
      visibleScreenActions.value = [
        ScreenActionEntry('id', 'HomeScreen', const [Text('Screen action')]),
      ];
      const page = ActionsBorealisPage(actions: [Text('Static action')]);
      await tester.pumpWidget(host(page));
      await tester.pump();

      expect(find.text('Static action'), findsOneWidget);
      expect(find.text('HomeScreen'), findsOneWidget);
      expect(find.text('Screen action'), findsOneWidget);
    });
  });
}
