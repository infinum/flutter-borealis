part of 'wiretap.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first

/// Color that represents [statusCode], shared by the request list chip and
/// the gamify popup so both render the same status the same way.
Color wiretapStatusColor(int? statusCode) {
  if (statusCode == null) return Colors.grey;
  if (statusCode >= 200 && statusCode < 300) return Colors.green;
  if (statusCode >= 300 && statusCode < 400) return Colors.blue;
  if (statusCode >= 400 && statusCode < 500) return Colors.orange;
  if (statusCode >= 500) return Colors.red;
  return Colors.grey;
}

/// One captured request and its response.
///
/// [WiretapInterceptor] creates an entry on the request and updates it when the
/// response or the error arrives, so [isLoading] is `true` until the call ends.
/// The header maps are snapshots taken at capture, with credential headers
/// already masked.
///
/// This is what [WiretapConfig.onExport] and a custom [WiretapBodyParser] work
/// with, so its fields are public.
class WiretapEntry {
  const WiretapEntry({
    required this.id,
    required this.method,
    required this.uri,
    required this.requestHeaders,
    required this.requestBody,
    required this.timestamp,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseTimestamp,
    this.error,
    this.isLoading = true,
  });

  final String id;
  final String method;
  final Uri uri;
  final Map<String, dynamic> requestHeaders;
  final dynamic requestBody;
  final DateTime timestamp;

  final DateTime? responseTimestamp;
  final int? statusCode;
  final Map<String, dynamic>? responseHeaders;
  final dynamic responseBody;
  final Object? error;
  final bool isLoading;

  Map<String, String> get prettyRequestHeaders =>
      Map<String, String>.fromEntries(requestHeaders.entries.map((e) => MapEntry(e.key, _prettyDynamic(e.value))));

  Map<String, String>? get prettyResponseHeaders => responseHeaders != null
      ? Map<String, String>.fromEntries(responseHeaders!.entries.map((e) => MapEntry(e.key, _prettyDynamic(e.value))))
      : null;

  Duration? get duration => responseTimestamp?.difference(timestamp);

  String get path {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
    return '$path$query';
  }

  /// Whether this entry matches a search [query], case-insensitively.
  ///
  /// Matched against [path] — the path and query string, which is what the
  /// request list shows and what the search field offers. Deliberately not the
  /// whole URL: matching the scheme and host meant typing `https` selected
  /// every captured request.
  bool matches(String query) => path.toLowerCase().contains(query.toLowerCase());

  static String _prettyDynamic(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is List<dynamic>) {
      return value.map(_prettyDynamic).join(', ');
    }

    if (value is String) {
      return value;
    }

    return value.toString();
  }

  WiretapEntry copyWith({
    String? id,
    String? method,
    Uri? uri,
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    DateTime? timestamp,
    DateTime? responseTimestamp,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
    dynamic responseBody,
    Object? error,
    bool? isLoading,
  }) {
    return WiretapEntry(
      id: id ?? this.id,
      method: method ?? this.method,
      uri: uri ?? this.uri,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      timestamp: timestamp ?? this.timestamp,
      responseTimestamp: responseTimestamp ?? this.responseTimestamp,
      statusCode: statusCode ?? this.statusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WiretapEntry) return false;

    return other.id == id &&
        other.method == method &&
        other.uri == uri &&
        mapEquals(other.requestHeaders, requestHeaders) &&
        other.requestBody == requestBody &&
        other.timestamp == timestamp &&
        other.responseTimestamp == responseTimestamp &&
        other.statusCode == statusCode &&
        mapEquals(other.responseHeaders, responseHeaders) &&
        other.responseBody == responseBody &&
        other.error == error &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode => Object.hash(
    id,
    method,
    uri,
    _headersHash(requestHeaders),
    requestBody,
    timestamp,
    responseTimestamp,
    statusCode,
    _headersHash(responseHeaders),
    responseBody,
    error,
    isLoading,
  );

  /// Order-independent hash of a header map, matching how [==] compares them
  /// with [mapEquals].
  static int _headersHash(Map<String, dynamic>? headers) =>
      headers == null ? 0 : Object.hashAllUnordered(headers.entries.map((e) => Object.hash(e.key, e.value)));
}
