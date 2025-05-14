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
  final rdfGraph = rdfxml.decoder.convert(xmlContent);

  // Print the decoded triples
  print('Decoded ${rdfGraph.size} triples:');
  for (final triple in rdfGraph.triples) {
    print('- $triple');
  }

  print('\n--- ENCODER EXAMPLE ---\n');

  // Use the encoder, but change its options with readable preset as base, and with custom prefixes
  final encoder = rdfxml.encoder.withOptions(
    RdfXmlEncoderOptions.readable().copyWith(
      customPrefixes: {
        'dc': 'http://purl.org/dc/elements/1.1/',
        'foaf': 'http://xmlns.com/foaf/0.1/',
        'ex': 'http://example.org/',
      },
    ),
  );
  final rdfXml = encoder.convert(rdfGraph);

  print('Encoded RDF/XML:');
  print(rdfXml);
}
