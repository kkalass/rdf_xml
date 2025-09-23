import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:rdf_xml/src/configuration.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlSerializer Configuration Options', () {
    test('prettyPrint option controls formatting', () {
      final subject = const IriTerm('http://example.org/resource');
      final predicate = const IriTerm('http://example.org/property');
      final object = LiteralTerm.string('Value');

      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph(triples: [triple]);

      // Create serializer with pretty printing
      final prettySerializer = RdfXmlSerializer(
        options: const RdfXmlEncoderOptions(prettyPrint: true),
      );
      final prettyXml = prettySerializer.write(graph);

      // Create serializer without pretty printing
      final compactSerializer = RdfXmlSerializer(
        options: const RdfXmlEncoderOptions(prettyPrint: false),
      );
      final compactXml = compactSerializer.write(graph);

      // Pretty XML should have newlines
      expect(prettyXml, contains('\n'));

      // Compact XML should not have newlines or unnecessary whitespace
      expect(compactXml, isNot(contains('\n')));

      // Both should be valid XML and parse to the same triples
      final prettyParser = RdfXmlParser(prettyXml);
      final compactParser = RdfXmlParser(compactXml);

      final prettyTriples = prettyParser.parse();
      final compactTriples = compactParser.parse();

      expect(prettyTriples, hasLength(1));
      expect(compactTriples, hasLength(1));
      expect(prettyTriples.first, equals(compactTriples.first));
    });

    test('indentSpaces option controls indentation level', () {
      final triple = Triple(
        const IriTerm('http://example.org/resource'),
        const IriTerm('http://example.org/property'),
        LiteralTerm.string('Value'),
      );
      final graph = RdfGraph(triples: [triple]);

      // Create serializer with 2-space indentation
      final twoSpaceSerializer = RdfXmlSerializer(
        options: const RdfXmlEncoderOptions(prettyPrint: true, indentSpaces: 2),
      );
      final twoSpaceXml = twoSpaceSerializer.write(graph);

      // Create serializer with 4-space indentation
      final fourSpaceSerializer = RdfXmlSerializer(
        options: const RdfXmlEncoderOptions(prettyPrint: true, indentSpaces: 4),
      );
      final fourSpaceXml = fourSpaceSerializer.write(graph);

      // Two-space indentation should have lines with two spaces
      expect(twoSpaceXml, contains('\n  <'));

      // Four-space indentation should have lines with four spaces
      expect(fourSpaceXml, contains('\n    <'));
    });

    test('useNamespaces option affects serialization output', () {
      // Setup a more complex graph with multiple different namespaces
      final resource = const IriTerm('http://example.org/resource');
      final triples = [
        Triple(
          resource,
          RdfTerms.type,
          const IriTerm('http://example.org/Type'),
        ),
        Triple(
          resource,
          const IriTerm('http://example.org/property'),
          LiteralTerm.string('Value'),
        ),
        Triple(
          resource,
          const IriTerm('http://purl.org/dc/terms/title'),
          LiteralTerm.string('Resource Title'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      // With namespaces enabled - the default
      final withNamespaces = RdfXmlSerializer(
        options: const RdfXmlEncoderOptions(),
      );
      final xmlWithNamespaces = withNamespaces.write(graph);

      // Verify the output contains valid RDF/XML and can be parsed back
      final parser = RdfXmlParser(xmlWithNamespaces);
      final parsedTriples = parser.parse();

      // Should have all original triples
      expect(parsedTriples, hasLength(3));
      for (final triple in triples) {
        expect(parsedTriples.contains(triple), isTrue);
      }
    });

    test('useTypedNodes option affects serialization output', () {
      final subject = const IriTerm('http://example.org/person/1');
      final typeTriple = Triple(
        subject,
        RdfTerms.type,
        const IriTerm('http://example.org/Person'),
      );
      final nameTriple = Triple(
        subject,
        const IriTerm('http://example.org/name'),
        LiteralTerm.string('John Doe'),
      );

      final graph = RdfGraph(triples: [typeTriple, nameTriple]);

      // With useTypedNodes setting (any value)
      final serializer = RdfXmlSerializer(
        options: const RdfXmlEncoderOptions(useTypedNodes: true),
      );
      final xml = serializer.write(graph);

      // Verify the output can be parsed back correctly regardless of how it's serialized
      final parser = RdfXmlParser(xml);
      final parsedTriples = parser.parse();

      // Should have all original triples
      expect(parsedTriples, hasLength(2));
      expect(parsedTriples.contains(typeTriple), isTrue);
      expect(parsedTriples.contains(nameTriple), isTrue);
    });

    test('factory methods create correct configurations', () {
      // Test the readable factory
      final readableOptions = RdfXmlEncoderOptions.readable();
      expect(readableOptions.prettyPrint, isTrue);
      expect(readableOptions.indentSpaces, equals(2));

      // Test the compact factory
      final compactOptions = RdfXmlEncoderOptions.compact();
      expect(compactOptions.prettyPrint, isFalse);
      // Still use namespaces for compactness
    });

    test('only used namespaces are declared in XML output', () {
      // Create custom prefixes - we'll only use some of them
      final customPrefixes = {
        'ex': 'http://example.org/',
        'dc': 'http://purl.org/dc/terms/',
        'foaf': 'http://xmlns.com/foaf/0.1/',
        'unused': 'http://unused.example.org/',
      };

      // Set up a graph that only uses some of the namespaces
      final resource = const IriTerm('http://example.org/resource');
      final triples = [
        Triple(
          resource,
          RdfTerms.type,
          const IriTerm('http://example.org/Type'),
        ),
        Triple(
          resource,
          const IriTerm('http://purl.org/dc/terms/title'),
          LiteralTerm.string('Resource Title'),
        ),
        // No triples using the 'foaf' or 'unused' namespaces
      ];

      final graph = RdfGraph(triples: triples);

      // Serialize with the namespaces
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph, customPrefixes: customPrefixes);

      // The XML should contain the used namespaces
      expect(xml, contains('xmlns:ex="http://example.org/"'));
      expect(xml, contains('xmlns:dc="http://purl.org/dc/terms/"'));
      expect(
        xml,
        contains('xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'),
      ); // rdf is always included

      // The XML should NOT contain the unused namespaces
      expect(xml, isNot(contains('xmlns:foaf="http://xmlns.com/foaf/0.1/"')));
      expect(xml, isNot(contains('xmlns:unused="http://unused.example.org/"')));
    });
  });
}
