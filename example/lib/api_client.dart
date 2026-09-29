import 'package:borealis/borealis.dart';
import 'package:dio/dio.dart';
import 'package:loggy/loggy.dart';

mixin ApiLoggy implements LoggyType {
  @override
  Loggy<ApiLoggy> get loggy => Loggy<ApiLoggy>('Api($runtimeType)');
}

/// A single demo request. The screen and the debug panel both build their
/// entries from this list.
class ApiCall {
  const ApiCall({required this.label, required this.description, required this.send});

  final String label;
  final String description;
  final Future<Response<dynamic>> Function() send;
}

/// Sample API client hitting a public test API.
///
/// [Borealis.initNetworkLogger] attaches the wiretap interceptor to this Dio
/// instance, so every request below shows up in the **Network** tab of the
/// debug panel.
class ExampleApi with ApiLoggy {
  ExampleApi() {
    Borealis.initNetworkLogger(dio, requestHeader: true, requestBody: true, responseHeader: true);
  }

  static final ExampleApi instance = ExampleApi();

  /// Builds the shared client, which attaches the Borealis network logger.
  static void init() {
    instance.loggy.info('Example API ready — ${instance.dio.options.baseUrl}');
  }

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'X-Borealis-Demo': 'example-app'},
    ),
  );

  late final List<ApiCall> calls = [
    ApiCall(label: 'GET /posts', description: 'Big JSON list — 100 posts', send: () => dio.get<dynamic>('/posts')),
    ApiCall(label: 'GET /posts/1', description: 'Single object response', send: () => dio.get<dynamic>('/posts/1')),
    ApiCall(
      label: 'GET /comments?postId=1',
      description: 'Query parameters',
      send: () => dio.get<dynamic>('/comments', queryParameters: {'postId': 1}),
    ),
    ApiCall(
      label: 'POST /posts',
      description: 'Request body — 201 Created',
      send: () =>
          dio.post<dynamic>('/posts', data: {'title': 'Borealis', 'body': 'Sent from the example app', 'userId': 1}),
    ),
    ApiCall(
      label: 'PUT /posts/1',
      description: 'Update with a request body',
      send: () => dio.put<dynamic>('/posts/1', data: {'id': 1, 'title': 'Updated title', 'userId': 1}),
    ),
    ApiCall(label: 'DELETE /posts/1', description: 'Empty response body', send: () => dio.delete<dynamic>('/posts/1')),
    ApiCall(label: 'GET /posts/9999', description: 'Client error — 404', send: () => dio.get<dynamic>('/posts/9999')),
    ApiCall(
      label: 'GET httpbin /status/500',
      description: 'Server error — 500',
      send: () => dio.get<dynamic>('https://httpbin.org/status/500'),
    ),
    ApiCall(
      label: 'GET httpbin /delay/3',
      description: 'Slow request — 3s duration',
      send: () => dio.get<dynamic>('https://httpbin.org/delay/3'),
    ),
    ApiCall(
      label: 'GET borealis.invalid',
      description: 'Connection failure — no response',
      send: () => dio.get<dynamic>('https://borealis.invalid/ping'),
    ),
  ];

  /// Sends [call]. Errors are swallowed on purpose — the point is to get them
  /// into the wiretap log, not to crash the demo. Inspect the result in the
  /// **Network** tab.
  Future<void> run(ApiCall call) async {
    loggy.info('Sending ${call.label}');

    try {
      await call.send();
    } on DioException catch (error) {
      loggy.warning('${call.label} failed: ${error.type.name}');
    }
  }

  /// Fires every demo request.
  Future<void> runAll() => Future.wait(calls.map(run));
}
