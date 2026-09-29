part of 'actions.dart';

/// The body of the **Debug options** tab: the global controls, then the
/// controls each live [ScreenDebugActions] contributes, grouped by screen.
///
/// Internal to the package — reach it through [ActionsBorealisPage].
class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key, required this.actions});

  final List<Widget> actions;

  /// Screen-contributed actions to render below [actions].
  ///

  /// The registry `ScreenDebugActions` writes to. Global, like the widget
  /// that fills it.
  ValueListenable<List<ScreenActionEntry>> get _screenActions => visibleScreenActions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ...actions,
          ValueListenableBuilder(
            valueListenable: _screenActions,
            builder: (context, data, child) {
              if (data.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12.0),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 12.0),
                  ],
                  ...data.map(
                    (action) => Column(
                      key: ValueKey(action.id),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            action.screenName,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        ...action.actions,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
