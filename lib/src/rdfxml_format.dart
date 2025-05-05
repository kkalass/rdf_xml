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

import 'configuration.dart';
import 'implementations/parsing_impl.dart';
import 'implementations/serialization_impl.dart';
import 'interfaces/serialization.dart';
import 'interfaces/xml_parsing.dart';
import 'rdfxml_parser.dart';
import 'rdfxml_serializer.dart';

/// Enhanced parser with stream-based parsing capabilities
///
/// Extends the standard RdfParser interface with streaming capabilities
/// for more efficient processing of large RDF documents.
abstract class StreamingRdfParser implements RdfParser {
  /// Parses an RDF document as a stream of triples
  ///
  /// This method allows for more memory-efficient processing of large documents
  /// by yielding triples incrementally as they are parsed, rather than
  /// building a complete graph in memory.
  Stream<Triple> parseAsStream(String input, {String? documentUrl});
}

/// Format plugin for RDF/XML
///
/// Implements the [RdfFormat] interface for the RDF/XML format,
/// providing factory methods for creating parsers and serializers.
final class RdfXmlFormat implements RdfFormat {
  /// MIME type for RDF/XML
  static const String mimeType = 'application/rdf+xml';

  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Namespace manager for handling namespace declarations
  final INamespaceManager _namespaceManager;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Parser options for configuring parser behavior
  final RdfXmlParserOptions _parserOptions;

  /// Serializer options for configuring serializer behavior
  final RdfXmlSerializerOptions _serializerOptions;

  /// Creates a new RDF/XML format plugin with optional dependencies
  ///
  /// Parameters:
  /// - [xmlDocumentProvider] Optional XML document provider
  /// - [uriResolver] Optional URI resolver
  /// - [namespaceManager] Optional namespace manager
  /// - [xmlBuilder] Optional XML builder
  /// - [parserOptions] Optional parser options
  /// - [serializerOptions] Optional serializer options
  RdfXmlFormat({
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    INamespaceManager? namespaceManager,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlParserOptions? parserOptions,
    RdfXmlSerializerOptions? serializerOptions,
  }) : _xmlDocumentProvider =
           xmlDocumentProvider ?? const DefaultXmlDocumentProvider(),
       _uriResolver = uriResolver ?? const DefaultUriResolver(),
       _namespaceManager = namespaceManager ?? const DefaultNamespaceManager(),
       _xmlBuilder = xmlBuilder ?? DefaultRdfXmlBuilder(),
       _parserOptions = parserOptions ?? const RdfXmlParserOptions(),
       _serializerOptions =
           serializerOptions ?? const RdfXmlSerializerOptions();

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
    return _RdfXmlFormatParserAdapter(
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _parserOptions,
    );
  }

  /// Creates a streaming parser for processing large documents
  ///
  /// Returns a parser that supports incremental processing of RDF/XML documents
  /// using a stream-based approach for better memory efficiency.
  StreamingRdfParser createStreamingParser() {
    return _RdfXmlFormatStreamingParserAdapter(
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _parserOptions,
    );
  }

  @override
  RdfSerializer createSerializer() {
    return _RdfXmlFormatSerializerAdapter(
      namespaceManager: _namespaceManager,
      xmlBuilder: _xmlBuilder,
      options: _serializerOptions,
    );
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

  /// Creates a new RDF/XML format with strict parser options
  ///
  /// Convenience factory for creating a format that enforces strict compliance
  /// with the RDF/XML specification.
  factory RdfXmlFormat.strict() =>
      RdfXmlFormat(parserOptions: RdfXmlParserOptions.strict());

  /// Creates a new RDF/XML format with lenient parser options
  ///
  /// Convenience factory for creating a format that tries to parse
  /// even non-conformant RDF/XML.
  factory RdfXmlFormat.lenient() =>
      RdfXmlFormat(parserOptions: RdfXmlParserOptions.lenient());

  /// Creates a new RDF/XML format optimized for readability
  ///
  /// Convenience factory for creating a format that produces
  /// human-readable RDF/XML output.
  factory RdfXmlFormat.readable() =>
      RdfXmlFormat(serializerOptions: RdfXmlSerializerOptions.readable());

  /// Creates a new RDF/XML format optimized for compact output
  ///
  /// Convenience factory for creating a format that produces
  /// the most compact RDF/XML output.
  factory RdfXmlFormat.compact() =>
      RdfXmlFormat(serializerOptions: RdfXmlSerializerOptions.compact());

  /// Creates a copy of this format with the given values
  ///
  /// Returns a new instance with updated values.
  RdfXmlFormat copyWith({
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    INamespaceManager? namespaceManager,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlParserOptions? parserOptions,
    RdfXmlSerializerOptions? serializerOptions,
  }) {
    return RdfXmlFormat(
      xmlDocumentProvider: xmlDocumentProvider ?? _xmlDocumentProvider,
      uriResolver: uriResolver ?? _uriResolver,
      namespaceManager: namespaceManager ?? _namespaceManager,
      xmlBuilder: xmlBuilder ?? _xmlBuilder,
      parserOptions: parserOptions ?? _parserOptions,
      serializerOptions: serializerOptions ?? _serializerOptions,
    );
  }
}

/// Adapter class to make RdfXmlParser compatible with the RdfParser interface
final class _RdfXmlFormatParserAdapter implements RdfParser {
  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Parser options for configuring behavior
  final RdfXmlParserOptions _options;

  /// Creates a new adapter for RdfXmlParser
  const _RdfXmlFormatParserAdapter({
    required IXmlDocumentProvider xmlDocumentProvider,
    required IUriResolver uriResolver,
    required RdfXmlParserOptions options,
  }) : _xmlDocumentProvider = xmlDocumentProvider,
       _uriResolver = uriResolver,
       _options = options;

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    final parser = RdfXmlParser(
      input,
      baseUri: documentUrl,
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _options,
    );
    final triples = parser.parse();
    return RdfGraph.fromTriples(triples);
  }
}

/// Adapter class to make RdfXmlSerializer compatible with the RdfSerializer interface
final class _RdfXmlFormatSerializerAdapter implements RdfSerializer {
  /// Namespace manager for handling namespace declarations
  final INamespaceManager _namespaceManager;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Serializer options for configuring behavior
  final RdfXmlSerializerOptions _options;

  /// Creates a new adapter for RdfXmlSerializer
  const _RdfXmlFormatSerializerAdapter({
    required INamespaceManager namespaceManager,
    required IRdfXmlBuilder xmlBuilder,
    required RdfXmlSerializerOptions options,
  }) : _namespaceManager = namespaceManager,
       _xmlBuilder = xmlBuilder,
       _options = options;

  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    final serializer = RdfXmlSerializer(
      namespaceManager: _namespaceManager,
      xmlBuilder: _xmlBuilder,
      options: _options,
    );
    return serializer.write(
      graph,
      baseUri: baseUri,
      customPrefixes: customPrefixes,
    );
  }
}

/// Adapter class to make RdfXmlParser compatible with the StreamingRdfParser interface
final class _RdfXmlFormatStreamingParserAdapter implements StreamingRdfParser {
  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Parser options for configuring behavior
  final RdfXmlParserOptions _options;

  /// Creates a new adapter for RdfXmlParser with streaming capabilities
  const _RdfXmlFormatStreamingParserAdapter({
    required IXmlDocumentProvider xmlDocumentProvider,
    required IUriResolver uriResolver,
    required RdfXmlParserOptions options,
  }) : _xmlDocumentProvider = xmlDocumentProvider,
       _uriResolver = uriResolver,
       _options = options;

  @override
  RdfGraph parse(String input, {String? documentUrl}) {
    final parser = RdfXmlParser(
      input,
      baseUri: documentUrl,
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _options,
    );
    final triples = parser.parse();
    return RdfGraph.fromTriples(triples);
  }

  @override
  Stream<Triple> parseAsStream(String input, {String? documentUrl}) async* {
    final parser = RdfXmlParser(
      input,
      baseUri: documentUrl,
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _options,
    );
    yield* parser.parseAsStream();
  }
}
