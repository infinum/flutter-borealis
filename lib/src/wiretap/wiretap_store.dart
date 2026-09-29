part of 'wiretap.dart';

/// An observable store that holds captured [WiretapEntry] objects.
///
/// [WiretapInterceptor] writes to a store and the Wiretap UI widgets read from
/// it. The store extends [ChangeNotifier], so any widget wrapped in a
/// [ListenableBuilder] (or [AnimatedBuilder]) will rebuild automatically
/// whenever entries are added, updated, or cleared.
///
/// Use the shared singleton for the default setup:
///
/// ```dart
/// final store = WiretapStore.instance;
/// ```
///
/// Or create a private instance to keep logs for different [Dio] clients
/// isolated from each other.
class WiretapStore extends ChangeNotifier {
  WiretapStore() : _entries = LinkedHashMap<String, WiretapEntry>();

  static const _maxEvents = kBorealisMaxStoredEntries;

  /// The shared singleton used by default when no explicit store is supplied
  /// to [WiretapInterceptor] or [WiretapContent].
  static final instance = WiretapStore();

  final LinkedHashMap<String, WiretapEntry> _entries;

  List<WiretapEntry>? _entriesCache;

  /// The captured entries, oldest first, as an unmodifiable list.
  ///
  /// Built once per mutation instead of once per read: the badge count, the
  /// gamify hook and every list rebuild all read this on each captured request,
  /// and copying a 1000-entry store for each of them is pure waste. Prefer
  /// [length] and [newestCompleted] where the full list isn't needed.
  List<WiretapEntry> get entries => _entriesCache ??= List.unmodifiable(_entries.values);

  /// Number of captured entries, without materialising [entries].
  int get length => _entries.length;

  WiretapEntry? operator [](String id) => _entries[id];

  /// The entry that most recently stopped being in flight — got a response, or
  /// failed — or `null` until one has. Errors that carry no HTTP status (a
  /// connection timeout, a DNS failure) count: they finished too.
  ///
  /// Recorded on the transition rather than derived from [entries]. Requests do
  /// not complete in the order they were issued, so picking the last finished
  /// entry out of the insertion-ordered list reports whichever one happens to
  /// sit furthest along, not the one that just finished — and a request that
  /// finishes before an older one would then never be reported at all.
  WiretapEntry? get newestCompleted => _newestCompleted;
  WiretapEntry? _newestCompleted;

  void add(WiretapEntry entry) {
    _entries[entry.id] = entry;
    if (!entry.isLoading) _newestCompleted = entry;
    _trim();
    _entriesCache = null;
    notifyListeners();
  }

  void update(WiretapEntry entry) {
    final previous = _entries[entry.id];
    if (previous == null) {
      return;
    }

    _entries[entry.id] = entry;
    if (previous.isLoading && !entry.isLoading) _newestCompleted = entry;
    _entriesCache = null;
    notifyListeners();
  }

  /// How long an entry may stay in flight before eviction stops protecting it.
  ///
  /// An interceptor registered after [WiretapInterceptor] can answer a request
  /// itself — dio's `handler.resolve` and `handler.reject` skip the rest of the
  /// chain by default, which cache, offline-queue and some retry interceptors
  /// rely on. The wiretap's `onResponse` then never runs and the entry stays
  /// loading for good. Without this cut-off those entries are protected
  /// forever, and because each one costs a real entry on every capture, the
  /// usable buffer shrinks until the tab is a list of spinners.
  ///
  /// Long enough that no genuine request reaches it: dio's own connect and
  /// receive timeouts are measured in seconds, and a request still running
  /// after two minutes has nothing left to show.
  static const _staleAfter = Duration(minutes: 2);

  /// Evicts oldest entries once the store grows past [_maxEvents].
  ///
  /// Finished entries are dropped first so in-flight requests stay visible.
  /// Finished means no longer loading, not "has a status code" — a request that
  /// failed without a response is done too, and holding it as if it were still
  /// pending would evict a live request instead. An entry that has been in
  /// flight longer than [_staleAfter] counts as finished for this purpose; see
  /// that constant for why one can get stuck. If every overflowing entry is
  /// still pending and recent, the oldest one is removed instead so the bound
  /// always holds and the store can never get stuck above the limit.
  void _trim() {
    if (_entries.length <= _maxEvents) return;

    final now = DateTime.now();
    // One pass, resumed across evictions. Restarting the scan from the head per
    // evicted entry made trimming quadratic in the overflow, which is the case
    // it exists for.
    final keys = _entries.keys.toList(growable: false);
    var cursor = 0;

    while (_entries.length > _maxEvents) {
      String? evictable;
      while (cursor < keys.length) {
        final key = keys[cursor++];
        final entry = _entries[key];
        if (entry == null) continue;
        if (!entry.isLoading || now.difference(entry.timestamp) > _staleAfter) {
          evictable = key;
          break;
        }
      }
      // Everything left is in flight and recent: drop the oldest anyway, so the
      // bound always holds and the store can never get stuck above the limit.
      _entries.remove(evictable ?? _entries.keys.first);
    }
  }

  void clear() {
    _entries.clear();
    _entriesCache = null;
    _newestCompleted = null;
    notifyListeners();
  }
}
