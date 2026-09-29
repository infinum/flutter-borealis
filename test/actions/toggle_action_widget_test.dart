import 'dart:async';

import 'package:borealis/src/actions/actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a second toggle in the same frame does not start the action twice', (tester) async {
    var runs = 0;
    final action = Completer<bool>();

    await tester.pumpWidget(
      _host(
        ToggleActionWidget(
          label: 'Flag',
          initialState: () => false,
          action: (value) {
            runs++;
            return action.future;
          },
        ),
      ),
    );
    await tester.pump();

    final onChanged = tester.widget<Switch>(find.byType(Switch)).onChanged!;
    onChanged(true);
    onChanged(true);
    await tester.pump();

    expect(runs, 1);

    action.complete(true);
    await tester.pumpAndSettle();
  });

  testWidgets('the switch is not interactive while the action runs', (tester) async {
    final action = Completer<bool>();

    await tester.pumpWidget(
      _host(ToggleActionWidget(label: 'Flag', initialState: () => false, action: (value) => action.future)),
    );
    await tester.pump();

    tester.widget<Switch>(find.byType(Switch)).onChanged!(true);
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    action.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });

  testWidgets('the switch toggles again once the action has finished', (tester) async {
    var runs = 0;

    await tester.pumpWidget(
      _host(
        ToggleActionWidget(
          label: 'Flag',
          initialState: () => false,
          action: (value) async {
            runs++;
            return value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.widget<Switch>(find.byType(Switch)).onChanged!(true);
    await tester.pumpAndSettle();
    tester.widget<Switch>(find.byType(Switch)).onChanged!(false);
    await tester.pumpAndSettle();

    expect(runs, 2);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('a failing action reverts the switch and leaves it usable', (tester) async {
    var shouldThrow = true;

    await tester.pumpWidget(
      _host(
        ToggleActionWidget(
          label: 'Flag',
          initialState: () => false,
          action: (value) {
            if (shouldThrow) throw StateError('boom');
            return value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse, reason: 'the optimistic flip is rolled back');
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byType(Switch)).onChanged,
      isNotNull,
      reason: 'one failure must not latch it off',
    );

    shouldThrow = false;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('a failing initial read leaves the switch usable', (tester) async {
    await tester.pumpWidget(
      _host(ToggleActionWidget(label: 'Flag', initialState: () => throw StateError('boom'), action: (value) => value)),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });
}
