import 'package:borealis/src/actions/actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a second tap in the same frame does not open a second dialog', (tester) async {
    await tester.pumpWidget(_host(InputActionWidget(label: 'Token', action: (_) {})));
    await tester.pumpAndSettle();

    final onPressed = tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the button opens again once the action has finished', (tester) async {
    var runs = 0;

    await tester.pumpWidget(_host(InputActionWidget(label: 'Token', action: (_) async => runs++)));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    expect(runs, 2);
  });

  testWidgets('keeps the saved text in the field instead of restoring the initial value', (tester) async {
    String? saved;

    await tester.pumpWidget(
      _host(InputActionWidget(label: 'Token', initialValue: 'first', action: (value) => saved = value)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, 'second');

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'second'), findsOneWidget, reason: 'reopening must show what was saved');
  });

  testWidgets('clears the field when the value is disabled', (tester) async {
    await tester.pumpWidget(_host(InputActionWidget(label: 'Token', initialValue: 'first', action: (_) {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'first'), findsNothing);
  });
}
