import 'package:borealis/src/annotation/annotation.dart';
import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/annotation_test_widgets.dart';

/// Mirrors the real mounting shape: BorealisOverlay sits in
/// `MaterialApp.builder`, so the annotation overlay lives above the app's
/// Navigator but below MaterialApp's MediaQuery/Directionality.
Widget _harness({required GlobalKey appKey, required AnnotationStore store, required Widget home, bool active = true}) {
  store.active.value = active;
  return MaterialApp(
    builder: (context, child) => Stack(
      children: [
        KeyedSubtree(key: appKey, child: child!),
        Positioned.fill(
          child: AnnotationOverlay(targetKey: appKey, store: store),
        ),
      ],
    ),
    home: home,
  );
}

void main() {
  testWidgets('selects the deepest annotatable widget directly under the tap', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    await tester.tapAt(tester.getCenter(find.text('Hello')));
    await tester.pump();

    // The selection matches the finger: the app's own Text, not its internal
    // framework RichText, and not the enclosing FancyCard.
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('RichText'), findsNothing);
    expect(find.text('FancyCard'), findsNothing);
  });

  testWidgets('selects the app-created Text rather than its internal RichText', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: const Scaffold(body: Center(child: Text('plain'))),
      ),
    );

    await tester.tapAt(tester.getCenter(find.text('plain')));
    await tester.pump();

    expect(find.text('Text'), findsOneWidget);
    expect(find.text('RichText'), findsNothing);
  });

  testWidgets('inline Builder closures are skipped when broadening up', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => const ColoredBox(color: Colors.teal, child: Text('built')),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.text('built'));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsOneWidget);

    // Broadening up reaches the ColoredBox; the inline Builder is never picked.
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('ColoredBox'), findsOneWidget);
    expect(find.text('Builder'), findsNothing);
  });

  testWidgets('tapping the same widget again broadens the selection outward', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    final center = tester.getCenter(find.text('Hello'));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump();

    // One step out from the Text: its enclosing Padding.
    expect(find.text('Padding'), findsOneWidget);
    expect(find.text('Text'), findsNothing);
  });

  testWidgets('broadening grows the highlight rect to the enclosing widget', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    // The red highlight border container (full-opacity accent, 2px).
    final highlight = find.byWidgetPredicate((w) {
      if (w is! Container || w.decoration is! BoxDecoration) return false;
      final border = (w.decoration as BoxDecoration).border;
      // The highlight is drawn under the Borealis overlay theme (see
      // AnnotationOverlay.build), not the app's own theme, so match its primary.
      return border is Border &&
          border.top.width == 2 &&
          border.top.color == OverlayNestedNavigation.theme.colorScheme.primary;
    });

    final center = tester.getCenter(find.text('Hello'));
    await tester.tapAt(center);
    await tester.pump();
    final textRect = tester.getRect(highlight);

    // Text -> Padding -> ColoredBox -> FancyCard; the card wraps the text and
    // its padding, so its rect strictly contains the text's.
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(center);
      await tester.pump();
    }
    final cardRect = tester.getRect(highlight);

    expect(find.text('FancyCard'), findsOneWidget);
    expect(cardRect, tester.getRect(find.byType(FancyCard)));
    expect(cardRect, isNot(textRect));
    expect(cardRect.contains(textRect.topLeft), isTrue);
    expect(cardRect.contains(textRect.bottomRight), isTrue);
  });

  testWidgets('broadening skips non-visual wrapper widgets', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: const Scaffold(body: Center(child: WrappedCard())),
      ),
    );

    final center = tester.getCenter(find.text('Wrapped'));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Padding'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump();

    // GestureDetector, KeyedSubtree and NotificationListener between the
    // Padding and WrappedCard are skipped.
    expect(find.text('WrappedCard'), findsOneWidget);
    expect(find.textContaining('NotificationListener'), findsNothing);
    expect(find.textContaining('GestureDetector'), findsNothing);
  });

  testWidgets('layout groupings like Column are selectable as whole sections', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: const Scaffold(body: Center(child: StructuredCard())),
      ),
    );

    final center = tester.getCenter(find.text('Structured'));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsOneWidget);

    // AnimatedDefaultTextStyle is skipped; the Column section is selectable.
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Column'), findsOneWidget);
    expect(find.text('AnimatedDefaultTextStyle'), findsNothing);

    // Material (not a whitelisted basic) is skipped on the way to the card.
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('StructuredCard'), findsOneWidget);
    expect(find.text('Material'), findsNothing);
  });

  testWidgets('broadening visits whitelisted basics but never framework internals', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: const Scaffold(body: Center(child: ButtonCard())),
      ),
    );

    final center = tester.getCenter(find.text('Press'));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsOneWidget);

    // The button's internal Padding/Align/RichText are framework-created and
    // skipped; the next stop out is the ElevatedButton itself.
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('ElevatedButton'), findsOneWidget);

    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('ButtonCard'), findsOneWidget);
  });

  testWidgets('broadening wraps back to the deepest target past the outermost widget', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    final center = tester.getCenter(find.text('Hello'));
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsOneWidget);

    // Step off the Text, then keep broadening until it cycles back to it.
    await tester.tapAt(center);
    await tester.pump();
    expect(find.text('Text'), findsNothing);

    var wrapped = false;
    for (var i = 0; i < 10 && !wrapped; i++) {
      await tester.tapAt(center);
      await tester.pump();
      wrapped = find.text('Text').evaluate().isNotEmpty;
    }
    expect(wrapped, isTrue);
  });

  testWidgets('a single tap records the full biggest-to-deepest drill path', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    // One tap on the Text — no broadening — still captures the whole chain.
    await tester.tapAt(tester.getCenter(find.text('Hello')));
    await tester.pump();

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong alignment');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final annotation = store.annotations.single;
    expect(annotation.widgetType, 'Text');
    expect(annotation.tappedWidgetRoute, 'FancyScreen>FancyCard>ColoredBox>Padding>Text');
  });

  testWidgets('broadening the selection keeps the full drill path', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    final center = tester.getCenter(find.text('Hello'));
    await tester.tapAt(center);
    await tester.pump();
    await tester.tapAt(center);
    await tester.pump();

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong alignment');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final annotation = store.annotations.single;
    // Broadening moves the highlighted widget but not the recorded path.
    expect(annotation.widgetType, 'Padding');
    expect(annotation.tappedWidgetRoute, 'FancyScreen>FancyCard>ColoredBox>Padding>Text');
  });

  testWidgets('records key and ordinal to tell identical siblings apart', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const TwoFabScreen()));

    // Each FAB tap first selects its inner Icon; a second tap broadens up to
    // the FloatingActionButton, which is what we annotate.
    Future<void> annotateFab(IconData icon, String note) async {
      final center = tester.getCenter(find.byIcon(icon));
      await tester.tapAt(center);
      await tester.pump();
      await tester.tapAt(center);
      await tester.pump();
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), note);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    await annotateFab(Icons.add, 'top fab');
    await annotateFab(Icons.remove, 'bottom fab');

    final top = store.annotations[0];
    final bottom = store.annotations[1];

    expect(top.widgetType, 'FloatingActionButton');
    expect(bottom.widgetType, 'FloatingActionButton');

    // Ordered top-to-bottom: the keyed FAB is #1, the unkeyed one #2, both of 2.
    expect(top.widgetOrdinal, 1);
    expect(top.widgetOrdinalCount, 2);
    expect(top.widgetKey, "[<'topFab'>]");

    expect(bottom.widgetOrdinal, 2);
    expect(bottom.widgetOrdinalCount, 2);
    expect(bottom.widgetKey, isNull);
  });

  testWidgets('saved annotation records screen widget, route name and source location', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    await tester.tapAt(tester.getCenter(find.text('Hello')));
    await tester.pump();

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'padding is off');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.annotations, hasLength(1));
    final annotation = store.annotations.single;
    expect(annotation.widgetType, 'Text');
    expect(annotation.screenWidget, 'FancyScreen');
    expect(annotation.routeName, '/');
    expect(annotation.sourceLocation, contains('annotation_test_widgets.dart'));
  });

  Future<void> addNote(WidgetTester tester, Offset at, String text) async {
    await tester.tapAt(at);
    await tester.pump();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Offset badgeCorner(AnnotationStore store) => store.annotations.single.rect.topLeft.translate(4, 4);

  testWidgets('highlight follows the widget when the screen relayouts (keyboard/resize)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(key: ValueKey('box'), color: Color(0xFF2196F3), child: SizedBox(width: 120, height: 40)),
          ),
        ),
      ),
    );

    const box = ValueKey('box');
    // The red, full-opacity 2px highlight border (not the fainter markers).
    final highlight = find.byWidgetPredicate((w) {
      if (w is! Container || w.decoration is! BoxDecoration) return false;
      final border = (w.decoration as BoxDecoration).border;
      // The highlight is drawn under the Borealis overlay theme (see
      // AnnotationOverlay.build), not the app's own theme, so match its primary.
      return border is Border &&
          border.top.width == 2 &&
          border.top.color == OverlayNestedNavigation.theme.colorScheme.primary;
    });

    await tester.tapAt(tester.getCenter(find.byKey(box)));
    await tester.pump();
    expect(tester.getRect(highlight), tester.getRect(find.byKey(box)));

    // Shrink the viewport the way a keyboard/rotation would: the bottom-anchored
    // widget moves up, and the highlight must track it rather than stay put.
    tester.view.physicalSize = const Size(2400, 1200); // 800x400 at dpr 3.
    await tester.pumpAndSettle();

    expect(tester.getRect(highlight), tester.getRect(find.byKey(box)));
  });

  testWidgets('shows a numbered marker for each saved annotation', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');
    expect(store.annotations, hasLength(1));
    // The badge for annotation #1 (no info window is shown once deselected).
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('shows markers for persistent shell chrome outside the page route', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const ShellWithBottomNav()));
    await tester.pumpAndSettle();

    // The bottom nav bar lives in the root shell, above the page's nested
    // Navigator, so it resolves to a different screen identity than the page
    // content at the viewport centre.
    await addNote(tester, tester.getCenter(find.byIcon(Icons.home)), 'nav note');
    expect(store.annotations, hasLength(1));

    // The marker must still render: shell chrome stays visible on every page.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping a saved annotation badge edits its note', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');
    await tester.tapAt(badgeCorner(store));
    await tester.pumpAndSettle();
    expect(find.text('Edit note for Text'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'first'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'edited');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.annotations.single.note, 'edited');
  });

  testWidgets('lets app taps through while annotation mode is disabled', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();
    var tapped = false;

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        active: false,
        home: Scaffold(
          body: Center(
            child: ElevatedButton(onPressed: () => tapped = true, child: const Text('App button')),
          ),
        ),
      ),
    );

    // No tap catcher while disabled: the tap must reach the app's button.
    await tester.tap(find.text('App button'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('keeps showing saved markers after annotation mode is disabled', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));
    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');
    expect(find.text('1'), findsOneWidget);

    store.active.value = false;
    await tester.pumpAndSettle();

    // The marker stays visible even though capture mode is off.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping a badge edits the note while annotation mode is disabled', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));
    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');

    store.active.value = false;
    await tester.pumpAndSettle();

    await tester.tapAt(badgeCorner(store));
    await tester.pumpAndSettle();
    expect(find.text('Edit note for Text'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'edited while off');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.annotations.single.note, 'edited while off');
  });

  testWidgets('a badge whose widget is covered on the same screen is not tappable', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const CoverableScreen(covered: false)));
    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');
    expect(find.text('1'), findsOneWidget);

    // An opaque sibling now paints over the annotated Text. Same screen widget
    // and same route, so only the occlusion test rules it out — and it does:
    // the badge is no longer drawn.
    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const CoverableScreen(covered: true)));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);

    // A tap where the badge used to be must not reach it either.
    await tester.tapAt(badgeCorner(store));
    await tester.pumpAndSettle();
    expect(find.text('Edit note for Text'), findsNothing);
  });

  testWidgets('hides markers while a dialog/route covers them, restores on dismiss', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));
    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');

    store.active.value = false;
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    // Push a dialog over the annotated widget (root navigator, under the
    // borealis overlay). The covered marker must re-evaluate and hide.
    final appContext = tester.element(find.byType(FancyCard));
    showDialog<void>(
      context: appContext,
      builder: (_) => const Dialog(
        child: SizedBox(width: 200, height: 200, child: Center(child: Text('Popup'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Popup'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Dismiss: the widget is visible again, so the marker comes back.
    Navigator.of(appContext).pop();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('re-attaches a saved annotation when its screen is recreated', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        builder: (context, child) => Stack(
          children: [
            KeyedSubtree(key: appKey, child: child!),
            Positioned.fill(
              child: AnnotationOverlay(targetKey: appKey, store: store),
            ),
          ],
        ),
        home: const Scaffold(body: Center(child: Text('Menu'))),
      ),
    );

    // Capture an annotation on a pushed screen.
    store.active.value = true;
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const FancyScreen()));
    await tester.pumpAndSettle();
    await addNote(tester, tester.getCenter(find.text('Hello')), 'note');
    expect(store.annotations, hasLength(1));

    // Leave the screen (disposed) with capture off: the marker is gone.
    store.active.value = false;
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
    expect(find.text('1'), findsNothing);

    // Return to the same screen: the annotation re-binds to the new widget.
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const FancyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // The store entry now points at the freshly created element.
    expect(store.annotations.single.element?.mounted, isTrue);
  });

  testWidgets('does not hit-test the app subtree during build while it needs layout (active)', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();
    const transformKey = ValueKey('transform');

    await tester.pumpWidget(
      _harness(
        appKey: appKey,
        store: store,
        home: const Scaffold(
          body: Center(
            child: FractionalTranslation(
              key: transformKey,
              translation: Offset.zero,
              child: ColoredBox(
                color: Color(0xFF2196F3),
                child: SizedBox(width: 120, height: 40, child: Center(child: Text('Tag me'))),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await addNote(tester, tester.getCenter(find.text('Tag me')), 'note');
    final annotation = store.annotations.single;
    expect(find.text('1'), findsOneWidget);

    // Reproduce the real-world crash: a render object on the marker's hit-test
    // path (here a RenderFractionalTranslation, the same box type as a route/
    // sheet transition) is dirtied for layout, and in the SAME frame the store
    // notifies so the capture layer rebuilds. Hit-testing during that build —
    // before layout runs — trips `!debugNeedsLayout` in
    // RenderFractionalTranslation.hitTestChildren.
    tester.renderObject(find.byKey(transformKey)).markNeedsLayout();
    store.rebindElement(annotation, annotation.element!); // notifies _store; set unchanged
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('deleting from the edit sheet removes the annotation', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    await addNote(tester, tester.getCenter(find.text('Hello')), 'first');
    await tester.tapAt(badgeCorner(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(store.annotations, isEmpty);
  });

  /// Harness with a root [Navigator] handle so tests can push/pop screens,
  /// mirroring the re-attach flow (annotate, navigate away, navigate back).
  Future<GlobalKey<NavigatorState>> pumpNavHarness(WidgetTester tester, GlobalKey appKey, AnnotationStore store) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        builder: (context, child) => Stack(
          children: [
            KeyedSubtree(key: appKey, child: child!),
            Positioned.fill(
              child: AnnotationOverlay(targetKey: appKey, store: store),
            ),
          ],
        ),
        home: const Scaffold(body: Center(child: Text('Menu'))),
      ),
    );
    store.active.value = true;
    return navKey;
  }

  testWidgets('hides a marker once its element reference is gone (garbage-collected)', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));

    // The state after the WeakReference to a disposed screen's element has
    // been garbage-collected: a stored annotation for another screen whose
    // element reads null.
    store.add(
      Annotation(
        note: 'ghost',
        widgetType: 'Text',
        tappedWidgetRoute: 'OtherScreen>Text',
        sourceLocation: null,
        screenWidget: 'OtherScreen',
        routeName: '/other',
        rect: const Rect.fromLTWH(100, 100, 80, 20),
        props: const {},
      ),
    );
    await tester.pumpAndSettle();

    // The annotated screen is not showing: no marker at the stale rect.
    expect(find.text('1'), findsNothing);
  });

  testWidgets('re-attaches a garbage-collected annotation while its screen is showing', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();

    await tester.pumpWidget(_harness(appKey: appKey, store: store, home: const FancyScreen()));
    await addNote(tester, tester.getCenter(find.text('Hello')), 'note');

    // Same annotation with its element reference collected.
    final original = store.annotations.single;
    store.remove(original);
    store.add(
      Annotation(
        note: original.note,
        widgetType: original.widgetType,
        tappedWidgetRoute: original.tappedWidgetRoute,
        sourceLocation: original.sourceLocation,
        screenWidget: original.screenWidget,
        routeName: original.routeName,
        rect: original.rect,
        props: original.props,
        widgetKey: original.widgetKey,
        widgetOrdinal: original.widgetOrdinal,
        widgetOrdinalCount: original.widgetOrdinalCount,
      ),
    );
    await tester.pumpAndSettle();

    // The widget is still on screen, so the annotation re-binds and shows.
    expect(find.text('1'), findsOneWidget);
    expect(store.annotations.single.element?.mounted, isTrue);
  });

  testWidgets('does not re-attach across instances of the same screen with different data', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();
    final navKey = await pumpNavHarness(tester, appKey, store);

    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const TitleScreen(title: 'AAAA')));
    await tester.pumpAndSettle();
    await addNote(tester, tester.getCenter(find.text('AAAA')), 'note');
    expect(store.annotations, hasLength(1));

    store.active.value = false;
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);

    // Same screen class showing different data: a same-size Text at the same
    // spot, differing only in content. The annotation must stay hidden.
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const TitleScreen(title: 'BBBB')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);

    // Back on the matching instance it re-attaches.
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const TitleScreen(title: 'AAAA')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('does not re-attach to a widget with a different key at the same spot', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();
    final navKey = await pumpNavHarness(tester, appKey, store);

    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const KeyedBoxScreen(boxKey: 'a')));
    await tester.pumpAndSettle();
    await addNote(tester, tester.getCenter(find.byKey(const ValueKey('a'))), 'note');
    expect(store.annotations.single.widgetKey, "[<'a'>]");

    store.active.value = false;
    navKey.currentState!.pop();
    await tester.pumpAndSettle();

    // Identical widget at the same spot but with a different key: not ours.
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const KeyedBoxScreen(boxKey: 'b')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);

    // The matching key re-attaches.
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const KeyedBoxScreen(boxKey: 'a')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('does not re-attach to a look-alike widget created at a different source line', (tester) async {
    final appKey = GlobalKey();
    final store = AnnotationStore();
    final navKey = await pumpNavHarness(tester, appKey, store);

    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const ToggleScreen(useFirst: true)));
    await tester.pumpAndSettle();
    await addNote(tester, tester.getCenter(find.text('Same')), 'note');
    expect(store.annotations.single.sourceLocation, isNotNull);

    store.active.value = false;
    navKey.currentState!.pop();
    await tester.pumpAndSettle();

    // Same type, key, content and bounds — but built by a different line of
    // code. Creation site is the only discriminator and must be honored.
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const ToggleScreen(useFirst: false)));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);

    // The original variant re-attaches.
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const ToggleScreen(useFirst: true)));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });
}
