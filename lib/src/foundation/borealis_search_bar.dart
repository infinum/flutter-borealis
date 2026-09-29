part of 'foundation.dart';

/// Search field shared by the list-based Borealis pages.
class BorealisSearchBar extends StatelessWidget {
  const BorealisSearchBar({super.key, required this.controller, required this.hintText, this.resultCount});

  final TextEditingController controller;
  final String hintText;

  /// When non-null, shown inline as `<resultCount> results` while a query is
  /// active.
  final int? resultCount;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (resultCount != null) Text('$resultCount results'),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: controller.clear),
                  ],
                ),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// The export action the list-based Borealis pages put beside their search bar.
///
/// Owns the whole export interaction: hide when unconfigured, disable when
/// there is nothing to send, one run at a time, a spinner over the icon while
/// it runs, and the result or the failure reported through
/// [runBorealisExport]. Written once because the Logs tab and the Network tab
/// held a copy each, and the copies had drifted — different spinner sizes,
/// different empty-guards, and one of them reporting nothing on success.
class BorealisExportButton extends StatefulWidget {
  const BorealisExportButton({
    super.key,
    required this.onExport,
    required this.tooltip,
    this.enabled = true,
    this.icon = Icons.ios_share,
  });

  /// Runs the export and returns the message to show, or null for none.
  ///
  /// When this is null the button is not rendered at all, which is how a page
  /// hides an action its config never supplied a callback for.
  final Future<String?> Function()? onExport;

  final String tooltip;

  /// Whether there is anything to export right now.
  final bool enabled;

  final IconData icon;

  @override
  State<BorealisExportButton> createState() => _BorealisExportButtonState();
}

class _BorealisExportButtonState extends State<BorealisExportButton> {
  bool _running = false;

  Future<void> _run() async {
    final onExport = widget.onExport;
    if (onExport == null || _running) return;

    setState(() => _running = true);
    try {
      await runBorealisExport(context, onExport);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onExport == null) return const SizedBox.shrink();

    return BorealisLoadingOverlay(
      loading: _running,
      indicatorSize: 18,
      child: IconButton(
        icon: Icon(widget.icon),
        tooltip: widget.tooltip,
        onPressed: widget.enabled && !_running ? _run : null,
      ),
    );
  }
}

/// The header the list-based Borealis pages share: a search field, and any
/// actions that belong beside it.
class BorealisListHeader extends StatelessWidget {
  const BorealisListHeader({
    super.key,
    required this.controller,
    required this.hintText,
    this.resultCount,
    this.actions = const [],
  });

  final TextEditingController controller;
  final String hintText;

  /// Shown inline while a query is active. Both pages filter, so both say how
  /// much survived the filter.
  final int? resultCount;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        spacing: 2,
        children: [
          Expanded(
            child: BorealisSearchBar(controller: controller, hintText: hintText, resultCount: resultCount),
          ),
          ...actions,
        ],
      ),
    );
  }
}
