part of 'rendering.dart';

/// Debug panel page exposing Flutter's render debug flags as switches, plus
/// the gamify toggle.
///
/// The render paint flags (`debugRepaintRainbowEnabled`, `debugPaintSizeEnabled`
/// and friends) are read inside `assert` blocks, so those switches are inert in
/// profile and release. **Slow animations** is not: it sets `timeDilation`,
/// which the scheduler divides by in every build mode.
class RenderingBorealisPage extends BorealisPage {
  const RenderingBorealisPage({super.useAppTheme = false}) : super(title: 'Rendering', icon: Icons.brush_outlined);

  @override
  Widget build(BuildContext context) => const RenderingPage();
}
