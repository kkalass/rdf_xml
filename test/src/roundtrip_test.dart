import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';

void main() {
  group('Roundtrip test', () {
    test('parses and serializes xml correctly', () {
      final xmlContent = '''
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/elements/1.1/"
             xmlns:ex="http://example.org/terms#"
             xml:base="http://example.org/data/">
      
      <!-- Resource with multiple properties -->
      <rdf:Description rdf:about="resource1">
        <dc:title>Configuration Example</dc:title>
        <dc:description xml:lang="en">An example showing configuration options</dc:description>
      </rdf:Description>
      
      <!-- Typed node with nested blank node -->
      <ex:Document rdf:about="doc1">
        <ex:author>
          <ex:Person>
            <ex:name>Jane Smith</ex:name>
          </ex:Person>
        </ex:author>
        <ex:lastModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">2025-05-05</ex:lastModified>
      </ex:Document>
      
      <!-- Container example -->
      <rdf:Description rdf:about="collection1">
        <ex:items>
          <rdf:Bag>
            <rdf:li>Item 1</rdf:li>
            <rdf:li>Item 2</rdf:li>
            <rdf:li>Item 3</rdf:li>
          </rdf:Bag>
        </ex:items>
      </rdf:Description>
    </rdf:RDF>
  ''';

      final parser = RdfXmlParser(xmlContent);
      final triples = parser.parse();
      final serializer = RdfXmlSerializer();
      final serializedXml = serializer.write(
        RdfGraph.fromTriples(triples),
        baseUri: 'http://example.org/data/',
      );
      expect(serializedXml, equals(xmlContent));
    });
  });
}
