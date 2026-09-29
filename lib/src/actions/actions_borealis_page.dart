part of 'actions.dart';

/// The **Debug options** tab: your own controls for changing app state.
///
/// It shows two sections. [actions] holds the global controls, which are
/// always present. Below them come the controls that a [ScreenDebugActions]
/// contributes, for as long as the screen that registered them stays in the
/// widget tree.
///
/// ```dart
/// ActionsBorealisPage(
///   actions: [
///     ButtonActionWidget(
///       label: 'Clear cache',
///       icon: Icons.delete_outline,
///       action: () => CacheService.clear(),
///     ),
///   ],
/// )
/// ```
///
/// Any widget works, but [ButtonActionWidget], [ToggleActionWidget],
/// [InputActionWidget] and [SelectableActionWidget] match the panel's styling
/// and handle their own loading and failure states. With no global actions and
/// no screen actions the tab is empty, so add this page only when you use one
/// of the two.
class ActionsBorealisPage extends BorealisPage {
  const ActionsBorealisPage({this.actions = const [], super.useAppTheme = false})
    : super(title: 'Debug options', icon: Icons.devices_other_outlined);

  /// Controls shown above the screen actions, on every screen.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ActionsPage(actions: actions);
  }
}
