// Basic usage of the rdf_xml package
// Shows how to decode and encode RDF/XML data

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

  print('--- DECODER EXAMPLE ---\n');

  // Use the global rdfxml codec
  final rdfGraph = rdfxml.decode(xmlContent);

  // Print the decoded triples
  print('Decoded ${rdfGraph.size} triples:');
  for (final triple in rdfGraph.triples) {
    print('- $triple');
  }

  print('\n--- ENCODER EXAMPLE ---\n');

  // Use the readable preset with the global codec
  final rdfXml = RdfXmlCodec.readable().encode(
    rdfGraph,
    customPrefixes: {
      'dc': 'http://purl.org/dc/elements/1.1/',
      'foaf': 'http://xmlns.com/foaf/0.1/',
      'ex': 'http://example.org/',
    },
  );

  print('Encoded RDF/XML:');
  print(rdfXml);
}
