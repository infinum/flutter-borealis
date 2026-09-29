import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ActionScreen extends StatelessWidget {
  const _ActionScreen({required this.name, required this.activeRouteOnly, this.next});

  final String name;
  final bool activeRouteOnly;
  final Widget? next;

  @override
  Widget build(BuildContext context) {
    return ScreenDebugActions(
      screenName: name,
      activeRouteOnly: activeRouteOnly,
      actions: (context) => [Text('$name action')],
      child: Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(
          child: next == null
              ? null
              : ElevatedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => next!)),
                  child: const Text('push'),
                ),
        ),
      ),
    );
  }
}

void main() {
  setUp(() => visibleScreenActions.value = []);
  tearDown(() => visibleScreenActions.value = []);

  testWidgets('activeRouteOnly: only the top route contributes actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _ActionScreen(
          name: 'A',
          activeRouteOnly: true,
          next: _ActionScreen(name: 'B', activeRouteOnly: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.map((e) => e.screenName), <String>['A']);

    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.map((e) => e.screenName), <String>['B']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.map((e) => e.screenName), <String>['A']);
  });

  testWidgets('default: all live screens contribute', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _ActionScreen(
          name: 'A',
          activeRouteOnly: false,
          next: _ActionScreen(name: 'B', activeRouteOnly: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.map((e) => e.screenName).toList(), <String>['A', 'B']);
  });

  testWidgets('screenName defaults to the enclosing widget type', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _UnnamedScreen()));
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.single.screenName, '_UnnamedScreen');
  });

  testWidgets('inferred screenName skips framework wrappers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DeeplyWrappedScreen()));
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.single.screenName, '_DeeplyWrappedScreen');
  });

  testWidgets('inferred screenName stops at the route boundary and falls back to the route name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/details',
        routes: {
          '/details': (context) =>
              ScreenDebugActions(actions: (context) => [const Text('action')], child: const Scaffold()),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.single.screenName, '/details');
  });

  testWidgets('inferred screenName falls back to a placeholder without a widget or route', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScreenDebugActions(actions: (context) => [const Text('action')], child: const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.single.screenName, 'Unknown screen');
  });

  testWidgets('explicit screenName wins over inference', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ActionScreen(name: 'explicit', activeRouteOnly: false)));
    await tester.pumpAndSettle();
    expect(visibleScreenActions.value.single.screenName, 'explicit');
  });

  testWidgets('keys: actions rebuild when a key changes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _CounterActionScreen()));
    await tester.pumpAndSettle();
    expect((visibleScreenActions.value.single.actions.single as Text).data, 'count 0');

    // Bumping the counter rebuilds the parent, which passes a new key to
    // ScreenDebugActions and refreshes the contributed action.
    await tester.tap(find.text('bump'));
    await tester.pumpAndSettle();
    expect((visibleScreenActions.value.single.actions.single as Text).data, 'count 1');
  });
}

/// Registers actions without a [ScreenDebugActions.screenName]; the group name
/// must come from this widget's type.
class _UnnamedScreen extends StatelessWidget {
  const _UnnamedScreen();

  @override
  Widget build(BuildContext context) {
    return ScreenDebugActions(actions: (context) => [const Text('action')], child: const Scaffold());
  }
}

/// Same, but buried under framework widgets the inference has to walk past.
class _DeeplyWrappedScreen extends StatelessWidget {
  const _DeeplyWrappedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Builder(
            builder: (context) =>
                ScreenDebugActions(actions: (context) => [const Text('action')], child: const SizedBox()),
          ),
        ),
      ),
    );
  }
}

class _CounterActionScreen extends StatefulWidget {
  const _CounterActionScreen();

  @override
  State<_CounterActionScreen> createState() => _CounterActionScreenState();
}

class _CounterActionScreenState extends State<_CounterActionScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return ScreenDebugActions(
      screenName: 'counter',
      keys: [_count],
      actions: (context) => [Text('count $_count')],
      child: Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => setState(() => _count++), child: const Text('bump')),
        ),
      ),
    );
  }
}
