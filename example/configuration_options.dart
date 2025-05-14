// Advanced configuration options for RDF/XML decoding and encoding
//
// This example demonstrates how to use various configuration options
// to customize the behavior of the RDF/XML decoder and encoder.

import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Example RDF/XML content with various RDF/XML features
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

  print('--- DECODER CONFIGURATION EXAMPLES ---\n');

  // 1. Standard decoder
  print('STANDARD DECODER:');
  // Use the global rdfxml codec
  final standardGraph = rdfxml.decode(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Decoded ${standardGraph.size} triples with standard configuration\n');

  // 2. Strict decoder
  print('STRICT DECODER:');
  final strictRdfXml = RdfXmlCodec.strict();
  final strictGraph = strictRdfXml.decode(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Decoded ${strictGraph.size} triples with strict configuration\n');

  // 3. Lenient decoder
  print('LENIENT DECODER:');
  final lenientRdfXml = RdfXmlCodec.lenient();
  final lenientGraph = lenientRdfXml.decode(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Decoded ${lenientGraph.size} triples with lenient configuration\n');

  // 4. Custom decoder configuration
  print('CUSTOM DECODER CONFIGURATION:');
  final customDecoderCodec = RdfXmlCodec(
    decoderOptions: RdfXmlDecoderOptions(
      strictMode: false,
      normalizeWhitespace: true,
      validateOutput: true,
    ),
  );
  final customGraph = customDecoderCodec.decode(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Decoded ${customGraph.size} triples with custom configuration\n');

  print('\n--- ENCODER CONFIGURATION EXAMPLES ---\n');

  // Use the graph we decoded above
  final graph = standardGraph;

  // 1. Standard encoder
  print('STANDARD ENCODER:');
  final standardOutput = rdfxml.encode(graph);
  print('${standardOutput.split('\n').length} lines of output\n');

  // 2. Readable encoder
  print('READABLE ENCODER:');
  final readableOutput = RdfXmlCodec.readable().encode(graph);
  print('${readableOutput.split('\n').length} lines of output\n');

  // 3. Compact encoder
  print('COMPACT ENCODER:');
  final compactOutput = RdfXmlCodec.compact().encode(graph);
  print('${compactOutput.split('\n').length} lines of output\n');

  // 4. Custom encoder configuration
  print('CUSTOM ENCODER CONFIGURATION:');
  final customEncoderCodec = RdfXmlCodec(
    encoderOptions: RdfXmlEncoderOptions(
      prettyPrint: true,
      indentSpaces: 4,
      useTypedNodes: true,
      customPrefixes: {
        'ex': 'http://example.org/terms#',
        'dc': 'http://purl.org/dc/elements/1.1/',
      },
    ),
  );
  final customOutput = customEncoderCodec.encode(
    graph,
    baseUri: 'http://example.org/data/',
  );
  print('${customOutput.split('\n').length} lines of output');
  print('Sample of custom output:');
  print(customOutput.split('\n').take(10).join('\n'));
}
