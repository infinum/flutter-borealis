import 'package:flutter/material.dart';

/// App-style custom widgets used by the annotation overlay tests.
///
/// Defined outside the test file so custom-class detection (the class's
/// `build` creates children in a non-framework file) sees them exactly like
/// widgets in a real app's `lib/`.
class FancyCard extends StatelessWidget {
  const FancyCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.amber,
      child: Padding(padding: const EdgeInsets.all(8), child: Text(label)),
    );
  }
}

/// Custom widget whose subtree is wrapped in non-visual plumbing widgets
/// (listeners, keyed subtrees, gesture detectors) that a dev cannot visually
/// edit — the drill-down should skip them.
class WrappedCard extends StatelessWidget {
  const WrappedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => false,
      child: KeyedSubtree(
        child: GestureDetector(
          onTap: () {},
          child: const Padding(padding: EdgeInsets.all(8), child: Text('Wrapped')),
        ),
      ),
    );
  }
}

/// Custom widget whose subtree is built from layout scaffolding and animated
/// style wrappers (Material, Column, AnimatedDefaultTextStyle) that are not
/// visually edited — the drill-down should skip straight to the Text.
class StructuredCard extends StatelessWidget {
  const StructuredCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 100),
            style: const TextStyle(fontSize: 16, color: Color(0xFF222222)),
            child: const Text('Structured'),
          ),
        ],
      ),
    );
  }
}

/// Custom widget hosting a basic UI element (a button) — the drill-down
/// steps through whitelisted basics, not button internals.
class ButtonCard extends StatelessWidget {
  const ButtonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () {}, child: const Text('Press'));
  }
}

/// Screen with two widgets of the same type (FloatingActionButton) at
/// different positions — the top one keyed, the bottom one not — to exercise
/// sibling disambiguation (key + ordinal). `heroTag: null` avoids the
/// duplicate-hero-tag clash two default FABs would otherwise cause.
class TwoFabScreen extends StatelessWidget {
  const TwoFabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            key: const ValueKey('topFab'),
            heroTag: null,
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          FloatingActionButton(heroTag: null, onPressed: () {}, child: const Icon(Icons.remove)),
        ],
      ),
    );
  }
}

/// Screen-level custom widget hosting a [FancyCard].
class FancyScreen extends StatelessWidget {
  const FancyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: FancyCard(label: 'Hello')),
    );
  }
}

/// App shell with a persistent bottom navigation bar that lives in the root
/// route, while the page content sits inside a nested [Navigator]. The nav bar
/// therefore resolves to a different `(screenWidget, routeName)` than the page
/// content at the viewport centre — the real-world shape where shell chrome
/// must still show its annotation markers.
class ShellWithBottomNav extends StatelessWidget {
  const ShellWithBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const NestedHomePage())),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        ],
      ),
    );
  }
}

/// Page content hosted inside [ShellWithBottomNav]'s nested [Navigator].
class NestedHomePage extends StatelessWidget {
  const NestedHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Home content')));
  }
}

/// Parameterised screen — the same screen class shows different data. Two
/// instances (`TitleScreen('AAAA')` vs `TitleScreen('BBBB')`) put a same-size
/// Text at the same spot, differing only in content: the shape where a saved
/// annotation must NOT re-attach across instances.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(title)));
  }
}

/// Screen whose centred box carries a data-driven [ValueKey]. Two instances
/// place an identical widget at the same spot, differing only by key.
class KeyedBoxScreen extends StatelessWidget {
  const KeyedBoxScreen({super.key, required this.boxKey});

  final String boxKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ColoredBox(
          key: ValueKey(boxKey),
          color: const Color(0xFF2196F3),
          child: const SizedBox(width: 120, height: 40),
        ),
      ),
    );
  }
}

/// Screen that builds an identical-looking Text from one of two different
/// source lines. The two variants match on type, key, content and bounds —
/// only the widget creation site tells them apart.
class ToggleScreen extends StatelessWidget {
  const ToggleScreen({super.key, required this.useFirst});

  final bool useFirst;

  @override
  Widget build(BuildContext context) {
    if (useFirst) {
      return const Scaffold(body: Center(child: Text('Same')));
    }
    return const Scaffold(body: Center(child: Text('Same')));
  }
}

/// Screen whose annotated content can be covered in place by an opaque sibling
/// in the same [Stack]. The cover sits on the same screen widget and the same
/// route as the content, so nothing but the per-widget occlusion test can tell
/// the covered state apart.
class CoverableScreen extends StatelessWidget {
  const CoverableScreen({super.key, required this.covered});

  final bool covered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: Stack(
            children: [
              const Positioned.fill(child: Center(child: Text('Hello'))),
              if (covered) const Positioned.fill(child: ColoredBox(color: Color(0xFF123456))),
            ],
          ),
        ),
      ),
    );
  }
}
