import 'package:borealis/borealis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the lifecycle calls the overlay makes, so "once" can be asserted.
class _CountingPage extends BorealisPage {
  const _CountingPage() : super(title: 'Counting', icon: Icons.numbers);

  static int attached = 0;
  static int detached = 0;

  static void reset() {
    attached = 0;
    detached = 0;
  }

  @override
  void onAttach() => attached++;

  @override
  void onDetach() => detached++;

  @override
  Widget build(BuildContext context) => const Text('Counting body');
}

/// A page that pushes a route onto the panel's own navigator, the way the
/// Network tab opens a request.
class _PushingPage extends BorealisPage {
  const _PushingPage() : super(title: 'Pushing', icon: Icons.open_in_new);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Center(child: Text('Deeper'))),
          ),
        ),
        child: const Text('Go deeper'),
      ),
    );
  }
}

Widget _app({required List<BorealisPage> pages, BorealisSettings settings = const BorealisSettings()}) {
  return MaterialApp(
    builder: (context, child) => BorealisOverlay(pages: pages, settings: settings, child: child!),
    home: const Scaffold(body: Center(child: Text('App'))),
  );
}

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.bug_report));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_CountingPage.reset);

  group('construction', () {
    testWidgets('rejects an empty page list with an ArgumentError', (tester) async {
      // An assert would be stripped in release, where the empty list then
      // failed much later as a RangeError inside build.
      await tester.pumpWidget(
        MaterialApp(
          home: BorealisOverlay(pages: const [], child: const SizedBox()),
        ),
      );

      expect(tester.takeException(), isA<ArgumentError>());
    });
  });

  group('page lifecycle', () {
    testWidgets('attaches each page once, not on every rebuild', (tester) async {
      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpAndSettle();

      expect(_CountingPage.attached, 1);

      // A new BorealisOverlay widget for the same state, which is what
      // MaterialApp.builder produces on any app rebuild.
      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpAndSettle();

      expect(_CountingPage.attached, 1);
    });

    testWidgets('detaches each page when the overlay goes away', (tester) async {
      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(_CountingPage.detached, 1);
    });

    testWidgets('a disabled overlay attaches nothing', (tester) async {
      await tester.pumpWidget(_app(pages: const [_CountingPage()], settings: const BorealisSettings(enabled: false)));
      await tester.pumpAndSettle();

      expect(_CountingPage.attached, 0);
      expect(find.byIcon(Icons.bug_report), findsNothing);
    });

    testWidgets('enabling a disabled overlay attaches its pages then', (tester) async {
      await tester.pumpWidget(_app(pages: const [_CountingPage()], settings: const BorealisSettings(enabled: false)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpAndSettle();

      expect(_CountingPage.attached, 1);
    });
  });

  group('hideDebugPanel', () {
    testWidgets('closes the panel', (tester) async {
      await tester.pumpWidget(_app(pages: const [_PushingPage()]));
      await tester.pumpAndSettle();
      await _openPanel(tester);

      expect(find.text('Go deeper'), findsOneWidget);

      Borealis.hideDebugPanel();
      await tester.pumpAndSettle();

      expect(find.text('Go deeper'), findsNothing);
    });

    testWidgets('closes the panel even with a page route open on top of it', (tester) async {
      await tester.pumpWidget(_app(pages: const [_PushingPage()]));
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await tester.tap(find.text('Go deeper'));
      await tester.pumpAndSettle();
      expect(find.text('Deeper'), findsOneWidget);

      Borealis.hideDebugPanel();
      await tester.pumpAndSettle();

      expect(find.text('Deeper'), findsNothing, reason: 'popping one route only went back to the tab');
      expect(find.text('Go deeper'), findsNothing, reason: 'the panel itself must close');
    });

    testWidgets('the panel can be opened again afterwards', (tester) async {
      await tester.pumpWidget(_app(pages: const [_PushingPage()]));
      await tester.pumpAndSettle();

      await _openPanel(tester);
      Borealis.hideDebugPanel();
      await tester.pumpAndSettle();

      await _openPanel(tester);

      expect(find.text('Go deeper'), findsOneWidget);
    });
  });

  group('floating button drag', () {
    testWidgets('follows the point it was grabbed by rather than jumping', (tester) async {
      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.bug_report)));
      // First move only gets the pan past the touch slop; measure from there.
      await gesture.moveBy(const Offset(0, 30));
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byIcon(Icons.bug_report));

      const delta = Offset(40, 120);
      await gesture.moveBy(delta);
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(find.byIcon(Icons.bug_report));
      expect((after - origin - delta).distance, lessThan(1.0), reason: 'the button must track the drag exactly');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('cannot be dragged off the screen', (tester) async {
      await tester.pumpWidget(_app(pages: const [_CountingPage()]));
      await tester.pumpAndSettle();

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.bug_report)));
      await gesture.moveBy(const Offset(-4000, -4000));
      await tester.pumpAndSettle();

      final topLeft = tester.getTopLeft(find.byIcon(Icons.bug_report));
      expect(topLeft.dx, greaterThanOrEqualTo(-1));
      expect(topLeft.dy, greaterThanOrEqualTo(-1));

      await gesture.moveBy(const Offset(8000, 8000));
      await tester.pumpAndSettle();

      final bottomRight = tester.getBottomRight(find.byIcon(Icons.bug_report));
      expect(bottomRight.dx, lessThanOrEqualTo(size.width + 1));
      expect(bottomRight.dy, lessThanOrEqualTo(size.height + 1));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
