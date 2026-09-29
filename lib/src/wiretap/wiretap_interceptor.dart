part of 'wiretap.dart';

const _entryIdKey = 'wiretap_entry_id';

const _entryIdCharset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

// Seeded once; a fresh Random per request is both slower and pointless here.
final Random _entryIdRandom = Random();

/// An opaque id correlating a captured request with its response.
///
/// Lives beside its only caller rather than in a `RandomUtils` of its own.
String _generateEntryId() =>
    List.generate(16, (_) => _entryIdCharset[_entryIdRandom.nextInt(_entryIdCharset.length)], growable: false).join();

/// A [Dio] interceptor that records every request and response into a
/// [WiretapStore].
///
/// Add it to any [Dio] instance to start capturing network traffic:
///
/// ```dart
/// dio.interceptors.add(WiretapInterceptor());
/// ```
///
/// By default it writes to the shared [WiretapStore.instance]. Pass a
/// custom [store] if you need an isolated log (e.g. when using multiple [Dio]
/// clients):
///
/// ```dart
/// final store = WiretapStore();
/// dio.interceptors.add(WiretapInterceptor(store: store));
/// ```
///
/// Sensitive headers are masked before they reach the store — see
/// [defaultRedactedHeaders] and the [WiretapInterceptor.new] `redactHeaders`
/// parameter.
class WiretapInterceptor extends Interceptor {
  /// Captures into [store], defaulting to [WiretapStore.instance].
  ///
  /// [redactHeaders] names the headers whose values are replaced with
  /// [redactedValue] before capture, matched case-insensitively and defaulting
  /// to [defaultRedactedHeaders]. Pass an empty set to capture every header
  /// verbatim.
  ///
  /// [redactBodyKeys] does the same for keys inside request and response
  /// bodies. It is empty by default, because a key name that is a credential
  /// in one API is ordinary data in another — see [defaultRedactedHeaders] for
  /// why headers can carry a default and bodies cannot.
  WiretapInterceptor({WiretapStore? store, Set<String>? redactHeaders, Set<String>? redactBodyKeys})
    : _store = store ?? WiretapStore.instance,
      _redactedHeaders = {for (final header in redactHeaders ?? defaultRedactedHeaders) header.toLowerCase()},
      _redactedBodyKeys = {for (final key in redactBodyKeys ?? const <String>{}) key.toLowerCase()};

  /// Headers masked unless the caller says otherwise: the ones that carry
  /// credentials on essentially every API.
  ///
  /// Masking happens at capture. The masked map is the one the detail screen,
  /// the cURL export and the log file export read, and Borealis never restores
  /// the original, so a build that masks cannot reveal a token later.
  ///
  /// Three limits are worth knowing.
  ///
  /// Beyond headers, Borealis masks only the body keys named in
  /// `redactBodyKeys`, inside maps and lists. An oversized string body is
  /// truncated at [maxCapturedBodyChars] and an oversized byte body is
  /// replaced with a size marker at [maxCapturedBodyBytes], but `FormData` and
  /// any other body that is not a map or list are kept as received. A token in
  /// the URL or in a query parameter is captured in full.
  ///
  /// On a failed request [WiretapEntry.error] holds the original
  /// [DioException], which still references the unmasked
  /// `requestOptions.headers` and `response.headers`. Borealis itself never
  /// reads those maps, but code that walks the exception reaches them.
  ///
  /// The detail screen and the log file export render that exception through
  /// `error.toString()`, and dio decides what that string holds. Today it
  /// covers the type, the message and the nested cause. An app can replace it
  /// for every exception through `DioException.readableStringBuilder`, so
  /// Borealis cannot promise that the rendered text omits a credential.
  static const Set<String> defaultRedactedHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };

  /// Stands in for a redacted header value. A marker rather than an empty
  /// string, so the header's presence stays visible.
  static const String redactedValue = '<redacted>';

  /// The largest binary body captured whole, in bytes.
  ///
  /// The store bounds how many entries it holds, not how large they are, and a
  /// captured body is held by the entry for as long as the entry lives. Without
  /// a cap, a debug session against an image or file endpoint retains every
  /// payload it saw. A body past the cap is replaced by a marker that keeps its
  /// real size visible.
  ///
  /// A decoded JSON body arrives as a `Map` or `List` whose size cannot be
  /// measured without walking it, so it is captured whole.
  static const int maxCapturedBodyBytes = 512 * 1024;

  /// The largest text body captured whole, in UTF-16 code units.
  ///
  /// Counted separately from [maxCapturedBodyBytes] because the two diverge for
  /// any non-ASCII payload, and one constant compared against both made the
  /// effective cap depend on the alphabet.
  static const int maxCapturedBodyChars = 512 * 1024;

  final WiretapStore _store;

  /// Lower-cased, so lookups match whatever casing the server or the caller
  /// used.
  final Set<String> _redactedHeaders;

  /// Lower-cased, for the same reason as [_redactedHeaders].
  final Set<String> _redactedBodyKeys;

  /// Snapshots [headers], masking the value of every redacted entry.
  ///
  /// Always copies, even when nothing matches. The response maps arrive
  /// straight from dio and stay mutable, so an interceptor that runs after
  /// this one could otherwise rewrite what the store already recorded — the
  /// panel would then show headers that were never on the wire.
  Map<String, dynamic> _redact(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: _redactedHeaders.contains(entry.key.toLowerCase()) ? redactedValue : _detach(entry.value),
    };
  }

  /// Copies a header value that would otherwise stay shared with dio.
  ///
  /// `Headers.add` appends to the existing list in place, so copying the map
  /// alone leaves multi-value headers open to later mutation. The `List<String>`
  /// case is kept separate to preserve the element type dio hands us.
  static Object? _detach(Object? value) {
    if (value is List<String>) return List<String>.of(value);
    if (value is List) return List<Object?>.of(value);
    return value;
  }

  /// Snapshots [body] for the store: masks every key named in
  /// [_redactedBodyKeys], replaces an oversized payload with a
  /// marker (see [maxCapturedBodyBytes] and [maxCapturedBodyChars]), and copies
  /// the containers on the way through.
  ///
  /// The copy matters for the same reason it does for headers: dio hands over
  /// the caller's own object, so a request map mutated after `dio.post`
  /// returns would otherwise rewrite what the panel already recorded.
  ///
  /// Masking descends through maps and lists, because a token is as likely to
  /// sit under `data` or in the first element of a list as at the top level.
  Object? _captureBody(Object? body) {
    // Before the generic List branch: a byte payload is data, not structure,
    // and walking it per element would be both pointless and slow.
    if (body is List<int>) {
      if (body.length > maxCapturedBodyBytes) return '<${body.length} bytes not captured>';
      return List<int>.of(body);
    }

    if (body is String) {
      if (body.length <= maxCapturedBodyChars) return body;
      return '${body.substring(0, maxCapturedBodyChars)}\n'
          '<truncated: kept $maxCapturedBodyChars of ${body.length} characters>';
    }

    if (body is Map) {
      return {
        for (final entry in body.entries)
          entry.key: _redactedBodyKeys.contains(entry.key.toString().toLowerCase())
              ? redactedValue
              : _captureBody(entry.value),
      };
    }

    if (body is List) return [for (final value in body) _captureBody(value)];

    // FormData, a stream, a custom object: nothing to walk and nothing safe to
    // copy, so it is stored as dio handed it over.
    return body;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final id = _generateEntryId();
    final entry = WiretapEntry(
      id: id,
      method: options.method,
      uri: options.uri,
      requestHeaders: _redact(Map<String, dynamic>.from(options.headers)),
      requestBody: _captureBody(options.data),
      timestamp: DateTime.now(),
      isLoading: true,
    );
    options.extra[_entryIdKey] = id;
    _store.add(entry);
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final id = response.requestOptions.extra[_entryIdKey] as String?;
    if (id != null) {
      final entry = _store[id];
      if (entry != null) {
        final updatedEntry = entry.copyWith(
          statusCode: response.statusCode,
          responseHeaders: _redact(response.headers.map),
          responseBody: _captureBody(response.data),
          responseTimestamp: DateTime.now(),
          isLoading: false,
        );
        _store.update(updatedEntry);
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final id = err.requestOptions.extra[_entryIdKey] as String?;
    if (id != null) {
      final entry = _store[id];
      if (entry != null) {
        final responseHeaders = err.response?.headers.map;
        final updatedEntry = entry.copyWith(
          statusCode: err.response?.statusCode,
          responseHeaders: responseHeaders == null ? null : _redact(responseHeaders),
          responseBody: _captureBody(err.response?.data),
          responseTimestamp: DateTime.now(),
          error: err,
          isLoading: false,
        );
        _store.update(updatedEntry);
      }
    }
    handler.next(err);
  }
}
