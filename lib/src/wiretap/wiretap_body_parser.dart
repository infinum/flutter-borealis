part of 'wiretap.dart';

/// Renders a request or response body in the **Network** tab.
///
/// Borealis ships parsers for JSON, images, XML and HTML, form data, plain
/// text and raw bytes, and tries them in order until one accepts the body.
/// Implement this to render a format of your own, then pass it through
/// [WiretapConfig.parsers], where it is tried before every built-in parser.
abstract class WiretapBodyParser {
  bool shouldParse(WiretapEntry entry, {required bool forRequest});
  FutureOr<WiretapParsedBody> parse(WiretapEntry entry, {required bool forRequest});
}

/// What a [WiretapBodyParser] produces: the text to show, and how to show it.
///
/// Exactly one of [formattedBody] and [widget] is enough; a parser may supply
/// both, and the detail screen prefers the widget.
class WiretapParsedBody {
  const WiretapParsedBody({this.formattedBody, this.widget})
    : assert((formattedBody != null || widget != null), 'either widget or formattedBody need to be included');

  /// The body rendered as text, ready to show in a monospace block.
  final String? formattedBody;

  /// A richer rendering, for a body that text cannot carry — an image, say.
  final Widget? widget;
}

/// The body parsers Borealis ships with.
///
/// Internal. A [WiretapConfig.parsers] entry is tried before all of these, so
/// an app can render a format of its own without replacing what is here.
abstract final class WiretapBuiltInBodyParsers {
  /// The built-in parsers in priority order — the first one whose
  /// [WiretapBodyParser.shouldParse] returns `true` renders the body, so the
  /// catch-all `_UnknownBodyParser` comes last.
  static const List<WiretapBodyParser> parsers = [
    _ImageBodyParser(),
    _BinaryBodyParser(),
    _JsonBodyParser(),
    _XmlHtmlTextBodyParser(),
    _FormUrlEncodedBodyParser(),
    _UnknownBodyParser(),
  ];
}

class _ImageBodyParser implements WiretapBodyParser {
  const _ImageBodyParser();

  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) {
    final contentType = _normalizedContentType(entry, forRequest: forRequest);
    return contentType?.startsWith('image/') ?? false;
  }

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) {
    final body = forRequest ? entry.requestBody : entry.responseBody;
    final imageWidget = _imageWidgetFromBody(body);

    return WiretapParsedBody(widget: imageWidget, formattedBody: _formatImageBody(body));
  }
}

class _JsonBodyParser implements WiretapBodyParser {
  const _JsonBodyParser();

  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) {
    final contentType = _normalizedContentType(entry, forRequest: forRequest);
    if (contentType == null) {
      return false;
    }
    return contentType.contains('/json') || contentType.contains('+json');
  }

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) {
    return WiretapParsedBody(formattedBody: _formatJsonBody(forRequest ? entry.requestBody : entry.responseBody));
  }
}

class _XmlHtmlTextBodyParser implements WiretapBodyParser {
  const _XmlHtmlTextBodyParser();

  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) {
    final contentType = _normalizedContentType(entry, forRequest: forRequest);
    if (contentType == null) {
      return false;
    }
    return contentType.contains('/xml') ||
        contentType.contains('+xml') ||
        contentType == 'text/html' ||
        contentType.startsWith('text/');
  }

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) {
    return WiretapParsedBody(formattedBody: _stringifyBody(forRequest ? entry.requestBody : entry.responseBody));
  }
}

class _FormUrlEncodedBodyParser implements WiretapBodyParser {
  const _FormUrlEncodedBodyParser();

  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) {
    return _normalizedContentType(entry, forRequest: forRequest) == 'application/x-www-form-urlencoded';
  }

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) {
    return WiretapParsedBody(
      formattedBody: _formatFormUrlEncodedBody(forRequest ? entry.requestBody : entry.responseBody),
    );
  }
}

class _BinaryBodyParser implements WiretapBodyParser {
  const _BinaryBodyParser();
  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) {
    final contentType = _normalizedContentType(entry, forRequest: forRequest);
    if (contentType == null) {
      return false;
    }
    return contentType.startsWith('audio/') ||
        contentType.startsWith('video/') ||
        contentType == 'application/octet-stream' ||
        contentType == 'application/pdf' ||
        contentType == 'application/zip';
  }

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) {
    return WiretapParsedBody(formattedBody: _formatBinaryBody(forRequest ? entry.requestBody : entry.responseBody));
  }
}

class _UnknownBodyParser implements WiretapBodyParser {
  const _UnknownBodyParser();

  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) => true;

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) {
    final body = forRequest ? entry.requestBody : entry.responseBody;

    if (body is List<int>) {
      return WiretapParsedBody(formattedBody: _formatBinaryBody(body));
    }

    return WiretapParsedBody(formattedBody: _formatJsonBody(body));
  }
}

String? _normalizedContentType(WiretapEntry entry, {required bool forRequest}) {
  final header = forRequest
      ? _headerValue(entry.requestHeaders, 'content-type')
      : _headerValue(entry.responseHeaders, 'content-type');

  if (header == null || header.trim().isEmpty) {
    return null;
  }

  return header.split(';').first.trim().toLowerCase();
}

String? _headerValue(Map<String, dynamic>? headers, String key) {
  if (headers == null || headers.isEmpty) {
    return null;
  }

  final lowerKey = key.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() != lowerKey) {
      continue;
    }

    final value = entry.value;
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is List<dynamic>) {
      if (value.isEmpty) {
        return null;
      }
      return value.first?.toString();
    }
    return value.toString();
  }

  return null;
}

String _formatJsonBody(dynamic body) {
  if (body == null) {
    return '';
  }

  // Bytes reach here whenever the caller asked dio for a byte response and the
  // server still labelled it JSON. Encoding them yields an array of one integer
  // per byte, rendered into a single Text widget.
  if (body is List<int>) {
    return _formatBinaryBody(body);
  }

  // Already-encoded JSON. `dio.post(url, data: jsonEncode(payload))` is
  // idiomatic, and encoding that string again produced an escaped one-liner
  // rather than the document the caller sent.
  if (body is String) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
    } catch (_) {
      // Labelled JSON but is not: show the text rather than a quoted version
      // of it.
      return body;
    }
  }

  try {
    return const JsonEncoder.withIndent('  ').convert(body);
  } catch (_) {
    return body.toString();
  }
}

Widget? _imageWidgetFromBody(dynamic body) {
  final bytes = _imageBytesFromBody(body);
  if (bytes == null) {
    return null;
  }

  return Image.memory(bytes, fit: BoxFit.contain, width: double.infinity);
}

Uint8List? _imageBytesFromBody(dynamic body) {
  if (body == null) {
    return null;
  }

  if (body is Uint8List) {
    return body;
  }
  if (body is List<int>) {
    return Uint8List.fromList(body);
  }
  if (body is String) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('data:')) {
      return _decodeDataUrlImagePayload(trimmed);
    }

    final decodedBase64 = _decodeBase64Bytes(trimmed);
    if (decodedBase64 != null) {
      return decodedBase64;
    }

    if (trimmed.contains('%')) {
      return _decodePercentEncodedBytes(trimmed);
    }
  }

  return null;
}

Uint8List? _decodeDataUrlImagePayload(String dataUrl) {
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex <= 5 || commaIndex == dataUrl.length - 1) {
    return null;
  }

  final metadata = dataUrl.substring(5, commaIndex);
  final payload = dataUrl.substring(commaIndex + 1);
  if (payload.isEmpty) {
    return null;
  }

  final metadataParts = metadata.split(';');
  final mediaType = metadataParts.first.toLowerCase();
  if (!mediaType.startsWith('image/')) {
    return null;
  }

  final isBase64 = metadataParts.skip(1).any((part) => part.trim().toLowerCase() == 'base64');

  if (isBase64) {
    return _decodeBase64Bytes(payload);
  }

  return _decodePercentEncodedBytes(payload);
}

Uint8List? _decodeBase64Bytes(String input) {
  final normalized = input.replaceAll(RegExp(r'\s+'), '');
  if (normalized.isEmpty) {
    return null;
  }

  try {
    return base64Decode(normalized);
  } on FormatException {
    final rem = normalized.length % 4;
    final padded = rem == 0 ? normalized : '$normalized${'=' * (4 - rem)}';
    try {
      return base64Url.decode(padded);
    } on FormatException {
      return null;
    }
  }
}

Uint8List _decodePercentEncodedBytes(String input) {
  final bytes = <int>[];
  var i = 0;
  final textBuffer = StringBuffer();

  void flushTextBuffer() {
    if (textBuffer.isEmpty) {
      return;
    }
    bytes.addAll(utf8.encode(textBuffer.toString()));
    textBuffer.clear();
  }

  while (i < input.length) {
    final code = input.codeUnitAt(i);
    if (code == 0x25 && i + 2 < input.length) {
      final hi = _hexValue(input.codeUnitAt(i + 1));
      final lo = _hexValue(input.codeUnitAt(i + 2));
      if (hi >= 0 && lo >= 0) {
        flushTextBuffer();
        bytes.add((hi << 4) + lo);
        i += 3;
        continue;
      }
    }

    textBuffer.writeCharCode(code);
    i++;
  }

  flushTextBuffer();
  return Uint8List.fromList(bytes);
}

int _hexValue(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) {
    return codeUnit - 0x30;
  }
  if (codeUnit >= 0x41 && codeUnit <= 0x46) {
    return codeUnit - 0x41 + 10;
  }
  if (codeUnit >= 0x61 && codeUnit <= 0x66) {
    return codeUnit - 0x61 + 10;
  }
  return -1;
}

String _formatFormUrlEncodedBody(dynamic value) {
  if (value is Map) {
    final normalized = value.map((key, val) => MapEntry(key.toString(), val));
    return const JsonEncoder.withIndent('  ').convert(normalized);
  }

  final raw = _stringifyBody(value);
  if (raw.isEmpty) {
    return raw;
  }

  try {
    final decoded = Uri.splitQueryString(raw);
    if (decoded.isEmpty) {
      return raw;
    }
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } on FormatException {
    return raw;
  }
}

String _formatBinaryBody(dynamic value) {
  if (value is List<int>) {
    return '<binary payload: ${value.length} bytes>';
  }
  return '<binary payload>';
}

String _formatImageBody(dynamic value) {
  if (value is List<int>) {
    return '<image payload: ${value.length} bytes>';
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('data:image/')) {
      return '<image payload: data URL>';
    }
    return '<image payload: base64/text>';
  }
  return '<image payload>';
}

String _stringifyBody(dynamic value) {
  if (value is String) {
    return value;
  }
  if (value is List<int>) {
    try {
      return utf8.decode(value);
    } catch (_) {
      return _formatBinaryBody(value);
    }
  }
  return value.toString();
}
