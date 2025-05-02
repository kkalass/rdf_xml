/// RDF/XML Format Implementation
///
/// Defines the format plugin for RDF/XML serialization and parsing.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// final parser = RdfParser.forFormat('application/rdf+xml');
/// final serializer = RdfSerializer.forFormat('application/rdf+xml');
/// ```
library rdfxml_format;

import 'package:rdf_core/rdf_core.dart';

import 'rdfxml_parser.dart';
import 'rdfxml_serializer.dart';

/// Format plugin for RDF/XML
///
/// Implements the [FormatPlugin] interface for the RDF/XML format,
/// providing factory methods for creating parsers and serializers.
final class RdfXmlFormat implements RdfFormat {
  /// MIME type for RDF/XML
  static const String mimeType = 'application/rdf+xml';

  /// Additional MIME types that this format can handle
  static const List<String> alternativeMimeTypes = [
    'application/xml',
    'text/xml',
  ];

  /// File extensions for RDF/XML files
  static const List<String> fileExtensions = ['rdf', 'xml'];

  /// Creates a new RDF/XML format plugin
  const RdfXmlFormat();

  @override
  String get primaryMimeType => mimeType;

  @override
  List<String> get additionalMimeTypes => alternativeMimeTypes;

  @override
  List<String> get supportedFileExtensions => fileExtensions;

  @override
  RdfParser createParser(
    String input, {
    String? baseUri,
    RdfNamespaceMappings? namespaceMappings,
    Map<String, dynamic> parserOptions = const {},
  }) {
    return _RdfXmlParserWrapper(
      RdfXmlParser(
        input,
        baseUri: baseUri,
        namespaceMappings: namespaceMappings,
      ),
      format: mimeType,
    );
  }

  @override
  RdfSerializer createSerializer({
    RdfNamespaceMappings? namespaceMappings,
    Map<String, dynamic> serializerOptions = const {},
  }) {
    return _RdfXmlSerializerWrapper(
      RdfXmlSerializer(namespaceMappings: namespaceMappings),
      format: mimeType,
    );
  }
}

/// Wrapper for RdfXmlParser that implements RdfParser interface
///
/// Adapts the format-specific parser to the common RdfParser interface.
class _RdfXmlParserWrapper implements RdfParser {
  final RdfXmlParser _parser;
  final String _format;

  _RdfXmlParserWrapper(this._parser, {required String format})
    : _format = format;

  @override
  String get format => _format;

  @override
  List<Triple> parse() {
    return _parser.parse();
  }
}

/// Wrapper for RdfXmlSerializer that implements RdfSerializer interface
///
/// Adapts the format-specific serializer to the common RdfSerializer interface.
class _RdfXmlSerializerWrapper implements RdfSerializer {
  final RdfXmlSerializer _serializer;
  final String _format;

  _RdfXmlSerializerWrapper(this._serializer, {required String format})
    : _format = format;

  @override
  String get format => _format;

  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    return _serializer.write(
      graph,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }
}
