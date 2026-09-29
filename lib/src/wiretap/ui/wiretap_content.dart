part of '../wiretap.dart';

/// An embeddable widget that displays the network request log.
///
/// Contains a real-time search bar and a scrollable list of recorded requests.
/// It brings no [Scaffold] of its own, so it fits inside existing layouts such
/// as bottom sheets or debug panels:
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (_) => const WiretapContent(),
/// );
/// ```
class WiretapContent extends StatefulWidget {
  /// Creates a [WiretapContent] widget.
  ///
  /// [store] – the [WiretapStore] to observe. Defaults to [WiretapStore.instance] when not provided.
  /// [config] – display options such as [WiretapConfig.urlDisplay].
  const WiretapContent({super.key, this.store, this.config});

  /// The store whose entries are displayed.
  ///
  /// Defaults to [WiretapStore.instance] when not provided.
  final WiretapStore? store;

  /// Controls how request items are rendered.
  ///
  /// Defaults to [WiretapConfig.defaultConfig] when not provided.
  final WiretapConfig? config;

  @override
  State<WiretapContent> createState() => _WiretapContentState();
}

class _WiretapContentState extends State<WiretapContent> {
  final _searchController = TextEditingController();
  String _query = '';

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  WiretapStore get _store => widget.store ?? WiretapStore.instance;

  WiretapConfig get _config => widget.config ?? WiretapConfig.defaultConfig;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WiretapEntry> get _filteredEntries => _store.entries.where((e) => _query.isEmpty || e.matches(_query)).toList();

  bool get _exportConfigured => _config.onExport != null;

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  /// The entries an export would send: the explicit selection when the user
  /// made one, whatever the search filter says otherwise. Selection is intent,
  /// so it wins over the filter.
  List<WiretapEntry> get _exportableEntries {
    if (!_isSelectionMode) return _filteredEntries;
    return _store.entries.where((e) => _selectedIds.contains(e.id)).toList();
  }

  /// Writes the exportable entries to a file and hands the path to the config's
  /// callback. Null when no callback is set, which hides the action.
  Future<String?> Function()? get _exportEntries {
    final onExport = _config.onExport;
    if (onExport == null) return null;

    return () async {
      final entries = _exportableEntries;
      final file = await WiretapExportUtils.buildExportFile(entries, parsers: _config.parsers);
      await onExport(file);
      return 'Exported ${entries.length} ${entries.length == 1 ? 'request' : 'requests'}';
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final filteredEntries = _filteredEntries;

        return Column(
          children: [
            BorealisListHeader(
              controller: _searchController,
              hintText: 'Search by path…',
              resultCount: filteredEntries.length,
              actions: [
                BorealisExportButton(
                  onExport: _exportEntries,
                  tooltip: _isSelectionMode ? 'Export selected' : 'Export filtered logs',
                  enabled: _exportableEntries.isNotEmpty,
                ),
              ],
            ),
            _SelectionBar(
              selectedCount: _selectedIds.length,
              onCancel: _exitSelectionMode,
              isSelectionMode: _isSelectionMode,
            ),
            Expanded(
              child: filteredEntries.isEmpty
                  ? const Center(child: Text('No requests recorded yet.'))
                  : ListView.separated(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      separatorBuilder: (context, index) => Divider(
                        height: 0.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                      ),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        // Newest first, without copying the list again.
                        final entry = filteredEntries[filteredEntries.length - 1 - index];
                        return _EntryTile(
                          key: ValueKey(entry.id),
                          entry: entry,
                          config: _config,
                          isSelected: _selectedIds.contains(entry.id),
                          // Selection mode exists to pick entries for export,
                          // so don't enter it when export isn't configured.
                          onLongPress: !_exportConfigured
                              ? null
                              : _isSelectionMode
                              ? () => _toggleSelection(entry.id)
                              : () => _enterSelectionMode(entry.id),
                          onTap: _isSelectionMode
                              ? () => _toggleSelection(entry.id)
                              : () => Navigator.of(
                                  context,
                                ).push(WiretapDetailScreen.route(entryId: entry.id, config: _config, store: _store)),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.selectedCount, required this.onCancel, required this.isSelectionMode});

  final int selectedCount;
  final VoidCallback onCancel;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: isSelectionMode
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCount == 0 ? 'Select items' : '$selectedCount selected',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    super.key,
    required this.entry,
    required this.config,
    required this.isSelected,
    required this.onLongPress,
    required this.onTap,
  });

  final WiretapEntry entry;
  final WiretapConfig config;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLine = _buildTimeLine();

    final url = switch (config.urlDisplay) {
      WiretapUrlDisplay.pathOnly => entry.path,
      WiretapUrlDisplay.fullUrl => entry.uri.toString(),
    };
    final decodedUrl = config.urlDecoded ? Uri.decodeFull(url) : url;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
      // The tile needs a Material of its own above the selection tint: it paints
      // its ink splashes on the nearest Material ancestor, and without this one
      // that is the surface *below* the tint, which would hide them.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          title: Text(entry.method, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(decodedUrl, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                timeLine,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          trailing: _StatusChip(entry: entry),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  String _buildTimeLine() {
    final start = _formatTime(entry.timestamp);
    final duration = entry.duration;
    if (duration == null) return start;
    final end = _formatTime(entry.timestamp.add(duration));
    final durationLabel = duration.inMilliseconds >= 1000
        ? '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s'
        : '${duration.inMilliseconds}ms';
    return '$start → $end  —  $durationLabel';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entry});

  final WiretapEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.isLoading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final statusCode = entry.statusCode;
    final color = wiretapStatusColor(statusCode);
    final label = statusCode?.toString() ?? 'ERR';

    return Container(
      width: 40,
      height: 24,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
