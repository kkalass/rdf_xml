import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_format.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlFormat', () {
    test('supports correct MIME types', () {
      final format = RdfXmlFormat();

      // Primary MIME type
      expect(format.primaryMimeType, equals('application/rdf+xml'));

      // All supported MIME types
      expect(format.supportedMimeTypes, contains('application/rdf+xml'));
      expect(format.supportedMimeTypes, contains('text/xml'));
      expect(format.supportedMimeTypes, contains('application/xml'));
    });

    test('canParse detects RDF/XML content', () {
      final format = RdfXmlFormat();

      // Valid RDF/XML content
      final validContent = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      expect(format.canParse(validContent), isTrue);

      // XML but not RDF/XML
      final nonRdfContent = '''
        <root>
          <element>Just some XML</element>
        </root>
      ''';

      expect(format.canParse(nonRdfContent), isFalse);
    });

    test('creates parser and serializer instances', () {
      final format = RdfXmlFormat();

      final parser = format.createParser();
      final serializer = format.createSerializer();

      expect(parser, isNotNull);
      expect(serializer, isNotNull);
    });

    test('parser can parse RDF/XML content', () {
      final format = RdfXmlFormat();
      final parser = format.createParser();

      final content = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final graph = parser.parse(content);
      expect(graph.triples, hasLength(1));

      final triple = graph.triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/subject')));
      expect(triple.predicate, equals(IriTerm('http://example.org/predicate')));
      expect(triple.object, equals(LiteralTerm.string('Object')));
    });

    test('serializer can write RDF/XML content', () {
      final format = RdfXmlFormat();
      final serializer = format.createSerializer();

      final subject = IriTerm('http://example.org/subject');
      final predicate = RdfTerms.type;
      final object = IriTerm('http://example.org/Class');

      final graph = RdfGraph(triples: [Triple(subject, predicate, object)]);

      final xml = serializer.write(graph);
      expect(xml, contains('<rdf:RDF'));
      expect(
        xml,
        contains('xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'),
      );
      expect(xml, contains('rdf:about="http://example.org/subject"'));
    });
  });
}
