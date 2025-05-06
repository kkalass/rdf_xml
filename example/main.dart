// Basic usage of the rdf_xml package
// Shows how to integrate with RdfCore and
// then parse and serialize RDF/XML data

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Example RDF/XML content
  final xmlContent = '''
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/elements/1.1/"
             xmlns:foaf="http://xmlns.com/foaf/0.1/">
      <rdf:Description rdf:about="http://example.org/resource">
        <dc:title>Example Resource</dc:title>
        <dc:creator>Example Author</dc:creator>
        <foaf:maker>
          <foaf:Person>
            <foaf:name>John Doe</foaf:name>
            <foaf:mbox rdf:resource="mailto:john@example.org"/>
          </foaf:Person>
        </foaf:maker>
      </rdf:Description>
    </rdf:RDF>
  ''';

  print('--- PARSING EXAMPLE ---\n');

  // Register the format with the registry
  final rdfCore = RdfCore.withStandardFormats();
  rdfCore.registerFormat(RdfXmlFormat());

  final rdfGraph = rdfCore.parse(xmlContent);

  // Print the parsed triples
  print('Parsed ${rdfGraph.size} triples:');
  for (final triple in rdfGraph.triples) {
    print('- $triple');
  }

  print('\n--- SERIALIZATION EXAMPLE ---\n');

  // Serialize with custom prefixes
  final rdfXml = rdfCore.serialize(
    rdfGraph,
    contentType: "application/rdf+xml",
  );

  print('Serialized RDF/XML:');
  print(rdfXml);
}
