import 'package:borealis/src/wiretap/wiretap.dart';
import 'package:flutter_test/flutter_test.dart';

WiretapEntry _entry(String url) {
  return WiretapEntry(
    id: '1',
    method: 'GET',
    uri: Uri.parse(url),
    requestHeaders: const {},
    requestBody: null,
    timestamp: DateTime.utc(2026, 1, 1),
    isLoading: false,
  );
}

void main() {
  group('WiretapEntry.matches', () {
    test('matches the path the list shows', () {
      expect(_entry('https://api.example.com/users/42').matches('users'), isTrue);
    });

    test('matches the query string, which the list shows too', () {
      expect(_entry('https://api.example.com/search?q=borealis').matches('borealis'), isTrue);
    });

    test('ignores case on both sides', () {
      expect(_entry('https://api.example.com/Users').matches('users'), isTrue);
      expect(_entry('https://api.example.com/users').matches('USERS'), isTrue);
    });

    test('does not match the scheme', () {
      // The field says "Search by path". Matching the whole URL meant typing
      // "https" selected every request that had been captured.
      expect(_entry('https://api.example.com/users').matches('https'), isFalse);
    });

    test('does not match the host', () {
      expect(_entry('https://api.example.com/users').matches('example.com'), isFalse);
    });

    test('a path-less URL still matches its root', () {
      expect(_entry('https://api.example.com').matches('/'), isTrue);
    });
  });
}
