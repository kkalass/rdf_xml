import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/configuration.dart';
import 'package:rdf_xml/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlParser Error Handling', () {
    test('throws XmlParseException on invalid XML', () {
      final invalidXml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object
          </rdf:Description>
        </rdf:RDF>
      ''';

      // The parser should throw an XmlParseException for malformed XML
      expect(
        () => RdfXmlParser(invalidXml).parse(),
        throwsA(isA<XmlParseException>()),
      );
    });

    test('throws RdfXmlException on missing RDF root element', () {
      final invalidRdf = '''
        <root xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <element>Not an RDF document</element>
        </root>
      ''';

      // When the RDF root element is missing, RdfXmlException should be thrown
      expect(
        () => RdfXmlParser(invalidRdf).parse(),
        throwsA(isA<RdfXmlDecoderException>()),
      );
    });

    test('strict mode rejects undefined namespaces', () {
      final missingNamespace = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // In strict mode, undefined namespaces should cause an error
      final strictParser = RdfXmlParser(
        missingNamespace,
        options: RdfXmlDecoderOptions.strict(),
      );
      expect(
        () => strictParser.parse(),
        throwsA(isA<RdfXmlDecoderException>()),
      );

      // Skip the lenient test since it's implementation-dependent
      // and we don't want to make assumptions about the underlying implementation
    });

    test('enforces maximum nesting depth when configured', () {
      // Create a deeply nested RDF/XML structure
      final deeplyNested = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/level1">
            <ex:contains>
              <rdf:Description>
                <ex:contains>
                  <rdf:Description>
                    <ex:contains>
                      <rdf:Description>
                        <ex:contains>
                          <rdf:Description>
                            <ex:contains>
                              <rdf:Description>
                                <ex:value>Too deep!</ex:value>
                              </rdf:Description>
                            </ex:contains>
                          </rdf:Description>
                        </ex:contains>
                      </rdf:Description>
                    </ex:contains>
                  </rdf:Description>
                </ex:contains>
              </rdf:Description>
            </ex:contains>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // Set max nesting depth to 3
      final limitedParser = RdfXmlParser(
        deeplyNested,
        options: const RdfXmlDecoderOptions(maxNestingDepth: 3),
      );

      // Should throw RdfXmlException when exceeding nesting depth
      expect(
        () => limitedParser.parse(),
        throwsA(isA<RdfXmlDecoderException>()),
      );

      // No limit should parse fine
      final unlimitedParser = RdfXmlParser(
        deeplyNested,
        options: const RdfXmlDecoderOptions(maxNestingDepth: 0),
      );

      final triples = unlimitedParser.parse();
      expect(triples, isNotEmpty);
    });
  });

  group('RdfXmlParser Edge Cases', () {
    test('handles empty RDF document', () {
      final emptyRdf = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(emptyRdf);
      final triples = parser.parse();

      expect(triples, isEmpty);
    });

    test('handles RDF/XML with xml:base and baseUri', () {
      final xmlWithBase = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="relative">
            <ex:predicate rdf:resource="other"/>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // Using baseUri to resolve relative URIs
      final parser = RdfXmlParser(
        xmlWithBase,
        baseUri: 'http://example.org/base/',
      );
      final triples = parser.parse();

      expect(triples, hasLength(1));
      expect(
        triples[0].subject,
        equals(const IriTerm('http://example.org/base/relative')),
      );
      expect(
        triples[0].object,
        equals(const IriTerm('http://example.org/base/other')),
      );
    });

    test('handles RDF/XML with blank nodes using nodeID', () {
      final xmlWithNodeId = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/">
          <rdf:Description rdf:nodeID="node1">
            <ex:knows rdf:nodeID="node2"/>
          </rdf:Description>
          <rdf:Description rdf:nodeID="node2">
            <ex:name>Jane</ex:name>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xmlWithNodeId);
      final triples = parser.parse();

      expect(triples, hasLength(2));

      // Both subjects should be blank nodes
      expect(triples[0].subject, isA<BlankNodeTerm>());
      expect(triples[1].subject, isA<BlankNodeTerm>());

      // The object of the first triple should be a blank node and
      // should match the subject of the second triple
      expect(triples[0].object, isA<BlankNodeTerm>());
      expect(triples[0].object, equals(triples[1].subject));
    });

    test('handles datatyped literals with rdf:datatype', () {
      final xmlWithDatatype = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema#">
          <rdf:Description rdf:about="http://example.org/person">
            <ex:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">42</ex:age>
            <ex:height rdf:datatype="http://www.w3.org/2001/XMLSchema#decimal">1.75</ex:height>
            <ex:registered rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">true</ex:registered>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xmlWithDatatype);
      final triples = parser.parse();

      expect(triples, hasLength(3));

      // Find the age triple
      final ageTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).value == 'http://example.org/age',
      );

      expect(ageTriple.object, isA<LiteralTerm>());
      expect((ageTriple.object as LiteralTerm).value, equals('42'));
      expect(
        (ageTriple.object as LiteralTerm).datatype,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
      );

      // Find the height triple
      final heightTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).value == 'http://example.org/height',
      );

      expect(heightTriple.object, isA<LiteralTerm>());
      expect((heightTriple.object as LiteralTerm).value, equals('1.75'));
      expect(
        (heightTriple.object as LiteralTerm).datatype,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#decimal')),
      );

      // Find the registered triple
      final registeredTriple = triples.firstWhere(
        (t) =>
            (t.predicate as IriTerm).value == 'http://example.org/registered',
      );

      expect(registeredTriple.object, isA<LiteralTerm>());
      expect((registeredTriple.object as LiteralTerm).value, equals('true'));
      expect(
        (registeredTriple.object as LiteralTerm).datatype,
        equals(const IriTerm('http://www.w3.org/2001/XMLSchema#boolean')),
      );
    });
  });
}
