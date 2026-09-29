import 'dart:async';

import 'package:borealis/src/actions/actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a second tap in the same frame does not start the action twice', (tester) async {
    var runs = 0;
    final action = Completer<void>();

    await tester.pumpWidget(
      _host(
        ButtonActionWidget(
          label: 'Run',
          action: () {
            runs++;
            return action.future;
          },
        ),
      ),
    );

    // Both taps land before a frame is built, so the rebuild that disables the
    // button has not happened yet and `onPressed` is still live on the second.
    final button = tester.getCenter(find.byType(FilledButton));
    await tester.tapAt(button);
    await tester.tapAt(button);
    await tester.pump();

    expect(runs, 1);

    action.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the button runs again once the action has finished', (tester) async {
    var runs = 0;

    await tester.pumpWidget(_host(ButtonActionWidget(label: 'Run', action: () async => runs++)));

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(runs, 2);
  });

  testWidgets('a synchronous action never enters the loading state', (tester) async {
    await tester.pumpWidget(_host(ButtonActionWidget(label: 'Run', action: () {})));
    await tester.pump();

    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();

    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an asynchronous action shows the spinner until it completes', (tester) async {
    final action = Completer<void>();

    await tester.pumpWidget(_host(ButtonActionWidget(label: 'Run', action: () => action.future)));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    action.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failing action is reported and leaves the button usable', (tester) async {
    var runs = 0;

    await tester.pumpWidget(
      _host(
        ButtonActionWidget(
          label: 'Run',
          action: () {
            runs++;
            throw StateError('boom');
          },
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(runs, 2);
  });

  testWidgets('an action that completes after the widget is gone reports no exception', (tester) async {
    final action = Completer<void>();

    await tester.pumpWidget(_host(ButtonActionWidget(label: 'Run', action: () => action.future)));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    action.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing action marks the button and clears the mark on the next success', (tester) async {
    var shouldThrow = true;

    await tester.pumpWidget(
      _host(
        ButtonActionWidget(
          label: 'Run',
          action: () {
            if (shouldThrow) throw StateError('boom');
          },
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    shouldThrow = false;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
