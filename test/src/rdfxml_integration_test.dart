import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';

void main() {
  group('RDF Format Registry Integration', () {
    test('RdfXmlFormat can be registered and retrieved', () {
      final registry = RdfFormatRegistry();
      final format = RdfXmlFormat();

      registry.registerFormat(format);

      // Retrieve by primary MIME type
      final retrievedFormat = registry.getFormat('application/rdf+xml');
      expect(retrievedFormat, isNotNull);

      // Retrieve by alternative MIME types
      final xmlFormat = registry.getFormat('application/xml');
      expect(xmlFormat, isNotNull);

      final textXmlFormat = registry.getFormat('text/xml');
      expect(textXmlFormat, isNotNull);
    });

    test('Parser factory creates RdfXmlParser', () {
      final registry = RdfFormatRegistry();
      registry.registerFormat(RdfXmlFormat());

      final factory = RdfParserFactory(registry);
      final parser = factory.createParser(contentType: 'application/rdf+xml');

      expect(parser, isNotNull);

      // Very simple RDF document
      final rdfContent = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="http://example.org/resource">
            <rdf:type rdf:resource="http://example.org/Type"/>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final graph = parser.parse(rdfContent);
      expect(graph.triples, hasLength(1));

      final triple = graph.triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/resource')));
      expect(triple.predicate, equals(RdfTerms.type));
      expect(triple.object, equals(IriTerm('http://example.org/Type')));
    });

    test('Direct format parsing works', () {
      final format = RdfXmlFormat();

      // Very simple RDF document
      final rdfContent = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="http://example.org/resource">
            <rdf:type rdf:resource="http://example.org/Type"/>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final graph = format.createParser().parse(rdfContent);
      expect(graph.triples, hasLength(1));
    });

    test('Format detection works', () {
      final format = RdfXmlFormat();

      // Valid RDF/XML
      final validRdf = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="http://example.org/resource"/>
        </rdf:RDF>
      ''';
      expect(format.canParse(validRdf), isTrue);

      // Not RDF/XML
      final invalidRdf = '''
        <root>
          <element>Not RDF/XML</element>
        </root>
      ''';
      expect(format.canParse(invalidRdf), isFalse);
    });

    test('Factory methods create properly configured formats', () {
      // Test strict format
      final strictFormat = RdfXmlFormat.strict();
      expect(strictFormat.createParser(), isNotNull);

      // Test lenient format
      final lenientFormat = RdfXmlFormat.lenient();
      expect(lenientFormat.createParser(), isNotNull);

      // Test readable format
      final readableFormat = RdfXmlFormat.readable();
      expect(readableFormat.createSerializer(), isNotNull);

      // Test compact format
      final compactFormat = RdfXmlFormat.compact();
      expect(compactFormat.createSerializer(), isNotNull);
    });
  });

  group('Advanced RDF/XML Features', () {
    test('RDF/XML format supports round-trip serialization', () {
      final format = RdfXmlFormat();

      // Create an initial graph with some triples
      final subject = IriTerm('http://example.org/resource');
      final triple1 = Triple(
        subject,
        RdfTerms.type,
        IriTerm('http://example.org/Type'),
      );
      final triple2 = Triple(
        subject,
        IriTerm('http://example.org/title'),
        LiteralTerm.string('Resource Title'),
      );

      final originalGraph = RdfGraph(triples: [triple1, triple2]);

      // Serialize to RDF/XML
      final serializer = format.createSerializer();
      final rdfXml = serializer.write(originalGraph);

      // Parse back to a graph
      final parser = format.createParser();
      final reparsedGraph = parser.parse(rdfXml);

      // Verify that all original triples are present
      for (final originalTriple in originalGraph.triples) {
        expect(
          reparsedGraph.triples.contains(originalTriple),
          isTrue,
          reason: 'Missing triple after round-trip: $originalTriple',
        );
      }
    });

    test('Handles XML entities correctly', () {
      final xmlWithEntities = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/resource">
            <ex:title>Title with &lt;brackets&gt; &amp; ampersands</ex:title>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xmlWithEntities);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final title = triples.first.object as LiteralTerm;
      expect(title.value, equals('Title with <brackets> & ampersands'));

      // Now test serialization of entities
      final subject = IriTerm('http://example.org/resource');
      final predicate = IriTerm('http://example.org/title');
      final object = LiteralTerm.string('Contains <, > and & characters');

      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph(triples: [triple]);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // At minimum, < and & must be escaped in XML
      expect(xml, contains('&lt;'));
      expect(xml, contains('&amp;'));

      // > may or may not be escaped (it's optional in XML)
      // so we won't test for that specifically

      // Parse it back and ensure we get the original text
      final reparser = RdfXmlParser(xml);
      final reparsedTriples = reparser.parse();

      expect(reparsedTriples, hasLength(1));

      final reparsedObject = reparsedTriples.first.object as LiteralTerm;
      expect(reparsedObject.value, equals('Contains <, > and & characters'));
    });

    test('Supports custom namespace prefixes', () {
      final subject = IriTerm('http://example.org/resource');
      final predicate = IriTerm('http://example.org/property');
      final object = LiteralTerm.string('Value');

      final triple = Triple(subject, predicate, object);
      final graph = RdfGraph(triples: [triple]);

      // Define custom prefixes
      final customPrefixes = <String, String>{'custom': 'http://example.org/'};

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph, customPrefixes: customPrefixes);

      // The XML should use our custom prefix
      expect(xml, contains('xmlns:custom="http://example.org/"'));
    });
  });
}
