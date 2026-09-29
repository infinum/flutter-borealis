part of '../annotation.dart';

/// Red border over the selected [rect] plus a floating info window — styled
/// after the Claude/Figma inspect-annotation tooltip: a compact dark card with
/// a monospace type readout. The window is laid out by [_InfoWindowLayout] so
/// it always stays within the visible viewport (flips above the target when
/// there is no room below, and clamps horizontally to the screen edges).
class _AnnotationHighlight extends StatelessWidget {
  const _AnnotationHighlight({required this.target, required this.onAddNote});

  final _AnnotationTarget target;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final rect = target.rect;

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2)),
            ),
          ),
        ),
        // Fills the viewport so the layout delegate has the screen bounds to
        // clamp against; only the window itself is hit-testable, so taps
        // elsewhere fall through to reselect another widget.
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _InfoWindowLayout(targetRect: rect),
            child: _InfoWindow(target: target, onAddNote: onAddNote),
          ),
        ),
      ],
    );
  }
}

/// Positions the info window relative to [targetRect] while keeping it fully
/// inside the viewport. Prefers placing it just below the target; flips above
/// when it would overflow the bottom, and clamps to the margins otherwise.
class _InfoWindowLayout extends SingleChildLayoutDelegate {
  _InfoWindowLayout({required this.targetRect});

  final Rect targetRect;

  static const double _margin = 8;
  static const double _gap = 8;
  static const double _maxWidth = 320;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = (constraints.maxWidth - _margin * 2).clamp(0.0, _maxWidth);
    return BoxConstraints(
      maxWidth: maxWidth.toDouble(),
      maxHeight: (constraints.maxHeight - _margin * 2).clamp(0.0, double.infinity).toDouble(),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = (size.width - childSize.width - _margin).clamp(_margin, double.infinity);
    final left = targetRect.left.clamp(_margin, maxLeft).toDouble();

    final below = targetRect.bottom + _gap;
    final above = targetRect.top - _gap - childSize.height;
    final double top;
    if (below + childSize.height <= size.height - _margin) {
      top = below;
    } else if (above >= _margin) {
      top = above;
    } else {
      top = (size.height - childSize.height - _margin).clamp(_margin, double.infinity).toDouble();
    }
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_InfoWindowLayout oldDelegate) => oldDelegate.targetRect != targetRect;
}

/// Compact dark info window: an accent-dotted type header, a monospace key/value
/// readout of the resolved props, and an "add note" affordance.
class _InfoWindow extends StatelessWidget {
  const _InfoWindow({required this.target, required this.onAddNote});

  final _AnnotationTarget target;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final props = target.props;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              target.widgetType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _kMonoFamily,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (props.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.inverseSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 8),
              for (final entry in props.entries) _InfoRow(label: entry.key, value: entry.value),
            ],
            const SizedBox(height: 10),
            _AddNoteButton(onTap: onAddNote),
          ],
        ),
      ),
    );
  }
}

/// Single monospace `label  value` line; renders a swatch for color props.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  static const _baseStyle = TextStyle(fontFamily: _kMonoFamily, fontSize: 11.5, height: 1.5);

  @override
  Widget build(BuildContext context) {
    final swatch = _parseHex(value);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: _baseStyle.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          if (swatch != null)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          Flexible(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _baseStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  static Color? _parseHex(String hex) {
    final normalized = hex.replaceFirst('#', '');
    if (normalized.length != 6 && normalized.length != 8) return null;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;
    return Color(normalized.length == 6 ? (0xFF000000 | value) : value);
  }
}

/// Subtle accent-tinted "add note" button matching the window's monospace look.
class _AddNoteButton extends StatelessWidget {
  const _AddNoteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 16, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 6),
            Text(
              'Add note',
              style: TextStyle(
                fontFamily: _kMonoFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
