// Advanced configuration options for RDF/XML parsing and serialization
//
// This example demonstrates how to use various configuration options
// to customize the behavior of the RDF/XML parser and serializer.

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

  print('--- PARSER CONFIGURATION EXAMPLES ---\n');

  // 1. Standard parser
  print('STANDARD PARSER:');
  final standardParser = RdfXmlFormat().createParser();
  // Provide a base URI for resolving relative URIs in the document
  final standardGraph = standardParser.parse(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Parsed ${standardGraph.size} triples with standard configuration\n');

  // 2. Strict parser
  print('STRICT PARSER:');
  final strictParser = RdfXmlFormat.strict().createParser();
  final strictGraph = strictParser.parse(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Parsed ${strictGraph.size} triples with strict configuration\n');

  // 3. Lenient parser
  print('LENIENT PARSER:');
  final lenientParser = RdfXmlFormat.lenient().createParser();
  final lenientGraph = lenientParser.parse(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Parsed ${lenientGraph.size} triples with lenient configuration\n');

  // 4. Custom parser configuration
  print('CUSTOM PARSER CONFIGURATION:');
  final customParserFormat = RdfXmlFormat(
    parserOptions: RdfXmlParserOptions(
      strictMode: false,
      normalizeWhitespace: true,
      validateOutput: true,
    ),
  );
  final customParser = customParserFormat.createParser();
  final customGraph = customParser.parse(
    xmlContent,
    documentUrl: 'http://example.org/data/',
  );
  print('Parsed ${customGraph.size} triples with custom configuration\n');

  print('\n--- SERIALIZER CONFIGURATION EXAMPLES ---\n');

  // Use the graph we parsed above
  final graph = standardGraph;

  // 1. Standard serializer
  print('STANDARD SERIALIZER:');
  final standardSerializer = RdfXmlFormat().createSerializer();
  final standardOutput = standardSerializer.write(graph);
  print('${standardOutput.split('\n').length} lines of output\n');

  // 2. Readable serializer
  print('READABLE SERIALIZER:');
  final readableSerializer = RdfXmlFormat.readable().createSerializer();
  final readableOutput = readableSerializer.write(graph);
  print('${readableOutput.split('\n').length} lines of output\n');

  // 3. Compact serializer
  print('COMPACT SERIALIZER:');
  final compactSerializer = RdfXmlFormat.compact().createSerializer();
  final compactOutput = compactSerializer.write(graph);
  print('${compactOutput.split('\n').length} lines of output\n');

  // 4. Custom serializer configuration
  print('CUSTOM SERIALIZER CONFIGURATION:');
  final customSerializerFormat = RdfXmlFormat(
    serializerOptions: RdfXmlSerializerOptions(
      prettyPrint: true,
      indentSpaces: 4,
      useTypedNodes: true,
    ),
  );
  final customSerializer = customSerializerFormat.createSerializer();
  final customOutput = customSerializer.write(
    graph,
    baseUri: 'http://example.org/data/',
    customPrefixes: {
      'ex': 'http://example.org/terms#',
      'dc': 'http://purl.org/dc/elements/1.1/',
    },
  );
  print('${customOutput.split('\n').length} lines of output');
  print('Sample of custom output:');
  print(customOutput.split('\n').take(10).join('\n'));
}
