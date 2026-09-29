import 'package:borealis/borealis.dart';
import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyPage extends BorealisPage {
  const _EmptyPage() : super(title: 'Empty', icon: Icons.abc);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// Scale of the popup carrying [label], read from the nearest Transform.
double _popupScale(WidgetTester tester, String label) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.text(label), matching: find.byType(Transform)).first,
  );
  return transform.transform.getMaxScaleOnAxis();
}

void main() {
  tearDown(() => gamifyBorealis.value = false);

  testWidgets('popup animation keeps running when an older popup expires', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BorealisOverlay(
          pages: const [_EmptyPage()],
          settings: const BorealisSettings(gamify: true),
          child: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    // Spawns are throttled to one per 250ms, so each popup needs a pump past
    // that interval before it shows up.
    BorealisGamify.emit(BorealisGamifyEvent(label: 'first', color: Colors.red));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('first'), findsOneWidget);

    BorealisGamify.emit(BorealisGamifyEvent(label: 'second', color: Colors.red));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('second'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    final before = _popupScale(tester, 'second');

    // Cross the point where 'first' is removed from the list.
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('first'), findsNothing);

    final after = _popupScale(tester, 'second');
    expect(after, greaterThan(before), reason: 'the surviving popup restarted its animation');

    // Let the remaining popup expire so no timers outlive the test.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('rebuilding with equal settings keeps the runtime gamify toggle', (tester) async {
    Widget app({required Key key}) => MaterialApp(
      home: BorealisOverlay(
        key: key,
        pages: const [_EmptyPage()],
        settings: const BorealisSettings(),
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    const key = ValueKey('overlay');
    await tester.pumpWidget(app(key: key));

    // Simulates the user flipping Gamify on from the Rendering tab.
    gamifyBorealis.value = true;
    await tester.pumpWidget(app(key: key));

    expect(gamifyBorealis.value, isTrue);
  });

  test('a hook emits nothing while the gamified layer is disabled', () {
    gamifyBorealis.value = false;
    final store = WiretapStore();
    final hook = BorealisGamifyHook<WiretapEntry>(
      source: store,
      latest: () => store.newestCompleted,
      toEvent: (_) => fail('toEvent must not run while gamify is off'),
    )..attach();
    addTearDown(hook.detach);

    store.add(
      WiretapEntry(
        id: '1',
        method: 'GET',
        uri: Uri.parse('https://api.example.com/users'),
        requestHeaders: const {},
        requestBody: null,
        timestamp: DateTime.now(),
        statusCode: 200,
        isLoading: false,
      ),
    );
  });

  test('a hook stays attached until every attach has been matched by a detach', () {
    gamifyBorealis.value = true;
    addTearDown(() => gamifyBorealis.value = false);

    final store = WiretapStore();
    final emitted = <String>[];
    final hook = BorealisGamifyHook<WiretapEntry>(
      source: store,
      latest: () => store.newestCompleted,
      toEvent: (entry) {
        emitted.add(entry.id);
        return null;
      },
    );

    // Two overlays, one shared hook.
    hook.attach();
    hook.attach();
    hook.detach();

    store.add(_completed('1'));
    expect(emitted, ['1'], reason: 'one overlay is still mounted and still wants popups');

    hook.detach();
    store.add(_completed('2'));
    expect(emitted, ['1'], reason: 'the last detach really detaches');
  });
}

WiretapEntry _completed(String id) {
  return WiretapEntry(
    id: id,
    method: 'GET',
    uri: Uri.parse('https://api.example.com/$id'),
    requestHeaders: const {},
    requestBody: null,
    timestamp: DateTime.now(),
    statusCode: 200,
    isLoading: false,
  );
}
