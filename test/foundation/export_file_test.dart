@TestOn('vm')
library;

import 'dart:io';

import 'package:borealis/src/foundation/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _export({String prefix = 'borealis_test', List<String> records = const ['a record']}) {
  return BorealisExportUtils.writeExportFile(
    title: 'Test export',
    unit: 'records',
    filePrefix: prefix,
    records: records,
  );
}

void main() {
  group('writeExportFile', () {
    test('writes into a Borealis-owned subdirectory of the system temp dir', () async {
      final path = await _export();

      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.parent.path, endsWith('borealis_exports'));
      expect(file.parent.parent.path, Directory.systemTemp.path);
      expect(file.readAsStringSync(), contains('a record'));
    });

    test('keeps exports written earlier in the same run', () async {
      final first = await _export(records: const ['first run record']);
      final second = await _export(records: const ['second run record']);

      expect(first, isNot(second), reason: 'two exports must not collide on one path');
      expect(File(first).existsSync(), isTrue);
      expect(File(second).existsSync(), isTrue);
    });

    test('removes exports left behind by an earlier run', () async {
      final stale = await _export(records: const ['from a previous run']);
      // Backdating it past the point this process started exporting is what an
      // export from yesterday's session looks like on disk.
      File(stale).setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));

      final fresh = await _export(records: const ['from this run']);

      expect(File(stale).existsSync(), isFalse, reason: 'an export from an earlier run must not survive');
      expect(File(fresh).existsSync(), isTrue);
    });
  });
}
