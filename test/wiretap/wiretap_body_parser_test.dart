import 'dart:convert';
import 'dart:typed_data';

import 'package:borealis/src/wiretap/wiretap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parsers = WiretapBuiltInBodyParsers.parsers;

  group('WiretapBuiltInBodyParsers', () {
    test('exposes six default parsers', () {
      expect(parsers, hasLength(6));
    });
  });

  group('_ImageBodyParser (via pipeline)', () {
    test('matches image/* and formats byte body', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final e = _entry(responseHeaders: {'content-type': 'image/png'}, responseBody: bytes);
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_ImageBodyParser');
      expect(c.widget, isNotNull);
      expect(c.formattedBody, '<image payload: 4 bytes>');
    });

    test('normalizes content-type with charset', () async {
      final e = _entry(responseHeaders: {'content-type': 'image/jpeg; charset=binary'}, responseBody: Uint8List(0));
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_ImageBodyParser');
      expect(c.widget, isNotNull);
    });

    test('data URL image payload sets formattedBody hint', () async {
      final e = _entry(responseHeaders: {'content-type': 'image/png'}, responseBody: 'data:image/png;base64,AA==');
      final c = await _parse(e, forRequest: false);
      expect(c.formattedBody, '<image payload: data URL>');
      expect(c.widget, isNotNull);
    });
  });

  group('_JsonBodyParser (via pipeline)', () {
    test('matches application/json and pretty-prints map body', () async {
      final e = _entry(
        responseHeaders: {'content-type': 'application/json'},
        responseBody: <String, dynamic>{'a': 1, 'b': 'x'},
      );
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_JsonBodyParser');
      expect(c.widget, isNull);
      expect(c.formattedBody, contains('"a"'));
      expect(c.formattedBody, contains('1'));
      expect(c.formattedBody, contains('"x"'));
    });

    test('matches vendor +json subtype', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/vnd.api+json'}, responseBody: {'ok': true});
      expect(_parserFor(e, forRequest: false), '_JsonBodyParser');
    });

    test('matches Content-Type header provided as list', () async {
      final e = _entry(
        responseHeaders: {
          'content-type': <String>['application/json; charset=utf-8'],
        },
        responseBody: [1, 2, 3],
      );
      expect(_parserFor(e, forRequest: false), '_JsonBodyParser');
    });

    test('uses request headers when forRequest is true', () async {
      final e = _entry(requestHeaders: {'content-type': 'application/json'}, requestBody: {'method': 'POST'});
      final c = await _parse(e, forRequest: true);
      expect(_parserFor(e, forRequest: true), '_JsonBodyParser');
      expect(c.formattedBody, contains('POST'));
    });
  });

  group('_XmlHtmlTextBodyParser (via pipeline)', () {
    test('application/xml label and raw string body', () async {
      const xml = '<root/>';
      final e = _entry(responseHeaders: {'content-type': 'application/xml'}, responseBody: xml);
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_XmlHtmlTextBodyParser');
      expect(c.formattedBody, xml);
    });

    test('application/atom+xml maps to application/xml label', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/atom+xml'}, responseBody: '<feed/>');
      expect(_parserFor(e, forRequest: false), '_XmlHtmlTextBodyParser');
    });

    test('text/xml uses application/xml label', () async {
      final e = _entry(responseHeaders: {'content-type': 'text/xml'}, responseBody: '<a/>');
      expect(_parserFor(e, forRequest: false), '_XmlHtmlTextBodyParser');
    });

    test('text/html', () async {
      final e = _entry(responseHeaders: {'content-type': 'text/html'}, responseBody: '<p>hi</p>');
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_XmlHtmlTextBodyParser');
      expect(c.formattedBody, '<p>hi</p>');
    });

    test('text/plain uses text/* label', () async {
      final e = _entry(responseHeaders: {'content-type': 'text/plain'}, responseBody: 'plain');
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_XmlHtmlTextBodyParser');
      expect(c.formattedBody, 'plain');
    });

    test('decodes UTF-8 from bytes', () async {
      final e = _entry(responseHeaders: {'content-type': 'text/plain'}, responseBody: utf8.encode('čćž'));
      final c = await _parse(e, forRequest: false);
      expect(c.formattedBody, 'čćž');
    });
  });

  group('_FormUrlEncodedBodyParser (via pipeline)', () {
    test('pretty-prints split query string from request body', () async {
      final e = _entry(requestHeaders: {'content-type': 'application/x-www-form-urlencoded'}, requestBody: 'a=1&b=two');
      final c = await _parse(e, forRequest: true);
      expect(_parserFor(e, forRequest: true), '_FormUrlEncodedBodyParser');
      expect(c.formattedBody, contains('"a"'));
      expect(c.formattedBody, contains('1'));
      expect(c.formattedBody, contains('two'));
    });

    test('map body is JSON-encoded', () async {
      final e = _entry(
        requestHeaders: {'content-type': 'application/x-www-form-urlencoded'},
        requestBody: <String, String>{'x': 'y'},
      );
      final c = await _parse(e, forRequest: true);
      expect(c.formattedBody, contains('"x"'));
      expect(c.formattedBody, contains('"y"'));
    });
  });

  group('_BinaryBodyParser (via pipeline)', () {
    test('application/octet-stream', () async {
      final raw = Uint8List.fromList([0, 255]);
      final e = _entry(responseHeaders: {'content-type': 'application/octet-stream'}, responseBody: raw);
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_BinaryBodyParser');
      expect(c.formattedBody, '<binary payload: 2 bytes>');
    });

    test('application/pdf', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/pdf'}, responseBody: Uint8List(10));
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_BinaryBodyParser');
      expect(c.formattedBody, '<binary payload: 10 bytes>');
    });

    test('audio and video types', () async {
      for (final type in ['audio/wav', 'video/mp4']) {
        final e = _entry(responseHeaders: {'content-type': type}, responseBody: Uint8List(1));
        expect(_parserFor(e, forRequest: false), '_BinaryBodyParser', reason: type);
      }
    });

    test('application/zip', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/zip'}, responseBody: Uint8List(0));
      expect(_parserFor(e, forRequest: false), '_BinaryBodyParser');
    });
  });

  group('_UnknownBodyParser (via pipeline)', () {
    test('shows a plain string body as text rather than as a quoted JSON string', () async {
      final e = _entry(responseBody: 'not json');
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_UnknownBodyParser');
      expect(c.formattedBody, 'not json');
    });

    test('byte body shows size', () async {
      final e = _entry(responseBody: Uint8List.fromList([0, 1, 2]));
      final c = await _parse(e, forRequest: false);
      expect(_parserFor(e, forRequest: false), '_UnknownBodyParser');
      expect(c.formattedBody, '<binary payload: 3 bytes>');
    });

    test('invalid UTF-8 bytes fall back to binary message', () async {
      final e = _entry(responseBody: Uint8List.fromList([0xFF, 0xFE, 0xFD]));
      final c = await _parse(e, forRequest: false);
      expect(c.formattedBody, '<binary payload: 3 bytes>');
    });
  });

  group('a broken parser does not blank the body', () {
    test('a throwing shouldParse falls through to the next parser', () async {
      final body = await WiretapExportUtils.buildBodyContentWithParsers(
        entry: _entry(responseHeaders: {'content-type': 'application/json'}, responseBody: {'k': 'v'}),
        forRequest: false,
        parsers: [const _ThrowingShouldParse(), ...WiretapBuiltInBodyParsers.parsers],
      );

      expect(body.formattedBody, contains('"k": "v"'), reason: 'the parsers after the throwing one still run');
    });

    test('a throwing shouldParse still leaves the raw-body fallback', () async {
      final body = await WiretapExportUtils.buildBodyContentWithParsers(
        entry: _entry(responseBody: 'raw'),
        forRequest: false,
        parsers: const [_ThrowingShouldParse()],
      );

      expect(body.formattedBody, 'raw');
    });
  });

  group('parser order / precedence', () {
    test('image/ wins over other types when listed as image', () async {
      final e = _entry(responseHeaders: {'content-type': 'image/png'}, responseBody: Uint8List.fromList([7]));
      final c = await _parse(e, forRequest: false);
      expect(c.widget, isNotNull);
      expect(_parserFor(e, forRequest: false), '_ImageBodyParser');
    });

    test('json wins over text/* for application/json', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/json'}, responseBody: {'k': 'v'});
      expect(_parserFor(e, forRequest: false), '_JsonBodyParser');
    });
  });

  group('json bodies that are not decoded maps', () {
    test('a byte body with a JSON content type is described, not rendered as integers', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/json'}, responseBody: List<int>.filled(2048, 65));

      final c = await _parse(e, forRequest: false);

      expect(c.formattedBody, isNot(contains('65')), reason: 'a byte array must not be printed element by element');
      expect(c.formattedBody, contains('2048'));
    });

    test('a pre-encoded JSON string is pretty-printed rather than escaped', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/json'}, responseBody: '{"a":1,"b":{"c":2}}');

      final c = await _parse(e, forRequest: false);

      expect(c.formattedBody, isNot(startsWith('"')), reason: 'the string must be decoded, not re-encoded');
      expect(c.formattedBody, contains('"c": 2'));
    });

    test('a string that is not JSON at all is left as it is', () async {
      final e = _entry(responseHeaders: {'content-type': 'application/json'}, responseBody: 'not json');

      final c = await _parse(e, forRequest: false);

      expect(c.formattedBody, 'not json');
    });
  });
}

/// A parser that blows up while deciding whether it applies. The pipeline has
/// to survive it: the parsers after it, and the raw-body fallback, still run.
class _ThrowingShouldParse implements WiretapBodyParser {
  const _ThrowingShouldParse();

  @override
  bool shouldParse(WiretapEntry entry, {required bool forRequest}) => throw StateError('boom');

  @override
  WiretapParsedBody parse(WiretapEntry entry, {required bool forRequest}) =>
      const WiretapParsedBody(formattedBody: 'never');
}

WiretapEntry _entry({
  Map<String, dynamic> requestHeaders = const {},
  dynamic requestBody,
  Map<String, dynamic>? responseHeaders,
  dynamic responseBody,
}) {
  return WiretapEntry(
    id: 't1',
    method: 'GET',
    uri: Uri.parse('https://example.com/path'),
    requestHeaders: requestHeaders,
    requestBody: requestBody,
    timestamp: DateTime.utc(2024, 1, 1),
    responseHeaders: responseHeaders,
    responseBody: responseBody,
    isLoading: false,
  );
}

Future<WiretapParsedBody> _parse(WiretapEntry entry, {required bool forRequest}) {
  return WiretapExportUtils.buildBodyContentWithParsers(
    entry: entry,
    forRequest: forRequest,
    parsers: WiretapBuiltInBodyParsers.parsers,
  );
}

/// The built-in parser that claims [entry].
///
/// `WiretapParsedBody` no longer carries a label, so parser selection is
/// asserted here directly rather than through a field the UI never read.
String _parserFor(WiretapEntry entry, {required bool forRequest}) {
  return WiretapBuiltInBodyParsers.parsers
      .firstWhere((parser) => parser.shouldParse(entry, forRequest: forRequest))
      .runtimeType
      .toString();
}
