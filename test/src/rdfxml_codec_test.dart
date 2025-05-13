import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_codec.dart';
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
      expect(triple.subject, equals(IriTerm('http://example.org/subject')));
      expect(triple.predicate, equals(IriTerm('http://example.org/predicate')));
      expect(triple.object, equals(LiteralTerm.string('Object')));
    });

    test('serializer can write RDF/XML content', () {
      final codec = RdfXmlCodec();
      final encoder = codec.encoder;

      final subject = IriTerm('http://example.org/subject');
      final predicate = RdfTerms.type;
      final object = IriTerm('http://example.org/Class');

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
}
