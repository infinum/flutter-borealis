import 'package:borealis/src/actions/actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a second tap in the same frame does not open a second dialog', (tester) async {
    await tester.pumpWidget(
      _host(
        SelectableActionWidget<String>(
          label: 'Env',
          options: const ['dev', 'prod'],
          initialSelection: () => 'dev',
          onSelection: (value) => value ?? 'dev',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final onPressed = tester.widget<TextButton>(find.byType(TextButton)).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsOneWidget);
  });

  testWidgets('the button opens again once the action has finished', (tester) async {
    var runs = 0;

    await tester.pumpWidget(
      _host(
        SelectableActionWidget<String>(
          label: 'Env',
          options: const ['dev', 'prod'],
          initialSelection: () => 'dev',
          onSelection: (value) async {
            runs++;
            return value ?? 'dev';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('prod').last);
      await tester.pumpAndSettle();
    }

    expect(runs, 2);
  });

  testWidgets('a selected null option is not treated as a dismissal', (tester) async {
    final selections = <String?>[];

    await tester.pumpWidget(
      _host(
        SelectableActionWidget<String?>(
          label: 'Env',
          options: const ['dev', null],
          initialSelection: () => 'dev',
          onSelection: (value) {
            selections.add(value);
            return value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SimpleDialogOption).last);
    await tester.pumpAndSettle();

    expect(selections, [null]);
  });

  testWidgets('shows a placeholder rather than the string "null" when nothing is selected', (tester) async {
    await tester.pumpWidget(
      _host(
        SelectableActionWidget<String?>(
          label: 'Env',
          options: const ['dev'],
          initialSelection: () => null,
          onSelection: (value) => value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('null'), findsNothing);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('takes its colors from the theme so it stays legible on a dark panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SelectableActionWidget<String>(
              label: 'Env',
              options: const ['dev'],
              initialSelection: () => 'dev',
              onSelection: (value) => value ?? 'dev',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(TextButton));
    final scheme = Theme.of(context).colorScheme;
    final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
    final foreground = style.foregroundColor!.resolve(const <WidgetState>{});

    expect(foreground, isNot(Colors.black));
    expect(foreground, scheme.onSurface);
  });

  testWidgets('a failing initial read leaves the control usable', (tester) async {
    await tester.pumpWidget(
      _host(
        SelectableActionWidget<String>(
          label: 'Env',
          options: const ['dev'],
          initialSelection: () => throw StateError('boom'),
          onSelection: (value) => value ?? 'dev',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNotNull);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
