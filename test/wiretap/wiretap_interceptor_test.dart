import 'dart:typed_data';

import 'package:borealis/src/wiretap/wiretap.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a canned response so the interceptor runs against a real Dio
/// pipeline — `options.extra` tagging included — without touching the network.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter({this.statusCode = 200, this.responseHeaders = const {}, this.body = '{}'});

  final int statusCode;
  final Map<String, List<String>> responseHeaders;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: const ['application/json'],
        ...responseHeaders,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Runs after the wiretap interceptor, as any interceptor registered later
/// would, and mutates the response headers both ways dio allows.
class _HeaderMutator extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    response.headers.set('x-trace', 'rewritten-after-capture');
    response.headers.add('set-cookie', 'b=2');
    handler.next(response);
  }
}

Dio _client(
  WiretapStore store, {
  int statusCode = 200,
  Map<String, List<String>> responseHeaders = const {},
  Set<String>? redactHeaders,
  Set<String>? redactBodyKeys,
  String responseBody = '{}',
}) {
  return Dio()
    ..httpClientAdapter = _CannedAdapter(statusCode: statusCode, responseHeaders: responseHeaders, body: responseBody)
    ..interceptors.add(WiretapInterceptor(store: store, redactHeaders: redactHeaders, redactBodyKeys: redactBodyKeys));
}

/// Posts [data] and returns the entry the interceptor captured for it.
Future<WiretapEntry> _capturePost(Dio client, WiretapStore store, Object? data) async {
  try {
    await client.post<dynamic>('https://api.example.com/token', data: data);
  } on DioException {
    // The entry is what matters.
  }
  return store.entries.single;
}

/// Sends one request and returns the entry the interceptor captured for it.
/// Swallows the error so the non-2xx cases can assert on the stored entry.
Future<WiretapEntry> _capture(Dio client, WiretapStore store, {Map<String, dynamic> headers = const {}}) async {
  try {
    await client.get<dynamic>('https://api.example.com/users', options: Options(headers: headers));
  } on DioException {
    // The error path is under test; the entry is what matters.
  }
  return store.entries.single;
}

void main() {
  group('WiretapInterceptor header redaction', () {
    test('masks Authorization on the request before it reaches the store', () async {
      final store = WiretapStore();

      final entry = await _capture(_client(store), store, headers: {'Authorization': 'Bearer secret-token'});

      expect(entry.requestHeaders['Authorization'], WiretapInterceptor.redactedValue);
      expect(entry.requestHeaders.toString(), isNot(contains('secret-token')));
    });

    test('masks Set-Cookie on a successful response', () async {
      final store = WiretapStore();
      final client = _client(
        store,
        responseHeaders: {
          'set-cookie': const ['session=secret-session; HttpOnly'],
        },
      );

      final entry = await _capture(client, store);

      expect(entry.responseHeaders?['set-cookie'], WiretapInterceptor.redactedValue);
      expect(entry.responseHeaders.toString(), isNot(contains('secret-session')));
    });

    test('masks Set-Cookie on the DioException path too', () async {
      final store = WiretapStore();
      final client = _client(
        store,
        statusCode: 500,
        responseHeaders: {
          'set-cookie': const ['session=secret-session'],
        },
      );

      final entry = await _capture(client, store, headers: {'Cookie': 'a=secret-crumb'});

      expect(entry.statusCode, 500);
      expect(entry.isLoading, isFalse);
      expect(entry.responseHeaders?['set-cookie'], WiretapInterceptor.redactedValue);
      expect(entry.requestHeaders['Cookie'], WiretapInterceptor.redactedValue);
    });

    test('matches header names case-insensitively, in both directions', () async {
      final store = WiretapStore();

      final entry = await _capture(
        // The configured name is upper-case; the sent headers are not.
        _client(store, redactHeaders: {'X-Custom-Secret'}),
        store,
        headers: {'x-custom-secret': 'nope', 'AUTHORIZATION': 'Bearer kept'},
      );

      expect(entry.requestHeaders['x-custom-secret'], WiretapInterceptor.redactedValue);
      // An explicit set replaces the defaults rather than adding to them.
      expect(entry.requestHeaders['AUTHORIZATION'], 'Bearer kept');
    });

    test('leaves unlisted headers untouched', () async {
      final store = WiretapStore();

      final entry = await _capture(
        _client(store),
        store,
        headers: {'Authorization': 'Bearer secret-token', 'X-Borealis-Demo': 'example-app'},
      );

      expect(entry.requestHeaders['X-Borealis-Demo'], 'example-app');
    });

    test('an empty set captures every header verbatim', () async {
      final store = WiretapStore();

      final entry = await _capture(
        _client(store, redactHeaders: const {}),
        store,
        headers: {'Authorization': 'Bearer secret-token'},
      );

      expect(entry.requestHeaders['Authorization'], 'Bearer secret-token');
    });

    test('defaultRedactedHeaders covers the common credential headers', () {
      expect(
        WiretapInterceptor.defaultRedactedHeaders,
        containsAll(['authorization', 'proxy-authorization', 'cookie', 'set-cookie', 'x-api-key']),
      );
    });
  });

  group('WiretapInterceptor redaction reaches the export paths', () {
    testWidgets('the cURL export of a captured request carries no credential', (tester) async {
      final store = WiretapStore();
      String? curl;

      await tester.runAsync(() async {
        await _capture(
          _client(store),
          store,
          headers: {'Authorization': 'Bearer secret-token', 'Cookie': 'a=secret-crumb'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => WiretapDetailScreen.route(
              entryId: store.entries.single.id,
              config: WiretapConfig(onCurlExport: (value) => curl = value),
              store: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as cURL'));
      await tester.pumpAndSettle();

      expect(curl, isNotNull);
      expect(curl, isNot(contains('secret-token')));
      expect(curl, isNot(contains('secret-crumb')));
      expect(curl, contains('-H \'Authorization: ${WiretapInterceptor.redactedValue}\''));
    });
  });

  group('WiretapInterceptor snapshots the headers it captures', () {
    // dio hands the live response map to every interceptor in the chain, and
    // `Headers.add` appends to the existing list in place. A store that shared
    // either would report headers that were never on the wire.
    late Dio client;
    late WiretapStore store;

    void build({Set<String>? redactHeaders}) {
      store = WiretapStore();
      client = Dio()
        ..httpClientAdapter = _CannedAdapter(
          responseHeaders: {
            'x-trace': <String>['original-trace'],
            'set-cookie': <String>['a=1'],
          },
        )
        ..interceptors.add(WiretapInterceptor(store: store, redactHeaders: redactHeaders))
        ..interceptors.add(_HeaderMutator());
    }

    test('a later interceptor cannot rewrite a recorded header', () async {
      build(redactHeaders: const {});

      final entry = await _capture(client, store);

      expect(entry.responseHeaders?['x-trace'], <String>['original-trace']);
    });

    test('a later interceptor cannot append to a recorded multi-value header', () async {
      build(redactHeaders: const {});

      final entry = await _capture(client, store);

      expect(entry.responseHeaders?['set-cookie'], <String>['a=1']);
    });

    test('the snapshot holds when no header matches the redaction set', () async {
      // The old early-return handed back the live map whenever nothing matched,
      // which is most responses.
      build(redactHeaders: {'authorization'});

      final entry = await _capture(client, store);

      expect(entry.responseHeaders?['x-trace'], <String>['original-trace']);
      expect(entry.responseHeaders?['set-cookie'], <String>['a=1']);
    });

    test('mutating the request headers after the call does not alter the entry', () async {
      final store = WiretapStore();
      final headers = <String, dynamic>{'x-req': 'original'};
      final client = Dio()
        ..httpClientAdapter = _CannedAdapter()
        ..interceptors.add(WiretapInterceptor(store: store, redactHeaders: const {}));

      await client.get<dynamic>('https://api.example.com/users', options: Options(headers: headers));
      headers['x-req'] = 'mutated';

      expect(store.entries.single.requestHeaders['x-req'], 'original');
    });
  });

  group('WiretapInterceptor body redaction', () {
    test('masks configured keys in a request body map before capture', () async {
      final store = WiretapStore();

      final entry = await _capturePost(_client(store, redactBodyKeys: {'access_token'}), store, {
        'access_token': 'secret-token',
        'expires_in': 3600,
      });

      expect((entry.requestBody as Map)['access_token'], WiretapInterceptor.redactedValue);
      expect((entry.requestBody as Map)['expires_in'], 3600);
      expect(entry.requestBody.toString(), isNot(contains('secret-token')));
    });

    test('masks configured keys in a response body map', () async {
      final store = WiretapStore();
      final client = _client(
        store,
        redactBodyKeys: {'refresh_token'},
        responseBody: '{"refresh_token":"secret-refresh","token_type":"bearer"}',
      );

      final entry = await _capturePost(client, store, null);

      expect((entry.responseBody as Map)['refresh_token'], WiretapInterceptor.redactedValue);
      expect((entry.responseBody as Map)['token_type'], 'bearer');
    });

    test('reaches keys nested in maps and in lists', () async {
      final store = WiretapStore();

      final entry = await _capturePost(_client(store, redactBodyKeys: {'password'}), store, {
        'user': {'password': 'secret-pw', 'name': 'ada'},
        'accounts': [
          {'password': 'another-secret'},
        ],
      });

      final body = entry.requestBody as Map;
      expect((body['user'] as Map)['password'], WiretapInterceptor.redactedValue);
      expect((body['user'] as Map)['name'], 'ada');
      expect(((body['accounts'] as List).single as Map)['password'], WiretapInterceptor.redactedValue);
      expect(entry.requestBody.toString(), isNot(contains('secret')));
    });

    test('matches body keys case-insensitively', () async {
      final store = WiretapStore();

      final entry = await _capturePost(_client(store, redactBodyKeys: {'Access_Token'}), store, {
        'ACCESS_TOKEN': 'secret-token',
      });

      expect((entry.requestBody as Map)['ACCESS_TOKEN'], WiretapInterceptor.redactedValue);
    });

    test('captures every body key when no keys are configured', () async {
      final store = WiretapStore();

      final entry = await _capturePost(_client(store), store, {'access_token': 'secret-token'});

      expect((entry.requestBody as Map)['access_token'], 'secret-token');
    });

    test('leaves a body that is not a map or list untouched', () async {
      final store = WiretapStore();

      final entry = await _capturePost(_client(store, redactBodyKeys: {'access_token'}), store, 'access_token=abc');

      expect(entry.requestBody, 'access_token=abc');
    });
  });

  group('WiretapInterceptor bounds the bodies it captures', () {
    test('a byte body past the cap is replaced with a size marker', () async {
      final store = WiretapStore();
      final big = List<int>.filled(WiretapInterceptor.maxCapturedBodyBytes + 1, 7);

      final entry = await _capturePost(_client(store), store, big);

      expect(entry.requestBody, isA<String>());
      expect(entry.requestBody as String, contains('${big.length} bytes'));
      expect(entry.requestBody as String, contains('not captured'));
    });

    test('a byte body within the cap is captured whole', () async {
      final store = WiretapStore();
      final small = List<int>.filled(16, 7);

      final entry = await _capturePost(_client(store), store, small);

      expect(entry.requestBody, isA<List<int>>());
      expect((entry.requestBody as List).length, 16);
    });

    test('a string body past the cap is truncated with a marker', () async {
      final store = WiretapStore();
      final big = 'a' * (WiretapInterceptor.maxCapturedBodyChars + 100);

      final entry = await _capturePost(_client(store), store, big);

      final captured = entry.requestBody as String;
      expect(captured.length, lessThan(big.length));
      expect(captured, startsWith('a' * 100));
      expect(captured, contains('truncated'));
      expect(captured, contains('${big.length}'));
    });

    test('a request body map is snapshotted so a later mutation cannot rewrite it', () async {
      final store = WiretapStore();
      final body = <String, dynamic>{'value': 'original'};

      await _capturePost(_client(store), store, body);
      body['value'] = 'mutated';

      expect((store.entries.single.requestBody as Map)['value'], 'original');
    });
  });
}
