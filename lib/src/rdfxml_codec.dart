/// RDF/XML Codec Implementation
///
/// Defines the codec plugin for RDF/XML encoding and decoding.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// final graph = rdfxml.decode(rdfXmlString);
/// ```
library;

import 'package:rdf_core/rdf_core.dart';

import 'configuration.dart';
import 'implementations/parsing_impl.dart';
import 'implementations/serialization_impl.dart';
import 'interfaces/serialization.dart';
import 'interfaces/xml_parsing.dart';
import 'rdfxml_parser.dart';
import 'rdfxml_serializer.dart';

/// Codec plugin for RDF/XML
///
/// Extends the [RdfGraphCodec] base class for the RDF/XML mimetype.
final class RdfXmlCodec extends RdfGraphCodec {
  /// MIME type for RDF/XML
  static const String mimeType = 'application/rdf+xml';

  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Namespace manager for handling namespace declarations
  final INamespaceManager _namespaceManager;

  final RdfNamespaceMappings _namespaceMappings;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Parser options for configuring parser behavior
  final RdfXmlDecoderOptions _decoderOptions;

  /// Serializer options for configuring serializer behavior
  final RdfXmlEncoderOptions _encoderOptions;

  /// Creates a new RDF/XML format plugin with optional dependencies
  ///
  /// Parameters:
  /// - [xmlDocumentProvider] Optional XML document provider
  /// - [uriResolver] Optional URI resolver
  /// - [namespaceManager] Optional namespace manager
  /// - [xmlBuilder] Optional XML builder
  /// - [decoderOptions] Optional decoder options
  /// - [encoderOptions] Optional encoder options
  RdfXmlCodec({
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    INamespaceManager? namespaceManager,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlDecoderOptions? decoderOptions,
    RdfXmlEncoderOptions? encoderOptions,
    RdfNamespaceMappings? namespaceMappings,
  }) : _xmlDocumentProvider =
           xmlDocumentProvider ?? const DefaultXmlDocumentProvider(),
       _uriResolver = uriResolver ?? const DefaultUriResolver(),
       _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings(),
       _namespaceManager =
           namespaceManager ??
           DefaultNamespaceManager(
             namespaceMappings:
                 namespaceMappings ?? const RdfNamespaceMappings(),
           ),
       _xmlBuilder = xmlBuilder ?? DefaultRdfXmlBuilder(),
       _decoderOptions = decoderOptions ?? const RdfXmlDecoderOptions(),
       _encoderOptions = encoderOptions ?? const RdfXmlEncoderOptions();

  @override
  String get primaryMimeType => mimeType;

  @override
  Set<String> get supportedMimeTypes => {
    mimeType,
    'application/xml',
    'text/xml',
  };

  @override
  RdfGraphDecoder get decoder {
    return RdfXmlDecoder(
      xmlDocumentProvider: _xmlDocumentProvider,
      rdfNamespaceMappings: _namespaceMappings,
      uriResolver: _uriResolver,
      options: _decoderOptions,
    );
  }

  @override
  RdfGraphEncoder get encoder {
    return RdfXmlEncoder(
      namespaceManager: _namespaceManager,
      xmlBuilder: _xmlBuilder,
      options: _encoderOptions,
    );
  }

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
  }) => RdfXmlCodec(
    xmlDocumentProvider: _xmlDocumentProvider,
    uriResolver: _uriResolver,
    namespaceManager: _namespaceManager,
    namespaceMappings: _namespaceMappings,
    xmlBuilder: _xmlBuilder,
    decoderOptions: RdfXmlDecoderOptions.from(decoder ?? _decoderOptions),
    encoderOptions: RdfXmlEncoderOptions.from(encoder ?? _encoderOptions),
  );

  @override
  bool canParse(String content) {
    // Check if content appears to be RDF/XML
    return content.contains('<rdf:RDF') ||
        (content.contains(
              'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"',
            ) &&
            content.contains('<rdf:Description'));
  }

  /// Creates a new RDF/XML codec with strict decoder options
  ///
  /// Convenience factory for creating a codec that enforces strict compliance
  /// with the RDF/XML specification.
  factory RdfXmlCodec.strict() =>
      RdfXmlCodec(decoderOptions: RdfXmlDecoderOptions.strict());

  /// Creates a new RDF/XML codec with lenient decoder options
  ///
  /// Convenience factory for creating a codec that tries to parse
  /// even non-conformant RDF/XML.
  factory RdfXmlCodec.lenient() =>
      RdfXmlCodec(decoderOptions: RdfXmlDecoderOptions.lenient());

  /// Creates a new RDF/XML codec optimized for readability
  ///
  /// Convenience factory for creating a codec that produces
  /// human-readable RDF/XML output.
  factory RdfXmlCodec.readable() =>
      RdfXmlCodec(encoderOptions: RdfXmlEncoderOptions.readable());

  /// Creates a new RDF/XML codec optimized for compact output
  ///
  /// Convenience factory for creating a codec that produces
  /// the most compact RDF/XML output.
  factory RdfXmlCodec.compact() =>
      RdfXmlCodec(encoderOptions: RdfXmlEncoderOptions.compact());

  /// Creates a copy of this codec with the given values
  ///
  /// Returns a new instance with updated values.
  RdfXmlCodec copyWith({
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    INamespaceManager? namespaceManager,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlDecoderOptions? decoderOptions,
    RdfXmlEncoderOptions? encoderOptions,
  }) {
    return RdfXmlCodec(
      xmlDocumentProvider: xmlDocumentProvider ?? _xmlDocumentProvider,
      uriResolver: uriResolver ?? _uriResolver,
      namespaceManager: namespaceManager ?? _namespaceManager,
      xmlBuilder: xmlBuilder ?? _xmlBuilder,
      decoderOptions: decoderOptions ?? _decoderOptions,
      encoderOptions: encoderOptions ?? _encoderOptions,
    );
  }
}

/// Adapter class to make RdfXmlParser compatible with the RdfGraphDecoder interface
final class RdfXmlDecoder extends RdfGraphDecoder {
  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Decoder options for configuring behavior
  final RdfXmlDecoderOptions _options;

  final RdfNamespaceMappings _rdfNamespaceMappings;

  /// Creates a new adapter for RdfXmlParser
  const RdfXmlDecoder({
    required IXmlDocumentProvider xmlDocumentProvider,
    required IUriResolver uriResolver,
    required RdfXmlDecoderOptions options,
    required RdfNamespaceMappings rdfNamespaceMappings,
  }) : _xmlDocumentProvider = xmlDocumentProvider,
       _rdfNamespaceMappings = rdfNamespaceMappings,
       _uriResolver = uriResolver,
       _options = options;

  @override
  RdfXmlDecoder withOptions(RdfGraphDecoderOptions options) => RdfXmlDecoder(
    xmlDocumentProvider: _xmlDocumentProvider,
    uriResolver: _uriResolver,
    options: RdfXmlDecoderOptions.from(options),
    rdfNamespaceMappings: _rdfNamespaceMappings,
  );

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    final parser = RdfXmlParser(
      input,
      namespaceMappings: _rdfNamespaceMappings,
      baseUri: documentUrl,
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _options,
    );
    final triples = parser.parse();
    return RdfGraph.fromTriples(triples);
  }
}

/// Adapter class to make RdfXmlSerializer compatible with the RdfGraphEncoder interface
final class RdfXmlEncoder extends RdfGraphEncoder {
  /// Namespace manager for handling namespace declarations
  final INamespaceManager _namespaceManager;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Serializer options for configuring behavior
  final RdfXmlEncoderOptions _options;

  /// Creates a new adapter for RdfXmlSerializer
  const RdfXmlEncoder({
    required INamespaceManager namespaceManager,
    required IRdfXmlBuilder xmlBuilder,
    required RdfXmlEncoderOptions options,
  }) : _namespaceManager = namespaceManager,
       _xmlBuilder = xmlBuilder,
       _options = options;

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => RdfXmlEncoder(
    namespaceManager: _namespaceManager,
    xmlBuilder: _xmlBuilder,
    options: RdfXmlEncoderOptions.from(options),
  );

  @override
  String convert(RdfGraph graph, {String? baseUri}) {
    final serializer = RdfXmlSerializer(
      namespaceManager: _namespaceManager,
      xmlBuilder: _xmlBuilder,
      options: _options,
    );
    return serializer.write(
      graph,
      baseUri: baseUri,
      customPrefixes: _options.customPrefixes,
    );
  }
}

/// Global convenience variable for working with RDF/XML format
///
/// This variable provides direct access to RDF/XML codec for easy
/// encoding and decoding of RDF/XML data.
///
/// Example:
/// ```dart
/// final graph = rdfxml.decode(rdfxmlString);
/// final rdfxmlString2 = rdfxml.encode(graph);
/// ```
final rdfxml = RdfXmlCodec();
