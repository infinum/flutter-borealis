import 'package:borealis/src/annotation/annotation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a candidate render object on the hit-test path.
class _Candidate {
  const _Candidate(this.depth, {required this.hasSize, required this.resolvable});

  final int depth;
  final bool hasSize;
  final bool resolvable;
}

void main() {
  group('firstAnnotationTarget', () {
    bool resolvable(_Candidate c) => c.hasSize && c.resolvable;

    test('picks the deepest candidate that has size and a resolvable element', () {
      // Hit-test path is deepest-first.
      final path = [
        const _Candidate(0, hasSize: false, resolvable: true), // zero-size, skip
        const _Candidate(1, hasSize: true, resolvable: false), // no element, skip
        const _Candidate(2, hasSize: true, resolvable: true), // <- target
        const _Candidate(3, hasSize: true, resolvable: true),
      ];

      final target = firstAnnotationTarget(path, isResolvable: resolvable);

      expect(target?.depth, 2);
    });

    test('returns null when nothing resolves', () {
      final path = [
        const _Candidate(0, hasSize: false, resolvable: true),
        const _Candidate(1, hasSize: true, resolvable: false),
      ];

      expect(firstAnnotationTarget(path, isResolvable: resolvable), isNull);
    });

    test('returns null for an empty path', () {
      expect(firstAnnotationTarget(const <_Candidate>[], isResolvable: resolvable), isNull);
    });
  });
}
