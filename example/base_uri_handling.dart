// Base URI handling and includeBaseDeclaration option examples
//
// This example demonstrates how to control the inclusion of xml:base
// attributes in serialized RDF/XML output using the includeBaseDeclaration option.

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Create a graph with URIs that can be relativized
  final graph = RdfGraph.fromTriples([
    Triple(
      const IriTerm('http://example.org/base/document'),
      const IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('Example Document'),
    ),
    Triple(
      const IriTerm('http://example.org/base/document'),
      const IriTerm('http://purl.org/dc/elements/1.1/creator'),
      LiteralTerm.string('Jane Doe'),
    ),
    Triple(
      const IriTerm('http://example.org/base/images/photo.jpg'),
      const IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('Profile Photo'),
    ),
  ]);

  final baseUri = 'http://example.org/base/';

  print('=== BASE URI HANDLING EXAMPLES ===\n');

  // Example 1: Default behavior (includeBaseDeclaration: true)
  print('1. DEFAULT: includeBaseDeclaration = true');
  print('   - xml:base attribute is included');
  print('   - URIs are relativized against the base\n');

  final defaultCodec = RdfXmlCodec(); // Uses default options
  final xmlWithBase = defaultCodec.encode(graph, baseUri: baseUri);
  print(xmlWithBase);
  print('\n' + '─' * 60 + '\n');

  // Example 2: Exclude base declaration (includeBaseDeclaration: false)
  print('2. COMPACT: includeBaseDeclaration = false');
  print('   - No xml:base attribute in output');
  print('   - URIs are still relativized but base is not declared\n');

  final noBaseCodec = RdfXmlCodec(
    encoderOptions: RdfXmlEncoderOptions(includeBaseDeclaration: false),
  );
  final xmlWithoutBase = noBaseCodec.encode(graph, baseUri: baseUri);
  print(xmlWithoutBase);
  print('\n' + '─' * 60 + '\n');

  // Example 3: Factory methods with different defaults
  print('3. FACTORY METHOD DEFAULTS:');
  print(
    '   readable() → includeBaseDeclaration: ${RdfXmlEncoderOptions.readable().includeBaseDeclaration}',
  );
  print(
    '   compact()  → includeBaseDeclaration: ${RdfXmlEncoderOptions.compact().includeBaseDeclaration}',
  );
  print(
    '   compatible() → includeBaseDeclaration: ${RdfXmlEncoderOptions.compatible().includeBaseDeclaration}\n',
  );

  // Example 4: Using factory methods
  print('4. USING COMPACT FACTORY METHOD:');
  final compactCodec = RdfXmlCodec.compact();
  final compactXml = compactCodec.encode(graph, baseUri: baseUri);
  print(compactXml);
  print('\n' + '─' * 60 + '\n');

  // Example 5: No base URI provided - option has no effect
  print('5. NO BASE URI PROVIDED:');
  print('   - includeBaseDeclaration has no effect');
  print('   - All URIs remain absolute\n');

  final xmlNoBaseUri = defaultCodec.encode(graph); // No baseUri parameter
  print(xmlNoBaseUri);
  print('\n' + '─' * 60 + '\n');

  // Example 6: Special case - Empty relative IRI (IRI equals base URI)
  print('6. EMPTY RELATIVE IRI (IRI = BASE URI):');
  print(
    '   - Demonstrates the edge case where an IRI exactly matches the base URI',
  );
  print('   - Results in an empty relative IRI (rdf:about="")\n');

  final emptyRelativeGraph = RdfGraph.fromTriples([
    Triple(
      const IriTerm('http://example.org/base/'), // IRI equals base URI exactly
      const IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('Base Document'),
    ),
    Triple(
      const IriTerm('http://example.org/base/'), // Same IRI again
      const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
      const IriTerm('http://purl.org/dc/dcmitype/Text'),
    ),
  ]);

  print('   With base declaration:');
  final emptyRelativeWithBase = defaultCodec.encode(
    emptyRelativeGraph,
    baseUri: baseUri,
  );
  print(emptyRelativeWithBase);
  print('\n   Without base declaration:');
  final emptyRelativeNoBase = noBaseCodec.encode(
    emptyRelativeGraph,
    baseUri: baseUri,
  );
  print(emptyRelativeNoBase);
  print('\n' + '─' * 60 + '\n');

  // Example 7: Practical use cases
  print('7. PRACTICAL USE CASES:\n');

  print('   a) Human-readable documentation (with base):');
  print('      Use includeBaseDeclaration: true');
  print('      → Readers can understand the base context\n');

  print('   b) Minimal file size for storage/transmission:');
  print('      Use includeBaseDeclaration: false');
  print('      → Saves bytes by omitting xml:base declaration\n');

  print('   c) Compatibility with older RDF/XML parsers:');
  print('      Use includeBaseDeclaration: true');
  print('      → Ensures base URI is explicitly declared\n');

  // Example 8: Integration with RdfCore
  print('8. INTEGRATION WITH RDFCORE:\n');
  final rdfCore = RdfCore.withStandardCodecs(
    additionalCodecs: [
      RdfXmlCodec(
        encoderOptions: RdfXmlEncoderOptions(includeBaseDeclaration: false),
      ),
    ],
  );

  final coreXml = rdfCore.encode(
    graph,
    contentType: 'application/rdf+xml',
    baseUri: baseUri,
  );
  print('RdfCore with custom codec (no base declaration):');
  print(coreXml);
}
