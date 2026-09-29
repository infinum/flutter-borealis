import 'dart:typed_data';

import 'package:borealis/borealis.dart';
import 'package:dio/dio.dart';
import 'package:flutter_loggy_dio/flutter_loggy_dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request from memory so the interceptors run against a real
/// Dio pipeline without touching the network.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter({this.body = '{}'});

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: const ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _wired(WiretapStore store, {Set<String>? redactHeaders, Set<String>? redactBodyKeys, String body = '{}'}) {
  final dio = Dio();
  Borealis.initNetworkLogger(dio, wiretapStore: store, redactHeaders: redactHeaders, redactBodyKeys: redactBodyKeys);
  return dio..httpClientAdapter = _CannedAdapter(body: body);
}

void main() {
  group('Borealis.initNetworkLogger', () {
    test('attaches the wiretap interceptor and the Loggy one', () {
      final dio = Dio();

      Borealis.initNetworkLogger(dio);

      expect(dio.interceptors.whereType<WiretapInterceptor>(), hasLength(1));
      expect(dio.interceptors.whereType<LoggyDioInterceptor>(), hasLength(1));
    });

    test('a second call replaces its own interceptors rather than stacking them', () {
      final dio = Dio();

      Borealis.initNetworkLogger(dio);
      Borealis.initNetworkLogger(dio);

      expect(dio.interceptors.whereType<WiretapInterceptor>(), hasLength(1));
      expect(dio.interceptors.whereType<LoggyDioInterceptor>(), hasLength(1));
    });

    test('captures into the store it is given', () async {
      final store = WiretapStore();

      await _wired(store).get<dynamic>('https://api.example.com/users');

      expect(store.entries.single.uri.path, '/users');
    });

    test('forwards redactHeaders to the interceptor', () async {
      final store = WiretapStore();

      await _wired(
        store,
        redactHeaders: {'x-session'},
      ).get<dynamic>('https://api.example.com/users', options: Options(headers: {'x-session': 'secret-session'}));

      expect(store.entries.single.requestHeaders['x-session'], WiretapInterceptor.redactedValue);
    });

    test('forwards redactBodyKeys to the interceptor', () async {
      final store = WiretapStore();

      await _wired(
        store,
        redactBodyKeys: {'access_token'},
        body: '{"access_token":"secret-token"}',
      ).post<dynamic>('https://api.example.com/token', data: {'access_token': 'secret-request-token'});

      final entry = store.entries.single;
      expect((entry.requestBody as Map)['access_token'], WiretapInterceptor.redactedValue);
      expect((entry.responseBody as Map)['access_token'], WiretapInterceptor.redactedValue);
    });
  });
}
