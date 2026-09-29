part of '../annotation.dart';

/// A saved annotation resolved to its current on-screen position for drawing.
class _AnnotationMarker {
  const _AnnotationMarker({required this.number, required this.rect, required this.annotation});

  /// 1-based store position, shown in the badge.
  final int number;

  /// The widget's live global bounds (tracks scrolling).
  final Rect rect;

  /// The saved annotation this marker draws, so a badge tap can edit it.
  final Annotation annotation;
}

/// Markers for the currently visible saved annotations: a faint outline of each
/// widget's live bounds plus a numbered badge in its top-left corner.
///
/// The outlines always ignore pointers. Badges are interactive only when
/// [onBadgeTap] is supplied — used while annotation capture is off so saved
/// notes can still be edited. When it is null the whole layer is inert and the
/// overlay's full-screen tap catcher owns badge-corner taps.
class _SavedAnnotationMarkers extends StatelessWidget {
  const _SavedAnnotationMarkers({required this.markers, this.onBadgeTap});

  final List<_AnnotationMarker> markers;

  final void Function(Annotation annotation)? onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final marker in markers) ...[
          Positioned.fromRect(
            rect: marker.rect,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: marker.rect.left, top: marker.rect.top, child: _buildBadge(context, marker)),
        ],
      ],
    );
  }

  /// The numbered corner badge — tappable to edit its note when [onBadgeTap] is
  /// supplied, inert otherwise.
  Widget _buildBadge(BuildContext context, _AnnotationMarker marker) {
    final onTap = onBadgeTap;
    final badge = _AnnotationBadge(number: marker.number, color: Theme.of(context).colorScheme.primary);

    if (onTap == null) return IgnorePointer(child: badge);

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap(marker.annotation), child: badge);
  }
}

class _AnnotationBadge extends StatelessWidget {
  const _AnnotationBadge({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: _kBadgeSize,
        height: _kBadgeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
        ),
        child: Text(
          '$number',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, height: 1),
        ),
      ),
    );
  }
}
