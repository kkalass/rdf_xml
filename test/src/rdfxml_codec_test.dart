import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlCodec', () {
    test('supports correct MIME types', () {
      final codec = RdfXmlCodec();

      // Primary MIME type
      expect(codec.primaryMimeType, equals('application/rdf+xml'));

      // All supported MIME types
      expect(codec.supportedMimeTypes, contains('application/rdf+xml'));
      expect(codec.supportedMimeTypes, contains('text/xml'));
      expect(codec.supportedMimeTypes, contains('application/xml'));
    });

    test('canParse detects RDF/XML content', () {
      final codec = RdfXmlCodec();

      // Valid RDF/XML content
      final validContent = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      expect(codec.canParse(validContent), isTrue);

      // XML but not RDF/XML
      final nonRdfContent = '''
        <root>
          <element>Just some XML</element>
        </root>
      ''';

      expect(codec.canParse(nonRdfContent), isFalse);
    });

    test('creates parser and serializer instances', () {
      final codec = RdfXmlCodec();

      final parser = codec.decoder;
      final serializer = codec.encoder;

      expect(parser, isNotNull);
      expect(serializer, isNotNull);
    });

    test('parser can parse RDF/XML content', () {
      final codec = RdfXmlCodec();
      final decoder = codec.decoder;

      final content = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final graph = decoder.convert(content);
      expect(graph.triples, hasLength(1));

      final triple = graph.triples.first;
      expect(
        triple.subject,
        equals(const IriTerm('http://example.org/subject')),
      );
      expect(
        triple.predicate,
        equals(const IriTerm('http://example.org/predicate')),
      );
      expect(triple.object, equals(LiteralTerm.string('Object')));
    });

    test('serializer can write RDF/XML content', () {
      final codec = RdfXmlCodec();
      final encoder = codec.encoder;

      final subject = const IriTerm('http://example.org/subject');
      final predicate = RdfTerms.type;
      final object = const IriTerm('http://example.org/Class');

      final graph = RdfGraph(triples: [Triple(subject, predicate, object)]);

      final xml = encoder.convert(graph);

      expect(xml, contains('<rdf:RDF'));
      expect(
        xml,
        contains('xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'),
      );
      expect(xml, contains('rdf:about="http://example.org/subject"'));
    });
  });

  group("Decoding of relative URLs", () {
    test("Parses empty (relative) IRITerm attributes", () {
      final xml = '''
    <?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="">
  </rdf:Description>
</rdf:RDF>
  ''';
      final expectedMessage =
          '''
RDF/XML Error in rdf:Description: 

Cannot resolve relative URI '' because no base URI is available. 
This can happen when: 

(1) The RDF/XML document has no xml:base attribute, and 
(2) No documentUrl was provided to the parser. 

To fix this, either add an xml:base attribute to your RDF/XML document or 
provide a documentUrl parameter when calling the decoder: 

rdfxml.decode(xmlString, documentUrl: 'https://example.org/base/')

Tip: To encode documents like this (with relative URIs but without xml:base declaration), 
use the includeBaseDeclaration option and provide a baseUri parameter:

RdfXmlCodec(encoderOptions: RdfXmlEncoderOptions(includeBaseDeclaration: false))
  .encode(graph, baseUri: 'https://example.org/base/')
'''.trim();

      expect(
        () => rdfxml.decode(xml),
        throwsA(
          allOf(
            isA<RdfXmlBaseUriRequiredException>(),
            predicate((e) => e.toString().trim() == expectedMessage),
          ),
        ),
      );
    });

    test(
      "Parses empty (relative) IRITerm attributes with documentUrl and no content",
      () {
        final xml = '''
    <?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="">
  </rdf:Description>
</rdf:RDF>
  ''';

        final triples =
            rdfxml
                .decode(xml, documentUrl: 'http://example.org/resource')
                .triples;
        expect(triples, isEmpty);
      },
    );
    test("Parses empty (relative) IRITerm attributes with documentUrl", () {
      final xml = '''
    <?xml version="1.0"?> 
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <rdf:Description rdf:about="">
    <dc:identifier>4711</dc:identifier>
  </rdf:Description>
</rdf:RDF>
  ''';

      final triples =
          rdfxml
              .decode(xml, documentUrl: 'http://example.org/resource')
              .triples;

      expect(triples, isNotEmpty);
      expect(
        triples.first.subject,
        equals(const IriTerm("http://example.org/resource")),
      );
      expect(
        triples.first.predicate,
        equals(const IriTerm("http://purl.org/dc/elements/1.1/identifier")),
      );
      expect(triples.first.object, equals(LiteralTerm("4711")));
    });

    test("Encodes empty (relative) IRITerm attributes with baseUri", () {
      final newXml = rdfxml.encode(
        RdfGraph.fromTriples([
          Triple(
            const IriTerm("http://example.org/resource"),
            const IriTerm("http://purl.org/dc/elements/1.1/identifier"),
            LiteralTerm("4711"),
          ),
        ]),
        baseUri: 'http://example.org/resource',
      );

      expect(newXml, contains('xml:base="http://example.org/resource"'));
      expect(newXml, contains('<rdf:Description rdf:about="">'));
    });
    test(
      "Encodes empty (relative) IRITerm attributes with baseUri, but without xml:base",
      () {
        final newXml = rdfxml.encode(
          RdfGraph.fromTriples([
            Triple(
              const IriTerm("http://example.org/resource"),
              const IriTerm("http://purl.org/dc/elements/1.1/identifier"),
              LiteralTerm("4711"),
            ),
          ]),
          baseUri: 'http://example.org/resource',
          options: RdfXmlEncoderOptions(includeBaseDeclaration: false),
        );
        expect(
          newXml,
          isNot(contains('xml:base="http://example.org/resource"')),
        );
        expect(newXml, isNot(contains('xml:base')));
        expect(newXml, contains('<rdf:Description rdf:about="">'));
      },
    );
    test("Encodes relative IRITerm attributes with baseUri", () {
      final newXml = rdfxml.encode(
        RdfGraph.fromTriples([
          Triple(
            const IriTerm("http://example.org/resource/1"),
            const IriTerm("http://purl.org/dc/elements/1.1/identifier"),
            LiteralTerm("4711"),
          ),
        ]),
        baseUri: 'http://example.org/resource/',
      );
      expect(newXml, contains('<rdf:Description rdf:about="1">'));
    });

    test("Parses empty (relative) IRITerm attributes with baseUri", () {
      final xml = '''
    <?xml version="1.0"?>
<rdf:RDF xml:base="http://example.org/resource" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <rdf:Description rdf:about="">
   <dc:identifier>4711</dc:identifier>
  </rdf:Description>
</rdf:RDF>
  ''';

      final triples = rdfxml.decode(xml).triples;

      expect(triples, isNotEmpty);
      expect(
        triples.first.subject,
        equals(const IriTerm("http://example.org/resource")),
      );
      expect(
        triples.first.predicate,
        equals(const IriTerm("http://purl.org/dc/elements/1.1/identifier")),
      );
      expect(triples.first.object, equals(LiteralTerm("4711")));
    });
  });
}
