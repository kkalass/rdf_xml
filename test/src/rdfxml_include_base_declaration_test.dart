/// Tests for the includeBaseDeclaration option
///
/// This file contains tests that verify the includeBaseDeclaration option
/// controls whether xml:base attributes are included in the serialized output.
library rdfxml.test.include_base_declaration;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:test/test.dart';

/// Creates a simple test graph for testing
RdfGraph createSimpleTestGraph() {
  return RdfGraph.fromTriples([
    Triple(
      const IriTerm('http://example.org/subject'),
      const IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm('Test Title'),
    ),
  ]);
}

void main() {
  group('includeBaseDeclaration option', () {
    test('includes xml:base when includeBaseDeclaration is true (default)', () {
      final graph = createSimpleTestGraph();
      final baseUri = 'http://example.org/base/';

      final options = RdfXmlEncoderOptions(includeBaseDeclaration: true);
      final serializer = RdfXmlCodec(encoderOptions: options);

      final xml = serializer.encode(graph, baseUri: baseUri);

      expect(xml, contains('xml:base="$baseUri"'));
    });

    test('excludes xml:base when includeBaseDeclaration is false', () {
      final graph = createSimpleTestGraph();
      final baseUri = 'http://example.org/base/';

      final options = RdfXmlEncoderOptions(includeBaseDeclaration: false);
      final serializer = RdfXmlCodec(encoderOptions: options);

      final xml = serializer.encode(graph, baseUri: baseUri);

      expect(xml, isNot(contains('xml:base="$baseUri"')));
    });

    test('factory methods have correct default values', () {
      // readable() should include base declaration
      final readableOptions = RdfXmlEncoderOptions.readable();
      expect(readableOptions.includeBaseDeclaration, isTrue);

      // compact() should not include base declaration for minimal output
      final compactOptions = RdfXmlEncoderOptions.compact();
      expect(compactOptions.includeBaseDeclaration, isFalse);

      // compatible() should include base declaration
      final compatibleOptions = RdfXmlEncoderOptions.compatible();
      expect(compatibleOptions.includeBaseDeclaration, isTrue);
    });

    test(
      'from() method preserves includeBaseDeclaration from RdfXmlEncoderOptions',
      () {
        final originalOptions = RdfXmlEncoderOptions(
          includeBaseDeclaration: false,
        );
        final newOptions = RdfXmlEncoderOptions.from(originalOptions);

        expect(newOptions.includeBaseDeclaration, isFalse);
      },
    );

    test(
      'from() method defaults to true for generic RdfGraphEncoderOptions',
      () {
        final genericOptions = RdfGraphEncoderOptions();
        final xmlOptions = RdfXmlEncoderOptions.from(genericOptions);

        expect(xmlOptions.includeBaseDeclaration, isTrue);
      },
    );

    test('copyWith preserves and updates includeBaseDeclaration', () {
      final originalOptions = RdfXmlEncoderOptions(
        includeBaseDeclaration: false,
      );

      // Test preserving the value
      final preserved = originalOptions.copyWith(prettyPrint: false);
      expect(preserved.includeBaseDeclaration, isFalse);

      // Test updating the value
      final updated = originalOptions.copyWith(includeBaseDeclaration: true);
      expect(updated.includeBaseDeclaration, isTrue);
    });

    test('equality and hashCode include includeBaseDeclaration', () {
      final options1 = RdfXmlEncoderOptions(includeBaseDeclaration: true);
      final options2 = RdfXmlEncoderOptions(includeBaseDeclaration: true);
      final options3 = RdfXmlEncoderOptions(includeBaseDeclaration: false);

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
      expect(options1.hashCode, equals(options2.hashCode));
      expect(options1.hashCode, isNot(equals(options3.hashCode)));
    });

    test('toString includes includeBaseDeclaration', () {
      final options = RdfXmlEncoderOptions(includeBaseDeclaration: false);
      final string = options.toString();

      expect(string, contains('includeBaseDeclaration: false'));
    });

    test('works correctly with relative URIs when base is excluded', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          const IriTerm('http://example.org/base/resource'),
          const IriTerm('http://purl.org/dc/elements/1.1/title'),
          LiteralTerm('Test Title'),
        ),
      ]);

      final baseUri = 'http://example.org/base/';
      final options = RdfXmlEncoderOptions(includeBaseDeclaration: false);
      final serializer = RdfXmlCodec(encoderOptions: options);

      final xml = serializer.encode(graph, baseUri: baseUri);

      // Should have relative URI but no xml:base
      expect(xml, contains('rdf:about="resource"'));
      expect(xml, isNot(contains('xml:base')));
    });
  });
}
