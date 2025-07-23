import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:rdf_xml/src/implementations/parsing_impl.dart';

final _log = Logger('URI Resolution Test');
void main() {
  group('URI Resolution RFC 3986 Compliance', () {
    late DefaultUriResolver resolver;

    setUp(() {
      resolver = DefaultUriResolver();
    });

    test('fragment identifier resolution with base URI ending in #', () {
      // According to RFC 3986, when resolving 'foo' against 'http://my.host/path#'
      // the result should be 'http://my.host/foo', NOT 'http://my.host/path#foo'
      final baseUri = 'http://my.host/path#';
      final relativeUri = 'foo';

      final result = resolver.resolveUri(relativeUri, baseUri);

      _log.info('Base URI: $baseUri');
      _log.info('Relative URI: $relativeUri');
      _log.info('Resolved result: $result');

      // This should NOT be 'http://my.host/path#foo'
      expect(result, isNot(equals('http://my.host/path#foo')));

      // According to RFC 3986, it should be 'http://my.host/foo'
      expect(result, equals('http://my.host/foo'));
    });

    test('fragment identifier resolution with standard base URI', () {
      final baseUri = 'http://my.host/path/';
      final relativeUri = 'foo';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/path/foo'));
    });

    test('relative fragment resolution', () {
      final baseUri = 'http://my.host/path';
      final relativeUri = '#fragment';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/path#fragment'));
    });

    test('absolute URI should pass through unchanged', () {
      final baseUri = 'http://my.host/path#';
      final absoluteUri = 'https://other.host/resource';

      final result = resolver.resolveUri(absoluteUri, baseUri);
      expect(result, equals('https://other.host/resource'));
    });

    test('non-URI scheme identifiers should pass through unchanged', () {
      final baseUri = 'http://my.host/path#';
      final nonUriIdentifier = 'isbn:123456789';

      final result = resolver.resolveUri(nonUriIdentifier, baseUri);
      expect(result, equals('isbn:123456789'));
    });

    test('complex base URI with query and fragment', () {
      final baseUri = 'http://my.host/path/file.html?query=value#fragment';
      final relativeUri = 'other.html';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/path/other.html'));
    });

    test('relative path with dots', () {
      final baseUri = 'http://my.host/path/subpath/';
      final relativeUri = '../other.html';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/path/other.html'));
    });

    test('absolute path resolution', () {
      final baseUri = 'http://my.host/path/subpath/';
      final relativeUri = '/newpath/file.html';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/newpath/file.html'));
    });

    test('query-only relative URI', () {
      final baseUri = 'http://my.host/path/file.html';
      final relativeUri = '?newquery=value';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/path/file.html?newquery=value'));
    });

    test('empty relative URI should resolve to base without fragment', () {
      final baseUri = 'http://my.host/path/file.html#fragment';
      final relativeUri = '';

      final result = resolver.resolveUri(relativeUri, baseUri);
      expect(result, equals('http://my.host/path/file.html'));
    });

    test('various scheme identifiers correctly identified as absolute', () {
      final baseUri = 'http://my.host/path';

      final schemes = [
        'http://example.com',
        'https://example.com',
        'ftp://example.com',
        'file:///path/to/file',
        'mailto:user@example.com',
        'urn:isbn:123456789',
        'doi:10.1000/123456',
        'data:text/plain;base64,SGVsbG8=',
      ];

      for (final scheme in schemes) {
        final result = resolver.resolveUri(scheme, baseUri);
        expect(
          result,
          equals(scheme),
          reason: 'Scheme $scheme should remain unchanged',
        );
      }
    });
  });
}
