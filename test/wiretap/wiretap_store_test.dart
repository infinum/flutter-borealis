import 'package:borealis/src/wiretap/wiretap.dart';
import 'package:flutter_test/flutter_test.dart';

WiretapEntry _entry({required String id, int? statusCode, bool? isLoading, DateTime? timestamp}) {
  return WiretapEntry(
    id: id,
    method: 'GET',
    uri: Uri.parse('https://api.example.com/$id'),
    requestHeaders: const {},
    requestBody: null,
    // Defaults to now: an entry's age decides whether eviction may take it
    // while it is still in flight, so a fixture pinned to a past date would
    // read as abandoned.
    timestamp: timestamp ?? DateTime.now(),
    statusCode: statusCode,
    // A request that failed before it got a response is finished but has no
    // status, so the two are set independently.
    isLoading: isLoading ?? statusCode == null,
  );
}

void main() {
  group('WiretapStore', () {
    test('entries view is unmodifiable and reflects later additions', () {
      final store = WiretapStore()..add(_entry(id: '1', statusCode: 200));

      final before = store.entries;
      expect(() => before.add(_entry(id: 'x')), throwsUnsupportedError);
      expect(before, hasLength(1));

      store.add(_entry(id: '2', statusCode: 200));

      expect(store.entries, hasLength(2));
    });

    test('length matches the entry count without materialising the list', () {
      final store = WiretapStore()
        ..add(_entry(id: '1', statusCode: 200))
        ..add(_entry(id: '2'));

      expect(store.length, 2);

      store.clear();

      expect(store.length, 0);
    });

    test('update replaces an entry in place and keeps its position', () {
      final store = WiretapStore()
        ..add(_entry(id: '1'))
        ..add(_entry(id: '2'));

      store.update(_entry(id: '1', statusCode: 500));

      expect(store.entries.first.statusCode, 500);
      expect(store.entries.map((e) => e.id), ['1', '2']);
    });

    test('update ignores entries the store does not know', () {
      final store = WiretapStore()..add(_entry(id: '1'));

      store.update(_entry(id: 'unknown', statusCode: 200));

      expect(store.length, 1);
    });

    test('newestCompleted is the entry that finished last', () {
      final store = WiretapStore()
        ..add(_entry(id: '1', statusCode: 200))
        ..add(_entry(id: '2', statusCode: 404))
        ..add(_entry(id: '3'));

      expect(store.newestCompleted?.id, '2');
    });

    test('newestCompleted is null while every entry is in flight', () {
      final store = WiretapStore()..add(_entry(id: '1'));

      expect(store.newestCompleted, isNull);
    });

    test('newestCompleted follows completion order, not insertion order', () {
      final store = WiretapStore()
        ..add(_entry(id: '1'))
        ..add(_entry(id: '2'));

      // The second request answers first, then the first one does. Insertion
      // order would report '2' throughout and never surface '1' finishing.
      store.update(_entry(id: '2', statusCode: 200));
      expect(store.newestCompleted?.id, '2');

      store.update(_entry(id: '1', statusCode: 200));
      expect(store.newestCompleted?.id, '1');
    });

    test('newestCompleted counts a failure that carries no status code', () {
      final store = WiretapStore()..add(_entry(id: '1'));

      // A connection timeout: done, but there is no response to read a status
      // from.
      store.update(_entry(id: '1', isLoading: false));

      expect(store.newestCompleted?.id, '1');
      expect(store.newestCompleted?.statusCode, isNull);
    });

    test('an update that does not finish a request leaves newestCompleted alone', () {
      final store = WiretapStore()
        ..add(_entry(id: '1', statusCode: 200))
        ..add(_entry(id: '2'));

      store.update(_entry(id: '2'));

      expect(store.newestCompleted?.id, '1');
    });

    test('clear resets newestCompleted', () {
      final store = WiretapStore()..add(_entry(id: '1', statusCode: 200));

      store.clear();

      expect(store.newestCompleted, isNull);
    });

    test('trimming drops the oldest completed entries first', () {
      final store = WiretapStore();
      // One pending entry at the very front, then enough completed ones to
      // push the store one past its 1000-entry cap.
      store.add(_entry(id: 'pending'));
      for (var i = 0; i < 1000; i++) {
        store.add(_entry(id: 'done-$i', statusCode: 200));
      }

      expect(store.length, 1000);
      expect(store['pending'], isNotNull, reason: 'an in-flight request must stay visible');
      expect(store['done-0'], isNull, reason: 'the oldest completed entry is evicted first');
    });

    test('trimming treats a status-less failure as finished, not in flight', () {
      final store = WiretapStore();
      store.add(_entry(id: 'pending'));
      store.add(_entry(id: 'failed', isLoading: false));
      for (var i = 0; i < 999; i++) {
        store.add(_entry(id: 'done-$i', statusCode: 200));
      }

      expect(store.length, 1000);
      expect(store['failed'], isNull, reason: 'the oldest finished entry is evicted first');
      expect(store['pending'], isNotNull, reason: 'an in-flight request must stay visible');
    });

    test('trimming evicts an in-flight entry that has gone stale', () {
      final store = WiretapStore();
      // An interceptor registered after the wiretap answered this request
      // itself, so onResponse never ran and the entry never left isLoading.
      // Protecting it forever would cost a real entry on every capture.
      store.add(_entry(id: 'abandoned', timestamp: DateTime.now().subtract(const Duration(hours: 1))));
      for (var i = 0; i < 1000; i++) {
        store.add(_entry(id: 'done-$i', statusCode: 200));
      }

      expect(store.length, 1000);
      expect(store['abandoned'], isNull, reason: 'an abandoned request must not outrank a completed one');
      expect(store['done-0'], isNotNull, reason: 'the stale entry is evicted instead of the oldest completed one');
    });

    test('trimming still protects an in-flight entry that is merely recent', () {
      final store = WiretapStore();
      store.add(_entry(id: 'in-flight', timestamp: DateTime.now()));
      for (var i = 0; i < 1000; i++) {
        store.add(_entry(id: 'done-$i', statusCode: 200));
      }

      expect(store['in-flight'], isNotNull);
      expect(store['done-0'], isNull);
    });

    test('trimming falls back to the oldest entry when all are pending', () {
      final store = WiretapStore();
      for (var i = 0; i < 1001; i++) {
        store.add(_entry(id: 'pending-$i'));
      }

      expect(store.length, 1000);
      expect(store['pending-0'], isNull);
    });
  });
}
