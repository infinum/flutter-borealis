part of 'rendering.dart';

/// One row of the Rendering page: a labelled switch over a debug flag.
class _DebugFlag {
  const _DebugFlag({required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool Function() value;
  final void Function(bool value) onChanged;
}

/// Section header rendered between groups of flags.
class _DebugFlagSection {
  const _DebugFlagSection(this.title);

  final String title;
}

/// The body of the **Rendering** tab: Flutter's render debug flags, one
/// switch each.
///
/// Internal to the package — reach it through [RenderingBorealisPage].
class RenderingPage extends StatefulWidget {
  const RenderingPage({super.key, this.gamify});

  /// Notifier toggled by the "Gamify" switch.
  ///
  /// Defaults to [gamifyBorealis] when not provided.
  final ValueNotifier<bool>? gamify;

  @override
  State<RenderingPage> createState() => _RenderingPageState();
}

class _RenderingPageState extends State<RenderingPage> {
  ValueNotifier<bool> get _gamify => widget.gamify ?? gamifyBorealis;

  /// The rows, in display order. Each flag reads and writes a global debug
  /// switch directly, so the list stays declarative and adding one is a line.
  List<Object> get _rows => [
    _DebugFlag(
      title: 'Slow animations',
      value: () => timeDilation != 1.0,
      onChanged: (value) => timeDilation = value ? 8.0 : 1.0,
    ),
    const _DebugFlagSection('UI'),
    _DebugFlag(
      title: 'Repaint rainbow',
      subtitle: 'Border changes color on redraw',
      value: () => debugRepaintRainbowEnabled,
      onChanged: (value) => debugRepaintRainbowEnabled = value,
    ),
    _DebugFlag(
      title: 'Repaint text rainbow',
      subtitle: 'Text color changes on redraw',
      value: () => debugRepaintTextRainbowEnabled,
      onChanged: (value) => debugRepaintTextRainbowEnabled = value,
    ),
    _DebugFlag(
      title: 'Show widget sizes',
      subtitle: 'Show layout, padding and margins',
      value: () => debugPaintSizeEnabled,
      onChanged: (value) => debugPaintSizeEnabled = value,
    ),
    _DebugFlag(
      title: 'Paint hitboxes on tap',
      subtitle: 'Inspect hitbox size',
      value: () => debugPaintPointersEnabled,
      onChanged: (value) => debugPaintPointersEnabled = value,
    ),
    const _DebugFlagSection('Borealis'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom, top: 24.0),
      children: [
        for (final row in _rows)
          switch (row) {
            _DebugFlagSection(:final title) => ListTile(title: Text(title), dense: true, enabled: false),
            final _DebugFlag flag => SwitchListTile.adaptive(
              dense: true,
              title: Text(flag.title),
              subtitle: flag.subtitle == null ? null : Text(flag.subtitle!),
              value: flag.value(),
              onChanged: (value) => setState(() => flag.onChanged(value)),
            ),
            _ => const SizedBox.shrink(),
          },
        // Listens to the notifier rather than snapshotting it, so the switch
        // still reflects the state when gamify is toggled from elsewhere.
        ValueListenableBuilder<bool>(
          valueListenable: _gamify,
          builder: (context, gamifyEnabled, _) => SwitchListTile.adaptive(
            dense: true,
            title: const Text('Gamify'),
            subtitle: const Text('Enable gamified overlay'),
            value: gamifyEnabled,
            onChanged: (value) => _gamify.value = value,
          ),
        ),
      ],
    );
  }
}
