import 'package:borealis/src/rendering/rendering.dart';
import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_test_support.dart';

void main() {
  const page = RenderingBorealisPage();

  // The page mutates Flutter's global debug flags; restore them after each test
  // so toggles can't leak into other tests.
  tearDown(() {
    timeDilation = 1.0;
    debugRepaintRainbowEnabled = false;
    debugRepaintTextRainbowEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintPointersEnabled = false;
    gamifyBorealis.value = false;
  });

  group('page wiring', () {
    test('title and icon', () {
      expect(page.title, 'Rendering');
      expect(page.icon, Icons.brush_outlined);
    });

    test('has no clear action or badge', () {
      expect(page.onClearTap, isNull);
      expect(page.badgeListenable, isNull);
    });
  });

  group('render', () {
    testWidgets('builds the render flag toggles', (tester) async {
      await tester.pumpWidget(host(page));

      expect(find.byType(RenderingPage), findsOneWidget);
      expect(find.text('Slow animations'), findsOneWidget);
      expect(find.text('Repaint rainbow'), findsOneWidget);
      expect(find.text('Show widget sizes'), findsOneWidget);
      expect(find.text('Gamify'), findsOneWidget);
    });
  });

  group('toggles', () {
    testWidgets('Gamify switch flips gamifyBorealis', (tester) async {
      expect(gamifyBorealis.value, isFalse);
      await tester.pumpWidget(host(page));

      await tester.tap(find.text('Gamify'));
      await tester.pump();

      expect(gamifyBorealis.value, isTrue);
    });

    testWidgets('Slow animations switch sets timeDilation', (tester) async {
      expect(timeDilation, 1.0);
      await tester.pumpWidget(host(page));

      await tester.tap(find.text('Slow animations'));
      await tester.pump();

      expect(timeDilation, 8.0);

      // flutter_test asserts timeDilation == 1.0 at the end of the test body
      // (before tearDown), so restore it inline.
      timeDilation = 1.0;
    });
  });
}
