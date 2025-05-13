// Basic usage of the rdf_xml package
// Shows how to integrate with RdfCore and
// then decode and encode RDF/XML data

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

  // OPTIONAL: just use the global rdfxml instance directly, without RdfCore integration. For example:
  // rdfxml.decode(xmlContent);
  // rdfxml.encode(rdfGraph);
  //
  // Below is the RdfCore integration example, which allows for more advanced usage.
  //
  print('--- DECODING EXAMPLE ---\n');

  // Register the codec with the registry
  final rdfCore = RdfCore.withStandardCodecs(additionalCodecs: [RdfXmlCodec()]);

  final rdfGraph = rdfCore.decode(xmlContent);

  // Print the parsed triples
  print('Parsed ${rdfGraph.size} triples:');
  for (final triple in rdfGraph.triples) {
    print('- $triple');
  }

  print('\n--- ENCODING EXAMPLE ---\n');

  // Serialize with custom prefixes
  final rdfXml = rdfCore.encode(rdfGraph, contentType: "application/rdf+xml");

  print('Serialized RDF/XML:');
  print(rdfXml);
}
