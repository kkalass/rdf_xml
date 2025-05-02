// filepath: /Users/klaskalass/privat/rdf/rdf_xml/test/src/rdfxml/rdfxml_format_test.dart
import 'package:rdf_xml/src/rdfxml_format.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlFormat', () {
    test('supports correct MIME types', () {
      const format = RdfXmlFormat();

      // Primary MIME type
      expect(format.primaryMimeType, equals('application/rdf+xml'));

      // All supported MIME types
      expect(format.supportedMimeTypes, contains('application/rdf+xml'));
      expect(format.supportedMimeTypes, contains('text/xml'));
      expect(format.supportedMimeTypes, contains('application/xml'));
    });

    test('canParse detects RDF/XML content', () {
      const format = RdfXmlFormat();

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
      const format = RdfXmlFormat();

      final parser = format.createParser();
      final serializer = format.createSerializer();

      expect(parser, isNotNull);
      expect(serializer, isNotNull);
    });
  });
}
