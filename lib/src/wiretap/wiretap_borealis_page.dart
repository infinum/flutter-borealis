part of 'wiretap.dart';

/// The **Network** tab: every request and response [WiretapInterceptor]
/// records.
///
/// Attach the interceptor or this tab stays empty:
///
/// ```dart
/// Borealis.initNetworkLogger(dio);
/// ```
///
/// Each row shows the method, the path, a start-to-end time line and a
/// color-coded status chip. A search bar filters by path, a tap opens the
/// request detail, and a long press starts multi-select for exporting a subset.
/// The tab keeps the most recent 1000 requests.
///
/// Set [WiretapConfig.onExport] and [WiretapConfig.onCurlExport] to enable the
/// export actions; each one stays hidden until its callback exists. Credential
/// headers are masked before capture — read
/// [WiretapInterceptor.defaultRedactedHeaders].
class WiretapBorealisPage extends BorealisPage {
  const WiretapBorealisPage({super.useAppTheme = false, this.wiretapConfig, this.store})
    : super(title: 'Network', icon: Icons.network_ping_outlined);

  /// The store this tab reads. Defaults to [WiretapStore.instance], the store
  /// [WiretapInterceptor] writes to when it is given none of its own. Pass the
  /// store handed to [Borealis.initNetworkLogger] to show that client's traffic
  /// here.
  final WiretapStore? store;

  final WiretapConfig? wiretapConfig;

  WiretapStore get _store => store ?? WiretapStore.instance;

  // Cached per store instead of held in one static: the page is const, so it
  // cannot build these itself, and both have to come back *identical* on every
  // call — the overlay subscribes to them and a fresh notifier per call breaks
  // the badge and replays the gamify history. Weakly keyed, so a short-lived
  // store takes its listenable with it.
  static final Expando<CountListenable> _badges = Expando('borealis.wiretapBadge');
  static final Expando<BorealisGamifyHook<WiretapEntry>> _gamifyHooks = Expando('borealis.wiretapGamify');

  @override
  Widget build(BuildContext context) => WiretapContent(store: _store, config: wiretapConfig);

  @override
  VoidCallback? get onClearTap => _store.clear;

  @override
  ValueListenable<int>? get badgeListenable {
    final store = _store;
    return _badges[store] ??= CountListenable(store, () => store.length);
  }

  @override
  void onAttach() {
    final store = _store;
    final hook = _gamifyHooks[store] ??= BorealisGamifyHook<WiretapEntry>(
      source: store,
      latest: () => store.newestCompleted,
      toEvent: (entry) => BorealisGamifyEvent(
        // A request can fail with no response at all (timeout, DNS, socket), so
        // there is no status to show — say ERR rather than "null".
        label: '${entry.method} ${entry.statusCode ?? 'ERR'} - ${(entry.duration?.inMilliseconds ?? 0) / 1000}s',
        color: wiretapStatusColor(entry.statusCode),
      ),
    );
    hook.attach();
  }

  @override
  void onDetach() => _gamifyHooks[_store]?.detach();
}
