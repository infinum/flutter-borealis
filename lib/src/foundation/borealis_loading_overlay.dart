part of 'foundation.dart';

/// Covers [child] with a centred spinner while [loading].
///
/// The child keeps its size and stays in the tree (so no layout jump), but is
/// hidden and non-interactive for the duration. Shared by every Borealis page
/// that runs an async action from a button.
class BorealisLoadingOverlay extends StatelessWidget {
  const BorealisLoadingOverlay({super.key, required this.loading, required this.child, this.indicatorSize = 24});

  final bool loading;
  final Widget child;

  /// Side of the square spinner drawn over [child].
  final double indicatorSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: !loading,
          maintainAnimation: true,
          maintainSize: true,
          maintainState: true,
          maintainFocusability: false,
          maintainInteractivity: false,
          maintainSemantics: false,
          child: child,
        ),
        if (loading)
          Positioned.fill(
            child: Center(
              child: SizedBox.square(dimension: indicatorSize, child: const CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
      ],
    );
  }
}
