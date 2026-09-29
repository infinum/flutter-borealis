import 'package:borealis/borealis.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loggy/loggy.dart';

class ScreenWithAction extends StatefulWidget {
  const ScreenWithAction({super.key});

  @override
  State<ScreenWithAction> createState() => _ScreenWithActionState();
}

class _ScreenWithActionState extends State<ScreenWithAction> with UiLoggy {
  @override
  Widget build(BuildContext context) {
    return ScreenDebugActions(
      screenName: 'Screen with additional actions',
      actions: (context) => [
        ListTile(
          title: Text('Go to next page'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Center(child: _SomeOtherPart())),
              ),
            );
            Borealis.hideDebugPanel();
          },
        ),
        ListTile(
          title: Text('Go back'),
          onTap: () {
            loggy.debug('Going back to main screen');
            Navigator.of(context).pop();
            Borealis.hideDebugPanel();
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Screen with additional actions')),
        body: const Center(child: Text('This screen has additional actions in the debug panel!')),
      ),
    );
  }
}

/// Demonstrates [ScreenDebugActions] — contributing debug actions from a widget
/// that has no [State] of its own. This is exactly the case for hook widgets
/// (`HookConsumerWidget`/`HookWidget`), where the state is hidden.
///
/// It also omits `screenName`, so the overlay groups these actions under this
/// widget's type: `StatelessScreenWithAction`.
class StatelessScreenWithAction extends StatelessWidget {
  const StatelessScreenWithAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenDebugActions(
      actions: (context) => [ListTile(title: const Text('Go back'), onTap: () => Navigator.of(context).pop())],
      child: Scaffold(
        appBar: AppBar(title: const Text('Stateless screen with actions')),
        body: const Center(child: Text('These debug actions come from a StatelessWidget!')),
      ),
    );
  }
}

class _SomeOtherPart extends StatefulWidget {
  const _SomeOtherPart();

  @override
  State<_SomeOtherPart> createState() => _SomeOtherPartState();
}

class _SomeOtherPartState extends State<_SomeOtherPart> with UiLoggy {
  @override
  Widget build(BuildContext context) {
    return ScreenDebugActions(
      screenName: 'Some other part of the app',
      actions: (context) => [
        Text('I can just show some random text'),
        ListTile(
          title: Text('Go back to previous screen'),
          onTap: () {
            loggy.debug('Going back to previous screen');
            Navigator.of(context).pop();
            Borealis.hideDebugPanel();
          },
        ),
        ListTile(
          title: Text('Go back to root'),
          onTap: () {
            loggy.debug('Going back to root screen');
            Navigator.of(context).popUntil((route) => route.isFirst);
            Borealis.hideDebugPanel();
          },
        ),
      ],
      child: CupertinoButton(
        onPressed: () {
          loggy.debug('Going back to main screen');
          Navigator.of(context).pop();
          Borealis.hideDebugPanel();
        },
        child: const Text('Go back!'),
      ),
    );
  }
}
