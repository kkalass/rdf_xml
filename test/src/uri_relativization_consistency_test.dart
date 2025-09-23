import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

final _log = Logger('uri_relativization_consistency_test');
void main() {
  group('URI Relativization and Resolution RFC 3986 Compliance Tests', () {
    late RdfXmlCodec codec;

    setUp(() {
      codec = RdfXmlCodec(
        encoderOptions: RdfXmlEncoderOptions(
          iriRelativization: IriRelativizationOptions.full().copyWith(
            allowAbsolutePath: false,
          ),
        ),
      );
    });

    test('roundtrip consistency: base URI ending with fragment', () {
      // This test verifies that encoding and decoding are consistent
      final baseUri = 'http://my.host/path#';

      // Create a graph with an IRI that should be correctly relativized to 'foo'
      // when encoding, and correctly resolved back to 'http://my.host/foo' when decoding
      final graph = RdfGraph.fromTriples([
        Triple(
          const IriTerm(
            'http://my.host/foo',
          ), // This should be what we get after resolving 'foo'
          const IriTerm('http://example.org/title'),
          LiteralTerm.string('Test Resource'),
        ),
      ]);

      // Encode with the same base URI
      final encodedXml = codec.encode(graph, baseUri: baseUri);
      _log.info('Encoded XML:\n$encodedXml');

      // Decode it back
      final decodedGraph = codec.decode(encodedXml);
      final decodedTriples = decodedGraph.triples.toList();

      expect(decodedTriples, hasLength(1));
      final subject = decodedTriples[0].subject as IriTerm;

      _log.info('Original IRI: http://my.host/foo');
      _log.info('Decoded IRI:  ${subject.value}');

      // This should work correctly with consistent relativization
      expect(subject.value, equals('http://my.host/foo'));
    });

    test('RFC 3986 compliant relativization with fragment base URI', () {
      // Test the specific case: relativizing against a base URI with fragment
      final baseUri = 'http://my.host/path#';

      final graph = RdfGraph.fromTriples([
        Triple(
          const IriTerm(
            'http://my.host/foo',
          ), // This should relativize to 'foo'
          const IriTerm('http://example.org/title'),
          LiteralTerm.string('Should be relativized to foo'),
        ),
      ]);

      final encodedXml = codec.encode(graph, baseUri: baseUri);
      _log.info('Encoded XML with fragment base:\n$encodedXml');

      // According to RFC 3986, this should create 'foo' as relative URI
      // because resolving 'foo' against 'http://my.host/path#' gives 'http://my.host/foo'
      expect(encodedXml, contains('rdf:about="foo"'));

      // Verify roundtrip
      final decodedGraph = codec.decode(encodedXml, documentUrl: baseUri);
      final decodedTriples = decodedGraph.triples.toList();
      final subject = decodedTriples[0].subject as IriTerm;
      expect(subject.value, equals('http://my.host/foo'));
    });

    test('Fragment-only relativization optimization', () {
      // Test optimal relativization when only the fragment differs
      final baseUri = 'http://my.host/path#';

      // This URI differs only by fragment and should be relativized to just #foo
      final graph = RdfGraph.fromTriples([
        Triple(
          const IriTerm('http://my.host/path#foo'),
          const IriTerm('http://example.org/title'),
          LiteralTerm.string('Should be relativized to #foo'),
        ),
      ]);

      final encodedXml = codec.encode(graph, baseUri: baseUri);
      _log.info('Encoded XML with fragment-only difference:\n$encodedXml');

      // According to RFC 3986, this should create '#foo' as relative URI
      // because resolving '#foo' against 'http://my.host/path#' gives 'http://my.host/path#foo'
      expect(encodedXml, contains('rdf:about="#foo"'));

      // Verify roundtrip
      final decodedGraph = codec.decode(encodedXml, documentUrl: baseUri);
      final decodedTriples = decodedGraph.triples.toList();
      final subject = decodedTriples[0].subject as IriTerm;
      expect(subject.value, equals('http://my.host/path#foo'));
    });

    test('proper relativization examples', () {
      // Test various relativization scenarios to ensure correct behavior
      final baseUri = 'http://my.host/path/';

      final graph = RdfGraph.fromTriples([
        Triple(
          const IriTerm('http://my.host/path/subresource'),
          const IriTerm('http://example.org/title'),
          LiteralTerm.string('Sub Resource'),
        ),
        Triple(
          const IriTerm('http://my.host/other'), // Should also be relativized
          const IriTerm('http://example.org/title'),
          LiteralTerm.string('Other Resource'),
        ),
      ]);

      final encodedXml = codec.encode(graph, baseUri: baseUri);
      _log.info('Proper relativization:\n$encodedXml');

      // First should be relativized to 'subresource'
      expect(encodedXml, contains('rdf:about="subresource"'));
      // Second should also be relativized to '../other'
      // because it is one level up from the base URI
      expect(encodedXml, contains('rdf:about="../other"'));
    });

    test('edge case: empty relative URI', () {
      // Test the special case where the URI equals the base URI exactly
      final baseUri = 'http://my.host/document';

      final graph = RdfGraph.fromTriples([
        Triple(
          const IriTerm('http://my.host/document'), // Exactly equals base URI
          const IriTerm('http://example.org/title'),
          LiteralTerm.string('Document'),
        ),
      ]);

      final encodedXml = codec.encode(graph, baseUri: baseUri);
      _log.info('Empty relative URI:\n$encodedXml');

      // Should create empty relative URI
      expect(encodedXml, contains('rdf:about=""'));

      // Decode to verify roundtrip
      final decodedGraph = codec.decode(encodedXml, documentUrl: baseUri);
      final decodedTriples = decodedGraph.triples.toList();
      final subject = decodedTriples[0].subject as IriTerm;

      expect(subject.value, equals('http://my.host/document'));
    });
  });
}
