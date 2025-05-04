/// RDF/XML Format Implementation
///
/// Defines the format plugin for RDF/XML serialization and parsing.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// final registry = RdfFormatRegistry();
/// registry.registerFormat(const RdfXmlFormat());
/// final parser = registry.getParser('application/rdf+xml');
/// final graph = parser.parse(rdfXmlString);
/// ```
library rdfxml_format;

import 'package:rdf_core/rdf_core.dart';

import 'rdfxml_parser.dart';
import 'rdfxml_serializer.dart';

/// Format plugin for RDF/XML
///
/// Implements the [RdfFormat] interface for the RDF/XML format,
/// providing factory methods for creating parsers and serializers.
final class RdfXmlFormat implements RdfFormat {
  /// MIME type for RDF/XML
  static const String mimeType = 'application/rdf+xml';

  /// Creates a new RDF/XML format plugin
  const RdfXmlFormat();

  @override
  String get primaryMimeType => mimeType;

  @override
  Set<String> get supportedMimeTypes => {
    mimeType,
    'application/xml',
    'text/xml',
  };

  @override
  RdfParser createParser() {
    return _RdfXmlFormatParserAdapter();
  }

  @override
  RdfSerializer createSerializer() {
    return _RdfXmlFormatSerializerAdapter();
  }

  @override
  bool canParse(String content) {
    // Check if content appears to be RDF/XML
    return content.contains('<rdf:RDF') ||
        (content.contains(
              'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"',
            ) &&
            content.contains('<rdf:Description'));
  }
}

/// Adapter class to make RdfXmlParser compatible with the RdfParser interface
final class _RdfXmlFormatParserAdapter implements RdfParser {
  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    final parser = RdfXmlParser(input, baseUri: documentUrl);
    final triples = parser.parse();
    return RdfGraph.fromTriples(triples);
  }
}

/// Adapter class to make RdfXmlSerializer compatible with the RdfSerializer interface
final class _RdfXmlFormatSerializerAdapter implements RdfSerializer {
  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    final serializer = RdfXmlSerializer();
    return serializer.write(
      graph,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }
}
